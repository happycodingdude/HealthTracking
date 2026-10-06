import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

/// Dòng ngân sách một tháng (`ai_budget_months`), tiền tính bằng 1/100 đồng.
final class BudgetMonth {
  const BudgetMonth({
    required this.month,
    required this.capVnd,
    required this.usedCenti,
    required this.reservedCenti,
    required this.warnedAt,
    required this.blockedAt,
  });

  final YearMonth month;
  final int capVnd;
  final int usedCenti;
  final int reservedCenti;
  final DateTime? warnedAt;
  final DateTime? blockedAt;

  int get capCenti => capVnd * 100;
}

/// Sổ ngân sách AI dùng chung toàn app (06 VS12-T06, 05 §6.9.2). Mọi thao tác
/// ghi chạy trong transaction của nơi gọi, sau khi đã khóa dòng tháng bằng
/// [lock] (`FOR UPDATE`): hai yêu cầu đồng thời không thể cùng lọt qua trần.
abstract final class BudgetLedger {
  static const _columns = '''
    month, cap_vnd, round(used_vnd * 100)::bigint, round(reserved_vnd * 100)::bigint,
    warned_80_at, blocked_at''';

  /// Tạo dòng tháng nếu chưa có (F11-E2: tháng mới bắt đầu từ 0) rồi khóa.
  static Future<BudgetMonth> lock(
    Session s,
    YearMonth month,
    int capVnd,
  ) async {
    await s.execute(
      Sql.named('''
        INSERT INTO ai_budget_months (month, cap_vnd) VALUES (@m, @cap)
        ON CONFLICT (month) DO NOTHING'''),
      parameters: {'m': month.toKey(), 'cap': capVnd},
    );
    final rows = await s.execute(
      Sql.named(
        'SELECT $_columns FROM ai_budget_months WHERE month = @m FOR UPDATE',
      ),
      parameters: {'m': month.toKey()},
    );
    return _row(rows.single);
  }

  /// Đọc không khóa; null khi tháng chưa có yêu cầu nào.
  static Future<BudgetMonth?> read(Session s, YearMonth month) async {
    final rows = await s.execute(
      Sql.named('SELECT $_columns FROM ai_budget_months WHERE month = @m'),
      parameters: {'m': month.toKey()},
    );
    return rows.isEmpty ? null : _row(rows.single);
  }

  /// `meta.aiBudget` của tháng chứa [now] (ED-04).
  static Future<AiBudgetMeta> meta(Session s, DateTime now, int capVnd) async {
    final month = AiBudgetRules.monthOf(now);
    final row = await read(s, month);
    return AiBudgetMeta(
      month: month,
      usedVnd: row == null ? 0 : _vnd(row.usedCenti),
      capVnd: row?.capVnd ?? capVnd,
      blocked: row?.blockedAt != null,
    );
  }

  static Future<void> reserve(Session s, YearMonth month, int centi) =>
      s.execute(
        Sql.named('''
          UPDATE ai_budget_months SET reserved_vnd = reserved_vnd + @c::numeric / 100
          WHERE month = @m'''),
        parameters: {'m': month.toKey(), 'c': centi},
      );

  /// Quyết toán: cộng chi phí thực tế, trả lại số đã đặt trước.
  static Future<void> settle(
    Session s,
    YearMonth month, {
    required int reservedCenti,
    required int actualCenti,
  }) => s.execute(
    Sql.named('''
      UPDATE ai_budget_months
      SET used_vnd = used_vnd + @a::numeric / 100,
          reserved_vnd = greatest(reserved_vnd - @r::numeric / 100, 0)
      WHERE month = @m'''),
    parameters: {'m': month.toKey(), 'a': actualCenti, 'r': reservedCenti},
  );

  /// F11-R5: tháng bị chặn đến 00:00 ngày 1 tháng sau.
  static Future<void> block(Session s, YearMonth month, DateTime now) =>
      s.execute(
        Sql.named('''
          UPDATE ai_budget_months SET blocked_at = coalesce(blocked_at, @now)
          WHERE month = @m'''),
        parameters: {'m': month.toKey(), 'now': now},
      );

  /// F11-R4: ghi đã báo 80%. Trả true đúng một lần trong tháng.
  static Future<bool> warn(Session s, YearMonth month, DateTime now) async {
    final rows = await s.execute(
      Sql.named('''
        UPDATE ai_budget_months SET warned_80_at = @now
        WHERE month = @m AND warned_80_at IS NULL
        RETURNING 1'''),
      parameters: {'m': month.toKey(), 'now': now},
    );
    return rows.isNotEmpty;
  }

  static num _vnd(int centi) => centi % 100 == 0 ? centi ~/ 100 : centi / 100;

  static BudgetMonth _row(ResultRow r) => BudgetMonth(
    month: YearMonth.parse(r[0]! as String),
    capVnd: r[1]! as int,
    usedCenti: r[2]! as int,
    reservedCenti: r[3]! as int,
    warnedAt: r[4] as DateTime?,
    blockedAt: r[5] as DateTime?,
  );
}

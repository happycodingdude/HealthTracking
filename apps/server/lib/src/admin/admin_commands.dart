import 'dart:math';

import 'package:api_contract/api_contract.dart' show ApnsEnvironment;
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../ai/budget_ledger.dart';
import '../auth/token_service.dart';
import '../live_activity/apns.dart';
import '../live_activity/scheduler.dart';

final class AdminException implements Exception {
  AdminException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lệnh quản trị trên server (TR-09, 05 §6.8.4). Không có màn hình quản trị trong app.
final class AdminCommands {
  AdminCommands(this._pool, this._tokens, {int bcryptCost = 12})
    : _cost = bcryptCost;

  final Pool<void> _pool;
  final TokenService _tokens;
  final int _cost;

  /// Bỏ các ký tự dễ nhầm (0/O, 1/l/I) để đọc mật khẩu tạm qua điện thoại.
  static const _alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  static final _random = Random.secure();

  static String generateTempPassword({int length = 12}) => List.generate(
    length,
    (_) => _alphabet[_random.nextInt(_alphabet.length)],
  ).join();

  /// Đặt mật khẩu tạm cho tài khoản có số [phone], thu hồi mọi phiên của tài
  /// khoản. Trả mật khẩu tạm để in ra màn hình.
  Future<String> resetPassword(String phone) async {
    if (!AccountValidators.isValidPhone(phone)) {
      throw AdminException(
        'Số điện thoại không đúng định dạng (10 chữ số, bắt đầu bằng 0).',
      );
    }
    final temp = generateTempPassword();
    await _pool.runTx((tx) async {
      final rows = await tx.execute(
        Sql.named('''
          UPDATE users SET password_hash = crypt(@password, gen_salt('bf', @cost::int)), updated_at = now()
          WHERE phone = @phone
          RETURNING id'''),
        parameters: {
          'password': temp,
          'cost': _cost,
          'phone': AccountValidators.normalizePhone(phone),
        },
      );
      if (rows.isEmpty) {
        throw AdminException('Không có tài khoản nào dùng số $phone.');
      }
      await _tokens.revokeAll(tx, rows.first[0]! as String);
    });
    return temp;
  }

  /// `admin apns test --user <số>` (06 Bản 3 VS40-T06): gửi push `end` tới
  /// token thẻ của tài khoản (token cập nhật nếu có, không thì push-to-start
  /// token) để thử khóa APNs. Không in token.
  Future<ApnsResult> apnsTest(String phone, Apns apns, DateTime now) async {
    if (!AccountValidators.isValidPhone(phone)) {
      throw AdminException(
        'Số điện thoại không đúng định dạng (10 chữ số, bắt đầu bằng 0).',
      );
    }
    final rows = await _pool.execute(
      Sql.named('''
        SELECT COALESCE(t.activity_push_token, t.push_to_start_token), t.environment
        FROM live_activity_tokens t JOIN users u ON u.id = t.user_id
        WHERE u.phone = @phone'''),
      parameters: {'phone': AccountValidators.normalizePhone(phone)},
    );
    if (rows.isEmpty) {
      throw AdminException(
        'Tài khoản $phone chưa có token thẻ (mở app Bản 3 trên iPhone trước).',
      );
    }
    return apns.send(
      ApnsPush(
        token: rows.first[0]! as String,
        environment: ApnsEnvironment.tryParse(rows.first[1]! as String)!,
        payload: LiveActivityPayload.end(now),
      ),
    );
  }

  /// `admin budget --show` (06 VS13-T03, TR-09): tháng hiện tại theo giờ Việt
  /// Nam, đã dùng, đang đặt trước, trạng thái chặn, 10 yêu cầu gần nhất. Không
  /// in thông tin tài khoản.
  Future<String> budgetReport(DateTime now, {int capVnd = 50000}) async {
    final month = AiBudgetRules.monthOf(now);
    final row = await BudgetLedger.read(_pool, month);
    final cap = row?.capVnd ?? capVnd;
    final used = row?.usedCenti ?? 0;
    final out = StringBuffer()
      ..writeln('Ngân sách AI tháng ${month.toKey()} (giờ Việt Nam)')
      ..writeln('Mức trần: ${_vnd(cap * 100)}')
      ..writeln(
        'Đã dùng: ${_vnd(used)} (${AiBudgetRules.percent(used / 100, cap)}%)',
      )
      ..writeln('Đang đặt trước: ${_vnd(row?.reservedCenti ?? 0)}')
      ..writeln(
        row?.blockedAt == null
            ? 'Trạng thái: đang hoạt động'
            : 'Trạng thái: ĐÃ CHẶN từ ${_time(row!.blockedAt!)}, gợi ý AI dừng '
                  'đến ${AiBudgetRules.resetDate(month).toKey()}',
      )
      ..writeln(
        row?.warnedAt == null
            ? 'Báo 80%: chưa'
            : 'Báo 80%: đã báo lúc ${_time(row!.warnedAt!)}',
      )
      ..writeln('10 yêu cầu gần nhất:');
    final rows = await _pool.execute(
      Sql.named('''
        SELECT created_at, feature, status::text, round(reserved_vnd * 100)::bigint,
               round(actual_vnd * 100)::bigint, input_tokens, output_tokens, error_code
        FROM ai_requests WHERE month = @m
        ORDER BY created_at DESC LIMIT 10'''),
      parameters: {'m': month.toKey()},
    );
    if (rows.isEmpty) out.writeln('  (chưa có)');
    for (final r in rows) {
      final actual = r[4] as int?;
      out.writeln(
        '  ${_time(r[0]! as DateTime)}  ${r[1]}  ${r[2]}  '
        'đặt trước ${_vnd(r[3]! as int)}  '
        'thực tế ${actual == null ? '—' : _vnd(actual)}  '
        'token ${r[5] ?? '—'}/${r[6] ?? '—'}'
        '${r[7] == null ? '' : '  ${r[7]}'}',
      );
    }
    return out.toString();
  }

  /// `12.500,50đ`.
  static String _vnd(int centi) {
    final whole = (centi ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final frac = centi % 100;
    return frac == 0 ? '$wholeđ' : '$whole,${frac.toString().padLeft(2, '0')}đ';
  }

  static String _time(DateTime t) =>
      '${t.toUtc().toIso8601String().substring(0, 19)}Z';
}

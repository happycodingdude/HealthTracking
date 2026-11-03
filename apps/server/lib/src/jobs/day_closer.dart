import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

/// `DayCloser` (05 Bản 5 TD5-12, TD5-17; F05-R63, CR5-08): mỗi 5 phút, với
/// mỗi tài khoản có múi giờ trong hồ sơ, buổi theo lịch của ngày đã qua
/// 00:00 (theo múi giờ đó) mà vẫn chưa đánh dấu và **không** nằm trong khoảng
/// tạm dừng (F31-R3) → `mark = 'skipped_auto'` ("Không tập (tự động)"). Thay
/// mốc cuối thứ 7 của Bản 2. Mỗi lần quét 8 ngày gần nhất (lần chạy đầu sau
/// khi lên Bản 5 đóng cả các buổi còn sót, TD5-17); chạy lại không đổi gì.
///
/// Giá trị ghi chỉ để database phản ánh đúng; pull không gửi `skipped_auto`
/// (app suy ra cùng trạng thái, TA5-05) nên không đổi `server_version`.
final class DayCloser {
  DayCloser(this._pool, this._clock);

  final Pool<void> _pool;
  final Clock _clock;

  /// Số ngày quét lùi từ hôm qua (TD5-17).
  static const lookbackDays = 8;

  /// Chu kỳ chạy (TD5-12; 05 Bản 5 §6.12 mặc định `*/5 * * * *`).
  static const interval = Duration(minutes: 5);

  /// Trả số buổi vừa đóng.
  Future<int> run() async {
    final result = await _pool.execute(
      Sql.named(
        '''
        UPDATE days d
        SET mark = 'skipped_auto', updated_at = now()
        FROM profiles p
        WHERE p.user_id = d.user_id AND NOT p.deleted
          AND p.timezone IN (SELECT name FROM pg_timezone_names)
          AND NOT d.deleted AND d.kind = 'workout' AND d.mark IS NULL
          AND d.date < (@now::timestamptz AT TIME ZONE p.timezone)::date
          AND d.date >= (@now::timestamptz AT TIME ZONE p.timezone)::date - @back::int
          AND NOT EXISTS (
            SELECT 1 FROM schedule_pauses sp
            WHERE sp.user_id = d.user_id AND NOT sp.deleted
              AND d.date >= sp.start_date
              AND d.date <= LEAST(sp.end_date, coalesce(sp.ended_on, sp.end_date)))''',
      ),
      parameters: {'now': _clock.now().toUtc(), 'back': lookbackDays},
    );
    return result.affectedRows;
  }
}

// Kiểm thử nâng cấp Bản 5 (06 Bản 5 ED5-11, VS60-T04, TAC5-02), bước 3 —
// chạy TRONG cây code 5.0.0 trên app đã cài đè (tool/upgrade_test.sh chép
// file này vào apps/mobile/integration_test/ rồi xóa sau khi chạy): database
// của app 4.0.0 đã lên schema 3 ở bước 2; buổi "Không tập" ngày đã qua (còn
// hạn 7 ngày của Bản 4) giờ khóa vĩnh viễn (FC5-12, F05-E67).
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/open_database.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/main.dart' as app;

import 'flow_helpers.dart';

const _pastDay = String.fromEnvironment('PAST_DAY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ED5-11 bước 3, FC5-12, F05-E67: sau khi lên 5.0.0, buổi "Không '
      'tập" ngày đã qua còn hạn cũ khóa — không đổi sang Đã tập, không bỏ '
      'đánh dấu; app mở bình thường với dữ liệu cũ', (tester) async {
    expect(_pastDay, isNotEmpty, reason: 'thiếu --dart-define=PAST_DAY');
    final past = LocalDate.parse(_pastDay);
    final db = openAppDatabase();
    final day = (await ScheduleRepository(db).day(past))!;
    expect(day.mark, DayMark.skipped, reason: 'trạng thái cũ giữ nguyên');
    final now = DateTime.now();
    expect(SessionStatus.derive(day, now)!.locked, isTrue);
    expect(SessionRules.canMarkDone(day, now), isFalse);
    expect(SessionRules.canMarkSkipped(day, now), isFalse);
    expect(SessionRules.canUnmark(day, now), isFalse);

    await app.runIronlyApp(database: db);
    await pumpUntil(tester, tabLabel(S.tabToday));
    // ignore: avoid_print
    print('CHECK_V5 ok past=$_pastDay');
  });
}

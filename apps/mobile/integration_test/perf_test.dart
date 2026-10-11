// Đo hiệu năng (06 VS15-T08, IA-04) với 1 năm dữ liệu: mở app tới Hôm nay,
// đánh dấu "Đã tập" tới khi giao diện cập nhật, lưu mức tạ tới khi dòng bài
// cập nhật (06 Bản 2 IA2-05), cuộn S-20 và S-40.
//
// Chạy trong tool/integration_test.sh: trên simulator là bản debug nên số đo
// là cận trên. Số đo trên iPhone thật làm ở bản RC.
import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/open_database.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/main.dart' as app;
import 'package:package_info_plus/package_info_plus.dart';

import 'flow_helpers.dart';

/// T2 Ngực + Tay sau, T4 Lưng, T6 Vai, đều 18:00.
final _template = WeeklyTemplate({
  1: TemplateDay(
    enabled: true,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
  ),
  3: TemplateDay(
    enabled: true,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.back],
  ),
  5: TemplateDay(
    enabled: true,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.shoulders],
  ),
});

/// Hôm nay của app: ngày có buổi tập gần nhất trước hôm nay thật, lúc 18:30
/// (sau giờ tập, đánh dấu được).
final LocalDate _today = () {
  var d = LocalDate.fromDateTime(DateTime.now()).addDays(-1);
  while (_template.days[d.weekday]?.enabled != true) {
    d = d.addDays(-1);
  }
  return d;
}();

/// Ghi thẳng vào database của app 1 năm dữ liệu: thiết lập cách đây 364 ngày,
/// lịch từng tháng, buổi đã qua xen kẽ "Đã tập"/"Không tập", cân mỗi tuần.
/// Dữ liệu chỉ có trên máy: server chưa có lịch tháng nên từ chối lần gửi
/// đánh dấu (sau khi đã đo), không ảnh hưởng số đo.
Future<void> _seedOneYear() async {
  final db = openAppDatabase();
  final setup = _today.addDays(-364);
  final setupAt = setup.atTime(LocalTime(12, 0));
  await AccountRepository(db).put('Minh');
  await ProfileRepository(db).put(
    Profile(
      onboardingStep: 5,
      disclaimerAcceptedAt: setupAt.subtract(const Duration(minutes: 10)),
      heightCm: 175,
      birthYear: 1996,
      sex: Sex.male,
      activityLevel: ActivityLevel.moderate,
      calorieMode: CalorieMode.auto,
      calorieKcal: 2210,
      setupDate: setup,
      onboardingCompletedAt: setupAt,
      remindersEnabled: false,
      timezone: 'Asia/Ho_Chi_Minh',
    ),
  );
  final schedule = ScheduleRepository(db);
  await schedule.putTemplate(_template);
  var month = MonthGenerator.first(_template, setupAt);
  var ym = setup.yearMonth;
  var n = 0;
  while (true) {
    await schedule.putPlan(month.plan);
    for (final d in month.days) {
      if (d.kind != DayKind.workout || !d.date.isBefore(_today)) {
        await schedule.putDay(d);
        continue;
      }
      final skipped = n++ % 4 == 3;
      await schedule.putDay(
        d.withMark(
          skipped ? DayMark.skipped : DayMark.done,
          actual: skipped ? null : d.muscles,
          markedAt: d.date.atTime(d.time!).add(const Duration(hours: 1)),
        ),
      );
    }
    if (ym == _today.yearMonth) break;
    ym = ym.next;
    month = MonthGenerator.month(_template, ym, ym.firstDay.startOfDay);
  }
  final weights = WeightRepository(db);
  for (var w = 0; w <= 52; w++) {
    final week = setup.addDays(-(setup.weekday - 1) + w * 7);
    if (week.isAfter(_today)) break;
    await weights.put(week, 800 - w ~/ 2);
  }
  await db.close();
}

/// Bơm khung hình liên tục tới khi [done] đúng; trả về số ms đã chờ.
Future<int> _msUntil(WidgetTester tester, bool Function() done) async {
  final watch = Stopwatch()..start();
  while (!done()) {
    if (watch.elapsed > const Duration(seconds: 20)) fail('Quá 20 giây');
    await tester.pump(const Duration(milliseconds: 4));
  }
  return watch.elapsedMilliseconds;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VS15-T08, IA-04: 1 năm dữ liệu — mở app tới Hôm nay, đánh dấu '
      '"Đã tập" cập nhật giao diện, cuộn S-20 và S-40', (tester) async {
    final clock = ShiftedClock(
      DateTime.now().difference(_today.atTime(LocalTime(18, 30))),
    );
    // Tài khoản thật trên server thử, phiên lưu trong Keychain như sau đăng ký.
    final auth = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        appVersionProvider.overrideWithValue(
          AppVersion.parse((await PackageInfo.fromPlatform()).version),
        ),
      ],
    );
    await auth
        .read(authRepositoryProvider)
        .register(
          const RegisterRequest(
            displayName: 'Minh',
            phone: '0933333333',
            password: '***REMOVED***',
          ),
        );
    auth.dispose();
    await _seedOneYear();

    // Mở app: từ lúc gọi tới khi Hôm nay hiện buổi tập có nút "Đã tập".
    final done = find.byKey(ValueKey('mark-done-${_today.toKey()}'));
    final startWatch = Stopwatch()..start();
    await app.runHealthApp(overrides: [clockProvider.overrideWithValue(clock)]);
    await _msUntil(tester, () => done.evaluate().isNotEmpty);
    final startupMs = startWatch.elapsedMilliseconds;
    await tester.pumpAndSettle();

    // Ghi mức tạ (06 Bản 2 IA2-05): S-63 → "Ghi" → S-64 nhập hai ô; đo từ lúc
    // chạm "Lưu" tới khi dòng bài hiện con số. Đo trước khi đánh dấu: server
    // thử chưa có lịch nên lần gửi sau đó bị từ chối và ngày bị hoàn về.
    // Bài đầu tiên ghi được của buổi (buổi thay đổi theo ngày chạy test).
    final logButton = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('lift-log-'),
    );
    await tester.tap(find.byKey(const ValueKey('session-view-exercises')));
    await pumpUntil(tester, logButton);
    final exerciseId = (tester.widget(logButton.first).key! as ValueKey<String>)
        .value
        .substring('lift-log-'.length);
    await tester.tap(logButton.first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('lift-start-input')),
      '30',
    );
    await tester.enterText(find.byKey(const ValueKey('lift-end-input')), '35');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lift-save')));
    final value = find.byKey(ValueKey('lift-value-$exerciseId'));
    final liftMs = await _msUntil(tester, () => value.evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('session-back')));
    await tester.pumpAndSettle();

    // Đánh dấu: chạm "Đã tập" → hộp S-65; đo từ lúc chạm "Lưu" tới khi thẻ
    // đổi sang "đã tập" (nút biến mất).
    await tester.tap(done);
    final save = find.byKey(const ValueKey('lock-confirm-save'));
    await pumpUntil(tester, save);
    await tester.tap(save);
    final markMs = await _msUntil(tester, () => done.evaluate().isEmpty);
    await pumpUntil(tester, find.textContaining(S.markedDone('')));

    // Cuộn: thống kê thời gian dựng/vẽ từng khung hình.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    Future<void> scroll(String tab, String key) async {
      await tester.tap(tabLabel(tab));
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      await binding.watchPerformance(() async {
        for (var i = 0; i < 3; i++) {
          await tester.fling(list, const Offset(0, -600), 2500);
          await tester.pumpAndSettle();
        }
        for (var i = 0; i < 3; i++) {
          await tester.fling(list, const Offset(0, 600), 2500);
          await tester.pumpAndSettle();
        }
      }, reportKey: key);
    }

    await scroll(S.tabTraining, 'scroll_s20');
    await scroll(S.tabWeight, 'scroll_s40');

    binding.reportData = {
      ...?binding.reportData,
      'startup_ms': startupMs,
      'mark_ms': markMs,
      'lift_ms': liftMs,
    };
    // ignore: avoid_print
    print('PERF ${binding.reportData}');
    expect(startupMs, lessThan(2000), reason: 'IA-04: mở app dưới 2 giây');
    expect(markMs, lessThan(100), reason: 'IA-04: đánh dấu dưới 100 ms');
    expect(liftMs, lessThan(100), reason: 'IA2-05: lưu mức tạ dưới 100 ms');
  });
}

import 'package:domain/domain.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

/// Dữ liệu test chuẩn (06 §6.9.2).

/// `templateAc2`: T2 Ngực + Tay sau 18:00, T4 Lưng 18:00, T6 Vai 18:00.
final templateAc2 = WeeklyTemplate({
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

/// Như [templateAc2] nhưng không có thứ 4: thứ 4 07/10 là ngày nghỉ (Bản 4:
/// thẻ thực đơn đầy đủ chỉ hiện ở Hôm nay khi không có buổi — 04 S-10 H2).
final templateRestWed = WeeklyTemplate({
  1: templateAc2.days[1]!,
  5: templateAc2.days[5]!,
});

/// `setupAt20261007Noon`: thiết lập lúc 12:00 thứ 4, 07/10/2026.
final setupAt = DateTime(2026, 10, 7, 12);

/// Hồ sơ đã thiết lập xong (`profileMale30`, mức calo Tự động 2.210 kcal).
Profile completedProfile({
  CalorieMode mode = CalorieMode.auto,
  int kcal = 2210,
  bool remindersEnabled = false,
}) => Profile(
  onboardingStep: 5,
  disclaimerAcceptedAt: DateTime(2026, 10, 7, 11, 50),
  heightCm: 175,
  birthYear: 1996,
  sex: Sex.male,
  activityLevel: ActivityLevel.moderate,
  calorieMode: mode,
  calorieKcal: kcal,
  setupDate: LocalDate(2026, 10, 7),
  onboardingCompletedAt: setupAt,
  remindersEnabled: remindersEnabled,
  timezone: 'Asia/Ho_Chi_Minh',
);

/// Ghi vào [db]: tên "Minh", hồ sơ đã thiết lập, cân 80 kg tuần thiết lập,
/// lịch tuần [template] và lịch tháng 10 chia lúc [setupAt] (F03-R5).
Future<void> seedSetUp(
  AppDatabase db, {
  WeeklyTemplate? template,
  Profile? profile,
  List<YearMonth> extraMonths = const [],
}) async {
  final t = template ?? templateAc2;
  await AccountRepository(db).put('Minh');
  await ProfileRepository(db).put(profile ?? completedProfile());
  await WeightRepository(db).put(LocalDate(2026, 10, 5), 800);
  final schedule = ScheduleRepository(db);
  await schedule.putTemplate(t);
  final first = MonthGenerator.first(t, setupAt);
  await schedule.putPlan(first.plan);
  for (final d in first.days) {
    await schedule.putDay(d);
  }
  for (final m in extraMonths) {
    final g = MonthGenerator.month(t, m, m.firstDay.startOfDay);
    await schedule.putPlan(g.plan);
    for (final d in g.days) {
      await schedule.putDay(d);
    }
  }
}

/// Đánh dấu sẵn buổi ngày [date] (bỏ qua kiểm tra thời gian của use case).
Future<void> seedMark(
  AppDatabase db,
  LocalDate date,
  DayMark mark, {
  List<MuscleGroup>? actual,
}) async {
  final schedule = ScheduleRepository(db);
  final d = (await schedule.day(date))!;
  await schedule.putDay(
    d.withMark(
      mark,
      actual: mark == DayMark.done ? (actual ?? d.muscles) : null,
      markedAt: date.atTime(d.time!).add(const Duration(minutes: 30)),
    ),
  );
}

/// Ghi sẵn buổi tập thêm ngày nghỉ [date] (bỏ qua kiểm tra thời gian của use
/// case).
Future<void> seedExtra(
  AppDatabase db,
  LocalDate date,
  List<MuscleGroup> muscles,
) async {
  final schedule = ScheduleRepository(db);
  final d = (await schedule.day(date))!;
  await schedule.putDay(
    d.withExtra(muscles, loggedAt: date.atTime(LocalTime(20, 0))),
  );
}

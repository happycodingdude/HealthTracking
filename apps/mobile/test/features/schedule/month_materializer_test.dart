import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/schedule/application/month_materializer.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';

void main() {
  late AppDatabase db;
  late ScheduleRepository schedule;
  late FixedClock clock;
  late MonthMaterializer materializer;

  final template = WeeklyTemplate({
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

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    schedule = ScheduleRepository(db);
    clock = FixedClock(DateTime(2026, 11, 1, 0, 0, 1));
    materializer = MonthMaterializer(
      db: db,
      schedule: schedule,
      outbox: OutboxWriter(db, clock),
      clock: clock,
    );
  });
  tearDown(() => db.close());

  Future<List<String>> outboxOps() async => [
    for (final o in await db.select(db.outbox).get()) '${o.entity}:${o.op}',
  ];

  test('chưa có lịch tuần (chưa thiết lập) → không tạo gì', () async {
    expect(await materializer.run(), isFalse);
    expect(await schedule.plan(YearMonth(2026, 11)), isNull);
    expect(await outboxOps(), isEmpty);
  });

  test('F03-AC4, F03-R6: 00:00 ngày 01/11 → lịch tháng 11 tự có theo lịch tuần '
      'hiện tại, chỉ dùng ensure', () async {
    await schedule.putTemplate(template);
    final first = MonthGenerator.first(template, DateTime(2026, 10, 7, 12));
    await schedule.putPlan(first.plan);

    expect(await materializer.run(), isTrue);
    final plan = (await schedule.plan(YearMonth(2026, 11)))!;
    expect(plan.startDate, LocalDate(2026, 11, 1));
    expect(plan.templateHash, template.contentHash);
    final days = await schedule.monthDays(YearMonth(2026, 11));
    // Tháng 11/2026 có 30 ngày, 5 chủ nhật.
    expect(days, hasLength(25));
    expect(days.any((d) => d.date.isSunday), isFalse);
    expect(days.where((d) => d.isWorkout).map((d) => d.date.weekday).toSet(), {
      1,
      3,
      5,
    });
    final ops = await outboxOps();
    expect(ops.toSet(), {'month_plan:ensure', 'day:ensure'});
    expect(ops.where((o) => o == 'day:ensure'), hasLength(25));
  });

  test('VS04-T12: chạy nhiều lần không đổi kết quả; không ghi đè ngày đã có '
      '(ví dụ ngày đã lấy từ máy khác)', () async {
    await schedule.putTemplate(template);
    final fromOtherDevice = PlanDay(
      date: LocalDate(2026, 11, 2),
      kind: DayKind.workout,
      time: LocalTime(7, 0),
      muscles: const [MuscleGroup.abs],
      source: DaySource.override,
    );
    await schedule.putDay(fromOtherDevice);

    expect(await materializer.run(), isTrue);
    final once = await schedule.monthDays(YearMonth(2026, 11));
    final outboxOnce = await outboxOps();
    expect(await schedule.day(LocalDate(2026, 11, 2)), fromOtherDevice);
    expect(outboxOnce.where((o) => o == 'day:ensure'), hasLength(24));

    clock.set(DateTime(2026, 11, 20, 9));
    expect(await materializer.run(), isFalse);
    expect(await materializer.run(), isFalse);
    expect(await schedule.monthDays(YearMonth(2026, 11)), once);
    expect(await outboxOps(), outboxOnce);
  });
}

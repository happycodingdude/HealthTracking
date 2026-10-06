import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/today/application/log_extra_session.dart';

import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late LogExtraSession log;
  late ScheduleRepository schedule;
  final sat = LocalDate(2026, 10, 10);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    clock = FixedClock(DateTime(2026, 10, 10, 20));
    schedule = ScheduleRepository(db);
    log = LogExtraSession(
      db: db,
      schedule: schedule,
      outbox: OutboxWriter(db, clock),
      clock: clock,
    );
    await seedSetUp(db);
  });

  test('06 §6.4.2: thêm, sửa, xóa → bản ghi ngày + outbox trong một '
      'transaction; xóa = extraMuscles null (ED-08)', () async {
    await log(sat, const [MuscleGroup.abs]);
    var d = (await schedule.day(sat))!;
    expect(d.extraMuscles, [MuscleGroup.abs]);
    expect(d.extraLoggedAt, DateTime(2026, 10, 10, 20));

    clock.advance(const Duration(minutes: 1));
    await log(sat, const [MuscleGroup.back]);
    expect((await schedule.day(sat))!.extraMuscles, [MuscleGroup.back]);

    await log(sat, null);
    d = (await schedule.day(sat))!;
    expect(d.extraMuscles, isNull);
    expect(d.extraLoggedAt, isNull);

    final rows = await db.select(db.outbox).get();
    expect(rows, hasLength(1), reason: 'gộp khi chưa gửi được');
    final m = rows.single.toMutation();
    expect((m.entity, m.key, m.op), ('day', '2026-10-10', SyncOp.upsert));
    expect(const DayCodec().decode(m.key, m.data!).extraMuscles, isNull);
  });

  test('F05-AC6: ngày mai, chủ nhật, ngày đã có buổi theo lịch → '
      'ExtraException, không ghi gì', () async {
    clock.set(DateTime(2026, 10, 9, 20));
    for (final (date, error) in [
      (sat, ExtraError.future),
      (LocalDate(2026, 10, 11), ExtraError.notRestDay),
      (LocalDate(2026, 10, 9), ExtraError.notRestDay),
    ]) {
      await expectLater(
        log(date, const [MuscleGroup.abs]),
        throwsA(isA<ExtraException>().having((e) => e.error, 'error', error)),
        reason: '$date',
      );
    }
    expect(await db.select(db.outbox).get(), isEmpty);
  });
}

import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/today/application/mark_session.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';

import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late MarkSessionDone done;
  late MarkSessionSkipped skipped;
  late AddExtraSession addExtra;
  late EditExtraSession editExtra;
  late UnmarkSession unmark;
  late ScheduleRepository schedule;
  final wed = LocalDate(2026, 10, 7);
  final thu = LocalDate(2026, 10, 8);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    clock = FixedClock(DateTime(2026, 10, 7, 18, 5));
    schedule = ScheduleRepository(db);
    final outbox = OutboxWriter(db, clock);
    done = MarkSessionDone(
      db: db,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    skipped = MarkSessionSkipped(
      db: db,
      schedule: schedule,
      liftLogs: LiftLogRepository(db),
      outbox: outbox,
      clock: clock,
    );
    addExtra = AddExtraSession(
      db: db,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    editExtra = EditExtraSession(
      db: db,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    unmark = UnmarkSession(
      db: db,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    await seedSetUp(db);
  });

  Future<SyncMutation> onlyMutation() async {
    final rows = await db.select(db.outbox).get();
    expect(rows, hasLength(1));
    expect(jsonDecode(rows.single.payload!), isA<Map<String, Object?>>());
    return rows.single.toMutation();
  }

  test('ED2-04, F05-V22: chưa xác nhận S-65 → không lưu gì', () async {
    await expectLater(
      done(wed, confirmed: false),
      throwsA(isA<NotConfirmedException>()),
    );
    expect((await schedule.day(wed))!.mark, isNull);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('VS24-T04: "Đã tập" đã xác nhận → bản ghi ngày (nhóm cơ thực tế = '
      'lịch, TD2-08) + outbox trong một transaction', () async {
    await done(wed, confirmed: true);
    final m = await onlyMutation();
    expect((m.entity, m.key, m.op), ('day', '2026-10-07', SyncOp.upsert));
    final sent = const DayCodec().decode(m.key, m.data!);
    expect(sent.mark, DayMark.done);
    expect(sent.actualMuscles, [MuscleGroup.back]);
    expect(
      sent.markedAt!.isAtSameMomentAs(DateTime(2026, 10, 7, 18, 5)),
      isTrue,
    );
  });

  test('F05-AC61, F05-E61 (IR5-08, CR5-06): "Đã tập" → "Không tập" → bỏ đánh '
      'dấu → "Đã tập" lại trong ngày; gộp một mutation khi chưa gửi', () async {
    await done(wed, confirmed: true);
    clock.set(DateTime(2026, 10, 7, 18, 30));
    await skipped(wed);
    expect((await schedule.day(wed))!.mark, DayMark.skipped);
    await unmark(wed);
    expect((await schedule.day(wed))!.mark, isNull);
    await expectLater(
      unmark(wed),
      throwsA(
        isA<MarkException>().having((e) => e.error, 'e', MarkError.notMarked),
      ),
    );
    await done(wed, confirmed: true);
    final sent = const DayCodec().decode(
      '2026-10-07',
      (await onlyMutation()).data!,
    );
    expect(sent.mark, DayMark.done);
  });

  test('F05-E63 (IR5-08, CR5-02): 00:00 ngày sau → mọi thao tác MarkException '
      'locked, không ghi gì', () async {
    await done(wed, confirmed: true);
    await db.delete(db.outbox).go();
    clock.set(DateTime(2026, 10, 8, 0, 1));
    for (final call in [() => skipped(wed), () => unmark(wed)]) {
      await expectLater(
        call(),
        throwsA(
          isA<MarkException>().having((e) => e.error, 'e', MarkError.locked),
        ),
      );
    }
    expect((await schedule.day(wed))!.mark, DayMark.done);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('F05-R22, FC5-02: trước giờ tập → "Đã tập" tooEarly; "Không tập" được '
      '(F05-E62)', () async {
    clock.set(DateTime(2026, 10, 7, 10));
    await expectLater(
      done(wed, confirmed: true),
      throwsA(
        isA<MarkException>().having(
          (e) => e.error,
          'error',
          MarkError.tooEarly,
        ),
      ),
    );
    expect((await schedule.day(wed))!.mark, isNull);
    await skipped(wed);
    expect((await schedule.day(wed))!.mark, DayMark.skipped);
  });

  test('ngày nghỉ, chủ nhật → notWorkout', () async {
    await expectLater(skipped(thu), throwsA(isA<MarkException>()));
    await expectLater(
      done(LocalDate(2026, 10, 11), confirmed: true),
      throwsA(isA<MarkException>()),
    );
  });

  test('F05-R64, F05-E65, F05-AC64 (IR5-08, CR5-07): buổi tập thêm hôm nay → '
      'ghi + outbox, không hộp xác nhận; sửa nhóm cơ, xóa trong ngày; hôm sau '
      'khóa', () async {
    clock.set(DateTime(2026, 10, 8, 20));
    await addExtra(thu, const [MuscleGroup.shoulders]);
    final sent = const DayCodec().decode(
      '2026-10-08',
      (await onlyMutation()).data!,
    );
    expect(sent.extraMuscles, [MuscleGroup.shoulders]);
    await expectLater(
      addExtra(thu, const [MuscleGroup.back]),
      throwsA(
        isA<ExtraException>().having(
          (e) => e.error,
          'error',
          ExtraError.alreadyLogged,
        ),
      ),
    );
    clock.set(DateTime(2026, 10, 8, 21));
    await editExtra(thu, const [MuscleGroup.back]);
    expect((await schedule.day(thu))!.extraMuscles, [MuscleGroup.back]);
    await editExtra(thu, null);
    expect((await schedule.day(thu))!.extraMuscles, isNull);
    await addExtra(thu, const [MuscleGroup.abs]);
    clock.set(DateTime(2026, 10, 9, 0, 1));
    await expectLater(
      editExtra(thu, null),
      throwsA(
        isA<ExtraException>().having((e) => e.error, 'e', ExtraError.locked),
      ),
    );
    expect((await schedule.day(thu))!.extraMuscles, [MuscleGroup.abs]);
  });

  test('F05-AC64, F05-E66: thêm buổi tập thêm cho hôm qua → locked; ngày đã '
      'có buổi theo lịch → notRestDay', () async {
    clock.set(DateTime(2026, 10, 9, 9));
    await expectLater(
      addExtra(thu, const [MuscleGroup.abs]),
      throwsA(
        isA<ExtraException>().having((e) => e.error, 'e', ExtraError.locked),
      ),
    );
    await expectLater(
      addExtra(wed, const [MuscleGroup.abs]),
      throwsA(isA<ExtraException>()),
    );
  });
}

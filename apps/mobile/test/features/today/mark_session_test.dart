import 'dart:async';
import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/today/application/mark_session.dart';

import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late MarkSession mark;
  late ScheduleRepository schedule;
  final wed = LocalDate(2026, 10, 7);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    clock = FixedClock(DateTime(2026, 10, 7, 18, 5));
    schedule = ScheduleRepository(db);
    mark = MarkSession(
      db: db,
      schedule: schedule,
      outbox: OutboxWriter(db, clock),
      clock: clock,
    );
    await seedSetUp(db);
  });

  test('06 §6.4.2: bản ghi ngày + outbox trong một transaction; sửa nhiều lần '
      'khi chưa gửi được gộp thành một mutation', () async {
    await mark(wed, DayMark.done, actual: const [MuscleGroup.back]);
    clock.advance(const Duration(minutes: 1));
    await mark(wed, DayMark.done, actual: const [MuscleGroup.shoulders]);
    final rows = await db.select(db.outbox).get();
    expect(rows, hasLength(1));
    final m = rows.single.toMutation();
    expect((m.entity, m.key, m.op), ('day', '2026-10-07', SyncOp.upsert));
    final sent = const DayCodec().decode(m.key, m.data!);
    expect(sent.actualMuscles, [MuscleGroup.shoulders]);
    expect(
      sent.markedAt!.isAtSameMomentAs(DateTime(2026, 10, 7, 18, 6)),
      isTrue,
    );
    expect(jsonDecode(rows.single.payload!), isA<Map<String, Object?>>());
  });

  test('F05-R1: trước giờ tập → MarkException, không ghi gì', () async {
    clock.set(DateTime(2026, 10, 7, 17, 59));
    await expectLater(
      mark(wed, DayMark.done, actual: const [MuscleGroup.back]),
      throwsA(
        isA<MarkException>().having(
          (e) => e.error,
          'error',
          MarkError.tooEarly,
        ),
      ),
    );
    expect((await schedule.day(wed))!.mark, isNull);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('ngày nghỉ, chủ nhật → notWorkout', () async {
    await expectLater(
      mark(LocalDate(2026, 10, 8), DayMark.skipped),
      throwsA(isA<MarkException>()),
    );
    await expectLater(
      mark(LocalDate(2026, 10, 11), DayMark.skipped),
      throwsA(isA<MarkException>()),
    );
  });

  test('IA-04: đánh dấu → stream của ngày cập nhật dưới 100 ms', () async {
    final updated = Completer<void>();
    final sub = schedule.watchDay(wed).listen((d) {
      if (d?.mark == DayMark.done && !updated.isCompleted) updated.complete();
    });
    addTearDown(sub.cancel);
    // Lần đọc đầu của stream (không tính).
    await schedule.watchDay(wed).first;
    final watch = Stopwatch()..start();
    await mark(wed, DayMark.done, actual: const [MuscleGroup.back]);
    await updated.future;
    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(100));
  });
}

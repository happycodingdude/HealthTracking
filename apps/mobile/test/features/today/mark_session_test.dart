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
    await expectLater(
      addExtra(thu, const [MuscleGroup.abs], confirmed: false),
      throwsA(isA<NotConfirmedException>()),
    );
    expect((await schedule.day(wed))!.mark, isNull);
    expect((await schedule.day(thu))!.extraMuscles, isNull);
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

  test(
    'F05-AC22: sau "Đã tập" không "Không tập" được, không "Đã tập" lại',
    () async {
      await done(wed, confirmed: true);
      await expectLater(
        skipped(wed),
        throwsA(
          isA<MarkException>().having(
            (e) => e.error,
            'error',
            MarkError.alreadyDone,
          ),
        ),
      );
      await expectLater(
        done(wed, confirmed: true),
        throwsA(isA<MarkException>()),
      );
      expect((await schedule.day(wed))!.mark, DayMark.done);
    },
  );

  test('F05-R25: "Không tập" lưu ngay; đổi sang "Đã tập" trong 7 ngày → '
      'gộp thành một mutation khi chưa gửi', () async {
    await skipped(wed);
    clock.set(DateTime(2026, 10, 14, 23, 59));
    await done(wed, confirmed: true);
    final sent = const DayCodec().decode(
      '2026-10-07',
      (await onlyMutation()).data!,
    );
    expect(sent.mark, DayMark.done);
  });

  test('F05-R22: trước giờ tập → MarkException, không ghi gì', () async {
    clock.set(DateTime(2026, 10, 7, 17, 59));
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
    await expectLater(skipped(wed), throwsA(isA<MarkException>()));
    expect((await schedule.day(wed))!.mark, isNull);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('ngày nghỉ, chủ nhật → notWorkout', () async {
    await expectLater(skipped(thu), throwsA(isA<MarkException>()));
    await expectLater(
      done(LocalDate(2026, 10, 11), confirmed: true),
      throwsA(isA<MarkException>()),
    );
  });

  test('F05-AC26: buổi tập thêm đã xác nhận → ghi + outbox; không thêm lại '
      'được (khóa), không có cách sửa hay xóa', () async {
    clock.set(DateTime(2026, 10, 8, 20));
    await addExtra(thu, const [MuscleGroup.abs], confirmed: true);
    final sent = const DayCodec().decode(
      '2026-10-08',
      (await onlyMutation()).data!,
    );
    expect(sent.extraMuscles, [MuscleGroup.abs]);
    await expectLater(
      addExtra(thu, const [MuscleGroup.back], confirmed: true),
      throwsA(
        isA<ExtraException>().having(
          (e) => e.error,
          'error',
          ExtraError.alreadyLogged,
        ),
      ),
    );
    expect((await schedule.day(thu))!.extraMuscles, [MuscleGroup.abs]);
  });

  test(
    'F05-E29: ngày đã có buổi theo lịch, ngày mai → ExtraException',
    () async {
      await expectLater(
        addExtra(wed, const [MuscleGroup.abs], confirmed: true),
        throwsA(isA<ExtraException>()),
      );
      await expectLater(
        addExtra(thu, const [MuscleGroup.abs], confirmed: true),
        throwsA(isA<ExtraException>()),
      );
    },
  );
}

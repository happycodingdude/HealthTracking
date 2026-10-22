import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/workout/application/lift_log_edits.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';

import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 3 VS35-T06, VS35-T08 (app): `SaveLiftLog` (lần ghi đầu gắn đơn vị),
/// `SaveExerciseNote`, `SaveLiftEntry` (một nút Lưu), `ChangeExerciseUnit`;
/// mọi thao tác ghi máy trước, không gọi mạng (F21-AC51, F26-AC7).
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late LiftLogRepository logs;
  late ExerciseUnitRepository units;
  late ExerciseNoteRepository notes;
  late SaveLiftLog saveLift;
  late SaveExerciseNote saveNote;
  late SaveLiftEntry saveEntry;
  late ChangeExerciseUnit changeUnit;
  late _RecordingHooks hooks;

  // Thứ 2 12/10: Ngực + Tay sau 18:00 (templateAc2); 19:00 trong cửa sổ.
  final monday = LocalDate(2026, 10, 12);
  late String pecDeck;
  late String bench;
  late String triceps;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 12, 19));
    logs = LiftLogRepository(db);
    units = ExerciseUnitRepository(db);
    notes = ExerciseNoteRepository(db);
    hooks = _RecordingHooks();
    final schedule = ScheduleRepository(db);
    final exercises = ExerciseRepository(db);
    final outbox = OutboxWriter(db, clock);
    saveLift = SaveLiftLog(
      db: db,
      logs: logs,
      schedule: schedule,
      exercises: exercises,
      outbox: outbox,
      clock: clock,
      units: units,
      hooks: hooks,
    );
    saveNote = SaveExerciseNote(
      db: db,
      notes: notes,
      schedule: schedule,
      exercises: exercises,
      outbox: outbox,
      clock: clock,
    );
    saveEntry = SaveLiftEntry(db: db, lift: saveLift, note: saveNote);
    changeUnit = ChangeExerciseUnit(
      db: db,
      units: units,
      exercises: exercises,
      outbox: outbox,
      clock: clock,
      hooks: hooks,
    );
    await seedSetUp(db);
    final library = await seedLibrary(db, realLibraryV3());
    pecDeck = exerciseOf(library, MuscleRegion.chestMid).id;
    bench = library
        .where((e) => e.region == MuscleRegion.chestMid)
        .elementAt(1)
        .id;
    triceps = exerciseOf(library, MuscleRegion.tricepsLong).id;
  });
  tearDown(() => db.close());

  Future<List<String>> outbox() async => [
    for (final r in await db.select(db.outbox).get())
      '${r.entity}:${r.entityKey}:${r.op}',
  ];

  group('SaveLiftLog: đơn vị (F21-R41, FA3-03, TD3-05)', () {
    test('F21-V41: lần ghi đầu chưa chọn đơn vị → lỗi, không ghi gì', () async {
      await expectLater(
        saveLift(monday, pecDeck, start: '8', end: '10'),
        throwsA(
          isA<LiftInputException>().having(
            (e) => e.input.error,
            'error',
            LiftInputError.unitMissing,
          ),
        ),
      );
      expect(await outbox(), isEmpty);
      expect(await units.get(pecDeck), isNull);
    });

    test('F21-AC44: chọn nấc, gõ 8 và 10 → bản ghi 80 → 100; outbox có '
        'exercise_unit TRƯỚC lift_log; đơn vị gắn từ hôm nay', () async {
      final log = await saveLift(
        monday,
        pecDeck,
        start: '8',
        end: '10',
        unit: LiftUnit.steps,
      );
      expect((log.startKgX10, log.endKgX10), (80, 100));
      expect(
        await units.get(pecDeck),
        ExerciseUnit(
          exerciseId: pecDeck,
          unit: LiftUnit.steps,
          changedOn: monday,
        ),
      );
      expect(await outbox(), [
        'exercise_unit:$pecDeck:upsert',
        'lift_log:${log.key}:upsert',
      ]);
      expect(hooks.lifts, [monday]);
    });

    test('đã có đơn vị: dùng đơn vị của bài, bỏ qua lựa chọn khác; nấc 8,5 '
        'và 51 bị V44 chặn', () async {
      await saveLift(
        monday,
        pecDeck,
        start: '8',
        end: '10',
        unit: LiftUnit.steps,
      );
      await saveLift(monday, pecDeck, start: '8', end: '11', unit: LiftUnit.kg);
      expect((await units.get(pecDeck))!.unit, LiftUnit.steps);
      expect(
        (await outbox()).where((o) => o.startsWith('exercise_unit')),
        hasLength(1),
        reason: 'không gửi lại đơn vị',
      );
      for (final bad in ['8,5', '51']) {
        await expectLater(
          saveLift(monday, pecDeck, start: '8', end: bad),
          throwsA(
            isA<LiftInputException>().having(
              (e) => e.input.endError,
              'end',
              anyOf(LiftInputError.notStep, LiftInputError.outOfRange),
            ),
          ),
        );
      }
    });
  });

  group('SaveExerciseNote (F-26)', () {
    test('F26-AC1: lưu ghi chú đã trim; lưu lại là ghi đè, outbox gộp một '
        'dòng', () async {
      await saveNote(monday, pecDeck, '  máy 2 hỏng ');
      await saveNote(monday, pecDeck, 'máy 2 hỏng, tập máy 5');
      expect((await notes.get(monday, pecDeck))!.text, 'máy 2 hỏng, tập máy 5');
      expect(await outbox(), [
        'exercise_note:${ExerciseNote.keyOf(monday, pecDeck)}:upsert',
      ]);
    });

    test('F26-E1: dán dài hơn 200 ký tự → giữ 200 ký tự đầu', () async {
      final saved = await saveNote(monday, pecDeck, 'a' * 250);
      expect(saved!.text, 'a' * 200);
    });

    test('F26-V2, F26-AC5: chỉ khoảng trắng → xóa ghi chú đang có (tombstone); '
        'chưa có ghi chú thì không ghi gì', () async {
      expect(await saveNote(monday, bench, '   '), isNull);
      expect(await outbox(), isEmpty);
      await saveNote(monday, pecDeck, 'ghế 3');
      expect(await saveNote(monday, pecDeck, ' \n '), isNull);
      expect(await notes.get(monday, pecDeck), isNull);
      expect(await outbox(), [
        'exercise_note:${ExerciseNote.keyOf(monday, pecDeck)}:delete',
      ]);
    });

    test(
      'F26-E4: 00:01 → khóa; bài khác nhóm của buổi → không ghi được',
      () async {
        clock.set(DateTime(2026, 10, 13, 0, 1));
        await expectLater(
          saveNote(monday, pecDeck, 'muộn'),
          throwsA(
            isA<LiftException>().having(
              (e) => e.error,
              'error',
              LiftError.windowClosed,
            ),
          ),
        );
        clock.set(DateTime(2026, 10, 12, 19));
        final library = realLibraryV3();
        final lats = exerciseOf(library, MuscleRegion.lats).id;
        await expectLater(
          saveNote(monday, lats, 'x'),
          throwsA(isA<LiftException>()),
        );
      },
    );
  });

  group('SaveLiftEntry: một nút Lưu (F21-R49, FD3-01 = A)', () {
    test('F26-AC8: hai ô tạ trống + có ghi chú → chỉ lưu ghi chú, không báo '
        'F21-V42', () async {
      final r = await saveEntry(
        monday,
        bench,
        start: '',
        end: ' ',
        note: 'chỉ ghi chú',
      );
      expect((r.log, r.note?.text), (null, 'chỉ ghi chú'));
      expect(await logs.get(monday, bench), isNull);
    });

    test('mức tạ sai → không lưu gì, kể cả ghi chú', () async {
      await expectLater(
        saveEntry(
          monday,
          bench,
          start: '40',
          end: '13,25',
          unit: LiftUnit.kg,
          note: 'không được lưu',
        ),
        throwsA(isA<LiftInputException>()),
      );
      expect(await notes.get(monday, bench), isNull);
      expect(await outbox(), isEmpty);
    });

    test('có cả hai → lưu cả hai trong một lần; xóa mức tạ không xóa ghi chú '
        '(F26-R5)', () async {
      final r = await saveEntry(
        monday,
        triceps,
        start: '20',
        end: '22,5',
        unit: LiftUnit.kg,
        note: 'đổi dây cáp',
      );
      expect((r.log?.endKgX10, r.note?.text), (225, 'đổi dây cáp'));
      expect(await outbox(), [
        'exercise_unit:$triceps:upsert',
        'lift_log:${LiftLog.keyOf(monday, triceps)}:upsert',
        'exercise_note:${ExerciseNote.keyOf(monday, triceps)}:upsert',
      ]);
    });
  });

  group('ChangeExerciseUnit (F21-R47, FA3-04)', () {
    test(
      'đổi kg → nấc ngoài cửa sổ ghi tạ: số cũ giữ nguyên, changedOn hôm '
      'nay, outbox một mutation; đổi về đúng đơn vị đang có → không làm gì',
      () async {
        await saveLift(
          monday,
          bench,
          start: '40',
          end: '45',
          unit: LiftUnit.kg,
        );
        clock.set(DateTime(2026, 10, 14, 10));
        final changed = await changeUnit(bench, LiftUnit.steps);
        expect(
          (changed.unit, changed.changedOn),
          (LiftUnit.steps, LocalDate(2026, 10, 14)),
        );
        expect((await logs.get(monday, bench))!.endKgX10, 450);
        expect(
          (await outbox()).where((o) => o.startsWith('exercise_unit')),
          hasLength(1),
        );
        final before = await outbox();
        await changeUnit(bench, LiftUnit.steps);
        expect(await outbox(), before);
        expect(hooks.units, [bench, bench]);
      },
    );

    test('bài bụng không có đơn vị (F21-AC50)', () async {
      final plank = exerciseOf(realLibraryV3(), MuscleRegion.absMid).id;
      await expectLater(
        changeUnit(plank, LiftUnit.kg),
        throwsA(isA<LiftException>()),
      );
    });
  });
}

final class _RecordingHooks implements LiftChangeHooks {
  final lifts = <LocalDate>[];
  final units = <String>[];

  @override
  Future<void> liftChanged(LocalDate date) async => lifts.add(date);

  @override
  Future<void> unitChanged(String exerciseId) async => units.add(exerciseId);
}

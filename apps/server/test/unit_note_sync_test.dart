import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart' show LibraryImporter;
import 'package:server/testing.dart' show library28;
import 'package:test/test.dart';

import 'support/test_app.dart';

/// 06 Bản 3 VS35-T08 (server): đơn vị, mức tạ theo đơn vị, ghi chú —
/// TAC3-03, TAC3-06, TAC3-13. Giờ Việt Nam = UTC+7: buổi thứ 2 12/10 Ngực +
/// Bụng 18:00 = 11:00 UTC.
void main() {
  late TestApp app;
  late String token;
  final t0 = DateTime.utc(2026, 10, 7, 5);
  final at1830 = DateTime.utc(2026, 10, 12, 11, 30);
  final monday = LocalDate(2026, 10, 12);
  const pecDeck = 'chest-mid-machine-pec-deck';
  const bench = 'chest-mid-free-weight-flat-barbell-bench-press';
  const plank = 'abs-mid-bodyweight-forearm-plank';
  const lats = 'lats-machine-lat-pulldown';

  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest, MuscleGroup.abs],
    ),
  });
  final generated = MonthGenerator.first(template, DateTime(2026, 10, 7, 12));

  Future<String> login(String phone) async {
    final res = await app.post('/v1/auth/login', {
      'phone': phone,
      'password': testPassword,
    });
    return TokenPair.fromJson(res.json).accessToken;
  }

  Future<List<PushResult>> push(List<SyncMutation> ms, {String? as}) async =>
      (await app.push(as ?? token, ms)).results;

  Future<void> setUpSchedule(String as) async {
    final profile = Profile(
      onboardingStep: 5,
      disclaimerAcceptedAt: DateTime.utc(2026, 10, 7, 4),
      heightCm: 175,
      birthYear: 1996,
      sex: Sex.male,
      activityLevel: ActivityLevel.moderate,
      calorieMode: CalorieMode.auto,
      calorieKcal: 2210,
      setupDate: LocalDate(2026, 10, 7),
      onboardingCompletedAt: DateTime.utc(2026, 10, 7, 5),
      timezone: 'Asia/Ho_Chi_Minh',
    );
    final results = await push([
      mutation(
        'profile',
        'me',
        SyncOp.upsert,
        at: t0,
        data: const ProfileCodec().encode(profile),
      ),
      mutation(
        'weekly_template',
        'me',
        SyncOp.upsert,
        at: t0,
        data: const WeeklyTemplateCodec().encode(template),
      ),
      mutation(
        'month_plan',
        MonthPlanCodec.keyOf(generated.plan.month),
        SyncOp.ensure,
        at: t0,
        data: const MonthPlanCodec().encode(generated.plan),
      ),
      for (final d in generated.days)
        mutation(
          'day',
          d.date.toKey(),
          SyncOp.ensure,
          at: t0,
          data: const DayCodec().encode(d),
        ),
    ], as: as);
    expect(results.every((r) => r.status == PushStatus.applied), isTrue);
  }

  setUp(() async {
    app = await TestApp.create(now: t0);
    token = (await app.register()).accessToken;
    expect((await LibraryImporter(app.tdb.pool).run(library28())).ok, isTrue);
    await setUpSchedule(token);
    // 18:30 thứ 2 12/10 giờ Việt Nam, trong cửa sổ ghi tạ.
    app.clock.set(at1830);
    token = await login('0912345678');
  });
  tearDown(() => app.dispose());

  SyncMutation unit(
    String exerciseId,
    String unit, {
    DateTime? at,
    String changedOn = '2026-10-12',
  }) => mutation(
    SyncEntities.exerciseUnit,
    exerciseId,
    SyncOp.upsert,
    at: at ?? at1830,
    data: {'exerciseId': exerciseId, 'unit': unit, 'changedOn': changedOn},
  );

  SyncMutation lift(String exerciseId, int start, int end, {DateTime? at}) {
    final log = LiftLog(
      date: monday,
      exerciseId: exerciseId,
      startKgX10: start,
      endKgX10: end,
    );
    return mutation(
      SyncEntities.liftLog,
      log.key,
      SyncOp.upsert,
      at: at ?? at1830,
      data: const LiftLogCodec().encode(log),
    );
  }

  SyncMutation note(
    String exerciseId,
    String text, {
    DateTime? at,
    SyncOp op = SyncOp.upsert,
  }) {
    final n = ExerciseNote(date: monday, exerciseId: exerciseId, text: text);
    return mutation(
      SyncEntities.exerciseNote,
      n.key,
      op,
      at: at ?? at1830,
      data: op == SyncOp.delete ? null : const ExerciseNoteCodec().encode(n),
    );
  }

  Future<List<SyncChange>> pulled(String entity, {String? as}) async => [
    for (final c in (await app.pull(as ?? token)).changes)
      if (c.entity == entity) c,
  ];

  group('TAC3-03: mức tạ theo đơn vị của bài', () {
    test('bài chưa có đơn vị → lift_unit_missing; cùng batch có exercise_unit '
        'trước → applied (TD3-05)', () async {
      final missing = await push([lift(pecDeck, 80, 100)]);
      expect(
        (missing.single.status, missing.single.code),
        (PushStatus.rejected, ErrorCode.liftUnitMissing),
      );
      final ok = await push([unit(pecDeck, 'steps'), lift(pecDeck, 80, 100)]);
      expect(
        [for (final r in ok) r.status],
        [PushStatus.applied, PushStatus.applied],
      );
      final log = (await pulled(SyncEntities.liftLog)).single;
      expect((log.data!['startKgX10'], log.data!['endKgX10']), (80, 100));
    });

    test('nấc 8 → 80 lưu được; 85 (8,5 nấc), 510 (51 nấc) → '
        'validation_failed; kg 72,5 → 725 lưu được', () async {
      await push([unit(pecDeck, 'steps'), unit(bench, 'kg')]);
      for (final (start, end, status) in [
        (80, 80, PushStatus.applied),
        (80, 85, PushStatus.rejected),
        (80, 510, PushStatus.rejected),
      ]) {
        final r = (await push([lift(pecDeck, start, end)])).single;
        expect(r.status, status, reason: '$start → $end');
        if (status == PushStatus.rejected) {
          expect((r.code, r.field), (ErrorCode.validationFailed, 'endKgX10'));
        }
      }
      expect(
        (await push([lift(bench, 700, 725)])).single.status,
        PushStatus.applied,
      );
    });

    test('đổi đơn vị không kiểm tra lại bản ghi cũ; giá trị mới gửi lên theo '
        'đơn vị mới (F21-R47)', () async {
      await push([unit(bench, 'kg'), lift(bench, 700, 725)]);
      final later = at1830.add(const Duration(minutes: 5));
      expect(
        (await push([unit(bench, 'steps', at: later)])).single.status,
        PushStatus.applied,
      );
      final log = (await pulled(SyncEntities.liftLog)).single;
      expect(log.data!['endKgX10'], 725, reason: 'giữ con số, không quy đổi');
      final edit = (await push([
        lift(bench, 700, 735, at: later.add(const Duration(minutes: 1))),
      ])).single;
      expect((edit.status, edit.field), (PushStatus.rejected, 'startKgX10'));
      expect(
        (await push([
          lift(bench, 70, 80, at: later.add(const Duration(minutes: 2))),
        ])).single.status,
        PushStatus.applied,
      );
    });

    test('exercise_unit: bài bụng, bài không có, đơn vị lạ → '
        'validation_failed', () async {
      final results = await push([
        unit(plank, 'kg'),
        unit('no-such-exercise', 'kg'),
        unit(pecDeck, 'plates'),
      ]);
      expect(
        [for (final r in results) (r.status, r.code, r.field)],
        [
          (PushStatus.rejected, ErrorCode.validationFailed, 'exerciseId'),
          (PushStatus.rejected, ErrorCode.validationFailed, 'exerciseId'),
          (PushStatus.rejected, ErrorCode.validationFailed, 'unit'),
        ],
      );
    });

    test('hai máy đổi đơn vị cùng bài: bản mới hơn thắng, bản cũ đến sau → '
        'ignored_stale; đổi đơn vị không cần cửa sổ ghi tạ (FA3-04)', () async {
      // 10:00 thứ 3 13/10: ngoài mọi cửa sổ ghi tạ.
      final tuesday = DateTime.utc(2026, 10, 13, 3);
      app.clock.set(tuesday);
      token = await login('0912345678');
      final results = await push([
        unit(pecDeck, 'steps', at: tuesday, changedOn: '2026-10-13'),
        unit(
          pecDeck,
          'kg',
          at: tuesday.subtract(const Duration(minutes: 3)),
          changedOn: '2026-10-13',
        ),
      ]);
      expect(
        [for (final r in results) r.status],
        [PushStatus.applied, PushStatus.ignoredStale],
      );
      final u = (await pulled(SyncEntities.exerciseUnit)).single;
      expect((u.data!['unit'], u.data!['changedOn']), ('steps', '2026-10-13'));
    });
  });

  group('TAC3-06: ghi chú', () {
    test('201 ký tự → validation_failed; 200 ký tự có dấu → applied', () async {
      final tooLong = (await push([note(pecDeck, 'a' * 201)])).single;
      expect((tooLong.status, tooLong.field), (PushStatus.rejected, 'text'));
      // 200 chữ tiếng Việt có dấu (mỗi chữ một ký tự dựng sẵn như bàn phím
      // iPhone gõ ra).
      expect(
        (await push([note(pecDeck, 'ể' * 200)])).single.status,
        PushStatus.applied,
      );
    });

    test('chỉ khoảng trắng → coi như xóa; op delete → tombstone; nội dung '
        'được trim', () async {
      await push([note(pecDeck, '  máy 2 hỏng, tập máy 5 ')]);
      expect(
        (await pulled(SyncEntities.exerciseNote)).single.data!['text'],
        'máy 2 hỏng, tập máy 5',
      );
      final blank = (await push([
        note(pecDeck, '   ', at: at1830.add(const Duration(minutes: 1))),
      ])).single;
      expect(blank.status, PushStatus.applied);
      expect((await pulled(SyncEntities.exerciseNote)).single.deleted, isTrue);
      // Chỉ khoảng trắng cho bài chưa có ghi chú: không tạo gì.
      expect(
        (await push([note(bench, ' ')])).single.status,
        PushStatus.applied,
      );
      expect(await pulled(SyncEntities.exerciseNote), hasLength(1));

      await push([
        note(bench, 'ghế 3', at: at1830.add(const Duration(minutes: 2))),
      ]);
      final deleted = (await push([
        note(
          bench,
          '',
          op: SyncOp.delete,
          at: at1830.add(const Duration(minutes: 3)),
        ),
      ])).single;
      expect(deleted.status, PushStatus.applied);
      expect(
        (await pulled(SyncEntities.exerciseNote)).every((c) => c.deleted),
        isTrue,
      );
    });

    test('00:01 → lift_window_closed; bài bụng trong buổi có Bụng → applied '
        '(không xét logsWeight); bài khác nhóm → '
        'lift_exercise_not_in_session; ngày không có buổi → '
        'lift_no_session', () async {
      expect(
        (await push([note(plank, 'thở đều')])).single.status,
        PushStatus.applied,
      );
      final other = (await push([note(lats, 'x')])).single;
      expect(other.code, ErrorCode.liftExerciseNotInSession);
      final tuesdayNote = ExerciseNote(
        date: LocalDate(2026, 10, 13),
        exerciseId: pecDeck,
        text: 'x',
      );
      final noSession = (await push([
        mutation(
          SyncEntities.exerciseNote,
          tuesdayNote.key,
          SyncOp.upsert,
          at: at1830,
          data: const ExerciseNoteCodec().encode(tuesdayNote),
        ),
      ])).single;
      expect(noSession.code, ErrorCode.liftNoSession);

      // 00:01 thứ 3 13/10 giờ Việt Nam.
      final after = DateTime.utc(2026, 10, 12, 17, 1);
      app.clock.set(after);
      token = await login('0912345678');
      final closed = (await push([note(pecDeck, 'muộn', at: after)])).single;
      expect(closed.code, ErrorCode.liftWindowClosed);
    });
  });

  test('TAC3-13: B không đọc, không ghi, không xóa được đơn vị, ghi chú của '
      'A', () async {
    await push([
      unit(pecDeck, 'steps'),
      lift(pecDeck, 80, 100),
      note(pecDeck, 'của A'),
    ]);
    await app.register(phone: '0922222222', name: 'Bình');
    final b = await login('0922222222');
    expect(await pulled(SyncEntities.exerciseUnit, as: b), isEmpty);
    expect(await pulled(SyncEntities.exerciseNote, as: b), isEmpty);
    // B đổi đơn vị cùng bài: chỉ là đơn vị của B.
    await push([
      unit(pecDeck, 'kg', at: at1830.add(const Duration(minutes: 1))),
    ], as: b);
    // B chưa có buổi ngày đó: không ghi, không xóa được ghi chú.
    final results = await push([
      note(pecDeck, 'của B', at: at1830.add(const Duration(minutes: 1))),
      note(
        pecDeck,
        '',
        op: SyncOp.delete,
        at: at1830.add(const Duration(minutes: 2)),
      ),
    ], as: b);
    expect(results.first.code, ErrorCode.liftNoSession);
    final mine = await pulled(SyncEntities.exerciseUnit);
    expect(mine.single.data!['unit'], 'steps');
    final myNote = (await pulled(SyncEntities.exerciseNote)).single;
    expect((myNote.deleted, myNote.data?['text']), (false, 'của A'));
    expect(
      (await pulled(SyncEntities.exerciseUnit, as: b)).single.data!['unit'],
      'kg',
    );
  });
}

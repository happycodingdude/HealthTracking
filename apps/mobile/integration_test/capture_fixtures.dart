// Dữ liệu dựng màn cho bộ ảnh so sánh (06 Bản 4 ED4-04, `todayFiveStates`):
// trong bộ nhớ, không cần server; tên bài theo mock 04 Bản 4.
import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/features/schedule/data/schedule_pause_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/features/workout/data/exercise_feel_repository.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/data/session_exercise_repository.dart';

import '../test/support/menu_fixture.dart';
import '../test/support/schedule_fixture.dart';

Exercise _ex(String id, MuscleRegion region, String name, int sort) => Exercise(
  id: id,
  region: region,
  nameVi: name,
  youtubeVideoId: 'dQw4w9WgXcQ',
  videoChannel: 'demo',
  videoDurationS: 48,
  guideSteps: const [
    'Ngồi thẳng lưng, tay cầm ngang ngực.',
    'Đẩy hai tay ra trước đến khi gần thẳng, siết ngực, trở về chậm.',
  ],
  guideSafety: const ['Không khóa khuỷu tay.'],
  approvedAt: LocalDate(2026, 10, 1),
  sortInGroup: sort,
  sortOrder: sort,
);

/// Thư viện rút gọn theo tên bài trên mock.
List<Exercise> captureLibrary() => [
  _ex('chest-1', MuscleRegion.chestMid, 'Nằm đẩy thanh đòn', 1),
  _ex('chest-2', MuscleRegion.chestMid, 'Ngồi máy ép ngực', 2),
  _ex('chest-3', MuscleRegion.chestUpper, 'Ghế dốc lên có trợ lực', 3),
  _ex('chest-4', MuscleRegion.chestLower, 'Bay ngực với cáp', 4),
  _ex('chest-5', MuscleRegion.chestMid, 'Hít xà đẩy ngực', 5),
  _ex('back-1', MuscleRegion.lats, 'Kéo xà đơn', 1),
  _ex('back-2', MuscleRegion.backMid, 'Ngồi kéo cáp', 2),
  _ex('abs-1', MuscleRegion.absMid, 'Gập bụng', 1),
  _ex('abs-2', MuscleRegion.absMid, 'Plank', 2),
  _ex('abs-3', MuscleRegion.absLower, 'Treo nâng chân', 3),
  _ex('shoulders-1', MuscleRegion.deltSide, 'Bay vai ngang với cáp', 1),
  _ex('legs-1', MuscleRegion.calves, 'Đứng máy nhón gót', 1),
];

/// Lịch tuần của mock: T2 Ngực, T3 Lưng + Bụng, T5 Vai, T7 Tay trước, 18:00.
final captureTemplate = WeeklyTemplate({
  1: TemplateDay(
    enabled: true,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.chest],
  ),
  2: TemplateDay(
    enabled: true,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.back, MuscleGroup.abs],
  ),
  4: TemplateDay(
    enabled: true,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.shoulders],
  ),
  6: TemplateDay(
    enabled: true,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.biceps],
  ),
});

/// Thứ 2 26/10/2026 là ngày của mock ("Thứ 2, 26/10").
final captureMonday = LocalDate(2026, 10, 26);

/// Dựng dữ liệu: hồ sơ, lịch tháng 10 (thiết lập 05/10), thực đơn hôm nay,
/// thư viện, mức tạ buổi trước và vài bản ghi hôm nay.
Future<List<Exercise>> seedCapture(
  AppDatabase db, {
  LocalDate? today,
  bool withMenu = true,
  bool todayLogs = true,
}) async {
  await seedSetUp(db, template: captureTemplate);
  final repo = ExerciseRepository(db);
  final library = captureLibrary();
  for (final e in library) {
    await repo.put(e);
  }
  final units = ExerciseUnitRepository(db);
  final logs = LiftLogRepository(db);
  final notes = ExerciseNoteRepository(db);
  final prev = LocalDate(2026, 10, 19);
  Future<void> put(String id, LiftUnit u, int s, int e) async {
    await units.put(ExerciseUnit(exerciseId: id, unit: u, changedOn: prev));
    await logs.put(
      LiftLog(date: prev, exerciseId: id, startKgX10: s, endKgX10: e),
    );
  }

  await put('chest-1', LiftUnit.kg, 400, 475);
  await put('chest-2', LiftUnit.steps, 80, 100);
  await put('chest-3', LiftUnit.kg, 300, 350);
  await put('chest-5', LiftUnit.kg, 600, 650);
  await put('back-1', LiftUnit.kg, 600, 650);
  await notes.put(
    ExerciseNote(date: prev, exerciseId: 'abs-1', text: '3 hiệp 20 cái'),
  );
  await notes.put(
    ExerciseNote(date: prev, exerciseId: 'chest-2', text: 'ghế để nấc 3'),
  );
  final day = today ?? captureMonday;
  if (todayLogs) {
    await logs.put(
      LiftLog(date: day, exerciseId: 'chest-1', startKgX10: 400, endKgX10: 500),
    );
    await logs.put(
      LiftLog(date: day, exerciseId: 'chest-2', startKgX10: 80, endKgX10: 100),
    );
    await notes.put(
      ExerciseNote(date: day, exerciseId: 'chest-2', text: 'Ghế nấc 3, vai ổn'),
    );
  }
  if (withMenu) {
    await MenuRepository(db).put(day, readyMenu(targetKcal: 1850));
  }
  return library;
}

/// Cân nặng của mock S-40: thiết lập 31/08, 8 tuần, tuần 05/10 không ghi
/// (đường ngắt), mới nhất 19/10 = 72,4.
Future<void> seedWeights(AppDatabase db) async {
  final profiles = ProfileRepository(db);
  final p = (await profiles.get())!;
  await profiles.put(p.copyWith(setupDate: LocalDate(2026, 8, 31)));
  final weights = WeightRepository(db);
  await weights.delete(LocalDate(2026, 10, 5));
  for (final (m, d, kg) in [
    (8, 31, 750),
    (9, 7, 746),
    (9, 14, 742),
    (9, 21, 743),
    (9, 28, 734),
    (10, 12, 728),
    (10, 19, 724),
  ]) {
    await weights.put(LocalDate(2026, m, d), kg);
  }
}

/// Dữ liệu tab Tôi của mock (S-50 → S-56): đề xuất mức calo chờ 2.180, ngân
/// sách AI 12.500đ / 50.000đ, một mục chưa đồng bộ.
Future<void> seedMeCapture(AppDatabase db, Clock clock) async {
  final profiles = ProfileRepository(db);
  final p = (await profiles.get())!;
  await profiles.put(p.withPending(2180, CaloriePendingReason.weight));
  await (db.update(db.syncState)..where((s) => s.id.equals(1))).write(
    SyncStateCompanion(
      aiBudget: Value(
        jsonEncode(
          AiBudgetMeta(
            month: YearMonth(2026, 10),
            usedVnd: 12500,
            capVnd: 50000,
            blocked: false,
          ).toJson(),
        ),
      ),
    ),
  );
  await OutboxWriter(
    db,
    clock,
  ).enqueue('weight', '2026-10-26', SyncOp.upsert, {'kgX10': 724});
}

/// Thư viện của mock Bản 5 (s10-h4, s64, s74, s75, s63): buổi Ngực 4 bài.
List<Exercise> captureLibraryV5() => [
  _ex('chest-1', MuscleRegion.chestMid, 'Máy ép ngực', 1),
  _ex('chest-2', MuscleRegion.chestMid, 'Nằm ghế phẳng đẩy thanh đòn', 2),
  _ex('chest-3', MuscleRegion.chestUpper, 'Ngồi ghế dốc lên với tạ đơn', 3),
  _ex('chest-4', MuscleRegion.chestLower, 'Nằm ghế dốc xuống đẩy tạ đơn', 4),
  _ex('back-1', MuscleRegion.lats, 'Kéo xô rộng tay', 1),
  _ex('back-2', MuscleRegion.backMid, 'Ngồi kéo cáp về bụng', 2),
  _ex('back-3', MuscleRegion.backMid, 'Máy dốc gắn bánh tạ', 3),
  _ex('shoulders-1', MuscleRegion.deltSide, 'Bay vai ngang với cáp', 1),
  _ex('biceps-1', MuscleRegion.biceps, 'Cuốn tạ đơn', 1),
  _ex('triceps-1', MuscleRegion.tricepsLong, 'Kéo cáp qua đầu', 1),
  _ex('abs-1', MuscleRegion.absMid, 'Plank', 1),
  _ex('legs-1', MuscleRegion.quads, 'Nằm máy đạp chân', 1),
];

/// Buổi Ngực thứ 2 26/10/2026 18:00 có đủ 5 loại dòng (mock s10-h4, 06 Bản 5
/// VS-55 bộ ảnh M24): bài 1 đã ghi 40 → 45 · Vừa + ghi chú; bài 2 đổi sang
/// "Máy dốc gắn bánh tạ"; bài 3 bỏ qua; bài 4 buổi trước 22,5 → 25 ·
/// Thoải mái (ghi chú buổi trước); Plank thêm cuối (ghi chú buổi trước).
/// [rows] = false: chưa đổi / bỏ / thêm bài.
Future<List<Exercise>> seedCaptureV5(AppDatabase db, {bool rows = true}) async {
  await seedSetUp(db, template: captureTemplate);
  final library = captureLibraryV5();
  final repo = ExerciseRepository(db);
  for (final e in library) {
    await repo.put(e);
  }
  final units = ExerciseUnitRepository(db);
  final logs = LiftLogRepository(db);
  final notes = ExerciseNoteRepository(db);
  final feels = ExerciseFeelRepository(db);
  final prev = LocalDate(2026, 10, 19);
  final day = captureMonday;
  for (final (id, s, e) in [('chest-1', 400, 450), ('chest-4', 225, 250)]) {
    await units.put(
      ExerciseUnit(exerciseId: id, unit: LiftUnit.kg, changedOn: prev),
    );
    await logs.put(
      LiftLog(date: prev, exerciseId: id, startKgX10: s, endKgX10: e),
    );
  }
  await feels.put(
    ExerciseFeel(date: prev, exerciseId: 'chest-4', feel: Feel.easy),
  );
  await notes.put(
    ExerciseNote(date: prev, exerciseId: 'chest-4', text: 'tay trái hơi yếu'),
  );
  await notes.put(
    ExerciseNote(date: prev, exerciseId: 'abs-1', text: '60 giây'),
  );
  await logs.put(
    LiftLog(date: day, exerciseId: 'chest-1', startKgX10: 400, endKgX10: 450),
  );
  await feels.put(
    ExerciseFeel(date: day, exerciseId: 'chest-1', feel: Feel.medium),
  );
  await notes.put(
    ExerciseNote(date: day, exerciseId: 'chest-1', text: 'Ghế nấc 3, vai ổn'),
  );
  if (rows) {
    final session = SessionExerciseRepository(db);
    await session.put(
      SessionExerciseRow(
        date: day,
        exerciseId: 'back-3',
        role: SessionExerciseRole.replacement,
        replacesExerciseId: 'chest-2',
        position: 1,
      ),
    );
    await session.put(
      SessionExerciseRow(
        date: day,
        exerciseId: 'chest-3',
        role: SessionExerciseRole.original,
        position: 2,
        skipped: true,
      ),
    );
    await session.put(
      SessionExerciseRow(
        date: day,
        exerciseId: 'abs-1',
        role: SessionExerciseRole.extra,
        position: 4,
      ),
    );
  }
  await MenuRepository(db).put(day, readyMenu(targetKcal: 1850));
  return library;
}

/// Lịch của mock Bản 5 mốc M25 (s20, s25, s10-h7, s10-h8, s76, s21): T2 Ngực
/// + Tay sau, T3 Ngực, T4 Lưng, T6 Vai, 18:00.
final captureTemplateM25 = WeeklyTemplate({
  1: TemplateDay(
    enabled: true,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
  ),
  2: TemplateDay(
    enabled: true,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.chest],
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

/// Tuần của mock M25: thứ 2 02/11/2026.
final captureMondayM25 = LocalDate(2026, 11, 2);

/// Dựng dữ liệu M25 (06 Bản 5 VS-57, bộ ảnh M25): lịch tháng 10 + 11, T2
/// 02/11 và T3 03/11 đã tập, tạm dừng T4 04/11 → CN 08/11 ([paused]; mock
/// ghi "CN 09/11" nhưng 09/11/2026 là thứ 2 — lấy chủ nhật của tuần); buổi
/// Lưng 4 bài theo mock s10-h7 (buổi trước T4 28/10: 50 → 55 kg · Vừa, 8 →
/// 10 nấc · Mệt, 20 → 25 kg).
Future<void> seedCaptureM25(AppDatabase db, {bool paused = true}) async {
  await seedSetUp(
    db,
    template: captureTemplateM25,
    extraMonths: [YearMonth(2026, 11)],
  );
  final repo = ExerciseRepository(db);
  for (final e in [
    ...captureLibraryV5(),
    _ex('back-4', MuscleRegion.backLower, 'Đứng kéo thanh đòn gập hông', 4),
  ]) {
    await repo.put(e);
  }
  final units = ExerciseUnitRepository(db);
  final logs = LiftLogRepository(db);
  final feels = ExerciseFeelRepository(db);
  final prev = LocalDate(2026, 10, 28);
  for (final (id, unit, s, e, feel) in [
    ('back-1', LiftUnit.kg, 500, 550, Feel.medium),
    ('back-2', LiftUnit.steps, 80, 100, Feel.hard),
    ('back-3', LiftUnit.kg, 200, 250, null),
  ]) {
    await units.put(ExerciseUnit(exerciseId: id, unit: unit, changedOn: prev));
    await logs.put(
      LiftLog(date: prev, exerciseId: id, startKgX10: s, endKgX10: e),
    );
    if (feel != null) {
      await feels.put(ExerciseFeel(date: prev, exerciseId: id, feel: feel));
    }
  }
  for (final d in [captureMondayM25, captureMondayM25.addDays(1)]) {
    await seedMark(db, d, DayMark.done);
  }
  if (paused) {
    await SchedulePauseRepository(db).put(
      SchedulePause(
        id: '6f1d2c3b-0000-4000-8000-0000000000d5',
        startDate: captureMondayM25.addDays(2),
        endDate: captureMondayM25.addDays(6),
      ),
    );
  }
  await MenuRepository(
    db,
  ).put(captureMondayM25.addDays(2), readyMenu(targetKcal: 1850));
}

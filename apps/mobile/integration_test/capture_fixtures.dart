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
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';

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

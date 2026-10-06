import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/local_marks.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/me/application/calorie_updates.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/weight/application/weight_edits.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late MemoryLocalMarks marks;
  late ProfileRepository profiles;
  late CalorieUpdates calorie;
  late WeightEdits weights;

  // seedSetUp: nam, 1996, 175 cm, vận động vừa, 80 kg, Tự động 2.210 kcal.
  final w1210 = LocalDate(2026, 10, 12);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    clock = FixedClock(DateTime(2026, 10, 14, 9));
    marks = MemoryLocalMarks();
    profiles = ProfileRepository(db);
    final outbox = OutboxWriter(db, clock);
    calorie = CalorieUpdates(
      db: db,
      profiles: profiles,
      weights: WeightRepository(db),
      outbox: outbox,
      marks: marks,
      clock: clock,
    );
    weights = WeightEdits(
      db: db,
      weights: WeightRepository(db),
      profiles: profiles,
      outbox: outbox,
      calorie: calorie,
      clock: clock,
    );
  });

  int estimate(Profile p, int kgX10, {int year = 2026}) =>
      CalorieRules.forProfile(p, weightKgX10: kgX10, currentYear: year)!.kcal;

  Future<Profile> profile() async => (await profiles.get())!;

  Future<void> manual(int kcal) async => profiles.put(
    (await profile()).copyWith(
      calorieMode: CalorieMode.manual,
      calorieKcal: kcal,
    ),
  );

  test('F02-AC4, F07-AC6: Tự động, ghi cân mới → mức calo cập nhật ngay, có '
      'kết quả để báo F02-R8', () async {
    await seedSetUp(db);
    final change = await weights.log(w1210, 725);
    final to = estimate(await profile(), 725);
    expect(to, 2090);
    final outcome = change.calorie as CalorieAutoUpdated;
    expect((outcome.from, outcome.to), (2210, 2090));
    expect((await profile()).calorieKcal, 2090);
  });

  test(
    'F02-AC5: Bạn tự đặt, ghi cân mới → đề xuất; Giữ nguyên → con số không '
    'đổi, hết đề xuất; ghi cân lần nữa → đề xuất lại; Đồng ý → Tự động',
    () async {
      await seedSetUp(db);
      await manual(1900);
      final first = await weights.log(w1210, 725);
      final proposed = first.calorie as CalorieProposed;
      expect((proposed.kcal, proposed.current), (2090, 1900));
      var p = await profile();
      expect(
        (p.caloriePendingKcal, p.caloriePendingReason),
        (2090, CaloriePendingReason.weight),
      );

      await calorie.keepManual();
      p = await profile();
      expect((p.calorieMode, p.calorieKcal), (CalorieMode.manual, 1900));
      expect(p.caloriePendingKcal, isNull);

      final again = await weights.log(w1210, 715);
      expect(again.calorie, isA<CalorieProposed>());
      await calorie.acceptProposal();
      p = await profile();
      expect(
        (p.calorieMode, p.calorieKcal, p.caloriePendingKcal),
        (CalorieMode.auto, estimate(p, 715), null),
      );
    },
  );

  test('F02-R10: số cân mới nhất đổi nhưng mức ước tính chênh dưới 10 kcal → '
      'không báo, không đề xuất', () async {
    await seedSetUp(db);
    await manual(1900);
    final change = await weights.log(w1210, 801);
    expect(change.latestChanged, isTrue);
    expect(change.calorie, isA<CalorieUnchanged>());
    expect((await profile()).caloriePendingKcal, isNull);
  });

  test('F02-AC6: "Dùng lại ước tính của app" → Tự động với mức ước tính hiện '
      'tại', () async {
    await seedSetUp(db);
    await manual(1900);
    await calorie.useAppEstimate();
    final p = await profile();
    expect((p.calorieMode, p.calorieKcal), (CalorieMode.auto, 2210));
  });

  test('F01-AC5, F01-R5: đổi mức vận động và lưu → Tự động cập nhật; Bạn tự '
      'đặt → đề xuất với lý do "hồ sơ"', () async {
    await seedSetUp(db);
    final auto = await calorie.updateProfile(
      heightCm: 175,
      birthYear: 1996,
      sex: Sex.male,
      activityLevel: ActivityLevel.active,
    );
    expect(auto, isA<CalorieAutoUpdated>());
    expect((await profile()).activityLevel, ActivityLevel.active);

    await manual(1900);
    final proposed = await calorie.updateProfile(
      heightCm: 175,
      birthYear: 1996,
      sex: Sex.male,
      activityLevel: ActivityLevel.light,
    );
    expect((proposed as CalorieProposed).reason, CaloriePendingReason.profile);
  });

  test('F01-E2, ED-07: 31/12 → 01/01 tuổi tăng 1 → tính lại một lần; lần đầu '
      'chỉ lưu mốc năm', () async {
    await seedSetUp(db);
    clock.set(DateTime(2026, 12, 31, 23));
    expect(await calorie.checkNewYear(), isA<CalorieUnchanged>());
    expect(await marks.lastAgeYear(), 2026);

    clock.set(DateTime(2027, 1, 1, 0, 1));
    final outcome = await calorie.checkNewYear();
    expect(outcome, isA<CalorieAutoUpdated>());
    expect((await profile()).calorieKcal, 2200);
    expect(await marks.lastAgeYear(), 2027);
    expect(await calorie.checkNewYear(), isA<CalorieUnchanged>());
  });
}

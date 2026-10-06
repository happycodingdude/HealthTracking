import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/local_marks.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../weight/data/weight_repository.dart';
import '../data/profile_repository.dart';

/// Ảnh chụp các đầu vào của mức ước tính trước một sự kiện F02-R7.
typedef CalorieInputs = ({Profile? profile, int? weightKgX10, int year});

/// Mức calo sau thiết lập (F-02, VS-11): tính lại khi số cân mới nhất, hồ sơ
/// hoặc năm đổi (F02-R7 → R10); chọn ở đề xuất; đặt mức khác; dùng lại ước
/// tính của app. Ghi hồ sơ + outbox trong transaction (06 §6.4.2).
final class CalorieUpdates {
  CalorieUpdates({
    required AppDatabase db,
    required ProfileRepository profiles,
    required WeightRepository weights,
    required OutboxWriter outbox,
    required LocalMarks marks,
    required Clock clock,
  }) : _db = db,
       _profiles = profiles,
       _weights = weights,
       _outbox = outbox,
       _marks = marks,
       _clock = clock;

  final AppDatabase _db;
  final ProfileRepository _profiles;
  final WeightRepository _weights;
  final OutboxWriter _outbox;
  final LocalMarks _marks;
  final Clock _clock;

  static const _codec = ProfileCodec();

  /// Đầu vào hiện tại (gọi trước khi đổi cân nặng, hồ sơ).
  Future<CalorieInputs> snapshot() async => (
    profile: await _profiles.get(),
    weightKgX10: (await _weights.latest())?.kgX10,
    year: _clock.now().year,
  );

  static int? _estimate(CalorieInputs i) => i.profile == null
      ? null
      : CalorieRules.forProfile(
          i.profile!,
          weightKgX10: i.weightKgX10,
          currentYear: i.year,
        )?.kcal;

  Future<void> _put(Profile p) async {
    await _profiles.put(p);
    await _outbox.enqueue(
      SyncEntities.profile,
      ProfileCodec.key,
      SyncOp.upsert,
      _codec.encode(p),
    );
  }

  /// Tính lại sau sự kiện, so với đầu vào [before] (F02-R7). Chỉ khi đã thiết
  /// lập xong. Gọi trong transaction của người gọi nếu có.
  Future<CalorieOutcome> recalc(
    CalorieInputs before, {
    required CaloriePendingReason reason,
  }) async {
    final after = await snapshot();
    final profile = after.profile;
    if (profile == null || profile.onboardingCompletedAt == null) {
      return const CalorieUnchanged();
    }
    final r = CalorieRecalc.apply(
      profile: profile,
      before: _estimate(before),
      after: _estimate(after),
      reason: reason,
    );
    final next = r.profile;
    if (next != null) await _put(next);
    return r.outcome;
  }

  /// S-51 (F01-R5): lưu chiều cao, năm sinh, giới tính, mức vận động rồi tính
  /// lại mức calo.
  Future<CalorieOutcome> updateProfile({
    required int heightCm,
    required int birthYear,
    required Sex sex,
    required ActivityLevel activityLevel,
  }) => _db.transaction(() async {
    final before = await snapshot();
    await _put(
      before.profile!.copyWith(
        heightCm: heightCm,
        birthYear: birthYear,
        sex: sex,
        activityLevel: activityLevel,
      ),
    );
    return recalc(before, reason: CaloriePendingReason.profile);
  });

  /// F01-E2, ED-07: sang năm mới thì tính lại như một lần sửa hồ sơ. Chạy khi
  /// khởi động, quay lại foreground, qua 00:00.
  Future<CalorieOutcome> checkNewYear() async {
    final year = _clock.now().year;
    final last = await _marks.lastAgeYear();
    if (last == year) return const CalorieUnchanged();
    final outcome = last == null || last > year
        ? const CalorieUnchanged()
        : await _db.transaction(() async {
            final now = await snapshot();
            return recalc((
              profile: now.profile,
              weightKgX10: now.weightKgX10,
              year: last,
            ), reason: CaloriePendingReason.profile);
          });
    await _marks.setLastAgeYear(year);
    return outcome;
  }

  /// "Dùng {Y} kcal" (F02-R9 đồng ý): về Tự động với mức đề xuất.
  Future<void> acceptProposal() => _db.transaction(() async {
    final p = (await _profiles.get())!;
    final kcal = p.caloriePendingKcal;
    if (kcal == null) return;
    await _put(CalorieRecalc.useEstimate(p, kcal));
  });

  /// "Giữ nguyên" (F02-R9): vẫn Bạn tự đặt, bỏ đề xuất.
  Future<void> keepManual() => _db.transaction(() async {
    final p = (await _profiles.get())!;
    if (p.caloriePendingKcal == null) return;
    await _put(CalorieRecalc.keepManual(p));
  });

  /// "Dùng lại ước tính của app" (F02-AC6): về Tự động với mức ước tính hiện
  /// tại.
  Future<void> useAppEstimate() => _db.transaction(() async {
    final now = await snapshot();
    final kcal = _estimate(now);
    if (kcal == null) return;
    await _put(CalorieRecalc.useEstimate(now.profile!, kcal));
  });

  /// "Đặt mức khác" (F02-R4, F02-V1, F02-R5 đã hỏi ở bảng).
  Future<void> setManual(int kcal) => _db.transaction(() async {
    if (!CalorieRules.isValidManual(kcal)) return;
    final p = (await _profiles.get())!;
    await _put(CalorieRecalc.setManual(p, kcal));
  });
}

final localMarksProvider = Provider<LocalMarks>((ref) => SecureLocalMarks());

final calorieUpdatesProvider = Provider<CalorieUpdates>(
  (ref) => CalorieUpdates(
    db: ref.watch(databaseProvider),
    profiles: ref.watch(profileRepositoryProvider),
    weights: ref.watch(weightRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    marks: ref.watch(localMarksProvider),
    clock: ref.watch(clockProvider),
  ),
);

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/sync/sync_providers.dart';
import '../../weight/data/weight_repository.dart';

/// Nội dung thẻ mức calo (S-04, S-52).
final class CalorieView {
  const CalorieView({
    required this.mode,
    required this.kcal,
    required this.estimate,
    required this.sex,
  });

  final CalorieMode mode;

  /// Mức calo của Bạn (con số lớn).
  final int kcal;

  /// Mức app ước tính lúc này (F02-R1).
  final CalorieEstimate estimate;
  final Sex sex;

  int get safetyFloor => CalorieRules.safetyFloor(sex);

  /// Nhãn "Dưới ngưỡng an toàn" (F02-R5).
  bool get belowSafetyFloor =>
      mode == CalorieMode.manual && CalorieRules.isBelowSafetyFloor(kcal, sex);

  /// "Thấp hơn mức duy trì khoảng {N} kcal"; null khi không thấp hơn.
  int? get belowMaintenance =>
      CalorieRules.belowMaintenance(estimate.maintenanceKcal, kcal);

  /// Ghi chú F02-E1/E2 chỉ áp dụng cho mức app ước tính.
  CalorieNote? get note => mode == CalorieMode.auto ? estimate.note : null;
}

final profileProvider = StreamProvider<Profile?>(
  (ref) => ref.watch(profileRepositoryProvider).watch(),
);

/// Số cân mới nhất (F07-R4).
final latestWeightProvider = StreamProvider<WeightEntry?>(
  (ref) => ref.watch(weightRepositoryProvider).watchLatest(),
);

/// null khi chưa đủ thông tin (bước 2 chưa xong) hoặc đang đọc.
final calorieViewProvider = Provider<CalorieView?>((ref) {
  final profile = ref.watch(profileProvider).value;
  final weight = ref.watch(latestWeightProvider).value;
  if (profile == null) return null;
  final estimate = CalorieRules.forProfile(
    profile,
    weightKgX10: weight?.kgX10,
    currentYear: ref.watch(clockProvider).now().year,
  );
  if (estimate == null) return null;
  final mode = profile.calorieMode ?? CalorieMode.auto;
  return CalorieView(
    mode: mode,
    kcal: mode == CalorieMode.manual ? profile.calorieKcal! : estimate.kcal,
    estimate: estimate,
    sex: profile.sex!,
  );
});

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/sync_providers.dart';

/// Đơn vị của mọi bài đã có đơn vị, theo `exerciseId` (05 Bản 3 §6.4.2, bảng
/// `exercise_units`). Đọc Drift, không chờ mạng.
final exerciseUnitsProvider = StreamProvider<Map<String, ExerciseUnit>>(
  (ref) => ref.watch(exerciseUnitRepositoryProvider).watchAll(),
);

/// `exerciseUnitProvider(exerciseId)`: đơn vị và ngày đổi gần nhất; null =
/// bài chưa từng ghi (F21-R41, F21-E50).
final exerciseUnitProvider = StreamProvider.family<ExerciseUnit?, String>(
  (ref, exerciseId) =>
      ref.watch(exerciseUnitRepositoryProvider).watch(exerciseId),
);

/// Đơn vị để hiện bản ghi đã có của bài [exerciseId]. Bài có bản ghi luôn có
/// đơn vị (lần ghi đầu tạo đơn vị; `library purge` tạo cho bài Bản 2,
/// F21-R41, TA3-04); khi đơn vị chưa về máy thì hiện kg như Bản 2.
LiftUnit displayUnit(Map<String, ExerciseUnit>? units, String exerciseId) =>
    units?[exerciseId]?.unit ?? LiftUnit.kg;

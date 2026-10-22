import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/sync_providers.dart';

/// Thư viện của một nhóm cơ (05 Bản 3 §6.4.2): danh sách phẳng theo thứ tự
/// thư viện (F18-R42, F18-R43, PD3-01), chỉ bài `active && !deleted`. Đọc từ
/// Drift, không chờ mạng (UR3-14).
final libraryProvider = StreamProvider.family<List<Exercise>, MuscleGroup>(
  (ref, group) => ref.watch(exerciseRepositoryProvider).watchGroup(group),
);

/// Một bài, kể cả bài đã rời thư viện (F19-E2), kèm trạng thái video.
final exerciseProvider = StreamProvider.family<Exercise?, String>(
  (ref, id) => ref.watch(exerciseRepositoryProvider).watch(id),
);

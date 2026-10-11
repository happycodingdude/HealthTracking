import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/sync_providers.dart';

/// Một vùng cơ và các bài của vùng, máy trước tạ sau (F18-R9).
typedef LibraryRegion = ({MuscleRegion region, List<Exercise> exercises});

/// Thư viện của một nhóm cơ (05 Bản 2 §6.4.2): vùng → bài, chỉ bài đang có
/// (`active`). Đọc từ Drift, không chờ mạng (UR2-10). Vùng chưa có bài nào
/// (chưa đồng bộ) không xuất hiện.
final libraryProvider = StreamProvider.family<List<LibraryRegion>, MuscleGroup>(
  (ref, group) => ref
      .watch(exerciseRepositoryProvider)
      .watchGroup(group)
      .map(
        (all) => [
          for (final region in MuscleRegion.of(group))
            if (all.where((e) => e.region == region).toList() case final list
                when list.isNotEmpty)
              (region: region, exercises: list),
        ],
      ),
);

/// Một bài, kể cả bài đã rời thư viện (F19-E2), kèm trạng thái video.
final exerciseProvider = StreamProvider.family<Exercise?, String>(
  (ref, id) => ref.watch(exerciseRepositoryProvider).watch(id),
);

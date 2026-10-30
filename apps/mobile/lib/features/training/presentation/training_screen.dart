import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components/components.dart';
import '../../library/presentation/library_screen.dart';
import '../../progress/presentation/progress_screen.dart';
import '../../schedule/presentation/schedule_screen.dart';
import '../application/training_section.dart';

/// Tab Tập luyện (04 Bản 2 §6.3.2, UD2-01): 3 mục Lịch | Bài tập | Tiến bộ
/// trong `IndexedStack` để giữ vị trí cuộn của từng mục (05 Bản 2 §6.4.7).
class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(trainingTabProvider);
    return IndexedStack(
      index: section.index,
      children: const [ScheduleScreen(), LibraryScreen(), ProgressScreen()],
    );
  }
}

/// Thanh chọn mục ở đầu mỗi mục của tab Tập luyện (04 Bản 4 S-20: thanh nền
/// thẻ bo 10, mục chọn nổi bo 8).
class TrainingSectionBar extends ConsumerWidget {
  const TrainingSectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentBar<TrainingSection>(
      items: TrainingSection.values,
      selected: ref.watch(trainingTabProvider),
      label: (s) => s.label,
      keyOf: (s) => ValueKey('section-${s.name}'),
      onSelected: ref.read(trainingTabProvider.notifier).select,
    );
  }
}

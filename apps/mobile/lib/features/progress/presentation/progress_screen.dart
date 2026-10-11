import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/shell/tab_scroll.dart';
import '../../../app/strings_vi.dart';
import '../../../core/widgets/empty_card.dart';
import '../../../core/widgets/tab_page.dart';
import '../../training/application/training_section.dart';
import '../../training/presentation/training_screen.dart';

/// S-68 — Tiến bộ mức tạ (mục Tiến bộ của tab Tập luyện). Đến VS-28 mới có
/// danh sách; trước đó chưa có bản ghi mức tạ nào nên luôn ở trạng thái trống
/// đúng câu F23-R4, không có nút (06 Bản 2 ED2-15, UX-AC41).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TabPage(
      tab: AppTab.schedule,
      title: S.tabTraining,
      scrollController: ref
          .watch(tabScrollControllersProvider)
          .section(TrainingSection.progress),
      children: const [
        TrainingSectionBar(),
        // Thẻ trống nằm thấp như mock S-68-2.
        SizedBox(height: 120),
        EmptyCard(
          key: ValueKey('progress-empty'),
          title: S.progressEmptyTitle,
          body: S.progressEmptyBody,
        ),
      ],
    );
  }
}

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/shell/tab_scroll.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/empty_card.dart';
import '../../../core/widgets/tab_page.dart';
import '../../training/application/training_section.dart';
import '../../training/presentation/training_screen.dart';
import '../../workout/application/lift_unit.dart';
import '../application/progress_providers.dart';
import 'lift_chart_screen.dart';

/// S-68 — Tiến bộ mức tạ (mục Tiến bộ của tab Tập luyện, 04 Bản 2 S-68,
/// F-23): mỗi bài đã ghi một dòng với mức tạ và ngày của bản ghi gần nhất,
/// mới nhất lên đầu (F23-R2); chạm → S-69. Chưa ghi bài nào (kể cả chưa có
/// lịch) → câu F23-R4, không có nút (UX-AC41). Chỉ con số: không xếp hạng,
/// không mũi tên tăng giảm, không màu xanh đỏ (F23-R7, P9).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(progressListProvider);
    final units = ref.watch(exerciseUnitsProvider).value;
    final palette = context.palette;
    return TabPage(
      tab: AppTab.schedule,
      title: S.tabTraining,
      scrollController: ref
          .watch(tabScrollControllersProvider)
          .section(TrainingSection.progress),
      children: [
        const TrainingSectionBar(),
        if (items == null)
          const SizedBox.shrink()
        else if (items.isEmpty) ...[
          // Thẻ trống nằm thấp như mock S-68-2.
          const SizedBox(height: 120),
          const EmptyCard(
            key: ValueKey('progress-empty'),
            title: S.progressEmptyTitle,
            body: S.progressEmptyBody,
          ),
        ] else ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              S.progressHint,
              style: context.text.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            key: const ValueKey('progress-list'),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _ProgressRow(
                    item: item,
                    unit: displayUnit(units, item.exercise.id),
                    onTap: () => context.push(liftChartPath(item.exercise.id)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Một dòng: tên bài · "{Nhóm cơ} · {Vùng cơ}" · "{a} → {b} kg" (bài máy:
/// "thanh"; đậm) và ngày bản ghi gần nhất · ›. Bài đã rời thư viện có ghi chú
/// nhỏ (F23-R5).
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.item,
    required this.unit,
    required this.onTap,
  });

  final ProgressItem item;
  final LiftUnit unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = item.exercise;
    final palette = context.palette;
    final secondary = context.text.bodyMedium?.copyWith(
      color: palette.textSecondary,
    );
    final value = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          Fmt.lift(item.latest, unit),
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(Fmt.dayMonth(item.latest.date), style: secondary),
      ],
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.nameVi, style: context.text.bodyLarge),
        const SizedBox(height: 2),
        Text(
          '${Fmt.muscle(e.group)} · ${Fmt.region(e.region)}',
          style: secondary,
        ),
        if (!e.active) ...[
          const SizedBox(height: 2),
          Text(
            S.notInLibrary,
            key: ValueKey('progress-not-in-library-${e.id}'),
            style: context.text.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ],
    );
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return InkWell(
      key: ValueKey('progress-${e.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        info,
                        const SizedBox(height: 6),
                        Align(alignment: Alignment.centerLeft, child: value),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: info),
                        const SizedBox(width: 12),
                        value,
                      ],
                    ),
            ),
            const SizedBox(width: 4),
            ExcludeSemantics(
              child: Icon(Icons.chevron_right, color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

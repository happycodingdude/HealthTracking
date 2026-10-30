import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/shell/tab_scroll.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../library/presentation/body_map.dart';
import '../../training/application/training_section.dart';
import '../../training/presentation/training_screen.dart';
import '../../workout/application/lift_unit.dart';
import '../application/progress_providers.dart';
import 'lift_chart_screen.dart';

/// S-68 — Tiến bộ mức tạ (mục Tiến bộ của tab Tập luyện, 04 Bản 4 S-68,
/// F-23): thẻ danh sách, mỗi bài đã ghi một dòng: icon tròn vùng cơ · tên
/// bài · "Ngực · 26/10" chữ phụ · mức gần nhất "40 → 50" phải trắng 600 (kèm
/// "nấc"); bài tập gần nhất lên đầu (F23-R2); chạm → S-69. Bài đã rời thư
/// viện: icon mờ + ổ khóa sau ngày (F23-R5). Trống: chỉ icon, không câu
/// (F4-R7). Chỉ con số (F23-R7, P9).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(progressListProvider);
    final units = ref.watch(exerciseUnitsProvider).value;
    return IronlyTabPage(
      tab: AppTab.schedule,
      title: S.tabTraining,
      scrollController: ref
          .watch(tabScrollControllersProvider)
          .section(TrainingSection.progress),
      children: [
        const TrainingSectionBar(),
        const SizedBox(height: TokenSpace.s4),
        if (items == null)
          const SizedBox.shrink()
        else if (items.isEmpty)
          const EmptyAction(
            key: ValueKey('progress-empty'),
            icon: Icons.show_chart,
          )
        else
          IronlyListCard(
            key: const ValueKey('progress-list'),
            children: [
              for (final item in items)
                _ProgressRow(
                  item: item,
                  unit: displayUnit(units, item.exercise.id),
                  onTap: () => context.push(liftChartPath(item.exercise.id)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Một dòng: icon tròn vùng cơ · tên bài · "{Nhóm cơ} · {dd/mm}" (+ ổ khóa
/// khi bài đã rời thư viện) · "{a} → {b}" (+ "nấc").
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
    final t = context.tokens;
    final e = item.exercise;
    final l = item.latest;
    final value =
        '${Fmt.kgNumber(l.startKgX10)} → ${Fmt.kgNumber(l.endKgX10)}'
        '${unit == LiftUnit.steps ? ' ${S.unitSteps}' : ''}';
    final semantics = [
      e.nameVi,
      '${Fmt.muscle(e.group)} · ${Fmt.dayMonth(l.date)}',
      Fmt.lift(l, unit),
      if (!e.active) S.notInLibrary,
    ].join(', ');
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >= IronlyRow.stackedScale;
    final valueText = Text(
      value,
      key: ValueKey('progress-value-${e.id}'),
      style: IronlyText.liftNumber,
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          e.nameVi,
          style: IronlyText.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${Fmt.muscle(e.group)} · ${Fmt.dayMonth(l.date)}',
                style: IronlyText.caption,
              ),
            ),
            if (!e.active) ...[
              const SizedBox(width: TokenSpace.s1),
              StatusGlyph(
                GlyphStatus.locked,
                key: ValueKey('progress-not-in-library-${e.id}'),
                label: S.notInLibrary,
                size: TokenSize.lockSmall,
              ),
            ],
          ],
        ),
        if (stacked) ...[const SizedBox(height: TokenSpace.s1), valueText],
      ],
    );
    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('progress-${e.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TokenSize.cardPadding,
              vertical: TokenSpace.s3,
            ),
            child: Row(
              children: [
                ExerciseAvatar(
                  id: e.id,
                  ring: true,
                  dim: !e.active,
                  child: BodyMap(
                    region: e.region,
                    size: BodyMap.avatar,
                    bare: true,
                  ),
                ),
                const SizedBox(width: TokenSpace.s3),
                Expanded(child: info),
                if (!stacked) ...[
                  const SizedBox(width: TokenSpace.s3),
                  valueText,
                ],
                const SizedBox(width: TokenSpace.s1),
                Icon(Icons.chevron_right, size: 18, color: t.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

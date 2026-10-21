import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/shell/tab_scroll.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/tab_page.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../training/application/training_section.dart';
import '../../training/presentation/training_screen.dart';
import '../application/library_providers.dart';
import 'body_map.dart';
import 'exercise_screen.dart';

/// S-66 — Thư viện bài tập (mục Bài tập của tab Tập luyện, 04 Bản 2 §6.8):
/// hàng 6 nhóm cơ theo thứ tự F18-R9; mặc định Ngực, hoặc nhóm cơ đầu tiên
/// của buổi tập hôm nay; bài chia theo vùng, máy trước tạ sau. Dữ liệu nằm sẵn
/// trong app: không có vòng xoay, không cần mạng, không phụ thuộc ngân sách AI
/// hay lịch (F18-R4, UR2-10).
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// Nhóm Bạn đã chọn; null = theo mặc định.
  MuscleGroup? _chosen;

  @override
  Widget build(BuildContext context) {
    final today = LocalDate.fromDateTime(ref.watch(nowProvider));
    final session = ref.watch(dayProvider(today)).value?.sessionMuscles;
    final group =
        _chosen ??
        (session == null || session.isEmpty
            ? MuscleGroup.chest
            : session.first);
    final regions = ref.watch(libraryProvider(group)).value ?? const [];
    final palette = context.palette;

    return TabPage(
      tab: AppTab.schedule,
      title: S.tabTraining,
      scrollController: ref
          .watch(tabScrollControllersProvider)
          .section(TrainingSection.library),
      children: [
        const TrainingSectionBar(),
        const SizedBox(height: 16),
        _GroupChips(
          selected: group,
          onSelected: (g) => setState(() => _chosen = g),
        ),
        for (final r in regions) ...[
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                Fmt.region(r.region).toUpperCase(),
                key: ValueKey('region-${r.region.id}'),
                style: context.text.labelLarge?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, e) in r.exercises.indexed) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  ExerciseRow(
                    exercise: e,
                    onTap: () =>
                        context.push(exercisePath(e.id, ExerciseFrom.library)),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          S.libraryFootnote,
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}

/// Hàng 6 nhóm cơ dạng viên thuốc, cuộn ngang nếu thiếu chỗ (04 Bản 2 S-66,
/// UA2-14).
class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.selected, required this.onSelected});

  final MuscleGroup selected;
  final ValueChanged<MuscleGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final g in LibraryRules.groupOrder)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: g == selected,
                label: Fmt.muscle(g),
                child: ExcludeSemantics(
                  child: InkWell(
                    key: ValueKey('group-${g.name}'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onSelected(g),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: g == selected ? colors.primary : null,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: g == selected
                              ? colors.primary
                              : context.palette.border,
                        ),
                      ),
                      child: Text(
                        Fmt.muscle(g),
                        style: context.text.titleSmall?.copyWith(
                          color: g == selected ? colors.onPrimary : null,
                          fontWeight: g == selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Một dòng bài (S-66; S-63 dùng lại): hình vùng cơ thu nhỏ · tên bài · nhãn
/// vùng cơ dưới tên · mũi tên (04 Bản 3 §6.6, §6.10). Không còn nhãn dụng cụ
/// (UR3-03).
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({
    super.key,
    required this.exercise,
    required this.onTap,
    this.trailing,
  });

  final Exercise exercise;
  final VoidCallback onTap;

  /// Phần bên phải thay cho mũi tên (VS-27: nút "Ghi", con số mức tạ).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${exercise.nameVi}, ${Fmt.region(exercise.region)}',
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('exercise-${exercise.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                BodyMap(region: exercise.region),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.nameVi, style: context.text.bodyLarge),
                      const SizedBox(height: 4),
                      RegionLabel(exercise.region),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    Icon(
                      Icons.chevron_right,
                      color: context.palette.textSecondary,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhãn vùng cơ dưới tên bài: chữ xám nhỏ, không nền, không màu (04 Bản 3
/// §6.10).
class RegionLabel extends StatelessWidget {
  const RegionLabel(this.region, {super.key});

  final MuscleRegion region;

  @override
  Widget build(BuildContext context) {
    return Text(
      Fmt.region(region),
      style: context.text.bodyMedium?.copyWith(
        color: context.palette.textSecondary,
      ),
    );
  }
}

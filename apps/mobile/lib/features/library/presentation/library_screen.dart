import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/shell/tab_scroll.dart';
import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../training/application/training_section.dart';
import '../../training/presentation/training_screen.dart';
import '../application/library_providers.dart';
import 'body_map.dart';
import 'exercise_screen.dart';

/// S-66 — Thư viện bài tập (mục Bài tập của tab Tập luyện, 04 Bản 4 S-66):
/// thanh viên 7 nhóm cơ cuộn ngang (chọn = cam; mặc định Ngực hoặc nhóm cơ
/// đầu của buổi hôm nay, UA3-11); thẻ danh sách phẳng: ảnh vùng cơ tròn
/// (viền cam) + tên bài + ›. Không nhãn vùng cơ, không câu cuối danh sách
/// (FR4-04). Bài đã bỏ không hiện. Dữ liệu nằm sẵn trong app (F18-R4).
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
    final exercises = ref.watch(libraryProvider(group)).value ?? const [];

    return IronlyTabPage(
      tab: AppTab.schedule,
      title: S.tabTraining,
      scrollController: ref
          .watch(tabScrollControllersProvider)
          .section(TrainingSection.library),
      children: [
        const TrainingSectionBar(),
        const SizedBox(height: TokenSpace.s4),
        _GroupChips(
          selected: group,
          onSelected: (g) => setState(() => _chosen = g),
        ),
        if (exercises.isNotEmpty) ...[
          const SizedBox(height: TokenSpace.s4),
          IronlyListCard(
            children: [
              for (final e in exercises)
                ExerciseRow(
                  exercise: e,
                  onTap: () =>
                      context.push(exercisePath(e.id, ExerciseFrom.library)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Hàng 7 viên nhóm cơ theo thứ tự thư viện, cuộn ngang (04 Bản 4 S-66).
class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.selected, required this.onSelected});

  final MuscleGroup selected;
  final ValueChanged<MuscleGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final g in LibraryRules.groupOrder)
            Padding(
              padding: const EdgeInsets.only(right: TokenSpace.s2),
              child: IronlyChip(
                key: ValueKey('group-${g.name}'),
                label: Fmt.muscle(g),
                selected: g == selected,
                onTap: () => onSelected(g),
              ),
            ),
        ],
      ),
    );
  }
}

/// Một dòng bài (S-66): ảnh vùng cơ tròn viền cam · tên bài 14 / 500 · ›
/// (04 Bản 4 S-66). VoiceOver đọc tên bài và vùng cơ.
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({
    super.key,
    required this.exercise,
    required this.onTap,
    this.trailing,
  });

  final Exercise exercise;
  final VoidCallback onTap;

  /// Phần bên phải thay cho mũi tên.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: '${exercise.nameVi}, ${Fmt.region(exercise.region)}',
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('exercise-${exercise.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TokenSize.cardPadding,
              vertical: TokenSpace.s3,
            ),
            child: Row(
              children: [
                ExerciseAvatar(
                  id: exercise.id,
                  ring: true,
                  child: BodyMap(
                    region: exercise.region,
                    size: BodyMap.avatar,
                    bare: true,
                  ),
                ),
                const SizedBox(width: TokenSpace.s3),
                Expanded(
                  // Tên bài 14 / 500 trắng (04 Bản 4 S-66).
                  child: Text(
                    exercise.nameVi,
                    style: IronlyText.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: TokenSpace.s2),
                trailing ??
                    Icon(Icons.chevron_right, size: 18, color: t.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

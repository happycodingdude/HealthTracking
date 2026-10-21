import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/reference_tag.dart';
import '../../workout/application/lift_unit.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/presentation/lift_log_sheet.dart';
import '../application/library_providers.dart';
import 'body_map.dart';
import 'video_area.dart';

/// Màn trước của S-67: quyết định chữ trên nút quay lại (04 Bản 2 S-67).
enum ExerciseFrom {
  library(S.backLibrary),
  session(S.backSession),
  progress(S.backProgress);

  const ExerciseFrom(this.backLabel);

  final String backLabel;

  static ExerciseFrom parse(String? name) => values.firstWhere(
    (f) => f.name == name,
    orElse: () => ExerciseFrom.library,
  );
}

/// Đường dẫn S-67, nằm trong tab Tập luyện (NAV-10).
String exercisePath(String id, ExerciseFrom from) =>
    '/schedule/exercise/${Uri.encodeComponent(id)}?from=${from.name}';

/// S-67 — Chi tiết bài (04 Bản 2 §6.8, F-19): video, tên, nhóm · vùng ·
/// dụng cụ, hình vùng cơ (nam/nữ theo hồ sơ), Cách tập, Lưu ý an toàn, nhãn
/// "tham khảo" của hướng dẫn (F10-R21). Tên, hình, hướng dẫn hiện được khi
/// không có mạng; chỉ video cần mạng (F19-R2). Hướng dẫn hiện đúng nội dung
/// Bạn đã duyệt (F19-R5). Cuối màn là khu mức tạ ([_LiftArea]).
class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({
    super.key,
    required this.id,
    required this.from,
    this.session,
  });

  final String id;
  final ExerciseFrom from;

  /// Ngày của buổi khi mở từ S-63 (F19-R3).
  final LocalDate? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseProvider(id)).value;
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('exercise-back'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.chevron_left),
                label: Text(from.backLabel),
              ),
            ),
            const SizedBox(height: 12),
            if (exercise != null) ...[
              VideoArea(exercise: exercise),
              const SizedBox(height: 20),
              Heading(
                exercise.nameVi,
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              // Ngay dưới tên bài (bảng khu mức tạ của S-67, F19-E2).
              if (!exercise.active) ...[
                const SizedBox(height: 4),
                Text(
                  S.notInLibrary,
                  key: const ValueKey('not-in-library'),
                  style: context.text.bodyMedium?.copyWith(
                    color: palette.attention,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${Fmt.muscle(exercise.group)} · '
                '${Fmt.region(exercise.region)}',
                style: context.text.bodyLarge?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  BodyMap(
                    region: exercise.region,
                    size: BodyMap.large,
                    semanticLabel:
                        '${S.mainRegion}: ${Fmt.region(exercise.region)}',
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        S.mainRegion,
                        style: context.text.bodyLarge?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionTitle(S.howTo),
              for (final (i, step) in exercise.guideSteps.indexed)
                _GuideLine(marker: '${i + 1}', text: step),
              const SizedBox(height: 16),
              const _SectionTitle(S.safetyNotes),
              for (final note in exercise.guideSafety)
                _GuideLine(marker: '•', text: note),
              const SizedBox(height: 16),
              const _GuideNote(),
              _LiftArea(exercise: exercise, session: session, from: from),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text.toUpperCase(),
            style: context.text.labelLarge?.copyWith(
              color: context.palette.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Một bước (đánh số) hoặc một ý (gạch đầu dòng) của hướng dẫn.
class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.marker, required this.text});

  final String marker;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: Text(
                  marker,
                  style: context.text.labelLarge?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: context.text.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn của hướng dẫn bài tập (F10-R21). Chạm → bảng giải thích như nhãn
/// "tham khảo" của Bản 1 (04 Bản 2 S-67).
class _GuideNote extends StatelessWidget {
  const _GuideNote();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.exerciseGuideNote,
      child: ExcludeSemantics(
        child: InkWell(
          key: const ValueKey('exercise-guide-note'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => showReferenceSheet(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.border),
            ),
            child: Text(
              S.exerciseGuideNote,
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Khu mức tạ (04 Bản 2 S-67, 6 tình huống): ghi hoặc sửa mức tạ của buổi khi
/// mở từ S-63 trong cửa sổ ghi tạ; chỉ đọc khi ngoài cửa sổ; nơi khác hiện
/// bản ghi gần nhất. Ẩn khi bài chưa có bản ghi nào (F19-AC3) và với bài bụng
/// (F19-R4). Bài đã rời thư viện không có "Ghi mức tạ" (UA2-18).
class _LiftArea extends ConsumerWidget {
  const _LiftArea({
    required this.exercise,
    required this.session,
    required this.from,
  });

  final Exercise exercise;
  final LocalDate? session;
  final ExerciseFrom from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!exercise.logsWeight) return const SizedBox.shrink();
    final logs = ref.watch(allLiftLogsProvider).value;
    if (logs == null) return const SizedBox.shrink();
    final date = session;
    final view = date == null ? null : ref.watch(sessionProvider(date));
    final inWindow = view?.canLog ?? false;
    LiftLog? latest;
    LiftLog? thisSession;
    for (final l in logs) {
      if (l.exerciseId != exercise.id) continue;
      if (latest == null || l.date.isAfter(latest.date)) latest = l;
      if (l.date == date) thisSession = l;
    }
    final secondary = context.text.bodyLarge?.copyWith(
      color: context.palette.textSecondary,
    );
    final unit = Fmt.liftUnit(exercise.liftUnit);

    final List<Widget> content;
    if (date != null && inWindow && thisSession == null && exercise.active) {
      final previous = LiftLogRules.previousSession(logs, exercise.id, date);
      content = [
        if (previous != null) ...[
          Text(
            S.liftPrevious(
              Fmt.dayMonth(previous.date),
              Fmt.kgNumber(previous.startKgX10),
              Fmt.kgNumber(previous.endKgX10),
              unit,
            ),
            style: secondary,
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          key: const ValueKey('exercise-log-lift'),
          onPressed: () =>
              showLiftLogSheet(context, date: date, exercise: exercise),
          child: const Text(S.logLift),
        ),
      ];
    } else if (date != null && thisSession != null) {
      final value = Text(
        S.liftThisSession(
          Fmt.kgNumber(thisSession.startKgX10),
          Fmt.kgNumber(thisSession.endKgX10),
          unit,
        ),
        key: const ValueKey('exercise-lift-this-session'),
        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      );
      final log = thisSession;
      content = [
        if (inWindow)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              value,
              OutlinedButton(
                key: const ValueKey('exercise-edit-lift'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 44),
                ),
                onPressed: () => showLiftLogSheet(
                  context,
                  date: date,
                  exercise: exercise,
                  existing: log,
                ),
                child: const Text(S.edit),
              ),
            ],
          )
        else
          value,
      ];
    } else if (latest != null) {
      content = [
        Text(
          S.liftLatest(
            Fmt.dayMonth(latest.date),
            Fmt.kgNumber(latest.startKgX10),
            Fmt.kgNumber(latest.endKgX10),
            unit,
          ),
          key: const ValueKey('exercise-lift-latest'),
          style: secondary,
        ),
        // S-69 (NAV-11). Mở từ biểu đồ thì quay lại biểu đồ đó.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('exercise-view-chart'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              textStyle: context.text.titleMedium,
            ),
            onPressed: () => from == ExerciseFrom.progress
                ? context.pop()
                : context.push('${GoRouterState.of(context).uri.path}/chart'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(S.viewChart)),
                Icon(Icons.chevron_right, size: 22),
              ],
            ),
          ),
        ),
      ];
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        key: const ValueKey('exercise-lift-area'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(20),
          // Thẻ viền đậm để thấy ngay khi cuộn tới (04 Bản 2 S-67).
          border: Border.all(color: context.colors.primary, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: content,
        ),
      ),
    );
  }
}

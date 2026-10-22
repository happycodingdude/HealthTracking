import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/reference_tag.dart';
import '../../../core/widgets/toast.dart';
import '../../workout/application/lift_log_edits.dart';
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

/// Khu cuối trang S-67 (04 Bản 3 S-67, UA3-12), các dòng theo tình huống:
/// "Ghi mức tạ" / "Buổi này" + "Sửa" và "Ghi chú hôm nay" khi mở từ buổi
/// trong cửa sổ ghi tạ; bài bụng: ghi chú buổi trước mờ, "Bài này không ghi
/// mức tạ" + "Ghi chú" (FA3-08); "Đơn vị" + "Đổi sang …" khi bài đã có đơn vị
/// (F19-R41, F19-R42); "Gần nhất" + "Xem biểu đồ" khi bài có bản ghi. Khu ẩn
/// khi không có dòng nào (F19-AC3). Thẻ viền đậm khi mở từ buổi trong cửa sổ.
/// Bài đã rời thư viện: không có "Ghi mức tạ" (UA2-18).
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
    final logs = ref.watch(allLiftLogsProvider).value;
    final notes = ref.watch(allExerciseNotesProvider).value;
    final units = ref.watch(exerciseUnitsProvider).value;
    if (logs == null || notes == null || units == null) {
      return const SizedBox.shrink();
    }
    final date = session;
    final view = date == null ? null : ref.watch(sessionProvider(date));
    final inWindow = date != null && (view?.canLog ?? false);
    final id = exercise.id;
    LiftLog? latest;
    LiftLog? thisSession;
    for (final l in logs) {
      if (l.exerciseId != id) continue;
      if (latest == null || l.date.isAfter(latest.date)) latest = l;
      if (l.date == date) thisSession = l;
    }
    ExerciseNote? todayNote;
    for (final n in notes) {
      if (n.exerciseId == id && n.date == date) todayNote = n;
    }
    final unit = units[id]?.unit;
    final shown = Fmt.liftUnit(unit ?? LiftUnit.kg);
    final palette = context.palette;
    final secondary = context.text.bodyLarge?.copyWith(
      color: palette.textSecondary,
    );
    final bold = context.text.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    void openSheet() =>
        showLiftLogSheet(context, date: date!, exercise: exercise);

    // Nút [label] nằm bên phải; chữ lớn làm nút chiếm quá nửa dòng thì nút
    // xuống dưới.
    Widget line(Widget left, [Widget? right, String label = '']) {
      if (right == null) return left;
      return LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: bold),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final wide = painter.width + 24 > constraints.maxWidth * 0.55;
          painter.dispose();
          return wide
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [left, right],
                )
              : Row(
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 8),
                    right,
                  ],
                );
        },
      );
    }

    Widget link(String text, Key key, VoidCallback onPressed) => TextButton(
      key: key,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: bold,
      ),
      onPressed: onPressed,
      child: Text(text),
    );
    Widget valueText(String label, LiftLog l, Key key) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text:
                '${Fmt.kgNumber(l.startKgX10)} → ${Fmt.kgNumber(l.endKgX10)} '
                '$shown',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      key: key,
      style: context.text.bodyLarge,
    );
    Widget noteToday(ExerciseNote n) => InkWell(
      key: const ValueKey('exercise-note-today'),
      onTap: openSheet,
      child: Row(
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 18,
            color: context.colors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              S.noteToday(n.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: secondary,
            ),
          ),
        ],
      ),
    );

    final rows = <Widget>[
      if (exercise.logsWeight) ...[
        if (inWindow && thisSession == null && exercise.active)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('exercise-log-lift'),
              onPressed: openSheet,
              child: const Text(S.logLift),
            ),
          )
        else if (date != null && thisSession != null)
          line(
            valueText(
              S.liftThisSessionLabel,
              thisSession,
              const ValueKey('exercise-lift-this-session'),
            ),
            inWindow
                ? link(S.edit, const ValueKey('exercise-edit-lift'), openSheet)
                : null,
            S.edit,
          ),
        if (inWindow && todayNote != null) noteToday(todayNote),
      ] else if (inWindow) ...[
        if (ExerciseNoteRules.previous(
              notes: notes,
              logs: logs,
              exercise: exercise,
              date: date,
            )
            case final previous?)
          Text(
            S.notePreviousSession(Fmt.dayMonth(previous.date), previous.text),
            key: const ValueKey('exercise-note-previous'),
            style: secondary,
          ),
        if (todayNote != null) noteToday(todayNote),
        line(
          Text(S.liftNoWeight, style: context.text.bodyLarge),
          OutlinedButton(
            key: const ValueKey('exercise-note'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.primary,
              minimumSize: const Size(64, 44),
              shape: const StadiumBorder(),
              side: BorderSide(color: context.colors.primary, width: 1.5),
              textStyle: bold,
            ),
            onPressed: openSheet,
            child: const Text(S.noteShort),
          ),
          S.noteShort,
        ),
      ],
      if (exercise.logsWeight && unit != null)
        line(
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: S.unitLine('')),
                TextSpan(
                  text: Fmt.liftUnitFull(unit),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            key: const ValueKey('exercise-unit'),
            style: context.text.bodyLarge,
          ),
          link(
            S.changeUnitTo(Fmt.liftUnitFull(_other(unit))),
            const ValueKey('exercise-change-unit'),
            () => confirmChangeUnit(context, ref, exercise, unit),
          ),
          S.changeUnitTo(Fmt.liftUnitFull(_other(unit))),
        ),
      if (exercise.logsWeight && latest != null)
        line(
          valueText(
            S.liftLatestOn(Fmt.dayMonth(latest.date)),
            latest,
            const ValueKey('exercise-lift-latest'),
          ),
          // S-69 (NAV-11). Mở từ biểu đồ thì quay lại biểu đồ đó.
          link(
            S.viewChart,
            const ValueKey('exercise-view-chart'),
            () => from == ExerciseFrom.progress
                ? context.pop()
                : context.push('${GoRouterState.of(context).uri.path}/chart'),
          ),
          S.viewChart,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        key: const ValueKey('exercise-lift-area'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(20),
          // Viền đậm khi mở từ buổi trong cửa sổ ghi tạ (04 Bản 3 S-67).
          border: inWindow
              ? Border.all(color: context.colors.primary, width: 2)
              : Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: row,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static LiftUnit _other(LiftUnit unit) =>
      unit == LiftUnit.kg ? LiftUnit.steps : LiftUnit.kg;
}

/// S-72 — Xác nhận đổi đơn vị (04 Bản 3 §6.6, UA3-17): tiêu đề "Đổi sang
/// {đơn vị}?", câu nguyên văn F21-R47, "Hủy" · "Đổi sang {đơn vị}" (không
/// đỏ). Xác nhận → [ChangeExerciseUnit] (không cần mạng, F21-AC51) → thông
/// báo nhanh "Đã đổi sang {đơn vị}"; mọi nơi đọc đơn vị đổi ngay.
Future<void> confirmChangeUnit(
  BuildContext context,
  WidgetRef ref,
  Exercise exercise,
  LiftUnit current,
) async {
  final to = current == LiftUnit.kg ? LiftUnit.steps : LiftUnit.kg;
  final name = Fmt.liftUnitFull(to);
  final confirmed =
      await showAppDialog<bool>(
        context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('change-unit-dialog'),
          title: Text(S.changeUnitTitle(name), textAlign: TextAlign.center),
          content: Text(S.changeUnitBody(name), textAlign: TextAlign.center),
          actions: [
            OutlinedButton(
              key: const ValueKey('change-unit-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(S.cancel),
            ),
            FilledButton(
              key: const ValueKey('change-unit-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(S.changeUnitTo(name)),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) return;
  await ref.read(changeExerciseUnitProvider).call(exercise.id, to);
  if (context.mounted) showToast(context, S.unitChanged(name));
}

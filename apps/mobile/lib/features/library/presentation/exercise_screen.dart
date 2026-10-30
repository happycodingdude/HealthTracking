import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../workout/application/lift_log_edits.dart';
import '../../workout/application/lift_unit.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/presentation/lift_log_sheet.dart';
import '../application/library_providers.dart';
import 'body_map.dart';
import 'video_area.dart';

/// Màn trước của S-67: quyết định "Biểu đồ ›" mở S-69 mới hay quay lại.
enum ExerciseFrom {
  library,
  session,
  progress;

  static ExerciseFrom parse(String? name) => values.firstWhere(
    (f) => f.name == name,
    orElse: () => ExerciseFrom.library,
  );
}

/// Đường dẫn S-67, nằm trong tab Tập luyện (NAV-10).
String exercisePath(String id, ExerciseFrom from) =>
    '/schedule/exercise/${Uri.encodeComponent(id)}?from=${from.name}';

/// S-67 — Chi tiết bài (04 Bản 4 S-67, F-19): tiêu đề giữa = tên bài, nút
/// quay lại trái; khối video 16:9; thẻ sơ đồ cơ · "Ngực · Ngực giữa" chữ phụ
/// + "Đơn vị" với thanh chọn kg | nấc máy (chạm đổi → S-72); thẻ "Cách tập"
/// (nội dung thư viện, giữ); thẻ mức tạ ([_LiftCard]). Tên, hình, hướng dẫn
/// hiện được khi không có mạng (F19-R2). Không câu "Hướng dẫn tham khảo…",
/// "Vùng cơ chịu tác động chính" (FR4-04, FR4-05).
class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({
    super.key,
    required this.id,
    required this.from,
    this.session,
  });

  final String id;
  final ExerciseFrom from;

  /// Ngày của buổi khi mở từ buổi tập (F19-R3).
  final LocalDate? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseProvider(id)).value;
    final t = context.tokens;
    return IronlySubPage(
      title: exercise?.nameVi ?? '',
      leading: Semantics(
        button: true,
        label: S.back,
        child: ExcludeSemantics(
          child: GestureDetector(
            key: const ValueKey('exercise-back'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.pop(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.chevron_left, color: t.accent, size: 26),
            ),
          ),
        ),
      ),
      children: [
        if (exercise != null) ...[
          VideoArea(exercise: exercise),
          const CardGap(),
          _InfoCard(exercise: exercise),
          const CardGap(),
          IronlyCard(
            key: const ValueKey('exercise-guide'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(S.howTo, style: IronlyText.cardTitle),
                ),
                const SizedBox(height: TokenSpace.s2),
                for (final (i, step) in exercise.guideSteps.indexed)
                  _GuideLine(marker: '${i + 1}', text: step),
                if (exercise.guideSafety.isNotEmpty) ...[
                  const SizedBox(height: TokenSpace.s2),
                  Semantics(
                    header: true,
                    child: Text(
                      S.safetyNotes.toUpperCase(),
                      style: IronlyText.groupLabel,
                    ),
                  ),
                  const SizedBox(height: TokenSpace.s2),
                  for (final note in exercise.guideSafety)
                    _GuideLine(marker: '•', text: note),
                ],
              ],
            ),
          ),
          _LiftCard(exercise: exercise, session: session, from: from),
        ],
      ],
    );
  }
}

/// Thẻ: sơ đồ cơ trái (vùng cam) · "Ngực · Ngực giữa" chữ phụ · "Đơn vị" +
/// thanh chọn kg | nấc máy (bài có đơn vị). Bài đã rời thư viện: dòng chữ
/// phụ ngay trên (F19-E2, F4-R3).
class _InfoCard extends ConsumerWidget {
  const _InfoCard({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(exerciseUnitsProvider).value;
    final unit = units?[exercise.id]?.unit;
    final showUnit = exercise.logsWeight && unit != null;
    return IronlyCard(
      key: const ValueKey('exercise-info'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BodyMap(
            region: exercise.region,
            size: BodyMap.large,
            bare: true,
            semanticLabel: Fmt.region(exercise.region),
          ),
          const SizedBox(width: TokenSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!exercise.active) ...[
                  Text(
                    S.notInLibrary,
                    key: const ValueKey('not-in-library'),
                    style: IronlyText.caption,
                  ),
                  const SizedBox(height: TokenSpace.s1),
                ],
                Text(
                  '${Fmt.muscle(exercise.group)} · '
                  '${Fmt.region(exercise.region)}',
                  style: IronlyText.caption,
                ),
                if (showUnit) ...[
                  const SizedBox(height: TokenSpace.s3),
                  Text(
                    S.unitLabel,
                    key: const ValueKey('exercise-unit'),
                    style: IronlyText.caption,
                  ),
                  const SizedBox(height: TokenSpace.s1),
                  SegmentBar<LiftUnit>(
                    items: const [LiftUnit.kg, LiftUnit.steps],
                    selected: unit,
                    style: SegmentStyle.accent,
                    label: Fmt.liftUnitFull,
                    keyOf: (u) => ValueKey(
                      u == unit
                          ? 'exercise-unit-current'
                          : 'exercise-change-unit',
                    ),
                    onSelected: (u) {
                      if (u != unit) {
                        confirmChangeUnit(context, ref, exercise, unit);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: TokenSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.accentSoft,
                shape: BoxShape.circle,
              ),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: Text(
                  marker,
                  style: IronlyText.caption.copyWith(
                    color: t.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: TokenSpace.s3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: IronlyText.body),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ mức tạ cuối S-67 (04 Bản 4 S-67, UA3-12): "Buổi này 8 → 10 nấc"
/// trắng (+ "Sửa" khi còn trong cửa sổ ghi), "20/10 8 → 9 nấc" chữ phụ (gần
/// nhất), dòng ghi chú "Hôm nay · …"; nút "Ghi mức tạ" khi mở từ buổi trong
/// cửa sổ mà chưa ghi; bài bụng: ghi chú buổi trước mờ + nút "Ghi chú";
/// chữ cam "Biểu đồ ›" → S-69. Thẻ ẩn khi không có dòng nào (F19-AC3). Bài
/// đã rời thư viện: không có "Ghi mức tạ" (UA2-18).
class _LiftCard extends ConsumerWidget {
  const _LiftCard({
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
    final t = context.tokens;
    final date = session;
    final view = date == null ? null : ref.watch(sessionProvider(date));
    final inWindow = date != null && (view?.canLog ?? false);
    final id = exercise.id;
    LiftLog? latest;
    LiftLog? thisSession;
    for (final l in logs) {
      if (l.exerciseId != id) continue;
      if (l.date == date) {
        thisSession = l;
      } else if (latest == null || l.date.isAfter(latest.date)) {
        latest = l;
      }
    }
    ExerciseNote? todayNote;
    for (final n in notes) {
      if (n.exerciseId == id && n.date == date) todayNote = n;
    }
    final unit = units[id]?.unit ?? LiftUnit.kg;
    String value(LiftLog l) =>
        '${Fmt.kgNumber(l.startKgX10)} → ${Fmt.kgNumber(l.endKgX10)}'
        '${unit == LiftUnit.steps ? ' ${S.unitSteps}' : ''}';
    void openSheet() =>
        showLiftLogSheet(context, date: date!, exercise: exercise);

    Widget pair(String label, String number, Key key, {bool dim = false}) =>
        Semantics(
          container: true,
          label: '$label: $number',
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: dim ? IronlyText.caption : IronlyText.body,
                  ),
                ),
                Text(
                  number,
                  key: key,
                  style: dim ? IronlyText.liftPrefill : IronlyText.liftNumber,
                ),
              ],
            ),
          ),
        );

    Widget noteLine(String text, Key key, {bool dim = false}) => Row(
      key: key,
      children: [
        Icon(
          Icons.sticky_note_2_outlined,
          size: 16,
          color: dim ? t.textPrefill : t.textSecondary,
        ),
        const SizedBox(width: TokenSpace.s2),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: IronlyText.caption.copyWith(
              color: dim ? t.textPrefill : t.textSecondary,
            ),
          ),
        ),
      ],
    );

    final rows = <Widget>[
      if (exercise.logsWeight) ...[
        if (inWindow && thisSession == null && exercise.active)
          IronlyButton.primary(
            key: const ValueKey('exercise-log-lift'),
            label: S.logLift,
            onPressed: openSheet,
          )
        else if (date != null && thisSession != null)
          Row(
            children: [
              Expanded(
                child: pair(
                  S.liftThisSessionLabel,
                  value(thisSession),
                  const ValueKey('exercise-lift-this-session'),
                ),
              ),
              if (inWindow) ...[
                const SizedBox(width: TokenSpace.s3),
                IronlyButton.link(
                  key: const ValueKey('exercise-edit-lift'),
                  label: S.edit,
                  small: true,
                  onPressed: openSheet,
                ),
              ],
            ],
          ),
        if (latest != null)
          pair(
            Fmt.dayMonth(latest.date),
            value(latest),
            const ValueKey('exercise-lift-latest'),
            dim: true,
          ),
        if (inWindow && todayNote != null)
          InkWell(
            key: const ValueKey('exercise-note-today'),
            onTap: openSheet,
            child: noteLine(
              '${S.todayLabel} · ${todayNote.text}',
              const ValueKey('exercise-note-today-line'),
            ),
          ),
      ] else if (inWindow) ...[
        if (ExerciseNoteRules.previous(
              notes: notes,
              logs: logs,
              exercise: exercise,
              date: date,
            )
            case final previous?)
          noteLine(
            '${Fmt.dayMonth(previous.date)} · ${previous.text}',
            const ValueKey('exercise-note-previous'),
            dim: true,
          ),
        if (todayNote != null)
          noteLine(
            '${S.todayLabel} · ${todayNote.text}',
            const ValueKey('exercise-note-today'),
          ),
        IronlyButton(
          key: const ValueKey('exercise-note'),
          kind: IronlyButtonKind.secondaryAccent,
          label: S.noteShort,
          onPressed: openSheet,
        ),
      ],
      if (exercise.logsWeight && latest != null || thisSession != null)
        Align(
          alignment: Alignment.centerLeft,
          child: IronlyButton.link(
            key: const ValueKey('exercise-view-chart'),
            label: '${S.chartLink} ›',
            small: true,
            expand: false,
            // S-69 (NAV-11). Mở từ biểu đồ thì quay lại biểu đồ đó.
            onPressed: () => from == ExerciseFrom.progress
                ? context.pop()
                : context.push('${GoRouterState.of(context).uri.path}/chart'),
          ),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: TokenSpace.s3),
      child: IronlyCard(
        key: const ValueKey('exercise-lift-area'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const SizedBox(height: TokenSpace.s3),
              row,
            ],
          ],
        ),
      ),
    );
  }
}

/// S-72 — Xác nhận đổi đơn vị (04 Bản 4 S-72): "Đổi sang {đơn vị}?" + câu
/// nguyên văn F21-R47; nút xám "Hủy", cam "Đổi sang {đơn vị}". Xác nhận →
/// [ChangeExerciseUnit] (không cần mạng, F21-AC51) → thông báo nhanh "Đã đổi
/// sang {đơn vị}"; mọi nơi đọc đơn vị đổi ngay.
Future<void> confirmChangeUnit(
  BuildContext context,
  WidgetRef ref,
  Exercise exercise,
  LiftUnit current,
) async {
  final to = current == LiftUnit.kg ? LiftUnit.steps : LiftUnit.kg;
  final name = Fmt.liftUnitFull(to);
  final confirmed =
      await showIronlyDialog<bool>(
        context,
        builder: (dialogContext) => IronlyDialog(
          key: const ValueKey('change-unit-dialog'),
          title: S.changeUnitTitle(name),
          body: S.changeUnitBody(name),
          secondaryLabel: S.cancel,
          secondaryKey: const ValueKey('change-unit-cancel'),
          onSecondary: () => Navigator.of(dialogContext).pop(false),
          primaryLabel: S.changeUnitTo(name),
          primaryKey: const ValueKey('change-unit-confirm'),
          onPrimary: () => Navigator.of(dialogContext).pop(true),
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) return;
  await ref.read(changeExerciseUnitProvider).call(exercise.id, to);
  if (context.mounted) showToast(context, S.unitChanged(name));
}

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/session_tag.dart';
import '../../../core/widgets/toast.dart';
import '../../library/presentation/body_map.dart';
import '../../library/presentation/library_screen.dart';
import '../../schedule/presentation/session_marking.dart';
import '../application/session_providers.dart';
import 'lift_log_sheet.dart';

/// Từ mức phóng chữ này trở lên, con số mức tạ nằm dưới tên bài (04 Bản 2
/// §6.13).
const _stackedScale = 1.6;

/// Đường dẫn S-63 của buổi ngày [date], mở trong tab [tab] (Hôm nay hoặc
/// Tập luyện, NAV-9).
String sessionPath(AppTab tab, LocalDate date) =>
    '${tab.path}/session/${date.toKey()}';

/// Đường dẫn S-67 mở từ S-63 (cùng tab, nút quay lại "Buổi tập").
String sessionExercisePath(AppTab tab, LocalDate date, String exerciseId) =>
    '${sessionPath(tab, date)}/exercise/${Uri.encodeComponent(exerciseId)}';

/// Mở S-63 của buổi ngày [date] trong tab đang mở (thẻ ở Hôm nay; S-21 từ
/// Lịch hoặc S-25; thông báo nhanh của S-24).
void openSession(BuildContext context, LocalDate date) {
  final shell = StatefulNavigationShell.maybeOf(context);
  final tab = shell != null && shell.currentIndex == AppTab.today.index
      ? AppTab.today
      : AppTab.schedule;
  // Thông báo nhanh mở từ ngữ cảnh ngoài khung tab: về tab đang chọn.
  final router = GoRouter.of(context);
  router.push(sessionPath(tab, date));
}

/// S-63 — Buổi tập (04 Bản 2 S-63, F-20, F-21): vùng cơ và bài của buổi, ghi
/// mức tạ từng bài không rời danh sách. Một màn cho mọi trạng thái: ngoài
/// cửa sổ ghi tạ chỉ khác dòng trạng thái, nút "Ghi" và thanh đáy (06 Bản 2
/// ED2-17). Qua 00:00 khi đang mở thì tự chuyển chỉ đọc ([SessionView] tính
/// lại theo giờ).
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.date, required this.tab});

  final LocalDate date;

  /// Tab mở màn hình; nút quay lại về Hôm nay hoặc Lịch.
  final AppTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(date));
    final exercises = ref.watch(sessionExercisesProvider(date));
    // Giữ sẵn mọi bản ghi để S-64 có "Buổi trước" ngay khi mở.
    ref.watch(allLiftLogsProvider);
    final palette = context.palette;
    final bottom = session == null || exercises == null
        ? null
        : _BottomBar(session: session, exercises: exercises);

    return Scaffold(
      bottomNavigationBar: bottom,
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: const ValueKey('session-list'),
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
                key: const ValueKey('session-back'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.chevron_left),
                label: Text(
                  tab == AppTab.today ? S.tabToday : S.sectionSchedule,
                ),
              ),
            ),
            if (session != null) ...[
              const SizedBox(height: 8),
              Heading(
                session.isExtra
                    ? S.extraSessionTitle(Fmt.musclesTitle(session.muscles))
                    : S.sessionTitle(Fmt.musclesTitle(session.muscles)),
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _Subtitle(session),
              if (session.readOnly case final reason?) ...[
                const SizedBox(height: 16),
                _ReadOnlyLine(session: session, reason: reason),
              ],
              if (exercises != null) ...[
                for (final g in exercises.groups) ...[
                  // Mỗi nhóm một tiêu đề nhỏ, kể cả buổi một nhóm; dưới là
                  // danh sách phẳng theo thứ tự thư viện (F20-R41, 04 Bản 3
                  // S-63).
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        Fmt.muscle(g.group).toUpperCase(),
                        key: ValueKey('session-group-${g.group.name}'),
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
                        for (final (i, item) in g.items.indexed) ...[
                          if (i > 0) const Divider(indent: 16, endIndent: 16),
                          _ExerciseLine(
                            session: session,
                            item: item,
                            onOpen: () => context.push(
                              sessionExercisePath(tab, date, item.exercise.id),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (session.canLog) ...[
                  const SizedBox(height: 14),
                  Text(
                    S.sessionFootnote,
                    key: const ValueKey('session-footnote'),
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// "Thứ 4, 07/10 · 18:00 · [Chờ đánh dấu]"; buổi tập thêm "Thứ 5, 09/10 ·
/// [+ Đã lưu]".
class _Subtitle extends StatelessWidget {
  const _Subtitle(this.session);

  final SessionView session;

  @override
  Widget build(BuildContext context) {
    final day = session.day;
    final style = context.text.bodyLarge?.copyWith(
      color: context.palette.textSecondary,
    );
    final status = session.status;
    final info = session.isExtra
        ? '${Fmt.weekdayDate(day.date)} ·'
        : '${Fmt.weekdayDate(day.date)} · ${Fmt.time(day.time!)} ·';
    return Wrap(
      key: const ValueKey('session-subtitle'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        Text(info, style: style),
        if (status != null) SessionTag(status) else const ExtraSavedTag(),
      ],
    );
  }
}

/// Dòng chỉ đọc ở đầu màn (04 Bản 2 S-63 bảng dòng trạng thái, §6.11): nói
/// rõ vì sao và khi nào ghi được.
class _ReadOnlyLine extends StatelessWidget {
  const _ReadOnlyLine({required this.session, required this.reason});

  final SessionView session;
  final LiftReadOnly reason;

  @override
  Widget build(BuildContext context) {
    final text = switch (reason) {
      LiftReadOnly.opensLater => S.liftOpensAt(Fmt.time(session.day.time!)),
      LiftReadOnly.future => S.readOnlyFuture,
      LiftReadOnly.locked => S.readOnlyLocked,
      LiftReadOnly.pastExtra => S.readOnlyPastExtra,
    };
    return Container(
      key: ValueKey('session-readonly-${reason.name}'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.palette.neutralContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: context.text.bodyLarge),
    );
  }
}

/// Một dòng bài (04 Bản 3 S-63, 8 tình huống, [LiftRowState]): hình vùng cơ
/// thu nhỏ · tên (+ biểu tượng ghi chú rõ / mờ, F20-R43) · nhãn vùng cơ;
/// bên phải mức tạ buổi trước / gần nhất (xám, có nhãn), mức hôm nay (đậm),
/// nút "Ghi" / "Ghi chú", hoặc trống. Chạm phần phải (và biểu tượng ghi chú)
/// → S-64; chạm tên, hình hoặc cả dòng khi không ghi được → S-67.
class _ExerciseLine extends ConsumerWidget {
  const _ExerciseLine({
    required this.session,
    required this.item,
    required this.onOpen,
  });

  final SessionView session;
  final SessionExercise item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = item.exercise;
    final log = item.log;
    final unit = item.unit ?? LiftUnit.kg;
    final palette = context.palette;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= _stackedScale;

    void openSheet() =>
        showLiftLogSheet(context, date: session.date, exercise: e);
    final canOpenSheet = switch (item.state) {
      LiftRowState.prev || LiftRowState.today || LiftRowState.absNote => true,
      LiftRowState.none || LiftRowState.removed => session.canLog,
      _ => false,
    };

    final bold = context.text.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    Widget value(LiftLog l, {TextStyle? style, Key? key}) =>
        Text(Fmt.lift(l, unit), key: key, style: style);
    Widget labelled(String label, LiftLog l, Key key) => Column(
      key: key,
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: palette.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        value(
          l,
          style: context.text.titleMedium?.copyWith(
            color: palette.textSecondary,
          ),
        ),
      ],
    );
    Widget tappable(Widget child, Key key) => Semantics(
      button: true,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(10),
        onTap: openSheet,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              alignment: stacked ? Alignment.centerLeft : Alignment.centerRight,
              child: child,
            ),
          ),
        ),
      ),
    );
    Widget outlined(String text, Key key) => OutlinedButton(
      key: key,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape: const StadiumBorder(),
        side: BorderSide(color: context.colors.primary, width: 1.5),
        textStyle: bold,
      ),
      onPressed: openSheet,
      child: Text(text),
    );

    // Bên phải dòng bài (UA3-05).
    final Widget? action = switch (item.state) {
      LiftRowState.prev => tappable(
        labelled(
          S.liftPreviousLabel,
          item.previous!,
          ValueKey('lift-prev-${e.id}'),
        ),
        ValueKey('lift-prev-tap-${e.id}'),
      ),
      LiftRowState.today => tappable(
        value(log!, style: bold),
        ValueKey('lift-value-${e.id}'),
      ),
      LiftRowState.latest => labelled(
        S.liftLatestLabel,
        item.previous!,
        ValueKey('lift-latest-${e.id}'),
      ),
      LiftRowState.past => value(
        log!,
        key: ValueKey('lift-readonly-${e.id}'),
        style: context.text.titleMedium,
      ),
      LiftRowState.none when session.canLog => outlined(
        S.logLiftShort,
        ValueKey('lift-log-${e.id}'),
      ),
      LiftRowState.none
          when session.readOnly == LiftReadOnly.future ||
              session.readOnly == LiftReadOnly.opensLater =>
        Text(
          S.liftNotLogged,
          key: ValueKey('lift-none-${e.id}'),
          style: context.text.titleMedium?.copyWith(
            color: palette.textSecondary,
          ),
        ),
      LiftRowState.absNote => outlined(
        S.noteShort,
        ValueKey('note-log-${e.id}'),
      ),
      LiftRowState.removed when session.canLog => tappable(
        value(log!, style: bold),
        ValueKey('lift-value-${e.id}'),
      ),
      LiftRowState.removed => value(
        log!,
        key: ValueKey('lift-readonly-${e.id}'),
        style: context.text.titleMedium,
      ),
      _ => null,
    };

    final noteIcon = switch (item.noteMark) {
      NoteMark.none => null,
      final mark => GestureDetector(
        key: ValueKey('note-mark-${e.id}-${mark.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: canOpenSheet ? openSheet : onOpen,
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Icon(
            Icons.sticky_note_2_outlined,
            size: 16,
            semanticLabel: S.noteShort,
            color: mark == NoteMark.today
                ? context.colors.primary
                : palette.textSecondary.withAlpha(150),
          ),
        ),
      ),
    };

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: e.nameVi),
              if (noteIcon != null)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: noteIcon,
                ),
            ],
          ),
          style: context.text.bodyLarge,
        ),
        const SizedBox(height: 4),
        RegionLabel(e.region),
        if (!e.active) ...[
          const SizedBox(height: 4),
          Text(
            S.notInLibrary,
            key: ValueKey('session-not-in-library-${e.id}'),
            style: context.text.bodySmall?.copyWith(color: palette.attention),
          ),
        ],
        if (stacked && action != null) ...[const SizedBox(height: 8), action],
      ],
    );

    return Semantics(
      button: true,
      label: '${e.nameVi}, ${Fmt.region(e.region)}',
      child: InkWell(
        key: ValueKey('exercise-${e.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(child: BodyMap(region: e.region)),
              const SizedBox(width: 14),
              Expanded(child: info),
              if (!stacked && action != null) ...[
                const SizedBox(width: 8),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh đáy cố định (UA2-09): "Đã ghi mức tạ {n}/{tổng} bài" (tổng không
/// tính bài bụng) và nút "Đã tập" khi buổi theo lịch đang "Chờ đánh dấu".
/// Trạng thái khác: chỉ dòng số bài khi n > 0.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.session, required this.exercises});

  final SessionView session;
  final SessionExercises exercises;

  @override
  Widget build(BuildContext context) {
    final n = exercises.logged;
    final done = session.canMarkDone;
    if (!done && n == 0) return const SizedBox.shrink();
    final count = Text(
      S.liftLoggedOf(n, exercises.total),
      key: const ValueKey('session-logged'),
      style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
    final button = done
        ? FilledButton(
            key: const ValueKey('session-done'),
            onPressed: () => SessionMarking.done(context, session.day),
            child: const Text(S.sessionDone, textAlign: TextAlign.center),
          )
        : null;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= _stackedScale;
    // Cỡ chữ lớn nhất: thanh đáy phóng tối đa 2 lần để danh sách bài vẫn còn
    // chỗ (như thông báo nhanh).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: toastMaxTextScale,
      child: Material(
        color: context.palette.card,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.palette.border)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: stacked || button == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      count,
                      if (button != null) ...[
                        const SizedBox(height: 8),
                        button,
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: count),
                      const SizedBox(width: 12),
                      Expanded(child: button),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

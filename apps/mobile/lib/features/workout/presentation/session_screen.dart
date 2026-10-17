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
              if (exercises != null)
                for (final g in exercises.groups) ...[
                  // Nhiều nhóm cơ: tiêu đề nhóm lớn, rồi tiêu đề vùng (UA2-17).
                  if (exercises.groups.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 20, left: 4),
                      child: Semantics(
                        header: true,
                        child: Text(
                          Fmt.muscle(g.group),
                          key: ValueKey('session-group-${g.group.name}'),
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  for (final r in g.regions) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          Fmt.region(r.region).toUpperCase(),
                          key: ValueKey('session-region-${r.region.id}'),
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
                          for (final (i, item) in r.items.indexed) ...[
                            if (i > 0) const Divider(indent: 16, endIndent: 16),
                            _ExerciseLine(
                              session: session,
                              item: item,
                              onOpen: () => context.push(
                                sessionExercisePath(
                                  tab,
                                  date,
                                  item.exercise.id,
                                ),
                              ),
                            ),
                          ],
                        ],
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

/// Một dòng bài (04 Bản 2 S-63, 6 tình huống): bên trái hình vùng cơ thu
/// nhỏ · tên · nhãn dụng cụ (chạm → S-67); bên phải nút "Ghi", con số đậm
/// (chạm → S-64 sửa), con số thường, hoặc trống. Bài bụng không có chỗ ghi
/// (FR2-12). Bài đã rời thư viện có ghi chú nhỏ (F20-E1).
class _ExerciseLine extends StatelessWidget {
  const _ExerciseLine({
    required this.session,
    required this.item,
    required this.onOpen,
  });

  final SessionView session;
  final SessionExercise item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final e = item.exercise;
    final log = item.log;
    final canLog = session.canLog && e.logsWeight;
    final palette = context.palette;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= _stackedScale;

    void openSheet() => showLiftLogSheet(
      context,
      date: session.date,
      exercise: e,
      existing: log,
    );

    // Bên phải dòng bài.
    final Widget? action = switch ((canLog, log)) {
      (true, final LiftLog l) => TextButton(
        key: ValueKey('lift-value-${e.id}'),
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: context.colors.onSurface,
          textStyle: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: openSheet,
        child: Text(Fmt.lift(l, e.liftUnit)),
      ),
      (true, null) when e.active => OutlinedButton(
        key: ValueKey('lift-log-${e.id}'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: const StadiumBorder(),
          side: BorderSide(color: context.colors.primary, width: 1.5),
          textStyle: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: openSheet,
        child: const Text(S.logLiftShort),
      ),
      (false, final LiftLog l) => Text(
        Fmt.lift(l, e.liftUnit),
        key: ValueKey('lift-readonly-${e.id}'),
        style: context.text.titleMedium,
      ),
      _ => null,
    };

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.nameVi, style: context.text.bodyLarge),
        const SizedBox(height: 4),
        EquipmentTag(e.equipment),
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

    if (stacked) {
      // Cỡ chữ lớn: con số mức tạ nằm dưới tên bài (04 Bản 2 §6.13).
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: '${e.nameVi}, ${Fmt.equipment(e.equipment)}',
              child: ExcludeSemantics(
                child: InkWell(
                  key: ValueKey('exercise-${e.id}'),
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                    child: BodyMap(region: e.region),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: info,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: '${e.nameVi}, ${Fmt.equipment(e.equipment)}',
            child: ExcludeSemantics(
              child: InkWell(
                key: ValueKey('exercise-${e.id}'),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      BodyMap(region: e.region),
                      const SizedBox(width: 14),
                      Expanded(child: info),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child:
              action ??
              ExcludeSemantics(
                child: Icon(Icons.chevron_right, color: palette.textSecondary),
              ),
        ),
      ],
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

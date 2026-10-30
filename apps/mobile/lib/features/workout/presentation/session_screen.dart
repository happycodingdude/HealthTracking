import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../application/session_providers.dart';
import 'session_log_list.dart';

/// Đường dẫn S-63 của buổi ngày [date], mở trong tab [tab] (Hôm nay hoặc
/// Tập luyện, NAV-9). Buổi hôm nay nằm ở Hôm nay (05 Bản 4 TD4-05): đường
/// dẫn này của hôm nay được chuyển hướng về tab Hôm nay.
String sessionPath(AppTab tab, LocalDate date) =>
    '${tab.path}/session/${date.toKey()}';

/// Đường dẫn S-67 mở từ S-63 (cùng tab).
String sessionExercisePath(AppTab tab, LocalDate date, String exerciseId) =>
    '${sessionPath(tab, date)}/exercise/${Uri.encodeComponent(exerciseId)}';

/// Đường dẫn S-67 mở từ danh sách bài ở Hôm nay (buổi hôm nay).
String todayExercisePath(String exerciseId, LocalDate date) =>
    '${AppTab.today.path}/exercise/${Uri.encodeComponent(exerciseId)}'
    '?date=${date.toKey()}';

/// Mở buổi ngày [date]: hôm nay → tab Hôm nay (danh sách bài nằm ở đó);
/// ngày khác → S-63 trong tab đang mở (S-21 từ Lịch hoặc S-25; thông báo
/// nhanh của S-24).
void openSession(BuildContext context, LocalDate date) {
  final shell = StatefulNavigationShell.maybeOf(context);
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final today = LocalDate.fromDateTime(container.read(clockProvider).now());
  if (date == today) {
    router.go(AppTab.today.path);
    return;
  }
  final tab = shell != null && shell.currentIndex == AppTab.today.index
      ? AppTab.today
      : AppTab.schedule;
  router.push(sessionPath(tab, date));
}

/// S-63 — Buổi tập ngày khác (04 Bản 4 S-63): tiêu đề giữa = nhóm cơ; góc
/// phải dấu tích / gạch (buổi đã qua) hoặc ổ khóa (buổi chưa đến); hàng số
/// liệu Ngày · Giờ · Đã ghi n / m (buổi đã qua); danh sách bài như Hôm nay
/// nhưng không ô tick, chạm hàng số không mở ghi.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.date, required this.tab});

  final LocalDate date;

  /// Tab mở màn hình.
  final AppTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(date));
    final exercises = ref.watch(sessionExercisesProvider(date));
    if (session == null) {
      return const IronlySubPage(title: '', children: []);
    }
    final day = session.day;
    final title = session.isExtra
        ? '+ ${Fmt.musclesTitle(session.muscles)}'
        : Fmt.musclesTitle(session.muscles);
    final status = session.status;
    final future = session.window is LiftWindowNotOpen;
    final (GlyphStatus glyph, String label) = session.isExtra
        ? (
            GlyphStatus.extra,
            session.readOnly == LiftReadOnly.pastExtra
                ? S.readOnlyPastExtra
                : S.extraSession,
          )
        : future
        ? (GlyphStatus.locked, S.readOnlyFuture)
        : switch (status!.state) {
            SessionState.done => (GlyphStatus.done, S.sessionDone),
            SessionState.skipped => (GlyphStatus.skipped, S.sessionSkipped),
            SessionState.autoSkipped => (
              GlyphStatus.skipped,
              S.statusAutoSkipped,
            ),
            SessionState.awaitingMark => (
              GlyphStatus.pending,
              S.statusAwaiting,
            ),
            SessionState.upcoming => (GlyphStatus.locked, S.readOnlyFuture),
          };
    final locked = status?.locked ?? false;
    final showLogged = !future && exercises != null && exercises.total > 0;

    Widget stat(String label, String value, {Key? key}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: IronlyText.columnLabel),
        const SizedBox(height: 2),
        Text(
          value,
          key: key,
          style: IronlyText.body.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return IronlySubPage(
      title: title,
      listKey: const ValueKey('session-list'),
      trailing: Padding(
        padding: const EdgeInsets.only(right: TokenSpace.s2),
        child: StatusGlyph(
          glyph,
          key: const ValueKey('session-status'),
          label: locked ? '$label, ${S.statusLocked}' : label,
        ),
      ),
      children: [
        Wrap(
          key: const ValueKey('session-stats'),
          spacing: TokenSpace.s6,
          runSpacing: TokenSpace.s3,
          children: [
            stat(S.statDate, Fmt.weekdayDate(date)),
            if (day.time != null) stat(S.statTime, Fmt.time(day.time!)),
            if (showLogged)
              stat(
                S.statLogged,
                S.ratio(exercises.logged, exercises.total),
                key: const ValueKey('session-logged'),
              ),
          ],
        ),
        const SizedBox(height: TokenSpace.s5),
        SessionLogList(date: date, tab: tab),
      ],
    );
  }
}

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../schedule/presentation/extra_session_sheet.dart';
import '../../schedule/presentation/pause_sheet.dart';
import '../../schedule/presentation/session_marking.dart';
import '../../schedule/presentation/session_status_sheet.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/presentation/session_log_list.dart';
import '../application/today_screen_state.dart';
import 'today_cards.dart';

/// S-10 — Hôm nay (04 Bản 4 S-10): tiêu đề "Hôm nay" + dấu trạng thái buổi
/// (hoặc ngày) góc phải; sáu trạng thái H1 → H6 của 03 Bản 4 §6.3. Ngày có
/// buổi: hàng số liệu, danh sách bài với hàng ghi tạ, thực đơn một dòng.
/// Không "Buổi chưa đánh dấu", không "Chưa đồng bộ" (BR4-14).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayScreenStateProvider);
    if (state == null) {
      return const IronlyTabPage(tab: AppTab.today, title: S.tabToday);
    }
    _openExtraSessionLink(context, state);
    final hasSession =
        state.kind != TodayKind.noSchedule && state.kind != TodayKind.rest;
    // Banner tạm dừng dưới tiêu đề (04 Bản 5 S-10 H7, H8).
    final pause = state.pause;
    final banner = pause == null
        ? null
        : PauseBanner(
            until: Fmt.shortWeekdayDate(pause.lastDay),
            onEnd: () => confirmEndPause(context, ref, pause),
          );
    return IronlyTabPage(
      tab: AppTab.today,
      title: S.tabToday,
      listKey: const ValueKey('today-list'),
      trailing: _Trailing(state: state),
      // Ngày có buổi: hàng tiêu đề (dấu chốt buổi) + hàng số liệu neo trên
      // cùng, danh sách bài cuộn bên dưới.
      pinned: hasSession
          ? (banner == null
                ? SessionStats(state: state)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      banner,
                      const SizedBox(height: TokenSpace.s4),
                      SessionStats(state: state),
                    ],
                  ))
          : null,
      children: switch (state.kind) {
        TodayKind.noSchedule => const [NoScheduleCard(), CardGap(), MenuCard()],
        TodayKind.rest => [
          if (banner != null) ...[banner, const CardGap()],
          RestCard(state: state),
          const CardGap(),
          WeekCard(progress: state.progress, today: state.today),
          const CardGap(),
          const MenuCard(),
        ],
        _ => [
          if (_showList(ref, state))
            SessionLogList(date: state.today, tab: AppTab.today)
          else
            // H7 (Bạn chọn B 06/11/2026): ngày tạm dừng không hiện danh sách
            // bài; "Vẫn tập hôm nay" → hiện lại, tạm dừng giữ nguyên.
            IronlyButton.secondary(
              key: const ValueKey('train-anyway'),
              label: S.trainAnywayToday,
              onPressed: () =>
                  ref.read(trainDuringPauseProvider.notifier).show(state.today),
            ),
          const MenuLine(),
        ],
      },
    );
  }
}

/// Danh sách bài hôm nay: luôn hiện, trừ buổi Tạm dừng (H7) chưa bấm "Vẫn tập
/// hôm nay" và chưa có gì trong buổi (mức tạ, ghi chú, mức thoải mái, đổi /
/// bỏ qua / thêm bài).
bool _showList(WidgetRef ref, TodayScreenState state) {
  if (!state.pausedScheduled) return true;
  if (ref.watch(trainDuringPauseProvider).contains(state.today)) return true;
  final exercises = ref.watch(sessionExercisesProvider(state.today));
  return exercises != null &&
      exercises.all.any(
        (e) =>
            SessionExercises.hasRecords(e) ||
            e.item.skipped ||
            e.item.role != SessionExerciseRole.original,
      );
}

/// Thẻ ngày nghỉ (S-71 rút gọn) mở `ironly://extra-session` → Hôm nay
/// `?open=extra-session` (04 Bản 5 §6.3): bỏ tham số, rồi mở S-24 cho hôm nay
/// nếu còn thêm được Buổi tập thêm (F25-R63, F05-R64); không thì chỉ ở Hôm nay.
void _openExtraSessionLink(BuildContext context, TodayScreenState state) {
  final GoRouterState route;
  try {
    route = GoRouterState.of(context);
  } on GoError {
    return;
  }
  if (route.uri.queryParameters['open'] != extraSessionLink) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    GoRouter.of(context).go(AppTab.today.path);
    if (state.canAddExtra) {
      showExtraSessionSheet(context, state.today);
    }
  });
}

/// Góc phải tiêu đề: ngày (H1, H2, H3) hoặc dấu trạng thái buổi (H4 → H6,
/// buổi tập thêm). H4: ô vuông viền cam → S-65; H5 / H6: dấu → S-23.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.state});

  final TodayScreenState state;

  @override
  Widget build(BuildContext context) {
    final date = Text(
      Fmt.weekdayDate(state.today),
      key: const ValueKey('today-date'),
      style: IronlyText.caption,
    );
    final day = state.day;
    // H7 (04 Bản 5 S-10): vòng hai vạch thay ô tick; chạm → S-65 từ giờ tập.
    if (state.pausedScheduled) {
      final canMark = state.session?.canMarkDone ?? false;
      return StatusGlyph(
        GlyphStatus.paused,
        key: ValueKey(canMark ? 'today-mark-done' : 'today-status'),
        label: S.statusPaused,
        onTap: canMark ? () => SessionMarking.done(context, day!) : null,
      );
    }
    return switch (state.kind) {
      TodayKind.noSchedule || TodayKind.rest => date,
      TodayKind.notStarted => Semantics(
        container: true,
        label: '${Fmt.weekdayDate(state.today)}, ${S.statusUpcoming}',
        child: ExcludeSemantics(child: date),
      ),
      TodayKind.logging => StatusGlyph(
        GlyphStatus.markDone,
        key: const ValueKey('today-mark-done'),
        label: S.statusAwaiting,
        onTap: () => SessionMarking.done(context, day!),
      ),
      TodayKind.done => StatusGlyph(
        GlyphStatus.done,
        key: const ValueKey('today-status'),
        label: S.sessionDone,
        onTap: () => showSessionStatusSheet(context, state.today),
      ),
      TodayKind.skipped => StatusGlyph(
        GlyphStatus.skipped,
        key: const ValueKey('today-status'),
        label: state.session?.status?.state == SessionState.autoSkipped
            ? S.statusAutoSkipped
            : S.sessionSkipped,
        onTap: () => showSessionStatusSheet(context, state.today),
      ),
      TodayKind.extra => const StatusGlyph(
        GlyphStatus.extra,
        key: ValueKey('today-status'),
        label: S.extraSession,
      ),
    };
  }
}

/// Hàng số liệu (04 Bản 4 S-10 H3 → H6): BUỔI "Ngực · 18:00" (cam) hoặc nhóm
/// cơ đã tập (trắng) · ĐÃ GHI n / m (cam, khi ghi được) · TUẦN n / m.
class SessionStats extends ConsumerWidget {
  const SessionStats({super.key, required this.state});

  final TodayScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final session = state.session!;
    final day = state.day!;
    final muscles = Fmt.musclesTitle(session.muscles);
    final (String sessionValue, Color sessionColor) = switch (state.kind) {
      TodayKind.notStarted ||
      TodayKind.logging => ('$muscles · ${Fmt.time(day.time!)}', t.accent),
      TodayKind.extra => ('+ $muscles', t.accent),
      _ => (muscles, t.textPrimary),
    };
    final exercises = ref.watch(sessionExercisesProvider(state.today));
    // H6 (không tập) chỉ xem (03 Bản 4 §6.3): không đếm "Đã ghi".
    final showLogged =
        session.canLog &&
        state.kind != TodayKind.skipped &&
        exercises != null &&
        exercises.total > 0;
    final progress = state.progress;
    Widget stat(String label, String value, Color color, {Key? key}) => Column(
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
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    return Wrap(
      key: const ValueKey('session-stats'),
      spacing: TokenSpace.s6,
      runSpacing: TokenSpace.s3,
      children: [
        stat(
          S.statSession,
          sessionValue,
          sessionColor,
          key: const ValueKey('stat-session'),
        ),
        if (showLogged)
          stat(
            S.statLogged,
            S.ratio(exercises.logged, exercises.total),
            t.accent,
            key: const ValueKey('stat-logged'),
          ),
        if (progress != null)
          stat(
            S.statWeek,
            S.ratio(progress.done, progress.planned),
            t.textPrimary,
            key: const ValueKey('stat-week'),
          ),
      ],
    );
  }
}

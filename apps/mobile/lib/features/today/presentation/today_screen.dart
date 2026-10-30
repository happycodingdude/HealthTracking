import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
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
    return IronlyTabPage(
      tab: AppTab.today,
      title: S.tabToday,
      listKey: const ValueKey('today-list'),
      trailing: _Trailing(state: state),
      children: switch (state.kind) {
        TodayKind.noSchedule => const [NoScheduleCard(), CardGap(), MenuCard()],
        TodayKind.rest => [
          RestCard(state: state),
          const CardGap(),
          WeekCard(progress: state.progress, today: state.today),
          const CardGap(),
          const MenuCard(),
        ],
        _ => [
          SessionStats(state: state),
          const SizedBox(height: TokenSpace.s5),
          SessionLogList(date: state.today, tab: AppTab.today),
          const MenuLine(),
        ],
      },
    );
  }
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

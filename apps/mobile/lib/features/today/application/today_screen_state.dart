import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../workout/application/session_providers.dart';
import 'progress_view.dart';
import 'today_view.dart';

/// Trạng thái của Hôm nay (03 Bản 4 §6.3 H1 → H6; 05 Bản 4 §6.5.2
/// `todayScreenStateProvider`), thêm [extra] = ngày nghỉ đã có buổi tập thêm
/// hôm nay (danh sách bài của buổi thêm nằm ngay ở Hôm nay).
enum TodayKind {
  /// H1: chưa có lịch tuần.
  noSchedule,

  /// H2: ngày nghỉ (kể cả chủ nhật), chưa có buổi tập thêm.
  rest,

  /// Ngày nghỉ đã ghi buổi tập thêm (chốt ngay khi lưu).
  extra,

  /// H3: có buổi, chưa đến giờ.
  notStarted,

  /// H4: có buổi, đã đến giờ, chờ đánh dấu.
  logging,

  /// H5: đã tập.
  done,

  /// H6: không tập (tự đánh dấu hoặc tự động).
  skipped,
}

final class TodayScreenState {
  const TodayScreenState({
    required this.kind,
    required this.today,
    this.day,
    this.session,
    this.next,
    this.canAddExtra = false,
    this.progress,
  });

  final TodayKind kind;
  final LocalDate today;
  final PlanDay? day;

  /// Buổi hôm nay (theo lịch hoặc buổi tập thêm); null ở H1, H2.
  final SessionView? session;

  /// Buổi tới (H2).
  final PlanDay? next;

  /// Nút "+ Buổi thêm" (H2, không có ở chủ nhật và khi đã quá giờ).
  final bool canAddExtra;
  final WeeklyProgress? progress;

  bool get hasSession => session != null;
}

final todayScreenStateProvider = Provider<TodayScreenState?>((ref) {
  final now = ref.watch(nowProvider);
  final today = LocalDate.fromDateTime(now);
  final schedule = ref.watch(scheduleStateProvider);
  final dayAsync = ref.watch(dayProvider(today));
  if (schedule == null || !dayAsync.hasValue) return null;
  final progress = ref.watch(
    weekProgressProvider(ProgressWeek.containing(today)),
  );
  if (!schedule.hasSchedule) {
    return TodayScreenState(
      kind: TodayKind.noSchedule,
      today: today,
      progress: progress,
    );
  }
  final day = dayAsync.value;
  final session = ref.watch(sessionProvider(today));
  if (day == null || session == null) {
    return TodayScreenState(
      kind: TodayKind.rest,
      today: today,
      day: day,
      next: ref.watch(nextSessionProvider),
      canAddExtra: day != null && ExtraSessionRules.canAdd(day, now),
      progress: progress,
    );
  }
  final TodayKind kind;
  if (session.isExtra) {
    kind = TodayKind.extra;
  } else {
    kind = switch (session.status!.state) {
      SessionState.upcoming => TodayKind.notStarted,
      SessionState.awaitingMark => TodayKind.logging,
      SessionState.done => TodayKind.done,
      SessionState.skipped || SessionState.autoSkipped => TodayKind.skipped,
    };
  }
  return TodayScreenState(
    kind: kind,
    today: today,
    day: day,
    session: session,
    progress: progress,
  );
});

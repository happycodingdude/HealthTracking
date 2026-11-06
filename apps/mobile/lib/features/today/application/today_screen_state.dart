import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../workout/application/session_providers.dart';
import 'progress_view.dart';
import 'today_view.dart';

/// Trạng thái của Hôm nay (03 Bản 4 §6.3 H1 → H6; 05 Bản 4 §6.5.2
/// `todayScreenStateProvider`), thêm [extra] = ngày nghỉ đã có buổi tập thêm
/// hôm nay (danh sách bài của buổi thêm nằm ngay ở Hôm nay). Bản 5 (F20-R66,
/// 04 Bản 5 S-10): H7 = buổi Tạm dừng hôm nay — [notStarted] / [logging] theo
/// giờ kèm [TodayScreenState.pausedScheduled]; H8 = ngày nghỉ trong khoảng tạm
/// dừng — [rest] kèm [TodayScreenState.pausedRest].
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
    this.pause,
    this.sessionPaused = false,
    this.nextPaused = false,
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

  /// Khoảng tạm dừng phủ hôm nay (banner H7, H8 và mọi trạng thái hôm nay
  /// trong khoảng, 04 Bản 5 §6.2); null = hôm nay không tạm dừng.
  final SchedulePause? pause;

  /// Buổi theo lịch hôm nay là "Tạm dừng" (chưa đánh dấu, trong khoảng).
  final bool sessionPaused;

  /// Buổi tới (H2 / H8) rơi vào khoảng tạm dừng: hai vạch nhỏ sau dòng buổi
  /// tới (04 Bản 5 S-10 H8).
  final bool nextPaused;

  bool get hasSession => session != null;

  /// H7 — Tạm dừng, ngày có buổi (05 Bản 5 §6.4.3 `pausedScheduled`).
  bool get pausedScheduled => sessionPaused;

  /// H8 — Tạm dừng, ngày nghỉ (05 Bản 5 §6.4.3 `pausedRest`).
  bool get pausedRest => kind == TodayKind.rest && pause != null;

  /// Đã tới phòng gym trước giờ tập (05 Bản 5 §6.4.3 `opened`, FD5-01 = A):
  /// buổi mở từ lúc tới gym — H4 ghi tạ, "Đã tập" được trước giờ tập.
  bool get opened {
    final d = session?.day;
    final at = d?.openedAt;
    if (d == null || at == null || !d.isWorkout || d.time == null) {
      return false;
    }
    return SessionRules.opensAt(d).isBefore(SessionRules.startsAt(d));
  }
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
  final pauses = ref.watch(pausesProvider).value ?? const <SchedulePause>[];
  final pause = PauseRules.active(pauses, today);
  final todayPause = pause != null && pause.covers(today) ? pause : null;
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
    final next = ref.watch(nextSessionProvider);
    return TodayScreenState(
      kind: TodayKind.rest,
      today: today,
      day: day,
      next: next,
      canAddExtra: day != null && ExtraSessionRules.canAdd(day, now),
      progress: progress,
      pause: todayPause,
      nextPaused: next != null && PauseRules.isPaused(next.date, pauses),
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
      // H7: như H3 / H4 theo giờ (và lúc tới gym, FD5-01).
      SessionState.paused =>
        now.isBefore(SessionRules.opensAt(day))
            ? TodayKind.notStarted
            : TodayKind.logging,
    };
  }
  return TodayScreenState(
    kind: kind,
    today: today,
    day: day,
    session: session,
    progress: progress,
    pause: todayPause,
    sessionPaused: session.status?.state == SessionState.paused,
  );
});

/// Ngày tạm dừng (H7) mà Bạn đã bấm "Vẫn tập hôm nay" (Bạn chọn B
/// 06/11/2026): danh sách bài hiện lại cho ngày đó, khoảng tạm dừng giữ
/// nguyên. Giữ trong lúc app chạy; buổi đã có ghi / đổi / bỏ / thêm bài thì
/// danh sách tự hiện (TodayScreen).
final trainDuringPauseProvider =
    NotifierProvider<TrainDuringPause, Set<LocalDate>>(TrainDuringPause.new);

class TrainDuringPause extends Notifier<Set<LocalDate>> {
  @override
  Set<LocalDate> build() => const {};

  void show(LocalDate date) => state = {...state, date};
}

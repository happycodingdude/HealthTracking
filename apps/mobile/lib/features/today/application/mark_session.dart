import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../workout/application/session_item_edits.dart';
import '../../workout/data/lift_log_repository.dart';

/// Chưa xác nhận hộp chốt buổi S-65: chưa lưu gì (F05-V22, 06 Bản 2 ED2-04).
final class NotConfirmedException implements Exception {
  const NotConfirmedException();

  @override
  String toString() => 'NotConfirmedException';
}

/// Thẻ màn hình khóa (05 Bản 3 §6.4.4, VS-41): "Đã tập" / "Không tập" tắt
/// thẻ của ngày đó tại chỗ.
abstract interface class SessionMarkHooks {
  Future<void> sessionMarked(LocalDate date);
}

final class NoSessionMarkHooks implements SessionMarkHooks {
  const NoSessionMarkHooks();

  @override
  Future<void> sessionMarked(LocalDate date) async {}
}

final sessionMarkHooksProvider = Provider<SessionMarkHooks>(
  (ref) => const NoSessionMarkHooks(),
);

/// Ghi một bản ngày đã kiểm tra bằng domain + outbox trong một transaction.
/// Giao diện đổi ngay nhờ stream của Drift, không chờ mạng (P6, F05-E28).
abstract base class _DayWrite {
  _DayWrite({
    required AppDatabase db,
    required ScheduleRepository schedule,
    required OutboxWriter outbox,
    required Clock clock,
  }) : _db = db,
       _schedule = schedule,
       _outbox = outbox,
       _clock = clock;

  final AppDatabase _db;
  final ScheduleRepository _schedule;
  final OutboxWriter _outbox;
  final Clock _clock;

  static const _codec = DayCodec();

  /// [endsLiveActivity]: "Đã tập" / "Không tập" — mutation kèm
  /// `liveActivityEnded: true` để server không gửi push tắt thừa (05 Bản 3
  /// §6.6.5), rồi tắt thẻ tại chỗ.
  Future<PlanDay> _write(
    LocalDate date,
    PlanDay Function(PlanDay? day, DateTime now) change, {
    SessionMarkHooks? endsLiveActivity,
  }) async {
    final updated = await _db.transaction(() async {
      final updated = change(await _schedule.day(date), _clock.now());
      await _schedule.putDay(updated);
      await _outbox.enqueue(SyncEntities.day, date.toKey(), SyncOp.upsert, {
        ..._codec.encode(updated),
        if (endsLiveActivity != null) 'liveActivityEnded': true,
      });
      return updated;
    });
    await endsLiveActivity?.sessionMarked(date);
    return updated;
  }
}

/// "Đã tập" (F05-R61, 05 Bản 2 TD2-08): chỉ khi Bạn đã xác nhận hộp S-65
/// ([confirmed]); ghi `mark = done`, nhóm cơ thực tế = nhóm cơ của lịch,
/// `markedAt`. Từ giờ mở buổi ([LiftWindow], FD5-01) đến hết ngày ([DayLock]);
/// đổi lại được trong ngày. Ném [NotConfirmedException] hoặc [MarkException].
final class MarkSessionDone extends _DayWrite {
  MarkSessionDone({
    required super.db,
    required super.schedule,
    required super.outbox,
    required super.clock,
    SessionMarkHooks hooks = const NoSessionMarkHooks(),
    Future<List<SessionItem>> Function(LocalDate date)? sessionItems,
  }) : _hooks = hooks,
       _sessionItems = sessionItems;

  final SessionMarkHooks _hooks;

  /// Danh sách bài của buổi (FC5-03): mọi bài bỏ qua → lưu "Không tập".
  final Future<List<SessionItem>> Function(LocalDate date)? _sessionItems;

  /// FC5-03, F29-R5: bỏ qua tất cả bài rồi "Đã tập" (hộp S-79) → buổi lưu
  /// **"Không tập"**; còn lại lưu "Đã tập".
  Future<PlanDay> call(LocalDate date, {required bool confirmed}) async {
    if (!confirmed) throw const NotConfirmedException();
    final items = await _sessionItems?.call(date);
    final allSkipped = items != null && SessionList.allSkipped(items);
    return _write(date, (day, now) {
      if (day == null) throw const MarkException(MarkError.notWorkout);
      return allSkipped
          ? SessionRules.markSkipped(day, now: now)
          : SessionRules.markDone(day, now: now);
    }, endsLiveActivity: _hooks);
  }
}

/// "Không tập" (F05-R62, FC5-02): lưu ngay, không cần xác nhận, từ đầu ngày
/// đến hết ngày, kể cả đổi từ "Đã tập" (D5-02 = B). Ném [MarkException]. Mức
/// tạ, ghi chú, bài trong buổi giữ nguyên (FD2-02, A5-12).
final class MarkSessionSkipped extends _DayWrite {
  MarkSessionSkipped({
    required super.db,
    required super.schedule,
    required LiftLogRepository liftLogs,
    required super.outbox,
    required super.clock,
    SessionMarkHooks hooks = const NoSessionMarkHooks(),
  }) : _liftLogs = liftLogs,
       _hooks = hooks;

  final LiftLogRepository _liftLogs;
  final SessionMarkHooks _hooks;

  /// Số bài đã có mức tạ trong buổi ngày [date]: > 0 thì UI hỏi trước khi
  /// lưu "Buổi này đã có mức tạ của {N} bài." (F05-R28).
  Future<int> liftLogCount(LocalDate date) => _liftLogs.countDay(date);

  Future<PlanDay> call(LocalDate date) => _write(date, (day, now) {
    if (day == null) throw const MarkException(MarkError.notWorkout);
    return SessionRules.markSkipped(day, now: now);
  }, endsLiveActivity: _hooks);
}

/// Bỏ đánh dấu (FC5-13, F05-R65): buổi về "Chờ đánh dấu" đến hết ngày; mức
/// tạ, ghi chú, mức thoải mái, bài đổi / bỏ / thêm giữ nguyên (A5-12). Thẻ màn
/// hình khóa không làm gì tại chỗ: server bật lại (TA5-06, 05 Bản 5 §6.4.4).
/// Ném [MarkException].
final class UnmarkSession extends _DayWrite {
  UnmarkSession({
    required super.db,
    required super.schedule,
    required super.outbox,
    required super.clock,
  });

  Future<PlanDay> call(LocalDate date) => _write(date, (day, now) {
    if (day == null) throw const MarkException(MarkError.notWorkout);
    return SessionRules.unmark(day, now: now);
  });
}

/// Thêm buổi tập thêm (F05-R31 → R35, F05-R64): chỉ cho hôm nay, đã có lịch
/// tuần; lưu ngay (Bản 5 bỏ hộp "Sau khi lưu, buổi này không sửa được nữa").
/// Ném [ExtraException].
final class AddExtraSession extends _DayWrite {
  AddExtraSession({
    required super.db,
    required super.schedule,
    required super.outbox,
    required super.clock,
  });

  Future<PlanDay> call(LocalDate date, List<MuscleGroup> muscles) async {
    // F05-R31: chưa có lịch tuần thì không có buổi tập thêm.
    final hasSchedule = await _schedule.template() != null;
    return _write(date, (day, now) {
      if (day == null) {
        throw ExtraException(
          hasSchedule ? ExtraError.notRestDay : ExtraError.noSchedule,
        );
      }
      return ExtraSessionRules.add(
        day,
        muscles,
        now: now,
        hasSchedule: hasSchedule,
      );
    });
  }
}

/// Sửa nhóm cơ / xóa buổi tập thêm (F05-R64, F05-E65): chỉ hôm nay, đến hết
/// ngày. [muscles] null = xóa. Ném [ExtraException].
final class EditExtraSession extends _DayWrite {
  EditExtraSession({
    required super.db,
    required super.schedule,
    required super.outbox,
    required super.clock,
  });

  Future<PlanDay> call(LocalDate date, List<MuscleGroup>? muscles) =>
      _write(date, (day, now) {
        if (day == null) throw const ExtraException(ExtraError.notRestDay);
        return muscles == null
            ? ExtraSessionRules.delete(day, now: now)
            : ExtraSessionRules.edit(day, muscles, now: now);
      });
}

final markSessionDoneProvider = Provider<MarkSessionDone>(
  (ref) => MarkSessionDone(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
    hooks: ref.watch(sessionMarkHooksProvider),
    sessionItems: ref.watch(sessionItemsReaderProvider).call,
  ),
);

final markSessionSkippedProvider = Provider<MarkSessionSkipped>(
  (ref) => MarkSessionSkipped(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    liftLogs: ref.watch(liftLogRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
    hooks: ref.watch(sessionMarkHooksProvider),
  ),
);

final unmarkSessionProvider = Provider<UnmarkSession>(
  (ref) => UnmarkSession(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);

final addExtraSessionProvider = Provider<AddExtraSession>(
  (ref) => AddExtraSession(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);

final editExtraSessionProvider = Provider<EditExtraSession>(
  (ref) => EditExtraSession(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);

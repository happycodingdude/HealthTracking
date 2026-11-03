import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/reminders.dart';
import '../../today/application/mark_session.dart';
import '../data/schedule_pause_repository.dart';

/// Tạm dừng lịch tập (03 Bản 5 F-31; 05 Bản 5 §6.4.2 `StartPause`,
/// `UpdatePauseEnd`, `EndPauseEarly`): mỗi thao tác là một transaction (bản
/// ghi + outbox `schedule_pause`), xong thì hẹn lại nhắc (F04-R61). Đặt tạm
/// dừng phủ hôm nay → tắt thẻ của hôm nay tại chỗ (F31-R7, §6.4.4); bật lại
/// sau kết thúc sớm do server (TD5-13). Ném [PauseException].
final class PauseEdits {
  PauseEdits({
    required AppDatabase db,
    required SchedulePauseRepository pauses,
    required OutboxWriter outbox,
    required ReminderScheduler reminders,
    required SessionMarkHooks liveActivity,
    required Clock clock,
    Uuid uuid = const Uuid(),
  }) : _db = db,
       _pauses = pauses,
       _outbox = outbox,
       _reminders = reminders,
       _liveActivity = liveActivity,
       _clock = clock,
       _uuid = uuid;

  final AppDatabase _db;
  final SchedulePauseRepository _pauses;
  final OutboxWriter _outbox;
  final ReminderScheduler _reminders;
  final SessionMarkHooks _liveActivity;
  final Clock _clock;
  final Uuid _uuid;

  static const _codec = SchedulePauseCodec();

  LocalDate get _today => LocalDate.fromDateTime(_clock.now());

  Future<void> _put(SchedulePause p) async {
    await _pauses.put(p);
    await _outbox.enqueue(
      SyncEntities.schedulePause,
      p.id,
      SyncOp.upsert,
      _codec.encode(p),
    );
  }

  /// "Tạm dừng" ở S-76 (F31-R1, R2, R7).
  Future<SchedulePause> start(LocalDate from, LocalDate to) async {
    final today = _today;
    final pause = await _db.transaction(() async {
      final p = PauseRules.start(
        id: _uuid.v4(),
        start: from,
        end: to,
        others: await _pauses.all(),
        today: today,
      );
      await _put(p);
      return p;
    });
    await _reminders.reschedule();
    if (pause.covers(today)) await _liveActivity.sessionMarked(today);
    return pause;
  }

  /// "Lưu" ở S-76 khi đang có khoảng: sửa ngày kết thúc (F31-R9).
  Future<SchedulePause> updateEnd(SchedulePause pause, LocalDate end) async {
    final updated = await _db.transaction(() async {
      final all = await _pauses.all();
      final p = PauseRules.updateEnd(
        all.firstWhere((x) => x.id == pause.id, orElse: () => pause),
        end,
        others: all.where((x) => x.id != pause.id),
        today: _today,
      );
      await _put(p);
      return p;
    });
    await _reminders.reschedule();
    return updated;
  }

  /// "Kết thúc tạm dừng" / "Kết thúc" ở banner (F31-R8): khoảng kết thúc hôm
  /// qua; chưa qua ngày nào thì xóa khoảng.
  Future<void> endEarly(SchedulePause pause) async {
    await _db.transaction(() async {
      final ended = PauseRules.endEarly(pause, _today);
      if (ended == null) {
        await _pauses.delete(pause.id);
        await _outbox.enqueue(
          SyncEntities.schedulePause,
          pause.id,
          SyncOp.delete,
          null,
        );
      } else {
        await _put(ended);
      }
    });
    await _reminders.reschedule();
  }
}

final pauseEditsProvider = Provider<PauseEdits>(
  (ref) => PauseEdits(
    db: ref.watch(databaseProvider),
    pauses: ref.watch(schedulePauseRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    reminders: ref.watch(reminderSchedulerProvider),
    liveActivity: ref.watch(sessionMarkHooksProvider),
    clock: ref.watch(clockProvider),
  ),
);

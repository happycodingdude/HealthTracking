import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/calorie_updates.dart';
import '../../me/data/profile_repository.dart';
import '../data/weight_repository.dart';

/// Kết quả một lần ghi, sửa, xóa số cân. [latestChanged] = số cân mới nhất
/// đổi (F07-R5); khi đó mức calo được tính lại ([calorie], F02-R7, F07-AC6).
typedef WeightChange = ({
  bool latestChanged,
  WeightPoint? latest,
  CalorieOutcome calorie,
});

/// Ghi, sửa, xóa số cân theo tuần (F-07). Mỗi thao tác là một transaction
/// (bản ghi + outbox, 06 §6.4.2); không cần mạng (F07-E3).
final class WeightEdits {
  WeightEdits({
    required AppDatabase db,
    required WeightRepository weights,
    required ProfileRepository profiles,
    required OutboxWriter outbox,
    required CalorieUpdates calorie,
    required Clock clock,
  }) : _db = db,
       _weights = weights,
       _profiles = profiles,
       _outbox = outbox,
       _calorie = calorie,
       _clock = clock;

  final AppDatabase _db;
  final WeightRepository _weights;
  final ProfileRepository _profiles;
  final OutboxWriter _outbox;
  final CalorieUpdates _calorie;
  final Clock _clock;

  static const _codec = WeightCodec();

  Future<WeightLog> _log() async => WeightLog(await _weights.all());

  /// Ghi hoặc thay số cân của tuần [week] (F07-R1). Ném [WeightException].
  Future<WeightChange> log(LocalDate week, int kgX10) =>
      _db.transaction(() async {
        if (!WeightRules.isValidKgX10(kgX10)) {
          throw const WeightException(WeightError.outOfRange);
        }
        final setup = (await _profiles.get())?.setupDate;
        final today = LocalDate.fromDateTime(_clock.now());
        if (setup == null ||
            !WeightLog.canLog(week, setupDate: setup, today: today)) {
          throw const WeightException(WeightError.invalidWeek);
        }
        final before = await _log();
        final inputs = await _calorie.snapshot();
        await _weights.put(week, kgX10);
        await _outbox.enqueue(
          SyncEntities.weight,
          week.toKey(),
          SyncOp.upsert,
          _codec.encode(WeightData(weightKgX10: kgX10)),
        );
        return _change(before, await _log(), inputs);
      });

  /// Xóa số cân tuần [week] (F07-R3, F07-E2). Ném [WeightException] khi đó
  /// là số cân duy nhất còn lại.
  Future<WeightChange> delete(LocalDate week) => _db.transaction(() async {
    final before = await _log();
    if (!before.canDelete(week)) {
      throw const WeightException(WeightError.onlyOne);
    }
    final inputs = await _calorie.snapshot();
    await _weights.delete(week);
    await _outbox.enqueue(
      SyncEntities.weight,
      week.toKey(),
      SyncOp.delete,
      null,
    );
    return _change(before, await _log(), inputs);
  });

  /// F07-R5: chỉ khi số cân mới nhất (tuần hoặc số) đổi mới tính lại calo.
  Future<WeightChange> _change(
    WeightLog before,
    WeightLog after,
    CalorieInputs inputs,
  ) async {
    final changed = before.latest != after.latest;
    return (
      latestChanged: changed,
      latest: after.latest,
      calorie: changed
          ? await _calorie.recalc(inputs, reason: CaloriePendingReason.weight)
          : const CalorieUnchanged(),
    );
  }
}

final weightEditsProvider = Provider<WeightEdits>(
  (ref) => WeightEdits(
    db: ref.watch(databaseProvider),
    weights: ref.watch(weightRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    calorie: ref.watch(calorieUpdatesProvider),
    clock: ref.watch(clockProvider),
  ),
);

import 'package:domain/domain.dart';

import 'codecs.dart';
import 'json_reader.dart';
import 'sync_entities.dart';

/// Entity `lift_log` (push + pull, 05 Bản 2 §6.6.2): key `{date}:{exerciseId}`;
/// `data` có `date`, `exerciseId` (phải khớp key), `startKgX10`, `endKgX10`
/// (06 Bản 2 §6.5.1). `op = delete` là tombstone.
final class LiftLogCodec {
  const LiftLogCodec();

  String get entity => SyncEntities.liftLog;

  LiftLog decode(String key, Map<String, Object?> data) {
    final parsed = LiftLog.parseKey(key);
    if (parsed == null) throw const ContractFormatException('key');
    final (date, exerciseId) = parsed;
    final r = JsonReader(data, path: 'data');
    if (r.decoded('date', DateCodec.decode) != date) {
      throw const ContractFormatException('data.date');
    }
    if (r.string('exerciseId') != exerciseId) {
      throw const ContractFormatException('data.exerciseId');
    }
    return LiftLog(
      date: date,
      exerciseId: exerciseId,
      startKgX10: r.integer('startKgX10'),
      endKgX10: r.integer('endKgX10'),
    );
  }

  Map<String, Object?> encode(LiftLog l) => {
    'date': DateCodec.encode(l.date),
    'exerciseId': l.exerciseId,
    'startKgX10': l.startKgX10,
    'endKgX10': l.endKgX10,
  };
}

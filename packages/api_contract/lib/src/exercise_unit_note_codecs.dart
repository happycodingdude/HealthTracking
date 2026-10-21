import 'package:domain/domain.dart';

import 'codecs.dart';
import 'json_reader.dart';
import 'sync_entities.dart';

/// Entity `exercise_unit` (push + pull, 05 Bản 3 §6.6.2): key = `exerciseId`;
/// `data` có `exerciseId` (khớp key), `unit` (`kg` / `steps`), `changedOn`.
/// Đổi đơn vị là `upsert`, không có tombstone.
final class ExerciseUnitCodec {
  const ExerciseUnitCodec();

  String get entity => SyncEntities.exerciseUnit;

  ExerciseUnit decode(String key, Map<String, Object?> data) {
    final r = JsonReader(data, path: 'data');
    if (r.string('exerciseId') != key) {
      throw const ContractFormatException('data.exerciseId');
    }
    final unit =
        LiftUnit.tryParse(r.string('unit')) ??
        (throw const ContractFormatException('data.unit'));
    return ExerciseUnit(
      exerciseId: key,
      unit: unit,
      changedOn: r.decoded('changedOn', DateCodec.decode),
    );
  }

  Map<String, Object?> encode(ExerciseUnit u) => {
    'exerciseId': u.exerciseId,
    'unit': u.unit.wire,
    'changedOn': DateCodec.encode(u.changedOn),
  };
}

/// Entity `exercise_note` (push + pull, 05 Bản 3 §6.6.4): key
/// `{date}:{exerciseId}`; `data` có `date`, `exerciseId` (khớp key), `text`.
/// Ghi chú trống là `op = delete` (tombstone, TD3-06).
final class ExerciseNoteCodec {
  const ExerciseNoteCodec();

  String get entity => SyncEntities.exerciseNote;

  ExerciseNote decode(String key, Map<String, Object?> data) {
    final parsed = ExerciseNote.parseKey(key);
    if (parsed == null) throw const ContractFormatException('key');
    final (date, exerciseId) = parsed;
    final r = JsonReader(data, path: 'data');
    if (r.decoded('date', DateCodec.decode) != date) {
      throw const ContractFormatException('data.date');
    }
    if (r.string('exerciseId') != exerciseId) {
      throw const ContractFormatException('data.exerciseId');
    }
    return ExerciseNote(
      date: date,
      exerciseId: exerciseId,
      text: r.string('text'),
    );
  }

  Map<String, Object?> encode(ExerciseNote n) => {
    'date': DateCodec.encode(n.date),
    'exerciseId': n.exerciseId,
    'text': n.text,
  };
}

import 'package:domain/domain.dart';

import 'codecs.dart';
import 'json_reader.dart';
import 'sync_entities.dart';

/// Kiểm `data.date` + `data.exerciseId` khớp key `{date}:{exerciseId}`.
(LocalDate, String) _dateExercise(String key, JsonReader r) {
  final parsed = SessionExerciseRow.parseKey(key);
  if (parsed == null) throw const ContractFormatException('key');
  final (date, exerciseId) = parsed;
  if (r.decoded('date', DateCodec.decode) != date) {
    throw const ContractFormatException('data.date');
  }
  if (r.string('exerciseId') != exerciseId) {
    throw const ContractFormatException('data.exerciseId');
  }
  return parsed;
}

/// Entity `session_exercise` (05 Bản 5 §6.6.1): `data: { date, exerciseId,
/// role, replacesExerciseId?, position, skipped }`.
final class SessionExerciseCodec {
  const SessionExerciseCodec();

  String get entity => SyncEntities.sessionExercise;

  SessionExerciseRow decode(String key, Map<String, Object?> data) {
    final r = JsonReader(data, path: 'data');
    final (date, exerciseId) = _dateExercise(key, r);
    final role =
        SessionExerciseRole.tryParse(r.string('role')) ??
        (throw const ContractFormatException('data.role'));
    return SessionExerciseRow(
      date: date,
      exerciseId: exerciseId,
      role: role,
      replacesExerciseId: r.optString('replacesExerciseId'),
      position: r.integer('position'),
      skipped: r.boolean('skipped'),
    );
  }

  Map<String, Object?> encode(SessionExerciseRow row) => {
    'date': DateCodec.encode(row.date),
    'exerciseId': row.exerciseId,
    'role': row.role.wire,
    'replacesExerciseId': row.replacesExerciseId,
    'position': row.position,
    'skipped': row.skipped,
  };
}

/// Entity `exercise_feel` (05 Bản 5 §6.6.1): `data: { date, exerciseId, feel }`.
final class ExerciseFeelCodec {
  const ExerciseFeelCodec();

  String get entity => SyncEntities.exerciseFeel;

  ExerciseFeel decode(String key, Map<String, Object?> data) {
    final r = JsonReader(data, path: 'data');
    final (date, exerciseId) = _dateExercise(key, r);
    final feel =
        Feel.tryParse(r.string('feel')) ??
        (throw const ContractFormatException('data.feel'));
    return ExerciseFeel(date: date, exerciseId: exerciseId, feel: feel);
  }

  Map<String, Object?> encode(ExerciseFeel f) => {
    'date': DateCodec.encode(f.date),
    'exerciseId': f.exerciseId,
    'feel': f.feel.wire,
  };
}

/// Entity `schedule_pause` (05 Bản 5 §6.6.1): `data: { id, startDate,
/// endDate, endedOn? }`, key = `id` (UUID).
final class SchedulePauseCodec {
  const SchedulePauseCodec();

  String get entity => SyncEntities.schedulePause;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool validKey(String key) => _uuid.hasMatch(key);

  SchedulePause decode(String key, Map<String, Object?> data) {
    if (!validKey(key)) throw const ContractFormatException('key');
    final r = JsonReader(data, path: 'data');
    if (r.string('id') != key) throw const ContractFormatException('data.id');
    return SchedulePause(
      id: key,
      startDate: r.decoded('startDate', DateCodec.decode),
      endDate: r.decoded('endDate', DateCodec.decode),
      endedOn: r.has('endedOn') ? r.decoded('endedOn', DateCodec.decode) : null,
    );
  }

  Map<String, Object?> encode(SchedulePause p) => {
    'id': p.id,
    'startDate': DateCodec.encode(p.startDate),
    'endDate': DateCodec.encode(p.endDate),
    'endedOn': p.endedOn == null ? null : DateCodec.encode(p.endedOn!),
  };
}

/// Entity `gym_location` (05 Bản 5 §6.6.1), key `me`: `data: { lat, lng,
/// savedAt, enabled }`. Server không ghi body vào log (TD5-06, TAC5-10).
final class GymLocationCodec {
  const GymLocationCodec();

  String get entity => SyncEntities.gymLocation;

  GymLocation decode(String key, Map<String, Object?> data) {
    if (key != GymLocation.key) throw const ContractFormatException('key');
    final r = JsonReader(data, path: 'data');
    return GymLocation(
      lat: r.number('lat'),
      lng: r.number('lng'),
      savedAt: r.decoded('savedAt', InstantCodec.decode),
      enabled: r.boolean('enabled'),
    );
  }

  /// Tọa độ làm tròn 6 chữ số thập phân như cột `numeric(9,6)` (TA5-03).
  Map<String, Object?> encode(GymLocation g) => {
    'lat': _round6(g.lat),
    'lng': _round6(g.lng),
    'savedAt': InstantCodec.encode(g.savedAt.toUtc()),
    'enabled': g.enabled,
  };

  static double _round6(double v) => (v * 1e6).roundToDouble() / 1e6;
}

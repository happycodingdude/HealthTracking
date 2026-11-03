import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// 05 Bản 5 §6.6.1: 4 entity mới + `day.openedAt` (06 Bản 5 VS52-T03).
void main() {
  final date = LocalDate(2026, 11, 4);

  test('4 entity mới có tên đúng hợp đồng', () {
    expect(SyncEntities.sessionExercise, 'session_exercise');
    expect(SyncEntities.exerciseFeel, 'exercise_feel');
    expect(SyncEntities.schedulePause, 'schedule_pause');
    expect(SyncEntities.gymLocation, 'gym_location');
    expect(AppVersion.v5.toString(), '5.0.0');
  });

  group('session_exercise', () {
    const codec = SessionExerciseCodec();
    final row = SessionExerciseRow(
      date: date,
      exerciseId: 'back-incline',
      role: SessionExerciseRole.replacement,
      replacesExerciseId: 'chest-press',
      position: 1,
    );

    test('khứ hồi', () {
      final data = codec.encode(row);
      expect(data, {
        'date': '2026-11-04',
        'exerciseId': 'back-incline',
        'role': 'replacement',
        'replacesExerciseId': 'chest-press',
        'position': 1,
        'skipped': false,
      });
      expect(codec.decode(row.key, data), row);
    });

    test('key lệch data, role lạ → lỗi đúng trường', () {
      final data = codec.encode(row);
      expect(
        () => codec.decode('2026-11-05:back-incline', data),
        throwsA(
          isA<ContractFormatException>().having(
            (e) => e.field,
            'f',
            'data.date',
          ),
        ),
      );
      expect(
        () => codec.decode(row.key, {...data, 'role': 'other'}),
        throwsA(
          isA<ContractFormatException>().having(
            (e) => e.field,
            'f',
            'data.role',
          ),
        ),
      );
      expect(
        () => codec.decode('sai', data),
        throwsA(
          isA<ContractFormatException>().having((e) => e.field, 'f', 'key'),
        ),
      );
    });
  });

  test('exercise_feel khứ hồi; feel lạ → data.feel', () {
    const codec = ExerciseFeelCodec();
    final f = ExerciseFeel(date: date, exerciseId: 'plank', feel: Feel.hard);
    final data = codec.encode(f);
    expect(data['feel'], 'hard');
    expect(codec.decode(f.key, data), f);
    expect(
      () => codec.decode(f.key, {...data, 'feel': 'ok'}),
      throwsA(
        isA<ContractFormatException>().having((e) => e.field, 'f', 'data.feel'),
      ),
    );
  });

  test('schedule_pause khứ hồi; key phải là UUID trùng data.id', () {
    const codec = SchedulePauseCodec();
    const id = '0b6f1c9e-3d4a-4f6b-9a1e-2c3d4e5f6a7b';
    final p = SchedulePause(
      id: id,
      startDate: date,
      endDate: LocalDate(2026, 11, 8),
      endedOn: LocalDate(2026, 11, 6),
    );
    final data = codec.encode(p);
    expect(data['endedOn'], '2026-11-06');
    expect(codec.decode(id, data), p);
    expect(codec.decode(id, {...data, 'endedOn': null}).endedOn, isNull);
    expect(
      () => codec.decode('me', data),
      throwsA(isA<ContractFormatException>()),
    );
  });

  test('gym_location khứ hồi, tọa độ 6 chữ số; số nguyên đọc được', () {
    const codec = GymLocationCodec();
    final g = GymLocation(
      lat: 10.7701234567,
      lng: 106.69,
      savedAt: DateTime.utc(2026, 11, 4, 10),
    );
    final data = codec.encode(g);
    expect(data['lat'], 10.770123);
    final back = codec.decode('me', data);
    expect(back.lat, 10.770123);
    expect(back.enabled, isTrue);
    expect(codec.decode('me', {...data, 'lng': 106}).lng, 106.0);
    expect(
      () => codec.decode('x', data),
      throwsA(isA<ContractFormatException>()),
    );
  });

  test('day.openedAt: khứ hồi; không có thì không gửi trường', () {
    const codec = DayCodec();
    final day = PlanDay(
      date: date,
      kind: DayKind.workout,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back],
    );
    expect(codec.encode(day).containsKey('openedAt'), isFalse);
    final opened = day.withOpenedAt(DateTime.utc(2026, 11, 4, 10, 20));
    final data = codec.encode(opened);
    expect(data['openedAt'], '2026-11-04T10:20:00.000Z');
    expect(codec.decode('2026-11-04', data), opened);
  });
}

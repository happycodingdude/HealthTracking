import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/local_marks.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/me/application/calorie_updates.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/weight/application/weight_edits.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late WeightRepository weights;
  late WeightEdits edits;

  // seedSetUp: thiết lập 07/10, cân ban đầu 80 kg tuần 05/10. Hôm nay 14/10.
  final w0510 = LocalDate(2026, 10, 5);
  final w1210 = LocalDate(2026, 10, 12);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    clock = FixedClock(DateTime(2026, 10, 14, 9));
    weights = WeightRepository(db);
    final outbox = OutboxWriter(db, clock);
    edits = WeightEdits(
      db: db,
      weights: weights,
      profiles: ProfileRepository(db),
      outbox: outbox,
      calorie: CalorieUpdates(
        db: db,
        profiles: ProfileRepository(db),
        weights: weights,
        outbox: outbox,
        marks: MemoryLocalMarks(),
        clock: clock,
      ),
      clock: clock,
    );
    await seedSetUp(db);
  });

  Future<List<String>> outbox() async => [
    for (final o in await db.select(db.outbox).get())
      '${o.entity}:${o.entityKey}:${o.toMutation().op.name}',
  ];

  test('F07-R5, F07-AC6: ghi tuần mới nhất → số cân mới nhất đổi; sửa tuần cũ '
      'hơn → không đổi; bản ghi + outbox', () async {
    final logged = await edits.log(w1210, 790);
    expect(logged.latestChanged, isTrue);
    expect(logged.latest, (week: w1210, kgX10: 790));
    final older = await edits.log(w0510, 805);
    expect(older.latestChanged, isFalse);
    final same = await edits.log(w1210, 790);
    expect(same.latestChanged, isFalse, reason: 'ghi lại đúng số cũ');
    expect(
      await outbox(),
      [
        'weight:2026-10-12:upsert',
        'profile:me:upsert',
        'weight:2026-10-05:upsert',
      ],
      reason: 'Tự động: mức calo cập nhật theo số cân mới nhất (F07-AC6)',
    );
  });

  test(
    'F07-E2: xóa số cân mới nhất → tuần gần nhất còn lại là mới nhất',
    () async {
      await edits.log(w1210, 790);
      final deleted = await edits.delete(w1210);
      expect(deleted.latestChanged, isTrue);
      expect(deleted.latest, (week: w0510, kgX10: 800));
      expect(deleted.calorie, isA<CalorieAutoUpdated>());
      expect(await outbox(), ['weight:2026-10-12:delete', 'profile:me:upsert']);
    },
  );

  test('F07-AC5: không xóa được số cân duy nhất; F07-AC2: không ghi được tuần '
      'sau, tuần trước tuần thiết lập; F07-V1: ngoài 30–250 kg', () async {
    await expectLater(
      edits.delete(w0510),
      throwsA(
        isA<WeightException>().having(
          (e) => e.error,
          'error',
          WeightError.onlyOne,
        ),
      ),
    );
    for (final week in [LocalDate(2026, 10, 19), LocalDate(2026, 9, 28)]) {
      await expectLater(
        edits.log(week, 800),
        throwsA(
          isA<WeightException>().having(
            (e) => e.error,
            'error',
            WeightError.invalidWeek,
          ),
        ),
        reason: '$week',
      );
    }
    await expectLater(edits.log(w1210, 75), throwsA(isA<WeightException>()));
    expect(await outbox(), isEmpty);
    expect(await weights.all(), [(week: w0510, kgX10: 800)]);
  });
}

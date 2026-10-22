import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// 06 Bản 3 VS40-T08 (domain): nội dung thẻ — F25-AC1, F25-AC2, F25-AC7,
/// F25-E2, F25-E3, F25-R4, FA3-16; JSON đúng `content-state` (05 §6.9.2).
void main() {
  var order = 0;
  Exercise ex(
    String id,
    MuscleRegion region,
    String name, {
    bool active = true,
  }) => Exercise(
    id: id,
    region: region,
    nameVi: name,
    youtubeVideoId: 'v',
    videoChannel: 'c',
    guideSteps: const ['a'],
    guideSafety: const ['b'],
    approvedAt: LocalDate(2026, 10, 20),
    sortOrder: ++order,
    active: active,
  );

  final pecDeck = ex('pec', MuscleRegion.chestMid, 'Máy ép ngực');
  final bench = ex(
    'bench',
    MuscleRegion.chestMid,
    'Nằm ghế ngang đẩy thanh tạ',
  );
  final incline = ex('incline', MuscleRegion.chestUpper, 'Nằm máy dốc lên');
  final gone = ex('gone', MuscleRegion.chestLower, 'Bài đã rời', active: false);
  final pushdown = ex('push', MuscleRegion.tricepsLong, 'Kéo cáp tay sau');
  final plank = ex('plank', MuscleRegion.absMid, 'Plank');
  final library = [pushdown, plank, incline, gone, bench, pecDeck];

  final today = LocalDate(2026, 10, 12);
  LiftLog log(Exercise e, int start, int end, {LocalDate? date}) => LiftLog(
    date: date ?? today,
    exerciseId: e.id,
    startKgX10: start,
    endKgX10: end,
  );
  ExerciseUnit unit(Exercise e, LiftUnit u) => ExerciseUnit(
    exerciseId: e.id,
    unit: u,
    changedOn: LocalDate(2026, 10, 1),
  );

  final previous = {
    pecDeck.id: log(pecDeck, 400, 450, date: LocalDate(2026, 10, 5)),
    incline.id: log(incline, 80, 100, date: LocalDate(2026, 10, 5)),
  };
  final units = {
    pecDeck.id: unit(pecDeck, LiftUnit.kg),
    incline.id: unit(incline, LiftUnit.steps),
  };

  LiveActivityContent content(
    List<LiftLog> todayLogs, {
    List<MuscleGroup> groups = const [MuscleGroup.chest, MuscleGroup.triceps],
  }) => LiveActivityContent.of(
    groups: groups,
    library: library,
    today: todayLogs,
    previous: previous,
    units: units,
  );

  test('F25-AC1: lúc bật thẻ → "Chưa ghi bài nào", kế tiếp Máy ép ngực, buổi '
      'trước 40 → 45 kg; JSON đúng content-state', () {
    expect(content(const []).toJson(), {
      'lastLogged': null,
      'next': {'name': 'Máy ép ngực', 'prev': '40 → 45 kg'},
      'allLogged': false,
      'absOnly': false,
    });
  });

  test('F25-AC2: ghi Máy ép ngực 40 → 47,5 → vừa ghi + kế tiếp bài 2; '
      'F25-AC7: bài chưa từng ghi → prev null ("Buổi trước: chưa ghi")', () {
    final c = content([log(pecDeck, 400, 475)]);
    expect(c.lastLogged, (name: 'Máy ép ngực', lift: '40 → 47,5 kg'));
    expect(c.next, (name: 'Nằm ghế ngang đẩy thanh tạ', prev: null));
  });

  test('đơn vị nấc máy: "8 → 10 nấc"', () {
    final c = content([log(pecDeck, 400, 475), log(bench, 500, 550)]);
    expect(c.next, (name: 'Nằm máy dốc lên', prev: '8 → 10 nấc'));
  });

  test('F25-R4: bài vừa ghi là bản lưu muộn nhất (kể cả sửa); xóa bản đó → '
      'lùi về bản lưu muộn nhất còn lại; không còn → null', () {
    final a = log(pecDeck, 400, 475);
    final b = log(bench, 500, 550);
    expect(content([b, a]).lastLogged?.name, 'Máy ép ngực');
    expect(content([a, b]).lastLogged?.name, 'Nằm ghế ngang đẩy thanh tạ');
    expect(content([a]).lastLogged?.name, 'Máy ép ngực');
    expect(content(const []).lastLogged, isNull);
  });

  test('FA3-16: hết bài Ngực → sang nhóm Tay sau; bài rời thư viện không là '
      'bài kế tiếp', () {
    final c = content([
      log(pecDeck, 400, 475),
      log(bench, 500, 550),
      log(incline, 80, 100),
    ]);
    expect(c.next?.name, 'Kéo cáp tay sau');
  });

  test('F25-E2: ghi hết (không tính bụng) → allLogged', () {
    final c = content(
      [
        log(pecDeck, 400, 475),
        log(bench, 500, 550),
        log(incline, 80, 100),
        log(pushdown, 200, 250),
      ],
      groups: const [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.abs],
    );
    expect(c.next, isNull);
    expect(c.allLogged, isTrue);
    expect(c.absOnly, isFalse);
  });

  test('F25-E3: buổi chỉ có Bụng → absOnly, allLogged, chưa ghi bài nào', () {
    final c = content(const [], groups: const [MuscleGroup.abs]);
    expect(c.toJson(), {
      'lastLogged': null,
      'next': null,
      'allLogged': true,
      'absOnly': true,
    });
  });

  test('tên nhóm cơ của thẻ: "Ngực + Tay sau"', () {
    expect(
      LiveActivityContent.groupsTitle(const [
        MuscleGroup.chest,
        MuscleGroup.triceps,
      ]),
      'Ngực + Tay sau',
    );
  });
}

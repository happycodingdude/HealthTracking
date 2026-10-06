import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const menu = Menu([
    Meal(
      type: MealType.breakfast,
      dishes: [
        Dish(name: 'Phở gà', portion: '1 tô', kcal: 480),
        Dish(name: 'Trứng luộc', portion: '1 quả', kcal: 80),
      ],
    ),
    Meal(
      type: MealType.snack,
      dishes: [Dish(name: 'Sữa chua không đường', portion: '1 hộp', kcal: 100)],
    ),
    Meal(
      type: MealType.lunch,
      dishes: [Dish(name: 'Cơm gạo lứt', portion: '1,5 chén', kcal: 670)],
    ),
    Meal(
      type: MealType.dinner,
      dishes: [Dish(name: 'Bún chả cá', portion: '1 tô', kcal: 690)],
    ),
  ]);

  test('05 §6.9.4: thực đơn khứ hồi đúng định dạng AI trả về', () {
    final json = MenuPayloadCodec.encode(menu);
    expect((json['meals']! as List).first, {
      'type': 'breakfast',
      'dishes': [
        {'name': 'Phở gà', 'portion': '1 tô', 'kcal': 480},
        {'name': 'Trứng luộc', 'portion': '1 quả', 'kcal': 80},
      ],
    });
    expect(MenuPayloadCodec.decode(json), menu);
  });

  test('loại bữa lạ, thiếu trường → lỗi theo tên trường', () {
    expect(
      () => MenuPayloadCodec.decode({
        'meals': [
          {'type': 'brunch', 'dishes': <Object?>[]},
        ],
      }),
      throwsA(isA<ContractFormatException>()),
    );
    expect(
      () => MenuPayloadCodec.decode({
        'meals': [
          {
            'type': 'lunch',
            'dishes': [
              {'name': 'Phở', 'kcal': 400},
            ],
          },
        ],
      }),
      throwsA(
        isA<ContractFormatException>().having(
          (e) => e.field,
          'field',
          'payload.meals[0].dishes[0].portion',
        ),
      ),
    );
  });

  test('entity menu khứ hồi (06 §6.5.1); đang tạo chưa có thực đơn', () {
    final ready = MenuData(
      payload: menu,
      targetKcal: 2090,
      usedSafetyFloor: false,
      totalKcal: menu.totalKcal,
      lastAttemptStatus: MenuAttemptStatus.ready,
      generatedAt: DateTime.utc(2026, 10, 7, 4, 30),
    );
    const codec = MenuCodec();
    expect(codec.decode(codec.encode(ready)), ready);
    expect(codec.encode(ready)['lastAttemptStatus'], 'ready');

    const generating = MenuData(
      payload: null,
      targetKcal: 1500,
      usedSafetyFloor: true,
      totalKcal: null,
      lastAttemptStatus: MenuAttemptStatus.generating,
    );
    expect(codec.decode(codec.encode(generating)), generating);

    final failed = codec.decode({
      ...codec.encode(ready),
      'lastAttemptStatus': 'failed',
      'lastErrorCode': 'ai_invalid_output',
    });
    expect(failed.lastErrorCode, ErrorCode.aiInvalidOutput);
    expect(failed.payload, menu, reason: 'TAC-13: lỗi giữ thực đơn cũ');
  });

  test('ai_daily_usage: key "YYYY-MM-DD:menu", successCount', () {
    expect(AiDailyUsageCodec.key(LocalDate(2026, 10, 7)), '2026-10-07:menu');
    expect(AiDailyUsageCodec.parseKey('2026-10-07:menu'), (
      LocalDate(2026, 10, 7),
      'menu',
    ));
    expect(AiDailyUsageCodec.parseKey('menu'), isNull);
    const c = AiDailyUsageCodec();
    expect(c.decode(c.encode(2)), 2);
    expect(SyncEntities.codecs.keys, containsAll(['menu', 'ai_daily_usage']));
  });

  test('meta.aiBudget khứ hồi; số lẻ đồng giữ nguyên (ED-04)', () {
    final meta = AiBudgetMeta(
      month: YearMonth(2026, 10),
      usedVnd: 12500.5,
      capVnd: 50000,
      blocked: false,
    );
    expect(AiBudgetMeta.fromJson(meta.toJson()), meta);
    final sync = SyncMeta.fromJson({
      'serverTime': '2026-10-07T11:42:11.000Z',
      'aiBudget': meta.toJson(),
    });
    expect(sync.budget, meta);
    expect(
      SyncMeta.fromJson({'serverTime': '2026-10-07T11:42:11.000Z'}).budget,
      isNull,
    );
  });

  test('POST /v1/ai/menus: yêu cầu và kết quả khứ hồi', () {
    final req = GenerateMenuRequest(
      localDate: LocalDate(2026, 10, 7),
      requestId: '8f1c2b9e-4d4a-4b8e-9f00-1c2d3e4f5a6b',
      targetKcal: 2210,
    );
    final back = GenerateMenuRequest.fromJson(req.toJson());
    expect(
      (back.localDate, back.requestId, back.targetKcal),
      (req.localDate, req.requestId, req.targetKcal),
    );
    final res = GenerateMenuResponse(
      date: LocalDate(2026, 10, 7),
      menu: MenuData(
        payload: menu,
        targetKcal: 2210,
        usedSafetyFloor: false,
        totalKcal: menu.totalKcal,
        lastAttemptStatus: MenuAttemptStatus.ready,
        generatedAt: DateTime.utc(2026, 10, 7),
      ),
      remaining: 2,
      budgetWarning80: true,
    );
    final r2 = GenerateMenuResponse.fromJson(res.toJson());
    expect((r2.menu, r2.remaining, r2.budgetWarning80), (res.menu, 2, true));
    final status = MenuStatusResponse.fromJson(
      MenuStatusResponse(
        date: LocalDate(2026, 10, 7),
        menu: null,
        remaining: 3,
      ).toJson(),
    );
    expect((status.menu, status.remaining), (null, 3));
  });
}

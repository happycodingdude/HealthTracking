import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';

import 'fake_server.dart';

/// Thực đơn của mock S-30-3 (tổng 2.020 kcal).
const mockMenu = Menu([
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
    dishes: [
      Dish(name: 'Cơm gạo lứt', portion: '1,5 chén', kcal: 330),
      Dish(name: 'Cá basa kho tộ', portion: '150 g', kcal: 280),
      Dish(name: 'Canh rau muống', portion: '1 chén', kcal: 60),
    ],
  ),
  Meal(
    type: MealType.snack,
    dishes: [Dish(name: 'Chuối', portion: '1 quả', kcal: 110)],
  ),
  Meal(
    type: MealType.dinner,
    dishes: [
      Dish(name: 'Bún chả cá', portion: '1 tô', kcal: 520),
      Dish(name: 'Rau luộc', portion: '1 đĩa', kcal: 60),
    ],
  ),
]);

MenuData readyMenu({
  Menu menu = mockMenu,
  int targetKcal = 2210,
  bool usedSafetyFloor = false,
}) => MenuData(
  payload: menu,
  targetKcal: targetKcal,
  usedSafetyFloor: usedSafetyFloor,
  totalKcal: menu.totalKcal,
  lastAttemptStatus: MenuAttemptStatus.ready,
  generatedAt: DateTime.utc(2026, 10, 7, 4),
);

Map<String, Object?> errorBody(ErrorCode code) => {
  'error': {'code': code.wire},
};

/// `POST /v1/ai/menus` giả: lần thứ n trả [results] thứ n (mặc định thực đơn
/// mock). [gate] khác null → chờ trước khi trả (trạng thái "Đang tạo").
final class FakeMenuServer {
  FakeMenuServer(this.server) {
    server.on('POST', '/v1/ai/menus', (req) async {
      final g = gate;
      if (g != null) await g.future;
      final body = req.body! as Map;
      final date = LocalDate.parse(body['localDate']! as String);
      final next = results.isEmpty ? null : results.removeAt(0);
      if (next != null) return next;
      successes++;
      final floor = (body['targetKcal']! as int) < 1500;
      return (
        200,
        GenerateMenuResponse(
          date: date,
          menu: readyMenu(
            targetKcal: floor ? 1500 : body['targetKcal']! as int,
            usedSafetyFloor: floor,
          ),
          remaining: MenuRules.remaining(successes),
          budgetWarning80: warn80,
        ).toJson(),
      );
    });
  }

  final FakeServer server;
  Completer<void>? gate;
  int successes = 0;
  bool warn80 = false;

  /// Kết quả lập trình sẵn cho các lần gọi kế tiếp (status, thân).
  final results = <(int, Object?)>[];

  List<FakeRequest> get calls => server.calls('POST', '/v1/ai/menus');
}

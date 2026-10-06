import 'dart:math' as math;

import '../calorie/calorie.dart';
import '../profile/profile.dart';

/// Loại bữa trong thực đơn AI trả về (05 §6.9.4).
enum MealType { breakfast, lunch, dinner, snack }

/// Bữa phụ hiển thị theo vị trí (mock S-30-3): trước bữa trưa là bữa phụ
/// sáng, sau bữa trưa là bữa phụ chiều.
enum SnackTime { morning, afternoon }

/// Một món: tên, khẩu phần ước lượng, calo ước tính (F-08).
final class Dish {
  const Dish({required this.name, required this.portion, required this.kcal});

  final String name;
  final String portion;
  final int kcal;

  @override
  bool operator ==(Object other) =>
      other is Dish &&
      other.name == name &&
      other.portion == portion &&
      other.kcal == kcal;

  @override
  int get hashCode => Object.hash(name, portion, kcal);
}

final class Meal {
  const Meal({required this.type, required this.dishes});

  final MealType type;
  final List<Dish> dishes;

  /// Tổng calo của bữa, tự cộng (không tin con số AI trả về).
  int get kcal => dishes.fold(0, (sum, d) => sum + d.kcal);

  @override
  bool operator ==(Object other) =>
      other is Meal && other.type == type && _sameList(other.dishes, dishes);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(dishes));
}

/// Thực đơn một ngày (F-08), theo thứ tự AI trả về.
final class Menu {
  const Menu(this.meals);

  final List<Meal> meals;

  /// Tổng calo cả ngày, server tự cộng (05 §6.7.3 `total_kcal`).
  int get totalKcal => meals.fold(0, (sum, m) => sum + m.kcal);

  /// Tên các món, gửi kèm khi gợi ý lại để AI tránh lặp (F08-R4, TR-12).
  List<String> get dishNames => [
    for (final m in meals)
      for (final d in m.dishes) d.name,
  ];

  /// Các bữa theo thứ tự trong ngày: sáng, bữa phụ sáng, trưa, bữa phụ chiều,
  /// tối (mock S-30-3). Bữa phụ AI đặt trước bữa trưa là bữa phụ sáng, còn lại
  /// là bữa phụ chiều.
  List<(Meal, SnackTime?)> get ordered {
    final lunchAt = meals.indexWhere((m) => m.type == MealType.lunch);
    final out = <(Meal, SnackTime?, int)>[];
    for (var i = 0; i < meals.length; i++) {
      final m = meals[i];
      final (snack, rank) = switch (m.type) {
        MealType.breakfast => (null, 0),
        MealType.lunch => (null, 2),
        MealType.dinner => (null, 4),
        MealType.snack when lunchAt >= 0 && i < lunchAt => (
          SnackTime.morning,
          1,
        ),
        MealType.snack => (SnackTime.afternoon, 3),
      };
      out.add((m, snack, rank));
    }
    // Sắp xếp ổn định theo vị trí trong ngày.
    final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])]
      ..sort((a, b) {
        final c = a.$2.$3.compareTo(b.$2.$3);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return [for (final (_, (m, s, _)) in indexed) (m, s)];
  }

  @override
  bool operator ==(Object other) =>
      other is Menu && _sameList(other.meals, meals);

  @override
  int get hashCode => Object.hashAll(meals);
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Lý do thực đơn không hợp lệ (F08-E4, 05 §6.9.4).
enum MenuError {
  /// Không đúng 1 sáng, 1 trưa, 1 tối, 0–2 bữa phụ.
  meals,

  /// Bữa không có món.
  emptyMeal,

  /// Tên món ngoài 1–60 ký tự.
  dishName,

  /// Khẩu phần rỗng.
  portion,

  /// Calo món ngoài 1–2.000.
  dishKcal,

  /// Tổng calo ngoài ±10% mức calo dùng cho thực đơn (F08-R7).
  total,
}

/// Quy tắc thực đơn AI (F-08).
abstract final class MenuRules {
  /// F08-R2: tối đa 3 lần tạo thành công mỗi ngày, kể cả gợi ý lại.
  static const maxDaily = 3;

  static const maxSnacks = 2;
  static const maxDishName = 60;
  static const maxDishKcal = 2000;

  /// Mức calo dùng cho thực đơn được server giới hạn trong khoảng này
  /// (05 §6.9.2).
  static const minTargetKcal = CalorieRules.manualMin;
  static const maxTargetKcal = CalorieRules.manualMax;

  /// Lượt còn lại trong ngày khi đã có [successCount] lần thành công.
  static int remaining(int successCount) =>
      math.max(0, maxDaily - successCount);

  /// Mức calo dùng cho thực đơn (FR-05, F02-R6): không dưới ngưỡng an toàn,
  /// giới hạn 800–5.000. [usedSafetyFloor] = đã nâng lên ngưỡng an toàn
  /// (ghi chú F08-R9).
  static ({int kcal, bool usedSafetyFloor}) target(int requestedKcal, Sex sex) {
    final floor = CalorieRules.safetyFloor(sex);
    final kcal = CalorieRules.menuKcal(
      requestedKcal,
      sex,
    ).clamp(minTargetKcal, maxTargetKcal);
    return (kcal: kcal, usedSafetyFloor: requestedKcal < floor);
  }

  /// F08-R7: tổng calo hợp lệ trong `[min, max]` (F08-AC4: 2.210 → 1.989 →
  /// 2.431).
  static ({int min, int max}) totalRange(int targetKcal) =>
      (min: (targetKcal * 90 + 99) ~/ 100, max: targetKcal * 110 ~/ 100);
}

/// Kiểm tra thực đơn AI trả về (05 §6.9.4). Server dùng trước khi lưu.
abstract final class MenuValidator {
  /// null = hợp lệ.
  static MenuError? validate(Menu menu, int targetKcal) {
    int count(MealType t) => menu.meals.where((m) => m.type == t).length;
    if (count(MealType.breakfast) != 1 ||
        count(MealType.lunch) != 1 ||
        count(MealType.dinner) != 1 ||
        count(MealType.snack) > MenuRules.maxSnacks) {
      return MenuError.meals;
    }
    for (final meal in menu.meals) {
      if (meal.dishes.isEmpty) return MenuError.emptyMeal;
      for (final d in meal.dishes) {
        final name = d.name.trim().runes.length;
        if (name < 1 || name > MenuRules.maxDishName) return MenuError.dishName;
        if (d.portion.trim().isEmpty) return MenuError.portion;
        if (d.kcal < 1 || d.kcal > MenuRules.maxDishKcal) {
          return MenuError.dishKcal;
        }
      }
    }
    final range = MenuRules.totalRange(targetKcal);
    final total = menu.totalKcal;
    if (total < range.min || total > range.max) return MenuError.total;
    return null;
  }
}

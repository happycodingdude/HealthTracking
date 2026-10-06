import 'package:domain/domain.dart';
import 'package:test/test.dart';

Dish dish(int kcal, [String name = 'Phở gà']) =>
    Dish(name: name, portion: '1 tô', kcal: kcal);

/// Thực đơn mock S-30-3: sáng, bữa phụ sáng, trưa, bữa phụ chiều, tối.
Menu menuOf(List<(MealType, List<int>)> meals) => Menu([
  for (final (t, kcals) in meals)
    Meal(type: t, dishes: [for (final k in kcals) dish(k)]),
]);

void main() {
  final mock = menuOf([
    (MealType.breakfast, [480, 80]),
    (MealType.snack, [100]),
    (MealType.lunch, [330, 280, 60]),
    (MealType.snack, [110]),
    (MealType.dinner, [520, 60]),
  ]);

  test('tổng calo tự cộng (mock S-30-3: 2.020 kcal)', () {
    expect(mock.totalKcal, 2020);
    expect(mock.meals[2].kcal, 670);
  });

  group('F08-R7, F08-AC4: tổng trong ±10% mức calo dùng cho thực đơn', () {
    test('2.210 kcal → 1.989 đến 2.431', () {
      expect(MenuRules.totalRange(2210), (min: 1989, max: 2431));
    });

    for (final (total, ok) in [
      (1988, false),
      (1989, true),
      (2210, true),
      (2431, true),
      (2432, false),
    ]) {
      test('F08-AC4: tổng $total → ${ok ? 'hợp lệ' : 'F08-E4'}', () {
        final m = menuOf([
          (MealType.breakfast, [500]),
          (MealType.lunch, [800]),
          (MealType.dinner, [total - 1300]),
        ]);
        expect(MenuValidator.validate(m, 2210), ok ? isNull : MenuError.total);
      });
    }
  });

  group('F08-E4: cấu trúc thực đơn (05 §6.9.4)', () {
    test('thiếu bữa tối → meals', () {
      final m = menuOf([
        (MealType.breakfast, [1000]),
        (MealType.lunch, [1210]),
      ]);
      expect(MenuValidator.validate(m, 2210), MenuError.meals);
    });

    test('2 bữa trưa → meals; 3 bữa phụ → meals; 2 bữa phụ hợp lệ', () {
      expect(
        MenuValidator.validate(
          menuOf([
            (MealType.breakfast, [500]),
            (MealType.lunch, [600]),
            (MealType.lunch, [500]),
            (MealType.dinner, [610]),
          ]),
          2210,
        ),
        MenuError.meals,
      );
      expect(
        MenuValidator.validate(
          menuOf([
            (MealType.breakfast, [500]),
            (MealType.snack, [100]),
            (MealType.lunch, [800]),
            (MealType.snack, [100]),
            (MealType.snack, [100]),
            (MealType.dinner, [610]),
          ]),
          2210,
        ),
        MenuError.meals,
      );
      expect(MenuValidator.validate(mock, 2090), isNull);
    });

    test('bữa không có món → emptyMeal', () {
      final m = Menu([
        Meal(type: MealType.breakfast, dishes: [dish(700)]),
        const Meal(type: MealType.lunch, dishes: []),
        Meal(type: MealType.dinner, dishes: [dish(1500)]),
      ]);
      expect(MenuValidator.validate(m, 2210), MenuError.emptyMeal);
    });

    test('tên món 0 hoặc 61 ký tự → dishName; 60 ký tự hợp lệ', () {
      Menu named(String name) => Menu([
        Meal(type: MealType.breakfast, dishes: [dish(700, name)]),
        Meal(type: MealType.lunch, dishes: [dish(800)]),
        Meal(type: MealType.dinner, dishes: [dish(710)]),
      ]);
      expect(MenuValidator.validate(named('  '), 2210), MenuError.dishName);
      expect(MenuValidator.validate(named('ơ' * 61), 2210), MenuError.dishName);
      expect(MenuValidator.validate(named('ơ' * 60), 2210), isNull);
    });

    test('khẩu phần rỗng → portion; kcal 0 hoặc 2.001 → dishKcal', () {
      final noPortion = Menu([
        const Meal(
          type: MealType.breakfast,
          dishes: [Dish(name: 'Phở', portion: ' ', kcal: 700)],
        ),
        Meal(type: MealType.lunch, dishes: [dish(800)]),
        Meal(type: MealType.dinner, dishes: [dish(710)]),
      ]);
      expect(MenuValidator.validate(noPortion, 2210), MenuError.portion);
      for (final k in [0, 2001]) {
        final m = menuOf([
          (MealType.breakfast, [k]),
          (MealType.lunch, [1000]),
          (MealType.dinner, [1000]),
        ]);
        expect(MenuValidator.validate(m, 2210), MenuError.dishKcal);
      }
    });
  });

  group('F08-R9, FR-05: mức calo dùng cho thực đơn', () {
    test('F08-AC5: nam đặt 1.300 → 1.500, có ghi chú ngưỡng an toàn', () {
      expect(MenuRules.target(1300, Sex.male), (
        kcal: 1500,
        usedSafetyFloor: true,
      ));
    });

    test('nữ 1.200 (đúng ngưỡng) → 1.200, không ghi chú; 2.210 giữ nguyên', () {
      expect(MenuRules.target(1200, Sex.female), (
        kcal: 1200,
        usedSafetyFloor: false,
      ));
      expect(MenuRules.target(2210, Sex.male), (
        kcal: 2210,
        usedSafetyFloor: false,
      ));
    });

    test('Tự động 6.000 → giới hạn 5.000 (05 §6.9.2)', () {
      expect(MenuRules.target(6000, Sex.male).kcal, 5000);
    });
  });

  test('F08-R2: tối đa 3 lượt mỗi ngày', () {
    expect(
      [
        for (final n in [0, 1, 2, 3, 4]) MenuRules.remaining(n),
      ],
      [3, 2, 1, 0, 0],
    );
  });

  test('mock S-30-3: thứ tự sáng, bữa phụ sáng, trưa, bữa phụ chiều, tối', () {
    final shuffled = Menu([
      mock.meals[4],
      mock.meals[1],
      mock.meals[2],
      mock.meals[0],
      mock.meals[3],
    ]);
    final o = shuffled.ordered;
    expect(
      [for (final (m, s) in o) (m.type, s)],
      [
        (MealType.breakfast, null),
        (MealType.snack, SnackTime.morning),
        (MealType.lunch, null),
        (MealType.snack, SnackTime.afternoon),
        (MealType.dinner, null),
      ],
    );
  });

  test('TR-12: tên các món gửi kèm khi gợi ý lại', () {
    final m = Menu([
      Meal(type: MealType.breakfast, dishes: [dish(500, 'Phở gà')]),
      Meal(type: MealType.lunch, dishes: [dish(800, 'Cơm gạo lứt')]),
      Meal(type: MealType.dinner, dishes: [dish(900, 'Bún chả cá')]),
    ]);
    expect(m.dishNames, ['Phở gà', 'Cơm gạo lứt', 'Bún chả cá']);
  });
}

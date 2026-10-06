import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'ai_provider.dart';

/// Kịch bản của [FakeAiProvider] (06 VS12-T04).
enum FakeAiMode {
  /// Thực đơn hợp lệ, tổng calo đúng mức yêu cầu.
  valid,

  /// Tổng calo ngoài ±10% (F08-E4).
  wrongKcal,

  /// Thiếu bữa tối (F08-E4).
  missingMeal,

  /// Văn bản không phải JSON (F08-E4).
  invalidJson,

  /// Hết giờ chờ: không biết đã tính tiền hay chưa.
  timeout,

  /// Nhà cung cấp quá tải sau khi đã thử lại (ai_provider_error).
  overloaded,
}

/// Nhà cung cấp AI giả: mặc định ở local và CI, không tốn tiền (ED-11).
final class FakeAiProvider implements AiProvider {
  FakeAiProvider({
    this.mode = FakeAiMode.valid,
    this.inputTokens = 900,
    this.outputTokens = 1200,
    this.delay = Duration.zero,
  });

  /// Kịch bản mặc định; [enqueue] đặt kịch bản cho các lần gọi kế tiếp.
  FakeAiMode mode;
  int inputTokens;
  int outputTokens;
  Duration delay;

  /// Khi khác null, mọi lần gọi chờ tới khi hoàn thành (test đồng thời, job
  /// dọn yêu cầu treo).
  Completer<void>? gate;

  final _queue = Queue<FakeAiMode>();

  /// Các yêu cầu đã nhận (kiểm TR-12).
  final requests = <AiRequest>[];

  void enqueue(Iterable<FakeAiMode> modes) => _queue.addAll(modes);

  @override
  String get name => 'fake';

  @override
  String get model => 'fake-menu-1';

  @override
  Future<AiResult> complete(AiRequest request) async {
    requests.add(request);
    final m = _queue.isEmpty ? mode : _queue.removeFirst();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final g = gate;
    if (g != null) await g.future;
    switch (m) {
      case FakeAiMode.timeout:
        throw const AiProviderException('timeout', billingUnknown: true);
      case FakeAiMode.overloaded:
        throw const AiProviderException(
          'http_529',
          inputTokens: 0,
          outputTokens: 0,
        );
      case FakeAiMode.invalidJson:
        return _result('Xin lỗi, tôi chưa tạo được thực đơn.');
      case FakeAiMode.valid:
      case FakeAiMode.wrongKcal:
      case FakeAiMode.missingMeal:
        final target = m == FakeAiMode.wrongKcal
            ? request.targetKcal * 3 ~/ 2
            : request.targetKcal;
        final menu = menuJson(
          target,
          variant: requests.length + request.avoidDishes.length,
          avoid: request.avoidDishes.toSet(),
        );
        if (m == FakeAiMode.missingMeal) {
          (menu['meals']! as List).removeWhere(
            (meal) => (meal as Map)['type'] == 'dinner',
          );
        }
        return _result(jsonEncode(menu));
    }
  }

  AiResult _result(String text) => AiResult(
    text: text,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
  );

  static const _catalog = {
    'breakfast': [
      ('Phở gà', '1 tô', 5),
      ('Bánh mì trứng ốp la', '1 ổ', 5),
      ('Xôi gà', '1 gói', 5),
      ('Cháo yến mạch sữa tươi', '1 chén', 4),
      ('Trứng luộc', '1 quả', 1),
      ('Sữa đậu nành không đường', '1 ly', 1),
    ],
    'snack_morning': [
      ('Sữa chua không đường', '1 hộp', 1),
      ('Táo', '1 quả', 1),
    ],
    'lunch': [
      ('Cơm gạo lứt', '1,5 chén', 4),
      ('Cá basa kho tộ', '150 g', 3),
      ('Ức gà áp chảo', '150 g', 3),
      ('Đậu phụ sốt cà chua', '150 g', 2),
      ('Canh rau muống', '1 chén', 1),
      ('Canh bí đỏ', '1 chén', 1),
    ],
    'snack_afternoon': [('Chuối', '1 quả', 1), ('Hạt điều rang', '20 g', 1)],
    'dinner': [
      ('Bún chả cá', '1 tô', 5),
      ('Cơm trắng', '1 chén', 3),
      ('Thịt bò xào cải ngọt', '150 g', 3),
      ('Rau luộc', '1 đĩa', 1),
      ('Canh chua cá', '1 chén', 2),
    ],
  };

  /// Phần calo của từng bữa (phần nghìn), tổng 1.000.
  static const _shares = [
    ('breakfast', 'snack_morning', 270),
    ('snack', 'snack_morning', 50),
    ('lunch', 'lunch', 330),
    ('snack', 'snack_afternoon', 50),
    ('dinner', 'dinner', 300),
  ];

  /// Thực đơn hợp lệ có tổng đúng [targetKcal] (05 §6.9.4). [variant] đổi món
  /// giữa các lần; món trong [avoid] được tránh khi còn món khác.
  static Map<String, Object?> menuJson(
    int targetKcal, {
    int variant = 0,
    Set<String> avoid = const {},
  }) {
    final meals = <Map<String, Object?>>[];
    var left = targetKcal;
    for (var i = 0; i < _shares.length; i++) {
      final (type, catalogKey, share) = _shares[i];
      final key = type == 'snack' ? catalogKey : type;
      final mealKcal = i == _shares.length - 1
          ? left
          : targetKcal * share ~/ 1000;
      left -= mealKcal;
      final options = _catalog[key]!;
      final fresh = options.where((o) => !avoid.contains(o.$1)).toList();
      final pool = fresh.length >= 2 ? fresh : options;
      final count = type == 'snack' ? 1 : 2;
      final picked = [
        for (var k = 0; k < count; k++) pool[(variant + k) % pool.length],
      ];
      final weight = picked.fold(0, (s, d) => s + d.$3);
      var mealLeft = mealKcal;
      final dishes = <Map<String, Object?>>[];
      for (var k = 0; k < picked.length; k++) {
        final kcal = k == picked.length - 1
            ? mealLeft
            : mealKcal * picked[k].$3 ~/ weight;
        mealLeft -= kcal;
        dishes.add({
          'name': picked[k].$1,
          'portion': picked[k].$2,
          'kcal': kcal,
        });
      }
      meals.add({'type': type, 'dishes': dishes});
    }
    return {'meals': meals};
  }
}

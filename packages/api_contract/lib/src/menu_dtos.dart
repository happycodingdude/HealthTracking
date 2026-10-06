import 'package:domain/domain.dart';

import 'codecs.dart';
import 'error_code.dart';
import 'json_reader.dart';
import 'profile_codecs.dart';
import 'sync_entities.dart';

/// Trạng thái lần tạo gần nhất của thực đơn một ngày (05 §6.7.3 `menus`).
enum MenuAttemptStatus { generating, ready, failed }

/// Giá trị enum trong API và PostgreSQL.
abstract final class MenuWire {
  static const mealType = {
    MealType.breakfast: 'breakfast',
    MealType.lunch: 'lunch',
    MealType.dinner: 'dinner',
    MealType.snack: 'snack',
  };
  static const status = {
    MenuAttemptStatus.generating: 'generating',
    MenuAttemptStatus.ready: 'ready',
    MenuAttemptStatus.failed: 'failed',
  };
}

/// Thực đơn theo định dạng AI trả về và lưu ở `menus.payload` (05 §6.9.4):
/// `{"meals": [{"type", "dishes": [{"name", "portion", "kcal"}]}]}`.
abstract final class MenuPayloadCodec {
  static Menu decode(Object? json, {String path = 'payload'}) {
    final r = JsonReader(json, path: path);
    final meals = r.list('meals');
    return Menu([
      for (var i = 0; i < meals.length; i++) _meal(meals[i], '$path.meals[$i]'),
    ]);
  }

  static Meal _meal(Object? json, String path) {
    final r = JsonReader(json, path: path);
    final type = ProfileWire.parse(MenuWire.mealType, r.string('type'), 'type');
    final dishes = r.list('dishes');
    return Meal(
      type: type!,
      dishes: [
        for (var i = 0; i < dishes.length; i++)
          _dish(dishes[i], '$path.dishes[$i]'),
      ],
    );
  }

  static Dish _dish(Object? json, String path) {
    final r = JsonReader(json, path: path);
    return Dish(
      name: r.string('name'),
      portion: r.string('portion'),
      kcal: r.integer('kcal'),
    );
  }

  static Map<String, Object?> encode(Menu menu) => {
    'meals': [
      for (final m in menu.meals)
        {
          'type': MenuWire.mealType[m.type],
          'dishes': [
            for (final d in m.dishes)
              {'name': d.name, 'portion': d.portion, 'kcal': d.kcal},
          ],
        },
    ],
  };
}

/// Entity `menu` (chỉ pull), key = ngày Bạn bấm tạo (06 §6.5.1, F08-E5).
final class MenuData {
  const MenuData({
    required this.payload,
    required this.targetKcal,
    required this.usedSafetyFloor,
    required this.totalKcal,
    required this.lastAttemptStatus,
    this.lastErrorCode,
    this.generatedAt,
  });

  /// Thực đơn hợp lệ gần nhất của ngày; null khi chưa có lần nào thành công.
  final Menu? payload;

  /// Mức calo dùng cho thực đơn (đã áp ngưỡng an toàn, FR-05).
  final int targetKcal;

  /// Ghi chú F08-R9.
  final bool usedSafetyFloor;

  /// Server tự cộng (null khi chưa có thực đơn).
  final int? totalKcal;
  final MenuAttemptStatus lastAttemptStatus;

  /// Mã lỗi của lần tạo gần nhất khi `failed` (F08-E4 / lỗi khác).
  final ErrorCode? lastErrorCode;
  final DateTime? generatedAt;

  @override
  bool operator ==(Object other) =>
      other is MenuData &&
      other.payload == payload &&
      other.targetKcal == targetKcal &&
      other.usedSafetyFloor == usedSafetyFloor &&
      other.totalKcal == totalKcal &&
      other.lastAttemptStatus == lastAttemptStatus &&
      other.lastErrorCode == lastErrorCode &&
      other.generatedAt == generatedAt;

  @override
  int get hashCode => Object.hash(
    payload,
    targetKcal,
    usedSafetyFloor,
    totalKcal,
    lastAttemptStatus,
    lastErrorCode,
    generatedAt,
  );
}

final class MenuCodec implements EntityCodec<MenuData> {
  const MenuCodec();

  @override
  String get entity => SyncEntities.menu;

  @override
  MenuData decode(Map<String, Object?> data) {
    final r = JsonReader(data, path: 'data');
    final error = r.optString('lastErrorCode');
    return MenuData(
      payload: r.has('payload')
          ? MenuPayloadCodec.decode(data['payload'], path: 'data.payload')
          : null,
      targetKcal: r.integer('targetKcal'),
      usedSafetyFloor: r.boolean('usedSafetyFloor'),
      totalKcal: r.optInteger('totalKcal'),
      lastAttemptStatus: ProfileWire.parse(
        MenuWire.status,
        r.string('lastAttemptStatus'),
        'lastAttemptStatus',
      )!,
      lastErrorCode: error == null ? null : ErrorCode.fromWire(error),
      generatedAt: r.has('generatedAt')
          ? r.decoded('generatedAt', InstantCodec.decode)
          : null,
    );
  }

  @override
  Map<String, Object?> encode(MenuData v) => {
    'payload': v.payload == null ? null : MenuPayloadCodec.encode(v.payload!),
    'targetKcal': v.targetKcal,
    'usedSafetyFloor': v.usedSafetyFloor,
    'totalKcal': v.totalKcal,
    'lastAttemptStatus': MenuWire.status[v.lastAttemptStatus],
    'lastErrorCode': v.lastErrorCode?.wire,
    'generatedAt': v.generatedAt == null
        ? null
        : InstantCodec.encode(v.generatedAt!),
  };
}

/// Entity `ai_daily_usage` (chỉ pull), key `YYYY-MM-DD:menu`: số lần tạo
/// thành công trong ngày (F08-R2).
final class AiDailyUsageCodec implements EntityCodec<int> {
  const AiDailyUsageCodec();

  static const menuFeature = 'menu';

  static String key(LocalDate date, [String feature = menuFeature]) =>
      '${date.toKey()}:$feature';

  /// Ngày và tính năng từ [key]; null khi sai định dạng.
  static (LocalDate, String)? parseKey(String key) {
    final i = key.indexOf(':');
    if (i <= 0) return null;
    final date = LocalDate.tryParse(key.substring(0, i));
    return date == null ? null : (date, key.substring(i + 1));
  }

  @override
  String get entity => SyncEntities.aiDailyUsage;

  @override
  int decode(Map<String, Object?> data) =>
      JsonReader(data, path: 'data').integer('successCount');

  @override
  Map<String, Object?> encode(int successCount) => {
    'successCount': successCount,
  };
}

/// `meta.aiBudget` của pull (ED-04): tháng hiện tại theo giờ Việt Nam.
final class AiBudgetMeta {
  const AiBudgetMeta({
    required this.month,
    required this.usedVnd,
    required this.capVnd,
    required this.blocked,
  });

  factory AiBudgetMeta.fromJson(Object? json) {
    final r = JsonReader(json, path: 'aiBudget');
    final used = json is Map ? json['usedVnd'] : null;
    if (used is! num) {
      throw const ContractFormatException('aiBudget.usedVnd', 'cần số');
    }
    return AiBudgetMeta(
      month: r.decoded('month', YearMonth.parse),
      usedVnd: used,
      capVnd: r.integer('capVnd'),
      blocked: r.boolean('blocked'),
    );
  }

  final YearMonth month;

  /// Chi phí đã dùng (đồng), có thể lẻ.
  final num usedVnd;
  final int capVnd;

  /// Tháng đã bị chặn (F11-R5).
  final bool blocked;

  Map<String, Object?> toJson() => {
    'month': month.toKey(),
    'usedVnd': usedVnd,
    'capVnd': capVnd,
    'blocked': blocked,
  };

  @override
  bool operator ==(Object other) =>
      other is AiBudgetMeta &&
      other.month == month &&
      other.usedVnd == usedVnd &&
      other.capVnd == capVnd &&
      other.blocked == blocked;

  @override
  int get hashCode => Object.hash(month, usedVnd, capVnd, blocked);
}

/// `POST /v1/ai/menus` (05 §6.9.2).
final class GenerateMenuRequest {
  const GenerateMenuRequest({
    required this.localDate,
    required this.requestId,
    required this.targetKcal,
  });

  factory GenerateMenuRequest.fromJson(Object? json) {
    final r = JsonReader(json);
    return GenerateMenuRequest(
      localDate: r.decoded('localDate', DateCodec.decode),
      requestId: r.string('requestId'),
      targetKcal: r.integer('targetKcal'),
    );
  }

  /// Ngày trên iPhone lúc bấm (F08-E5).
  final LocalDate localDate;

  /// UUID do app tạo; gửi lại cùng giá trị thì không tạo, không tính tiền lần
  /// nữa.
  final String requestId;

  /// Mức calo của Bạn; server tự áp ngưỡng an toàn.
  final int targetKcal;

  Map<String, Object?> toJson() => {
    'localDate': DateCodec.encode(localDate),
    'requestId': requestId,
    'targetKcal': targetKcal,
  };
}

/// Kết quả tạo thành công.
final class GenerateMenuResponse {
  const GenerateMenuResponse({
    required this.date,
    required this.menu,
    required this.remaining,
    required this.budgetWarning80,
  });

  factory GenerateMenuResponse.fromJson(Object? json) {
    final r = JsonReader(json);
    return GenerateMenuResponse(
      date: r.decoded('date', DateCodec.decode),
      menu: const MenuCodec().decode(r.object('menu').raw),
      remaining: r.integer('remaining'),
      budgetWarning80: r.boolean('budgetWarning80'),
    );
  }

  final LocalDate date;
  final MenuData menu;

  /// Lượt còn lại hôm nay (F08-R2).
  final int remaining;

  /// Lần tạo này làm chi phí tháng lần đầu đạt 80% (F11-R4, đúng một lần).
  final bool budgetWarning80;

  Map<String, Object?> toJson() => {
    'date': DateCodec.encode(date),
    'menu': const MenuCodec().encode(menu),
    'remaining': remaining,
    'budgetWarning80': budgetWarning80,
  };
}

/// `GET /v1/ai/menus/{date}`: trạng thái và kết quả của một ngày.
final class MenuStatusResponse {
  const MenuStatusResponse({
    required this.date,
    required this.menu,
    required this.remaining,
  });

  factory MenuStatusResponse.fromJson(Object? json) {
    final r = JsonReader(json);
    final menu = r.optObject('menu');
    return MenuStatusResponse(
      date: r.decoded('date', DateCodec.decode),
      menu: menu == null ? null : const MenuCodec().decode(menu.raw),
      remaining: r.integer('remaining'),
    );
  }

  final LocalDate date;

  /// null = chưa từng tạo cho ngày này.
  final MenuData? menu;
  final int remaining;

  Map<String, Object?> toJson() => {
    'date': DateCodec.encode(date),
    'menu': menu == null ? null : const MenuCodec().encode(menu!),
    'remaining': remaining,
  };
}

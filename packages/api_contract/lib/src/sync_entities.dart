import 'json_reader.dart';
import 'menu_dtos.dart';
import 'profile_codecs.dart';
import 'schedule_codecs.dart';

/// Codec `data` của một entity đồng bộ (06 §6.5.1). App và server cùng dùng để
/// đọc/ghi đúng hợp đồng.
abstract interface class EntityCodec<T> {
  String get entity;
  T decode(Map<String, Object?> data);
  Map<String, Object?> encode(T value);
}

/// Entity `account`, key `me`: tên hiển thị (VS-02).
final class AccountData {
  const AccountData({required this.displayName});

  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is AccountData && other.displayName == displayName;

  @override
  int get hashCode => displayName.hashCode;
}

final class AccountCodec implements EntityCodec<AccountData> {
  const AccountCodec();

  static const key = 'me';

  @override
  String get entity => SyncEntities.account;

  @override
  AccountData decode(Map<String, Object?> data) => AccountData(
    displayName: JsonReader(data, path: 'data').string('displayName'),
  );

  @override
  Map<String, Object?> encode(AccountData value) => {
    'displayName': value.displayName,
  };
}

/// Danh sách entity đồng bộ (06 §6.5.1). Slice sau thêm entity mới vào đây.
/// `month_plan`, `day` có khóa là ngày/tháng nên dùng [MonthPlanCodec],
/// [DayCodec] (giải mã cần cả `key`).
abstract final class SyncEntities {
  static const account = 'account';
  static const profile = 'profile';
  static const weight = 'weight';
  static const weeklyTemplate = 'weekly_template';
  static const monthPlan = 'month_plan';
  static const day = 'day';

  /// Chỉ pull, do server ghi (05 §6.6.1, VS-12).
  static const menu = 'menu';
  static const aiDailyUsage = 'ai_daily_usage';

  /// Bản 2 (06 Bản 2 §6.5.1). `exercise`, `dish_image` là dòng dùng chung
  /// (không có `user_id`), chỉ pull; `lift_log` push + pull.
  static const exercise = 'exercise';
  static const dishImage = 'dish_image';
  static const liftLog = 'lift_log';

  static const Map<String, EntityCodec<Object>> codecs = {
    account: AccountCodec(),
    profile: ProfileCodec(),
    weight: WeightCodec(),
    weeklyTemplate: WeeklyTemplateCodec(),
    menu: MenuCodec(),
    aiDailyUsage: AiDailyUsageCodec(),
  };
}

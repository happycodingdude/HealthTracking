import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Trạng thái đồng bộ (05 §6.5): cursor của lần pull cuối và thời điểm đồng
/// bộ thành công gần nhất. Một dòng duy nhất, `id = 1`.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  @override
  String get tableName => 'sync_state';

  IntColumn get id => integer().check(const CustomExpression<bool>('id = 1'))();
  IntColumn get cursor => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  /// `meta.aiBudget` của lần pull gần nhất, JSON (VS-12, ED-04).
  TextColumn get aiBudget => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Hàng đợi thay đổi chưa gửi (05 §6.5). Còn dòng = "Chưa đồng bộ" (F09-E1).
@DataClassName('OutboxRow')
class Outbox extends Table {
  @override
  String get tableName => 'outbox';

  /// Thứ tự gửi.
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mutationId => text().unique()();
  TextColumn get entity => text()();
  TextColumn get entityKey => text().named('key')();

  /// `upsert` / `ensure` / `delete`.
  TextColumn get op => text()();

  /// `data` dạng JSON; null với `delete`.
  TextColumn get payload => text().nullable()();
  DateTimeColumn get clientUpdatedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

/// Bản sao entity `account` (key `me`): tên hiển thị (VS-02).
@DataClassName('AccountRow')
class Account extends Table {
  @override
  String get tableName => 'account';

  TextColumn get key => text()();
  TextColumn get displayName => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Bản sao entity `profile` (key `me`, VS-03). Cột giống bảng `profiles` của
/// server (05 §6.5, §6.7.3); enum lưu đúng giá trị trong API.
@DataClassName('ProfileRow')
class Profiles extends Table {
  @override
  String get tableName => 'profiles';

  TextColumn get key => text()();
  IntColumn get onboardingStep => integer()();
  IntColumn get heightCm => integer().nullable()();
  IntColumn get birthYear => integer().nullable()();
  TextColumn get sex => text().nullable()();
  TextColumn get activityLevel => text().nullable()();

  /// `YYYY-MM-DD`.
  TextColumn get setupDate => text().nullable()();
  DateTimeColumn get disclaimerAcceptedAt => dateTime().nullable()();
  DateTimeColumn get onboardingCompletedAt => dateTime().nullable()();
  TextColumn get calorieMode => text().nullable()();
  IntColumn get calorieKcal => integer().nullable()();
  IntColumn get caloriePendingKcal => integer().nullable()();
  TextColumn get caloriePendingReason => text().nullable()();
  BoolColumn get remindersEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get timezone => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Bản sao entity `weight`: một số cân mỗi tuần (FR-11), khóa = thứ 2.
@DataClassName('WeightRow')
class Weights extends Table {
  @override
  String get tableName => 'weights';

  /// `YYYY-MM-DD` của thứ 2.
  TextColumn get weekStart => text()();
  IntColumn get weightKgX10 => integer()();

  @override
  Set<Column<Object>> get primaryKey => {weekStart};
}

/// Thông tin đang nhập dở ở S-03 (OB-3). Chỉ nằm trên máy, không đồng bộ.
/// Một dòng duy nhất, `id = 1`.
@DataClassName('OnboardingDraftRow')
class OnboardingDraft extends Table {
  @override
  String get tableName => 'onboarding_draft';

  IntColumn get id => integer().check(const CustomExpression<bool>('id = 1'))();

  /// Chuỗi Bạn gõ, giữ nguyên kể cả khi sai (04 §6.13.5).
  TextColumn get height => text().withDefault(const Constant(''))();
  IntColumn get birthYear => integer().nullable()();
  TextColumn get sex => text().nullable()();
  TextColumn get activityLevel => text().nullable()();
  TextColumn get weight => text().withDefault(const Constant(''))();

  /// Lịch tuần đang xếp dở ở S-05 (JSON như `WeeklyTemplate.toJson`, VS-04).
  TextColumn get template => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Bản sao entity `weekly_template` (key `me`, VS-04): `days` là JSON chuẩn
/// hóa của lịch tuần.
@DataClassName('WeeklyTemplateRow')
class WeeklyTemplates extends Table {
  @override
  String get tableName => 'weekly_templates';

  TextColumn get key => text()();
  TextColumn get days => text()();
  TextColumn get contentHash => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Bản sao entity `month_plan` (key `YYYY-MM`).
@DataClassName('MonthPlanRow')
class MonthPlans extends Table {
  @override
  String get tableName => 'month_plans';

  TextColumn get month => text()();

  /// `YYYY-MM-DD`.
  TextColumn get startDate => text()();
  TextColumn get templateHash => text()();
  DateTimeColumn get generatedAt => dateTime()();
  DateTimeColumn get redistributedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {month};
}

/// Bản sao entity `day` (key `YYYY-MM-DD`, thứ 2 → thứ 7). Danh sách nhóm cơ
/// lưu dạng JSON (`["chest","triceps"]`).
@DataClassName('DayRow')
class Days extends Table {
  @override
  String get tableName => 'days';

  TextColumn get date => text()();
  TextColumn get kind => text()();

  /// `HH:mm`.
  TextColumn get time => text().nullable()();
  TextColumn get muscles => text().nullable()();
  TextColumn get source => text()();
  TextColumn get mark => text().nullable()();
  TextColumn get actualMuscles => text().nullable()();
  DateTimeColumn get markedAt => dateTime().nullable()();
  TextColumn get extraMuscles => text().nullable()();
  DateTimeColumn get extraLoggedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {date};
}

/// Bản sao entity `menu` (chỉ pull, VS-12): thực đơn AI của một ngày (key
/// `YYYY-MM-DD`, F08-E5). Cột giống bảng `menus` của server (05 §6.7.3).
@DataClassName('MenuRow')
class Menus extends Table {
  @override
  String get tableName => 'menus';

  TextColumn get date => text()();

  /// Thực đơn (JSON theo 05 §6.9.4); null khi chưa có lần nào thành công.
  TextColumn get payload => text().nullable()();
  IntColumn get targetKcal => integer()();
  BoolColumn get usedSafetyFloor => boolean()();
  IntColumn get totalKcal => integer().nullable()();

  /// `generating` / `ready` / `failed`.
  TextColumn get lastAttemptStatus => text()();
  TextColumn get lastErrorCode => text().nullable()();
  DateTimeColumn get generatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {date};
}

/// Bản sao entity `ai_daily_usage` (chỉ pull, VS-12): số lần tạo thành công
/// trong ngày (F08-R2), key `YYYY-MM-DD:menu`.
@DataClassName('AiDailyUsageRow')
class AiDailyUsage extends Table {
  @override
  String get tableName => 'ai_daily_usage';

  TextColumn get key => text()();
  IntColumn get successCount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// SQLite trên máy (TD-04). Mỗi slice tăng `schemaVersion` tối đa 1 bước
/// (ED-05, 06 §6.5.2).
@DriftDatabase(
  tables: [
    SyncState,
    Outbox,
    Account,
    Profiles,
    Weights,
    OnboardingDraft,
    WeeklyTemplates,
    MonthPlans,
    Days,
    Menus,
    AiDailyUsage,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 5;

  /// Đăng nhập tài khoản khác trên máy này (05 §6.6.6): xóa toàn bộ dữ liệu
  /// của tài khoản cũ (kể cả thay đổi chưa gửi), đặt lại cursor để khôi phục
  /// tài khoản mới từ đầu.
  Future<void> wipe() => transaction(() async {
    for (final table in allTables) {
      if (table != syncState) await delete(table).go();
    }
    await update(syncState).write(
      const SyncStateCompanion(
        cursor: Value(0),
        lastSyncedAt: Value(null),
        aiBudget: Value(null),
      ),
    );
  });

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(
        syncState,
      ).insert(SyncStateCompanion.insert(id: const Value(1)));
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // VS-02: outbox và account.
        await m.createTable(outbox);
        await m.createTable(account);
      }
      if (from < 3) {
        // VS-03: hồ sơ, cân nặng, nháp thiết lập.
        await m.createTable(profiles);
        await m.createTable(weights);
        await m.createTable(onboardingDraft);
      }
      if (from == 3) {
        // VS-04: nháp lịch tuần (bảng nháp tạo mới ở v4 đã có cột này).
        await m.addColumn(onboardingDraft, onboardingDraft.template);
      }
      if (from < 4) {
        // VS-04: lịch tuần, lịch tháng, ngày trong lịch.
        await m.createTable(weeklyTemplates);
        await m.createTable(monthPlans);
        await m.createTable(days);
      }
      if (from < 5) {
        // VS-12: thực đơn AI, lượt trong ngày, ngân sách AI của tháng.
        await m.addColumn(syncState, syncState.aiBudget);
        await m.createTable(menus);
        await m.createTable(aiDailyUsage);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

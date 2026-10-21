import 'package:domain/domain.dart' show MuscleRegion;
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

  /// Bộ entity app đã biết lúc pull, cách nhau bởi dấu phẩy (06 Bản 2 ED2-14).
  /// App mới biết thêm entity → đặt lại cursor về 0 và pull lại toàn bộ.
  TextColumn get knownEntities => text().nullable()();

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

  /// `YYYY-MM-DD`, Bản 2 (05 Bản 2 §6.6.5).
  TextColumn get scheduleStartedOn => text().nullable()();
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

/// Bản sao entity `dish_image` (chỉ pull, dòng dùng chung, 05 Bản 2 §6.5),
/// khóa = tên món chuẩn hóa. [cachedPath] chỉ có trên máy: file hình đã tải
/// về thư mục Application Support (TD2-10, 05 Bản 2 §6.4.8).
@DataClassName('DishImageRow')
class DishImages extends Table {
  @override
  String get tableName => 'dish_images';

  TextColumn get nameKey => text()();
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  IntColumn get bytes => integer()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get cachedPath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {nameKey};
}

/// 19 vùng cơ (05 Bản 3 §6.10.3), nạp sẵn lúc tạo database từ
/// [MuscleRegion]; không đồng bộ.
@DataClassName('MuscleRegionRow')
class MuscleRegions extends Table {
  @override
  String get tableName => 'muscle_regions';

  TextColumn get id => text()();
  TextColumn get muscleGroup => text()();

  /// `front` / `back`.
  TextColumn get view => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Bản sao chỉ đọc entity `exercise` (dòng dùng chung, AP-7). Cột giống bảng
/// `exercises` của server trừ `library_version` (06 Bản 3 §6.5.1). Bài bỏ ở
/// Bản 3 (tombstone) bị xóa dòng (05 Bản 3 §6.5).
@DataClassName('ExerciseRow')
class Exercises extends Table {
  @override
  String get tableName => 'exercises';

  TextColumn get id => text()();
  TextColumn get muscleGroup => text()();
  TextColumn get muscleRegion => text()();

  /// Cột của Bản 2, app Bản 3 không đọc (TD3-20). Còn trong SQLite đã nâng
  /// từ schema 1 (NOT NULL) nên ghi chuỗi rỗng.
  TextColumn get equipment => text().clientDefault(() => '')();
  BoolColumn get logsWeight => boolean()();
  TextColumn get nameVi => text()();
  TextColumn get nameEn => text().nullable()();
  TextColumn get youtubeVideoId => text()();
  TextColumn get videoChannel => text()();
  IntColumn get videoDurationS => integer().nullable()();
  BoolColumn get videoAvailable => boolean()();
  DateTimeColumn get videoCheckedAt => dateTime().nullable()();
  TextColumn get videoUnavailableReason => text().nullable()();

  /// Danh sách chuỗi dạng JSON.
  TextColumn get guideSteps => text()();
  TextColumn get guideSafety => text()();

  /// `YYYY-MM-DD`.
  TextColumn get approvedAt => text()();

  /// Vị trí trong nhóm (TD3-07), schema 2.
  IntColumn get sortInGroup => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer()();
  BoolColumn get active => boolean()();

  /// Schema 2 (06 Bản 3 §6.5.2).
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Bản sao entity `lift_log` (key `YYYY-MM-DD:exerciseId`, 05 Bản 2 §6.6.2),
/// ghi qua outbox. Mức tạ lưu kg × 10 như cân nặng. Cùng trường với `data`
/// của entity (06 Bản 2 §6.5.1).
@DataClassName('LiftLogRow')
class LiftLogs extends Table {
  @override
  String get tableName => 'lift_logs';

  /// `YYYY-MM-DD`.
  TextColumn get date => text()();
  TextColumn get exerciseId => text()();
  IntColumn get startKgX10 => integer()();
  IntColumn get endKgX10 => integer()();

  @override
  Set<Column<Object>> get primaryKey => {date, exerciseId};
}

/// Bản sao entity `exercise_unit` (key `exerciseId`, 05 Bản 3 §6.6.2): đơn vị
/// mức tạ Bạn chọn cho bài, ghi qua outbox. Schema 2.
@DataClassName('ExerciseUnitRow')
class ExerciseUnits extends Table {
  @override
  String get tableName => 'exercise_units';

  TextColumn get exerciseId => text()();

  /// `kg` / `steps`.
  TextColumn get unit => text()();

  /// `YYYY-MM-DD`: ngày đổi đơn vị gần nhất (F22-R42).
  TextColumn get changedOn => text()();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId};
}

/// Bản sao entity `exercise_note` (key `YYYY-MM-DD:exerciseId`, 05 Bản 3
/// §6.6.4): ghi chú bài theo buổi, ghi qua outbox; xóa là xóa dòng. Schema 2.
@DataClassName('ExerciseNoteRow')
class ExerciseNotes extends Table {
  @override
  String get tableName => 'exercise_notes';

  /// `YYYY-MM-DD`.
  TextColumn get date => text()();
  TextColumn get exerciseId => text()();
  TextColumn get noteText => text().named('text')();

  @override
  Set<Column<Object>> get primaryKey => {date, exerciseId};
}

/// SQLite trên máy (TD-04). Bản 2 đã phát hành với `schemaVersion = 1`; từ
/// Bản 3 mỗi lần đổi cấu trúc tăng `schemaVersion` và có bước nâng cấp, chỉ
/// thêm, không xóa database vì outbox có thể còn thay đổi chưa gửi (ED-05,
/// 05 Bản 3 §6.5, TR3-05).
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
    DishImages,
    MuscleRegions,
    Exercises,
    LiftLogs,
    ExerciseUnits,
    ExerciseNotes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 1 = Bản 2; 2 = Bản 3 (06 Bản 3 §6.5.2).
  @override
  int get schemaVersion => 2;

  /// Vùng cơ còn thiếu (lần tạo: 19 vùng; nâng từ schema 1: 3 vùng chân).
  Future<void> _insertMuscleRegions() => batch((b) {
    b.insertAllOnConflictUpdate(muscleRegions, [
      for (final r in MuscleRegion.values)
        MuscleRegionsCompanion.insert(
          id: r.id,
          muscleGroup: r.group.name,
          view: r.view.name,
          sortOrder: r.sortOrder,
        ),
    ]);
  });

  /// Đăng nhập tài khoản khác trên máy này (05 §6.6.6): xóa toàn bộ dữ liệu
  /// của tài khoản cũ (kể cả thay đổi chưa gửi), đặt lại cursor để khôi phục
  /// tài khoản mới từ đầu.
  Future<void> wipe() => transaction(() async {
    for (final table in allTables) {
      // Vùng cơ là dữ liệu nạp sẵn của app, không thuộc tài khoản nào.
      if (table != syncState && table != muscleRegions) {
        await delete(table).go();
      }
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
      await _insertMuscleRegions();
    },
    // 1 → 2 (Bản 3): chỉ thêm bảng, cột, vùng cơ; outbox và dữ liệu giữ
    // nguyên. Cursor về 0 một lần do bộ entity đã biết đổi (TD3-09).
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(exerciseUnits);
        await m.createTable(exerciseNotes);
        await m.addColumn(exercises, exercises.sortInGroup);
        await m.addColumn(exercises, exercises.deleted);
        await _insertMuscleRegions();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

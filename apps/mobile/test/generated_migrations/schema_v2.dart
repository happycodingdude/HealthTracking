// dart format width=80
import 'package:drift/src/runtime/query_builder/query_builder.dart' as i2;
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class SyncState extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncState(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('id = 1'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> cursor = GeneratedColumn<int>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> aiBudget = GeneratedColumn<String>(
    'ai_budget',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> knownEntities = GeneratedColumn<String>(
    'known_entities',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cursor,
    lastSyncedAt,
    aiBudget,
    knownEntities,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  SyncState createAlias(String alias) {
    return SyncState(attachedDatabase, alias);
  }
}

class Outbox extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Outbox(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> entityKey = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> clientUpdatedAt =
      GeneratedColumn<DateTime>(
        'client_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mutationId,
    entity,
    entityKey,
    op,
    payload,
    clientUpdatedAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  Outbox createAlias(String alias) {
    return Outbox(attachedDatabase, alias);
  }
}

class Account extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Account(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, displayName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account';
  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  Account createAlias(String alias) {
    return Account(attachedDatabase, alias);
  }
}

class Profiles extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Profiles(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> onboardingStep = GeneratedColumn<int>(
    'onboarding_step',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> heightCm = GeneratedColumn<int>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> birthYear = GeneratedColumn<int>(
    'birth_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> activityLevel = GeneratedColumn<String>(
    'activity_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> setupDate = GeneratedColumn<String>(
    'setup_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> scheduleStartedOn =
      GeneratedColumn<String>(
        'schedule_started_on',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<DateTime> disclaimerAcceptedAt =
      GeneratedColumn<DateTime>(
        'disclaimer_accepted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<DateTime> onboardingCompletedAt =
      GeneratedColumn<DateTime>(
        'onboarding_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<String> calorieMode = GeneratedColumn<String>(
    'calorie_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> calorieKcal = GeneratedColumn<int>(
    'calorie_kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> caloriePendingKcal = GeneratedColumn<int>(
    'calorie_pending_kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> caloriePendingReason =
      GeneratedColumn<String>(
        'calorie_pending_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<bool> remindersEnabled = GeneratedColumn<bool>(
    'reminders_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminders_enabled" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    onboardingStep,
    heightCm,
    birthYear,
    sex,
    activityLevel,
    setupDate,
    scheduleStartedOn,
    disclaimerAcceptedAt,
    onboardingCompletedAt,
    calorieMode,
    calorieKcal,
    caloriePendingKcal,
    caloriePendingReason,
    remindersEnabled,
    timezone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  Profiles createAlias(String alias) {
    return Profiles(attachedDatabase, alias);
  }
}

class Weights extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Weights(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> weekStart = GeneratedColumn<String>(
    'week_start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> weightKgX10 = GeneratedColumn<int>(
    'weight_kg_x10',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [weekStart, weightKgX10];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weights';
  @override
  Set<GeneratedColumn> get $primaryKey => {weekStart};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  Weights createAlias(String alias) {
    return Weights(attachedDatabase, alias);
  }
}

class OnboardingDraft extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  OnboardingDraft(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('id = 1'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> height = GeneratedColumn<String>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'\''),
  );
  late final GeneratedColumn<int> birthYear = GeneratedColumn<int>(
    'birth_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> activityLevel = GeneratedColumn<String>(
    'activity_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> weight = GeneratedColumn<String>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'\''),
  );
  late final GeneratedColumn<String> template = GeneratedColumn<String>(
    'template',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    height,
    birthYear,
    sex,
    activityLevel,
    weight,
    template,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'onboarding_draft';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  OnboardingDraft createAlias(String alias) {
    return OnboardingDraft(attachedDatabase, alias);
  }
}

class WeeklyTemplates extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  WeeklyTemplates(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> days = GeneratedColumn<String>(
    'days',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, days, contentHash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_templates';
  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  WeeklyTemplates createAlias(String alias) {
    return WeeklyTemplates(attachedDatabase, alias);
  }
}

class MonthPlans extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MonthPlans(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> templateHash = GeneratedColumn<String>(
    'template_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> redistributedAt =
      GeneratedColumn<DateTime>(
        'redistributed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    month,
    startDate,
    templateHash,
    generatedAt,
    redistributedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'month_plans';
  @override
  Set<GeneratedColumn> get $primaryKey => {month};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  MonthPlans createAlias(String alias) {
    return MonthPlans(attachedDatabase, alias);
  }
}

class Days extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Days(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> muscles = GeneratedColumn<String>(
    'muscles',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> mark = GeneratedColumn<String>(
    'mark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> actualMuscles = GeneratedColumn<String>(
    'actual_muscles',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> markedAt = GeneratedColumn<DateTime>(
    'marked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> extraMuscles = GeneratedColumn<String>(
    'extra_muscles',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> extraLoggedAt =
      GeneratedColumn<DateTime>(
        'extra_logged_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    kind,
    time,
    muscles,
    source,
    mark,
    actualMuscles,
    markedAt,
    extraMuscles,
    extraLoggedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'days';
  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  Days createAlias(String alias) {
    return Days(attachedDatabase, alias);
  }
}

class Menus extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Menus(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> targetKcal = GeneratedColumn<int>(
    'target_kcal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> usedSafetyFloor = GeneratedColumn<bool>(
    'used_safety_floor',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("used_safety_floor" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<int> totalKcal = GeneratedColumn<int>(
    'total_kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> lastAttemptStatus =
      GeneratedColumn<String>(
        'last_attempt_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    payload,
    targetKcal,
    usedSafetyFloor,
    totalKcal,
    lastAttemptStatus,
    lastErrorCode,
    generatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'menus';
  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  Menus createAlias(String alias) {
    return Menus(attachedDatabase, alias);
  }
}

class AiDailyUsage extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AiDailyUsage(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> successCount = GeneratedColumn<int>(
    'success_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, successCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_daily_usage';
  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  AiDailyUsage createAlias(String alias) {
    return AiDailyUsage(attachedDatabase, alias);
  }
}

class DishImages extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DishImages(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> cachedPath = GeneratedColumn<String>(
    'cached_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    nameKey,
    id,
    displayName,
    width,
    height,
    bytes,
    createdAt,
    cachedPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dish_images';
  @override
  Set<GeneratedColumn> get $primaryKey => {nameKey};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  DishImages createAlias(String alias) {
    return DishImages(attachedDatabase, alias);
  }
}

class MuscleRegions extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MuscleRegions(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> muscleGroup = GeneratedColumn<String>(
    'muscle_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> view = GeneratedColumn<String>(
    'view',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, muscleGroup, view, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'muscle_regions';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  MuscleRegions createAlias(String alias) {
    return MuscleRegions(attachedDatabase, alias);
  }
}

class Exercises extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Exercises(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> muscleGroup = GeneratedColumn<String>(
    'muscle_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> muscleRegion = GeneratedColumn<String>(
    'muscle_region',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> logsWeight = GeneratedColumn<bool>(
    'logs_weight',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("logs_weight" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<String> nameVi = GeneratedColumn<String>(
    'name_vi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
    'name_en',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> youtubeVideoId = GeneratedColumn<String>(
    'youtube_video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> videoChannel = GeneratedColumn<String>(
    'video_channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> videoDurationS = GeneratedColumn<int>(
    'video_duration_s',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<bool> videoAvailable = GeneratedColumn<bool>(
    'video_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("video_available" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<DateTime> videoCheckedAt =
      GeneratedColumn<DateTime>(
        'video_checked_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<String> videoUnavailableReason =
      GeneratedColumn<String>(
        'video_unavailable_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<String> guideSteps = GeneratedColumn<String>(
    'guide_steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> guideSafety = GeneratedColumn<String>(
    'guide_safety',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> approvedAt = GeneratedColumn<String>(
    'approved_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> sortInGroup = GeneratedColumn<int>(
    'sort_in_group',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    muscleGroup,
    muscleRegion,
    equipment,
    logsWeight,
    nameVi,
    nameEn,
    youtubeVideoId,
    videoChannel,
    videoDurationS,
    videoAvailable,
    videoCheckedAt,
    videoUnavailableReason,
    guideSteps,
    guideSafety,
    approvedAt,
    sortInGroup,
    sortOrder,
    active,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  Exercises createAlias(String alias) {
    return Exercises(attachedDatabase, alias);
  }
}

class LiftLogs extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LiftLogs(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> startKgX10 = GeneratedColumn<int>(
    'start_kg_x10',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> endKgX10 = GeneratedColumn<int>(
    'end_kg_x10',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    exerciseId,
    startKgX10,
    endKgX10,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lift_logs';
  @override
  Set<GeneratedColumn> get $primaryKey => {date, exerciseId};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  LiftLogs createAlias(String alias) {
    return LiftLogs(attachedDatabase, alias);
  }
}

class ExerciseUnits extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ExerciseUnits(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> changedOn = GeneratedColumn<String>(
    'changed_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [exerciseId, unit, changedOn];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_units';
  @override
  Set<GeneratedColumn> get $primaryKey => {exerciseId};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  ExerciseUnits createAlias(String alias) {
    return ExerciseUnits(attachedDatabase, alias);
  }
}

class ExerciseNotes extends Table with TableInfo {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ExerciseNotes(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [date, exerciseId, noteText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_notes';
  @override
  Set<GeneratedColumn> get $primaryKey => {date, exerciseId};
  @override
  Never map(Map<String, dynamic> data, {String? tablePrefix}) {
    throw UnsupportedError('TableInfo.map in schema verification code');
  }

  @override
  ExerciseNotes createAlias(String alias) {
    return ExerciseNotes(attachedDatabase, alias);
  }
}

class DatabaseAtV2 extends GeneratedDatabase {
  DatabaseAtV2(QueryExecutor e) : super(e);
  late final SyncState syncState = SyncState(this);
  late final Outbox outbox = Outbox(this);
  late final Account account = Account(this);
  late final Profiles profiles = Profiles(this);
  late final Weights weights = Weights(this);
  late final OnboardingDraft onboardingDraft = OnboardingDraft(this);
  late final WeeklyTemplates weeklyTemplates = WeeklyTemplates(this);
  late final MonthPlans monthPlans = MonthPlans(this);
  late final Days days = Days(this);
  late final Menus menus = Menus(this);
  late final AiDailyUsage aiDailyUsage = AiDailyUsage(this);
  late final DishImages dishImages = DishImages(this);
  late final MuscleRegions muscleRegions = MuscleRegions(this);
  late final Exercises exercises = Exercises(this);
  late final LiftLogs liftLogs = LiftLogs(this);
  late final ExerciseUnits exerciseUnits = ExerciseUnits(this);
  late final ExerciseNotes exerciseNotes = ExerciseNotes(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncState,
    outbox,
    account,
    profiles,
    weights,
    onboardingDraft,
    weeklyTemplates,
    monthPlans,
    days,
    menus,
    aiDailyUsage,
    dishImages,
    muscleRegions,
    exercises,
    liftLogs,
    exerciseUnits,
    exerciseNotes,
  ];
  @override
  int get schemaVersion => 2;
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

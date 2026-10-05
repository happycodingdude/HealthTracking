import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của lịch tuần, lịch tháng và các ngày (VS-04).
final class ScheduleRepository {
  ScheduleRepository(this._db);

  final AppDatabase _db;

  // Lịch tuần (key `me`).

  SimpleSelectStatement<$WeeklyTemplatesTable, WeeklyTemplateRow>
  get _template =>
      _db.select(_db.weeklyTemplates)
        ..where((t) => t.key.equals(WeeklyTemplateCodec.key));

  Stream<WeeklyTemplate?> watchTemplate() =>
      _template.watchSingleOrNull().map(_toTemplate);

  Future<WeeklyTemplate?> template() async =>
      _toTemplate(await _template.getSingleOrNull());

  Future<void> putTemplate(WeeklyTemplate t) => _db
      .into(_db.weeklyTemplates)
      .insertOnConflictUpdate(
        WeeklyTemplatesCompanion.insert(
          key: WeeklyTemplateCodec.key,
          days: jsonEncode(t.toJson()),
          contentHash: t.contentHash,
        ),
      );

  Future<void> deleteTemplate() => (_db.delete(
    _db.weeklyTemplates,
  )..where((t) => t.key.equals(WeeklyTemplateCodec.key))).go();

  static WeeklyTemplate? _toTemplate(WeeklyTemplateRow? r) => r == null
      ? null
      : WeeklyTemplate.fromJson(
          (jsonDecode(r.days) as Map).cast<String, Object?>(),
        );

  // Lịch tháng (key `YYYY-MM`).

  Future<MonthPlan?> plan(YearMonth month) async {
    final r =
        await (_db.select(_db.monthPlans)
              ..where((p) => p.month.equals(MonthPlanCodec.keyOf(month))))
            .getSingleOrNull();
    return r == null ? null : _toPlan(r);
  }

  /// Mọi tháng đã có lịch, cũ → mới (thanh chuyển tháng ở S-20).
  Stream<List<MonthPlan>> watchPlans() =>
      (_db.select(_db.monthPlans)..orderBy([(p) => OrderingTerm.asc(p.month)]))
          .watch()
          .map((rows) => [for (final r in rows) _toPlan(r)]);

  Future<void> putPlan(MonthPlan p) => _db
      .into(_db.monthPlans)
      .insertOnConflictUpdate(
        MonthPlansCompanion.insert(
          month: MonthPlanCodec.keyOf(p.month),
          startDate: p.startDate.toKey(),
          templateHash: p.templateHash,
          generatedAt: p.generatedAt,
          redistributedAt: Value(p.redistributedAt),
        ),
      );

  Future<void> deletePlan(YearMonth month) => (_db.delete(
    _db.monthPlans,
  )..where((p) => p.month.equals(MonthPlanCodec.keyOf(month)))).go();

  static MonthPlan _toPlan(MonthPlanRow r) => MonthPlan(
    month: YearMonth.parse(r.month),
    startDate: LocalDate.parse(r.startDate),
    templateHash: r.templateHash,
    generatedAt: r.generatedAt,
    redistributedAt: r.redistributedAt,
  );

  // Ngày (key `YYYY-MM-DD`).

  Future<PlanDay?> day(LocalDate date) async {
    final r = await (_db.select(
      _db.days,
    )..where((d) => d.date.equals(date.toKey()))).getSingleOrNull();
    return r == null ? null : _toDay(r);
  }

  /// Các ngày (thứ 2 → thứ 7) của [month], theo thứ tự ngày.
  Stream<List<PlanDay>> watchMonth(YearMonth month) =>
      _month(month).watch().map((rows) => [for (final r in rows) _toDay(r)]);

  Future<List<PlanDay>> monthDays(YearMonth month) async => [
    for (final r in await _month(month).get()) _toDay(r),
  ];

  SimpleSelectStatement<$DaysTable, DayRow> _month(YearMonth month) =>
      _db.select(_db.days)
        ..where((d) => d.date.like('${MonthPlanCodec.keyOf(month)}-%'))
        ..orderBy([(d) => OrderingTerm.asc(d.date)]);

  Future<void> putDay(PlanDay d) {
    String? names(List<MuscleGroup>? m) =>
        m == null ? null : jsonEncode([for (final g in m) g.name]);
    return _db
        .into(_db.days)
        .insertOnConflictUpdate(
          DaysCompanion.insert(
            date: d.date.toKey(),
            kind: d.kind.name,
            time: Value(d.time?.toKey()),
            muscles: Value(d.isWorkout ? names(d.muscles) : null),
            source: d.source.name,
            mark: Value(d.mark?.name),
            actualMuscles: Value(names(d.actualMuscles)),
            markedAt: Value(d.markedAt),
            extraMuscles: Value(names(d.extraMuscles)),
            extraLoggedAt: Value(d.extraLoggedAt),
          ),
        );
  }

  Future<void> deleteDay(LocalDate date) =>
      (_db.delete(_db.days)..where((d) => d.date.equals(date.toKey()))).go();

  static PlanDay _toDay(DayRow r) {
    List<MuscleGroup>? muscles(String? json) => json == null
        ? null
        : MuscleGroup.ordered([
            for (final n in jsonDecode(json) as List)
              MuscleGroup.tryParse(n as String)!,
          ]);
    T? named<T extends Enum>(List<T> values, String? name) =>
        name == null ? null : values.byName(name);
    return PlanDay(
      date: LocalDate.parse(r.date),
      kind: DayKind.values.byName(r.kind),
      time: r.time == null ? null : LocalTime.parse(r.time!),
      muscles: muscles(r.muscles) ?? const [],
      source: DaySource.values.byName(r.source),
      mark: named(DayMark.values, r.mark),
      actualMuscles: muscles(r.actualMuscles),
      markedAt: r.markedAt,
      extraMuscles: muscles(r.extraMuscles),
      extraLoggedAt: r.extraLoggedAt,
    );
  }
}

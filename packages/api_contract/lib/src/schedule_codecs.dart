import 'package:domain/domain.dart';

import 'codecs.dart';
import 'json_reader.dart';
import 'sync_entities.dart';

/// Entity `weekly_template`, key `me` (06 §6.5.1): `days`, `contentHash`.
final class WeeklyTemplateCodec implements EntityCodec<WeeklyTemplate> {
  const WeeklyTemplateCodec();

  static const key = 'me';

  @override
  String get entity => SyncEntities.weeklyTemplate;

  /// Ném [ContractFormatException] khi `days` sai cấu trúc hoặc `contentHash`
  /// không khớp nội dung.
  @override
  WeeklyTemplate decode(Map<String, Object?> data) {
    final r = JsonReader(data, path: 'data');
    final WeeklyTemplate template;
    try {
      template = WeeklyTemplate.fromJson(r.object('days').raw);
    } on FormatException catch (e) {
      throw ContractFormatException('data.days', e.message);
    }
    if (r.string('contentHash') != template.contentHash) {
      throw const ContractFormatException('data.contentHash', 'không khớp');
    }
    return template;
  }

  @override
  Map<String, Object?> encode(WeeklyTemplate t) => {
    'days': t.toJson(),
    'contentHash': t.contentHash,
  };
}

/// Entity `month_plan`, key `YYYY-MM`.
final class MonthPlanCodec {
  const MonthPlanCodec();

  String get entity => SyncEntities.monthPlan;

  static String keyOf(YearMonth m) =>
      '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';

  MonthPlan decode(String key, Map<String, Object?> data) {
    final r = JsonReader(data, path: 'data');
    final YearMonth month;
    try {
      month = YearMonth.parse(key);
    } on FormatException {
      throw const ContractFormatException('key');
    }
    return MonthPlan(
      month: month,
      startDate: r.decoded('startDate', DateCodec.decode),
      templateHash: r.string('templateHash'),
      generatedAt: r.decoded('generatedAt', InstantCodec.decode),
      redistributedAt: r.has('redistributedAt')
          ? r.decoded('redistributedAt', InstantCodec.decode)
          : null,
    );
  }

  Map<String, Object?> encode(MonthPlan p) => {
    'startDate': DateCodec.encode(p.startDate),
    'templateHash': p.templateHash,
    'generatedAt': InstantCodec.encode(p.generatedAt.toUtc()),
    'redistributedAt': p.redistributedAt == null
        ? null
        : InstantCodec.encode(p.redistributedAt!.toUtc()),
  };
}

/// Entity `day`, key `YYYY-MM-DD` (thứ 2 → thứ 7).
final class DayCodec {
  const DayCodec();

  String get entity => SyncEntities.day;

  PlanDay decode(String key, Map<String, Object?> data) {
    final date = LocalDate.tryParse(key);
    if (date == null) throw const ContractFormatException('key');
    final r = JsonReader(data, path: 'data');
    List<MuscleGroup>? muscles(String k) {
      if (!r.has(k)) return null;
      final out = <MuscleGroup>[];
      for (final m in r.list(k)) {
        final g = m is String ? MuscleGroup.tryParse(m) : null;
        if (g == null) throw ContractFormatException('data.$k');
        out.add(g);
      }
      return MuscleGroup.ordered(out);
    }

    T? enumOf<T extends Enum>(List<T> values, String k) {
      final s = r.optString(k);
      if (s == null) return null;
      for (final v in values) {
        if (v.name == s) return v;
      }
      throw ContractFormatException('data.$k', 'giá trị lạ: $s');
    }

    return PlanDay(
      date: date,
      kind:
          enumOf(DayKind.values, 'kind') ??
          (throw const ContractFormatException('data.kind')),
      time: r.has('time') ? r.decoded('time', TimeCodec.decode) : null,
      muscles: muscles('muscles') ?? const [],
      source: enumOf(DaySource.values, 'source') ?? DaySource.template,
      mark: enumOf(DayMark.values, 'mark'),
      actualMuscles: muscles('actualMuscles'),
      markedAt: r.has('markedAt')
          ? r.decoded('markedAt', InstantCodec.decode)
          : null,
      extraMuscles: muscles('extraMuscles'),
      extraLoggedAt: r.has('extraLoggedAt')
          ? r.decoded('extraLoggedAt', InstantCodec.decode)
          : null,
    );
  }

  Map<String, Object?> encode(PlanDay d) {
    List<String>? names(List<MuscleGroup>? m) =>
        m == null ? null : [for (final g in MuscleGroup.ordered(m)) g.name];
    return {
      'kind': d.kind.name,
      'time': d.time?.toKey(),
      'muscles': d.isWorkout ? names(d.muscles) : null,
      'source': d.source.name,
      'mark': d.mark?.name,
      'actualMuscles': names(d.actualMuscles),
      'markedAt': d.markedAt == null
          ? null
          : InstantCodec.encode(d.markedAt!.toUtc()),
      'extraMuscles': names(d.extraMuscles),
      'extraLoggedAt': d.extraLoggedAt == null
          ? null
          : InstantCodec.encode(d.extraLoggedAt!.toUtc()),
    };
  }
}

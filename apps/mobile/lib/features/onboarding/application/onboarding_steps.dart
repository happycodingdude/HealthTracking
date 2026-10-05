import 'dart:math' as math;

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/data/profile_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../weight/data/weight_repository.dart';
import '../data/onboarding_draft_repository.dart';

/// Các bước 1–3 của thiết lập lần đầu (VS03-T08). Mỗi bước ghi bản trên máy và
/// outbox trong một transaction (06 §6.4.2): giao diện đổi ngay, không chờ mạng.
final class OnboardingSteps {
  OnboardingSteps({
    required AppDatabase db,
    required ProfileRepository profiles,
    required WeightRepository weights,
    required OnboardingDraftRepository drafts,
    required ScheduleRepository schedule,
    required OutboxWriter outbox,
    required Clock clock,
  }) : _db = db,
       _profiles = profiles,
       _weights = weights,
       _drafts = drafts,
       _schedule = schedule,
       _outbox = outbox,
       _clock = clock;

  final AppDatabase _db;
  final ProfileRepository _profiles;
  final WeightRepository _weights;
  final OnboardingDraftRepository _drafts;
  final ScheduleRepository _schedule;
  final OutboxWriter _outbox;
  final Clock _clock;

  static const _profileCodec = ProfileCodec();
  static const _weightCodec = WeightCodec();
  static const _templateCodec = WeeklyTemplateCodec();
  static const _planCodec = MonthPlanCodec();
  static const _dayCodec = DayCodec();

  /// Bước 1 (S-02): "Tôi đã hiểu" (F10-R1). Tạo hồ sơ, chuyển sang bước 2.
  Future<void> acceptDisclaimer() => _db.transaction(() async {
    final current = await _profiles.get();
    final base = current ?? const Profile(onboardingStep: 1);
    await _saveProfile(
      base.copyWith(
        disclaimerAcceptedAt: base.disclaimerAcceptedAt ?? _clock.now(),
        onboardingStep: math.max(base.onboardingStep, 2),
      ),
    );
  });

  /// Bước 2 (S-03): kiểm tra F01-V1 → V5, lưu hồ sơ và cân nặng ban đầu cho
  /// tuần hiện tại (F01-R3, ED-06). Trả các ô sai; rỗng = đã lưu.
  Future<List<ProfileField>> saveProfile(ProfileDraft d) async {
    final errors = ProfileRules.validate(
      height: d.height,
      birthYear: d.birthYear,
      sex: d.sex,
      activityLevel: d.activityLevel,
      weight: d.weight,
      currentYear: _clock.now().year,
    );
    if (errors.isNotEmpty) return errors;
    final kgX10 = WeightRules.parseKgX10(d.weight)!;
    final week = WeightRules.weekKey(_clock.today());
    await _db.transaction(() async {
      // Trong lúc thiết lập chỉ có một số cân (cân ban đầu): lưu lại ở tuần
      // khác thì bỏ bản cũ để không thành hai lần ghi.
      for (final old in await _weights.all()) {
        if (old.week == week) continue;
        await _weights.delete(old.week);
        await _outbox.enqueue(
          SyncEntities.weight,
          old.week.toKey(),
          SyncOp.delete,
          null,
        );
      }
      await _weights.put(week, kgX10);
      await _outbox.enqueue(
        SyncEntities.weight,
        week.toKey(),
        SyncOp.upsert,
        _weightCodec.encode(WeightData(weightKgX10: kgX10)),
      );
      final current = await _profiles.get();
      var next = (current ?? const Profile(onboardingStep: 2)).copyWith(
        heightCm: ProfileRules.parseHeight(d.height),
        birthYear: d.birthYear,
        sex: d.sex,
        activityLevel: d.activityLevel,
        onboardingStep: math.max(current?.onboardingStep ?? 2, 3),
      );
      // Đã qua bước 3 ở chế độ Tự động: mức calo theo thông tin mới (F02-R8).
      if (next.calorieMode == CalorieMode.auto) {
        next = next.copyWith(calorieKcal: _estimate(next, kgX10)!.kcal);
      }
      await _saveProfile(next);
      await _drafts.clearProfile();
    });
    return const [];
  }

  /// Bước 3 (S-04): "Giữ mức này" ([manualKcal] = null, chế độ Tự động,
  /// F02-R3) hoặc "Đặt mức khác" (Bạn tự đặt, F02-R4). false khi mức tự đặt
  /// sai F02-V1.
  Future<bool> saveCalorie({int? manualKcal}) async {
    if (manualKcal != null && !CalorieRules.isValidManual(manualKcal)) {
      return false;
    }
    await _db.transaction(() async {
      final current = (await _profiles.get())!;
      final kcal =
          manualKcal ??
          _estimate(current, (await _weights.latest())?.kgX10)!.kcal;
      await _saveProfile(
        current.copyWith(
          calorieMode: manualKcal == null
              ? CalorieMode.auto
              : CalorieMode.manual,
          calorieKcal: kcal,
          onboardingStep: math.max(current.onboardingStep, 4),
        ),
      );
    });
    return true;
  }

  /// Bước 4 (S-05): kiểm tra F03-V1 → V3, lưu lịch tuần và chia lịch tháng từ
  /// lúc lưu đến cuối tháng (F03-R5), rồi chuyển sang bước 5. Trả lỗi; rỗng =
  /// đã lưu.
  ///
  /// Lần đầu tạo lịch bằng `ensure`. Quay lại bước này và lưu lại (chưa xong
  /// thiết lập nên chưa có buổi nào được đánh dấu) thì chia lại bằng `upsert`.
  Future<List<TemplateError>> saveSchedule(WeeklyTemplate template) async {
    final errors = template.validate();
    if (errors.isNotEmpty) return errors;
    await _db.transaction(() async {
      await _schedule.putTemplate(template);
      await _outbox.enqueue(
        SyncEntities.weeklyTemplate,
        WeeklyTemplateCodec.key,
        SyncOp.upsert,
        _templateCodec.encode(template),
      );
      final generated = MonthGenerator.first(template, _clock.now());
      final existing = await _schedule.plan(generated.plan.month);
      final op = existing == null ? SyncOp.ensure : SyncOp.upsert;
      final plan = existing == null
          ? generated.plan
          : MonthPlan(
              month: existing.month,
              startDate: existing.startDate.isBefore(generated.plan.startDate)
                  ? existing.startDate
                  : generated.plan.startDate,
              templateHash: generated.plan.templateHash,
              generatedAt: generated.plan.generatedAt,
            );
      await _schedule.putPlan(plan);
      await _outbox.enqueue(
        SyncEntities.monthPlan,
        MonthPlanCodec.keyOf(plan.month),
        op,
        _planCodec.encode(plan),
      );
      for (final day in generated.days) {
        await _schedule.putDay(day);
        await _outbox.enqueue(
          SyncEntities.day,
          day.date.toKey(),
          op,
          _dayCodec.encode(day),
        );
      }
      final profile = (await _profiles.get())!;
      await _saveProfile(
        profile.copyWith(onboardingStep: math.max(profile.onboardingStep, 5)),
      );
      await _drafts.saveTemplate(null);
    });
    return const [];
  }

  CalorieEstimate? _estimate(Profile p, int? weightKgX10) =>
      CalorieRules.forProfile(
        p,
        weightKgX10: weightKgX10,
        currentYear: _clock.now().year,
      );

  Future<void> _saveProfile(Profile p) async {
    await _profiles.put(p);
    await _outbox.enqueue(
      SyncEntities.profile,
      ProfileCodec.key,
      SyncOp.upsert,
      _profileCodec.encode(p),
    );
  }
}

final onboardingDraftRepositoryProvider = Provider<OnboardingDraftRepository>(
  (ref) => OnboardingDraftRepository(ref.watch(databaseProvider)),
);

final onboardingStepsProvider = Provider<OnboardingSteps>(
  (ref) => OnboardingSteps(
    db: ref.watch(databaseProvider),
    profiles: ref.watch(profileRepositoryProvider),
    weights: ref.watch(weightRepositoryProvider),
    drafts: ref.watch(onboardingDraftRepositoryProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);

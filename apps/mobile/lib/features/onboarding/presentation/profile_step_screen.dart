import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/sync/sync_providers.dart';
import '../application/onboarding_steps.dart';
import '../data/onboarding_draft_repository.dart';
import 'onboarding_scaffold.dart';
import 'profile_fields.dart';

/// S-03 — Hồ sơ cơ thể (Bước 2/5, F-01). Mỗi lần đổi một ô, thông tin được lưu
/// nháp trên máy (OB-3). "Tiếp tục" luôn bấm được; sai thì báo dưới ô và cuộn
/// tới ô lỗi đầu tiên (OB-5).
class ProfileStepScreen extends ConsumerStatefulWidget {
  const ProfileStepScreen({super.key});

  @override
  ConsumerState<ProfileStepScreen> createState() => _ProfileStepScreenState();
}

class _ProfileStepScreenState extends ConsumerState<ProfileStepScreen> {
  final _height = TextEditingController();
  final _weight = TextEditingController();
  int? _birthYear;
  Sex? _sex;
  ActivityLevel? _activity;
  Set<ProfileField> _errors = {};
  final _keys = {for (final f in ProfileField.values) f: GlobalKey()};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Nháp đang dở; không có thì thông tin đã lưu ở bước này (OB-2, OB-6).
  Future<void> _load() async {
    final draft = await ref.read(onboardingDraftRepositoryProvider).get();
    final profile = await ref.read(profileRepositoryProvider).get();
    final weight = await ref.read(weightRepositoryProvider).latest();
    if (!mounted) return;
    setState(() {
      if (draft != null) {
        _height.text = draft.height;
        _birthYear = draft.birthYear;
        _sex = draft.sex;
        _activity = draft.activityLevel;
        _weight.text = draft.weight;
      } else if (profile != null) {
        _height.text = profile.heightCm?.toString() ?? '';
        _birthYear = profile.birthYear;
        _sex = profile.sex;
        _activity = profile.activityLevel;
        _weight.text = weight == null ? '' : Fmt.kgNumber(weight.kgX10);
      }
    });
  }

  ProfileDraft get _draft => ProfileDraft(
    height: _height.text,
    birthYear: _birthYear,
    sex: _sex,
    activityLevel: _activity,
    weight: _weight.text,
  );

  /// Đổi một ô: lưu nháp, bỏ lỗi của ô đó (04 §6.13.5).
  void _changed(ProfileField field, [VoidCallback? update]) {
    setState(() {
      update?.call();
      _errors = {..._errors}..remove(field);
    });
    unawaited(ref.read(onboardingDraftRepositoryProvider).save(_draft));
  }

  Future<void> _continue() async {
    final errors = await ref.read(onboardingStepsProvider).saveProfile(_draft);
    if (!mounted) return;
    if (errors.isEmpty) {
      context.go('/onboarding/3');
      return;
    }
    setState(() => _errors = errors.toSet());
    final first = _keys[errors.first]!.currentContext;
    if (first != null && first.mounted) {
      await Scrollable.ensureVisible(
        first,
        alignment: 0.1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
    }
  }

  Future<void> _pickBirthYear() async {
    final year = ref.read(clockProvider).now().year;
    final picked = await showAppSheet<int>(
      context,
      builder: (_) => BirthYearPicker(
        first: ProfileRules.firstBirthYear(year),
        last: ProfileRules.lastBirthYear(year),
        initial: _birthYear ?? year - 30,
      ),
    );
    if (picked != null) {
      _changed(ProfileField.birthYear, () => _birthYear = picked);
    }
  }

  String? _error(ProfileField f) => !_errors.contains(f)
      ? null
      : switch (f) {
          ProfileField.height => S.invalidHeight,
          ProfileField.birthYear => S.invalidBirthYear,
          ProfileField.sex => S.missingSex,
          ProfileField.activityLevel => S.missingActivityLevel,
          ProfileField.weight => S.invalidWeight,
        };

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(clockProvider).now().year;
    return OnboardingScaffold(
      step: 2,
      title: S.profileTitle,
      subtitle: S.profileSubtitle,
      bottom: [PrimaryButton(label: S.continueLabel, onPressed: _continue)],
      children: [
        LabeledField(
          key: _keys[ProfileField.height],
          label: S.fieldHeight,
          controller: _height,
          error: _error(ProfileField.height),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffix: const FieldUnit(S.unitCm),
          onChanged: (_) => _changed(ProfileField.height),
        ),
        const SizedBox(height: 20),
        FieldBlock(
          key: _keys[ProfileField.birthYear],
          label: S.fieldBirthYear,
          error: _error(ProfileField.birthYear),
          child: BirthYearField(
            year: _birthYear,
            age: _birthYear == null
                ? null
                : ProfileRules.age(_birthYear!, year),
            hasError: _errors.contains(ProfileField.birthYear),
            onTap: _pickBirthYear,
          ),
        ),
        const SizedBox(height: 20),
        FieldBlock(
          key: _keys[ProfileField.sex],
          label: S.fieldSex,
          error: _error(ProfileField.sex),
          child: SexSelector(
            value: _sex,
            onChanged: (v) => _changed(ProfileField.sex, () => _sex = v),
          ),
        ),
        const SizedBox(height: 20),
        FieldBlock(
          key: _keys[ProfileField.activityLevel],
          label: S.fieldActivityLevel,
          error: _error(ProfileField.activityLevel),
          child: ActivityCards(
            value: _activity,
            onChanged: (v) =>
                _changed(ProfileField.activityLevel, () => _activity = v),
          ),
        ),
        const SizedBox(height: 20),
        LabeledField(
          key: _keys[ProfileField.weight],
          label: S.fieldInitialWeight,
          controller: _weight,
          error: _error(ProfileField.weight),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          suffix: const FieldUnit(S.unitKg),
          onChanged: (_) => _changed(ProfileField.weight),
        ),
        const SizedBox(height: 20),
        const _GoalRow(),
      ],
    );
  }
}

/// "Mục tiêu: Giảm mỡ" — chỉ hiển thị (FR-07).
class _GoalRow extends StatelessWidget {
  const _GoalRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${S.goalLabel}: ${S.goalFatLoss}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: fieldBoxDecoration(context),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              Text(
                S.goalLabel,
                style: context.text.bodyLarge?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              Text(
                S.goalFatLoss,
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

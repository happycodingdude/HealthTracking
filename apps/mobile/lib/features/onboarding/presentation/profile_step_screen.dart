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
      builder: (_) => _BirthYearPicker(
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
          suffix: const _Unit(S.unitCm),
          onChanged: (_) => _changed(ProfileField.height),
        ),
        const SizedBox(height: 20),
        _FieldBlock(
          key: _keys[ProfileField.birthYear],
          label: S.fieldBirthYear,
          error: _error(ProfileField.birthYear),
          child: _BirthYearField(
            year: _birthYear,
            age: _birthYear == null
                ? null
                : ProfileRules.age(_birthYear!, year),
            hasError: _errors.contains(ProfileField.birthYear),
            onTap: _pickBirthYear,
          ),
        ),
        const SizedBox(height: 20),
        _FieldBlock(
          key: _keys[ProfileField.sex],
          label: S.fieldSex,
          error: _error(ProfileField.sex),
          child: _SexSelector(
            value: _sex,
            onChanged: (v) => _changed(ProfileField.sex, () => _sex = v),
          ),
        ),
        const SizedBox(height: 20),
        _FieldBlock(
          key: _keys[ProfileField.activityLevel],
          label: S.fieldActivityLevel,
          error: _error(ProfileField.activityLevel),
          child: _ActivityCards(
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
          suffix: const _Unit(S.unitKg),
          onChanged: (_) => _changed(ProfileField.weight),
        ),
        const SizedBox(height: 20),
        const _GoalRow(),
      ],
    );
  }
}

/// Đơn vị đứng sau ô nhập (04 §6.13.5).
class _Unit extends StatelessWidget {
  const _Unit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 16),
    child: Align(
      alignment: Alignment.centerRight,
      widthFactor: 1,
      child: Text(
        text,
        style: context.text.bodyLarge?.copyWith(
          color: context.palette.textSecondary,
        ),
      ),
    ),
  );
}

/// Nhãn phía trên, câu lỗi đỏ phía dưới (giống [LabeledField]).
class _FieldBlock extends StatelessWidget {
  const _FieldBlock({
    super.key,
    required this.label,
    required this.child,
    this.error,
  });

  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: context.text.bodyLarge?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

BoxDecoration _boxDecoration(BuildContext context, {bool error = false}) =>
    BoxDecoration(
      color: context.palette.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: error ? context.colors.error : context.palette.border,
        width: error ? 2 : 1,
      ),
    );

class _BirthYearField extends StatelessWidget {
  const _BirthYearField({
    required this.year,
    required this.age,
    required this.hasError,
    required this.onTap,
  });

  final int? year;
  final int? age;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.fieldBirthYear,
      value: year == null ? null : '$year, ${S.ageYears(age!)}',
      child: ExcludeSemantics(
        child: InkWell(
          key: const ValueKey('birth-year-field'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: _boxDecoration(context, error: hasError),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    year?.toString() ?? '',
                    style: context.text.bodyLarge?.copyWith(fontSize: 17),
                  ),
                ),
                if (age != null)
                  Text(
                    S.ageYears(age!),
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                Icon(Icons.chevron_right, color: context.palette.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bánh xe chọn năm sinh, chỉ trong khoảng 18–80 tuổi (S-03, 04 §6.13.5).
class _BirthYearPicker extends StatefulWidget {
  const _BirthYearPicker({
    required this.first,
    required this.last,
    required this.initial,
  });

  final int first;
  final int last;
  final int initial;

  @override
  State<_BirthYearPicker> createState() => _BirthYearPickerState();
}

class _BirthYearPickerState extends State<_BirthYearPicker> {
  late int _year = widget.initial.clamp(widget.first, widget.last);
  late final _controller = FixedExtentScrollController(
    initialItem: _year - widget.first,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.last - widget.first + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 216,
            child: CupertinoPicker(
              key: const ValueKey('birth-year-picker'),
              itemExtent: 40,
              scrollController: _controller,
              onSelectedItemChanged: (i) => _year = widget.first + i,
              children: [
                for (var i = 0; i < count; i++)
                  Center(
                    child: Text(
                      '${widget.first + i}',
                      style: context.text.titleLarge,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: S.done,
            onPressed: () => Navigator.of(context).pop(_year),
          ),
        ],
      ),
    );
  }
}

class _SexSelector extends StatelessWidget {
  const _SexSelector({required this.value, required this.onChanged});

  final Sex? value;
  final ValueChanged<Sex> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.neutralContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final (sex, label) in [
            (Sex.male, S.sexMale),
            (Sex.female, S.sexFemale),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: value == sex,
                inMutuallyExclusiveGroup: true,
                label: label,
                child: ExcludeSemantics(
                  child: InkWell(
                    key: ValueKey('sex-${sex.name}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onChanged(sex),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: value == sex
                          ? BoxDecoration(
                              color: context.palette.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.palette.border),
                            )
                          : null,
                      child: Text(
                        label,
                        style: context.text.bodyLarge?.copyWith(
                          fontWeight: value == sex
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 5 thẻ mức vận động có mô tả; không hiện hệ số (S-03).
class _ActivityCards extends StatelessWidget {
  const _ActivityCards({required this.value, required this.onChanged});

  final ActivityLevel? value;
  final ValueChanged<ActivityLevel> onChanged;

  static String label(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary => S.activitySedentary,
    ActivityLevel.light => S.activityLight,
    ActivityLevel.moderate => S.activityModerate,
    ActivityLevel.active => S.activityActive,
    ActivityLevel.veryActive => S.activityVeryActive,
  };

  static String hint(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary => S.activitySedentaryHint,
    ActivityLevel.light => S.activityLightHint,
    ActivityLevel.moderate => S.activityModerateHint,
    ActivityLevel.active => S.activityActiveHint,
    ActivityLevel.veryActive => S.activityVeryActiveHint,
  };

  @override
  Widget build(BuildContext context) {
    const levels = ActivityLevel.values;
    return Container(
      decoration: _boxDecoration(context),
      child: Column(
        children: [
          for (var i = 0; i < levels.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: context.palette.border,
              ),
            Semantics(
              button: true,
              selected: value == levels[i],
              inMutuallyExclusiveGroup: true,
              label: '${label(levels[i])}, ${hint(levels[i])}',
              child: ExcludeSemantics(
                child: InkWell(
                  key: ValueKey('activity-${levels[i].name}'),
                  onTap: () => onChanged(levels[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label(levels[i]),
                                style: context.text.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                hint(levels[i]),
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          value == levels[i]
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: value == levels[i]
                              ? context.colors.primary
                              : context.palette.border,
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
          decoration: _boxDecoration(context),
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

import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../../data/sync/sync_providers.dart';
import '../../onboarding/presentation/profile_fields.dart';
import '../application/calorie_updates.dart';
import '../application/calorie_view.dart';
import 'calorie_proposal_sheet.dart';

/// S-51 — Hồ sơ cơ thể (04 S-51): các ô giống S-03 trừ cân nặng ban đầu; cân
/// nặng hiện tại chỉ xem, ghi ở tab Cân nặng (F01-R4). Lưu → "Đã lưu hồ sơ",
/// rồi xử lý mức calo như S-41 (F01-R5).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _height = TextEditingController();
  int? _birthYear;
  Sex? _sex;
  ActivityLevel? _activity;
  Profile? _saved;
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
    super.dispose();
  }

  Future<void> _load() async {
    final p = await ref.read(profileRepositoryProvider).get();
    if (!mounted || p == null) return;
    setState(() => _reset(p));
  }

  void _reset(Profile p) {
    _saved = p;
    _height.text = p.heightCm?.toString() ?? '';
    _birthYear = p.birthYear;
    _sex = p.sex;
    _activity = p.activityLevel;
  }

  bool get _dirty {
    final p = _saved;
    return p != null &&
        (_height.text != (p.heightCm?.toString() ?? '') ||
            _birthYear != p.birthYear ||
            _sex != p.sex ||
            _activity != p.activityLevel);
  }

  void _changed(ProfileField field, [VoidCallback? update]) => setState(() {
    update?.call();
    _errors = {..._errors}..remove(field);
  });

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

  Future<void> _save() async {
    final errors = ProfileRules.validate(
      height: _height.text,
      birthYear: _birthYear,
      sex: _sex,
      activityLevel: _activity,
      weight: null,
      currentYear: ref.read(clockProvider).now().year,
    );
    if (errors.isNotEmpty) {
      setState(() => _errors = errors.toSet());
      // Giống S-03: cuộn tới ô sai đầu tiên.
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
      return;
    }
    final outcome = await ref
        .read(calorieUpdatesProvider)
        .updateProfile(
          heightCm: ProfileRules.parseHeight(_height.text)!,
          birthYear: _birthYear!,
          sex: _sex!,
          activityLevel: _activity!,
        );
    if (!mounted) return;
    // Màn hình đóng; thông báo và S-53 hiện ở tầng gốc (S-50 phía dưới).
    final root = Navigator.of(context, rootNavigator: true).context;
    showToast(context, S.profileSaved);
    await _leave(
      () => _saved = (_saved!).copyWith(
        heightCm: ProfileRules.parseHeight(_height.text),
        birthYear: _birthYear,
        sex: _sex,
        activityLevel: _activity,
      ),
    );
    if (root.mounted) showCalorieOutcome(root, outcome);
  }

  Future<void> _back() async {
    if (_dirty && !await confirmDiscardChanges(context)) return;
    await _leave(() => _reset(_saved!));
  }

  /// Hết thay đổi chưa lưu ([settle]) rồi mới đóng, để [PopScope] cho đi.
  Future<void> _leave(VoidCallback settle) async {
    if (!mounted) return;
    setState(settle);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop();
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
    final weight = ref.watch(latestWeightProvider).value;
    final palette = context.palette;
    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          // Dựng đủ mọi ô (không lười như ListView) để cuộn được tới ô lỗi.
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('profile-back'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(right: 12),
                    ),
                    onPressed: _back,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text(S.tabMe),
                  ),
                ),
                const SizedBox(height: 16),
                Heading(
                  S.bodyProfile,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
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
                    onChanged: (v) =>
                        _changed(ProfileField.sex, () => _sex = v),
                  ),
                ),
                const SizedBox(height: 20),
                FieldBlock(
                  key: _keys[ProfileField.activityLevel],
                  label: S.fieldActivityLevel,
                  error: _error(ProfileField.activityLevel),
                  child: ActivityCards(
                    value: _activity,
                    onChanged: (v) => _changed(
                      ProfileField.activityLevel,
                      () => _activity = v,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // F01-R4: cân nặng chỉ đổi ở tab Cân nặng.
                Card(
                  key: const ValueKey('profile-current-weight'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              S.currentWeight,
                              style: context.text.bodyLarge?.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                            if (weight != null)
                              Text(
                                Fmt.kg(weight.kgX10),
                                style: context.text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        TextButton(
                          key: const ValueKey('go-weight-tab'),
                          onPressed: () => context.go('/weight'),
                          child: const Text(S.logInWeightTab),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: S.save, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/sync/sync_providers.dart';
import '../../schedule/presentation/weekly_template_editor.dart';
import '../application/onboarding_steps.dart';
import 'onboarding_scaffold.dart';

/// S-05 — Lịch tuần (Bước 4/5, F-03). Dùng trình sửa S-22; nút "Lưu lịch
/// tập". Lưu xong app chia lịch tháng theo F03-R5 rồi chuyển sang bước 5.
class ScheduleStepScreen extends ConsumerStatefulWidget {
  const ScheduleStepScreen({super.key});

  @override
  ConsumerState<ScheduleStepScreen> createState() => _ScheduleStepScreenState();
}

class _ScheduleStepScreenState extends ConsumerState<ScheduleStepScreen> {
  Map<int, TemplateDay> _days = {};
  int? _expanded;
  List<TemplateError> _errors = const [];
  bool _attempted = false;
  final _rowKeys = {
    for (var w = DateTime.monday; w <= DateTime.saturday; w++) w: GlobalKey(),
  };
  final _noDayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Nháp đang xếp dở; không có thì lịch tuần đã lưu (quay lại bước này, OB-2).
  Future<void> _load() async {
    final draft = await ref.read(onboardingDraftRepositoryProvider).template();
    final saved = await ref.read(scheduleRepositoryProvider).template();
    final t = draft ?? saved;
    if (!mounted || t == null) return;
    setState(() => _days = {...t.days});
  }

  WeeklyTemplate get _template => WeeklyTemplate(_days);

  void _changed(int weekday, TemplateDay day) {
    setState(() {
      _days = {..._days, weekday: day};
      // Sau lần lưu lỗi, lỗi cập nhật theo từng thay đổi (biến mất khi sửa).
      if (_attempted) _errors = _template.validate();
    });
    unawaited(
      ref.read(onboardingDraftRepositoryProvider).saveTemplate(_template),
    );
  }

  Future<void> _save() async {
    final errors = await ref
        .read(onboardingStepsProvider)
        .saveSchedule(_template);
    if (!mounted) return;
    if (errors.isEmpty) {
      context.go('/onboarding/5');
      return;
    }
    final first = errors.first.weekday;
    setState(() {
      _attempted = true;
      _errors = errors;
      if (first != null) _expanded = first;
    });
    await WidgetsBinding.instance.endOfFrame;
    final target =
        (first == null ? _noDayKey : _rowKeys[first]!).currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(target, alignment: 0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noDay = _errors.any((e) => e.issue == TemplateIssue.noWorkoutDay);
    return OnboardingScaffold(
      step: 4,
      title: S.scheduleStepTitle,
      subtitle: S.scheduleStepSubtitle,
      bottom: [PrimaryButton(label: S.saveSchedule, onPressed: _save)],
      children: [
        WeeklyTemplateEditor(
          days: _days,
          expanded: _expanded,
          errors: _errors,
          rowKeys: _rowKeys,
          onChanged: _changed,
          onExpand: (w) => setState(() => _expanded = w),
        ),
        Padding(
          key: _noDayKey,
          padding: const EdgeInsets.only(top: 12),
          child: noDay
              ? Semantics(
                  liveRegion: true,
                  child: Text(
                    S.noWorkoutDay,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

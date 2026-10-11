import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../../data/sync/sync_providers.dart';
import '../application/schedule_edits.dart';
import 'weekly_template_editor.dart';

/// Đường dẫn S-22 (mở từ nút "Lịch tuần" ở S-20).
const weeklySchedulePath = '/schedule/weekly';

/// S-22 — Lịch tuần, chế độ sửa sau khi thiết lập (04 S-22, F03-R7). Lưu
/// không đổi lịch tháng hiện tại; quay lại S-20 có thông báo nhanh "Đã lưu
/// lịch tuần", banner Chia lại và chấm ở tab Lịch tập.
class WeeklyScheduleScreen extends ConsumerStatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  ConsumerState<WeeklyScheduleScreen> createState() =>
      _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends ConsumerState<WeeklyScheduleScreen> {
  Map<int, TemplateDay> _saved = {};
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

  Future<void> _load() async {
    final t = await ref.read(scheduleRepositoryProvider).template();
    if (!mounted || t == null) return;
    setState(() {
      _saved = {...t.days};
      _days = {...t.days};
    });
  }

  WeeklyTemplate get _template => WeeklyTemplate(_days);

  bool get _dirty =>
      _template.contentHash != WeeklyTemplate(_saved).contentHash;

  void _changed(int weekday, TemplateDay day) {
    setState(() {
      _days = {..._days, weekday: day};
      if (_attempted) _errors = _template.validate();
    });
  }

  Future<void> _save() async {
    final errors = await ref
        .read(scheduleEditsProvider)
        .saveTemplate(_template);
    if (!mounted) return;
    if (errors.isEmpty) {
      showToast(context, S.templateSaved);
      await _leave(() => _saved = {..._days});
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

  Future<void> _back() async {
    if (_dirty && !await confirmDiscardChanges(context)) return;
    await _leave(() => _days = {..._saved});
  }

  /// Hết thay đổi chưa lưu ([settle]) rồi mới đóng, để [PopScope] cho đi.
  Future<void> _leave(VoidCallback settle) async {
    if (!mounted) return;
    setState(settle);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final noDay = _errors.any((e) => e.issue == TemplateIssue.noWorkoutDay);
    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('weekly-back'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(right: 12),
                  ),
                  onPressed: _back,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text(S.tabTraining),
                ),
              ),
              const SizedBox(height: 16),
              Heading(
                S.weeklySchedule,
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                S.weeklyEditHint,
                style: context.text.bodyLarge?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              PrimaryButton(label: S.save, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

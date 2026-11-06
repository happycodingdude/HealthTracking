import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../library/presentation/body_map.dart';
import '../application/session_item_edits.dart';
import '../application/session_providers.dart';
import 'pick_exercise_screen.dart';
import 'session_screen.dart';

/// Thao tác chọn ở S-74.
enum ExerciseAction {
  view,
  replace,
  restoreOriginal,
  skip,
  unskip,
  removeExtra,
}

/// S-74 — Thao tác với bài (04 Bản 5 S-74, UA5-01): mở từ ··· của một bài
/// trong buổi hôm nay. Đầu bảng ảnh vùng cơ tròn 44 + tên bài + "Nhóm · Vùng";
/// các dòng Xem bài · Đổi bài · [Chọn lại bài gốc] · Bỏ qua hôm nay · [Xóa bài
/// thêm — chỉ bài thêm]. Buổi "Đã tập": chỉ Xem bài sáng (BR5-13).
Future<void> openExerciseActions(
  BuildContext context, {
  required LocalDate date,
  required SessionExercise entry,
}) async {
  final action = await showIronlySheet<ExerciseAction>(
    context,
    builder: (_) => ExerciseActionsSheet(date: date, entry: entry),
  );
  if (action == null || !context.mounted) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final item = entry.item;
  switch (action) {
    case ExerciseAction.view:
      unawaited(context.push(todayExercisePath(entry.exercise.id, date)));
    case ExerciseAction.replace:
      // FC5-14: bài đã có bản ghi hôm nay → S-78 trước, xác nhận thì xóa rồi
      // mới sang S-75.
      if (SessionExercises.hasRecords(entry)) {
        final ok = await confirmDeleteRecords(
          context,
          title: S.replaceConfirmTitle,
          action: S.replaceConfirmAction,
          key: 'records-delete-replace',
        );
        if (!ok || !context.mounted) return;
        try {
          await container.read(clearSessionRecordsProvider)(date, item.id);
        } on SessionEditException {
          return;
        }
        if (!context.mounted) return;
      }
      unawaited(context.push(pickExercisePath(date, slot: item.id)));
    case ExerciseAction.restoreOriginal:
      if (SessionExercises.hasRecords(entry)) {
        final ok = await confirmDeleteRecords(
          context,
          title: S.restoreConfirmTitle,
          action: S.restoreConfirmAction,
          key: 'records-delete-restore',
        );
        if (!ok) return;
      }
      try {
        await container.read(replaceExerciseProvider)(
          date,
          item.id,
          item.original!.id,
        );
      } on SessionEditException {
        return;
      }
    case ExerciseAction.skip:
      // F29-R3, FC5-14: bài đã có bản ghi hôm nay → S-78 "Bỏ qua bài?".
      if (SessionExercises.hasRecords(entry)) {
        final ok = await confirmDeleteRecords(
          context,
          title: S.skipConfirmTitle,
          action: S.skipConfirmAction,
          key: 'records-delete-skip',
        );
        if (!ok) return;
      }
      try {
        await container.read(skipExerciseProvider)(
          date,
          item.id,
          skipped: true,
        );
      } on SessionEditException {
        return;
      }
      if (context.mounted) {
        showToast(context, S.skippedExercise(entry.exercise.nameVi));
      }
    case ExerciseAction.unskip:
      try {
        await container.read(skipExerciseProvider)(
          date,
          item.id,
          skipped: false,
        );
      } on SessionEditException {
        return;
      }
    case ExerciseAction.removeExtra:
      // F30-R5, FC5-14: bài thêm đã có bản ghi → S-78 "Xóa bài thêm?".
      if (SessionExercises.hasRecords(entry)) {
        final ok = await confirmDeleteRecords(
          context,
          title: S.removeExtraConfirmTitle,
          action: S.removeExtraConfirmAction,
          key: 'records-delete-remove-extra',
        );
        if (!ok) return;
      }
      try {
        await container.read(removeExtraExerciseProvider)(date, item.id);
      } on SessionEditException {
        return;
      }
  }
}

/// S-78 — Xác nhận xóa bản ghi trước khi đổi / bỏ qua / xóa bài (04 Bản 5
/// S-78, FC5-14): câu giữa cố định, tiêu đề và nút đỏ theo thao tác; "Hủy" →
/// không đổi gì.
Future<bool> confirmDeleteRecords(
  BuildContext context, {
  required String title,
  required String action,
  required String key,
}) async =>
    await showIronlyDialog<bool>(
      context,
      builder: (dialogContext) => IronlyDialog(
        key: ValueKey(key),
        title: title,
        body: S.recordsDeleteBody,
        secondaryLabel: S.cancel,
        onSecondary: () => Navigator.of(dialogContext).pop(false),
        primaryLabel: action,
        destructive: true,
        primaryKey: const ValueKey('records-delete-confirm'),
        onPrimary: () => Navigator.of(dialogContext).pop(true),
      ),
    ) ??
    false;

class ExerciseActionsSheet extends ConsumerWidget {
  const ExerciseActionsSheet({
    super.key,
    required this.date,
    required this.entry,
  });

  final LocalDate date;
  final SessionExercise entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final e = entry.exercise;
    final item = entry.item;
    // Buổi "Đã tập" (hoặc hết ngày): chỉ Xem bài (BR5-13).
    final editable = ref.watch(sessionActionsProvider(date)) == null;
    final isExtra = item.role == SessionExerciseRole.extra;
    void pick(ExerciseAction a) => Navigator.of(context).pop(a);
    final rows = <Widget>[
      _ActionRow(
        key: const ValueKey('action-view'),
        icon: Icons.visibility_outlined,
        label: S.actionViewExercise,
        chevron: true,
        onTap: () => pick(ExerciseAction.view),
      ),
      if (!isExtra)
        _ActionRow(
          key: const ValueKey('action-replace'),
          icon: Icons.swap_horiz,
          label: S.actionReplace,
          chevron: true,
          onTap: editable ? () => pick(ExerciseAction.replace) : null,
        ),
      if (item.role == SessionExerciseRole.replacement)
        _ActionRow(
          key: const ValueKey('action-restore'),
          icon: Icons.undo,
          label: S.actionRestoreOriginal,
          onTap: editable ? () => pick(ExerciseAction.restoreOriginal) : null,
        ),
      _ActionRow(
        key: const ValueKey('action-skip'),
        icon: Icons.remove,
        label: item.skipped ? S.actionUnskip : S.actionSkipToday,
        onTap: editable
            ? () => pick(
                item.skipped ? ExerciseAction.unskip : ExerciseAction.skip,
              )
            : null,
      ),
      // Chỉ bài thêm (Bạn yêu cầu 06/11/2026: bài trong lịch không hiện).
      if (isExtra)
        _ActionRow(
          key: const ValueKey('action-remove-extra'),
          icon: Icons.delete_outline,
          label: S.actionRemoveExtra,
          danger: true,
          onTap: editable ? () => pick(ExerciseAction.removeExtra) : null,
        ),
    ];
    return IronlySheet(
      key: const ValueKey('exercise-actions'),
      children: [
        Semantics(
          header: true,
          child: Row(
            children: [
              ExerciseAvatar(
                id: e.id,
                size: TokenSize.avatarLarge,
                child: ExcludeSemantics(
                  child: BodyMap(
                    region: e.region,
                    size: BodyMap.avatar,
                    bare: true,
                  ),
                ),
              ),
              const SizedBox(width: TokenSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.nameVi, style: IronlyText.subtitle),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.muscle(e.group)} · ${Fmt.region(e.region)}',
                      style: IronlyText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TokenSpace.s3),
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) Divider(height: 0.5, thickness: 0.5, color: t.divider),
          row,
        ],
      ],
    );
  }
}

/// Một dòng của S-74 (`srow`): icon tròn 36 + tên 14 / 500 (+ ›). Không bấm
/// được → mờ 40 %.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.chevron = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool chevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = danger ? t.danger : t.textPrimary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: TokenSpace.s3),
              child: Row(
                children: [
                  CircleIcon(icon, color: danger ? t.danger : t.textSecondary),
                  const SizedBox(width: TokenSpace.s4),
                  Expanded(
                    child: Text(
                      label,
                      style: IronlyText.body.copyWith(color: color),
                    ),
                  ),
                  if (chevron)
                    Icon(Icons.chevron_right, size: 18, color: t.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

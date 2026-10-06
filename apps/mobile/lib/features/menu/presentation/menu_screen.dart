import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/reference_tag.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../data/sync/sync_providers.dart';
import '../application/menu_generator.dart';
import '../application/menu_view.dart';

/// Tên bữa theo vị trí trong ngày (mock S-30-3).
String mealLabel(Meal meal, SnackTime? snack) => switch (meal.type) {
  MealType.breakfast => S.mealBreakfast,
  MealType.lunch => S.mealLunch,
  MealType.dinner => S.mealDinner,
  MealType.snack =>
    snack == SnackTime.morning ? S.mealMorningSnack : S.mealAfternoonSnack,
};

/// S-30 — Thực đơn hôm nay (04 §6.9): trống, đang tạo, có thực đơn, hết lượt;
/// banner F08-E1, F08-E2, F08-E4, lỗi khác, F08-R10; ghi chú F08-R9.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  /// Hỏi trạng thái mỗi 3 giây khi đang tạo (05 §6.9.2).
  static const pollInterval = Duration(seconds: 3);

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  void Function()? _cancelPoll;

  @override
  void dispose() {
    _cancelPoll?.call();
    super.dispose();
  }

  /// Server báo đang tạo mà máy này không chờ yêu cầu nào (rời app rồi quay
  /// lại, F08-E5) → hỏi trạng thái định kỳ khi đang ở S-30.
  void _poll(MenuView view) {
    final waiting = view.generating && !ref.read(menuGeneratorProvider).busy;
    if (!waiting) {
      _cancelPoll?.call();
      _cancelPoll = null;
      return;
    }
    if (_cancelPoll != null) return;
    _cancelPoll = ref.read(syncSchedulerProvider).after(
      MenuScreen.pollInterval,
      () async {
        _cancelPoll = null;
        await ref.read(menuGeneratorProvider.notifier).refresh(view.date);
        if (mounted) _poll(ref.read(menuViewProvider)!);
      },
    );
  }

  Future<void> _regenerate(MenuView view) async {
    final ok =
        await showAppDialog<bool>(
          context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(S.regenerateTitle),
            content: Text(S.regenerateBody(view.remaining)),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(S.cancel),
              ),
              FilledButton(
                key: const ValueKey('confirm-regenerate'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(S.regenerate),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) unawaited(_generate());
  }

  Future<void> _generate() =>
      ref.read(menuGeneratorProvider.notifier).generate();

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(menuViewProvider);
    if (view == null) {
      return const TabPage(tab: AppTab.menu, title: S.menuCardTitle);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _poll(view);
    });
    final palette = context.palette;
    final retryable =
        view.issue == MenuIssue.offline ||
        view.issue == MenuIssue.invalid ||
        view.issue == MenuIssue.provider;
    return TabPage(
      tab: AppTab.menu,
      title: S.menuCardTitle,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              S.menuDateLine(
                Fmt.weekdayDate(view.date),
                Fmt.kcal(view.targetKcal),
              ),
              key: const ValueKey('menu-date-line'),
              style: context.text.titleMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const ReferenceTag(),
          ],
        ),
        if (view.usedSafetyFloor) ...[
          const SizedBox(height: 8),
          Text(
            S.menuSafetyFloor(Fmt.kcal(view.targetKcal)),
            key: const ValueKey('menu-safety-floor'),
            style: context.text.bodyLarge,
          ),
        ],
        for (final (key, text, retry) in [
          if (view.blocked)
            ('menu-banner-budget', S.budgetPaused(view.nextMonth), false),
          if (!view.generating && view.issue == MenuIssue.offline)
            ('menu-banner-offline', S.offlineMenu, false),
          if (!view.generating && view.issue == MenuIssue.invalid)
            ('menu-banner-invalid', S.menuInvalidOutput, view.menu != null),
          if (!view.generating && view.issue == MenuIssue.provider)
            ('menu-banner-error', S.menuProviderError, view.menu != null),
          if (view.calorieChanged && !view.generating)
            ('menu-banner-calorie', S.calorieChangedRegenerate, false),
        ]) ...[
          const SizedBox(height: 16),
          _Banner(
            key: ValueKey(key),
            text: text,
            action: retry && !view.exhausted && !view.blocked
                ? TextButton(
                    key: const ValueKey('banner-retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.attention,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _generate,
                    child: const Text(S.retry),
                  )
                : null,
          ),
        ],
        const SizedBox(height: 16),
        if (view.generating)
          const _Generating()
        else if (view.menu == null)
          _Empty(
            view: view,
            label: retryable ? S.retry : S.generateMenu,
            onPressed: view.blocked || view.exhausted ? null : _generate,
          )
        else ...[
          for (final (meal, snack) in view.menu!.ordered) ...[
            _MealCard(meal: meal, snack: snack),
            const SizedBox(height: 12),
          ],
          _Total(kcal: view.totalKcal ?? view.menu!.totalKcal),
          const SizedBox(height: 16),
          Text(
            S.menuEstimateNote,
            style: context.text.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (view.exhausted)
            Text(
              S.menuQuotaExhausted,
              key: const ValueKey('menu-exhausted'),
              textAlign: TextAlign.center,
              style: context.text.bodyLarge,
            )
          else
            OutlinedButton(
              key: const ValueKey('regenerate'),
              onPressed: view.blocked ? null : () => _regenerate(view),
              child: Text(
                S.regenerateWithRemaining(view.remaining),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ],
    );
  }
}

/// Banner cảnh báo (màu chú ý, không dùng đỏ, UX-AC17).
class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: palette.attentionContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              text,
              style: context.text.bodyLarge?.copyWith(color: palette.attention),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.view,
    required this.label,
    required this.onPressed,
  });

  final MenuView view;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        key: const ValueKey('menu-empty'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ExcludeSemantics(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: context.colors.primaryContainer,
                child: Icon(
                  Icons.radio_button_checked,
                  size: 40,
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Heading(
            S.menuEmptyTitle,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            S.menuEmptyBody,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          if (onPressed == null)
            FilledButton(onPressed: null, child: Text(label))
          else
            PrimaryButton(
              key: const ValueKey('generate-menu'),
              label: label,
              onPressed: onPressed!,
            ),
          const SizedBox(height: 12),
          Text(
            view.exhausted
                ? S.menuQuotaExhausted
                : S.remainingToday(view.remaining),
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung chờ hình 4 thẻ bữa ăn (04 S-30 "Đang tạo", mock S-30-2).
class _Generating extends StatelessWidget {
  const _Generating();

  @override
  Widget build(BuildContext context) {
    final fill = context.palette.neutralContainer;
    Widget bar(double widthFactor) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(
          height: 18,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(9),
          ),
        ),
      ),
    );
    return Column(
      key: const ValueKey('menu-generating'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            S.menuGenerating,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final lines in const [
          [0.3, 0.85, 0.6],
          [0.25, 0.75],
          [0.3, 0.8, 0.7, 0.55],
          [0.25, 0.65],
        ])
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ExcludeSemantics(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final w in lines) bar(w)],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Thẻ một bữa: tên bữa, calo bữa; mỗi món một dòng gồm tên, khẩu phần, calo
/// (04 S-30, mock S-30-3).
class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.snack});

  final Meal meal;
  final SnackTime? snack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = mealLabel(meal, snack);
    return Card(
      key: ValueKey(
        'meal-${meal.type.name}${snack == null ? '' : '-${snack!.name}'}',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Line(
              left: Text(
                label,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              right: Text(
                Fmt.kcal(meal.kcal),
                style: context.text.bodyLarge?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
            for (final d in meal.dishes)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _Line(
                  left: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name, style: context.text.bodyLarge),
                      Text(
                        d.portion,
                        style: context.text.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  right: Text(
                    Fmt.kcal(d.kcal),
                    style: context.text.bodyLarge?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Trái và phải trên một hàng; cỡ chữ lớn thì xếp dọc (UX-AC18).
class _Line extends StatelessWidget {
  const _Line({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.6) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [left, right],
      );
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        right,
      ],
    );
  }
}

/// "Tổng: {X} kcal" kèm nhãn "tham khảo" (04 S-30, F08-AC7).
class _Total extends StatelessWidget {
  const _Total({required this.kcal});

  final int kcal;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('menu-total'),
      label: '${S.menuTotal}: ${Fmt.kcal(kcal)}',
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          ExcludeSemantics(
            child: Text(
              S.menuTotal,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              ExcludeSemantics(
                child: Text(
                  Fmt.kcal(kcal),
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const ReferenceTag(),
            ],
          ),
        ],
      ),
    );
  }
}

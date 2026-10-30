import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../application/menu_generator.dart';
import '../application/menu_view.dart';

/// Tên bữa theo vị trí trong ngày.
String mealLabel(Meal meal, SnackTime? snack) => switch (meal.type) {
  MealType.breakfast => S.mealBreakfast,
  MealType.lunch => S.mealLunch,
  MealType.dinner => S.mealDinner,
  MealType.snack =>
    snack == SnackTime.morning ? S.mealMorningSnack : S.mealAfternoonSnack,
};

/// S-30 — Thực đơn hôm nay (04 Bản 4 S-30): "THỨ 2, 26/10" in hoa nhỏ ·
/// "Thực đơn" 17 · kcal ngày phải; mỗi bữa tiêu đề cam in hoa + thẻ các dòng
/// món (tên trắng + khẩu phần chữ phụ · kcal); dưới cùng nút phụ viền cam
/// "↻ Gợi ý lại · 2". Trống: icon bát + nút cam "Gợi ý thực đơn" + "Còn 3
/// lượt". Đang tạo: tiêu đề bữa + khung chờ + "Đang lên thực đơn…". Banner
/// (không mạng, chạm trần, mức calo đổi, lỗi): thẻ viền cam dưới tiêu đề,
/// câu giữ nguyên. Không nhãn "tham khảo", không câu giải thích (BR4-15,
/// BR4-08). Quy tắc F-08, F-11 như Bản 1.
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
        await showIronlyDialog<bool>(
          context,
          builder: (dialogContext) => IronlyDialog(
            title: S.regenerateTitle,
            body: S.regenerateBody(view.remaining),
            secondaryLabel: S.cancel,
            onSecondary: () => Navigator.of(dialogContext).pop(false),
            primaryLabel: S.regenerate,
            primaryKey: const ValueKey('confirm-regenerate'),
            onPrimary: () => Navigator.of(dialogContext).pop(true),
          ),
        ) ??
        false;
    if (ok) await _generate();
  }

  Future<void> _generate() =>
      ref.read(menuGeneratorProvider.notifier).generate();

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(menuViewProvider);
    if (view == null) {
      return const IronlyTabPage(tab: AppTab.menu, title: S.tabMenu);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _poll(view);
    });
    final retryable =
        view.issue == MenuIssue.offline ||
        view.issue == MenuIssue.invalid ||
        view.issue == MenuIssue.provider;
    final menu = view.menu;
    return IronlyTabPage(
      tab: AppTab.menu,
      title: S.tabMenu,
      header: Fmt.weekdayDate(view.date),
      // Kcal ngày = mức calo của Bạn (mock S-30 "1.850 kcal"; Bản 3 "Theo mức").
      trailing: Text(
        Fmt.kcal(view.targetKcal),
        key: const ValueKey('menu-date-line'),
        style: IronlyText.caption,
      ),
      children: [
        if (view.usedSafetyFloor) ...[
          IronlyBanner(
            key: const ValueKey('menu-safety-floor'),
            text: S.menuSafetyFloor(Fmt.kcal(view.targetKcal)),
          ),
          const CardGap(),
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
          IronlyBanner(
            key: ValueKey(key),
            text: text,
            actionLabel: retry && !view.exhausted && !view.blocked
                ? S.retry
                : null,
            actionKey: const ValueKey('banner-retry'),
            onAction: _generate,
          ),
          const CardGap(),
        ],
        if (view.generating)
          const _Generating()
        else if (menu == null)
          _Empty(
            view: view,
            label: retryable ? S.retry : S.generateMenuShort,
            onPressed: view.blocked || view.exhausted ? null : _generate,
          )
        else ...[
          for (final (meal, snack) in menu.ordered)
            _MealSection(meal: meal, snack: snack),
          Semantics(
            key: const ValueKey('menu-total'),
            label:
                '${S.menuTotal}: ${Fmt.kcal(view.totalKcal ?? menu.totalKcal)}',
            child: const SizedBox.shrink(),
          ),
          const SizedBox(height: TokenSpace.s2),
          if (view.exhausted)
            const IronlyBanner(
              key: ValueKey('menu-exhausted'),
              text: S.menuQuotaExhausted,
            )
          else
            IronlyButton(
              key: const ValueKey('regenerate'),
              kind: IronlyButtonKind.secondaryAccent,
              icon: Icons.refresh,
              label: S.regenerateShort(view.remaining),
              enabled: !view.blocked,
              onPressed: () => _regenerate(view),
            ),
        ],
      ],
    );
  }
}

/// Trống (04 Bản 4 S-30): thẻ với icon bát + nút cam + "Còn n lượt" chữ phụ.
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
    return EmptyAction(
      key: const ValueKey('menu-empty'),
      icon: Icons.soup_kitchen_outlined,
      action: IronlyButton.primary(
        key: const ValueKey('generate-menu'),
        label: label,
        enabled: onPressed != null,
        onPressed: onPressed,
      ),
      caption: view.exhausted ? null : S.remainingShort(view.remaining),
    );
  }
}

/// Đang tạo: tiêu đề bữa + khung chờ + "Đang lên thực đơn…" (chữ đang chờ
/// còn giữ).
class _Generating extends StatelessWidget {
  const _Generating();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('menu-generating'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, lines) in [
          (S.mealBreakfast, 2),
          (S.mealLunch, 3),
          (S.mealDinner, 2),
        ]) ...[
          _MealTitle(label),
          IronlyCard(child: SkeletonLines(lines: lines)),
          const SizedBox(height: TokenSpace.s4),
        ],
        Semantics(
          liveRegion: true,
          child: Text(
            S.menuGenerating,
            textAlign: TextAlign.center,
            style: IronlyText.caption,
          ),
        ),
      ],
    );
  }
}

class _MealTitle extends StatelessWidget {
  const _MealTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TokenSpace.s2, left: 2),
    child: Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: IronlyText.groupLabel.copyWith(color: context.tokens.accent),
      ),
    ),
  );
}

/// Một bữa: tiêu đề cam in hoa; thẻ các dòng món: tên trắng 14 + khẩu phần
/// chữ phụ 11 · kcal phải (04 Bản 4 S-30).
class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal, required this.snack});

  final Meal meal;
  final SnackTime? snack;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      key: ValueKey(
        'meal-${meal.type.name}${snack == null ? '' : '-${snack!.name}'}',
      ),
      padding: const EdgeInsets.only(bottom: TokenSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _MealTitle(mealLabel(meal, snack))),
              Padding(
                padding: const EdgeInsets.only(bottom: TokenSpace.s2),
                child: Text(Fmt.kcal(meal.kcal), style: IronlyText.caption),
              ),
            ],
          ),
          IronlyListCard(
            children: [
              for (final d in meal.dishes)
                IronlyRow(
                  key: ValueKey('dish-${d.name}'),
                  title: d.name,
                  minHeight: 44,
                  trailing: Text(
                    Fmt.integer(d.kcal),
                    style: IronlyText.body.copyWith(
                      color: t.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  semanticsLabel:
                      '${d.name}, ${d.portion}, ${Fmt.kcal(d.kcal)}',
                  // Tên trắng 14 + khẩu phần chữ phụ 11 cùng dòng (mock S-30).
                  titleWidget: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 6,
                    children: [
                      Text(d.name, style: IronlyText.body),
                      if (d.portion.isNotEmpty)
                        Text(d.portion, style: IronlyText.caption),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

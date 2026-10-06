import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../application/budget_view.dart';

/// Đường dẫn S-54.
const budgetPath = '/me/budget';

/// Thanh tiến trình ngân sách: màu chủ đạo dưới 80%, màu cảnh báo từ 80% và
/// khi đã chạm trần (04 S-54).
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.view, this.height = 12});

  final AiBudgetView view;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: LinearProgressIndicator(
      value: view.percent / 100,
      minHeight: height,
      color: view.warning ? context.palette.attention : context.colors.primary,
      backgroundColor: context.palette.neutralContainer,
    ),
  );
}

/// S-54 — Ngân sách AI (04 S-54, F11-R6): số tiền và phần trăm đã dùng, ngày
/// đặt lại, giải thích; không có ô sửa mức trần (F11-R7).
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(aiBudgetViewProvider);
    final palette = context.palette;
    final secondary = context.text.bodyLarge?.copyWith(
      color: palette.textSecondary,
    );
    return Scaffold(
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
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.chevron_left),
                label: const Text(S.tabMe),
              ),
            ),
            const SizedBox(height: 16),
            Heading(
              S.aiBudget,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              key: const ValueKey('budget-card'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      Fmt.vnd(view.usedVnd),
                      key: const ValueKey('budget-used'),
                      style: context.text.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: view.warning ? palette.attention : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      S.budgetOfMonth(Fmt.vnd(view.capVnd), view.month.month),
                      style: secondary,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: S.percent(view.percent),
                      child: ExcludeSemantics(child: BudgetBar(view: view)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          S.percent(view.percent),
                          key: const ValueKey('budget-percent'),
                          style: context.text.bodyMedium?.copyWith(
                            color: view.warning
                                ? palette.attention
                                : palette.textSecondary,
                          ),
                        ),
                        Text(
                          S.budgetResets(Fmt.dayMonth(view.resetDate)),
                          style: context.text.bodyMedium?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (view.blocked) ...[
              const SizedBox(height: 16),
              Container(
                key: const ValueKey('budget-blocked'),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: palette.attentionContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  S.budgetPaused(view.month.next.month),
                  style: context.text.bodyLarge?.copyWith(
                    color: palette.attention,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(S.budgetExplain, style: secondary),
          ],
        ),
      ),
    );
  }
}

/// Hộp báo 80% (04 §6.9, F11-R4): "Đã hiểu" và liên kết "Xem chi tiết" → S-54.
Future<void> showBudgetWarning(BuildContext context) => showAppDialog<void>(
  context,
  builder: (dialogContext) => AlertDialog(
    key: const ValueKey('budget-warning'),
    content: Text(S.budgetWarning80, style: dialogContext.text.titleMedium),
    actions: [
      TextButton(
        key: const ValueKey('budget-warning-details'),
        onPressed: () {
          Navigator.of(dialogContext).pop();
          context.go(budgetPath);
        },
        child: const Text(S.seeDetails),
      ),
      FilledButton(
        key: const ValueKey('budget-warning-ok'),
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text(S.understood),
      ),
    ],
  ),
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../application/budget_view.dart';

/// Đường dẫn S-54.
const budgetPath = '/me/budget';

/// Thanh tiến trình ngân sách: cam dưới 80 %, đỏ từ 80 % và khi đã chạm trần
/// (04 Bản 4 S-54).
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.view, this.height = 8});

  final AiBudgetView view;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: view.percent / 100,
        minHeight: height,
        color: view.warning ? t.danger : t.accent,
        backgroundColor: t.surfaceRaised,
      ),
    );
  }
}

/// S-54 — Ngân sách AI (04 Bản 4 S-54, F11-R6): số lớn "12.500đ" + "/
/// 50.000đ" chữ phụ; thanh tiến độ + "25%"; chạm trần: banner câu nguyên văn.
/// Không dòng "Đặt lại vào…", không đoạn giải thích (FR4-04); không ô sửa mức
/// trần (F11-R7).
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(aiBudgetViewProvider);
    final t = context.tokens;
    return IronlySubPage(
      title: S.aiBudget,
      children: [
        IronlyCard(
          key: const ValueKey('budget-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: S.budgetSummary(
                  Fmt.vnd(view.usedVnd),
                  Fmt.vnd(view.capVnd),
                ),
                child: ExcludeSemantics(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: Fmt.vnd(view.usedVnd),
                          style: IronlyText.numberLarge.copyWith(
                            color: view.warning ? t.danger : null,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${Fmt.vnd(view.capVnd)}',
                          style: IronlyText.caption,
                        ),
                      ],
                    ),
                    key: const ValueKey('budget-used'),
                  ),
                ),
              ),
              const SizedBox(height: TokenSpace.s3),
              Semantics(
                label: S.percent(view.percent),
                child: ExcludeSemantics(child: BudgetBar(view: view)),
              ),
              const SizedBox(height: TokenSpace.s2),
              Align(
                alignment: Alignment.centerRight,
                child: ExcludeSemantics(
                  child: Text(
                    S.percent(view.percent),
                    key: const ValueKey('budget-percent'),
                    style: IronlyText.caption.copyWith(
                      color: view.warning ? t.danger : t.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (view.blocked) ...[
          const CardGap(),
          IronlyBanner(
            key: const ValueKey('budget-blocked'),
            text: S.budgetPaused(view.month.next.month),
          ),
        ],
      ],
    );
  }
}

/// Hộp báo 80 % (04 §6.9, F11-R4): "Đã hiểu" và "Xem chi tiết" → S-54.
Future<void> showBudgetWarning(BuildContext context) => showIronlyDialog<void>(
  context,
  builder: (dialogContext) => IronlyDialog(
    key: const ValueKey('budget-warning'),
    title: S.budgetWarning80,
    secondaryLabel: S.seeDetails,
    secondaryKey: const ValueKey('budget-warning-details'),
    onSecondary: () {
      Navigator.of(dialogContext).pop();
      context.go(budgetPath);
    },
    primaryLabel: S.understood,
    primaryKey: const ValueKey('budget-warning-ok'),
    onPrimary: () => Navigator.of(dialogContext).pop(),
  ),
);

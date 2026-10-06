import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/calorie_view.dart';
import '../../today/application/today_view.dart';
import 'menu_generator.dart';

/// Thực đơn hôm nay trên máy (F08-R11: xem lại không cần mạng).
final todayMenuProvider = StreamProvider<MenuData?>(
  (ref) => ref.watch(menuRepositoryProvider).watch(ref.watch(todayProvider)),
);

/// Số lần tạo thành công hôm nay (F08-R2).
final todayMenuUsageProvider = StreamProvider<int>(
  (ref) =>
      ref.watch(menuRepositoryProvider).watchUsage(ref.watch(todayProvider)),
);

/// Ngân sách AI của tháng từ lần pull gần nhất (ED-04).
final aiBudgetProvider = StreamProvider<AiBudgetMeta?>(
  (ref) => ref.watch(menuRepositoryProvider).watchBudget(),
);

/// Nội dung S-30 và thẻ thực đơn ở Hôm nay (04 §6.9, §6.7.4).
final class MenuView {
  const MenuView({
    required this.date,
    required this.targetKcal,
    required this.usedSafetyFloor,
    required this.menu,
    required this.totalKcal,
    required this.generating,
    required this.remaining,
    required this.issue,
    required this.blocked,
    required this.calorieChanged,
    required this.nextMonth,
  });

  final LocalDate date;

  /// "Theo mức {X} kcal": mức của thực đơn đang có, chưa có thì mức calo dùng
  /// cho thực đơn lúc này (F02-R6).
  final int targetKcal;

  /// Ghi chú F08-R9.
  final bool usedSafetyFloor;

  /// Thực đơn hôm nay; null = trống.
  final Menu? menu;
  final int? totalKcal;

  /// Đang lên thực đơn (đang chờ server, hoặc server báo đang tạo).
  final bool generating;

  /// Lượt còn lại hôm nay.
  final int remaining;

  /// Lỗi của lần tạo gần nhất (F08-E1, E4, lỗi khác); ngân sách ở [blocked].
  final MenuIssue? issue;

  /// F08-E2, F11-R5: gợi ý AI tạm dừng đến ngày 1 tháng sau.
  final bool blocked;

  /// F08-R10: mức calo đã đổi sau khi có thực đơn.
  final bool calorieChanged;

  /// Tháng sau (câu F08-E2).
  final int nextMonth;

  /// F08-E3.
  bool get exhausted => remaining == 0 || issue == MenuIssue.quota;
}

final menuViewProvider = Provider<MenuView?>((ref) {
  final calorie = ref.watch(calorieViewProvider);
  if (calorie == null) return null;
  final date = ref.watch(todayProvider);
  final stored = ref.watch(todayMenuProvider).value;
  final used = ref.watch(todayMenuUsageProvider).value ?? 0;
  final gen = ref.watch(menuGeneratorProvider);
  final budget = ref.watch(aiBudgetProvider).value;
  final month = AiBudgetRules.monthOf(ref.watch(nowProvider));
  final target = MenuRules.target(calorie.kcal, calorie.sex);
  final payload = stored?.payload;
  final mine = gen.date == date;
  // Lỗi của lần bấm trên máy này; không có thì lỗi lần tạo gần nhất trên
  // server (ví dụ yêu cầu bị dọn sau 10 phút, TAC-12).
  final issue = mine && gen.issue != null
      ? gen.issue
      : stored?.lastAttemptStatus == MenuAttemptStatus.failed
      ? (stored!.lastErrorCode == ErrorCode.aiInvalidOutput
            ? MenuIssue.invalid
            : MenuIssue.provider)
      : null;
  return MenuView(
    date: date,
    targetKcal: payload != null ? stored!.targetKcal : target.kcal,
    usedSafetyFloor: payload != null
        ? stored!.usedSafetyFloor
        : target.usedSafetyFloor,
    menu: payload,
    totalKcal: stored?.totalKcal,
    generating:
        (mine && gen.busy) ||
        stored?.lastAttemptStatus == MenuAttemptStatus.generating,
    remaining: MenuRules.remaining(used),
    issue: issue == MenuIssue.budget ? null : issue,
    blocked:
        issue == MenuIssue.budget ||
        (budget != null && budget.blocked && budget.month == month),
    calorieChanged: payload != null && stored!.targetKcal != target.kcal,
    nextMonth: month.next.month,
  );
});

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../menu/application/menu_view.dart';

/// Nội dung S-54 và dòng "Ngân sách AI" ở S-50 (F11-R6).
final class AiBudgetView {
  const AiBudgetView({
    required this.month,
    required this.usedVnd,
    required this.capVnd,
    required this.blocked,
  });

  final YearMonth month;

  /// Đã dùng, làm tròn tới đồng.
  final int usedVnd;
  final int capVnd;

  /// F11-R5: đã chạm trần, gợi ý AI tạm dừng đến tháng sau.
  final bool blocked;

  int get percent => AiBudgetRules.percent(usedVnd, capVnd);

  /// Từ 80% đổi sang màu cảnh báo (04 S-54).
  bool get warning => blocked || AiBudgetRules.reachedWarning(usedVnd, capVnd);

  LocalDate get resetDate => AiBudgetRules.resetDate(month);
}

/// Ngân sách của tháng hiện tại (giờ Việt Nam) từ lần pull gần nhất. Chưa
/// có số liệu của tháng này (sang tháng mới, chưa đồng bộ) → 0đ (F11-E2).
final aiBudgetViewProvider = Provider<AiBudgetView>((ref) {
  final month = AiBudgetRules.monthOf(ref.watch(nowProvider));
  final meta = ref.watch(aiBudgetProvider).value;
  final current = meta != null && meta.month == month;
  return AiBudgetView(
    month: month,
    usedVnd: current ? meta.usedVnd.round() : 0,
    capVnd: current ? meta.capVnd : AiBudgetRules.capVnd,
    blocked: current && meta.blocked,
  );
});

/// Hộp "Bạn đã dùng 80% ngân sách AI tháng này." đang chờ hiện (F11-R4):
/// bật khi lần tạo thực đơn vừa xong có `budgetWarning80`, tắt khi đã hiện.
class BudgetWarning extends Notifier<bool> {
  @override
  bool build() => false;

  void raise() => state = true;

  void shown() => state = false;
}

final budgetWarningProvider = NotifierProvider<BudgetWarning, bool>(
  BudgetWarning.new,
);

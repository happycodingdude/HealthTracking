import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../data/api/api_client.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/calorie_view.dart';
import '../data/menu_api.dart';

/// Lý do lần bấm tạo gần nhất không ra thực đơn (04 S-30 "Lỗi và giới hạn").
enum MenuIssue {
  /// F08-E1.
  offline,

  /// F08-E2.
  budget,

  /// F08-E3.
  quota,

  /// F08-E4.
  invalid,

  /// Lỗi khác.
  provider,
}

/// Trạng thái lần bấm tạo thực đơn của [date]: đang chờ server ([busy]) hoặc
/// lỗi ([issue]). Thực đơn đã tạo nằm trong database trên máy.
final class MenuGeneration {
  const MenuGeneration({this.date, this.busy = false, this.issue});

  final LocalDate? date;
  final bool busy;
  final MenuIssue? issue;
}

/// Tạo thực đơn (06 VS12-T10): cần mạng; server kiểm lượt, ngân sách và tạo.
/// Kết quả được ghi vào database trên máy rồi đồng bộ (pull) để khớp server.
class MenuGenerator extends Notifier<MenuGeneration> {
  static const _uuid = Uuid();

  @override
  MenuGeneration build() => const MenuGeneration();

  /// Bấm "Gợi ý thực đơn hôm nay", "Gợi ý lại" hoặc "Thử lại". Trả kết quả
  /// khi thành công (VS-13 dùng cờ báo 80%).
  Future<GenerateMenuResponse?> generate() async {
    if (state.busy) return null;
    final view = ref.read(calorieViewProvider);
    if (view == null) return null;
    final date = LocalDate.fromDateTime(ref.read(clockProvider).now());
    state = MenuGeneration(date: date, busy: true);
    if (!await ref.read(connectivityProvider).isOnline()) {
      state = MenuGeneration(date: date, issue: MenuIssue.offline);
      return null;
    }
    try {
      final res = await ref
          .read(menuApiProvider)
          .generate(
            GenerateMenuRequest(
              localDate: date,
              requestId: _uuid.v4(),
              // Server tự áp ngưỡng an toàn (FR-05).
              targetKcal: view.kcal,
            ),
          );
      await _save(res.date, res.menu, res.remaining);
      state = MenuGeneration(date: date);
      return res;
    } on NetworkFailure {
      state = MenuGeneration(date: date, issue: MenuIssue.offline);
    } on ServerFailure catch (e) {
      final issue = switch (e.error.code) {
        ErrorCode.budgetExhausted => MenuIssue.budget,
        ErrorCode.menuQuotaExhausted => MenuIssue.quota,
        ErrorCode.aiInvalidOutput => MenuIssue.invalid,
        // Đang có yêu cầu khác chạy: hiện "Đang tạo" và hỏi trạng thái.
        ErrorCode.generationInProgress => null,
        _ => MenuIssue.provider,
      };
      state = MenuGeneration(date: date, issue: issue);
      if (issue == null) await refresh(date);
    } finally {
      // Lỗi cũng làm server đổi trạng thái thực đơn, lượt, ngân sách.
      unawaited(ref.read(syncEngineProvider).syncNow());
    }
    return null;
  }

  /// Hỏi trạng thái khi thực đơn đang tạo (rời màn hình rồi quay lại, F08-E5).
  Future<void> refresh(LocalDate date) async {
    try {
      final s = await ref.read(menuApiProvider).status(date);
      final menu = s.menu;
      if (menu != null) await _save(date, menu, s.remaining);
    } on ApiFailure {
      // Thử lại ở lần hỏi sau hoặc khi đồng bộ.
    }
  }

  Future<void> _save(LocalDate date, MenuData menu, int remaining) {
    final repo = ref.read(menuRepositoryProvider);
    return ref.read(databaseProvider).transaction(() async {
      await repo.put(date, menu);
      await repo.putUsage(
        AiDailyUsageCodec.key(date),
        MenuRules.maxDaily - remaining,
      );
    });
  }
}

final menuGeneratorProvider = NotifierProvider<MenuGenerator, MenuGeneration>(
  MenuGenerator.new,
);

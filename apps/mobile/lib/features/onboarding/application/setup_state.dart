import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/sync_providers.dart';

/// Thiết lập lần đầu trên máy này đang ở đâu (OB-3, OB-6, NAV-1).
final class SetupState {
  const SetupState._(this.step, this.isCompleted);

  factory SetupState.of(Profile? p) => p == null
      ? notStarted
      : p.isOnboardingCompleted
      ? completed
      : SetupState._(p.onboardingStep, false);

  /// Chưa bấm "Tôi đã hiểu": bắt đầu từ bước 1.
  static const notStarted = SetupState._(1, false);
  static const completed = SetupState._(ProfileRules.onboardingSteps, true);

  /// Bước đang dở (1–5).
  final int step;
  final bool isCompleted;

  String get path => '/onboarding/$step';

  @override
  bool operator ==(Object other) =>
      other is SetupState &&
      other.step == step &&
      other.isCompleted == isCompleted;

  @override
  int get hashCode => Object.hash(step, isCompleted);

  @override
  String toString() =>
      isCompleted ? 'SetupState(completed)' : 'SetupState($step)';
}

/// Trạng thái đọc từ máy lúc khởi động (override trong `main.dart`), để màn
/// hình đầu tiên đã đúng chỗ.
final initialSetupProvider = Provider<SetupState>(
  (ref) => SetupState.notStarted,
);

final setupStateProvider = StreamProvider<SetupState>(
  (ref) => ref.watch(profileRepositoryProvider).watch().map(SetupState.of),
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../ui/theme.dart';

/// Kết quả gọi `/healthz` của server dev (demo VS-00).
final serverHealthProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(apiClientProvider).healthz(),
);

/// Dòng chẩn đoán chỉ có ở flavor `dev` (ED-15): server dev trên Mac có trả lời
/// không. Không phải câu chữ sản phẩm nên không nằm trong strings_vi.dart.
class DevServerStatus extends ConsumerWidget {
  const DevServerStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(envProvider);
    if (!env.isDev) return const SizedBox.shrink();
    final health = ref.watch(serverHealthProvider);
    final status = switch (health) {
      AsyncData(value: true) => 'OK',
      AsyncData(value: false) || AsyncError() => 'unreachable',
      _ => '...',
    };
    return GestureDetector(
      onTap: () => ref.invalidate(serverHealthProvider),
      child: Text(
        'Dev server: $status (${env.apiBaseUrl})',
        key: const ValueKey('dev-server-status'),
        style: context.text.bodySmall?.copyWith(
          color: context.tokens.textSecondary,
        ),
      ),
    );
  }
}

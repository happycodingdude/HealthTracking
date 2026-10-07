import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/toast.dart';
import '../../auth/application/auth_controller.dart';
import '../application/restore_controller.dart';

/// S-07 — Khôi phục dữ liệu (04 S-07): toàn màn hình, thanh tiến trình; mất
/// kết nối → câu lỗi và "Thử lại"; xong → Hôm nay kèm "Đã khôi phục dữ liệu".
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final setup = await ref.read(restoreControllerProvider.notifier).run();
    if (setup == null || !mounted) return;
    if (setup.isCompleted) showToast(context, S.restored);
    ref.read(authControllerProvider.notifier).restored(setup);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restoreControllerProvider);
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Heading(
                  S.restoreTitle,
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: S.restoreTitle,
                  value: '${(state.progress * 100).round()}%',
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        key: const ValueKey('restore-progress'),
                        value: state.progress,
                        minHeight: 12,
                        backgroundColor: palette.neutralContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (state.failed) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      S.restoreFailed,
                      key: const ValueKey('restore-failed'),
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    key: const ValueKey('restore-retry'),
                    label: S.retry,
                    onPressed: _run,
                  ),
                ] else
                  Text(
                    S.restoreSubtitle,
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

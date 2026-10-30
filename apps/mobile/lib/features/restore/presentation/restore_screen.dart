import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../application/restore_controller.dart';

/// S-07 — Khôi phục dữ liệu (04 Bản 4 S-07): thanh tiến trình cam + "Đang
/// khôi phục dữ liệu của Bạn…"; lỗi: câu giữ nguyên + "Thử lại"; xong → Hôm
/// nay kèm "Đã khôi phục dữ liệu".
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
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: TokenSpace.s6,
              vertical: TokenSpace.s4,
            ),
            child: IronlyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: S.restoreTitle,
                    value: '${(state.progress * 100).round()}%',
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          key: const ValueKey('restore-progress'),
                          value: state.progress,
                          minHeight: 6,
                          color: t.accent,
                          backgroundColor: t.surfaceRaised,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: TokenSpace.s3),
                  if (state.failed) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        S.restoreFailed,
                        key: const ValueKey('restore-failed'),
                        textAlign: TextAlign.center,
                        style: IronlyText.body,
                      ),
                    ),
                    const SizedBox(height: TokenSpace.s4),
                    IronlyButton.primary(
                      key: const ValueKey('restore-retry'),
                      label: S.retry,
                      onPressed: _run,
                    ),
                  ] else
                    Text(
                      S.restoreTitle,
                      textAlign: TextAlign.center,
                      style: IronlyText.caption,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

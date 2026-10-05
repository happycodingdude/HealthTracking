import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/sync_providers.dart';
import '../features/auth/application/auth_controller.dart';
import 'providers.dart';

/// Bật/tắt đồng bộ theo vòng đời app (05 §6.6.4):
/// - Đã đăng nhập và app ở foreground → chạy (đồng bộ ngay khi mở app).
/// - App chạy nền, chưa đăng nhập hoặc phiên hết hạn → dừng.
/// - Có mạng trở lại → đồng bộ ngay.
class SyncCoordinator extends ConsumerStatefulWidget {
  const SyncCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncCoordinator> createState() => _SyncCoordinatorState();
}

class _SyncCoordinatorState extends ConsumerState<SyncCoordinator> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<bool>? _connectivity;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => _setForeground(true),
      onHide: () => _setForeground(false),
    );
    _connectivity = ref.read(connectivityProvider).changes.listen((online) {
      if (online) ref.read(syncEngineProvider).onConnectivityRestored();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  void _setForeground(bool value) {
    _foreground = value;
    _apply();
  }

  void _apply() {
    if (!mounted) return;
    final engine = ref.read(syncEngineProvider);
    final signedIn =
        ref.read(authControllerProvider).status == AuthStatus.signedIn;
    if (signedIn && _foreground) {
      engine.start();
    } else {
      engine.stop();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_connectivity?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, _) => _apply());
    return widget.child;
  }
}

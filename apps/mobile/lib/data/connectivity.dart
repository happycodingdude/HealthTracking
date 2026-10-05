import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Theo dõi trạng thái mạng của iPhone. Dùng để đồng bộ ngay khi có mạng trở
/// lại (05 §6.6.4). Không hiện banner mất mạng toàn app (04 §6.14).
abstract interface class ConnectivityMonitor {
  Future<bool> isOnline();

  /// Phát `true` khi có mạng, `false` khi mất mạng; chỉ phát khi đổi trạng thái.
  Stream<bool> get changes;
}

final class DeviceConnectivity implements ConnectivityMonitor {
  DeviceConnectivity([Connectivity? connectivity])
    : _c = connectivity ?? Connectivity();

  final Connectivity _c;

  static bool _online(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async => _online(await _c.checkConnectivity());

  @override
  Stream<bool> get changes => _c.onConnectivityChanged.map(_online).distinct();
}

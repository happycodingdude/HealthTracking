import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_tab.dart';

/// Các màn đang mở trong từng tab. Đưa tab về trang đầu (NAV-15) bỏ các màn
/// con mà không qua [PopScope], nên trước đó phải biết tab có màn đang sửa
/// dở (`PopScope(canPop: false)`, ví dụ S-22, S-51) để hỏi trước (NAV-6).
final class TabStacks {
  final _observers = {for (final t in AppTab.values) t: _StackObserver()};

  /// Gắn vào `StatefulShellBranch.observers` của tab [tab].
  NavigatorObserver observer(AppTab tab) => _observers[tab]!;

  bool hasUnsavedChanges(AppTab tab) => _observers[tab]!.routes.any(
    (r) => r.popDisposition == RoutePopDisposition.doNotPop,
  );
}

final class _StackObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (i >= 0) routes.removeAt(i);
    if (newRoute != null) routes.insert(i >= 0 ? i : routes.length, newRoute);
  }
}

final tabStacksProvider = Provider<TabStacks>((ref) => TabStacks());

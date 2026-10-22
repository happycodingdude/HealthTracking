import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../data/db/app_database.dart';
import '../features/account/application/logout.dart';
import 'app.dart';
import 'strings_vi.dart';
import 'theme.dart';

/// Một lần khởi động: database đang mở và các override của ProviderScope.
typedef AppStart = ({AppDatabase db, List<Override> overrides});

/// Khởi động (mở database, đọc phiên, hồ sơ); [afterLogout] = vừa xóa dữ liệu
/// đăng xuất, vào màn Đăng nhập.
typedef AppBoot = Future<AppStart> Function({required bool afterLogout});

/// Gốc của app (05 Bản 3 §6.6.6, TD3-17, NAV-19). Đăng xuất: đóng mọi màn hình
/// (ProviderScope cũ bị hủy, không còn ai đọc database) → [LocalDataEraser] →
/// khởi động lại từ đầu như lần cài mới, lịch sử điều hướng mất theo. Mở app mà
/// cờ `logout_pending` còn bật ([initial] = null): xóa nốt trước (F27-E2).
class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.boot,
    required this.eraser,
    required this.initial,
  });

  final AppBoot boot;
  final LocalDataEraser Function() eraser;
  final AppStart? initial;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppStart? _start;
  Key _scope = UniqueKey();

  @override
  void initState() {
    super.initState();
    _start = widget.initial;
    if (_start == null) _finish(null);
  }

  Future<void> _logout() async {
    final db = _start?.db;
    setState(() => _start = null);
    await WidgetsBinding.instance.endOfFrame;
    await _finish(db);
  }

  Future<void> _finish(AppDatabase? db) async {
    await widget.eraser().run(db);
    final next = await widget.boot(afterLogout: true);
    if (!mounted) return;
    setState(() {
      _start = next;
      _scope = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    if (start == null) return const LogoutFinishingApp();
    return ProviderScope(
      key: _scope,
      // Không tự thử lại provider lỗi; lỗi được xử lý tường minh.
      retry: (_, _) => null,
      overrides: [
        ...start.overrides,
        logoutFinisherProvider.overrideWithValue(_logout),
      ],
      child: const IronlyApp(),
    );
  }
}

/// Màn chờ ngắn "Đang hoàn tất đăng xuất…" (04 Bản 3 §6.9) trong lúc xóa dữ
/// liệu trên máy.
class LogoutFinishingApp extends StatelessWidget {
  const LogoutFinishingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) => Scaffold(
          key: const ValueKey('logout-finishing'),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    S.logoutFinishing,
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium,
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

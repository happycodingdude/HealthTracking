import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background_tasks.dart';
import 'router.dart';
import 'sync_coordinator.dart';
import 'theme.dart';

/// Gốc của app: theme sáng/tối theo iPhone (UR-05), tiếng Việt.
class HealthApp extends ConsumerWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => SyncCoordinator(
        child: BackgroundTasks(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme.dart';
import 'background_tasks.dart';
import 'router.dart';
import 'sync_coordinator.dart';

/// Gốc của app: một theme tối đen cam (05 Bản 4 TD4-03), tiếng Việt.
class IronlyApp extends ConsumerWidget {
  const IronlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: IronlyTheme.dark(),
      darkTheme: IronlyTheme.dark(),
      themeMode: ThemeMode.dark,
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

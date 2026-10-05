import 'dart:async';
import 'dart:io';

import 'package:server/server.dart';

Future<void> main() async {
  final logger = Logger.stdout();
  final ServerApp app;
  try {
    final config = ServerConfig.fromEnvironment(ServerConfig.loadEnvironment());
    app = await ServerApp.start(config, logger: logger);
  } catch (e, s) {
    logger.error('server_start_failed', error: e, stack: s);
    exitCode = 1;
    return;
  }

  // Tắt an toàn khi nhận SIGINT/SIGTERM (docker stop gửi SIGTERM).
  final stop = Completer<void>();
  final subs = [
    for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm])
      signal.watch().listen((_) {
        if (!stop.isCompleted) stop.complete();
      }),
  ];
  await stop.future;
  await app.stop();
  for (final s in subs) {
    await s.cancel();
  }
  exit(0);
}

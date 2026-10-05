import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/env.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/auth/auth_interceptor.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';

import 'fake_server.dart';

/// Phiên thử đã đăng nhập.
const signedInSession = StoredSession(
  userId: 'u1',
  phone: '0912345678',
  refreshToken: 'R1',
);

/// Override chung cho test dựng cả app: không chạm Keychain, mạng thật hay file.
List<Override> appOverrides({
  StoredSession? session = signedInSession,
  FakeServer? server,
  AppDatabase? db,
  String flavor = 'prod',
}) {
  final store = MemorySessionStore(session);
  final database = db ?? AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final fake = server ?? FakeServer();
  return [
    envProvider.overrideWithValue(
      AppEnv(flavor: flavor, apiBaseUrl: 'http://server.test'),
    ),
    sessionStoreProvider.overrideWithValue(store),
    initialSessionProvider.overrideWithValue(session),
    databaseProvider.overrideWithValue(database),
    apiClientProvider.overrideWith((ref) {
      final api = fake.client();
      api.dio.interceptors.add(
        AuthInterceptor(api.dio, ref.watch(tokenManagerProvider)),
      );
      return api;
    }),
  ];
}

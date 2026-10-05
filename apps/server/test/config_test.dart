import 'package:server/server.dart';
import 'package:test/test.dart';

const secret = '***REMOVED***';

void main() {
  test('đọc cấu hình từ biến môi trường, giá trị mặc định', () {
    final c = ServerConfig.fromEnvironment({
      'DATABASE_URL': 'postgres://x',
      'JWT_SECRET': secret,
    });
    expect(c.databaseUrl, 'postgres://x');
    expect(c.host, '127.0.0.1');
    expect(c.port, 8080);
    expect(c.trustProxy, isFalse);
    expect(c.migrationsDir, 'migrations');

    final d = ServerConfig.fromEnvironment({
      'DATABASE_URL': 'postgres://x',
      'JWT_SECRET': secret,
      'BCRYPT_COST': '4',
      'HOST': '0.0.0.0',
      'PORT': '9000',
      'TRUST_PROXY': 'true',
    });
    expect(d.host, '0.0.0.0');
    expect(d.port, 9000);
    expect(d.trustProxy, isTrue);
    expect(d.bcryptCost, 4);
    expect(c.bcryptCost, 12, reason: 'TD-09');
    expect(c.jwtSecret, secret);
  });

  test(
    'JWT_SECRET thiếu hoặc ngắn hơn 32 ký tự, BCRYPT_COST sai → ConfigException',
    () {
      expect(
        () => ServerConfig.fromEnvironment({'DATABASE_URL': 'x'}),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => ServerConfig.fromEnvironment({
          'DATABASE_URL': 'x',
          'JWT_SECRET': '***REMOVED***',
        }),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => ServerConfig.fromEnvironment({
          'DATABASE_URL': 'x',
          'JWT_SECRET': secret,
          'BCRYPT_COST': '2',
        }),
        throwsA(isA<ConfigException>()),
      );
    },
  );

  test('thiếu DATABASE_URL hoặc PORT sai → ConfigException', () {
    expect(
      () => ServerConfig.fromEnvironment({}),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => ServerConfig.fromEnvironment({
        'DATABASE_URL': 'x',
        'JWT_SECRET': secret,
        'PORT': 'abc',
      }),
      throwsA(isA<ConfigException>()),
    );
  });

  test('parseDotEnv: bỏ comment, dòng trống, dấu nháy', () {
    expect(
      ServerConfig.parseDotEnv('# c\nA=1\n\nB="two words"\nC=\'x\'\nBAD\n'),
      {'A': '1', 'B': 'two words', 'C': 'x'},
    );
  });
}

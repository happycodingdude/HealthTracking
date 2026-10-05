import 'package:server/server.dart';
import 'package:test/test.dart';

void main() {
  test('đọc cấu hình từ biến môi trường, giá trị mặc định', () {
    final c = ServerConfig.fromEnvironment({'DATABASE_URL': 'postgres://x'});
    expect(c.databaseUrl, 'postgres://x');
    expect(c.host, '127.0.0.1');
    expect(c.port, 8080);
    expect(c.trustProxy, isFalse);
    expect(c.migrationsDir, 'migrations');

    final d = ServerConfig.fromEnvironment({
      'DATABASE_URL': 'postgres://x',
      'HOST': '0.0.0.0',
      'PORT': '9000',
      'TRUST_PROXY': 'true',
    });
    expect(d.host, '0.0.0.0');
    expect(d.port, 9000);
    expect(d.trustProxy, isTrue);
  });

  test('thiếu DATABASE_URL hoặc PORT sai → ConfigException', () {
    expect(
      () => ServerConfig.fromEnvironment({}),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => ServerConfig.fromEnvironment({'DATABASE_URL': 'x', 'PORT': 'abc'}),
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

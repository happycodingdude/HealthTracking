/// Tiện ích chỉ dùng cho test (server và test E2E của app): database tạm,
/// logger ghi lại; mật khẩu, token, khóa ngẫu nhiên (từ package:domain/testing.dart).
library;

export 'package:domain/testing.dart' show randomTestPassword, randomTestSecret;

export 'testing/library_fixtures.dart';
export 'testing/test_database.dart';
export 'testing/v2_data_set.dart';

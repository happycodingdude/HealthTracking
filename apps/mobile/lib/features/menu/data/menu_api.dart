import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/api/api_client.dart';

/// Gọi `/v1/ai/menus` (05 §6.8.2). Tạo thực đơn cần mạng (F08-E1).
abstract interface class MenuApi {
  Future<GenerateMenuResponse> generate(GenerateMenuRequest request);
  Future<MenuStatusResponse> status(LocalDate date);
}

final class HttpMenuApi implements MenuApi {
  HttpMenuApi(this._api);

  final ApiClient _api;

  /// Server chờ nhà cung cấp tối đa 60 giây, thử lại 1 lần (05 §6.9.1).
  static const generateTimeout = Duration(seconds: 150);

  @override
  Future<GenerateMenuResponse> generate(GenerateMenuRequest request) async =>
      GenerateMenuResponse.fromJson(
        await _api.postJson(
          '/v1/ai/menus',
          request.toJson(),
          receiveTimeout: generateTimeout,
        ),
      );

  @override
  Future<MenuStatusResponse> status(LocalDate date) async =>
      MenuStatusResponse.fromJson(
        await _api.getJson('/v1/ai/menus/${date.toKey()}'),
      );
}

final menuApiProvider = Provider<MenuApi>(
  (ref) => HttpMenuApi(ref.watch(apiClientProvider)),
);

import 'package:api_contract/api_contract.dart';

import '../api/api_client.dart';

/// Gọi `/v1/sync/*` (05 §6.6.2, §6.6.3).
abstract interface class SyncApi {
  Future<PushResponse> push(PushRequest request);
  Future<PullResponse> pull({required int cursor, int limit});
}

final class HttpSyncApi implements SyncApi {
  HttpSyncApi(this._api);

  final ApiClient _api;

  @override
  Future<PushResponse> push(PushRequest request) async => PushResponse.fromJson(
    await _api.postJson('/v1/sync/push', request.toJson()),
  );

  @override
  Future<PullResponse> pull({
    required int cursor,
    int limit = PullResponse.maxLimit,
  }) async => PullResponse.fromJson(
    await _api.getJson(
      '/v1/sync/pull',
      query: {'cursor': cursor, 'limit': limit},
    ),
  );
}

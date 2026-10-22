import 'apns.dart';

/// APNs giả (06 Bản 3 IA3-10): ghi lại push đã gửi; [respond] quyết định kết
/// quả (mặc định 200).
final class FakeApns implements Apns {
  FakeApns({ApnsResult Function(ApnsPush push)? respond})
    : respond = respond ?? ((_) => ApnsResult.ok);

  ApnsResult Function(ApnsPush push) respond;
  final sent = <ApnsPush>[];

  /// Các push có `aps.event` = [event].
  List<ApnsPush> events(String event) => [
    for (final p in sent)
      if ((p.payload['aps']! as Map)['event'] == event) p,
  ];

  @override
  Future<ApnsResult> send(ApnsPush push) async {
    sent.add(push);
    return respond(push);
  }

  @override
  Future<void> close() async {}
}

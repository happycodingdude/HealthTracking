import 'codecs.dart';
import 'error_code.dart';
import 'json_reader.dart';
import 'menu_dtos.dart';

/// Thao tác của một mutation (05 §6.6.2).
enum SyncOp {
  /// Tạo hoặc thay toàn bộ bản ghi.
  upsert,

  /// Chỉ tạo nếu chưa có (lịch tháng): hai máy cùng tạo không ghi đè nhau.
  ensure,

  /// Xóa mềm (tombstone) để máy khác nhận được việc xóa.
  delete;

  String get wire => name;

  static SyncOp fromWire(String wire, {String field = 'op'}) =>
      values.firstWhere(
        (o) => o.name == wire,
        orElse: () => throw ContractFormatException(field),
      );
}

/// Một thay đổi gửi lên server.
final class SyncMutation {
  const SyncMutation({
    required this.mutationId,
    required this.entity,
    required this.key,
    required this.op,
    required this.clientUpdatedAt,
    this.data,
  });

  factory SyncMutation.fromJson(Object? json, {String path = ''}) {
    final r = JsonReader(json, path: path);
    return SyncMutation(
      mutationId: r.string('mutationId'),
      entity: r.string('entity'),
      key: r.string('key'),
      op: SyncOp.fromWire(
        r.string('op'),
        field: path.isEmpty ? 'op' : '$path.op',
      ),
      clientUpdatedAt: r.decoded('clientUpdatedAt', InstantCodec.decode),
      data: r.optObject('data')?.raw,
    );
  }

  final String mutationId;
  final String entity;
  final String key;
  final SyncOp op;

  /// Thời điểm thao tác theo giờ trên máy. Dùng cho last-write-wins (TA-11) và
  /// quy tắc phụ thuộc thời gian (05 §6.6.2).
  final DateTime clientUpdatedAt;

  /// Nội dung bản ghi (camelCase). null với `delete`.
  final Map<String, Object?>? data;

  Map<String, Object?> toJson() => {
    'mutationId': mutationId,
    'entity': entity,
    'key': key,
    'op': op.wire,
    'clientUpdatedAt': InstantCodec.encode(clientUpdatedAt),
    'data': ?data,
  };
}

/// `POST /v1/sync/push`.
final class PushRequest {
  const PushRequest(this.mutations);

  factory PushRequest.fromJson(Object? json) {
    final list = JsonReader(json).list('mutations');
    if (list.length > maxMutations) {
      throw const ContractFormatException('mutations', 'quá nhiều');
    }
    return PushRequest([
      for (var i = 0; i < list.length; i++)
        SyncMutation.fromJson(list[i], path: 'mutations[$i]'),
    ]);
  }

  /// Số mutation tối đa mỗi lần gửi.
  static const maxMutations = 500;

  final List<SyncMutation> mutations;

  Map<String, Object?> toJson() => {
    'mutations': [for (final m in mutations) m.toJson()],
  };
}

/// Một bản ghi trên server, trả trong pull và trong kết quả push.
final class SyncChange {
  const SyncChange({
    required this.entity,
    required this.key,
    required this.deleted,
    required this.serverVersion,
    this.data,
  });

  factory SyncChange.fromJson(Object? json) {
    final r = JsonReader(json);
    return SyncChange(
      entity: r.string('entity'),
      key: r.string('key'),
      deleted: r.boolean('deleted'),
      serverVersion: r.integer('serverVersion'),
      data: r.optObject('data')?.raw,
    );
  }

  final String entity;
  final String key;
  final bool deleted;
  final int serverVersion;
  final Map<String, Object?>? data;

  Map<String, Object?> toJson() => {
    'entity': entity,
    'key': key,
    'deleted': deleted,
    'serverVersion': serverVersion,
    'data': ?data,
  };
}

enum PushStatus {
  applied('applied'),

  /// Bản trên server mới hơn (TA-11): giữ bản server.
  ignoredStale('ignored_stale'),

  /// Không hợp lệ (chỉ xảy ra khi app có lỗi, TA-12).
  rejected('rejected');

  const PushStatus(this.wire);

  final String wire;

  static PushStatus fromWire(String wire) => values.firstWhere(
    (s) => s.wire == wire,
    orElse: () => throw const ContractFormatException('status'),
  );
}

/// Kết quả của một mutation (05 §6.6.2 bước 5).
final class PushResult {
  const PushResult({
    required this.mutationId,
    required this.status,
    this.code,
    this.field,
    this.current,
  });

  factory PushResult.fromJson(Object? json) {
    final r = JsonReader(json);
    final code = r.optString('code');
    final current = r.optObject('current');
    return PushResult(
      mutationId: r.string('mutationId'),
      status: PushStatus.fromWire(r.string('status')),
      code: code == null ? null : ErrorCode.fromWire(code),
      field: r.optString('field'),
      current: current == null ? null : SyncChange.fromJson(current.raw),
    );
  }

  final String mutationId;
  final PushStatus status;

  /// Mã lỗi khi `rejected`.
  final ErrorCode? code;
  final String? field;

  /// Bản ghi hiện tại trên server khi không `applied`; app thay bản trên máy bằng
  /// bản này (TA-12). null = server không có bản ghi đó.
  final SyncChange? current;

  PushResult withCurrent(SyncChange? value) => PushResult(
    mutationId: mutationId,
    status: status,
    code: code,
    field: field,
    current: value,
  );

  Map<String, Object?> toJson() => {
    'mutationId': mutationId,
    'status': status.wire,
    'code': ?code?.wire,
    'field': ?field,
    'current': ?current?.toJson(),
  };
}

final class PushResponse {
  const PushResponse(this.results);

  factory PushResponse.fromJson(Object? json) => PushResponse([
    for (final r in JsonReader(json).list('results')) PushResult.fromJson(r),
  ]);

  final List<PushResult> results;

  Map<String, Object?> toJson() => {
    'results': [for (final r in results) r.toJson()],
  };
}

/// Thông tin kèm theo pull. `aiBudget` thêm ở VS-12 (ED-04).
final class SyncMeta {
  const SyncMeta({required this.serverTime, this.aiBudget});

  factory SyncMeta.fromJson(Object? json) {
    final r = JsonReader(json);
    return SyncMeta(
      serverTime: r.decoded('serverTime', InstantCodec.decode),
      aiBudget: r.optObject('aiBudget')?.raw,
    );
  }

  final DateTime serverTime;
  final Map<String, Object?>? aiBudget;

  /// [aiBudget] đã giải mã; null khi server không gửi.
  AiBudgetMeta? get budget =>
      aiBudget == null ? null : AiBudgetMeta.fromJson(aiBudget);

  Map<String, Object?> toJson() => {
    'serverTime': InstantCodec.encode(serverTime),
    'aiBudget': ?aiBudget,
  };
}

/// `GET /v1/sync/pull?cursor={n}&limit=500` (05 §6.6.3).
final class PullResponse {
  const PullResponse({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    required this.remaining,
    required this.meta,
  });

  factory PullResponse.fromJson(Object? json) {
    final r = JsonReader(json);
    return PullResponse(
      changes: [for (final c in r.list('changes')) SyncChange.fromJson(c)],
      nextCursor: r.integer('nextCursor'),
      hasMore: r.boolean('hasMore'),
      remaining: r.integer('remaining'),
      meta: SyncMeta.fromJson(r.object('meta').raw),
    );
  }

  static const maxLimit = 500;

  final List<SyncChange> changes;
  final int nextCursor;
  final bool hasMore;

  /// Số thay đổi còn lại sau trang này (thanh tiến trình S-07).
  final int remaining;
  final SyncMeta meta;

  Map<String, Object?> toJson() => {
    'changes': [for (final c in changes) c.toJson()],
    'nextCursor': nextCursor,
    'hasMore': hasMore,
    'remaining': remaining,
    'meta': meta.toJson(),
  };
}

import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';

/// Ngữ cảnh khi kiểm tra một mutation.
final class SyncContext {
  const SyncContext({
    required this.userId,
    required this.serverNow,
    this.appVersion,
  });

  final String userId;

  /// Header `X-App-Version` của request; null = app Bản 1 (05 Bản 2 TD2-15).
  final AppVersion? appVersion;

  /// Giờ server (UTC). Quy tắc phụ thuộc thời gian dùng `clientUpdatedAt` của
  /// mutation (05 §6.6.2), giờ server chỉ để chặn thời điểm tương lai.
  final DateTime serverNow;
}

/// Handler từ chối mutation ở bước cần đọc database (ví dụ ngày thuộc tháng
/// chưa có `month_plan`). Ném trong [SyncEntityHandler.apply]: phần đã ghi của
/// mutation được hoàn tác, kết quả là `rejected` kèm [field].
final class SyncRejection implements Exception {
  const SyncRejection(this.field, {this.code = ErrorCode.validationFailed});

  final String field;

  /// Mã lỗi trả về app, ví dụ `session_locked` (05 Bản 2 §6.6.3).
  final ErrorCode code;

  @override
  String toString() => 'SyncRejection($field, ${code.wire})';
}

/// Trạng thái dòng hiện có, đọc khi đã khóa (`FOR UPDATE`).
final class RowState {
  const RowState({required this.clientUpdatedAt, required this.deleted});

  final DateTime clientUpdatedAt;
  final bool deleted;
}

/// Xử lý một entity đồng bộ (06 VS02-T03): kiểm tra → ghi → xuất.
///
/// Mọi truy vấn đều có điều kiện `user_id` lấy từ access token (TAC-07).
abstract interface class SyncEntityHandler {
  String get entity;

  /// Thao tác app được phép dùng với entity này (06 §6.5.1).
  Set<SyncOp> get ops;

  /// Kiểm tra key, cấu trúc `data` và business rules bằng `packages/domain`.
  /// null = hợp lệ.
  ApiError? validate(SyncMutation mutation, SyncContext ctx);

  /// Khóa và đọc dòng của [key]. null = chưa có.
  Future<RowState?> lock(Session s, String userId, String key);

  /// Ghi `upsert`/`ensure`, hoặc tombstone với `delete`, kèm [serverVersion].
  /// Quy tắc cần đọc database thì ném [SyncRejection].
  Future<void> apply(
    Session s,
    SyncContext ctx,
    SyncMutation mutation,
    int serverVersion,
  );

  /// Bản ghi hiện tại trên server (kể cả tombstone). null = chưa có.
  Future<SyncChange?> read(Session s, String userId, String key);

  /// SELECT `entity, key, deleted, server_version, data` các dòng của
  /// `@user` có `server_version > @cursor`. Được ghép bằng `UNION ALL` khi pull.
  String get pullSql;
}

/// Entity có câu pull khác nhau theo phiên bản app (05 Bản 3 TD3-21): app cũ
/// nhận dữ liệu dạng cũ. Dòng app cũ không đọc được có `entity` =
/// [SyncService.skippedEntity]: không gửi, nhưng cursor vẫn tiến qua.
abstract interface class VersionedPull {
  /// Câu pull cho request có header `X-App-Version` = [appVersion] (null =
  /// không có header). Cùng cột và tham số với [SyncEntityHandler.pullSql].
  String pullSqlFor(AppVersion? appVersion);
}

/// Đọc một dòng `entity, key, deleted, server_version, data` thành [SyncChange].
SyncChange changeFromRow(ResultRow row) {
  final m = row.toColumnMap();
  final data = m['data'];
  return SyncChange(
    entity: m['entity']! as String,
    key: m['key']! as String,
    deleted: m['deleted']! as bool,
    serverVersion: m['server_version']! as int,
    data: m['deleted'] == true || data == null
        ? null
        : (data as Map).cast<String, Object?>(),
  );
}

/// Entity chỉ pull do server ghi (05 §6.6.1): app gửi lên → `rejected` (op).
abstract base class PullOnlyHandler implements SyncEntityHandler {
  const PullOnlyHandler();

  @override
  Set<SyncOp> get ops => const {};

  @override
  ApiError? validate(SyncMutation mutation, SyncContext ctx) =>
      const ApiError(ErrorCode.validationFailed, field: 'op');

  @override
  Future<RowState?> lock(Session s, String userId, String key) =>
      throw UnsupportedError('$entity chỉ pull');

  @override
  Future<void> apply(
    Session s,
    SyncContext ctx,
    SyncMutation mutation,
    int serverVersion,
  ) => throw UnsupportedError('$entity chỉ pull');

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE key = @key'),
      parameters: {'user': userId, 'cursor': 0, 'key': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }
}

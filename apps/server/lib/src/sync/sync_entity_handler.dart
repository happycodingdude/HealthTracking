import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';

/// Ngữ cảnh khi kiểm tra một mutation.
final class SyncContext {
  const SyncContext({required this.userId, required this.serverNow});

  final String userId;

  /// Giờ server (UTC). Quy tắc phụ thuộc thời gian dùng `clientUpdatedAt` của
  /// mutation (05 §6.6.2), giờ server chỉ để chặn thời điểm tương lai.
  final DateTime serverNow;
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
  Future<void> apply(
    Session s,
    String userId,
    SyncMutation mutation,
    int serverVersion,
  );

  /// Bản ghi hiện tại trên server (kể cả tombstone). null = chưa có.
  Future<SyncChange?> read(Session s, String userId, String key);

  /// SELECT `entity, key, deleted, server_version, data` các dòng của
  /// `@user` có `server_version > @cursor`. Được ghép bằng `UNION ALL` khi pull.
  String get pullSql;
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

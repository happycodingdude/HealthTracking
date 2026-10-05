import '../db/app_database.dart';

/// Trạng thái đồng bộ hiển thị cho Bạn (05 §6.5, F09-E1).
final class SyncStatus {
  const SyncStatus({required this.pending, this.lastSyncedAt});

  /// Số thay đổi còn trong outbox.
  final int pending;

  /// Lần push + pull thành công gần nhất.
  final DateTime? lastSyncedAt;

  /// "Chưa đồng bộ" = outbox còn bản ghi.
  bool get hasPending => pending > 0;
}

/// Theo dõi outbox và `sync_state` trong một truy vấn, cập nhật ngay khi ghi.
Stream<SyncStatus> watchSyncStatus(AppDatabase db) {
  return db
      .customSelect(
        'SELECT (SELECT count(*) FROM outbox) AS pending, last_synced_at FROM sync_state WHERE id = 1',
        readsFrom: {db.outbox, db.syncState},
      )
      .watchSingle()
      .map(
        (row) => SyncStatus(
          pending: row.read<int>('pending'),
          lastSyncedAt: row.readNullable<DateTime>('last_synced_at'),
        ),
      );
}

import 'time/local_date.dart';

/// Khóa trong ngày (05 Bản 5 TD5-08, FC5-01): mọi thứ của một ngày — trạng
/// thái buổi, nhóm cơ sửa riêng, buổi tập thêm, bài trong buổi, mức tạ, ghi
/// chú, mức thoải mái — chỉ sửa được đến **hết ngày** (00:00 ngày hôm sau
/// theo giờ iPhone); sau đó khóa vĩnh viễn. Thay cửa sổ sửa 7 ngày của Bản 1
/// và "Đã tập là chốt cuối" của Bản 2 (CR5-02, CR5-06, CR5-07).
///
/// [now] là giờ trên iPhone (giờ đồng hồ, không múi giờ). App dùng giờ máy;
/// server quy `clientUpdatedAt` về múi giờ trong hồ sơ trước khi gọi (AP-10,
/// AP-19). App và server cùng dùng một hàm (06 Bản 5 ED5-02).
abstract final class DayLock {
  /// Ngày [date] còn sửa được lúc [now]: `now < 00:00 ngày date + 1`.
  static bool isOpen(LocalDate date, DateTime now) => now.isBefore(endOf(date));

  /// 00:00 ngày sau [date] (giờ trên iPhone): mốc khóa (FC5-01).
  static DateTime endOf(LocalDate date) => date.addDays(1).startOfDay;
}

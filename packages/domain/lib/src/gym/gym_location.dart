import '../schedule/month_plan.dart';
import '../time/local_date.dart';

/// Vị trí phòng gym (entity `gym_location`, key `me`, 05 Bản 5 TD5-06): một
/// điểm Bạn lưu bằng vị trí hiện tại (F32-R1, R2), bật / tắt thẻ theo vị trí
/// (F32-R4). Không có địa chỉ, không lịch sử (C5-05, AP-18).
final class GymLocation {
  const GymLocation({
    required this.lat,
    required this.lng,
    required this.savedAt,
    this.enabled = true,
  });

  /// Vĩ độ, kinh độ; lưu 6 chữ số thập phân (≈ 10 cm, TA5-03).
  final double lat;
  final double lng;
  final DateTime savedAt;
  final bool enabled;

  /// Key duy nhất của entity.
  static const key = 'me';

  static bool validLat(double v) => v.isFinite && v >= -90 && v <= 90;

  static bool validLng(double v) => v.isFinite && v >= -180 && v <= 180;

  /// Trường sai (05 Bản 5 §6.6.2); null = hợp lệ.
  String? get invalidField {
    if (!validLat(lat)) return 'lat';
    if (!validLng(lng)) return 'lng';
    return null;
  }

  GymLocation withEnabled(bool value) =>
      GymLocation(lat: lat, lng: lng, savedAt: savedAt, enabled: value);

  @override
  bool operator ==(Object other) =>
      other is GymLocation &&
      other.lat == lat &&
      other.lng == lng &&
      other.savedAt.isAtSameMomentAs(savedAt) &&
      other.enabled == enabled;

  @override
  int get hashCode =>
      Object.hash(lat, lng, savedAt.millisecondsSinceEpoch, enabled);

  /// Không in tọa độ (TAC5-10).
  @override
  String toString() => 'GymLocation(${enabled ? 'bật' : 'tắt'})';
}

/// Những gì app biết lúc iPhone báo "vào vùng phòng gym" (05 Bản 5 §6.4.2
/// `GymArrival`, FC5-10). Không có tọa độ (AP-18).
final class GymArrivalAppState {
  const GymArrivalAppState({
    required this.today,
    required this.location,
    required this.alreadyCalled,
    this.paused = false,
    this.day,
  });

  /// Hôm nay theo giờ trên máy lúc xử lý sự kiện.
  final LocalDate today;

  /// Vị trí đã lưu trên máy (null: chưa lưu / đã xóa / đã đăng xuất).
  final GymLocation? location;

  /// Ngày đã báo "tới phòng gym" (bảng chỉ trên máy `gym_arrivals`).
  final bool alreadyCalled;

  /// Hôm nay nằm trong khoảng tạm dừng (F31-R4, A5-07).
  final bool paused;

  /// Bản ghi hôm nay trong lịch tháng (null: chưa có lịch / chưa tạo tháng).
  final PlanDay? day;
}

/// Quy tắc phía app khi vào vùng phòng gym (05 Bản 5 §6.4.2, FC5-10; 06 Bản 5
/// VS58-T01). App chỉ lọc để không gọi thừa; bật thẻ hay không do server
/// quyết (TD5-02).
abstract final class GymArrivalRules {
  /// Báo "tới phòng gym" một lần mỗi ngày: công tắc bật, sự kiện của hôm nay,
  /// chưa báo hôm nay, không tạm dừng, buổi hôm nay chưa đánh dấu, chưa có buổi
  /// tập thêm (05 Bản 5 §6.4.2 `GymArrival`).
  static bool shouldCall(LocalDate date, GymArrivalAppState s) {
    final location = s.location;
    if (location == null || !location.enabled) return false;
    if (date != s.today || s.alreadyCalled || s.paused) return false;
    final day = s.day;
    if (day == null) return true;
    if (day.mark != null) return false;
    return !(day.extraMuscles?.isNotEmpty ?? false);
  }
}

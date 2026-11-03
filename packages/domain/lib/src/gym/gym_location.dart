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

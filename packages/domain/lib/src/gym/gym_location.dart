import '../day_lock.dart';
import '../schedule/month_plan.dart';
import '../session/session.dart';
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

  /// Tới phòng gym lúc [at] (giờ trên máy) mở buổi sớm (FD5-01 = A, TD5-07):
  /// ngày có buổi theo lịch, chưa đánh dấu, trước giờ tập, cùng ngày, còn trong
  /// ngày. Khi đó `openedAt` = [at] (mốc sớm hơn thắng, TA5-02).
  static bool opensEarly(PlanDay? day, DateTime at) {
    if (day == null || !day.isWorkout || day.time == null) return false;
    if (day.mark != null || LocalDate.fromDateTime(at) != day.date) {
      return false;
    }
    if (!DayLock.isOpen(day.date, at)) return false;
    return at.isBefore(SessionRules.startsAt(day));
  }

  /// Server quyết khi nhận `POST /v1/me/gym-arrival` (05 Bản 5 TD5-14,
  /// §6.9.4, FC5-10): bật thẻ buổi tập ([GymArrivalOutcome.session]), thẻ ngày
  /// nghỉ ([GymArrivalOutcome.extra]) hay không bật, kèm lý do để log; và có
  /// mở buổi sớm không ([GymArrivalDecision.openEarly], mọi nhánh).
  static GymArrivalDecision decide(GymArrivalServerState s) {
    final today = LocalDate.fromDateTime(s.localNow);
    if (s.date != today) {
      return const GymArrivalDecision.none(GymArrivalReason.notToday);
    }
    final day = s.day;
    final early = opensEarly(day, s.localNow);
    GymArrivalDecision none(GymArrivalReason r) =>
        GymArrivalDecision.none(r, openEarly: early);
    if (s.paused) return none(GymArrivalReason.paused);
    if (!s.hasSchedule) return none(GymArrivalReason.noSchedule);
    if (!s.hasToken) return none(GymArrivalReason.noToken);
    // Chủ nhật không có buổi tập thêm (F05-R7, F25-E62).
    if (today.isSunday) return none(GymArrivalReason.sunday);
    if (day == null) return none(GymArrivalReason.noDay);
    if (day.isWorkout) {
      if (day.time == null) return none(GymArrivalReason.noDay);
      if (day.mark != null) return none(GymArrivalReason.marked);
      // Thẻ hôm nay đã bật (theo giờ hoặc lần tới gym trước): không hiện thêm.
      if (s.startedToday) return none(GymArrivalReason.alreadyStarted);
      return GymArrivalDecision(GymArrivalOutcome.session, openEarly: early);
    }
    if (day.extraMuscles?.isNotEmpty ?? false) {
      return none(GymArrivalReason.extraLogged);
    }
    if (s.startedToday) return none(GymArrivalReason.alreadyStarted);
    return const GymArrivalDecision(GymArrivalOutcome.extra);
  }
}

/// Thẻ server bật khi Bạn tới phòng gym (05 Bản 5 TD5-14, TD5-15).
enum GymArrivalOutcome {
  /// Thẻ buổi tập (ngày có buổi theo lịch), `trigger = location`.
  session,

  /// Thẻ ngày nghỉ rút gọn mời bắt đầu Buổi tập thêm (`kind = extra`, F25-R63).
  extra,

  /// Không bật.
  none,
}

/// Vì sao không bật thẻ (chỉ để log, 05 Bản 5 §6.14; app không biết, TD5-14).
enum GymArrivalReason {
  /// `date` gửi lên không phải hôm nay theo múi giờ của tài khoản.
  notToday,

  /// Trong khoảng tạm dừng (F31-R4, A5-07).
  paused,

  /// Chưa có lịch tuần.
  noSchedule,

  /// Không có token thẻ (chưa cấp quyền, đã đăng xuất).
  noToken,

  /// Chủ nhật (F05-R7).
  sunday,

  /// Chưa có bản ghi ngày hôm nay.
  noDay,

  /// Buổi hôm nay đã "Đã tập" / "Không tập".
  marked,

  /// Thẻ hôm nay đã bật (theo giờ hoặc theo vị trí, A5-09).
  alreadyStarted,

  /// Ngày nghỉ đã có Buổi tập thêm.
  extraLogged,
}

/// Kết quả [GymArrivalRules.decide].
final class GymArrivalDecision {
  const GymArrivalDecision(this.outcome, {this.openEarly = false})
    : reason = null;

  const GymArrivalDecision.none(
    GymArrivalReason this.reason, {
    this.openEarly = false,
  }) : outcome = GymArrivalOutcome.none;

  final GymArrivalOutcome outcome;
  final GymArrivalReason? reason;

  /// Ghi `days.opened_at` = lúc này (mốc sớm hơn thắng, TD5-07).
  final bool openEarly;

  @override
  bool operator ==(Object other) =>
      other is GymArrivalDecision &&
      other.outcome == outcome &&
      other.reason == reason &&
      other.openEarly == openEarly;

  @override
  int get hashCode => Object.hash(outcome, reason, openEarly);

  @override
  String toString() =>
      'GymArrivalDecision(${outcome.name}${reason == null ? '' : ', ${reason!.name}'}'
      '${openEarly ? ', mở sớm' : ''})';
}

/// Những gì server biết lúc nhận `gym-arrival` (05 Bản 5 §6.9.4). Giờ theo
/// múi giờ của tài khoản; không tọa độ (AP-18).
final class GymArrivalServerState {
  const GymArrivalServerState({
    required this.date,
    required this.localNow,
    required this.hasToken,
    required this.hasSchedule,
    this.paused = false,
    this.day,
    this.startedToday = false,
  });

  /// Ngày app gửi lên.
  final LocalDate date;

  /// Giờ hiện tại theo múi giờ của tài khoản (giờ đồng hồ).
  final DateTime localNow;

  /// Có token push-to-start của thẻ.
  final bool hasToken;
  final bool hasSchedule;

  /// Hôm nay trong khoảng tạm dừng.
  final bool paused;

  /// Bản ghi ngày hôm nay.
  final PlanDay? day;

  /// Đã có dòng `live_activity_sessions` hôm nay (bất kỳ nguồn bật nào).
  final bool startedToday;
}

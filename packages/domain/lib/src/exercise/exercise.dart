import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import 'muscle_region.dart';

/// Lý do video không khả dụng (05 Bản 2 §6.10.3).
enum VideoUnavailableReason {
  removed,
  private,
  notEmbeddable('not_embeddable'),
  tooLong('too_long');

  const VideoUnavailableReason([this._wire]);

  final String? _wire;

  String get wire => _wire ?? name;

  static VideoUnavailableReason? tryParse(String wire) {
    for (final r in values) {
      if (r.wire == wire) return r;
    }
    return null;
  }
}

/// Một bài trong thư viện (03 Bản 3 §6.1, §6.4, entity `exercise`). Thuộc đúng
/// 1 nhóm cơ và 1 vùng cơ. Không có loại dụng cụ và không có đơn vị mức tạ
/// (TD3-20, BR3-18). Bài gỡ sau ra mắt vẫn còn với [active] = false (F18-R46).
final class Exercise {
  const Exercise({
    required this.id,
    required this.region,
    required this.nameVi,
    this.nameEn,
    required this.youtubeVideoId,
    required this.videoChannel,
    this.videoDurationS,
    this.videoAvailable = true,
    this.videoUnavailableReason,
    this.videoCheckedAt,
    required this.guideSteps,
    required this.guideSafety,
    required this.approvedAt,
    this.sortInGroup = 0,
    this.sortOrder = 0,
    this.active = true,
  });

  /// Slug ổn định; thay video không đổi [id] (FA2-14).
  final String id;
  final MuscleRegion region;
  final String nameVi;
  final String? nameEn;
  final String youtubeVideoId;
  final String videoChannel;

  /// Độ dài video (giây), ≤ 60 (LIB-AC2). null khi chưa đo.
  final int? videoDurationS;
  final bool videoAvailable;
  final VideoUnavailableReason? videoUnavailableReason;
  final DateTime? videoCheckedAt;

  /// "Cách tập" 3–6 bước, "Lưu ý an toàn" 2–4 ý (LIB-R4).
  final List<String> guideSteps;
  final List<String> guideSafety;

  /// Ngày Bạn duyệt (LIB-AC1).
  final LocalDate approvedAt;

  /// Vị trí trong nhóm (1, 2, 3…), theo thứ tự trong file thư viện (PD3-02,
  /// LIB-R23).
  final int sortInGroup;

  /// Thứ tự toàn cục F18-R43, tính khi nạp (TD3-07).
  final int sortOrder;
  final bool active;

  MuscleGroup get group => region.group;

  /// FR2-12, BR3-11: bài bụng không ghi mức tạ, không có biểu đồ; bài chân
  /// ghi như mọi nhóm khác.
  bool get logsWeight => group != MuscleGroup.abs;

  Exercise copyWith({
    int? sortInGroup,
    int? sortOrder,
    bool? active,
    int? videoDurationS,
    bool? videoAvailable,
    VideoUnavailableReason? videoUnavailableReason,
    DateTime? videoCheckedAt,
  }) => Exercise(
    id: id,
    region: region,
    nameVi: nameVi,
    nameEn: nameEn,
    youtubeVideoId: youtubeVideoId,
    videoChannel: videoChannel,
    videoDurationS: videoDurationS ?? this.videoDurationS,
    videoAvailable: videoAvailable ?? this.videoAvailable,
    videoUnavailableReason:
        videoUnavailableReason ?? this.videoUnavailableReason,
    videoCheckedAt: videoCheckedAt ?? this.videoCheckedAt,
    guideSteps: guideSteps,
    guideSafety: guideSafety,
    approvedAt: approvedAt,
    sortInGroup: sortInGroup ?? this.sortInGroup,
    sortOrder: sortOrder ?? this.sortOrder,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.region == region &&
      other.nameVi == nameVi &&
      other.nameEn == nameEn &&
      other.youtubeVideoId == youtubeVideoId &&
      other.videoChannel == videoChannel &&
      other.videoDurationS == videoDurationS &&
      other.videoAvailable == videoAvailable &&
      other.videoUnavailableReason == videoUnavailableReason &&
      _sameInstant(other.videoCheckedAt, videoCheckedAt) &&
      _same(other.guideSteps, guideSteps) &&
      _same(other.guideSafety, guideSafety) &&
      other.approvedAt == approvedAt &&
      other.sortInGroup == sortInGroup &&
      other.sortOrder == sortOrder &&
      other.active == active;

  @override
  int get hashCode => Object.hash(
    id,
    region,
    nameVi,
    youtubeVideoId,
    videoDurationS,
    videoAvailable,
    sortInGroup,
    sortOrder,
    active,
  );

  @override
  String toString() => 'Exercise($id)';
}

bool _sameInstant(DateTime? a, DateTime? b) =>
    a == null || b == null ? a == b : a.isAtSameMomentAs(b);

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Một lỗi của thư viện: bài nào (null = cả thư viện), trường hay quy tắc nào.
typedef LibraryIssue = ({String? exerciseId, String rule});

/// Quy tắc thư viện bài tập (03 Bản 3 §6.4, §6.15; 05 Bản 3 §6.10.2). App
/// và server cùng dùng (ED2-09).
abstract final class LibraryRules {
  /// Thứ tự nhóm cơ của thư viện (F18-R43).
  static const groupOrder = MuscleGroup.libraryOrder;

  /// LIB-R4.
  static const minSteps = 3;
  static const maxSteps = 6;
  static const minSafety = 2;
  static const maxSafety = 4;

  /// LIB-R2, LIB-AC2.
  static const maxVideoSeconds = 60;

  static final _slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
  static final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// LIB-R4, LIB-AC3: hướng dẫn không nêu con số mức tạ, hiệp, lần.
  static final _numberWithUnit = RegExp(
    r'\d+([.,]\d+)?\s*(kg|hiệp|lần)(?![\p{L}])',
    caseSensitive: false,
    unicode: true,
  );

  /// Bước 1 của `library import` (05 Bản 2 §6.10.2): cấu trúc từng bài. Trả
  /// tên trường sai, rỗng = hợp lệ.
  static List<String> entryErrors(Exercise e) => [
    if (!_slug.hasMatch(e.id)) 'id',
    if (e.nameVi.trim().isEmpty || e.nameVi != e.nameVi.trim()) 'nameVi',
    if (!_youtubeId.hasMatch(e.youtubeVideoId)) 'video.youtubeId',
    if (e.videoChannel.trim().isEmpty) 'video.channel',
    if (e.videoDurationS != null &&
        (e.videoDurationS! < 1 || e.videoDurationS! > maxVideoSeconds))
      'video.durationSeconds',
    ..._guideCounts(e.guideSteps, e.guideSafety),
  ];

  static List<String> _guideCounts(List<String> steps, List<String> safety) => [
    if (steps.length < minSteps ||
        steps.length > maxSteps ||
        steps.any((s) => s.trim().isEmpty))
      'guide.steps',
    if (safety.length < minSafety ||
        safety.length > maxSafety ||
        safety.any((s) => s.trim().isEmpty))
      'guide.safety',
  ];

  /// LIB-R4 cho một hướng dẫn (dùng cả cho bản nháp AI soạn, ED2-12): số
  /// bước, số ý, không có con số đi kèm "kg", "hiệp", "lần".
  static List<String> guideErrors(List<String> steps, List<String> safety) => [
    ..._guideCounts(steps, safety),
    if ([...steps, ...safety].any(_numberWithUnit.hasMatch)) 'guide',
  ];

  /// Cổng phát hành (IR2-06, LIB-AC1 → AC3, `--check-only`): ngoài
  /// [entryErrors], bài phải có độ dài video đã đo ≤ 60 giây và hướng dẫn
  /// không có con số đi kèm "kg", "hiệp", "lần".
  static List<String> releaseErrors(Exercise e) => [
    ...entryErrors(e),
    if (e.videoDurationS == null) 'video.durationSeconds',
    if ([...e.guideSteps, ...e.guideSafety].any(_numberWithUnit.hasMatch))
      'guide',
  ];

  /// Trên tập bài đang có trong thư viện: id và tên tiếng Việt không trùng
  /// (LIB-R1). Bản 3 bỏ quy tắc máy/tạ mỗi vùng (F18-R41, LIB-R25).
  static List<LibraryIssue> coverageErrors(Iterable<Exercise> library) {
    final issues = <LibraryIssue>[];
    final ids = <String>{};
    final names = <String>{};
    for (final e in library) {
      if (!e.active) continue;
      if (!ids.add(e.id)) issues.add((exerciseId: e.id, rule: 'id trùng'));
      if (!names.add(e.nameVi)) {
        issues.add((exerciseId: e.id, rule: 'nameVi trùng'));
      }
    }
    return issues;
  }

  /// TD3-07, F18-R43, PD3-02: nhóm cơ theo [groupOrder], trong nhóm theo thứ
  /// tự trong file. Trả bản sao với `sortInGroup` = vị trí trong nhóm (1, 2,
  /// 3…) và `sortOrder` = (vị trí nhóm + 1) × 100 + `sortInGroup`.
  static List<Exercise> sorted(List<Exercise> library) {
    final out = <Exercise>[];
    for (var g = 0; g < groupOrder.length; g++) {
      var i = 0;
      for (final e in library) {
        if (e.group != groupOrder[g]) continue;
        i++;
        out.add(e.copyWith(sortInGroup: i, sortOrder: (g + 1) * 100 + i));
      }
    }
    return out;
  }
}

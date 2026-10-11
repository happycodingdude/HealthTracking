import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import 'muscle_region.dart';

/// Loại dụng cụ (03 Bản 2 §6.1). Giá trị trong API/PostgreSQL là [wire].
enum Equipment {
  /// Máy, gồm cả máy kéo cáp.
  machine('machine'),

  /// Tạ: tạ đơn, thanh đòn, thanh EZ… không dùng máy.
  freeWeight('free_weight'),

  /// Không dụng cụ — chỉ có ở bụng (BR2-22).
  bodyweight('bodyweight');

  const Equipment(this.wire);

  final String wire;

  static Equipment? tryParse(String wire) {
    for (final e in values) {
      if (e.wire == wire) return e;
    }
    return null;
  }
}

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

/// Một bài trong thư viện (03 Bản 2 §6.10, entity `exercise`). Thuộc đúng 1
/// vùng cơ (FA2-09). Bài rời thư viện vẫn còn với [active] = false (TA2-10).
final class Exercise {
  const Exercise({
    required this.id,
    required this.region,
    required this.equipment,
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
    this.sortOrder = 0,
    this.active = true,
  });

  /// Slug ổn định; thay video không đổi [id] (FA2-14).
  final String id;
  final MuscleRegion region;
  final Equipment equipment;
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

  /// Thứ tự F18-R9, tính khi nạp.
  final int sortOrder;
  final bool active;

  MuscleGroup get group => region.group;

  /// FR2-12: bài bụng không ghi mức tạ, không có biểu đồ.
  bool get logsWeight => group != MuscleGroup.abs;

  Exercise copyWith({
    int? sortOrder,
    bool? active,
    int? videoDurationS,
    bool? videoAvailable,
    VideoUnavailableReason? videoUnavailableReason,
    DateTime? videoCheckedAt,
  }) => Exercise(
    id: id,
    region: region,
    equipment: equipment,
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
    sortOrder: sortOrder ?? this.sortOrder,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.region == region &&
      other.equipment == equipment &&
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
      other.sortOrder == sortOrder &&
      other.active == active;

  @override
  int get hashCode => Object.hash(
    id,
    region,
    equipment,
    nameVi,
    youtubeVideoId,
    videoDurationS,
    videoAvailable,
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

/// Quy tắc thư viện bài tập (03 Bản 2 §6.10, §6.16; 05 Bản 2 §6.10.2). App và
/// server cùng dùng (ED2-09).
abstract final class LibraryRules {
  /// Thứ tự nhóm cơ của thư viện (F18-R9, UA2-14): Ngực · Lưng · Vai · Tay
  /// trước · Tay sau · Bụng. Khác thứ tự bộ chọn nhóm cơ của lịch (PR-02).
  static const groupOrder = [
    MuscleGroup.chest,
    MuscleGroup.back,
    MuscleGroup.shoulders,
    MuscleGroup.biceps,
    MuscleGroup.triceps,
    MuscleGroup.abs,
  ];

  /// F18-R1: mỗi vùng của 5 nhóm có 1–2 bài máy và 1–2 bài tạ.
  static const minPerEquipment = 1;
  static const maxPerEquipment = 2;

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
    if (e.equipment == Equipment.bodyweight && e.group != MuscleGroup.abs)
      'equipment',
    if (!_youtubeId.hasMatch(e.youtubeVideoId)) 'video.youtubeId',
    if (e.videoChannel.trim().isEmpty) 'video.channel',
    if (e.videoDurationS != null &&
        (e.videoDurationS! < 1 || e.videoDurationS! > maxVideoSeconds))
      'video.durationSeconds',
    if (e.guideSteps.length < minSteps || e.guideSteps.length > maxSteps)
      'guide.steps',
    if (e.guideSafety.length < minSafety || e.guideSafety.length > maxSafety)
      'guide.safety',
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

  /// F18-R1, LIB-R8 trên tập bài đang có trong thư viện: mỗi vùng của 5 nhóm
  /// có 1–2 bài máy, 1–2 bài tạ và không có bài không dụng cụ; mỗi vùng bụng
  /// đúng 1 bài. Thêm: id và tên tiếng Việt không trùng (LIB-R1).
  static List<LibraryIssue> coverageErrors(Iterable<Exercise> library) {
    final active = [
      for (final e in library)
        if (e.active) e,
    ];
    final issues = <LibraryIssue>[];
    for (final region in MuscleRegion.values) {
      final inRegion = [
        for (final e in active)
          if (e.region == region) e,
      ];
      if (region.group == MuscleGroup.abs) {
        if (inRegion.length != 1) {
          issues.add((exerciseId: null, rule: '${region.id}: cần đúng 1 bài'));
        }
        continue;
      }
      for (final eq in [Equipment.machine, Equipment.freeWeight]) {
        final n = inRegion.where((e) => e.equipment == eq).length;
        if (n < minPerEquipment || n > maxPerEquipment) {
          issues.add((
            exerciseId: null,
            rule: '${region.id}: cần 1–2 bài ${eq.wire}, đang có $n',
          ));
        }
      }
    }
    final ids = <String>{};
    final names = <String>{};
    for (final e in active) {
      if (!ids.add(e.id)) issues.add((exerciseId: e.id, rule: 'id trùng'));
      if (!names.add(e.nameVi)) {
        issues.add((exerciseId: e.id, rule: 'nameVi trùng'));
      }
    }
    return issues;
  }

  /// F18-R9: nhóm cơ (theo [groupOrder]) → vùng (thứ tự [MuscleRegion]) → máy
  /// trước, tạ sau → thứ tự trong file. Trả bản sao với `sortOrder` 1, 2, 3…
  static List<Exercise> sorted(List<Exercise> library) {
    final indexed = [for (var i = 0; i < library.length; i++) (i, library[i])];
    indexed.sort((a, b) {
      final ea = a.$2, eb = b.$2;
      final byGroup = groupOrder
          .indexOf(ea.group)
          .compareTo(groupOrder.indexOf(eb.group));
      if (byGroup != 0) return byGroup;
      final byRegion = ea.region.index.compareTo(eb.region.index);
      if (byRegion != 0) return byRegion;
      final byEquipment = ea.equipment.index.compareTo(eb.equipment.index);
      if (byEquipment != 0) return byEquipment;
      return a.$1.compareTo(b.$1);
    });
    return [
      for (var i = 0; i < indexed.length; i++)
        indexed[i].$2.copyWith(sortOrder: i + 1),
    ];
  }
}

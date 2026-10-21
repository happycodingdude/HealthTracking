import 'dart:convert';

import 'package:domain/domain.dart';

/// File thư viện không đọc được hoặc sai lược đồ (05 Bản 2 §6.10.1). Mỗi lỗi
/// có dạng `<id hoặc vị trí>: <trường>`.
final class LibraryFileException implements Exception {
  LibraryFileException(this.issues);

  final List<String> issues;

  @override
  String toString() => 'LibraryFileException(${issues.join('; ')})';
}

/// Giá trị `equipment` của thư viện Bản 2. Bản 3 bỏ loại dụng cụ (TD3-20);
/// cột còn trong database để gửi dạng Bản 2 cho app cũ (TD3-21) và để
/// `library purge` chọn đơn vị cho bài giữ (D3-04).
abstract final class LegacyEquipment {
  static const machine = 'machine';
  static const freeWeight = 'free_weight';
  static const bodyweight = 'bodyweight';
  static const values = {machine, freeWeight, bodyweight};
}

/// Nội dung file thư viện (`data/*.json`) — nguồn duy nhất của thư viện
/// (TD2-05). Trường ngoài lược đồ (kể cả `guideDraft`, `video.title`,
/// `videoBackup`) bị từ chối (06 Bản 2 VS21-T03, C2-3, ED2-12). Trường
/// `equipment` của file Bản 2 (không bắt buộc) được giữ riêng ở
/// [equipment].
final class LibraryFile {
  const LibraryFile(
    this.libraryVersion,
    this.exercises, {
    this.equipment = const {},
  });

  /// Đọc và kiểm lược đồ. Ném [LibraryFileException] với đủ mọi lỗi tìm thấy.
  factory LibraryFile.parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      throw LibraryFileException(['JSON không đọc được: ${e.message}']);
    }
    final issues = <String>[];
    if (json is! Map<String, Object?>) {
      throw LibraryFileException(['gốc file phải là object']);
    }
    _unknownKeys(json, _rootKeys, '', issues);
    final version = json['libraryVersion'];
    if (version is! int || version < 1) issues.add('libraryVersion');
    final list = json['exercises'];
    final exercises = <Exercise>[];
    final equipment = <String, String>{};
    if (list is! List<Object?>) {
      issues.add('exercises');
    } else {
      for (var i = 0; i < list.length; i++) {
        final e = _exercise(list[i], i, issues);
        if (e == null) continue;
        exercises.add(e);
        final raw = (list[i]! as Map<String, Object?>)['equipment'];
        if (raw is String) equipment[e.id] = raw;
      }
    }
    if (issues.isNotEmpty) throw LibraryFileException(issues);
    return LibraryFile(version! as int, exercises, equipment: equipment);
  }

  final int libraryVersion;
  final List<Exercise> exercises;

  /// `equipment` theo `id` của bài (chỉ file Bản 2 có).
  final Map<String, String> equipment;

  static const _rootKeys = {'libraryVersion', 'exercises'};
  static const _exerciseKeys = {
    'id',
    'muscleGroup',
    'muscleRegion',
    'equipment',
    'nameVi',
    'nameEn',
    'video',
    'guide',
    'approvedAt',
  };
  static const _videoKeys = {'youtubeId', 'channel', 'durationSeconds'};
  static const _guideKeys = {'steps', 'safety'};

  static void _unknownKeys(
    Map<String, Object?> map,
    Set<String> allowed,
    String where,
    List<String> issues,
  ) {
    for (final k in map.keys) {
      if (!allowed.contains(k)) issues.add('$where$k: trường ngoài lược đồ');
    }
  }

  static Exercise? _exercise(Object? raw, int index, List<String> issues) {
    if (raw is! Map<String, Object?>) {
      issues.add('exercises[$index]: phải là object');
      return null;
    }
    final id = raw['id'] is String ? raw['id']! as String : '#$index';
    final before = issues.length;
    void bad(String field) => issues.add('$id: $field');
    _unknownKeys(raw, _exerciseKeys, '$id: ', issues);

    String? str(Map<String, Object?> m, String k, String field) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v;
      bad(field);
      return null;
    }

    List<String>? strings(Map<String, Object?> m, String k, String field) {
      final v = m[k];
      if (v is List<Object?> && v.every((s) => s is String)) {
        return v.cast<String>();
      }
      bad(field);
      return null;
    }

    final region = MuscleRegion.tryParse(
      raw['muscleRegion'] is String ? raw['muscleRegion']! as String : '',
    );
    if (region == null) bad('muscleRegion');
    if (region != null && raw['muscleGroup'] != region.group.name) {
      bad('muscleGroup');
    }
    final equipment = raw['equipment'];
    if (equipment != null && !LegacyEquipment.values.contains(equipment)) {
      bad('equipment');
    }
    final nameVi = str(raw, 'nameVi', 'nameVi');
    final nameEn = raw['nameEn'];
    if (nameEn != null && nameEn is! String) bad('nameEn');

    final video = raw['video'];
    String? youtubeId, channel;
    int? duration;
    if (video is Map<String, Object?>) {
      _unknownKeys(video, _videoKeys, '$id: video.', issues);
      youtubeId = str(video, 'youtubeId', 'video.youtubeId');
      channel = str(video, 'channel', 'video.channel');
      final d = video['durationSeconds'];
      if (d != null && d is! int) bad('video.durationSeconds');
      duration = d is int ? d : null;
    } else {
      bad('video');
    }

    final guide = raw['guide'];
    List<String>? steps, safety;
    if (guide is Map<String, Object?>) {
      _unknownKeys(guide, _guideKeys, '$id: guide.', issues);
      steps = strings(guide, 'steps', 'guide.steps');
      safety = strings(guide, 'safety', 'guide.safety');
    } else {
      bad('guide');
    }

    final approved = raw['approvedAt'] is String
        ? LocalDate.tryParse(raw['approvedAt']! as String)
        : null;
    if (approved == null) bad('approvedAt');
    if (raw['id'] is! String) bad('id');

    if (issues.length > before) return null;
    return Exercise(
      id: id,
      region: region!,
      nameVi: nameVi!,
      nameEn: nameEn as String?,
      youtubeVideoId: youtubeId!,
      videoChannel: channel!,
      videoDurationS: duration,
      guideSteps: steps!,
      guideSafety: safety!,
      approvedAt: approved!,
    );
  }
}

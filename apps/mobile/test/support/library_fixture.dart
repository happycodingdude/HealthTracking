import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/library/data/video_player_gateway.dart';

/// Độ dài video dùng trong test và golden (file thư viện chưa đo, B2-1).
const fixtureVideoSeconds = 48;

/// 29 bài của thư viện Bản 2 (`data/v2__exercises.json`, Bạn đã duyệt), thứ
/// tự như `library import` (TD3-07). Độ dài video cố định
/// [fixtureVideoSeconds] để golden không đổi khi file được đo.
List<Exercise> realLibrary() {
  final json =
      jsonDecode(File('../../data/v2__exercises.json').readAsStringSync())
          as Map<String, Object?>;
  return LibraryRules.sorted([
    for (final raw in json['exercises']! as List)
      if (raw case final Map<String, Object?> e)
        Exercise(
          id: e['id']! as String,
          region: MuscleRegion.tryParse(e['muscleRegion']! as String)!,
          nameVi: e['nameVi']! as String,
          nameEn: e['nameEn'] as String?,
          youtubeVideoId: (e['video']! as Map)['youtubeId']! as String,
          videoChannel: (e['video']! as Map)['channel']! as String,
          videoDurationS: fixtureVideoSeconds,
          guideSteps: ((e['guide']! as Map)['steps']! as List).cast<String>(),
          guideSafety: ((e['guide']! as Map)['safety']! as List).cast<String>(),
          approvedAt: LocalDate.parse(e['approvedAt']! as String),
        ),
  ]);
}

/// Ghi [library] (mặc định [realLibrary]) vào Drift như sau một lần pull.
Future<List<Exercise>> seedLibrary(
  AppDatabase db, [
  List<Exercise>? library,
]) async {
  final all = library ?? realLibrary();
  final repo = ExerciseRepository(db);
  for (final e in all) {
    await repo.put(e);
  }
  return all;
}

/// Bài đầu tiên của vùng [region]; [kind] chọn theo mã bài của thư viện Bản
/// 2 (`machine`, `free-weight`, `bodyweight` trong `id`).
Exercise exerciseOf(
  List<Exercise> library,
  MuscleRegion region, [
  String? kind,
]) => library.firstWhere(
  (e) => e.region == region && (kind == null || e.id.contains('-$kind-')),
);

/// Trình phát giả (06 Bản 2 ED2-11): không tạo WebView; test gọi [ready] hoặc
/// [fail] để giả lập video tải xong hoặc tải lỗi.
final class FakeVideoGateway implements VideoPlayerGateway {
  final opened = <String>[];
  int closed = 0;
  VoidCallback? _onReady;
  VoidCallback? _onError;

  void ready() => _onReady?.call();

  void fail() => _onError?.call();

  @override
  VideoPlayerHandle open(
    String videoId, {
    required VoidCallback onReady,
    required VoidCallback onError,
  }) {
    opened.add(videoId);
    _onReady = onReady;
    _onError = onError;
    return _FakeHandle(this);
  }
}

final class _FakeHandle implements VideoPlayerHandle {
  _FakeHandle(this._gateway);

  final FakeVideoGateway _gateway;

  @override
  Widget get view => const SizedBox.expand(key: ValueKey('fake-player'));

  @override
  Future<void> close() async => _gateway.closed++;
}

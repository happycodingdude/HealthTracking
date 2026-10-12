// Đo độ dài và trạng thái video của thư viện trước khi nạp (06 Bản 2 ED2-19,
// VS21-T05). Chạy tay trên máy dev với khóa YouTube Data API thật; không chạy
// trong CI.
//
//   dart run tool/video_durations.dart [data/exercises.json]
//
// Khóa: biến YOUTUBE_API_KEY của tiến trình, rồi `.env` ở gốc repo, rồi
// `apps/server/.env` (IR2-09: khóa không vào git, không vào app).
//
// Với mỗi bài: video công khai, cho nhúng, đã xử lý xong và ≤ 60 giây → ghi
// `video.durationSeconds` vào file. Video không đạt → KHÔNG tự thay (IA2-11):
// in danh sách để gửi Bạn chọn video dự phòng trong gói duyệt thư viện; mã
// thoát 1.
import 'dart:convert';
import 'dart:io';

import 'package:server/server.dart';

Future<void> main(List<String> args) async {
  final path = args.isEmpty ? 'data/exercises.json' : args.single;
  final key = _apiKey();
  if (key == null) {
    stderr.writeln(
      'Thiếu YOUTUBE_API_KEY (biến môi trường hoặc file .env ở gốc repo).',
    );
    exitCode = 2;
    return;
  }
  final file = File(path);
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final exercises = (json['exercises']! as List).cast<Map<String, Object?>>();
  final ids = [
    for (final e in exercises) (e['video']! as Map)['youtubeId']! as String,
  ];
  final Map<String, VideoInfo> info;
  try {
    info = await YouTubeDataApiClient(apiKey: key).videos(ids);
  } on YouTubeApiException catch (e) {
    stderr.writeln('Không gọi được YouTube Data API: ${e.message}');
    exitCode = 1;
    return;
  }

  final failed = <String>[];
  stdout.writeln('| Bài | Video | Độ dài | privacy | embeddable | upload |');
  stdout.writeln('|---|---|---|---|---|---|');
  for (final e in exercises) {
    final video = e['video']! as Map<String, Object?>;
    final id = video['youtubeId']! as String;
    final v = info[id];
    if (v == null) {
      failed.add('${e['id']}: video $id không còn trên YouTube');
      stdout.writeln('| ${e['id']} | $id | — | — | — | — |');
      continue;
    }
    stdout.writeln(
      '| ${e['id']} | $id | ${v.durationSeconds}s | ${v.privacyStatus} | '
      '${v.embeddable} | ${v.uploadStatus} |',
    );
    final problem = v.problem;
    if (problem == null) {
      video['durationSeconds'] = v.durationSeconds;
    } else {
      failed.add(
        '${e['id']}: video $id không đạt (${problem.wire}, '
        '${v.durationSeconds} giây)',
      );
    }
  }
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(json)}\n',
  );
  stdout.writeln(
    '\nĐã ghi độ dài cho ${exercises.length - failed.length}/'
    '${exercises.length} bài vào $path.',
  );
  if (failed.isNotEmpty) {
    stdout
      ..writeln(
        '\nVideo không đạt — gửi Bạn chọn video dự phòng trong gói duyệt '
        'thư viện, không tự thay (IA2-11):',
      )
      ..writeln(failed.map((f) => '  - $f').join('\n'));
    exitCode = 1;
  }
}

String? _apiKey() {
  final fromProcess = Platform.environment['YOUTUBE_API_KEY'];
  if (fromProcess != null && fromProcess.isNotEmpty) return fromProcess;
  for (final path in ['.env', 'apps/server/.env']) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final v = ServerConfig.parseDotEnv(f.readAsStringSync())['YOUTUBE_API_KEY'];
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

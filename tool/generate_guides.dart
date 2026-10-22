// Soạn nháp hướng dẫn tiếng Việt cho bài mới hoặc bài thay video (06 Bản 2
// ED2-12, VS22-T03; 05 Bản 2 §6.9.4). Chạy tay trên máy dev, ngoài app:
//
//   ANTHROPIC_API_KEY=<khóa dev giới hạn 1 USD> \
//     dart run tool/generate_guides.dart [data/v3__exercises.json]
//
// Với mỗi bài chưa có `guide`: gọi Claude Haiku 4.5, ghi bản nháp vào
// `guideDraft` của file, xuất `build/library-review-<ngày>.md` để Bạn duyệt.
// In số token và chi phí quy đổi; ghi sổ bằng
//   admin ai-cost add --feature exercise_guide --vnd <số> --note "…"
// trong tháng soạn (F11-R22, LIB-R7). File còn `guideDraft` thì `library
// import` từ chối cho tới khi chép sang `guide` (sau khi Bạn duyệt).
//
// (Kế hoạch ghi `tools/generate_guides.dart`; đặt trong `tool/` cùng các công
// cụ khác của repo.)
import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:server/server.dart';

Future<void> main(List<String> args) async {
  final path = args.isEmpty ? 'data/v3__exercises.json' : args.single;
  final env = {
    ...ServerConfig.parseDotEnv(
      File('.env').existsSync() ? File('.env').readAsStringSync() : '',
    ),
    ...Platform.environment,
  };
  final key = env['ANTHROPIC_API_KEY'];
  if (key == null || key.isEmpty) {
    stderr.writeln('Thiếu ANTHROPIC_API_KEY (khóa dev, giới hạn 1 USD).');
    exitCode = 2;
    return;
  }
  final config = AiConfig.fromEnvironment({...env, 'AI_PROVIDER': 'anthropic'});
  final file = File(path);
  final library = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final report = await GuideDrafter(
    AnthropicProvider(apiKey: key, model: config.model),
    config,
  ).run(library);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(library)}\n',
  );
  final date = LocalDate.fromDateTime(DateTime.now()).toKey();
  final review = File('build/library-review-$date.md')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      GuideDrafter.reviewMarkdown(library, report.drafted, date: date),
    );
  stdout
    ..writeln('Đã soạn nháp ${report.drafted.length} bài: ${report.drafted}')
    ..writeln('Không đạt (soạn lại sau): ${report.failed}')
    ..writeln(
      'Token: ${report.inputTokens} vào, ${report.outputTokens} ra · chi phí '
      '≈ ${report.costVnd}đ',
    )
    ..writeln('Gói duyệt: ${review.path}')
    ..writeln(
      'Ghi sổ: admin ai-cost add --feature exercise_guide --vnd '
      '${report.costVnd} --note "soạn hướng dẫn ${report.drafted.length} bài"',
    );
}

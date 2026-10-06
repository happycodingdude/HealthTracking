// Bộ đánh giá AI (06 VS12-T12, IR-06): tạo thực đơn với model thật cho các hồ
// sơ chuẩn, đo tỷ lệ thực đơn hợp lệ và chi phí trung bình mỗi lần.
//
//   ANTHROPIC_API_KEY=... dart run bin/ai_eval.dart [--runs 20]
//   dart run bin/ai_eval.dart --fake        (kiểm tra bộ đánh giá, không tốn tiền)
//
// Dùng khóa dev có giới hạn chi tiêu 1 USD (OPS-4). Đạt khi ≥ 90% hợp lệ.
import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:args/args.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart';

/// Hồ sơ chuẩn (06 §6.9.2, VS12-T12).
const _profiles = [
  ('Nam 30t, 2.210 kcal', Sex.male, 30, 2210),
  ('Nữ 55t, 1.200 kcal', Sex.female, 55, 1200),
  ('Nam 30t đặt 1.300 → ngưỡng an toàn 1.500', Sex.male, 30, 1300),
];

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('runs', defaultsTo: '20')
    ..addFlag('fake', help: 'Dùng nhà cung cấp giả để kiểm tra bộ đánh giá.');
  final opts = parser.parse(args);
  final runs = int.tryParse(opts['runs'] as String) ?? 20;
  final env = Platform.environment;
  final config = AiConfig.fromEnvironment({
    ...env,
    'AI_PROVIDER': opts['fake'] == true ? 'fake' : 'anthropic',
  });
  final AiProvider provider = config.provider == 'anthropic'
      ? AnthropicProvider(
          apiKey: config.apiKey!,
          model: config.model,
          timeout: config.timeout,
        )
      : FakeAiProvider();
  final cost = CostEstimator(config);

  stdout.writeln(
    'Bộ đánh giá AI: $runs lần, nhà cung cấp ${provider.name}, model '
    '${provider.model}',
  );
  var valid = 0;
  var totalCenti = 0;
  var maxCenti = 0;
  final failures = <String, int>{};
  for (var i = 0; i < runs; i++) {
    final (label, sex, age, kcal) = _profiles[i % _profiles.length];
    final target = MenuRules.target(kcal, sex);
    final request = PromptBuilder.menu(
      sex: sex,
      age: age,
      targetKcal: target.kcal,
      maxTokens: config.maxTokens,
    );
    final started = DateTime.now();
    String outcome;
    var centi = 0;
    try {
      final r = await provider.complete(request);
      centi = cost.actualCenti(r.inputTokens, r.outputTokens);
      try {
        final menu = MenuPayloadCodec.decode(jsonDecode(r.text));
        final error = MenuValidator.validate(menu, target.kcal);
        outcome = error == null
            ? 'hợp lệ (tổng ${menu.totalKcal}/${target.kcal} kcal)'
            : 'không hợp lệ: ${error.name} (tổng ${menu.totalKcal})';
        if (error == null) {
          valid++;
        } else {
          failures.update(error.name, (n) => n + 1, ifAbsent: () => 1);
        }
      } on FormatException {
        outcome = 'không hợp lệ: không phải JSON';
        failures.update('json', (n) => n + 1, ifAbsent: () => 1);
      } on ContractFormatException catch (e) {
        outcome = 'không hợp lệ: sai schema ở ${e.field}';
        failures.update('schema', (n) => n + 1, ifAbsent: () => 1);
      }
    } on AiProviderException catch (e) {
      outcome = 'lỗi nhà cung cấp: ${e.reason}';
      final input = e.inputTokens;
      final output = e.outputTokens;
      if (input != null && output != null) {
        centi = cost.actualCenti(input, output);
      }
      failures.update(e.reason, (n) => n + 1, ifAbsent: () => 1);
    }
    totalCenti += centi;
    if (centi > maxCenti) maxCenti = centi;
    final ms = DateTime.now().difference(started).inMilliseconds;
    stdout.writeln(
      '${(i + 1).toString().padLeft(2)}. $label: $outcome · '
      '${(centi / 100).toStringAsFixed(0)}đ · ${ms}ms',
    );
  }
  final rate = runs == 0 ? 0 : valid * 100 ~/ runs;
  stdout
    ..writeln()
    ..writeln('Hợp lệ: $valid/$runs ($rate%) · mục tiêu ≥ 90% (IR-06)')
    ..writeln(
      'Chi phí: tổng ${(totalCenti / 100).toStringAsFixed(0)}đ · trung bình '
      '${runs == 0 ? 0 : (totalCenti / runs / 100).toStringAsFixed(0)}đ/lần · '
      'cao nhất ${(maxCenti / 100).toStringAsFixed(0)}đ',
    );
  if (failures.isNotEmpty) stdout.writeln('Lỗi: $failures');
  if (provider is AnthropicProvider) provider.close();
  exitCode = rate >= 90 ? 0 : 1;
}

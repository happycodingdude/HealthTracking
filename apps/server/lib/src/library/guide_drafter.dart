import 'dart:convert';

import 'package:domain/domain.dart';

import '../ai/ai_config.dart';
import '../ai/ai_provider.dart';

/// Kết quả một lần soạn nháp.
final class GuideDraftReport {
  const GuideDraftReport({
    required this.drafted,
    required this.failed,
    required this.inputTokens,
    required this.outputTokens,
    required this.costCenti,
  });

  /// Bài đã có `guideDraft` mới.
  final List<String> drafted;

  /// Bài AI trả không đạt LIB-R4 hoặc lỗi gọi AI (giữ nguyên, soạn lại sau).
  final List<String> failed;
  final int inputTokens;
  final int outputTokens;

  /// Chi phí quy đổi, đơn vị 1/100 đồng (ghi sổ bằng `admin ai-cost add`).
  final int costCenti;

  int get costVnd => (costCenti / 100).ceil();
}

/// Soạn nháp hướng dẫn tiếng Việt cho bài **chưa có `guide`** trong file thư
/// viện, dùng cho các lần thay bài hoặc thay video về sau (06 Bản 2 ED2-12,
/// 05 Bản 2 §6.9.4, TA2-14). Chạy ngoài app; kết quả chỉ ghi vào trường
/// `guideDraft` — không bao giờ vào app (F19-R5): `library import` từ chối
/// file còn `guideDraft`. Bạn duyệt xong, engineer chép `guideDraft` → `guide`,
/// ghi `approvedAt`, xóa `guideDraft`.
final class GuideDrafter {
  GuideDrafter(this._provider, this._config);

  final AiProvider _provider;
  final AiConfig _config;

  static const _maxTokens = 1500;

  static const _system =
      'Bạn soạn hướng dẫn tập gym bằng tiếng Việt cho người khỏe mạnh, mang '
      'tính tham khảo, không thay huấn luyện viên. Trả về JSON đúng schema: '
      '"steps" là 3–6 bước "Cách tập", "safety" là 2–4 ý "Lưu ý an toàn", mỗi '
      'mục một câu ngắn, dễ đọc trong phòng tập. Không nêu mức tạ, số hiệp, '
      'số lần cụ thể. Không hứa hẹn kết quả. Không chẩn đoán hay điều trị. '
      'Động tác phải khớp đúng tên bài.';

  static const _schema = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['steps', 'safety'],
    'properties': {
      'steps': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'safety': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  /// Soạn cho các bài trong [library] (JSON của file thư viện, sửa tại chỗ)
  /// chưa có `guide` và chưa có `guideDraft`. Không ghi đè `guide` đã có.
  Future<GuideDraftReport> run(Map<String, Object?> library) async {
    final drafted = <String>[], failed = <String>[];
    var input = 0, output = 0;
    for (final e
        in (library['exercises']! as List).cast<Map<String, Object?>>()) {
      if (e['guide'] != null || e['guideDraft'] != null) continue;
      final id = '${e['id']}';
      final AiResult result;
      try {
        result = await _provider.complete(
          AiRequest(
            system: _system,
            user: _prompt(e),
            schema: _schema,
            maxTokens: _maxTokens,
            targetKcal: 0,
          ),
        );
      } on AiProviderException catch (err) {
        input += err.inputTokens ?? 0;
        output += err.outputTokens ?? 0;
        failed.add(id);
        continue;
      }
      input += result.inputTokens;
      output += result.outputTokens;
      final draft = _parse(result.text);
      if (draft == null) {
        failed.add(id);
        continue;
      }
      e['guideDraft'] = {'steps': draft.steps, 'safety': draft.safety};
      drafted.add(id);
    }
    return GuideDraftReport(
      drafted: drafted,
      failed: failed,
      inputTokens: input,
      outputTokens: output,
      costCenti: CostEstimator(_config).actualCenti(input, output),
    );
  }

  static String _prompt(Map<String, Object?> e) => [
    'Bài: ${e['nameVi']} (${e['nameEn'] ?? ''})',
    'Nhóm cơ: ${e['muscleGroup']} · vùng cơ: ${e['muscleRegion']}',
    'Dụng cụ: ${e['equipment']}',
  ].join('\n');

  static ({List<String> steps, List<String> safety})? _parse(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      final steps = (json['steps'] as List).cast<String>();
      final safety = (json['safety'] as List).cast<String>();
      if (LibraryRules.guideErrors(steps, safety).isNotEmpty) return null;
      return (steps: steps, safety: safety);
    } on Object {
      return null;
    }
  }

  /// File Markdown liệt kê các bài vừa soạn để Bạn duyệt như gói 11/10:
  /// vùng, tên bài, dụng cụ, link video, kênh, độ dài, hướng dẫn nháp.
  static String reviewMarkdown(
    Map<String, Object?> library,
    List<String> ids, {
    required String date,
  }) {
    final out = StringBuffer()
      ..writeln('# Gói duyệt thư viện — các bài thay đổi ($date)')
      ..writeln()
      ..writeln(
        'Bạn xem video, đọc hướng dẫn nháp và duyệt hoặc yêu cầu đổi. Bài '
        'được duyệt mới đưa vào file thư viện (LIB-R5).',
      );
    for (final e
        in (library['exercises']! as List).cast<Map<String, Object?>>()) {
      if (!ids.contains(e['id'])) continue;
      final video = (e['video'] as Map?) ?? const {};
      final draft = e['guideDraft']! as Map;
      out
        ..writeln()
        ..writeln('## ${e['nameVi']}')
        ..writeln()
        ..writeln('- Mã: `${e['id']}`')
        ..writeln('- Vùng: ${e['muscleGroup']} · ${e['muscleRegion']}')
        ..writeln('- Dụng cụ: ${e['equipment']}')
        ..writeln(
          '- Video: https://www.youtube.com/watch?v=${video['youtubeId']} '
          '(kênh ${video['channel']}, '
          '${video['durationSeconds'] == null ? 'chưa đo độ dài' : '${video['durationSeconds']} giây'})',
        )
        ..writeln()
        ..writeln('**Cách tập (nháp)**')
        ..writeln();
      final steps = (draft['steps'] as List).cast<String>();
      for (var i = 0; i < steps.length; i++) {
        out.writeln('${i + 1}. ${steps[i]}');
      }
      out
        ..writeln()
        ..writeln('**Lưu ý an toàn (nháp)**')
        ..writeln();
      for (final s in (draft['safety'] as List).cast<String>()) {
        out.writeln('- $s');
      }
      out
        ..writeln()
        ..writeln('Duyệt: ☐ Đạt ☐ Đổi — ghi chú:');
    }
    return out.toString();
  }
}

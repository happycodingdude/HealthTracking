import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

/// Anthropic giả cho công cụ soạn hướng dẫn (VS22-T05).
final class FakeGuideProvider implements AiProvider {
  FakeGuideProvider(this.replies);

  final List<Map<String, Object?>> replies;
  final requests = <AiRequest>[];

  @override
  String get name => 'fake';

  @override
  String get model => 'fake-guide';

  @override
  Future<AiResult> complete(AiRequest request) async {
    requests.add(request);
    return AiResult(
      text: jsonEncode(replies.removeAt(0)),
      inputTokens: 300,
      outputTokens: 400,
    );
  }
}

void main() {
  Map<String, Object?> libraryWithNewExercise() {
    final json = libraryMinJson();
    final added =
        fixtureEntry(MuscleRegion.lats, Equipment.machine, suffix: 'b')
          ..remove('guide')
          ..remove('approvedAt');
    (json['exercises']! as List).add(added);
    return json;
  }

  const good = {
    'steps': ['Ngồi vào máy', 'Kéo thanh xuống ngực', 'Trả chậm về vị trí đầu'],
    'safety': ['Không ngả người ra sau', 'Dừng khi đau vai'],
  };

  test('ED2-12: chỉ soạn bài chưa có guide → ghi guideDraft, không ghi đè '
      'guide đã có; tính token và chi phí', () async {
    final library = libraryWithNewExercise();
    final ai = FakeGuideProvider([good]);
    final report = await GuideDrafter(ai, const AiConfig()).run(library);
    expect(report.drafted, ['lats-machine-b']);
    expect(ai.requests, hasLength(1));
    expect(ai.requests.single.user, contains('Bài machine lats b'));
    final list = (library['exercises']! as List).cast<Map<String, Object?>>();
    expect(list.last['guideDraft'], good);
    expect(list.last.containsKey('guide'), isFalse);
    expect(list.first.containsKey('guideDraft'), isFalse);
    // 300 × 1 + 400 × 5 USD/1M token × 27.000đ = 62,1đ → làm tròn lên.
    expect(report.costVnd, 63);

    final md = GuideDrafter.reviewMarkdown(
      library,
      report.drafted,
      date: '2026-11-12',
    );
    expect(md, contains('## Bài machine lats b'));
    expect(md, contains('https://www.youtube.com/watch?v='));
    expect(md, contains('1. Ngồi vào máy'));
    expect(md, contains('- Dừng khi đau vai'));

    // Chạy lại: đã có guideDraft thì không soạn nữa.
    final again = await GuideDrafter(
      FakeGuideProvider([]),
      const AiConfig(),
    ).run(library);
    expect(again.drafted, isEmpty);
  });

  test('bản nháp không đạt LIB-R4 (2 bước, có "12 lần") → không ghi, báo '
      'soạn lại', () async {
    final library = libraryWithNewExercise();
    final report = await GuideDrafter(
      FakeGuideProvider([
        {
          'steps': ['Một', 'Lặp lại 12 lần', 'Ba'],
          'safety': ['Một', 'Hai'],
        },
      ]),
      const AiConfig(),
    ).run(library);
    expect(report.drafted, isEmpty);
    expect(report.failed, ['lats-machine-b']);
    expect(
      ((library['exercises']! as List).last as Map).containsKey('guideDraft'),
      isFalse,
    );
  });

  test('F19-R5: file còn guideDraft thì không nạp được vào server', () async {
    final library = libraryWithNewExercise();
    await GuideDrafter(
      FakeGuideProvider([good]),
      const AiConfig(),
    ).run(library);
    expect(
      () => LibraryFile.parse(jsonEncode(library)),
      throwsA(isA<LibraryFileException>()),
    );
  });
}

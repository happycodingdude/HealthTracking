import 'dart:async';
import 'dart:convert';

import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

void main() {
  test('chạy định kỳ theo chu kỳ', () async {
    final log = CapturingLogger();
    final jobs = JobScheduler(log.logger);
    var count = 0;
    jobs.every('tick', const Duration(milliseconds: 20), () async => count++);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await jobs.stop();
    expect(count, greaterThanOrEqualTo(3));
  });

  test('không chạy chồng khi lần trước chưa xong', () async {
    final jobs = JobScheduler(CapturingLogger().logger);
    final gate = Completer<void>();
    var started = 0;
    Future<void> job() async {
      started++;
      await gate.future;
    }

    final first = jobs.runNow('slow', job);
    final second = jobs.runNow('slow', job);
    expect(started, 1);
    gate.complete();
    await Future.wait([first, second]);
  });

  test('lỗi được ghi log, không ném ra ngoài', () async {
    final log = CapturingLogger();
    final jobs = JobScheduler(log.logger);
    await jobs.runNow('bad', () async => throw StateError('x'));
    final line = jsonDecode(log.lines.single) as Map;
    expect(line['event'], 'job_failed');
    expect(line['job'], 'bad');
  });

  test('stop chờ job đang chạy xong rồi mới trả về', () async {
    final jobs = JobScheduler(CapturingLogger().logger);
    var finished = false;
    unawaited(
      jobs.runNow('slow', () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        finished = true;
      }),
    );
    await jobs.stop();
    expect(finished, isTrue);
    expect(
      () => jobs.every('x', const Duration(seconds: 1), () async {}),
      throwsStateError,
    );
  });
}

// In các ô của một mốc trong reviewMatrix dạng TSV cho tool/capture_screens.sh.
import 'dart:io';

import 'package:mobile/dev/review_matrix.dart' as rm;

void main(List<String> args) {
  final m = rm.Milestone.values.firstWhere(
    (x) => x.name.toUpperCase() == args.first.toUpperCase(),
  );
  for (final c in rm.cellsOf(m)) {
    stdout.writeln(
      [
        c.id,
        c.screen,
        c.state,
        c.mock.page,
        c.mock.x,
        c.mock.y,
        c.mock.w,
        c.mock.h,
      ].join('\t'),
    );
  }
}

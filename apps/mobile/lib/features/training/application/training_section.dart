import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';

/// 3 mục của tab Tập luyện (04 Bản 2 §6.3.2, UD2-01).
enum TrainingSection {
  schedule(S.sectionSchedule),
  library(S.sectionLibrary),
  progress(S.sectionProgress);

  const TrainingSection(this.label);

  final String label;
}

/// Mục đang mở của tab Tập luyện (05 Bản 2 §6.4.2): mở tab lần đầu trong
/// phiên là mục Lịch; sau đó nhớ mục đang mở khi Bạn sang tab khác rồi quay
/// lại (NAV-8). Chỉ giữ trong bộ nhớ, mở lại app thì về mục Lịch.
final trainingTabProvider =
    NotifierProvider<TrainingTabNotifier, TrainingSection>(
      TrainingTabNotifier.new,
    );

final class TrainingTabNotifier extends Notifier<TrainingSection> {
  @override
  TrainingSection build() => TrainingSection.schedule;

  void select(TrainingSection section) => state = section;
}

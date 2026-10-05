import '../strings_vi.dart';

/// 5 tab theo thứ tự trái → phải (UR-01, D-19). Chỉ số = chỉ số nhánh router.
enum AppTab {
  schedule(S.tabSchedule, '/schedule'),
  menu(S.tabMenu, '/menu'),
  today(S.tabToday, '/today'),
  weight(S.tabWeight, '/weight'),
  me(S.tabMe, '/me');

  const AppTab(this.label, this.path);

  final String label;
  final String path;
}

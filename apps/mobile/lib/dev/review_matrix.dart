// Ma trận màn × trạng thái của Bản 4 (06 Bản 4 ED4-04, §6.10.2
// `reviewMatrix`): dùng chung cho bộ ảnh so sánh (capture_test.dart) và kiểm
// mọi ô có golden (VS-51). Mỗi ô ghi trang và vùng tương ứng trong
// docs/specs/v4/04-ui-mockups.pdf (tọa độ điểm, trang 930 × 1315).

/// Mốc của 06 Bản 4 §6.3.1.
enum Milestone { m17, m18, m19, m20, m21 }

/// Vùng cắt trên trang mock: [page] 1-based; [x], [y], [w], [h] theo điểm.
typedef MockRect = ({int page, double x, double y, double w, double h});

final class ReviewCell {
  const ReviewCell({
    required this.id,
    required this.milestone,
    required this.screen,
    required this.state,
    required this.mock,
    this.goldenTest,
  });

  /// Tên ảnh chụp (`build/review/<id>.png`).
  final String id;
  final Milestone milestone;

  /// Mã màn của 02 Bản 4 §6.3 (S-10…).
  final String screen;

  /// Trạng thái theo 04 Bản 4.
  final String state;
  final MockRect mock;

  /// Tên file golden tương ứng (không có hậu tố biến thể), nếu có.
  final String? goldenTest;
}

/// Cột k (0..3) của một hàng mock có 4 màn: x ≈ 13 + 230·k, rộng 205.
MockRect col(int page, int k, double y, double h) =>
    (page: page, x: 13 + 230.0 * k, y: y, w: 205, h: h);

const _m17 = Milestone.m17;

final reviewMatrix = <ReviewCell>[
  // M17 — nền tảng: trang thành phần đối chiếu phần "0 · Nền tảng style".
  ReviewCell(
    id: 'm17_components_1',
    milestone: _m17,
    screen: 'Nền tảng',
    state: 'thành phần (nửa trên)',
    mock: col(1, 0, 205, 530),
    goldenTest: 'components',
  ),
  const ReviewCell(
    id: 'm17_components_2',
    milestone: _m17,
    screen: 'Nền tảng',
    state: 'thành phần (nửa dưới)',
    mock: (page: 1, x: 243, y: 205, w: 435, h: 440),
    goldenTest: 'components',
  ),
  const ReviewCell(
    id: 'm17_dialog',
    milestone: _m17,
    screen: 'Nền tảng',
    state: 'hộp xác nhận',
    mock: (page: 1, x: 243, y: 205, w: 205, h: 200),
    goldenTest: 'dialog',
  ),
  const ReviewCell(
    id: 'm17_sheet',
    milestone: _m17,
    screen: 'Nền tảng',
    state: 'bảng trượt',
    mock: (page: 1, x: 243, y: 405, w: 205, h: 180),
    goldenTest: 'sheet',
  ),
  const ReviewCell(
    id: 'm17_glyphs',
    milestone: _m17,
    screen: 'Nền tảng',
    state: 'dấu hiệu trạng thái',
    mock: (page: 1, x: 473, y: 205, w: 205, h: 440),
    goldenTest: 'components',
  ),
];

List<ReviewCell> cellsOf(Milestone m) => [
  for (final c in reviewMatrix)
    if (c.milestone == m) c,
];

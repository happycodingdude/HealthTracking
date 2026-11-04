// Ma trận màn × trạng thái của Bản 4 (06 Bản 4 ED4-04, §6.10.2
// `reviewMatrix`): dùng chung cho bộ ảnh so sánh (capture_test.dart) và kiểm
// mọi ô có golden (VS-51). Mỗi ô ghi trang và vùng tương ứng trong
// docs/specs/v4/04-ui-mockups.pdf (tọa độ điểm, trang 930 × 1315).
//
// Bản 5 (06 Bản 5 ED5-09): mốc M23 → M26; mỗi ô so với hình riêng của màn
// trong docs/specs/v5/04-ui-mockups/ ([ReviewCell.mockFile]); màn không có
// hình Bản 5 thì giữ mock Bản 4 (`mockFile` null, [noMock]).

/// Mốc của 06 Bản 4 §6.3.1 và 06 Bản 5 §6.3.1.
enum Milestone { m17, m18, m19, m20, m21, m23, m24, m25, m26 }

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
    this.mockFile,
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

  /// Bản 5: hình mock của màn (đường dẫn từ gốc repo), so cả hình.
  final String? mockFile;
}

/// Ô Bản 5 không có hình mock riêng (màn giữ nguyên Bản 4).
const MockRect noMock = (page: 0, x: 0, y: 0, w: 0, h: 0);

/// Hình mock Bản 5 của màn [name] (`s65`, `s21`…).
String v5Mock(String name) => 'docs/specs/v5/04-ui-mockups/$name.png';

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
  // M18 — màn dùng hằng ngày (trang 1 hàng "1 ·", trang 2).
  ReviewCell(
    id: 'm18_s10_logging',
    milestone: Milestone.m18,
    screen: 'S-10',
    state: 'H4 có buổi, đã đến giờ, đã ghi 2 bài',
    mock: col(1, 0, 915, 400),
    goldenTest: 's10_logging',
  ),
  ReviewCell(
    id: 'm18_s10_not_started',
    milestone: Milestone.m18,
    screen: 'S-10',
    state: 'H3 có buổi, chưa đến giờ',
    mock: col(1, 1, 915, 230),
    goldenTest: 's10_not_started',
  ),
  ReviewCell(
    id: 'm18_s10_done',
    milestone: Milestone.m18,
    screen: 'S-10',
    state: 'H5 đã tập, nhiều nhóm cơ',
    mock: col(1, 1, 1130, 185),
    goldenTest: 's10_done',
  ),
  ReviewCell(
    id: 'm18_s10_rest',
    milestone: Milestone.m18,
    screen: 'S-10',
    state: 'H2 ngày nghỉ',
    mock: col(1, 2, 915, 400),
    goldenTest: 's10_rest',
  ),
  ReviewCell(
    id: 'm18_s10_no_schedule',
    milestone: Milestone.m18,
    screen: 'S-10',
    state: 'H1 chưa có lịch',
    mock: col(1, 2, 1230, 85),
  ),
  ReviewCell(
    id: 'm18_s10_skipped',
    milestone: Milestone.m18,
    screen: 'S-10',
    state: 'H6 không tập',
    mock: col(1, 0, 915, 400),
    goldenTest: 's10_skipped',
  ),
  ReviewCell(
    id: 'm18_s63_past',
    milestone: Milestone.m18,
    screen: 'S-63',
    state: 'buổi đã qua, đã tập',
    mock: col(1, 3, 915, 400),
    goldenTest: 's63_window',
  ),
  ReviewCell(
    id: 'm18_s63_future',
    milestone: Milestone.m18,
    screen: 'S-63',
    state: 'buổi ngày mai, hai nhóm cơ',
    mock: col(2, 0, 299, 420),
    goldenTest: 's63_upcoming',
  ),
  ReviewCell(
    id: 'm18_s64_prefill',
    milestone: Milestone.m18,
    screen: 'S-64',
    state: 'điền sẵn, đã sửa Kết thúc',
    mock: col(2, 1, 299, 420),
    goldenTest: 's64_prefill',
  ),
  ReviewCell(
    id: 'm18_s64_first',
    milestone: Milestone.m18,
    screen: 'S-64',
    state: 'lần ghi đầu: chọn kg',
    mock: col(2, 2, 299, 310),
    goldenTest: 's64_first',
  ),
  ReviewCell(
    id: 'm18_s65',
    milestone: Milestone.m18,
    screen: 'S-65',
    state: 'xác nhận chốt buổi',
    mock: col(2, 2, 610, 170),
    goldenTest: 's65_today',
  ),
  ReviewCell(
    id: 'm18_s23',
    milestone: Milestone.m18,
    screen: 'S-23',
    state: 'sửa trạng thái buổi đã tập',
    mock: col(1, 1, 1130, 185),
    goldenTest: 's23_done',
  ),
  ReviewCell(
    id: 'm18_s30',
    milestone: Milestone.m18,
    screen: 'S-30',
    state: 'có thực đơn',
    mock: col(2, 3, 299, 420),
    goldenTest: 's30',
  ),
  ReviewCell(
    id: 'm18_s30_empty',
    milestone: Milestone.m18,
    screen: 'S-30',
    state: 'trống',
    mock: col(2, 0, 835, 230),
  ),
  ReviewCell(
    id: 'm18_s30_generating',
    milestone: Milestone.m18,
    screen: 'S-30',
    state: 'đang tạo',
    mock: col(2, 0, 1010, 110),
  ),
  ReviewCell(
    id: 'm18_s40',
    milestone: Milestone.m18,
    screen: 'S-40',
    state: 'có dữ liệu',
    mock: col(2, 1, 835, 420),
  ),
  ReviewCell(
    id: 'm18_s41',
    milestone: Milestone.m18,
    screen: 'S-41',
    state: 'sửa số cân',
    mock: col(2, 2, 835, 250),
  ),
  ReviewCell(
    id: 'm18_s41_big',
    milestone: Milestone.m18,
    screen: 'S-41',
    state: 'hộp chênh 5 kg',
    mock: col(2, 2, 1050, 130),
  ),
  // M19 — Tập luyện còn lại (trang 3): S-20, S-21, S-22, S-24, S-25 (VS-46);
  // S-66, S-67, S-68, S-69, S-72 (VS-47).
  ReviewCell(
    id: 'm19_s20',
    milestone: Milestone.m19,
    screen: 'S-20',
    state: 'lịch tháng, banner Chia lại, tuần này',
    mock: col(3, 0, 180, 540),
  ),
  ReviewCell(
    id: 'm19_s21',
    milestone: Milestone.m19,
    screen: 'S-21',
    state: 'ngày tập chưa đến (3 nút + Trả về)',
    mock: col(3, 1, 180, 230),
  ),
  ReviewCell(
    id: 'm19_s21_locked',
    milestone: Milestone.m19,
    screen: 'S-21',
    state: 'ngày quá 7 ngày: ổ khóa, nút mờ',
    mock: col(3, 1, 415, 110),
  ),
  ReviewCell(
    id: 'm19_s22',
    milestone: Milestone.m19,
    screen: 'S-22',
    state: 'đang sửa Thứ 4',
    mock: col(3, 2, 180, 505),
  ),
  ReviewCell(
    id: 'm19_s24',
    milestone: Milestone.m19,
    screen: 'S-24',
    state: 'buổi thêm, chọn Bụng',
    mock: col(3, 1, 180, 230),
  ),
  ReviewCell(
    id: 'm19_s25',
    milestone: Milestone.m19,
    screen: 'S-25',
    state: '3/4 +1, dải tuần, danh sách ngày',
    mock: col(3, 3, 180, 330),
  ),
  ReviewCell(
    id: 'm19_s66',
    milestone: Milestone.m19,
    screen: 'S-66',
    state: 'nhóm Ngực',
    mock: col(3, 0, 805, 420),
  ),
  ReviewCell(
    id: 'm19_s67',
    milestone: Milestone.m19,
    screen: 'S-67',
    state: 'từ buổi, nấc máy, ghi chú',
    mock: col(3, 1, 805, 440),
  ),
  ReviewCell(
    id: 'm19_s68',
    milestone: Milestone.m19,
    screen: 'S-68',
    state: 'tiến bộ, bài đã rời thư viện',
    mock: col(3, 2, 805, 330),
  ),
  ReviewCell(
    id: 'm19_s72',
    milestone: Milestone.m19,
    screen: 'S-72',
    state: 'hộp đổi đơn vị',
    mock: col(3, 2, 1140, 150),
  ),
  ReviewCell(
    id: 'm19_s69',
    milestone: Milestone.m19,
    screen: 'S-69',
    state: 'biểu đồ mức tạ',
    mock: col(3, 3, 805, 300),
  ),
  // M20 — tab Tôi (trang 4): S-50, S-51, S-52, S-53, S-54, S-56, S-73 (VS-48).
  ReviewCell(
    id: 'm20_s50',
    milestone: Milestone.m20,
    screen: 'S-50',
    state: 'thẻ hồ sơ, danh sách mục, banner chặn thông báo',
    mock: col(4, 0, 125, 480),
  ),
  ReviewCell(
    id: 'm20_s51',
    milestone: Milestone.m20,
    screen: 'S-51',
    state: 'ô dạng thẻ, mức vận động',
    mock: col(4, 1, 125, 400),
  ),
  ReviewCell(
    id: 'm20_s52',
    milestone: Milestone.m20,
    screen: 'S-52',
    state: 'số lớn, Tự động | Tự đặt, banner đề xuất',
    mock: col(4, 1, 525, 200),
  ),
  ReviewCell(
    id: 'm20_s53',
    milestone: Milestone.m20,
    screen: 'S-53',
    state: 'bảng trượt đề xuất',
    mock: col(4, 2, 125, 190),
  ),
  ReviewCell(
    id: 'm20_s54',
    milestone: Milestone.m20,
    screen: 'S-54',
    state: 'số lớn, thanh tiến độ',
    mock: col(4, 2, 330, 110),
  ),
  ReviewCell(
    id: 'm20_s56',
    milestone: Milestone.m20,
    screen: 'S-56',
    state: 'chưa đồng bộ, đăng xuất',
    mock: col(4, 3, 125, 210),
  ),
  ReviewCell(
    id: 'm20_s73',
    milestone: Milestone.m20,
    screen: 'S-73',
    state: 'hộp đăng xuất',
    mock: col(4, 3, 345, 130),
  ),
  // M20 — đăng nhập và thiết lập lần đầu (trang 4, hàng dưới): S-01, S-01a,
  // S-01b, S-02 → S-07 (VS-49). S-02, S-04, S-05 không có khung mock riêng:
  // đối chiếu phần chú thích dưới S-03 (mô tả S-02, S-04) và style chung.
  // Từ 04 Bản 4 v1.7: S-01 → S-01c đối chiếu `04-ui-mockups-login.pdf` (hàng
  // H "Thẻ hội viên"), không còn theo trang 4.
  ReviewCell(
    id: 'm20_s01',
    milestone: Milestone.m20,
    screen: 'S-01',
    state: 'chào mừng: hai thẻ xếp chồng, Tạo thẻ, Đã có thẻ',
    mock: col(4, 0, 870, 435),
  ),
  ReviewCell(
    id: 'm20_s01a',
    milestone: Milestone.m20,
    screen: 'S-01a',
    state: 'tạo thẻ, ô số điện thoại lỗi',
    mock: col(4, 1, 870, 425),
  ),
  ReviewCell(
    id: 'm20_s01b',
    milestone: Milestone.m20,
    screen: 'S-01b',
    state: 'đăng nhập, Quên mật khẩu?',
    mock: col(4, 1, 1142, 152),
  ),
  ReviewCell(
    id: 'm20_s01c',
    milestone: Milestone.m20,
    screen: 'S-01c',
    state: 'bảng trượt quên mật khẩu',
    mock: col(4, 1, 1142, 152),
  ),
  ReviewCell(
    id: 'm20_s02',
    milestone: Milestone.m20,
    screen: 'S-02',
    state: 'bước 1/5: 4 ý tham khảo, Tôi đã hiểu',
    mock: col(4, 2, 1234, 100),
  ),
  ReviewCell(
    id: 'm20_s03',
    milestone: Milestone.m20,
    screen: 'S-03',
    state: 'bước 2/5: ô dạng thẻ, mức vận động, mục tiêu',
    mock: col(4, 2, 870, 424),
  ),
  ReviewCell(
    id: 'm20_s04',
    milestone: Milestone.m20,
    screen: 'S-04',
    state: 'bước 3/5: số lớn, Giữ mức này / Đặt mức khác',
    mock: col(4, 2, 1234, 100),
  ),
  ReviewCell(
    id: 'm20_s05',
    milestone: Milestone.m20,
    screen: 'S-05',
    state: 'bước 4/5: lịch tuần trống, Để sau',
    mock: col(4, 2, 1234, 100),
  ),
  ReviewCell(
    id: 'm20_s06',
    milestone: Milestone.m20,
    screen: 'S-06',
    state: 'bước 5/5: ví dụ thật từ lịch, Bật nhắc / Để sau',
    mock: col(4, 3, 870, 315),
  ),
  ReviewCell(
    id: 'm20_s07',
    milestone: Milestone.m20,
    screen: 'S-07',
    state: 'đang khôi phục, thanh tiến trình',
    mock: col(4, 3, 1193, 105),
  ),
  // M21 — ngoài app (trang 5): S-70 widget (7 trạng thái), S-71 thẻ màn hình
  // khóa (4 trạng thái) + Dynamic Island. Ảnh từ XCTest snapshot (VS50-T03),
  // không chụp qua flutter drive.
  ReviewCell(
    id: 'm21_s70_not_done',
    milestone: Milestone.m21,
    screen: 'S-70',
    state: 'buổi hôm nay chưa đánh dấu (viền cam)',
    mock: col(5, 0, 122, 72),
  ),
  ReviewCell(
    id: 'm21_s70_done',
    milestone: Milestone.m21,
    screen: 'S-70',
    state: 'đã tập (dấu tích cam)',
    mock: col(5, 0, 122, 72),
  ),
  ReviewCell(
    id: 'm21_s70_skipped',
    milestone: Milestone.m21,
    screen: 'S-70',
    state: 'không tập (gạch ngang)',
    mock: col(5, 0, 122, 72),
  ),
  ReviewCell(
    id: 'm21_s70_rest_extra',
    milestone: Milestone.m21,
    screen: 'S-70',
    state: 'nghỉ + buổi thêm',
    mock: col(5, 0, 195, 72),
  ),
  ReviewCell(
    id: 'm21_s70_rest_no_sessions',
    milestone: Milestone.m21,
    screen: 'S-70',
    state: 'nghỉ, tuần không có buổi',
    mock: col(5, 0, 195, 72),
  ),
  ReviewCell(
    id: 'm21_s70_no_schedule',
    milestone: Milestone.m21,
    screen: 'S-70',
    state: 'chưa có lịch tập',
    mock: col(5, 0, 122, 72),
  ),
  ReviewCell(
    id: 'm21_s70_signed_out',
    milestone: Milestone.m21,
    screen: 'S-70',
    state: 'chưa đăng nhập',
    mock: col(5, 0, 122, 72),
  ),
  ReviewCell(
    id: 'm21_s70_not_done_maxtext',
    milestone: Milestone.m21,
    screen: 'S-70',
    state: 'chưa đánh dấu, cỡ chữ lớn',
    mock: col(5, 0, 122, 72),
  ),
  ReviewCell(
    id: 'm21_s71_logging',
    milestone: Milestone.m21,
    screen: 'S-71',
    state: 'đang ghi: vừa ghi + kế tiếp',
    mock: col(5, 1, 122, 113),
  ),
  ReviewCell(
    id: 'm21_s71_nothing_logged',
    milestone: Milestone.m21,
    screen: 'S-71',
    state: 'chưa ghi bài nào',
    mock: col(5, 1, 122, 113),
  ),
  ReviewCell(
    id: 'm21_s71_all_logged',
    milestone: Milestone.m21,
    screen: 'S-71',
    state: 'đã ghi hết bài',
    mock: col(5, 1, 122, 113),
  ),
  ReviewCell(
    id: 'm21_s71_abs_only',
    milestone: Milestone.m21,
    screen: 'S-71',
    state: 'bài bụng',
    mock: col(5, 1, 122, 113),
  ),
  ReviewCell(
    id: 'm21_s71_logging_maxtext',
    milestone: Milestone.m21,
    screen: 'S-71',
    state: 'đang ghi, cỡ chữ lớn',
    mock: col(5, 1, 122, 113),
  ),
  ReviewCell(
    id: 'm21_s71_island_compact',
    milestone: Milestone.m21,
    screen: 'S-71',
    state: 'Dynamic Island thu gọn',
    mock: col(5, 1, 241, 30),
  ),
  ReviewCell(
    id: 'm21_s71_island_expanded',
    milestone: Milestone.m21,
    screen: 'S-71',
    state: 'Dynamic Island mở rộng',
    mock: col(5, 1, 122, 113),
  ),
  // M23 — Bản 5 nền khóa trong ngày (06 Bản 5 VS-52).
  ReviewCell(
    id: 'm23_s65',
    milestone: Milestone.m23,
    screen: 'S-65',
    state: 'xác nhận "Đã tập" câu mới',
    mock: noMock,
    mockFile: v5Mock('s65'),
    goldenTest: 's65_today',
  ),
  ReviewCell(
    id: 'm23_s23',
    milestone: Milestone.m23,
    screen: 'S-23',
    state: 'ba mục Đã tập | Không tập | Chưa đánh dấu',
    mock: noMock,
    mockFile: v5Mock('s23'),
    goldenTest: 's23_done',
  ),
  ReviewCell(
    id: 'm23_s21_past',
    milestone: Milestone.m23,
    screen: 'S-21',
    state: 'ngày đã qua: chỉ "Xem buổi"',
    mock: noMock,
    mockFile: v5Mock('s21'),
    goldenTest: 's21_past',
  ),
  ReviewCell(
    id: 'm23_s21_today',
    milestone: Milestone.m23,
    screen: 'S-21',
    state: 'hôm nay đã "Không tập": "Đổi sang Đã tập" → S-23',
    mock: noMock,
    mockFile: v5Mock('s21'),
    goldenTest: 's21_today_marked',
  ),
  ReviewCell(
    id: 'm23_s20',
    milestone: Milestone.m23,
    screen: 'S-20',
    state: 'ngày đã qua không ổ khóa (phần tạm dừng thuộc M25)',
    mock: noMock,
    mockFile: v5Mock('s20'),
    goldenTest: 's20',
  ),
  const ReviewCell(
    id: 'm23_s24_edit',
    milestone: Milestone.m23,
    screen: 'S-24',
    state: 'sửa buổi tập thêm hôm nay, "Xóa buổi thêm"',
    mock: noMock,
    goldenTest: 's24_edit',
  ),
  const ReviewCell(
    id: 'm23_s10_done',
    milestone: Milestone.m23,
    screen: 'S-10',
    state: 'H5 Đã tập (chạm dấu → S-23)',
    mock: noMock,
    goldenTest: 's10_done',
  ),
  const ReviewCell(
    id: 'm23_s10_skipped',
    milestone: Milestone.m23,
    screen: 'S-10',
    state: 'H6 Không tập, đổi lại trong ngày',
    mock: noMock,
    goldenTest: 's10_skipped',
  ),
  // M24 — Bản 5 buổi tập linh hoạt + mức thoải mái (06 Bản 5 VS-53 → VS-55).
  ReviewCell(
    id: 'm24_s10_h4',
    milestone: Milestone.m24,
    screen: 'S-10',
    state:
        'H4 đủ 5 loại dòng (đã ghi + 2 vạch cam, thay ⇄, bỏ qua, buổi trước + 1 vạch xám, thêm "+"), "+ Thêm bài"',
    mock: noMock,
    mockFile: v5Mock('s10-h4'),
    goldenTest: 's10_items',
  ),
  ReviewCell(
    id: 'm24_s74_original',
    milestone: Milestone.m24,
    screen: 'S-74',
    state: 'bài gốc: Xem bài · Đổi bài · Bỏ qua hôm nay · Xóa bài thêm (mờ)',
    mock: noMock,
    mockFile: v5Mock('s74'),
    goldenTest: 's74_original',
  ),
  ReviewCell(
    id: 'm24_s74_replacement',
    milestone: Milestone.m24,
    screen: 'S-74',
    state: 'bài thay: thêm "Chọn lại bài gốc"',
    mock: noMock,
    mockFile: v5Mock('s74'),
    goldenTest: 's74_replacement',
  ),
  ReviewCell(
    id: 'm24_s74_extra',
    milestone: Milestone.m24,
    screen: 'S-74',
    state: 'bài thêm: không "Đổi bài", "Xóa bài thêm" đỏ',
    mock: noMock,
    mockFile: v5Mock('s74'),
    goldenTest: 's74_extra',
  ),
  ReviewCell(
    id: 'm24_s75_replace',
    milestone: Milestone.m24,
    screen: 'S-75',
    state: '"Đổi bài": ẩn bài trong buổi',
    mock: noMock,
    mockFile: v5Mock('s75'),
    goldenTest: 's75_replace',
  ),
  ReviewCell(
    id: 'm24_s75_add',
    milestone: Milestone.m24,
    screen: 'S-75',
    state: '"Thêm bài": ẩn bài trong buổi',
    mock: noMock,
    mockFile: v5Mock('s75'),
    goldenTest: 's75_add',
  ),
  ReviewCell(
    id: 'm24_s64_kg',
    milestone: Milestone.m24,
    screen: 'S-64',
    state: 'kg: "Kết thúc" + 1 vạch xám, +2,5, chọn Vừa',
    mock: noMock,
    mockFile: v5Mock('s64'),
    goldenTest: 's64_feel',
  ),
  ReviewCell(
    id: 'm24_s64_steps',
    milestone: Milestone.m24,
    screen: 'S-64',
    state: 'nấc máy lần ghi đầu, chọn Mệt',
    mock: noMock,
    mockFile: v5Mock('s64'),
    goldenTest: 's64_feel_steps',
  ),
  ReviewCell(
    id: 'm24_s64_abs',
    milestone: Milestone.m24,
    screen: 'S-64',
    state: 'bài bụng: chỉ thanh ba mức + ghi chú',
    mock: noMock,
    mockFile: v5Mock('s64'),
    goldenTest: 's64_feel_abs',
  ),
  ReviewCell(
    id: 'm24_s78_replace',
    milestone: Milestone.m24,
    screen: 'S-78',
    state: '"Đổi bài?" · "Xóa và đổi bài"',
    mock: noMock,
    mockFile: v5Mock('s78'),
    goldenTest: 's78_replace',
  ),
  ReviewCell(
    id: 'm24_s78_restore',
    milestone: Milestone.m24,
    screen: 'S-78',
    state: '"Chọn lại bài gốc?" · "Xóa và chọn lại"',
    mock: noMock,
    mockFile: v5Mock('s78'),
    goldenTest: 's78_restore',
  ),
  ReviewCell(
    id: 'm24_s78_skip',
    milestone: Milestone.m24,
    screen: 'S-78',
    state: '"Bỏ qua bài?" · "Xóa và bỏ qua"',
    mock: noMock,
    mockFile: v5Mock('s78'),
    goldenTest: 's78_skip',
  ),
  ReviewCell(
    id: 'm24_s78_remove_extra',
    milestone: Milestone.m24,
    screen: 'S-78',
    state: '"Xóa bài thêm?" · "Xóa bài"',
    mock: noMock,
    mockFile: v5Mock('s78'),
    goldenTest: 's78_remove_extra',
  ),
  ReviewCell(
    id: 'm24_s79',
    milestone: Milestone.m24,
    screen: 'S-79',
    state: 'mọi bài đã bỏ qua → "Buổi sẽ ghi là Không tập."',
    mock: noMock,
    mockFile: v5Mock('s79'),
    goldenTest: 's79',
  ),
  ReviewCell(
    id: 'm24_s63_past',
    milestone: Milestone.m24,
    screen: 'S-63',
    state: 'buổi đã qua: thay / bỏ qua / thêm, dấu ba vạch cam, chỉ xem',
    mock: noMock,
    mockFile: v5Mock('s63'),
    goldenTest: 's63_feel',
  ),
  const ReviewCell(
    id: 'm24_s63_upcoming',
    milestone: Milestone.m24,
    screen: 'S-63',
    state: 'buổi chưa đến: GẦN NHẤT + dấu ba vạch xám, không ···',
    mock: noMock,
    goldenTest: 's63_upcoming',
  ),
  // M25 — tạm dừng (06 Bản 5 VS-56, VS-57): lịch mock T2 Ngực + Tay sau, T3
  // Ngực, T4 Lưng, T6 Vai; tạm dừng T4 04/11 → CN 08/11/2026. S-70 là snapshot
  // XCTest (như M21). S-71 hiện lại sau bỏ đánh dấu: nội dung như Bản 4, không
  // chụp được trên simulator (TA3-15) → kiểm bằng test server (TAC5-07).
  ReviewCell(
    id: 'm25_s20',
    milestone: Milestone.m25,
    screen: 'S-20',
    state: 'tạm dừng: nút hai vạch, banner "Đến CN 08/11", ô 04 / 06 viền đứt',
    mock: noMock,
    mockFile: v5Mock('s20'),
    goldenTest: 's20_paused',
  ),
  ReviewCell(
    id: 'm25_s21',
    milestone: Milestone.m25,
    screen: 'S-21',
    state: 'ngày tạm dừng (T6 06/11, tương lai): dấu hai vạch, nút như thường',
    mock: noMock,
    mockFile: v5Mock('s21'),
    goldenTest: 's21_paused',
  ),
  ReviewCell(
    id: 'm25_s76_new',
    milestone: Milestone.m25,
    screen: 'S-76',
    state: 'chưa có khoảng: Từ ngày hôm nay, Đến ngày CN, dòng buổi rơi vào',
    mock: noMock,
    mockFile: v5Mock('s76a'),
    goldenTest: 's76_new',
  ),
  ReviewCell(
    id: 'm25_s76_active',
    milestone: Milestone.m25,
    screen: 'S-76',
    state: 'đang có khoảng: Từ ngày chỉ xem, Lưu, "Kết thúc tạm dừng"',
    mock: noMock,
    mockFile: v5Mock('s76b'),
    goldenTest: 's76_active',
  ),
  ReviewCell(
    id: 'm25_s25',
    milestone: Milestone.m25,
    screen: 'S-25',
    state: 'tuần tạm dừng: 2 / 2, dấu hai vạch',
    mock: noMock,
    mockFile: v5Mock('s25'),
    goldenTest: 's25_paused',
  ),
  ReviewCell(
    id: 'm25_s10_h7',
    milestone: Milestone.m25,
    screen: 'S-10',
    state: 'H7 tạm dừng, ngày có buổi: vòng hai vạch, banner, "Tuần 2 / 2"',
    mock: noMock,
    mockFile: v5Mock('s10-h7'),
    goldenTest: 's10_h7',
  ),
  ReviewCell(
    id: 'm25_s10_h8',
    milestone: Milestone.m25,
    screen: 'S-10',
    state: 'H8 tạm dừng, ngày nghỉ: banner, buổi tới có hai vạch',
    mock: noMock,
    mockFile: v5Mock('s10-h8'),
    goldenTest: 's10_h8',
  ),
  ReviewCell(
    id: 'm25_s70_paused',
    milestone: Milestone.m25,
    screen: 'S-70',
    state: 'tạm dừng ngày có buổi: hai vạch trước "Lưng", "2/2", chấm thẻ nổi',
    mock: noMock,
    mockFile: v5Mock('s70'),
  ),
  ReviewCell(
    id: 'm25_s70_rest_paused',
    milestone: Milestone.m25,
    screen: 'S-70',
    state: 'tạm dừng ngày nghỉ: hai vạch + "Nghỉ"',
    mock: noMock,
    mockFile: v5Mock('s70'),
  ),
  // M26 — vị trí phòng gym (06 Bản 5 VS-58): cầu vị trí giả của test (vị trí
  // thật trên simulator kiểm ở integration_test/gym_location_test.dart).
  ReviewCell(
    id: 'm26_s50',
    milestone: Milestone.m26,
    screen: 'S-50',
    state: 'dòng thứ tư "Vị trí phòng gym · Lưu 03/11 · Đang bật"',
    mock: noMock,
    mockFile: v5Mock('s50'),
    goldenTest: 's50_gym',
  ),
  ReviewCell(
    id: 'm26_s77_empty',
    milestone: Milestone.m26,
    screen: 'S-77',
    state: 'chưa lưu: ghim 64 thẻ nổi, "Lưu vị trí này" cam, công tắc mờ',
    mock: noMock,
    mockFile: v5Mock('s77a'),
    goldenTest: 's77_empty',
  ),
  ReviewCell(
    id: 'm26_s77_fetching',
    milestone: Milestone.m26,
    screen: 'S-77',
    state: 'đang lấy vị trí: vòng xoay cam + "Đang lấy vị trí…"',
    mock: noMock,
    mockFile: v5Mock('s77a'),
    goldenTest: 's77_fetching',
  ),
  ReviewCell(
    id: 'm26_s77_saved',
    milestone: Milestone.m26,
    screen: 'S-77',
    state:
        'đã lưu: ghim viền cam, "Lưu lúc 17:20 · T3 03/11/2026", công tắc, '
        'Quyền vị trí "Luôn luôn", "Xóa vị trí"',
    mock: noMock,
    mockFile: v5Mock('s77b'),
    goldenTest: 's77_saved',
  ),
];

List<ReviewCell> cellsOf(Milestone m) => [
  for (final c in reviewMatrix)
    if (c.milestone == m) c,
];

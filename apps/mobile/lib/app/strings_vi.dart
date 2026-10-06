// Toàn bộ câu chữ tiếng Việt của app (UR-12, ED-12).
//
// Câu lấy nguyên văn từ 03/04. Mỗi câu hằng có trong [S.catalog] để test so
// khớp với test/spec_strings.yaml. Câu có tham số là hàm.

abstract final class S {
  // Thanh tab (04 §6.3.1, UR-01).
  static const tabSchedule = 'Lịch tập';
  static const tabMenu = 'Thực đơn';
  static const tabToday = 'Hôm nay';
  static const tabWeight = 'Cân nặng';
  static const tabMe = 'Tôi';

  // Chung.
  static const back = 'Quay lại';
  static const understood = 'Đã hiểu';

  // S-01 Chào mừng.
  /// Tên app chưa được chốt (Q-1 trong docs/progress.md); mock S-01 ghi "[Tên app]".
  static const appName = 'Health Tracking';
  static const welcomeTagline =
      'Nhắc Bạn tập đúng lịch, gợi ý ăn gì mỗi ngày, cho Bạn thấy mình tiến bộ.';
  static const welcomeFootnote =
      'Tài khoản giúp giữ dữ liệu khi Bạn đổi điện thoại.';
  static const register = 'Đăng ký';
  static const login = 'Đăng nhập';

  // S-01a Đăng ký.
  static const registerSubtitle =
      'Tài khoản giúp Bạn lấy lại dữ liệu trên điện thoại mới.';
  static const fieldDisplayName = 'Tên hiển thị';
  static const fieldPhone = 'Số điện thoại';
  static const fieldPassword = 'Mật khẩu';
  static const fieldPasswordConfirm = 'Nhập lại mật khẩu';
  static const passwordHint = 'Ít nhất 8 ký tự';
  static const invalidPasswordConfirm = 'Mật khẩu nhập lại chưa khớp';
  static const haveAccount = 'Đã có tài khoản?';
  static const showPassword = 'Hiện mật khẩu';
  static const hidePassword = 'Ẩn mật khẩu';

  // S-01b Đăng nhập, S-01c Quên mật khẩu.
  static const noAccount = 'Chưa có tài khoản?';
  static const forgotPassword = 'Quên mật khẩu?';
  static const forgotPasswordBody =
      'Hiện app chưa hỗ trợ tự lấy lại mật khẩu. Liên hệ người quản trị app để được đặt lại mật khẩu.';
  static const forgotPasswordNote =
      'Dữ liệu của Bạn vẫn được giữ nguyên trong lúc chờ.';

  // S-02 Thông báo tham khảo (Bước 1/5).
  static const disclaimerTitle = 'Trước khi bắt đầu';

  // Thiết lập lần đầu: S-02, S-03, S-04 (04 §6.5, §6.6), nhãn "tham khảo"
  // (04 §6.13.2), hộp bỏ thay đổi (Q-2).
  /// "Bước {n}/5" (OB-1).
  static String stepOf(int step) => 'Bước $step/5';

  /// "{n} tuổi" (mock S-03).
  static String ageYears(int age) => '$age tuổi';

  /// "Thấp hơn mức duy trì khoảng {N} kcal" (S-04, S-52); [kcal] đã định dạng.
  static String belowMaintenance(String kcal) =>
      'Thấp hơn mức duy trì khoảng $kcal kcal';

  /// F02-R5; [floor] là ngưỡng an toàn đã định dạng.
  static String lowCalorieWarning(String floor) =>
      'Mức này thấp hơn ngưỡng an toàn tham khảo ($floor kcal). Thực đơn gợi ý vẫn sẽ dùng tối thiểu $floor kcal.';

  static const iUnderstand = 'Tôi đã hiểu';
  static const disclaimerPoint1 =
      'App theo dõi và gợi ý tham khảo, không chẩn đoán, không điều trị.';
  static const disclaimerPoint2 = 'Gợi ý dành cho người khỏe mạnh.';
  static const disclaimerPoint3 =
      'Không thay thế huấn luyện viên, bác sĩ hay chuyên gia dinh dưỡng.';
  static const disclaimerPoint4 = 'Gợi ý AI có thể chưa chính xác.';
  static const continueLabel = 'Tiếp tục';
  static const profileTitle = 'Thông tin của Bạn';
  static const profileSubtitle = 'Dùng để ước tính mức calo tham khảo.';
  static const fieldHeight = 'Chiều cao';
  static const fieldBirthYear = 'Năm sinh';
  static const fieldSex = 'Giới tính';
  static const sexMale = 'Nam';
  static const sexFemale = 'Nữ';
  static const fieldActivityLevel = 'Mức vận động';
  static const activitySedentary = 'Ít vận động';
  static const activitySedentaryHint = 'Ngồi nhiều, gần như không tập';
  static const activityLight = 'Vận động nhẹ';
  static const activityLightHint = 'Tập 1–3 buổi/tuần';
  static const activityModerate = 'Vận động vừa';
  static const activityModerateHint = 'Tập 3–5 buổi/tuần';
  static const activityActive = 'Vận động nhiều';
  static const activityActiveHint = 'Tập 6–7 buổi/tuần';
  static const activityVeryActive = 'Vận động rất nhiều';
  static const activityVeryActiveHint = 'Lao động nặng, hoặc tập 2 lần/ngày';
  static const fieldInitialWeight = 'Cân nặng ban đầu';
  static const goalLabel = 'Mục tiêu';
  static const goalFatLoss = 'Giảm mỡ';
  static const unitCm = 'cm';
  static const unitKg = 'kg';
  static const unitKcal = 'kcal';
  static const done = 'Xong';
  static const invalidHeight = 'Chiều cao cần từ 120 đến 230 cm';
  static const invalidBirthYear = 'App dành cho người từ 18 đến 80 tuổi';
  static const missingSex = 'Vui lòng chọn giới tính';
  static const missingActivityLevel = 'Vui lòng chọn mức vận động';
  static const invalidWeight = 'Cân nặng cần từ 30 đến 250 kg';
  static const calorieTitle = 'Mức calo mỗi ngày';
  static const calorieSubtitle = 'Dùng làm mốc cho thực đơn gợi ý.';
  static const calorieAuto = 'Tự động';
  static const calorieManual = 'Bạn tự đặt';
  static const referenceTag = 'tham khảo';
  static const howEstimated = 'Cách app ước tính';
  static const howEstimatedBody =
      'App ước tính dựa trên chiều cao, cân nặng mới nhất, tuổi, giới tính và mức vận động của Bạn, rồi trừ 500 kcal để giảm mỡ. Mức ước tính không bao giờ thấp hơn ngưỡng an toàn.';
  static const keepThisLevel = 'Giữ mức này';
  static const setOtherLevel = 'Đặt mức khác';
  static const belowSafetyFloor = 'Dưới ngưỡng an toàn';
  static const lowCalorieTitle = 'Mức calo thấp';
  static const saveAnyway = 'Vẫn lưu';
  static const editAgain = 'Sửa lại';
  static const noteRaisedToFloor =
      'Đã điều chỉnh lên ngưỡng an toàn tối thiểu.';
  static const noteMaintenanceBelowFloor =
      'Với thông số của Bạn, mức ăn an toàn tối thiểu đã gần hoặc cao hơn nhu cầu duy trì. Việc giảm mỡ nên dựa thêm vào vận động.';
  static const setCalorieTitle = 'Đặt mức calo';
  static const fieldDailyCalorie = 'Mức calo mỗi ngày';
  static const invalidManualKcal = 'Mức calo cần từ 800 đến 5.000 kcal';
  static const discardChangesTitle = 'Bỏ các thay đổi chưa lưu?';
  static const discard = 'Bỏ';
  static const keepEditing = 'Tiếp tục sửa';
  static const aboutReferenceTitle = 'Về gợi ý tham khảo';
  static const seeFull = 'Xem đầy đủ';
  static const scheduleStepTitle = 'Lịch tập trong tuần';

  // S-10 Hôm nay (đầu trang), S-50, S-56 — đồng bộ (F09-E1).
  /// "Chào {tên hiển thị}" (UR-14).
  static String greeting(String displayName) => 'Chào $displayName';
  static const syncPending = 'Chưa đồng bộ';
  static const syncDone = 'Đã đồng bộ';

  /// "Đã đồng bộ lúc {hh:mm}" (S-56).
  static String syncedAt(String time) => 'Đã đồng bộ lúc $time';
  static const syncPendingDetail = 'Chưa đồng bộ · Sẽ tự đồng bộ khi có mạng';
  static const syncLossWarning =
      'Dữ liệu chưa đồng bộ có thể mất nếu Bạn mất điện thoại.';
  static const accountAndData = 'Tài khoản và dữ liệu';
  static const syncLabel = 'Đồng bộ';
  static const save = 'Lưu';

  // Lịch tuần, lịch tháng: S-05, S-22 (trình sửa), S-20 (04 §6.8, §6.13.4).
  /// F03-V2: "Vui lòng chọn giờ tập cho {thứ}".
  static String missingTimeFor(String weekday) =>
      'Vui lòng chọn giờ tập cho $weekday';

  /// F03-V3: "Vui lòng chọn nhóm cơ cho {thứ}".
  static String missingMusclesFor(String weekday) =>
      'Vui lòng chọn nhóm cơ cho $weekday';

  /// "Tháng {m}/{yyyy}" (mock S-20).
  static String monthTitle(int month, int year) => 'Tháng $month/$year';

  /// S-20, F03-R13: "Lịch tháng {tháng sau} sẽ có từ 01/{tháng sau}".
  static String nextMonthNotice(int month) =>
      'Lịch tháng $month sẽ có từ 01/${month.toString().padLeft(2, '0')}';

  /// Thứ viết tắt ở S-20 (mock S-20-1).
  static const weekdaysShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  static const scheduleStepSubtitle = 'Chủ nhật luôn là ngày nghỉ.';
  static const saveSchedule = 'Lưu lịch tập';
  static const workoutTime = 'Giờ tập';
  static const alwaysRest = 'Luôn nghỉ';
  static const muscleChest = 'Ngực';
  static const muscleTriceps = 'Tay sau';
  static const muscleShoulders = 'Vai';
  static const muscleAbs = 'Bụng';
  static const muscleBack = 'Lưng';
  static const muscleBiceps = 'Tay trước';
  static const and = 'và';
  static const noWorkoutDay = 'Lịch tập cần ít nhất 1 ngày';
  static const rest = 'Nghỉ';
  static const overridden = 'Đã sửa riêng';
  static const timeNotSet = '--:--';
  static const previousMonth = 'Tháng trước';
  static const nextMonth = 'Tháng sau';
  static const reminderStepTitle = 'Nhắc Bạn trước giờ tập?';

  // Nhắc đi tập: S-06, S-50 (F-04).
  /// F04-R3: "Hôm nay tập {nhóm cơ} lúc {giờ}".
  static String reminderToday(String muscles, String time) =>
      'Hôm nay tập $muscles lúc $time';

  /// F04-E1: "Ngày mai tập {nhóm cơ} lúc {giờ}".
  static String reminderTomorrow(String muscles, String time) =>
      'Ngày mai tập $muscles lúc $time';

  /// Mock S-06: ví dụ lấy từ lịch Bạn vừa xếp.
  static String reminderExample(String time, String weekday) =>
      'Ví dụ từ lịch của Bạn: nhắc lúc $time $weekday. App nhắc 1 giờ trước mỗi buổi theo lịch. Bạn bật hoặc tắt được bất cứ lúc nào ở mục Tôi.';

  static const turnOnReminders = 'Bật nhắc';
  static const later = 'Để sau';
  static const remindersRow = 'Nhắc đi tập';
  static const remindersHint = '1 giờ trước giờ tập';
  static const notificationsBlocked =
      'iPhone đang chặn thông báo của app. Mở Cài đặt để cho phép.';
  static const openSettings = 'Mở Cài đặt';
  static const remindersTurnedOff = 'Đã tắt nhắc đi tập';
  static const remindersTurnedOn = 'Đã bật nhắc đi tập';

  // Hôm nay S-10 (04 §6.7), đánh dấu S-23, nhãn trạng thái buổi tập
  // (04 §6.13.3), F-05.
  static const todaySessionTitle = 'Buổi tập hôm nay';
  static const statusUpcoming = 'Sắp tới';
  static const statusAwaiting = 'Chờ đánh dấu';
  static const sessionDone = 'Đã tập';
  static const sessionSkipped = 'Không tập';
  static const statusAutoSkipped = 'Không tập · tự động';
  static const statusLocked = 'Đã khóa';
  static const todayRest = 'Hôm nay nghỉ';
  static const sundayRest = 'Chủ nhật luôn nghỉ';
  static const markedSkipped = 'Đã ghi: không tập';
  static const editMuscles = 'Sửa nhóm cơ';
  static const undo = 'Hoàn tác';
  static const edit = 'Sửa';
  static const unmarkedTitle = 'Buổi chưa đánh dấu';
  static const progressCardTitle = 'Tiến độ tuần · T2–T7';
  static const menuCardTitle = 'Thực đơn hôm nay';
  static const menuTargetPrefix = 'Theo mức';
  static const actualMusclesLabel = 'Nhóm cơ đã tập';
  static const missingActualMuscles = 'Vui lòng chọn ít nhất 1 nhóm cơ';
  static const lockedNote = 'Chỉ sửa được trong 7 ngày';

  /// F05-E1, UX-AC6: "Đánh dấu được từ {giờ tập}".
  static String markableFrom(String time) => 'Đánh dấu được từ $time';

  /// 04 §6.7.1: "Buổi tới: {thứ} · {nhóm cơ} · {giờ}".
  static String nextSession(String weekday, String muscles, String time) =>
      'Buổi tới: $weekday · $muscles · $time';

  /// UA-08: "Đã ghi: tập {nhóm cơ}".
  static String markedDone(String muscles) => 'Đã ghi: tập $muscles';

  /// Mock S-23: "Lịch: {nhóm cơ} · {giờ}".
  static String plannedLine(String muscles, String time) =>
      'Lịch: $muscles · $time';

  // Buổi tập thêm S-24 (04 §6.7.1, S-24, §6.13.3), F05-R7 → R12.
  static const logExtraSession = 'Đã tập ngoài lịch? Ghi buổi tập thêm';
  static const extraSession = 'Buổi tập thêm';
  static const extraNotCounted = 'Không tính vào kế hoạch tuần.';
  static const deleteExtraSession = 'Xóa buổi tập thêm';
  static const delete = 'Xóa';
  static const cancel = 'Hủy';

  /// 04 §6.7.1: "Buổi tập thêm · {nhóm cơ}".
  static String extraSessionLine(String muscles) => 'Buổi tập thêm · $muscles';

  /// Mock S-24: "Buổi tập thêm · Thứ 5, 08/10 · Hôm nay".
  static String extraSessionTitle(String weekdayDate, {required bool today}) =>
      'Buổi tập thêm · $weekdayDate${today ? ' · $tabToday' : ''}';

  /// Hộp xác nhận xóa (NAV-6), theo mẫu "Cho nghỉ {thứ}, {dd/mm}?" của S-21.
  static String deleteExtraConfirm(String weekdayDate) =>
      'Xóa buổi tập thêm $weekdayDate?';

  /// Mock S-25: "Nghỉ · Bụng".
  static String restWithExtra(String muscles) => '$rest · $muscles';

  // Tiến độ tuần (04 §6.7.3, S-25, S-20), F-06.
  static const weekProgressTitle = 'Tiến độ tuần';
  static const noPlannedSessions = 'Tuần này không có buổi tập theo lịch';
  static const previousWeek = 'Tuần trước';
  static const nextWeek = 'Tuần sau';

  /// F-06, 04 §6.7.3: "Đã tập X/Y buổi theo lịch".
  static String progressLine(int done, int planned) =>
      'Đã tập $done/$planned buổi theo lịch';

  /// F-06: "+Z buổi thêm".
  static String extraCount(int extra) => '+$extra buổi thêm';

  /// 04 S-20: tiêu đề tuần "… · Đã tập 2/3".
  static String weekDone(int done, int planned) => 'Đã tập $done/$planned';

  // Sửa riêng S-21, lịch tuần S-22, chia lại (04 S-20 → S-22), F03-R7 → R10.
  static const weeklySchedule = 'Lịch tuần';
  static const weeklyEditHint =
      'Thay đổi áp dụng từ tháng sau, hoặc bấm Chia lại để áp dụng ngay.';
  static const templateSaved = 'Đã lưu lịch tuần';
  static const templateChangedBanner =
      'Lịch tuần đã thay đổi. Bấm Chia lại để áp dụng cho tháng này.';
  static const redistribute = 'Chia lại';
  static const redistributeTitle = 'Chia lại lịch?';
  static const redistributeBody = 'Áp dụng lịch mới từ hôm nay đến cuối tháng?';
  static const redistributeNote = 'Các ngày Bạn đã sửa riêng được giữ nguyên.';
  static const fromTemplate = 'Theo lịch tuần';
  static const changeTime = 'Đổi giờ';
  static const changeMuscles = 'Đổi nhóm cơ';
  static const restThisDay = 'Cho nghỉ ngày này';
  static const scheduleThisDay = 'Lên lịch tập ngày này';
  static const scheduleToday = 'Lên lịch tập hôm nay';
  static const countsInPlan = 'Tính vào kế hoạch tuần.';
  static const revertToTemplate = 'Trả về theo lịch tuần';
  static const revertConfirmTitle = 'Trả về theo lịch tuần?';
  static const revert = 'Trả về';
  static const giveRest = 'Cho nghỉ';
  static const onlyThisDay = 'Chỉ thay đổi ngày này. Lịch tuần giữ nguyên.';
  static const noReminderUnderHour =
      'Còn chưa đến 1 giờ nên sẽ không có nhắc cho buổi này.';
  static const extraBlocksSchedule =
      'Hôm nay đã có buổi tập thêm nên không lên lịch tập được.';
  static const editExtraSession = 'Sửa buổi tập thêm';
  static const markSession = 'Đánh dấu buổi tập';
  static const editTodaySession = 'Sửa buổi hôm nay';
  static const missingTimeOrMuscles = 'Vui lòng chọn giờ tập và nhóm cơ';
  static const muscleGroups = 'Nhóm cơ';

  /// 04 S-21: "Cho nghỉ {thứ}, {dd/mm}? Nhắc của ngày này sẽ được hủy."
  static String restConfirm(String weekdayDate) =>
      'Cho nghỉ $weekdayDate? Nhắc của ngày này sẽ được hủy.';

  /// 04 S-21: "Đã sửa riêng {thứ} {dd/mm}".
  static String overriddenToast(String weekday, String dayMonth) =>
      'Đã sửa riêng $weekday $dayMonth';

  /// 03 F03-R8: "Đã chia lại lịch từ {ngày} đến {ngày}. Giữ nguyên {N} ngày
  /// Bạn đã sửa riêng." Không có ngày sửa riêng thì bỏ câu sau.
  static String redistributed(String from, String to, int kept) =>
      'Đã chia lại lịch từ $from đến $to.'
      '${kept > 0 ? ' Giữ nguyên $kept ngày Bạn đã sửa riêng.' : ''}';

  /// Mock S-21-2: "Thứ 5, 08/10 · Hôm nay".
  static String dayTitle(String weekdayDate, {required bool today}) =>
      '$weekdayDate${today ? ' · $tabToday' : ''}';

  // Định dạng (UR-10).
  static const currencySuffix = 'đ';
  static const weekdays = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật',
  ];

  // Lỗi từ server (05 §6.8.3) và câu không có mạng của từng màn hình.
  static const errorPhoneTaken = 'Số điện thoại này đã có tài khoản.';
  static const errorInvalidCredentials =
      'Số điện thoại hoặc mật khẩu chưa đúng.';
  static const offlineRegister = 'Cần kết nối internet để đăng ký.';
  static const offlineLogin = 'Cần kết nối internet để đăng nhập.';
  static const offlineMenu = 'Cần kết nối internet để gợi ý thực đơn.';
  static const menuQuotaExhausted = 'Bạn đã dùng hết 3 lượt hôm nay.';
  static const menuInvalidOutput =
      'Thực đơn vừa tạo chưa đạt yêu cầu. Thử lại.';
  static const menuProviderError = 'Chưa tạo được thực đơn. Thử lại.';
  static const menuGenerating = 'Đang lên thực đơn…';

  /// F08-E2: "Gợi ý AI tạm dừng đến ngày 1/{tháng sau} vì …".
  static String budgetPaused(int nextMonth) =>
      'Gợi ý AI tạm dừng đến ngày 1/$nextMonth vì đã dùng hết ngân sách tháng này.';

  // Kiểm tra ô nhập ở S-01a (UA-19, UA-20, UA-21).
  static const invalidDisplayName = 'Tên cần từ 1 đến 30 ký tự';
  static const invalidPhone = 'Số điện thoại chưa đúng';
  static const invalidPassword = 'Mật khẩu cần ít nhất 8 ký tự';

  /// Mọi câu hằng, dùng cho test so khớp nguyên văn (ED-12).
  static const Map<String, String> catalog = {
    'back': back,
    'understood': understood,
    'appName': appName,
    'welcomeTagline': welcomeTagline,
    'welcomeFootnote': welcomeFootnote,
    'register': register,
    'login': login,
    'registerSubtitle': registerSubtitle,
    'fieldDisplayName': fieldDisplayName,
    'fieldPhone': fieldPhone,
    'fieldPassword': fieldPassword,
    'fieldPasswordConfirm': fieldPasswordConfirm,
    'passwordHint': passwordHint,
    'invalidPasswordConfirm': invalidPasswordConfirm,
    'haveAccount': haveAccount,
    'showPassword': showPassword,
    'hidePassword': hidePassword,
    'noAccount': noAccount,
    'forgotPassword': forgotPassword,
    'forgotPasswordBody': forgotPasswordBody,
    'forgotPasswordNote': forgotPasswordNote,
    'disclaimerTitle': disclaimerTitle,
    'syncPending': syncPending,
    'turnOnReminders': turnOnReminders,
    'later': later,
    'remindersRow': remindersRow,
    'remindersHint': remindersHint,
    'notificationsBlocked': notificationsBlocked,
    'openSettings': openSettings,
    'remindersTurnedOff': remindersTurnedOff,
    'remindersTurnedOn': remindersTurnedOn,
    'scheduleStepSubtitle': scheduleStepSubtitle,
    'saveSchedule': saveSchedule,
    'workoutTime': workoutTime,
    'alwaysRest': alwaysRest,
    'muscleChest': muscleChest,
    'muscleTriceps': muscleTriceps,
    'muscleShoulders': muscleShoulders,
    'muscleAbs': muscleAbs,
    'muscleBack': muscleBack,
    'muscleBiceps': muscleBiceps,
    'and': and,
    'noWorkoutDay': noWorkoutDay,
    'rest': rest,
    'overridden': overridden,
    'timeNotSet': timeNotSet,
    'previousMonth': previousMonth,
    'nextMonth': nextMonth,
    'reminderStepTitle': reminderStepTitle,
    'iUnderstand': iUnderstand,
    'disclaimerPoint1': disclaimerPoint1,
    'disclaimerPoint2': disclaimerPoint2,
    'disclaimerPoint3': disclaimerPoint3,
    'disclaimerPoint4': disclaimerPoint4,
    'continueLabel': continueLabel,
    'profileTitle': profileTitle,
    'profileSubtitle': profileSubtitle,
    'fieldHeight': fieldHeight,
    'fieldBirthYear': fieldBirthYear,
    'fieldSex': fieldSex,
    'sexMale': sexMale,
    'sexFemale': sexFemale,
    'fieldActivityLevel': fieldActivityLevel,
    'activitySedentary': activitySedentary,
    'activitySedentaryHint': activitySedentaryHint,
    'activityLight': activityLight,
    'activityLightHint': activityLightHint,
    'activityModerate': activityModerate,
    'activityModerateHint': activityModerateHint,
    'activityActive': activityActive,
    'activityActiveHint': activityActiveHint,
    'activityVeryActive': activityVeryActive,
    'activityVeryActiveHint': activityVeryActiveHint,
    'fieldInitialWeight': fieldInitialWeight,
    'goalLabel': goalLabel,
    'goalFatLoss': goalFatLoss,
    'unitCm': unitCm,
    'unitKg': unitKg,
    'unitKcal': unitKcal,
    'done': done,
    'invalidHeight': invalidHeight,
    'invalidBirthYear': invalidBirthYear,
    'missingSex': missingSex,
    'missingActivityLevel': missingActivityLevel,
    'invalidWeight': invalidWeight,
    'calorieTitle': calorieTitle,
    'calorieSubtitle': calorieSubtitle,
    'calorieAuto': calorieAuto,
    'calorieManual': calorieManual,
    'referenceTag': referenceTag,
    'howEstimated': howEstimated,
    'howEstimatedBody': howEstimatedBody,
    'keepThisLevel': keepThisLevel,
    'setOtherLevel': setOtherLevel,
    'belowSafetyFloor': belowSafetyFloor,
    'lowCalorieTitle': lowCalorieTitle,
    'saveAnyway': saveAnyway,
    'editAgain': editAgain,
    'noteRaisedToFloor': noteRaisedToFloor,
    'noteMaintenanceBelowFloor': noteMaintenanceBelowFloor,
    'setCalorieTitle': setCalorieTitle,
    'fieldDailyCalorie': fieldDailyCalorie,
    'invalidManualKcal': invalidManualKcal,
    'discardChangesTitle': discardChangesTitle,
    'discard': discard,
    'keepEditing': keepEditing,
    'aboutReferenceTitle': aboutReferenceTitle,
    'seeFull': seeFull,
    'scheduleStepTitle': scheduleStepTitle,
    'syncDone': syncDone,
    'syncPendingDetail': syncPendingDetail,
    'syncLossWarning': syncLossWarning,
    'accountAndData': accountAndData,
    'syncLabel': syncLabel,
    'save': save,
    'tabSchedule': tabSchedule,
    'tabMenu': tabMenu,
    'tabToday': tabToday,
    'tabWeight': tabWeight,
    'tabMe': tabMe,
    'errorPhoneTaken': errorPhoneTaken,
    'errorInvalidCredentials': errorInvalidCredentials,
    'offlineRegister': offlineRegister,
    'offlineLogin': offlineLogin,
    'offlineMenu': offlineMenu,
    'menuQuotaExhausted': menuQuotaExhausted,
    'menuInvalidOutput': menuInvalidOutput,
    'menuProviderError': menuProviderError,
    'menuGenerating': menuGenerating,
    'invalidDisplayName': invalidDisplayName,
    'invalidPhone': invalidPhone,
    'invalidPassword': invalidPassword,
    'todaySessionTitle': todaySessionTitle,
    'statusUpcoming': statusUpcoming,
    'statusAwaiting': statusAwaiting,
    'sessionDone': sessionDone,
    'sessionSkipped': sessionSkipped,
    'statusAutoSkipped': statusAutoSkipped,
    'statusLocked': statusLocked,
    'todayRest': todayRest,
    'sundayRest': sundayRest,
    'markedSkipped': markedSkipped,
    'editMuscles': editMuscles,
    'undo': undo,
    'edit': edit,
    'unmarkedTitle': unmarkedTitle,
    'progressCardTitle': progressCardTitle,
    'menuCardTitle': menuCardTitle,
    'menuTargetPrefix': menuTargetPrefix,
    'actualMusclesLabel': actualMusclesLabel,
    'missingActualMuscles': missingActualMuscles,
    'lockedNote': lockedNote,
    'logExtraSession': logExtraSession,
    'extraSession': extraSession,
    'extraNotCounted': extraNotCounted,
    'deleteExtraSession': deleteExtraSession,
    'delete': delete,
    'cancel': cancel,
    'weekProgressTitle': weekProgressTitle,
    'noPlannedSessions': noPlannedSessions,
    'previousWeek': previousWeek,
    'nextWeek': nextWeek,
    'weeklySchedule': weeklySchedule,
    'weeklyEditHint': weeklyEditHint,
    'templateSaved': templateSaved,
    'templateChangedBanner': templateChangedBanner,
    'redistribute': redistribute,
    'redistributeTitle': redistributeTitle,
    'redistributeBody': redistributeBody,
    'redistributeNote': redistributeNote,
    'fromTemplate': fromTemplate,
    'changeTime': changeTime,
    'changeMuscles': changeMuscles,
    'restThisDay': restThisDay,
    'scheduleThisDay': scheduleThisDay,
    'scheduleToday': scheduleToday,
    'countsInPlan': countsInPlan,
    'revertToTemplate': revertToTemplate,
    'revertConfirmTitle': revertConfirmTitle,
    'revert': revert,
    'giveRest': giveRest,
    'onlyThisDay': onlyThisDay,
    'noReminderUnderHour': noReminderUnderHour,
    'extraBlocksSchedule': extraBlocksSchedule,
    'editExtraSession': editExtraSession,
    'markSession': markSession,
    'editTodaySession': editTodaySession,
    'missingTimeOrMuscles': missingTimeOrMuscles,
    'muscleGroups': muscleGroups,
  };
}

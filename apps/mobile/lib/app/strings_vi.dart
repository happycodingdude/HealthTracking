// Toàn bộ câu chữ tiếng Việt của app (UR-12, ED-12).
//
// Câu lấy nguyên văn từ 03/04. Mỗi câu hằng có trong [S.catalog] để test so
// khớp với test/spec_strings.yaml. Câu có tham số là hàm.

abstract final class S {
  // Thanh tab (04 §6.3.1, UR-01). Bản 2: tab thứ nhất "Tập luyện" (UR2-02).
  static const tabTraining = 'Tập luyện';
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

  /// Đơn vị mức tạ của bài với máy (BR2-24, sửa 13/10/2026).
  static const unitPlates = 'thanh';
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

  // Chưa có lịch (04 Bản 2 UA2-03 → UA2-05, UA2-15, S-06, S-10, S-20, S-50).
  static const noScheduleTitle = 'Chưa có lịch tập';
  static const noScheduleToday =
      'Buổi tập và tiến độ tuần sẽ hiện khi Bạn xếp lịch tuần.';
  static const noScheduleInvite =
      'Chọn các ngày Bạn muốn tập trong tuần. App sẽ xếp lịch từ hôm nay đến cuối tháng.';
  static const arrangeWeekly = 'Xếp lịch tuần';
  static const reminderGenericExample =
      'Ví dụ: lịch có buổi Ngực lúc 18:00 thứ 2, thì 17:00 app sẽ nhắc: Hôm nay tập ngực lúc 18:00.';
  static const remindersStartWhenScheduled =
      'Nhắc bắt đầu hoạt động khi Bạn xếp lịch tuần.';
  static const remindersHintNoSchedule = 'Sẽ nhắc khi Bạn đã xếp lịch tuần';
  static const notificationsBlocked =
      'iPhone đang chặn thông báo của app. Mở Cài đặt để cho phép.';
  static const openSettings = 'Mở Cài đặt';
  static const remindersTurnedOff = 'Đã tắt nhắc đi tập';
  static const remindersTurnedOn = 'Đã bật nhắc đi tập';

  // Hôm nay S-10 (04 §6.7, 04 Bản 2 §6.6), nhãn trạng thái buổi tập
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

  // Buổi tập thêm S-24 (04 §6.7.1, S-24, §6.13.3), F05-R7 → R12.
  static const logExtraSession = 'Đã tập ngoài lịch? Ghi buổi tập thêm';
  static const extraSession = 'Buổi tập thêm';
  static const extraNotCounted = 'Không tính vào kế hoạch tuần.';
  static const delete = 'Xóa';
  static const cancel = 'Hủy';

  /// 04 §6.7.1: "Buổi tập thêm · {nhóm cơ}".
  static String extraSessionLine(String muscles) => 'Buổi tập thêm · $muscles';

  /// 04 Bản 2 S-24: "Buổi tập thêm · {thứ} {dd/mm}".
  static String extraSheetTitle(String weekday, String dayMonth) =>
      'Buổi tập thêm · $weekday $dayMonth';

  /// 04 Bản 2 S-24: "Đã ghi buổi tập thêm: {nhóm cơ}".
  static String extraLogged(String muscles) => 'Đã ghi buổi tập thêm: $muscles';

  // Chốt buổi (04 Bản 2 S-65, §6.6.1, S-21; UA2-02), F05-R23, F05-R33.
  static const lockConfirmLine1 = 'Sau khi lưu, buổi này không sửa được nữa.';
  static const lockConfirmLine2 =
      'Mức tạ của buổi vẫn ghi được đến hết hôm nay.';
  static const extraConfirmTitle = 'Lưu buổi tập thêm?';
  static const lockedOnSave = 'Đã chốt khi lưu';
  static const changeToDone = 'Đổi sang Đã tập';

  /// 04 Bản 2 S-65: "Đã tập {nhóm cơ}?".
  static String doneConfirmTitle(String muscles) => 'Đã tập $muscles?';

  /// 04 Bản 2 §6.6.1, S-21: "Đã tập · {nhóm cơ}".
  static String doneLine(String muscles) => 'Đã tập · $muscles';

  /// 04 Bản 2 §6.6.1: "Đổi sang Đã tập được đến hết {dd/mm}".
  static String changeToDoneUntil(String dayMonth) =>
      'Đổi sang Đã tập được đến hết $dayMonth';

  /// 04 Bản 2 S-21: "Đổi được đến hết {dd/mm}".
  static String changeableUntil(String dayMonth) =>
      'Đổi được đến hết $dayMonth';

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

  // Cân nặng S-40, S-41 (04 §6.10), F-07.
  static const logThisWeek = 'Ghi cân tuần này';
  static const trendTitle = 'Xu hướng';
  static const lastEightWeeks = '8 tuần gần nhất';
  static const firstWeightHint = 'Ghi thêm tuần sau để thấy xu hướng';
  static const notLogged = 'Chưa ghi';
  static const add = 'Thêm';
  static const fieldWeight = 'Cân nặng';
  static const replace = 'Thay';
  static const deleteWeight = 'Xóa số cân này';
  static const keepOneWeight = 'Cần giữ ít nhất 1 số cân để tính mức calo.';

  /// Mock S-40: "Mới nhất · Tuần 05/10 – 11/10".
  static String latestWeek(String range) => 'Mới nhất · Tuần $range';

  /// 04 S-40: "Tuần 05/10 – 11/10".
  static String weekLabel(String range) => 'Tuần $range';

  /// F07-R7: "↓ 0,4 kg so với lần trước" ([change] đã có mũi tên).
  static String vsPrevious(String change) => '$change so với lần trước';

  /// F07-R7: "↓ 2,5 kg so với ban đầu".
  static String vsInitial(String change) => '$change so với ban đầu';

  /// 04 S-41: "Cân nặng tuần {dd/mm} – {dd/mm}".
  static String weightSheetTitle(String range) => 'Cân nặng tuần $range';

  /// 04 S-41: "Tuần này đã ghi {X} kg".
  static String weekAlreadyLogged(String kg) => 'Tuần này đã ghi $kg';

  /// F07-R1: "Tuần này đã ghi {X} kg. Thay bằng số mới?"
  static String replaceWeight(String kg) =>
      'Tuần này đã ghi $kg. Thay bằng số mới?';

  /// F07-V2: "Số này chênh {N} kg so với lần trước. Bạn chắc chắn chứ?"
  static String bigWeightChange(String kg) =>
      'Số này chênh $kg so với lần trước. Bạn chắc chắn chứ?';

  /// 04 S-41: "Xóa số cân tuần {dd/mm}?"
  static String deleteWeightConfirm(String dayMonth) =>
      'Xóa số cân tuần $dayMonth?';

  /// 04 S-41: "Đã lưu {X} kg".
  static String weightSaved(String kg) => 'Đã lưu $kg';

  // Hồ sơ S-51, mức calo S-52, đề xuất S-53, dòng S-50 (VS-11), F01, F02.
  static const bodyProfile = 'Hồ sơ cơ thể';
  static const calorieLevel = 'Mức calo';
  static const profileSaved = 'Đã lưu hồ sơ';
  static const currentWeight = 'Cân nặng hiện tại';
  static const logInWeightTab = 'Ghi ở tab Cân nặng';
  static const updateCalorieTitle = 'Cập nhật mức calo?';
  static const keepCurrent = 'Giữ nguyên';

  /// 04 S-50: "175 cm · 30 tuổi · Nam".
  static String profileSummary(int heightCm, int age, String sex) =>
      '$heightCm cm · $age tuổi · $sex';

  /// 04 S-50: "2.210 kcal · Tự động".
  static String calorieSummary(String kcal, String mode) => '$kcal · $mode';

  /// F02-R8: "Mức calo đã cập nhật từ X thành Y kcal."
  static String calorieUpdated(String from, String to) =>
      'Mức calo đã cập nhật từ $from thành $to kcal.';

  /// F02-R9: "Theo cân nặng mới, mức ước tính là {Y} kcal. Bạn muốn dùng con
  /// số này không?"; do sửa hồ sơ, sang năm mới: "Theo thông tin mới, …"
  /// (04 S-53).
  static String calorieProposal(String kcal, {required bool byWeight}) =>
      '${byWeight ? 'Theo cân nặng mới' : 'Theo thông tin mới'}, mức ước tính '
      'là $kcal. Bạn muốn dùng con số này không?';

  /// 04 S-53: "Hiện tại Bạn đang dùng {X} kcal."
  static String currentlyUsing(String kcal) => 'Hiện tại Bạn đang dùng $kcal.';

  /// 04 S-52, S-53: "Dùng {Y} kcal".
  static String useKcal(String kcal) => 'Dùng $kcal';

  /// 04 S-52, F02-AC6: "Dùng lại ước tính của app ({Y} kcal)".
  static String useAppEstimate(String kcal) =>
      'Dùng lại ước tính của app ($kcal)';

  // Thực đơn AI S-30, thẻ thực đơn ở Hôm nay (VS-12), F-08.
  static const menuEmptyTitle = 'Hôm nay ăn gì?';
  static const menuEmptyBody =
      'App gợi ý thực đơn cả ngày theo mức calo của Bạn, ưu tiên món Việt dễ nấu.';
  static const generateMenu = 'Gợi ý thực đơn hôm nay';
  static const retry = 'Thử lại';
  static const menuEstimateNote = 'Calo món ăn là ước lượng.';
  static const menuTotal = 'Tổng';
  static const calorieChangedRegenerate =
      'Mức calo đã thay đổi. Bạn có thể gợi ý lại.';
  static const regenerateTitle = 'Gợi ý thực đơn mới?';
  static const regenerate = 'Gợi ý lại';
  static const mealBreakfast = 'Sáng';
  static const mealLunch = 'Trưa';
  static const mealDinner = 'Tối';
  static const mealMorningSnack = 'Bữa phụ sáng';
  static const mealAfternoonSnack = 'Bữa phụ chiều';

  /// 04 S-30: "Còn {N} lượt hôm nay".
  static String remainingToday(int n) => 'Còn $n lượt hôm nay';

  /// 04 S-30: "Gợi ý lại (còn {N} lượt)".
  static String regenerateWithRemaining(int n) => 'Gợi ý lại (còn $n lượt)';

  /// UA-10: "Thực đơn hiện tại sẽ được thay bằng thực đơn mới. Còn {N} lượt
  /// hôm nay."
  static String regenerateBody(int n) =>
      'Thực đơn hiện tại sẽ được thay bằng thực đơn mới. Còn $n lượt hôm nay.';

  /// F08-R9: "Thực đơn dùng mức an toàn tối thiểu {X} kcal."
  static String menuSafetyFloor(String kcal) =>
      'Thực đơn dùng mức an toàn tối thiểu $kcal.';

  /// Mock S-30-1: "Thứ 4, 07/10 · Theo mức 2.090 kcal".
  static String menuDateLine(String date, String kcal) =>
      '$date · $menuTargetPrefix $kcal';

  // Ngân sách AI S-54, dòng S-50, hộp báo 80% (VS-13), F-11.
  static const aiBudget = 'Ngân sách AI';
  static const budgetExplain =
      'Mỗi lần tạo thực đơn đều tốn một ít chi phí. Khi chạm mức trần, gợi ý '
      'AI tạm dừng đến tháng sau. Phần theo dõi vẫn hoạt động bình thường.';
  static const budgetWarning80 = 'Bạn đã dùng 80% ngân sách AI tháng này.';
  static const seeDetails = 'Xem chi tiết';

  /// 04 S-50: "12.500đ / 50.000đ".
  static String budgetSummary(String used, String cap) => '$used / $cap';

  /// Mock S-54-1: "trên 50.000đ của tháng 10".
  static String budgetOfMonth(String cap, int month) =>
      'trên $cap của tháng $month';

  /// 04 S-54: phần trăm đã dùng (F11-R6).
  static String percent(int value) => '$value%';

  /// 04 S-54: "Đặt lại vào 01/{tháng sau}" (mock S-54-1 "Đặt lại vào 01/11").
  static String budgetResets(String date) => 'Đặt lại vào $date';

  // Khôi phục dữ liệu S-07 (VS-14), F-09.
  static const restoreTitle = 'Đang khôi phục dữ liệu của Bạn…';
  static const restoreSubtitle =
      'Hồ sơ, lịch tập, buổi tập, cân nặng và cài đặt';
  static const restoreFailed = 'Chưa khôi phục xong vì mất kết nối. Thử lại.';
  static const restored = 'Đã khôi phục dữ liệu';

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
  // Tab Tập luyện: thanh chọn mục (04 Bản 2 §6.3.2).
  static const sectionSchedule = 'Lịch';
  static const sectionLibrary = 'Bài tập';
  static const sectionProgress = 'Tiến bộ';

  // 16 vùng cơ (03 Bản 2 §6.10).
  static const regionChestUpper = 'Ngực trên';
  static const regionChestMid = 'Ngực giữa';
  static const regionChestLower = 'Ngực dưới';
  static const regionLats = 'Lưng xô';
  static const regionBackMid = 'Lưng giữa';
  static const regionBackLower = 'Lưng dưới';
  static const regionDeltFront = 'Vai trước';
  static const regionDeltSide = 'Vai giữa';
  static const regionDeltRear = 'Vai sau';
  static const regionBiceps = 'Bắp tay';
  static const regionBrachialisForearm = 'Cơ cánh tay và cẳng tay';
  static const regionTricepsLong = 'Đầu dài';
  static const regionTricepsLateralMedial = 'Đầu ngoài và đầu trong';
  static const regionAbsLower = 'Bụng dưới';
  static const regionAbsMid = 'Bụng giữa';
  static const regionObliques = 'Hai bên';

  // Nhãn dụng cụ (04 Bản 2 §6.10).
  static const equipmentMachine = 'Máy';
  static const equipmentFreeWeight = 'Tạ';
  static const equipmentBodyweight = 'Không dụng cụ';

  // S-66 Thư viện, S-67 Chi tiết bài (04 Bản 2 §6.8, §6.12).
  static const libraryFootnote =
      'Thư viện gồm các bài và video Bạn đã duyệt. Không cần mạng, trừ video.';
  static const backLibrary = 'Thư viện';
  static const backSession = 'Buổi tập';
  static const backProgress = 'Tiến bộ';
  static const mainRegion = 'Vùng cơ chịu tác động chính';
  static const howTo = 'Cách tập';
  static const safetyNotes = 'Lưu ý an toàn';
  static const exerciseGuideNote =
      'Hướng dẫn tham khảo cho người khỏe mạnh, không thay huấn luyện viên.';
  static const notInLibrary = 'Không còn trong thư viện';
  static const videoLoading = 'Đang tải video…';
  static const videoUnavailable = 'Video không khả dụng';
  static const videoOffline = 'Cần kết nối internet để xem video.';
  static const videoLoadFailed =
      'Không tải được video. Kiểm tra kết nối rồi thử lại.';

  /// Nhãn VoiceOver của nút phát video (giả định câu chữ, chờ Bạn xem).
  static const playVideo = 'Phát video';

  // S-63 Buổi tập, S-64 Ghi mức tạ, khu mức tạ của S-67, phần bài tập ở
  // S-10, S-21 (04 Bản 2 §6.6.1, S-21, S-63, S-64, S-67, §6.12; 03 Bản 2
  // F21-V1 → V4, F21-R8, F21-R12, F05-R28).
  static const viewExercises = 'Xem bài tập';
  static const viewExercisesAndLog = 'Xem bài tập · Ghi mức tạ';
  static const logLift = 'Ghi mức tạ';
  static const logLiftShort = 'Ghi';
  static const extraSaved = 'Đã lưu';
  static const readOnlyFuture = 'Chỉ xem · Buổi chưa đến';
  static const readOnlyLocked = 'Chỉ xem · Mức tạ của buổi này đã khóa';
  static const readOnlyPastExtra =
      'Chỉ xem · Buổi tập thêm cho ngày đã qua không ghi mức tạ';
  static const liftStart = 'Bắt đầu';
  static const liftEnd = 'Kết thúc';
  static const liftStepHint = 'Bước 0,5 kg · chạm vào số để gõ';
  static const liftStepHintPlates = 'Bước 1 thanh · chạm vào số để gõ';
  static const liftFirstTime = 'Lần ghi đầu tiên của bài này';
  static const deleteLift = 'Xóa mức tạ';
  static const deleteLiftConfirm = 'Xóa mức tạ của bài này?';
  static const liftDeleted = 'Đã xóa mức tạ';
  static const liftLockedAtMidnight = 'Mức tạ của buổi này đã khóa lúc 00:00.';
  static const liftMissing = 'Vui lòng nhập cả mức tạ bắt đầu và kết thúc';
  static const liftOutOfRange = 'Mức tạ cần từ 0,5 đến 300 kg';
  static const liftNotStep = 'Mức tạ nhập theo bước 0,5 kg';
  static const liftPlatesOutOfRange = 'Số thanh cần từ 1 đến 30';
  static const liftPlatesNotStep = 'Số thanh không có số lẻ';
  static const liftNotNumber = 'Mức tạ chưa đúng';

  /// Nhãn VoiceOver của nút − / + (giả định câu chữ, chờ Bạn xem).
  static const liftDecrease = 'Giảm 0,5 kg';
  static const liftIncrease = 'Tăng 0,5 kg';
  static const liftDecreasePlates = 'Giảm 1 thanh';
  static const liftIncreasePlates = 'Tăng 1 thanh';

  /// "Buổi tập · Ngực và Tay sau".
  static String sessionTitle(String muscles) => 'Buổi tập · $muscles';

  /// "Buổi tập thêm · Vai và Bụng".
  static String extraSessionTitle(String muscles) => 'Buổi tập thêm · $muscles';

  /// F20-E3, F21-AC1.
  static String liftOpensAt(String time) => 'Ghi mức tạ được từ $time';

  /// Thanh đáy S-63.
  static String liftLoggedOf(int n, int total) => 'Đã ghi mức tạ $n/$total bài';

  /// Thẻ buổi tập ở Hôm nay (UA2-08).
  static String liftLoggedCount(int n) => 'Đã ghi mức tạ $n bài';

  /// "12 → 14 kg", "7 → 8 thanh" ([unit] là [unitKg] hoặc [unitPlates]).
  static String liftValue(String start, String end, String unit) =>
      '$start → $end $unit';
  static String liftSaved(String start, String end, String unit) =>
      'Đã lưu $start → $end $unit';
  static String liftPrevious(
    String date,
    String start,
    String end,
    String unit,
  ) => 'Buổi trước ($date): $start → $end $unit';
  static String liftThisSession(String start, String end, String unit) =>
      'Buổi này: $start → $end $unit';
  static String liftLatest(
    String date,
    String start,
    String end,
    String unit,
  ) => 'Gần nhất ($date): $start → $end $unit';

  /// F21-R8 (nguyên văn `03`); {n} theo bước của đơn vị.
  static String liftEndLower(String n, String unit) =>
      'Mức tạ kết thúc thấp hơn buổi trước $n $unit. Bạn kiểm tra lại con số nhé.';
  static String liftEndMuchHigher(String n, String unit) =>
      'Mức tạ kết thúc cao hơn buổi trước $n $unit. Bạn kiểm tra lại con số, và nhớ tập trong sức mình nhé.';

  /// F05-R28.
  static String liftLogsExist(int n) => 'Buổi này đã có mức tạ của $n bài.';

  // S-68 Tiến bộ mức tạ, trạng thái trống (04 Bản 2 S-68, 03 Bản 2 F23-R4).
  static const progressEmptyTitle = 'Chưa có mức tạ nào';
  static const progressEmptyBody =
      'Chưa có mức tạ nào. Ghi mức tạ trong buổi tập để theo dõi tiến bộ.';

  // S-68 danh sách, S-69 Biểu đồ mức tạ (04 Bản 2 S-68, S-69, §6.12, §6.13;
  // 03 Bản 2 F22-E1).
  static const progressHint =
      'Mức tạ gần nhất của từng bài · bài tập gần nhất lên đầu';
  static const viewExercise = 'Xem bài';
  static const viewChart = 'Xem biểu đồ';
  static const chartLegend = '○ Bắt đầu · ● Kết thúc';
  static const chartMonthEmpty = 'Chưa có mức tạ trong tháng này';

  /// Tiêu đề danh sách dưới biểu đồ (theo mock S-69-1).
  static const chartSessions = 'Các buổi trong tháng';

  /// Nút quay lại của S-69 mở từ S-67 (giả định câu chữ: tên màn S-67).
  static const backExerciseDetail = 'Chi tiết bài';

  /// "Tháng 08/2026" (mock S-69).
  static String chartMonth(int month, int year) =>
      'Tháng ${month.toString().padLeft(2, '0')}/$year';

  /// VoiceOver của biểu đồ (04 Bản 2 §6.13).
  static String chartSemantics(int month, int sessions) =>
      'Biểu đồ mức tạ tháng ${month.toString().padLeft(2, '0')}, $sessions buổi';

  /// Ô nhỏ khi chạm một ngày: "07/10 · 10 → 12 kg", "07/10 · 7 → 8 thanh".
  static String chartTooltip(
    String date,
    String start,
    String end,
    String unit,
  ) => '$date · $start → $end $unit';

  // Hình món ăn (03 Bản 2 F12-E2, 05 Bản 2 §6.8.3).
  static const dishImageQuotaExhausted = 'Bạn đã xem đủ 3 hình mới hôm nay.';

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
    'noScheduleTitle': noScheduleTitle,
    'noScheduleToday': noScheduleToday,
    'noScheduleInvite': noScheduleInvite,
    'arrangeWeekly': arrangeWeekly,
    'reminderGenericExample': reminderGenericExample,
    'remindersStartWhenScheduled': remindersStartWhenScheduled,
    'remindersHintNoSchedule': remindersHintNoSchedule,
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
    'unitPlates': unitPlates,
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
    'lockConfirmLine1': lockConfirmLine1,
    'lockConfirmLine2': lockConfirmLine2,
    'extraConfirmTitle': extraConfirmTitle,
    'lockedOnSave': lockedOnSave,
    'changeToDone': changeToDone,
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
    'editTodaySession': editTodaySession,
    'missingTimeOrMuscles': missingTimeOrMuscles,
    'muscleGroups': muscleGroups,
    'logThisWeek': logThisWeek,
    'trendTitle': trendTitle,
    'lastEightWeeks': lastEightWeeks,
    'firstWeightHint': firstWeightHint,
    'notLogged': notLogged,
    'add': add,
    'fieldWeight': fieldWeight,
    'replace': replace,
    'deleteWeight': deleteWeight,
    'keepOneWeight': keepOneWeight,
    'bodyProfile': bodyProfile,
    'calorieLevel': calorieLevel,
    'profileSaved': profileSaved,
    'currentWeight': currentWeight,
    'logInWeightTab': logInWeightTab,
    'updateCalorieTitle': updateCalorieTitle,
    'keepCurrent': keepCurrent,
    'menuEmptyTitle': menuEmptyTitle,
    'menuEmptyBody': menuEmptyBody,
    'generateMenu': generateMenu,
    'retry': retry,
    'menuEstimateNote': menuEstimateNote,
    'menuTotal': menuTotal,
    'calorieChangedRegenerate': calorieChangedRegenerate,
    'regenerateTitle': regenerateTitle,
    'regenerate': regenerate,
    'mealBreakfast': mealBreakfast,
    'mealLunch': mealLunch,
    'mealDinner': mealDinner,
    'mealMorningSnack': mealMorningSnack,
    'mealAfternoonSnack': mealAfternoonSnack,
    'aiBudget': aiBudget,
    'budgetExplain': budgetExplain,
    'budgetWarning80': budgetWarning80,
    'seeDetails': seeDetails,
    'restoreTitle': restoreTitle,
    'restoreSubtitle': restoreSubtitle,
    'restoreFailed': restoreFailed,
    'restored': restored,
    'dishImageQuotaExhausted': dishImageQuotaExhausted,
    'tabTraining': tabTraining,
    'sectionSchedule': sectionSchedule,
    'sectionLibrary': sectionLibrary,
    'sectionProgress': sectionProgress,
    'regionChestUpper': regionChestUpper,
    'regionChestMid': regionChestMid,
    'regionChestLower': regionChestLower,
    'regionLats': regionLats,
    'regionBackMid': regionBackMid,
    'regionBackLower': regionBackLower,
    'regionDeltFront': regionDeltFront,
    'regionDeltSide': regionDeltSide,
    'regionDeltRear': regionDeltRear,
    'regionBiceps': regionBiceps,
    'regionBrachialisForearm': regionBrachialisForearm,
    'regionTricepsLong': regionTricepsLong,
    'regionTricepsLateralMedial': regionTricepsLateralMedial,
    'regionAbsLower': regionAbsLower,
    'regionAbsMid': regionAbsMid,
    'regionObliques': regionObliques,
    'equipmentMachine': equipmentMachine,
    'equipmentFreeWeight': equipmentFreeWeight,
    'equipmentBodyweight': equipmentBodyweight,
    'libraryFootnote': libraryFootnote,
    'backLibrary': backLibrary,
    'backSession': backSession,
    'backProgress': backProgress,
    'mainRegion': mainRegion,
    'howTo': howTo,
    'safetyNotes': safetyNotes,
    'exerciseGuideNote': exerciseGuideNote,
    'notInLibrary': notInLibrary,
    'videoLoading': videoLoading,
    'videoUnavailable': videoUnavailable,
    'videoOffline': videoOffline,
    'videoLoadFailed': videoLoadFailed,
    'playVideo': playVideo,
    'progressEmptyTitle': progressEmptyTitle,
    'progressEmptyBody': progressEmptyBody,
    'viewExercises': viewExercises,
    'viewExercisesAndLog': viewExercisesAndLog,
    'logLift': logLift,
    'logLiftShort': logLiftShort,
    'extraSaved': extraSaved,
    'readOnlyFuture': readOnlyFuture,
    'readOnlyLocked': readOnlyLocked,
    'readOnlyPastExtra': readOnlyPastExtra,
    'liftStart': liftStart,
    'liftEnd': liftEnd,
    'liftStepHint': liftStepHint,
    'liftStepHintPlates': liftStepHintPlates,
    'liftFirstTime': liftFirstTime,
    'deleteLift': deleteLift,
    'deleteLiftConfirm': deleteLiftConfirm,
    'liftDeleted': liftDeleted,
    'liftLockedAtMidnight': liftLockedAtMidnight,
    'liftMissing': liftMissing,
    'liftOutOfRange': liftOutOfRange,
    'liftNotStep': liftNotStep,
    'liftPlatesOutOfRange': liftPlatesOutOfRange,
    'liftPlatesNotStep': liftPlatesNotStep,
    'liftNotNumber': liftNotNumber,
    'liftDecrease': liftDecrease,
    'liftIncrease': liftIncrease,
    'liftDecreasePlates': liftDecreasePlates,
    'liftIncreasePlates': liftIncreasePlates,
    'progressHint': progressHint,
    'viewExercise': viewExercise,
    'viewChart': viewChart,
    'chartLegend': chartLegend,
    'chartMonthEmpty': chartMonthEmpty,
    'chartSessions': chartSessions,
    'backExerciseDetail': backExerciseDetail,
  };
}

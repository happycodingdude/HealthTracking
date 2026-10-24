import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'strings_vi.dart';

/// Ghi nhận giấy phép của phần mã nguồn mở không đến từ pub: bộ SVG sơ đồ cơ
/// lấy từ Jsplice/MuscleMap (MIT; 06 Bản 2 VS31-T05, `05` Bản 2 §6.10.4).
/// Nằm cùng chỗ với giấy phép các thư viện khác (`LicenseRegistry`); nội
/// dung giấy phép đi kèm app ở `assets/body_map/LICENSE`.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      S.bodyMapLicense,
    ], await rootBundle.loadString('assets/body_map/LICENSE'));
  });
}

import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

/// Mở database trong thư mục dữ liệu của app trên iPhone.
AppDatabase openAppDatabase() => AppDatabase(driftDatabase(name: 'ironly'));

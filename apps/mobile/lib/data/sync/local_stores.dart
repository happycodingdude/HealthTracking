import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';

import '../../features/library/data/exercise_repository.dart';
import '../../features/me/data/account_repository.dart';
import '../../features/me/data/profile_repository.dart';
import '../../features/menu/data/menu_repository.dart';
import '../../features/schedule/data/schedule_repository.dart';
import '../../features/weight/data/weight_repository.dart';
import '../../features/workout/data/exercise_note_repository.dart';
import '../../features/workout/data/exercise_unit_repository.dart';
import '../../features/workout/data/lift_log_repository.dart';

/// Ghi bản ghi từ server vào bảng trên máy của một entity.
abstract interface class LocalEntityStore {
  String get entity;

  /// Áp dụng bản ghi server (pull, hoặc bản server trả về khi push không
  /// `applied`). [change] = null hoặc tombstone → xóa bản trên máy.
  Future<void> apply(String key, SyncChange? change);
}

final class AccountStore implements LocalEntityStore {
  AccountStore(this._repo);

  final AccountRepository _repo;
  static const _codec = AccountCodec();

  @override
  String get entity => SyncEntities.account;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    // Tài khoản không bị xóa qua đồng bộ; bỏ qua tombstone.
    if (change == null || change.deleted || data == null) return;
    await _repo.put(_codec.decode(data).displayName);
  }
}

final class ProfileStore implements LocalEntityStore {
  ProfileStore(this._repo);

  final ProfileRepository _repo;
  static const _codec = ProfileCodec();

  @override
  String get entity => SyncEntities.profile;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      await _repo.delete();
      return;
    }
    await _repo.put(_codec.decode(data));
  }
}

final class WeightStore implements LocalEntityStore {
  WeightStore(this._repo);

  final WeightRepository _repo;
  static const _codec = WeightCodec();

  @override
  String get entity => SyncEntities.weight;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final week = LocalDate.parse(key);
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      await _repo.delete(week);
      return;
    }
    await _repo.put(week, _codec.decode(data).weightKgX10);
  }
}

final class WeeklyTemplateStore implements LocalEntityStore {
  WeeklyTemplateStore(this._repo);

  final ScheduleRepository _repo;
  static const _codec = WeeklyTemplateCodec();

  @override
  String get entity => SyncEntities.weeklyTemplate;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      await _repo.deleteTemplate();
      return;
    }
    await _repo.putTemplate(_codec.decode(data));
  }
}

final class MonthPlanStore implements LocalEntityStore {
  MonthPlanStore(this._repo);

  final ScheduleRepository _repo;
  static const _codec = MonthPlanCodec();

  @override
  String get entity => SyncEntities.monthPlan;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      await _repo.deletePlan(YearMonth.parse(key));
      return;
    }
    await _repo.putPlan(_codec.decode(key, data));
  }
}

final class DayStore implements LocalEntityStore {
  DayStore(this._repo);

  final ScheduleRepository _repo;
  static const _codec = DayCodec();

  @override
  String get entity => SyncEntities.day;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      await _repo.deleteDay(LocalDate.parse(key));
      return;
    }
    await _repo.putDay(_codec.decode(key, data));
  }
}

/// Entity chỉ pull `menu` (VS-12). Tombstone = thực đơn ngày cũ (F08-R5).
final class MenuStore implements LocalEntityStore {
  MenuStore(this._repo);

  final MenuRepository _repo;
  static const _codec = MenuCodec();

  @override
  String get entity => SyncEntities.menu;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final date = LocalDate.parse(key);
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      await _repo.delete(date);
      return;
    }
    await _repo.put(date, _codec.decode(data));
  }
}

/// Entity chỉ pull `ai_daily_usage` (VS-12).
final class AiDailyUsageStore implements LocalEntityStore {
  AiDailyUsageStore(this._repo);

  final MenuRepository _repo;
  static const _codec = AiDailyUsageCodec();

  @override
  String get entity => SyncEntities.aiDailyUsage;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      await _repo.deleteUsage(key);
      return;
    }
    await _repo.putUsage(key, _codec.decode(data));
  }
}

/// Entity chỉ pull `exercise` (dòng dùng chung, 06 Bản 2 VS21-T07).
final class ExerciseStore implements LocalEntityStore {
  ExerciseStore(this._repo);

  final ExerciseRepository _repo;
  static const _codec = ExerciseCodec();

  @override
  String get entity => SyncEntities.exercise;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      await _repo.delete(key);
      return;
    }
    await _repo.put(_codec.decode(key, data));
  }
}

/// Entity `lift_log` (push + pull, 06 Bản 2 VS26-T06). Tombstone → xóa.
final class LiftLogStore implements LocalEntityStore {
  LiftLogStore(this._repo);

  final LiftLogRepository _repo;
  static const _codec = LiftLogCodec();

  @override
  String get entity => SyncEntities.liftLog;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      final parsed = LiftLog.parseKey(key);
      if (parsed != null) await _repo.delete(parsed.$1, parsed.$2);
      return;
    }
    await _repo.put(_codec.decode(key, data));
  }
}

/// Entity `exercise_unit` (push + pull, 06 Bản 3 VS32-T05). Không có
/// tombstone; nếu có thì xóa dòng.
final class ExerciseUnitStore implements LocalEntityStore {
  ExerciseUnitStore(this._repo);

  final ExerciseUnitRepository _repo;
  static const _codec = ExerciseUnitCodec();

  @override
  String get entity => SyncEntities.exerciseUnit;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      await _repo.delete(key);
      return;
    }
    await _repo.put(_codec.decode(key, data));
  }
}

/// Entity `exercise_note` (push + pull, 06 Bản 3 VS32-T05). Tombstone → xóa.
final class ExerciseNoteStore implements LocalEntityStore {
  ExerciseNoteStore(this._repo);

  final ExerciseNoteRepository _repo;
  static const _codec = ExerciseNoteCodec();

  @override
  String get entity => SyncEntities.exerciseNote;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    if (change == null || change.deleted || data == null) {
      final parsed = ExerciseNote.parseKey(key);
      if (parsed != null) await _repo.delete(parsed.$1, parsed.$2);
      return;
    }
    await _repo.put(_codec.decode(key, data));
  }
}

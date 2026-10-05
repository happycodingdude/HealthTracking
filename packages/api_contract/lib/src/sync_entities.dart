import 'json_reader.dart';

/// Codec `data` của một entity đồng bộ (06 §6.5.1). App và server cùng dùng để
/// đọc/ghi đúng hợp đồng.
abstract interface class EntityCodec<T> {
  String get entity;
  T decode(Map<String, Object?> data);
  Map<String, Object?> encode(T value);
}

/// Entity `account`, key `me`: tên hiển thị (VS-02).
final class AccountData {
  const AccountData({required this.displayName});

  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is AccountData && other.displayName == displayName;

  @override
  int get hashCode => displayName.hashCode;
}

final class AccountCodec implements EntityCodec<AccountData> {
  const AccountCodec();

  static const key = 'me';

  @override
  String get entity => SyncEntities.account;

  @override
  AccountData decode(Map<String, Object?> data) => AccountData(
    displayName: JsonReader(data, path: 'data').string('displayName'),
  );

  @override
  Map<String, Object?> encode(AccountData value) => {
    'displayName': value.displayName,
  };
}

/// Danh sách entity đồng bộ (06 §6.5.1). Slice sau thêm entity mới vào đây.
abstract final class SyncEntities {
  static const account = 'account';

  static const Map<String, EntityCodec<Object>> codecs = {
    account: AccountCodec(),
  };
}

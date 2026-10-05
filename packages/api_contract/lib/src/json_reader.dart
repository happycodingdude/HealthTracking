/// Lỗi đọc JSON theo hợp đồng. [field] là tên trường gây lỗi.
final class ContractFormatException implements Exception {
  const ContractFormatException(this.field, [this.message = '']);

  final String field;
  final String message;

  @override
  String toString() =>
      'ContractFormatException($field${message.isEmpty ? '' : ': $message'})';
}

/// Đọc JSON object một cách chặt chẽ cho DTO (không ép kiểu ngầm).
final class JsonReader {
  JsonReader(Object? json, {String path = ''})
    : _path = path,
      _map = _asMap(json, path);

  final String _path;
  final Map<String, Object?> _map;

  Map<String, Object?> get raw => _map;

  static Map<String, Object?> _asMap(Object? json, String path) {
    if (json is Map<String, Object?>) return json;
    if (json is Map) {
      return json.map((k, v) => MapEntry(k.toString(), v));
    }
    throw ContractFormatException(path.isEmpty ? 'body' : path, 'cần object');
  }

  String _name(String key) => _path.isEmpty ? key : '$_path.$key';

  bool has(String key) => _map.containsKey(key) && _map[key] != null;

  T _require<T>(String key) {
    final v = _map[key];
    if (v is T) return v;
    throw ContractFormatException(_name(key), 'cần ${T.toString()}');
  }

  T? _optional<T>(String key) {
    final v = _map[key];
    if (v == null) return null;
    if (v is T) return v as T;
    throw ContractFormatException(_name(key), 'cần ${T.toString()}');
  }

  String string(String key) => _require<String>(key);
  String? optString(String key) => _optional<String>(key);

  int integer(String key) => _require<int>(key);
  int? optInteger(String key) => _optional<int>(key);

  bool boolean(String key) => _require<bool>(key);
  bool? optBoolean(String key) => _optional<bool>(key);

  JsonReader object(String key) =>
      JsonReader(_require<Map<Object?, Object?>>(key), path: _name(key));
  JsonReader? optObject(String key) {
    final v = _optional<Map<Object?, Object?>>(key);
    return v == null ? null : JsonReader(v, path: _name(key));
  }

  List<Object?> list(String key) => _require<List<Object?>>(key);

  /// Đọc giá trị bằng [decode]; lỗi định dạng được gắn tên trường.
  T decoded<T>(String key, T Function(String) decode) {
    final s = string(key);
    try {
      return decode(s);
    } on FormatException catch (e) {
      throw ContractFormatException(_name(key), e.message);
    }
  }
}

/// JSON 读取helpers。
///
/// 为什么手写而不上 `json_serializable`：coregen 白名单只开了 `drift_dev`，
/// `freezed` / `json_serializable` / `riverpod_generator` **仍禁**（`ADR-0001`）。
/// 手写还顺带得到一件事：字段缺失时的报错能指名道姓，而不是 `Null check operator`。
library;

typedef JsonMap = Map<String, Object?>;

Never _missing(String key, String expected) =>
    throw FormatException('字段 `$key` 缺失或类型不符（期望 $expected）');

String requireString(JsonMap json, String key) {
  final Object? value = json[key];
  return value is String ? value : _missing(key, 'String');
}

String? optionalString(JsonMap json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  return value is String ? value : _missing(key, 'String?');
}

int requireInt(JsonMap json, String key) {
  final Object? value = json[key];
  return value is int ? value : _missing(key, 'int');
}

bool requireBool(JsonMap json, String key) {
  final Object? value = json[key];
  return value is bool ? value : _missing(key, 'bool');
}

/// `1` 与 `1.0` 都接受 —— JSON 里没有 int/double 之分。
double requireDouble(JsonMap json, String key) {
  final Object? value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  return _missing(key, 'num');
}

List<String> requireStringList(JsonMap json, String key) {
  final Object? value = json[key];
  if (value is! List) {
    return _missing(key, 'List<String>');
  }
  return value.map((Object? e) => e is String ? e : _missing(key, 'List<String>')).toList();
}

Map<String, String> requireStringMap(JsonMap json, String key) {
  final Object? value = json[key];
  if (value is! Map) {
    return _missing(key, 'Map<String,String>');
  }
  final result = <String, String>{};
  for (final MapEntry<Object?, Object?> entry in value.entries) {
    final Object? k = entry.key;
    final Object? v = entry.value;
    if (k is! String || v is! String) {
      return _missing(key, 'Map<String,String>');
    }
    result[k] = v;
  }
  return result;
}

JsonMap requireMap(JsonMap json, String key) {
  final Object? value = json[key];
  if (value is! Map) {
    return _missing(key, 'Map');
  }
  return value.map((Object? k, Object? v) => MapEntry<String, Object?>('$k', v));
}

List<JsonMap> requireMapList(JsonMap json, String key) {
  final Object? value = json[key];
  if (value is! List) {
    return _missing(key, 'List<Map>');
  }
  return value.map((Object? e) {
    if (e is! Map) {
      return _missing(key, 'List<Map>');
    }
    return e.map((Object? k, Object? v) => MapEntry<String, Object?>('$k', v));
  }).toList();
}

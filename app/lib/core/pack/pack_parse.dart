/// 解析层：`pack.json` + 清单 → 强类型实体。
///
/// **解析层不知道包在哪**（那是探测层的事，`R-04`）。入参是两段文本，
/// 所以这一层可以在没有磁盘的情况下测，也可以在 iOS bundle、exe 同级、
/// 内置资产上跑同一份代码。
///
/// 校验边界（**刻意保守**）：
/// - **守**：段集合与 `meta` 信封（`SPEC-PACK-005`）· 多段即拒（`SPEC-PACK-007`）·
///   清单与包同空间同版本 · 五段各自的 `id` 段内唯一（`SPEC-PACK-008`）·
///   `⪯` 无环（`SPEC-FND-005`）
/// - **不守**：字段级语义（域在册、边端点存在、`schemes` 是 `⪯` 的线性扩展）。
///   这些构建期 `content/tools/validator.py` 已经拒过，客户端再写一份就是
///   **两份会分叉的判据**；而它们坏掉时的表象是「少几条边 / 逆序数偏大」，
///   不是崩溃，容错代价低于判据分叉的代价。
library;

import 'dart:convert';

import '../entities/content.dart';
import '../json.dart';
import 'cycle_check.dart';

/// `pack.json` 的内容五段，顺序固定（`SPEC-PACK-005`）。
const List<String> packSegments = <String>[
  'items',
  'edges',
  'schemes',
  'questions',
  'excerpts',
];

/// `meta` 信封的两个键。
const String metaKey = 'meta';
const String metaSpaceKey = 'space';
const String metaVersionKey = 'version';

/// 一个包解析失败。
///
/// **一次报全部问题**，不是遇到第一个就停：包是构建产物，坏了通常坏一片，
/// 逐条修比逐次重跑快。
class PackFormatException implements Exception {
  PackFormatException(this.problems);

  final List<String> problems;

  @override
  String toString() =>
      '内容包格式错误（${problems.length} 处）：\n'
      '${problems.map((String p) => '  · $p').join('\n')}';
}

/// 解析成功后的内存包 —— 三视图 / 定位引擎 / Planner 共用这一份
/// （`SPEC-FND-009`：同一份数据的四种投影）。
class LoadedPack {
  LoadedPack({
    required this.space,
    required this.items,
    required this.edges,
    required this.schemes,
    required this.questions,
    required this.excerpts,
  }) : itemById = Map<String, Item>.unmodifiable(<String, Item>{
         for (final Item item in items) item.id: item,
       });

  /// 空间（含主题色与 Z0 排序 —— 这两项只在清单里）。
  final KnowledgeSpace space;
  final List<Item> items;
  final List<Edge> edges;
  final List<Scheme> schemes;
  final List<Question> questions;
  final List<SourceRef> excerpts;

  /// `⪯` 的节点索引。**只读**：包的字段一律不可变，进度归事件流（`SPEC-FND-010`）。
  final Map<String, Item> itemById;

  Item? itemOf(String id) => itemById[id];

  /// 某套体系的节点 id（`null` = 无此体系）。
  List<String>? schemeNodes(String schemeId) {
    for (final Scheme scheme in schemes) {
      if (scheme.id == schemeId) {
        return scheme.nodes;
      }
    }
    return null;
  }
}

/// 解析清单与产物。任一处不合格即抛 [PackFormatException]（含全部问题）。
LoadedPack parsePack({required String manifestJson, required String packJson}) {
  final List<String> problems = <String>[];

  final JsonMap? manifest = _decodeObject(manifestJson, 'manifest.json', problems);
  final JsonMap? pack = _decodeObject(packJson, 'pack.json', problems);
  if (manifest == null || pack == null) {
    throw PackFormatException(problems);
  }

  final KnowledgeSpace? space = _parseSpace(manifest, problems);
  if (space != null) {
    _checkEnvelope(pack, space, problems);
  }

  final List<Item> items = _parseSegment(pack, 'items', Item.fromJson, problems);
  final List<Edge> edges = _parseSegment(pack, 'edges', Edge.fromJson, problems);
  final List<Scheme> schemes = _parseSegment(pack, 'schemes', Scheme.fromJson, problems);
  final List<Question> questions = _parseSegment(pack, 'questions', Question.fromJson, problems);
  final List<SourceRef> excerpts = _parseSegment(pack, 'excerpts', SourceRef.fromJson, problems);

  if (problems.isNotEmpty || space == null) {
    throw PackFormatException(problems);
  }

  for (final List<String> cycle in findCycles(edges)) {
    problems.add('`⪯` 出现环：${cycle.join(" → ")}（`SPEC-FND-005` 要求 DAG）');
  }

  if (problems.isNotEmpty) {
    throw PackFormatException(problems);
  }

  return LoadedPack(
    space: space,
    items: items,
    edges: edges,
    schemes: schemes,
    questions: questions,
    excerpts: excerpts,
  );
}

JsonMap? _decodeObject(String source, String where, List<String> problems) {
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    problems.add('$where 不是合法 JSON：${error.message}');
    return null;
  }
  if (decoded is! Map) {
    problems.add('$where 顶层必须是对象，实际是 ${decoded.runtimeType}');
    return null;
  }
  return decoded.map((Object? key, Object? value) => MapEntry<String, Object?>('$key', value));
}

KnowledgeSpace? _parseSpace(JsonMap manifest, List<String> problems) {
  try {
    return KnowledgeSpace.fromJson(manifest);
  } on FormatException catch (error) {
    problems.add('manifest.json ${error.message}');
    return null;
  }
}

/// `meta` 信封：只回答「这是哪个空间的哪一版」（`SPEC-PACK-005`），
/// 但仍须与清单**逐字一致** —— 不一致说明包与清单不是同一批产物，
/// 这种组合下的内容不可信，比缺字段更该拒。
void _checkEnvelope(JsonMap pack, KnowledgeSpace space, List<String> problems) {
  final Object? meta = pack[metaKey];
  if (meta is! Map) {
    problems.add('pack.json 缺 `meta` 信封（`SPEC-PACK-005`）');
    return;
  }
  final Object? spaceId = meta[metaSpaceKey];
  final Object? version = meta[metaVersionKey];
  if (spaceId is! String || version is! String) {
    problems.add('`meta` 必须含字符串 `space` 与 `version`');
    return;
  }
  if (spaceId != space.id) {
    problems.add('`meta.space` 为 `$spaceId`，清单 `id` 为 `${space.id}` —— 包与清单不是同一空间');
  }
  if (version != space.version) {
    problems.add(
      '`meta.version` 为 `$version`，清单 `version` 为 `${space.version}` —— '
      '包与清单不是同一批产物（`SPEC-PACK-005`）',
    );
  }

  for (final String key in pack.keys.toList()..sort()) {
    if (key != metaKey && !packSegments.contains(key)) {
      problems.add('pack.json 不得出现 `$key` 段（`SPEC-PACK-007`：笔记模板不进包）');
    }
  }
}

List<T> _parseSegment<T>(
  JsonMap pack,
  String name,
  T Function(JsonMap) parse,
  List<String> problems,
) {
  final Object? raw = pack[name];
  if (raw == null) {
    problems.add('pack.json 缺 `$name` 段（`SPEC-PACK-005`：五段缺一即格式错误）');
    return <T>[];
  }
  if (raw is! List) {
    problems.add('`$name` 段必须是数组，实际是 ${raw.runtimeType}');
    return <T>[];
  }

  final List<T> parsed = <T>[];
  final Set<String> ids = <String>{};
  for (int i = 0; i < raw.length; i++) {
    final Object? entry = raw[i];
    if (entry is! Map) {
      problems.add('`$name`[$i] 不是对象');
      continue;
    }
    try {
      parsed.add(parse(entry.map((Object? k, Object? v) => MapEntry<String, Object?>('$k', v))));
    } on FormatException catch (error) {
      problems.add('`$name`[$i] ${error.message}');
    } on ArgumentError catch (error) {
      problems.add('`$name`[$i] ${error.message}');
    }
  }

  for (final T object in parsed) {
    final String id = _idOf(object);
    if (!ids.add(id)) {
      problems.add('`$name` 段内 `id` 重复：`$id`（`SPEC-PACK-008`）');
    }
  }
  return parsed;
}

String _idOf(Object? object) {
  if (object is Item) {
    return object.id;
  }
  if (object is Edge) {
    return object.id;
  }
  if (object is Scheme) {
    return object.id;
  }
  if (object is Question) {
    return object.id;
  }
  if (object is SourceRef) {
    return object.id;
  }
  return '';
}

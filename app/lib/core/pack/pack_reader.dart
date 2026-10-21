/// 新格式解析层：**单文件** `pack.json` → 强类型实体。
///
/// ⚠️ **`B13a` 笔 4 新增，笔 5 接线**：旧 [`pack_parse.dart`](pack_parse.dart)
/// 解析的是六轴五段（`items` / `edges` / `schemes` / `questions` / `excerpts`），
/// 它的消费点（三视图 / 定位 / Planner 共 31 个文件）在笔 5 才切过来。
/// 两个解析器**并存而不互相 import**，因此同名类（`Scheme` / `SourceRef` /
/// `MethodProfile`）各在各的库里，不会撞；笔 5 删旧文件后撞名自动消失。
///
/// ## 形态：单文件，不是「清单 + 产物」两份
///
/// 旧格式吃两段文本（`manifest.json` + `dist/pack.json`），并用 `meta{space,
/// version}` 信封校验「两者是不是同一批产物」。新格式**没有这个必要**：
/// 清单字段与六段内容同在 `pack.json` 顶层（[`minimal-pack.md`](../../../../docs/reference/minimal-pack.md)
/// §3.1 的夹具就是这个形态），「同一批」由「同一个文件」保证。
/// 因此本层只收一个入参，也**不再有 `meta` 信封**。
///
/// ## 校验边界（沿用旧层，不是重新发明）
///
/// - **守**：六段齐全 · 顶层不得出现清单字段与六段之外的键 · 段内 id 唯一 ·
///   `⪯` 无环 · **`counts` 与实扫一致**
/// - **不守**：字段级语义（父链可达、`path` 构成、`criteria` 与 `quiz` 1:1）——
///   那些要么构建期 `content/tools/validator.py` 已拒过，要么归 `triple_validator`
///
/// `counts` 这一条是新加的，理由是它在旧层**没有对家**：`payload.counts.planet`
/// 是「这个包能学多少东西」的唯一摘要，而 `nodes[]` 里的行星数是唯一事实。
/// 两者不一致时，界面按摘要显示「零可学项」，数据里却躺着两百个行星，
/// **没有任何一处会报错** —— 记忆里 `sourceRefs` 那次「静默少一个根」是同一形态。
library;

import 'dart:convert';

import '../entities/edge.dart';
import '../entities/entry.dart';
import '../entities/method.dart';
import '../entities/node.dart';
import '../entities/pack.dart';
import '../entities/scheme.dart';
import '../entities/source.dart';
import '../enums.dart';
import '../json.dart';
import 'cycle_check.dart';

/// `pack.json` 的内容六段，顺序固定。
const List<String> packContentSegments = <String>[
  'nodes',
  'edges',
  'entries',
  'sources',
  'schemes',
  'methods',
];

/// 一个包解析失败。
///
/// **一次报全部问题**，与旧层同口径：包是构建产物，坏了通常坏一片，
/// 逐条修比逐次重跑快。（与之相反的是 `triple_validator` 的 fail-fast ——
/// 那是验收判据，一次报多个就说不清「这个反例证明了哪条规则」。）
class PackContentException implements Exception {
  PackContentException(this.problems);

  final List<String> problems;

  @override
  String toString() =>
      '内容包格式错误（${problems.length} 处）：\n'
      '${problems.map((String p) => '  · $p').join('\n')}';
}

/// 解析成功后的内存包 —— 三视图 / 定位引擎 / Planner 共用这一份
/// （`SPEC-FND-009`：同一份数据的四种投影）。
class PackContent {
  PackContent({
    required this.pack,
    required this.nodes,
    required this.edges,
    required this.entries,
    required this.sources,
    required this.schemes,
    required this.methods,
  }) : nodeById = Map<String, Node>.unmodifiable(<String, Node>{
         for (final Node node in nodes) node.id: node,
       }),
       entryByNodeId = Map<String, NodeEntry>.unmodifiable(<String, NodeEntry>{
         for (final NodeEntry entry in entries) entry.nodeId: entry,
       }),
       sourceById = Map<String, SourceRef>.unmodifiable(<String, SourceRef>{
         for (final SourceRef source in sources) source.id: source,
       });

  final Pack pack;
  final List<Node> nodes;
  final List<NodeEdge> edges;
  final List<NodeEntry> entries;
  final List<SourceRef> sources;
  final List<Scheme> schemes;
  final List<MethodProfile> methods;

  /// `Node.id` → 节点。**只读**：包的字段一律不可变，进度归事件流
  /// （`SPEC-FND-010`）。
  final Map<String, Node> nodeById;

  /// `Node.id` → 内容。骨架节点**没有** entry，所以这是稀疏表。
  final Map<String, NodeEntry> entryByNodeId;

  final Map<String, SourceRef> sourceById;

  Node? nodeOf(String id) => nodeById[id];

  NodeEntry? entryOf(String id) => entryByNodeId[id];

  /// 只取可学节点 —— 七步、排程、掌握度只对它们有意义。
  Iterable<LearnableNode> get learnableNodes => nodes.whereType<LearnableNode>();

  /// 只取先修边 —— `⪯` 的唯一来源。
  Iterable<PrerequisiteEdge> get prerequisites =>
      edges.whereType<PrerequisiteEdge>();

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

/// 解析一个包的全文。任一处不合格即抛 [PackContentException]（含全部问题）。
PackContent readPack(String packJson) {
  final List<String> problems = <String>[];

  final JsonMap? raw = _decodeObject(packJson, 'pack.json', problems);
  if (raw == null) {
    throw PackContentException(problems);
  }

  final Pack? parsedPack = _parsePack(raw, problems);
  if (parsedPack != null) {
    _checkTopLevelKeys(raw, parsedPack, problems);
  }

  final List<Node> nodes = _parseSegment(
    raw,
    'nodes',
    nodeFromJson,
    problems,
    idOf: (Node node) => node.id,
  );
  final List<NodeEdge> edges = _parseSegment(
    raw,
    'edges',
    nodeEdgeFromJson,
    problems,
  );
  final List<NodeEntry> entries = _parseSegment(
    raw,
    'entries',
    NodeEntry.fromJson,
    problems,
    idOf: (NodeEntry entry) => entry.nodeId,
  );
  final List<SourceRef> sources = _parseSegment(
    raw,
    'sources',
    SourceRef.fromJson,
    problems,
    idOf: (SourceRef source) => source.id,
  );
  final List<Scheme> schemes = _parseSegment(
    raw,
    'schemes',
    Scheme.fromJson,
    problems,
    idOf: (Scheme scheme) => scheme.id,
  );
  final List<MethodProfile> methods = _parseSegment(
    raw,
    'methods',
    MethodProfile.fromJson,
    problems,
    idOf: (MethodProfile method) => method.id,
  );

  if (problems.isNotEmpty || parsedPack == null) {
    throw PackContentException(problems);
  }

  for (final List<String> cycle in findCyclesFrom(<({String from, String to})>[
    for (final PrerequisiteEdge edge in edges.whereType<PrerequisiteEdge>())
      (from: edge.fromId, to: edge.toId),
  ])) {
    problems.add('`⪯` 出现环：${cycle.join(" → ")}（`SPEC-FND-005` 要求 DAG）');
  }

  _checkCounts(parsedPack, nodes, problems);

  if (problems.isNotEmpty) {
    throw PackContentException(problems);
  }

  return PackContent(
    pack: parsedPack,
    nodes: nodes,
    edges: edges,
    entries: entries,
    sources: sources,
    schemes: schemes,
    methods: methods,
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

Pack? _parsePack(JsonMap raw, List<String> problems) {
  try {
    return Pack.fromJson(raw);
  } on FormatException catch (error) {
    problems.add('manifest 字段 ${error.message}');
    return null;
  } on ArgumentError catch (error) {
    // `kinds[]` 与特化字段对不上时 `Pack` 自己会抛（`IllegalPackKindError`）。
    problems.add('manifest 字段 ${error.message}');
    return null;
  }
}

/// 顶层只允许「清单字段 + 六段」。
///
/// 清单字段集直接取 `Pack.toJson().keys`，**不另维护一张常量表** ——
/// 两张表迟早会分叉，而分叉的表象是新加一个清单字段后被判成「非法段」。
void _checkTopLevelKeys(JsonMap raw, Pack parsed, List<String> problems) {
  final Set<String> allowed = <String>{
    ...packContentSegments,
    ...parsed.toJson().keys,
  };
  for (final String key in raw.keys.toList()..sort()) {
    if (!allowed.contains(key)) {
      problems.add('pack.json 不得出现 `$key`（既不是清单字段，也不是六段之一）');
    }
  }
}

/// `counts` 与实扫必须一致（见文件头「守」第五条）。
///
/// 只在清单声明了 `payload` 时查：非载荷包没有 `counts` 可对。
void _checkCounts(Pack pack, List<Node> nodes, List<String> problems) {
  final PayloadFacts? facts = pack.payload;
  if (facts == null) {
    return;
  }
  int star = 0;
  int system = 0;
  int planet = 0;
  for (final Node node in nodes) {
    final LevelSlot slot = node.levelSlot;
    if (slot == LevelSlot.planet) {
      planet++;
    } else if (slot == LevelSlot.system) {
      system++;
    } else if (slot == LevelSlot.star) {
      star++;
    }
  }
  _compareCount('star', facts.counts.star, star, problems);
  _compareCount('system', facts.counts.system, system, problems);
  _compareCount('planet', facts.counts.planet, planet, problems);
}

void _compareCount(String key, int declared, int actual, List<String> problems) {
  if (declared != actual) {
    problems.add(
      '`payload.counts.$key` 声明 $declared，`nodes[]` 实扫 $actual '
      '—— 摘要与正文不一致时界面只会露出其中一份',
    );
  }
}

List<T> _parseSegment<T>(
  JsonMap pack,
  String name,
  T Function(JsonMap) parse,
  List<String> problems, {
  String Function(T)? idOf,
}) {
  final Object? raw = pack[name];
  if (raw == null) {
    problems.add('pack.json 缺 `$name` 段（六段缺一即格式错误）');
    return <T>[];
  }
  if (raw is! List) {
    problems.add('`$name` 段必须是数组，实际是 ${raw.runtimeType}');
    return <T>[];
  }

  final List<T> parsed = <T>[];
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
      // `StructuralNode` 的槽位校验抛 `ArgumentError`。
      problems.add('`$name`[$i] ${error.message}');
    }
  }

  // `edges` 没有 `id`：三类的身份是「类型 + 端点」，而两端相同的 `parent`
  // 与 `wormhole` 是两条不同的边，不是重复。所以只有带 `id` 的段查重。
  final String Function(T)? id = idOf;
  if (id != null) {
    final Set<String> ids = <String>{};
    for (final T object in parsed) {
      if (!ids.add(id(object))) {
        problems.add('`$name` 段内 id 重复：`${id(object)}`');
      }
    }
  }
  return parsed;
}

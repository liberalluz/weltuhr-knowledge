/// 新格式解析层：**单文件** `pack.json` → 强类型实体。
///
/// ⚠️ **`B13a` 笔 4 新增，笔 5c 成为唯一解析器**：旧的
/// [`pack_parse.dart`](pack_parse.dart)（六轴五段：`items` / `edges` / `schemes` /
/// `questions` / `excerpts`）与它服务的那批实体已在本笔删除 —— 两套解析器并存
/// 期间的同名类（`Scheme` / `SourceRef` / `MethodProfile`）也一并只剩这一份。
///
/// ## 形态：单文件，不是「清单 + 产物」两份
///
/// 旧格式吃两段文本（`manifest.json` + `dist/pack.json`），并用 `meta{space,
/// version}` 信封校验「两者是不是同一批产物」。新格式**没有这个必要**：
/// 清单字段与六段内容同在 `pack.json` 顶层（[`minimal-pack.md`](../../../../docs/specs/minimal-pack.md)
/// §3.1 的夹具就是这个形态），「同一批」由「同一个文件」保证。
/// 因此本层只收一个入参，也**不再有 `meta` 信封**。
///
/// ## 校验边界（沿用旧层，不是重新发明）
///
/// - **守**：六段齐全 · 顶层不得出现清单字段与六段之外的键 · 段内 id 唯一 ·
///   `⪯` 无环 · **两份摘要与实扫一致**（`payload.counts` 对 `nodes[]` ·
///   `terrain.edge_counts` 对 `edges[]`）· `terrain.axes_covered ⊆ axes[]`
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
import '../graph/parent_index.dart';
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
    Map<String, String> skeletonPaths = const <String, String>{},
  }) : nodeById = Map<String, Node>.unmodifiable(<String, Node>{
         for (final Node node in nodes) node.id: node,
       }),
       entryByNodeId = Map<String, NodeEntry>.unmodifiable(<String, NodeEntry>{
         for (final NodeEntry entry in entries) entry.nodeId: entry,
       }),
       sourceById = Map<String, SourceRef>.unmodifiable(<String, SourceRef>{
         for (final SourceRef source in sources) source.id: source,
       }),
       parents = ParentIndex(
         // 只收 `main` 边：`secondary` 是附加归属，同一节点可有 0..N 条，
         // 拿它算父链会让 `path` 与「在谁子树下」产生多解。
         mainParentOf: <String, String>{
           for (final ParentEdge edge in edges.whereType<ParentEdge>())
             if (edge.isMain) edge.childId: edge.parentId,
         },
         slugOf: <String, String>{
           for (final Node node in nodes) node.id: node.slug,
         },
         // 骨架 `path` 由外部注入（`minimal-pack.md` §4.2）。载荷包自己不知道
         // 骨架长什么样，也不该内置一份假骨架 —— 那是第二份骨架数据。
         // `B14` 笔 4 起由 `PackLoader` 注入：不注入的话 `pathOf` 到骨架父就断链。
         skeletonPaths: skeletonPaths,
       );

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

  /// 主父索引与派生 `path`（`path-rules` `P-01` / `P-02`）。
  ///
  /// **在装载时建一次**，不交给各消费点自建：`inScope`、面包屑、`Plan.subtree_root`
  /// 判定全要走父链，各写一遍就是「同一棵树有几份索引」，而它们不一致时没有任何
  /// 断言会红。
  ///
  /// 骨架 `path` 由构造体的 `skeletonPaths` 注入（`minimal-pack.md` §4.2）：
  /// 不给注入时 `pathOf` 对「父链顶端是骨架」的节点返回 `null`，那是**如实反映**
  /// —— 包自己不知道骨架在哪，也不该内置一份假骨架。`PackLoader` 装包时一定注入，
  /// 所以跨包 `path` 在装载层可算；直接 `readPack` 的调用方（解析层测试、构建期
  /// 工具）不需要它。
  final ParentIndex parents;

  Node? nodeOf(String id) => nodeById[id];

  /// 收窄到可学节点 —— 旧的 `LoadedPack.itemOf` 语义正是它（行星层）。
  ///
  /// **不与 [nodeOf] 合并**：`Item` 时代「按 id 取一项」从不担心取到的是不是
  /// 可学的；换成两型之后，结构节点上取不到东西这件事必须由调用方显式看见。
  /// 合并成一个返回 `Node` 的方法，那些调用点就会拿到 `StructuralNode` 再各自
  /// 判类型 —— 判断散出去正是 `ADR-0007` 决策 1 要堵的口子。
  LearnableNode? learnableOf(String id) {
    final Node? node = nodeById[id];
    return node is LearnableNode ? node : null;
  }

  NodeEntry? entryOf(String id) => entryByNodeId[id];

  /// 只取可学节点 —— 七步、排程、掌握度只对它们有意义。
  Iterable<LearnableNode> get learnableNodes => nodes.whereType<LearnableNode>();

  /// 本包里实际出现过的可学类型（方法覆盖率与候选排序的原料）。
  ///
  /// 由 [learnableNodes] 现算而不缓存：缓存会在装/卸载荷后与 `nodes` 分叉，
  /// 而调用点全都是一次性遍历，算一遍不比查表贵。
  Set<LearnableType> get presentTypes => <LearnableType>{
    for (final LearnableNode node in learnableNodes) node.type,
  };

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
///
/// [skeletonPaths] 是骨架节点 `id → path` 的注入表（`minimal-pack.md` §4.2）：
/// 给了它，跨包 `pathOf` 才算得出来；不给则骨架那一段断链，`pathOf` 返回 `null`。
/// **本层不校验 `path`** —— 三元校验归 `triple_validator`，这里只把它灌进索引。
PackContent readPack(
  String packJson, {
  Map<String, String> skeletonPaths = const <String, String>{},
}) {
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

  // ⚠️ **这里故意不收窄到 `required`**：`B15` 的出口判据要求环检测覆盖**两类边**，
  // `recommended` 成环同样要拒 —— 建议边写成一个圈，用户拿到的「建议先学」就
  // 变成了死结，而 `⪯` 那边（`kahnLevels` 只沿 required 走）一点都看不出来。
  // 改成 `requiredEdgesOf(...)` 会让 `TC-FND-015` 当场红，别顺手「统一口径」。
  for (final List<String> cycle in findCyclesFrom(<({String from, String to})>[
    for (final PrerequisiteEdge edge in edges.whereType<PrerequisiteEdge>())
      (from: edge.fromId, to: edge.toId),
  ])) {
    problems.add('`⪯` 出现环：${cycle.join(" → ")}（`SPEC-FND-005` 要求 DAG）');
  }

  _checkPayloadCounts(parsedPack, nodes, problems);
  _checkTerrainCounts(parsedPack, edges, problems);
  _checkTerrainAxes(parsedPack, problems);

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
    skeletonPaths: skeletonPaths,
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

/// `payload.counts` 与实扫必须一致（见文件头「守」第五条）。
///
/// 只在清单声明了 `payload` 时查：非载荷包没有 `counts` 可对。
void _checkPayloadCounts(Pack pack, List<Node> nodes, List<String> problems) {
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
  _compareCount('payload.counts', 'star', facts.counts.star, star, 'nodes[]', problems);
  _compareCount('payload.counts', 'system', facts.counts.system, system, 'nodes[]', problems);
  _compareCount('payload.counts', 'planet', facts.counts.planet, planet, 'nodes[]', problems);
}

/// `terrain.edge_counts` 与 `edges[]` 实扫必须一致。
///
/// 与 [`_checkPayloadCounts`] 同一形态、同一理由：摘要与正文不一致时没有任何一处
/// 会报错。地形包尤其隐蔽 —— 它没有 `nodes[]`，「这个包给了多少条先修边」在界面上
/// 只有 `edge_counts` 一份，而 `⪯` 走的是 `edges[]`。两个数分叉时，用户看到的建议
/// 顺序与摘要写的条数对不上，查起来还得先怀疑是不是渲染。
///
/// 两类强度**分开对**：只对总数会放过「`required` 少写一条、`recommended` 多写
/// 一条」—— 长度相同而静默通过，但这两类不可互换（一类构成 `⪯`，一类不构成）。
void _checkTerrainCounts(
  Pack pack,
  List<NodeEdge> edges,
  List<String> problems,
) {
  final TerrainFacts? facts = pack.terrain;
  if (facts == null) {
    return;
  }
  int required = 0;
  int recommended = 0;
  for (final NodeEdge edge in edges) {
    if (edge is! PrerequisiteEdge) {
      continue;
    }
    if (edge.isRequired) {
      required++;
    } else {
      recommended++;
    }
  }
  _compareCount(
    'terrain.edge_counts',
    'required',
    facts.requiredCount,
    required,
    'edges[]',
    problems,
  );
  _compareCount(
    'terrain.edge_counts',
    'recommended',
    facts.recommendedCount,
    recommended,
    'edges[]',
    problems,
  );
}

/// `terrain.axes_covered` 的三条定义性校验。
///
/// 依据 `entity-fields` §1：`axes[]` 是「本包涉及哪几条轴」，`axes_covered[]` 是
/// 「地形边跨了哪几条轴」—— 后者的元素必须在前者里。否则同一份 `pack.json` 里
/// 清单说「不涉及这条轴」、地形摘要说「跨了它」，两句互相打脸却都读得进。
///
/// **不校验「实际跨了哪几条轴」**：真实的地形边指向**别的包**的节点（决策 4 把先修
/// 边独立成包、且跨轴），边两端不在本包 `nodes[]` 里，解析层拿不到它们的轴。要在
/// 这里算，就得先把依赖包装进来 —— 那是装载层的事，还会让「单独读一个包」变成
/// 不可能的用法。所以只守三件不需要外部信息的事：非空 · 不重复 · 是 `axes[]` 的子集。
void _checkTerrainAxes(Pack pack, List<String> problems) {
  final TerrainFacts? facts = pack.terrain;
  if (facts == null) {
    return;
  }
  final List<Axis> covered = facts.axesCovered;
  if (covered.isEmpty) {
    problems.add(
      '`terrain.axes_covered` 不得为空 —— 一条轴都不跨就没有地形可言，'
      '而 `terrain` 这个 kind 已经声明了',
    );
  }
  final Set<Axis> seen = <Axis>{};
  for (final Axis axis in covered) {
    if (!seen.add(axis)) {
      problems.add('`terrain.axes_covered` 重复：`${axis.name}`');
    }
  }
  for (final Axis axis in seen) {
    if (!pack.axes.contains(axis)) {
      problems.add(
        '`terrain.axes_covered` 含 `axes[]` 里没有的轴 `${axis.name}` '
        '—— 清单说本包不涉及这条轴，地形摘要却说跨了它',
      );
    }
  }
}

void _compareCount(
  String path,
  String key,
  int declared,
  int actual,
  String segment,
  List<String> problems,
) {
  if (declared != actual) {
    problems.add(
      '`$path.$key` 声明 $declared，`$segment` 实扫 $actual '
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

/// 骨架包（内置，不走插件）—— `B14` 笔 6 的出口第一项「骨架包可加载」。
///
/// ## 它为什么不是第五类包
///
/// `ADR-0005` 决策 2：`skeleton` 全量内置、**不走插件、不进审核**。所以
/// [PackKind] 里没有 `skeleton`，骨架包的清单是 `kinds: []` + 四个 facts 全空 ——
/// 这不是「漏填 kind」，而是它本来就不参与插件那套装 / 卸。
///
/// 加第五个 kind 会立刻带出三个没有答案的问题：谁审核它、能不能卸载、卸载后
/// 载荷包挂在哪里。本类只回答一件事：**把骨架包读进来，并把 `id → path` 交给
/// [PackLoader]** —— 那正是载荷包此前缺的那半张表（`PackLoader.skeletonPaths`）。
///
/// ## 五项包级校验（`skeleton-catalog.md` §六 步骤 4）
///
/// [readPack] 的「不守」清单里明写不查父链语义（父链可达、`path` 构成），
/// 因为载荷包靠三元校验器在**装包时**查。骨架包没有「装包时」：它是内置的、
/// 一启动就在，所以那五项必须在这里查，否则永远没有一处会查。
///
/// | # | 校验 | 不查会怎样 |
/// |---|---|---|
/// | ① | `official_code` 轴内唯一 | 官方码是 `id` 的原料，重码 ⇒ 两条目录条目共用一个身份 |
/// | ② | 主父唯一 | 零条 = 悬空；两条 = 「主父是谁」有两个答案，`path` 与面包屑各取一条 |
/// | ③ | 父边无环 | [ParentIndex.pathOf] 见环返回 `null`，但返回 `null` 只是不崩，树仍是坏的 |
/// | ④ | 无孤儿 | 父边端点在 `nodes[]` 之外 ⇒ 这条边永远走不到，属于「数据在但看不见」 |
/// | ⑤ | 每个 `star` 父链到轴根 | 断链的恒星挂不进任何轴，界面表现为「不在任何轴下」 |
///
/// 另外两条与源侧同判据：`id` 全局唯一（三轴都以 `skeleton:` 开头，同名同码靠轴段区分）、
/// 派生 `path` 全局唯一（`P-01` / `P-07`：算出来查重，不写进数据）。
library;

import '../entities/edge.dart';
import '../entities/node.dart';
import '../enums.dart';
import '../graph/parent_index.dart';
import 'pack_reader.dart';

/// 骨架包校验失败（**一次报全部**，与 [PackContentException] 同口径）。
class SkeletonPackException implements Exception {
  SkeletonPackException(this.problems);

  final List<String> problems;

  @override
  String toString() =>
      '骨架包校验失败（${problems.length} 处）：\n'
      '${problems.map((String p) => '  · $p').join('\n')}';
}

/// 装载完成的内置骨架。
class SkeletonPack {
  const SkeletonPack({required this.content, required this.paths, required this.axisRoots});

  /// 骨架包解析结果。`entries` / `schemes` / `methods` 三段按规格为空。
  final PackContent content;

  /// `id → 完整 path`，3,375 条。**这是载荷包装包时缺的那半张表**
  /// （`PackLoader.skeletonPaths` 直接吃它）。
  ///
  /// 含轴根段（`major/01/0101`），与 `minimal-pack.md` §4.2 的注入形态一致；
  /// 不含轴根就成了「相对路径」，两个轴的 `01` 会撞在同一个 `path` 上。
  final Map<String, String> paths;

  /// 轴 → 该轴根节点 id。
  final Map<Axis, String> axisRoots;

  /// 节点总数（三轴合计）。
  int get nodeCount => content.nodes.length;
}

/// 解析并校验一个骨架包。
///
/// [packJson] 是 `content/skeleton/pack.json` 的全文（由
/// `content/tools/assemble_skeleton.py` 产出，不入库）。任何一条不合格即抛
/// [SkeletonPackException] —— **不返回半个骨架**：半份骨架的后果是载荷包
/// 挂不上去，而错误信息会指向载荷包，排查方向直接错。
SkeletonPack loadSkeleton(String packJson) {
  final PackContent content = readPack(packJson);
  final List<String> problems = <String>[];

  final List<Node> nodes = content.nodes;
  final Map<String, Node> byId = content.nodeById;

  _checkIdsUnique(nodes, problems);
  _checkOfficialCodes(nodes, problems);

  // 主父：只认 `main`。`secondary` 是 0..N 的附加归属（`entity-fields` §3），
  // 拿它算父链会让 `path` 多解。
  final Map<String, List<String>> mainParents = <String, List<String>>{
    for (final Node node in nodes) node.id: <String>[],
  };
  for (final ParentEdge edge in content.edges.whereType<ParentEdge>()) {
    if (!edge.isMain) {
      continue;
    }
    if (byId[edge.childId] == null) {
      problems.add('父边端点不在 `nodes[]`：child=`${edge.childId}`');
      continue;
    }
    final List<String>? bucket = mainParents[edge.childId];
    if (bucket == null) {
      continue;
    }
    if (byId[edge.parentId] == null) {
      problems.add('孤儿：`${edge.childId}` → `${edge.parentId}`');
      continue;
    }
    bucket.add(edge.parentId);
  }

  final Map<Axis, String> axisRoots = <Axis, String>{};
  for (final Node node in nodes) {
    final List<String> parents = mainParents[node.id] ?? const <String>[];
    final bool isRoot = node.levelSlot == LevelSlot.supercluster;
    if (isRoot) {
      if (parents.isNotEmpty) {
        problems.add('轴根不该有父边：`${node.id}` → `${parents.join(", ")}`');
      }
      // 一个轴只能有一个根：第二个根会让 `path` 出现两个起点。
      final String? existing = axisRoots[node.axis];
      if (existing != null && existing != node.id) {
        problems.add('轴 `${node.axis.name}` 有两个根：`$existing` 与 `${node.id}`');
      }
      axisRoots[node.axis] = node.id;
    } else if (parents.length != 1) {
      problems.add('主父不唯一 / 缺失：`${node.id}` 有 ${parents.length} 条 `main` 父边');
    }
  }
  for (final Axis axis in content.pack.axes) {
    if (!axisRoots.containsKey(axis)) {
      problems.add('轴 `${axis.name}` 没有 `supercluster` 根节点');
    }
  }

  final Map<String, String> paths = _derivePaths(nodes, byId, mainParents, problems);
  _checkStarChains(nodes, byId, mainParents, axisRoots, problems);
  _checkPathUnique(paths, problems);

  if (problems.isNotEmpty) {
    throw SkeletonPackException(problems);
  }
  return SkeletonPack(
    content: content,
    paths: Map<String, String>.unmodifiable(paths),
    axisRoots: Map<Axis, String>.unmodifiable(axisRoots),
  );
}

/// `id` 全局唯一。
///
/// `readPack` 已查「段内 id 重复」，但它的判据是**同一个 `nodes` 段**；这里再查一遍
/// 是为了把这条判据留在本类的错误清单里 —— 骨架包的 id 是跨包引用目标，
/// 重复时两条目录条目共用一个身份，而 `readPack` 的报错文案说的是「段内」，
/// 排查时会去翻数据而不是翻装配器。
void _checkIdsUnique(List<Node> nodes, List<String> problems) {
  final Map<String, int> seen = <String, int>{};
  for (final Node node in nodes) {
    seen[node.id] = (seen[node.id] ?? 0) + 1;
  }
  for (final MapEntry<String, int> entry in seen.entries) {
    if (entry.value > 1) {
      problems.add('`id` 重复 ${entry.value} 次：`${entry.key}`');
    }
  }
}

/// `official_code` **轴内**唯一。轴根的码为空，不参与。
void _checkOfficialCodes(List<Node> nodes, List<String> problems) {
  final Map<Axis, Map<String, int>> seen = <Axis, Map<String, int>>{};
  for (final Node node in nodes) {
    final String? code = node.officialCode;
    if (code == null || code.isEmpty) {
      continue;
    }
    final Map<String, int> bucket = seen.putIfAbsent(node.axis, () => <String, int>{});
    bucket[code] = (bucket[code] ?? 0) + 1;
  }
  for (final MapEntry<Axis, Map<String, int>> axis in seen.entries) {
    for (final MapEntry<String, int> code in axis.value.entries) {
      if (code.value > 1) {
        problems.add('`official_code` 在轴 `${axis.key.name}` 内重复：`${code.key}`');
      }
    }
  }
}

/// 沿 `main` 父链拼出完整 `path`（`P-01`：算出来，不存）。
///
/// 轴根自己的 `path` = 自己的 `slug`（`discipline` / `major` / `occupation`）——
/// 与 `skeleton-catalog` §四 的 `major/01/0101` 形态一致。环与断链都记问题并返回
/// 空表项，让上层把问题一次报全，而不是在这里抛。
Map<String, String> _derivePaths(
  List<Node> nodes,
  Map<String, Node> byId,
  Map<String, List<String>> mainParents,
  List<String> problems,
) {
  final Map<String, String> paths = <String, String>{};

  String? resolve(String id, Set<String> visiting) {
    final String? cached = paths[id];
    if (cached != null) {
      return cached;
    }
    final Node? node = byId[id];
    if (node == null) {
      return null;
    }
    if (!visiting.add(id)) {
      problems.add('父边有环：`$id`');
      return null;
    }
    final List<String> parents = mainParents[id] ?? const <String>[];
    final String path;
    if (parents.isEmpty) {
      path = node.slug;
    } else {
      final String? base = resolve(parents.first, visiting);
      if (base == null) {
        return null;
      }
      path = '$base/${node.slug}';
    }
    paths[id] = path;
    return path;
  }

  for (final Node node in nodes) {
    resolve(node.id, <String>{});
  }
  if (paths.length != nodes.length) {
    final List<String> missing = <String>[
      for (final Node node in nodes)
        if (!paths.containsKey(node.id)) node.id,
    ];
    // 只报首个未解析节点：这里的问题通常是「一个环带出一整片未解析」，
    // 逐条列会淹没首因。
    problems.add(
      '${missing.length} 个节点算不出 `path`（父链断裂或成环），首个是 `${missing.first}`',
    );
  }
  return paths;
}

/// 每个 `star` 的主父链必须走到轴根（步骤 ④ 第五项）。
void _checkStarChains(
  List<Node> nodes,
  Map<String, Node> byId,
  Map<String, List<String>> mainParents,
  Map<Axis, String> axisRoots,
  List<String> problems,
) {
  for (final Node node in nodes) {
    if (node.levelSlot != LevelSlot.star) {
      continue;
    }
    final String? root = axisRoots[node.axis];
    final Set<String> visiting = <String>{};
    String current = node.id;
    while (true) {
      if (!visiting.add(current)) {
        // 环已在 `_derivePaths` 报过，这里不再重复。
        break;
      }
      final List<String> parents = mainParents[current] ?? const <String>[];
      if (parents.isEmpty) {
        if (current != root) {
          problems.add('`star` 父链未到轴根：`${node.id}` 停在 `$current`');
        }
        break;
      }
      current = parents.first;
    }
  }
}

/// 派生 `path` 全局唯一（`P-07`，独立断言，不由「同父 slug 唯一」推出）。
void _checkPathUnique(Map<String, String> paths, List<String> problems) {
  final Map<String, List<String>> byPath = <String, List<String>>{};
  for (final MapEntry<String, String> entry in paths.entries) {
    byPath.putIfAbsent(entry.value, () => <String>[]).add(entry.key);
  }
  for (final MapEntry<String, List<String>> entry in byPath.entries) {
    if (entry.value.length > 1) {
      problems.add('`path` 重复：`${entry.key}` ← ${entry.value.join(", ")}');
    }
  }
}

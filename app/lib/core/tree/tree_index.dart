/// 容器树的只读视图（`TREE-001`–`008`）。
///
/// ## 这里没有 widget，也没有缓存
///
/// 每一样都从 `PackContent` 现算：子表、`path`、层深、面包屑。缓存会造出第二份
/// 真相 —— 父节点改名后缓存不跟着变，而按 `path` 比对的地方还在用旧值，
/// 没有任何断言会红（`ParentIndex` 的文件头已为 `path` 记过同一条）。
///
/// ## 为什么不吃 `ParentIndex`
///
/// `ParentIndex` 只暴露「给定子节点求父与 `path`」，没有反向索引，也没有
/// 「全部节点」的枚举 —— 而树要的第一件事恰恰是「给定父节点求子节点」。
/// 再造一个索引而不是给 `ParentIndex` 加方法：它的消费者是三元校验与定位，
/// 树是第三个；把反向索引塞进去会让那个类的构造多一份可空入参，而它现在的
/// 不可变契约（装包后即冻结）正是判据之一。
library;

import '../constants.dart';
import '../entities/edge.dart';
import '../entities/node.dart';
import '../enums.dart';
import '../pack/pack_reader.dart';

/// 树里的一行。**不含虚拟根** —— 虚拟根只在面包屑第 1 段（`SPEC-TREE-002`），
/// 不是树的一行（`SPEC-TREE-003` 说树的第一行是三条轴根）。
class TreeRow {
  const TreeRow({
    required this.nodeId,
    required this.label,
    required this.depth,
    required this.path,
    required this.axis,
  });

  final String nodeId;

  /// 展示名（`Node.name`）。面包屑与树行共用，不另取 slug。
  final String label;

  /// 层深：轴根 `0`，每下一级 `+1`。**面包屑段数 = 本值 + 1**（`SPEC-TREE-006`）。
  ///
  /// 不用 `Node.depth` 那个字段：`entity-fields` §2 把它标为「`level_slot` 在
  /// 轴内的序号」，同槽位跨轴恒等（恒星级在任何轴都是恒星级），而这里要的是
  /// **结构深度**（学科轴恒星级 = 2、角色轴恒星级 = 4）。两者在单轴上巧合相等，
  /// 跨轴就分叉 —— 而树的并排视图正是跨轴那一面。
  final int depth;

  /// 完整 `path`，**含轴根段**（`major/01/0101`）。去掉轴根段会让两轴的 `01`
  /// 撞在同一个 `path` 上。
  final String path;

  final Axis axis;
}

/// 面包屑的一段。
class BreadcrumbSegment {
  const BreadcrumbSegment({
    required this.label,
    required this.path,
    required this.nodeId,
  });

  final String label;

  /// 虚拟根为空串 —— 它没有地址，也不可点（`SPEC-TREE-002`）。
  final String path;

  /// 本段落到哪个节点。虚拟根为空串（它不是节点）。
  ///
  /// 与 [path] 分开带：界面点一段要交出去的是**节点 id**（点它是改地址，不是
  /// 「按路径字符串再查一遍」），而 `path` 是地址的字符串形态 —— 两者在这一层
  /// 同源，越往后越不该互相反解。
  final String nodeId;

  bool get isVirtualRoot => path.isEmpty;
}

/// 树索引。不可变：构建后即冻结。
class TreeIndex {
  TreeIndex._(
    this._nodeById,
    this._parentOf,
    this._childIdsOf,
    this._pathOf,
    this._axisRoots,
  );

  /// 从若干包（骨架一条 + 载荷若干条）建一棵树。
  ///
  /// **只认 `main` 父边**：`secondary` 是 0..N 的附加归属（`entity-fields` §3），
  /// 拿它算父链会让同一个节点有两个 `path`，于是面包屑取到哪一条取决于遍历顺序。
  factory TreeIndex.build({required Iterable<PackContent> contents}) {
    final Map<String, Node> nodeById = <String, Node>{};
    final Map<String, String> parentOf = <String, String>{};

    for (final PackContent content in contents) {
      for (final Node node in content.nodes) {
        final Node? previous = nodeById[node.id];
        if (previous != null) {
          throw ArgumentError(
            '节点 id 重复：${node.id}（${previous.packId} 与 ${node.packId}）',
          );
        }
        nodeById[node.id] = node;
      }
      for (final NodeEdge edge in content.edges) {
        if (edge is! ParentEdge || !edge.isMain) {
          continue;
        }
        final String? previous = parentOf[edge.childId];
        if (previous != null && previous != edge.parentId) {
          throw ArgumentError(
            '主父不唯一：${edge.childId}（$previous 与 ${edge.parentId}）',
          );
        }
        parentOf[edge.childId] = edge.parentId;
      }
    }

    // 父在树上、父本身不在节点表里 ⇒ 这条链断在中途。**不计成轴根**：
    // 把它当根会让一个载荷节点凭空变成第二条树根，而它本该挂在某个恒星下。
    parentOf.removeWhere(
      (String child, String parent) =>
          !nodeById.containsKey(child) || !nodeById.containsKey(parent),
    );

    final Map<String, List<String>> childIdsOf = <String, List<String>>{};
    for (final MapEntry<String, String> entry in parentOf.entries) {
      childIdsOf.putIfAbsent(entry.value, () => <String>[]).add(entry.key);
    }
    for (final List<String> siblings in childIdsOf.values) {
      siblings.sort(
        (String a, String b) => _compareSiblings(nodeById[a]!, nodeById[b]!),
      );
    }

    // 轴根 = 该轴第一个「无主父」的节点。骨架三轴各恰好一个（`TREE-001` 表的
    // 「根」行）；多于一个说明数据里出现了第二条无父链，**不静默取第一个** ——
    // 那会让第二棵树从界面上消失，而它还在数据里。
    final Map<Axis, String> axisRoots = <Axis, String>{};
    for (final Node node in nodeById.values) {
      if (parentOf.containsKey(node.id)) {
        continue;
      }
      final String? taken = axisRoots[node.axis];
      if (taken != null) {
        throw ArgumentError('轴 ${node.axis.name} 有两条无父链：$taken 与 ${node.id}');
      }
      axisRoots[node.axis] = node.id;
    }

    final Map<String, String> pathOf = <String, String>{};
    for (final String rootId in axisRoots.values) {
      _assignPaths(
        nodeId: rootId,
        basePath: nodeById[rootId]!.slug,
        nodeById: nodeById,
        childIdsOf: childIdsOf,
        pathOf: pathOf,
        visiting: <String>{},
      );
    }

    return TreeIndex._(
      Map<String, Node>.unmodifiable(nodeById),
      Map<String, String>.unmodifiable(parentOf),
      Map<String, List<String>>.unmodifiable(
        childIdsOf.map(
          (String key, List<String> value) =>
              MapEntry<String, List<String>>(key, List<String>.unmodifiable(value)),
        ),
      ),
      Map<String, String>.unmodifiable(pathOf),
      Map<Axis, String>.unmodifiable(axisRoots),
    );
  }

  final Map<String, Node> _nodeById;
  final Map<String, String> _parentOf;
  final Map<String, List<String>> _childIdsOf;
  final Map<String, String> _pathOf;
  final Map<Axis, String> _axisRoots;

  /// 兄弟排序：官方码升序，无码的排后，再按 `name`，最后按 `id` 兜底。
  ///
  /// 为什么不是「一律按 `name`」：骨架层同一父下的兄弟都是官方条目，码序就是
  /// 目录序 —— 按拼音排会让「01 哲学」排到「11 军事学」后面，与读者手上的那份
  /// 目录对不上。`id` 兜底是为了让相等键的先后可复现：`List.sort` 不稳定。
  static int _compareSiblings(Node a, Node b) {
    final String codeA = a.officialCode ?? '';
    final String codeB = b.officialCode ?? '';
    if (codeA != codeB) {
      if (codeA.isEmpty) {
        return 1;
      }
      if (codeB.isEmpty) {
        return -1;
      }
      return codeA.compareTo(codeB);
    }
    final int byName = a.name.compareTo(b.name);
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  /// 自轴根向下写 `path`；遇到环即停（不抛错，见 [pathOf] 的说明）。
  static void _assignPaths({
    required String nodeId,
    required String basePath,
    required Map<String, Node> nodeById,
    required Map<String, List<String>> childIdsOf,
    required Map<String, String> pathOf,
    required Set<String> visiting,
  }) {
    if (!visiting.add(nodeId)) {
      return;
    }
    pathOf[nodeId] = basePath;
    for (final String childId in childIdsOf[nodeId] ?? const <String>[]) {
      _assignPaths(
        nodeId: childId,
        basePath: '$basePath$pathSeparator${nodeById[childId]!.slug}',
        nodeById: nodeById,
        childIdsOf: childIdsOf,
        pathOf: pathOf,
        visiting: visiting,
      );
    }
    visiting.remove(nodeId);
  }

  /// 已知节点 / 已进树的节点数。
  int get nodeCount => _pathOf.length;

  Node? nodeOf(String nodeId) => _nodeById[nodeId];

  /// 完整 `path`；`null` = 不在树上（孤儿、或 id 未知）。
  String? pathOf(String nodeId) => _pathOf[nodeId];

  /// 层深（轴根 `0`）；`null` = 不在树上。
  int? depthOf(String nodeId) {
    final String? path = _pathOf[nodeId];
    if (path == null) {
      return null;
    }
    // 段数 - 1：`path` 从轴根 slug 起算，轴根本身是 1 段。
    return pathSeparator.allMatches(path).length;
  }

  /// 三条轴根，按 `Axis` 声明序。缺一条说明该轴没装（骨架未装载时全空）。
  List<TreeRow> axisRoots() => <TreeRow>[
    for (final Axis axis in Axis.values)
      if (_axisRoots[axis] != null) _rowOf(_axisRoots[axis]!),
  ];

  /// 子节点行。未知 id 返回空表（不抛错：调用方是界面，空表就是「这一行没展开」）。
  List<TreeRow> childrenOf(String nodeId) => <TreeRow>[
    for (final String childId in _childIdsOf[nodeId] ?? const <String>[])
      _rowOf(childId),
  ];

  /// 子树前序展开（含自己）。深度优先、兄弟有序 —— 界面按这个顺序平铺即可。
  List<TreeRow> subtree(String nodeId) {
    final List<TreeRow> rows = <TreeRow>[];
    void walk(String id) {
      final TreeRow? row = _rowOrNull(id);
      if (row == null) {
        return;
      }
      rows.add(row);
      for (final String childId in _childIdsOf[id] ?? const <String>[]) {
        walk(childId);
      }
    }

    walk(nodeId);
    return rows;
  }

  /// 面包屑 = 虚拟根 + 轴根到本节点。段数 = 层深 + 1（`SPEC-TREE-006`）。
  List<BreadcrumbSegment> breadcrumb(String nodeId) {
    // 先沿主父链收齐 id（轴根在前），再取各自的 `path`：直接用 `path` 切片
    // 只能拿到 slug，而面包屑要显示 `name` —— slug 是地址段、不是标题。
    final List<String> ids = <String>[];
    final Set<String> visiting = <String>{};
    String? current = nodeId;
    while (current != null && visiting.add(current)) {
      ids.insert(0, current);
      current = _parentOf[current];
    }
    if (ids.isEmpty) {
      return const <BreadcrumbSegment>[];
    }
    final List<BreadcrumbSegment> result = <BreadcrumbSegment>[
      const BreadcrumbSegment(
        label: treeVirtualRootLabel,
        path: '',
        nodeId: '',
      ),
    ];
    for (final String id in ids) {
      final String? path = _pathOf[id];
      if (path == null) {
        return const <BreadcrumbSegment>[];
      }
      result.add(
        BreadcrumbSegment(label: _nodeById[id]!.name, path: path, nodeId: id),
      );
    }
    return result;
  }

  /// 换根后的相对 `path`（`SPEC-TREE-005`）：从 `rootId` 起算，不含 `rootId` 本身。
  ///
  /// `null` = 本节点不在 `rootId` 子树下 —— 换根后要留在树里，这判据就是
  /// 「相对路径算得出来」。
  String? relativePath({required String rootId, required String nodeId}) {
    if (rootId == nodeId) {
      return '';
    }
    final String? rootPath = _pathOf[rootId];
    final String? nodePath = _pathOf[nodeId];
    if (rootPath == null || nodePath == null) {
      return null;
    }
    final String prefix = '$rootPath$pathSeparator';
    if (!nodePath.startsWith(prefix)) {
      return null;
    }
    return nodePath.substring(prefix.length);
  }

  /// 按 id 取一行；`null` = 不在树上。
  ///
  /// 公开是为了**换根到中间节点**（`SPEC-TREE-005` 只要求「留在树」，没要求
  /// 新根必须是轴根）：那种情形的根自己不在 [axisRoots] 里，界面得单独为它
  /// 造一行，而行的四个值都该由索引给 —— 界面自己拼一个会让「同一节点两个
  /// 缩进」这种偏差无从复现。
  TreeRow? rowOf(String nodeId) => _rowOrNull(nodeId);

  TreeRow _rowOf(String nodeId) => _rowOrNull(nodeId)!;

  TreeRow? _rowOrNull(String nodeId) {
    final String? path = _pathOf[nodeId];
    final Node? node = _nodeById[nodeId];
    if (path == null || node == null) {
      return null;
    }
    return TreeRow(
      nodeId: nodeId,
      label: node.name,
      depth: depthOf(nodeId)!,
      path: path,
      axis: node.axis,
    );
  }
}

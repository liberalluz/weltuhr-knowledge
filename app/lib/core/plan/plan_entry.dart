/// 定位结果 → 建计划入参（`SPEC-PLAN-016` 第三入口）。
///
/// ## 这一层只做「换算」，不开页面
///
/// 浮层知道「用户圈中了哪几条」，Planner 要知道「根是哪个、主轴是哪条、包版本
/// 组合是什么」。把这段换算放进界面会让 `tree_screen` 同时承担三件事（手势、
/// 换算、路由），而它已经有一件事要做：换根与地址。放进 `core/` 的另一个好处是
/// **可以被纯函数测试** —— 跨子树那条判据不需要拉起一个 widget 才问得出来。
///
/// ## 跨子树为什么直接给 `null`
///
/// `Plan.subtree_root` 只有一个（`entity-definitions` §2）。命中集若散在两条轴上，
/// 它们的公共祖先只能是骨架星（= 整个知识体系），按它建计划等于「按全部内容建」，
/// 而用户在浮层里明明只圈了几个词 —— 那是**把范围悄悄放大**，正是 `PLAN-015`
/// 反复禁止的。所以不出 CTA，由调用方把按钮藏掉（`LocateOverlay.canPlanHere`）。
library;

import '../entities/edge.dart';
import '../entities/node.dart';
import '../entities/plan.dart';
import '../enums.dart';
import '../locate/locator.dart';
import '../pack/pack_reader.dart';

/// 骨架包的 `plugin_id`。骨架在 `packVersions` 里单独一格（`entity-fields` §2），
/// 不混进 `payloads`。
const String skeletonPluginId = 'skeleton';

/// 三个入口最终交给 `PlannerScreen.open` 的四样东西。
class PlanEntry {
  const PlanEntry({
    required this.spaceId,
    required this.subtreeRoot,
    required this.primaryAxis,
    required this.packVersions,
  });

  /// 事件信封上的空间 id：取**第一条可用命中所在包**的 `plugin_id`。
  ///
  /// 跨包命中时空间只能选一个 —— 而 `subtree_root` 已经在同轴上，所以这里取哪条
  /// 的包都不会改变范围，只改变事件记在哪个空间名下。取第一条（排序最强者）是
  /// 「用户最先看到的那个」。
  final String spaceId;

  /// 命中集的公共根。
  final String subtreeRoot;

  /// 公共根所在的轴。
  final Axis primaryAxis;

  final PackVersions packVersions;
}

/// 换算入口。`null` = 这一轮命中圈不出单一子树，调用方**不该**给建计划入口。
PlanEntry? planEntryFor({
  required LocateResult result,
  required List<PackContent> contents,
}) {
  // 筛选类命中（`LocateKind.axis`）不算范围：它写的是 `axisFilter`、不换根
  // （`VIEW-028`）。浮层里那一行 CTA 也是这么过滤的，两处必须同口径。
  final List<LocateHit> hits = result.usableHits
      .where((LocateHit hit) => hit.kind != LocateKind.axis)
      .toList(growable: false);
  if (hits.isEmpty) {
    return null;
  }

  final Map<String, Node> nodes = _nodesOf(contents);
  final Map<String, String> parentOf = _mainParentsOf(contents);

  final List<String> targets = <String>[];
  for (final LocateHit hit in hits) {
    final Node? node = nodes[hit.target];
    if (node == null) {
      // 命中指向一个本进程没有装载的节点（跨包命中时可能只装载了本包）。
      // **不猜**：猜一个根出来，计划的范围就会指向别的包里的同名节点。
      return null;
    }
    targets.add(node.id);
  }

  final Axis axis = nodes[targets.first]!.axis;
  for (final String target in targets) {
    if (nodes[target]!.axis != axis) {
      // 跨轴 = 跨子树。公共祖先只能退到骨架星，那等于全量范围。
      return null;
    }
  }

  List<String>? common;
  for (final String target in targets) {
    final List<String>? chain = _chainToRoot(target, parentOf);
    if (chain == null) {
      // 父链成环：数据坏了，不是「跨子树」。给 `null` 让界面别建，
      // 具体原因留给包校验（`TreeIndex.build` 会先抛）。
      return null;
    }
    common = common == null ? chain : _commonSuffix(common, chain);
    if (common.isEmpty) {
      return null;
    }
  }

  final String rootId = common!.first;
  final Node root = nodes[rootId]!;
  if (root.axis != axis) {
    // 公共根爬到了轴之外：同轴命中也会有这种情形（同轴两条无父链）。
    return null;
  }

  return PlanEntry(
    spaceId: hits.first.packId,
    subtreeRoot: rootId,
    primaryAxis: root.axis,
    packVersions: packVersionsOf(contents),
  );
}

/// 现拼 `PackVersions`：骨架单独一格，其余包进 `payloads`。
///
/// **缺字段抛错、不填默认**（`SPEC-FND-014`）：空版本号写进事件之后，事后只能
/// 回答「不知道当时是哪个版本」，而计划的可解释性正是靠这一格。
PackVersions packVersionsOf(List<PackContent> contents) {
  String? skeleton;
  final Map<String, String> payloads = <String, String>{};
  for (final PackContent content in contents) {
    final String pluginId = content.pack.pluginId;
    final String version = content.pack.version.trim();
    if (version.isEmpty) {
      throw StateError('包 $pluginId 缺 version');
    }
    if (pluginId == skeletonPluginId) {
      if (skeleton != null) {
        throw StateError('装载了两个骨架包');
      }
      skeleton = version;
      continue;
    }
    if (payloads.containsKey(pluginId)) {
      throw StateError('同一个包装载了两次：$pluginId');
    }
    payloads[pluginId] = version;
  }
  if (skeleton == null) {
    throw StateError('已装载的包里没有骨架（plugin_id = $skeletonPluginId）');
  }
  return PackVersions(skeleton: skeleton, payloads: payloads);
}

/// 全部已装载包的 `Node.id → Node`。同一 id 出现两次视为数据坏了。
Map<String, Node> _nodesOf(List<PackContent> contents) {
  final Map<String, Node> nodes = <String, Node>{};
  for (final PackContent content in contents) {
    for (final Node node in content.nodes) {
      if (nodes.containsKey(node.id)) {
        throw StateError('节点 id 重复：${node.id}');
      }
      nodes[node.id] = node;
    }
  }
  return nodes;
}

/// 全部已装载包的 `子 → 主父`。只收 `main` 边（`ParentIndex` 同口径）：
/// `secondary` 是附加归属，拿它算父链会得到多条路径。
Map<String, String> _mainParentsOf(List<PackContent> contents) {
  final Map<String, String> parentOf = <String, String>{};
  for (final PackContent content in contents) {
    for (final ParentEdge edge in content.edges.whereType<ParentEdge>()) {
      if (edge.isMain) {
        parentOf[edge.childId] = edge.parentId;
      }
    }
  }
  return parentOf;
}

/// `[自己, 父, …, 根]`。成环时返回 `null`。
List<String>? _chainToRoot(String nodeId, Map<String, String> parentOf) {
  final List<String> chain = <String>[];
  final Set<String> seen = <String>{};
  String? current = nodeId;
  while (current != null) {
    if (!seen.add(current)) {
      return null;
    }
    chain.add(current);
    current = parentOf[current];
  }
  return chain;
}

/// 两条「自己→根」链的**公共后缀**。
///
/// 为什么是后缀而不是前缀：链是自下而上写的，而「公共祖先」= 两条链共有的
/// **上段**。取前缀会得到「从自己开始到第一次分叉」—— 那一段只有一条命中时
/// 会把范围放大成整个轴根（单条命中的正确范围是它自己）。
///
/// 返回值仍按自下而上排，所以首元素就是最深公共祖先。
List<String> _commonSuffix(List<String> a, List<String> b) {
  final int limit = a.length < b.length ? a.length : b.length;
  int i = 0;
  while (i < limit && a[a.length - 1 - i] == b[b.length - 1 - i]) {
    i++;
  }
  return a.sublist(a.length - i);
}

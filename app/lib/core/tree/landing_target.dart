/// 落点 → 树界面状态（`SPEC-TREE-010` / `013` / `014`）。
///
/// ## 为什么要这一层
///
/// [LandingResolver] 只回答「落点解析成什么」，`TreeScreen` 存的是「当前根 +
/// 当前地址」两个**节点 id**。两者之间差一步：解析结果给的是地址（`path`
/// 字符串），而界面状态按身份（`nodeId`）存。这一步以前没有落点来源，所以
/// 只在 `TreeScreen` 内部按「点一行改一个 id」实现；一旦落点可以从任意处进来
/// （搜索、详情页、包列表），「根要不要跟着动」就成了必须写死的一条判据 ——
/// 而不是某个页面的偶然行为。
///
/// ## 根为什么换到「目标所在轴」而不是目标自己
///
/// `SPEC-TREE-003` 让三条轴根永远并列，`SPEC-TREE-012` 让行集合从根一路展开到
/// 地址。把根设成目标自己的话，目标**祖先链**整条从画面上消失 —— 而用户从
/// 详情页跳进树，想看的恰恰是「它挂在哪条链上」。换成目标所在轴根之后：
/// 三条轴根仍在、链条从轴根铺到目标、各层兄弟都在，地址不变。
///
/// 反过来说，**同地不动根**也是判据：目标已经在当前根子树里时换根，会把用户
/// 自己刚选的那个视角（可能就是一个深层节点）无故推开。
///
/// ## 第四类为什么不返回新地址
///
/// `SPEC-TREE-010` 判的是「地址变没变」，第四类的裁定是**不变**。所以这里把
/// 传进来的当前根与当前地址原样还回去 —— 让「不变」成为返回值里看得见的事实，
/// 而不是靠调用方「记得别改」。`SPEC-TREE-014` 再补一句：它也不裁剪行集合。
library;

import '../entities/node.dart';
import '../entities/pack.dart';
import '../pack/pack_reader.dart';
import 'landing.dart';
import 'tree_index.dart';

/// 一次落点之后的树状态。`filterTag` 与另外两项**不是**互斥关系：第四类落点
/// 三项全给（地址项是原值），前三类只给前两项。
class TreeTarget {
  const TreeTarget({
    required this.rootId,
    required this.addressId,
    this.filterTag,
  });

  final String rootId;
  final String addressId;

  /// 要加的筛选条件；`null` = 本次落点不筛。
  final String? filterTag;
}

/// 把 [landing] 落成树状态。未命中返回 `null` = **状态一个字都不改**。
///
/// [currentRootId] / [currentAddressId] 是落点前的值：第四类落点要原样还回去，
/// 前三类要靠它们判「同地还是异地」。
TreeTarget? landInTree({
  required TreeIndex tree,
  required LandingResolver resolver,
  required Landing landing,
  required String currentRootId,
  required String currentAddressId,
}) {
  final LandingResult? result = resolver.resolve(landing);
  if (result == null) {
    return null;
  }

  final String? filterTag = result.filterTag;
  if (filterTag != null) {
    // 第四类：坐标语义，**不改地址也不动根**（`SPEC-TREE-010` / `014`）。
    return TreeTarget(
      rootId: currentRootId,
      addressId: currentAddressId,
      filterTag: filterTag,
    );
  }

  final String? nodeId = result.nodeId;
  if (nodeId == null) {
    // `resolve` 的两态互斥保证走不到这里；留着是为了让「改地址却没有目标」
    // 这种不可能状态显式返回 `null`，而不是被 `!` 变成一个运行时崩溃。
    return null;
  }

  // 同地：目标已在当前根子树内 ⇒ 根不动，只改地址。
  if (tree.relativePath(rootId: currentRootId, nodeId: nodeId) != null) {
    return TreeTarget(rootId: currentRootId, addressId: nodeId);
  }

  // 异地：根换到**目标所在轴的轴根**，不是目标自己（理由见文件头）。
  final Node? node = tree.nodeOf(nodeId);
  if (node == null) {
    return null;
  }
  for (final TreeRow row in tree.axisRoots()) {
    if (row.axis == node.axis) {
      return TreeTarget(rootId: row.nodeId, addressId: nodeId);
    }
  }
  // 节点在树上却找不到它的轴根：只可能是索引自身不自洽，交回调用方别猜。
  return null;
}

/// 从包集合现算 `LandingResolver` 要的 `pluginId → 根 id`。
///
/// 三种包分得开：
/// - **载荷**（有 `payload.attach_to`）⇒ 只有一个根，就是它挂上去的那个恒星；
/// - **骨架**（`kinds` 为空）⇒ 三条轴根，按轴序 —— 落点取第一个算得出 `path` 的，
///   因为地址只能是一处；
/// - **overlay / terrain / method** ⇒ **不给根**。这三类不覆盖子树，落点找不到
///   位置就是「跳不过去」，编一个根出来会让它显成一个不存在的位置。
///
/// 不在这里读 `Pack` 之外的任何东西：`attachTo` 是要占位的那颗恒星，而它是否
/// 真的在树上由 [LandingResolver] 用 `pathOf` 判 —— 两层各管一件事。
Map<String, List<String>> packRootsOf({
  required TreeIndex tree,
  required Iterable<PackContent> contents,
}) {
  final List<String> axisRootIds = <String>[
    for (final TreeRow row in tree.axisRoots()) row.nodeId,
  ];
  final Map<String, List<String>> roots = <String, List<String>>{};
  for (final PackContent content in contents) {
    final Pack pack = content.pack;
    final String? attachTo = pack.payload?.attachTo;
    if (attachTo != null && attachTo.isNotEmpty) {
      roots[pack.pluginId] = <String>[attachTo];
    } else if (pack.kinds.isEmpty) {
      roots[pack.pluginId] = axisRootIds;
    }
  }
  return roots;
}

/// `child → 主父` 的索引，以及由它派生的 `path`（`path-rules` `P-01` / `P-02`）。
///
/// ## 为什么必须有这一个 `Map`
///
/// `attach_to` 装包时物化为一条跨包 `main` `ParentEdge`（`minimal-pack.md` §4.1），
/// 于是「一个节点的主父」在数据里**只有一个来源** —— 这张 `Map`。
/// 若不物化，`pathOf` 就得同时处理「同包父边」与「manifest 的 `attach_to`」两种
/// 来源，而面包屑、圈定范围、`Plan.subtree_root` 判定的下游全要各写一遍二选一。
///
/// ## `path` 是算出来的，不是存的（`P-01`）
///
/// 这里**不缓存**任何 `path`。缓存会造出两份真相：父节点改名后缓存不跟着变，
/// 而所有按 `path` 比对的地方都还在用旧值 —— 没有断言会红。所以 `pathOf` 每次
/// 都从父链重算；`B13b` 骨架落地后也不会改这一点。
///
/// ## 骨架 `path` 由外部注入（`minimal-pack.md` §4.2）
///
/// 笔 2 时骨架数据尚不存在，所以骨架父的 `path` 由调用方给出。
/// **不许**为此内置一份假骨架 —— 那会成为第二份骨架数据，且它在 `B13b`
/// 落地那天不会自动消失。
library;

import '../constants.dart';

/// 主父索引。不可变：包与骨架装载后即冻结，进度归事件流。
class ParentIndex {
  ParentIndex({
    required Map<String, String> mainParentOf,
    required Map<String, String> slugOf,
    required Map<String, String> skeletonPaths,
  }) : _mainParentOf = Map<String, String>.unmodifiable(mainParentOf),
       _slugOf = Map<String, String>.unmodifiable(slugOf),
       _skeletonPaths = Map<String, String>.unmodifiable(skeletonPaths);

  final Map<String, String> _mainParentOf;
  final Map<String, String> _slugOf;
  final Map<String, String> _skeletonPaths;

  /// 该 id 是否属于骨架命名空间。
  ///
  /// 用前缀判定而不是「在 `_skeletonPaths` 里」：后者把「这个 id 是骨架」
  /// 与「这个骨架节点的 path 已知」两件事混成一件，而跨包边界（`P-15`）
  /// 要判的是前者。
  static bool isSkeleton(String nodeId) =>
      nodeId.startsWith(skeletonNodePrefix);

  /// 主父（`null` = 无主父边；骨架节点一律 `null`）。
  String? mainParentOf(String nodeId) => _mainParentOf[nodeId];

  /// 骨架节点的 `path`（`null` = 不是骨架，或该骨架节点未注入）。
  String? skeletonPathOf(String nodeId) => _skeletonPaths[nodeId];

  /// 节点自身的 `slug`（`null` = 未知节点）。
  String? slugOf(String nodeId) => _slugOf[nodeId];

  /// 已知节点（含已注入 path 的骨架节点）。
  bool knows(String nodeId) =>
      _slugOf.containsKey(nodeId) || _skeletonPaths.containsKey(nodeId);

  /// 从轴根到本节点的完整 `path`；`null` = 父链不可达或成环。
  ///
  /// 成环时返回 `null` 而不是抛错：调用方（三元校验器）要把它转成一个**错误码**
  /// 而不是异常 —— 反例夹具的判据是「恰好一个码」，抛异常会把码的判定
  /// 交给异常类型，那就不再可断言了。
  String? pathOf(String nodeId) {
    final String? skeletonPath = _skeletonPaths[nodeId];
    if (skeletonPath != null) {
      return skeletonPath;
    }
    if (!_slugOf.containsKey(nodeId)) {
      return null;
    }

    final List<String> segments = <String>[];
    final Set<String> visiting = <String>{};
    String? current = nodeId;
    while (current != null) {
      // 父链成环：`main` 边本该唯一，但夹具与作者数据都可能造出环，
      // 这里不能靠「上游已经校验过」——遍历到环还继续走就是死循环。
      if (!visiting.add(current)) {
        return null;
      }
      final String? slug = _slugOf[current];
      if (slug == null) {
        return null;
      }
      segments.insert(0, slug);
      final String? parent = _mainParentOf[current];
      if (parent == null) {
        return null;
      }
      final String? base = _skeletonPaths[parent];
      if (base != null) {
        return <String>[base, ...segments].join(pathSeparator);
      }
      current = parent;
    }
    return null;
  }

  /// 祖先链（**不含自己**），从直接父节点向轴根方向。
  ///
  /// 面包屑用；遇到环即停，不抛错。
  List<String> ancestorsOf(String nodeId) {
    final List<String> result = <String>[];
    final Set<String> visiting = <String>{};
    String? current = _mainParentOf[nodeId];
    while (current != null && visiting.add(current)) {
      result.add(current);
      current = _mainParentOf[current];
    }
    return result;
  }
}

/// 三元校验器：`id` / `path` / URI 三元 + `path` 16 条规则（`path-rules.md`）。
///
/// ## 判据从哪来
///
/// 六条码与校验顺序**不是这里自拟的** —— 出处是
/// [`minimal-pack.md`](../../../../docs/specs/minimal-pack.md) §4.3，
/// 而它逐条对应 [`path-rules.md`](../../../../docs/specs/path-rules.md) §六
/// 的七面对应表。本节注释只解释**为什么这么排**，不重新定义规则。
///
/// ## 为什么 fail-fast，而不是「一次报全部」
///
/// 这与 `pack_parse.dart` 的口径**相反**（那里一次报全部问题），理由是两者的
/// 消费者不同：解析层服务构建期修包的人，报全了能一次改完；这里是**验收判据**，
/// 它对每个反例夹具断言「恰好一个码」。若一次报多个，「这个反例到底证明了哪条
/// 规则」就说不清了 —— 而反例的全部价值就在这个归因上（`minimal-pack.md` §五）。
///
/// 顺序不可换：`neg-id-dup` 改 `func` 的 id 会连带让 `edges` 里对它的引用悬空，
/// 但「id 唯一」排在「父链可达」之前，所以只报 `E-ID-DUP`。
library;

import '../constants.dart';
import '../entities/edge.dart';
import '../enums.dart';
import '../graph/parent_index.dart';
import '../json.dart';

/// `id` 不符合 `{plugin_id}:{local_id}`，或含版本号段（`P-01` · `P-09`）。
const String codeIdFormat = 'E-ID-FORMAT';

/// 全库 `id` 重复（`P-07` 的 id 侧）。
const String codeIdDuplicate = 'E-ID-DUP';

/// 计算出的 `path` 与父链不符，或父链不可达 / 成环（`P-02` · `P-03`）。
const String codePathParent = 'E-PATH-PARENT';

/// 同一 `(parent_id, slug)` 出现两次，或两条不同父链拼出同一 `path`（`P-06` · `P-07`）。
const String codePathDuplicate = 'E-PATH-DUP';

/// `slug` 不匹配 `^[a-z0-9-]+$`，或作者使用了 `_` 开头的保留段（`P-04`）。
const String codeSlugFormat = 'E-SLUG-FORMAT';

/// `parent_id` 指向非同包节点，且不是 `attach_to` 申报的那一个（`P-15`）。
const String codeParentCrossPack = 'E-PARENT-CROSS-PACK';

/// 一次校验的结果。
///
/// `codes` 为空即通过；非空时**长度为 1**（fail-fast，见文件头）。
/// `paths` 只在通过时有值 —— 失败时给一半的 `path` 表，只会让人误以为
/// 「差一点就成了」，而失败点之后的部分本来也没算过。
class PathValidation {
  const PathValidation._({required this.codes, required this.paths});

  factory PathValidation.ok(Map<String, String> paths) => PathValidation._(
    codes: const <String>[],
    paths: Map<String, String>.unmodifiable(paths),
  );

  factory PathValidation.failed(String code) => PathValidation._(
    codes: <String>[code],
    paths: const <String, String>{},
  );

  final List<String> codes;

  /// 每个节点 id → 它的 `path`。**这是 `path` 一元的唯一断言形式** ——
  /// `path` 是派生值、包里不存（`P-01`），所以只能拿它和期望映射比。
  final Map<String, String> paths;

  bool get ok => codes.isEmpty;
}

/// 校验一个载荷包。
///
/// [skeletonPaths] 是**骨架父节点的 `path` 注入表**（`nodeId → path`）。
/// 笔 2 用夹具里那三条常量，`B13b` 起换成真骨架 —— **接口不变**。
/// 不内置假骨架：那会变成第二份骨架数据，且 `B13b` 落地那天不会自动消失。
PathValidation validatePack(
  JsonMap pack,
  Map<String, String> skeletonPaths,
) {
  final String pluginId = requireString(pack, 'plugin_id');
  final JsonMap payload = requireMap(pack, 'payload');
  final String attachTo = requireString(payload, 'attach_to');
  final List<JsonMap> nodeJson = requireMapList(pack, 'nodes');
  final List<JsonMap> edgeJson = requireMapList(pack, 'edges');
  final String prefix = '$pluginId$idNamespaceSeparator';

  // ① id 格式 —— 最先：它不合格时后面每一步都建立在错的键上。
  final List<String> nodeIds = <String>[];
  for (final JsonMap node in nodeJson) {
    final String id = requireString(node, 'id');
    if (!_wellFormedId(id, prefix)) {
      return PathValidation.failed(codeIdFormat);
    }
    nodeIds.add(id);
  }

  // ② id 唯一 —— 早于 slug 与父链：重复 id 会让「主父是谁」出现两个答案，
  //    此时再算 path 就是在一个矛盾的前提下计算。
  final Set<String> uniqueIds = <String>{};
  for (final String id in nodeIds) {
    if (!uniqueIds.add(id)) {
      return PathValidation.failed(codeIdDuplicate);
    }
  }

  // ③ slug 格式 —— 早于父链：非法 slug 拼出来的 path 必然非法，
  //    先报格式才能让人知道「问题在字符，不在树结构」。
  final Map<String, String> slugOf = <String, String>{};
  for (int i = 0; i < nodeJson.length; i++) {
    final String slug = requireString(nodeJson[i], 'slug');
    if (!_wellFormedSlug(slug)) {
      return PathValidation.failed(codeSlugFormat);
    }
    slugOf[nodeIds[i]] = slug;
  }

  // ④ 主父映射。`main` 边每节点恰好一条（`entity-fields` §3）——
  //    给第二条即判父链异常。6 个码里没有「主父重复」这一项，
  //    取最近的是 `E-PATH-PARENT`：主父不唯一，父链本来就无从确定。
  final Map<String, String> mainParentOf = <String, String>{};
  for (final JsonMap edge in edgeJson) {
    final Object? type = edge['type'];
    if (type != edgeTypeParent) {
      continue;
    }
    if (edge['kind'] != ParentEdgeKind.main.name) {
      continue;
    }
    final String child = requireString(edge, 'child_id');
    final String parent = requireString(edge, 'parent_id');
    if (mainParentOf.containsKey(child)) {
      return PathValidation.failed(codePathParent);
    }
    mainParentOf[child] = parent;
  }

  // ④ 父链可达 —— 父必须要么是同包节点，要么是已注入 path 的骨架节点。
  //    `neg-path-parent` 打在这一点上：父 id 指向一个不存在的同包节点。
  for (final String id in nodeIds) {
    final String? parent = mainParentOf[id];
    if (parent == null) {
      return PathValidation.failed(codePathParent);
    }
    if (!uniqueIds.contains(parent) && !skeletonPaths.containsKey(parent)) {
      return PathValidation.failed(codePathParent);
    }
  }

  // ⑤ path 构成 —— 由 `ParentIndex` 从父链重算，不读任何缓存。
  final ParentIndex index = ParentIndex(
    mainParentOf: mainParentOf,
    slugOf: slugOf,
    skeletonPaths: skeletonPaths,
  );
  final Map<String, String> paths = <String, String>{};
  for (final String id in nodeIds) {
    final String? path = index.pathOf(id);
    if (path == null) {
      return PathValidation.failed(codePathParent);
    }
    paths[id] = path;
  }

  // ⑥ 同父唯一（`P-06`）与 path 全局唯一（`P-07`）分开断言。
  //    只做前者就宣称唯一性是 `P-07` 明写的常见错法：跨轴同名 slug 拼出的
  //    重合没有任何东西会拦。两条都留下。
  final Set<String> parentSlug = <String>{};
  for (final String id in nodeIds) {
    final String pair = '${mainParentOf[id]}$pathSeparator${slugOf[id]}';
    if (!parentSlug.add(pair)) {
      return PathValidation.failed(codePathDuplicate);
    }
  }
  final Set<String> uniquePaths = <String>{};
  for (final String path in paths.values) {
    if (!uniquePaths.add(path)) {
      return PathValidation.failed(codePathDuplicate);
    }
  }

  // ⑦ 跨包边界（`P-15`）。骨架父**只有一个合法目标**：`attach_to` 申报的那一个，
  //    且**只能有一个节点挂上去** —— `subtree_root` 是单数（本包提供的最上层
  //    槽位只有一个），第二个节点挂同一颗恒星就是绕过 `attach_to` 的越权。
  //    `neg-parent-cross-pack` 正是靠「两条骨架父」被抓到：它把 `var` 的父
  //    改成和 `cs-core` 同一个骨架节点，单看「等于 attach_to」是过得去的。
  final List<String> skeletonAttached = <String>[];
  for (final String id in nodeIds) {
    final String parent = mainParentOf[id]!;
    if (ParentIndex.isSkeleton(parent)) {
      if (parent != attachTo) {
        return PathValidation.failed(codeParentCrossPack);
      }
      skeletonAttached.add(id);
    } else if (!parent.startsWith(prefix)) {
      return PathValidation.failed(codeParentCrossPack);
    }
  }
  if (skeletonAttached.length != 1) {
    return PathValidation.failed(codeParentCrossPack);
  }

  return PathValidation.ok(paths);
}

/// `{plugin_id}:{local_id}`，且 `local_id` 不再含分隔符。
///
/// 后半句是「不带版本号」（`P-09`）的判据形式：`m1-demo:v1:var` 的 local 部分
/// 是 `v1:var`，含分隔符即拒。**不单列一条「禁版本号」的正则** —— 版本号段
/// 长什么样没有尽头（`v1` / `1.0.0` / `2024-01`），而「local_id 里不许有冒号」
/// 是有限的、可判的。
bool _wellFormedId(String id, String prefix) {
  if (!id.startsWith(prefix)) {
    return false;
  }
  final String local = id.substring(prefix.length);
  return local.isNotEmpty &&
      !local.contains(idNamespaceSeparator) &&
      slugPattern.hasMatch(local);
}

/// `^[a-z0-9-]+$`，且不得占用保留段前缀（`P-04`）。
bool _wellFormedSlug(String slug) =>
    !slug.startsWith(reservedSegmentPrefix) && slugPattern.hasMatch(slug);

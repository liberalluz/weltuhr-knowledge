/// 体系（路径模板）—— `entity-fields` §10。
///
/// 笔 5c 之前它与 `content.dart` 里的旧 `Scheme` 同名并存，旧类已随 `Item`
/// 一并删除。
///
/// **跨轴体系不需要新机制**：它本质就是按顺序排好的一串虫洞跳转。
library;

import '../enums.dart';
import '../json.dart';

/// 一条学习路线。
///
/// 校验只有一条，且它本身是「不作检查」：**不校验同轴**（`entity-fields` §10）。
///
/// `nodes[]` 是**集合**（`plan/scope.dart` 取 `toSet()`，之后顺序即丢弃），
/// 书写顺序只是排序建议；逆序代价由 `SchemeOrderCost` 现算，`SPEC-PLAN-012`
/// 明确**允许**逆序存在。**不要在这里加「相邻项须有边」或「不得逆序」**——
/// §10 曾有过这两条，2026-10-25 已删，理由见该节。
///
/// 不在这里做的结构性理由：要整张图（父子 + 先修）的判据都得由有整包上下文的
/// 那一层担，塞进来就得让 `Scheme` 持有 `ParentIndex` 与全部先修边，那它就
/// 无法从 JSON 单独构造，反例也造不出来。
class Scheme {
  const Scheme({
    required this.id,
    required this.name,
    required this.nodes,
    required this.authorityLevel,
  });

  factory Scheme.fromJson(JsonMap json) => Scheme(
    id: requireString(json, 'id'),
    name: requireString(json, 'name'),
    nodes: requireStringList(json, 'nodes'),
    authorityLevel: AuthorityLevel.fromWire(
      requireString(json, 'authority_level'),
    ),
  );

  final String id;
  final String name;

  /// `Node.id` 的有序序列，**可跨轴**。
  final List<String> nodes;

  /// 五档语义值（`official` / `standard` / `textbook` / `reference` / `community`）。
  ///
  /// **废除 `L0`–`L4` 编号**：`L` 前缀在项目内已三处撞名。
  final AuthorityLevel authorityLevel;

  // `inversions`（逆序数）是**派生值**：违反 `required` 先修边的处数，
  // 由 `⪯` 与 [nodes] 算出，不入库。

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'nodes': nodes,
    'authority_level': authorityLevel.name,
  };
}

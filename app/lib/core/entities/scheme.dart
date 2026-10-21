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
/// 三条校验（全部可机器判，`entity-fields` §10）：
///
/// 1. `nodes[]` 相邻两项之间**必须存在** `ParentEdge` 或 `WormholeEdge` ——
///    否则那不是路线，只是一张清单
/// 2. 不得违反 `required` 先修边：`A --required--> B` 时 B 不得排在 A 之前
/// 3. **不校验同轴**
///
/// 三条都**不在这里做**：第 1、2 条要整张图（父子 + 先修），本类只有一串 id；
/// 放进来就得让 `Scheme` 持有 `ParentIndex` 与全部先修边，那它就无法从 JSON
/// 单独构造，反例也造不出来。校验落 `pack_reader`（有整包上下文的那一层）。
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

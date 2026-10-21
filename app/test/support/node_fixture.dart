/// 最小节点夹具 —— 只填「参与判据」的那几个字段。
///
/// 为什么不复用 α 包的 `Item`：`Item` 是旧本体的类，`appliesToNode` 收的是 `Node`。
/// 用 `Item` 反推 `Node` 要先跨 `ItemType → LearnableType` 两个同名枚举，还要给
/// 「六轴里哪一条算轴」编一个答案 —— 那两侧都是 `B13a` 笔 5c 要删的东西，
/// 夹具不该把待删的东西当桥。
///
/// 字段说明见 `entity-fields` §2；`requirements` 取「四格齐备 + 一格缺 + 一格
/// 不可外化」这一组固定值 —— 它不参与本文件的任何判据，只为构造合法节点。
library;

import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/entities/requirement.dart';
import 'package:project_knowledge/core/enums.dart';

const Requirements _requirements = Requirements(<RequirementKey, RequirementState>{
  RequirementKey.boundary: RequirementState.present,
  RequirementKey.justification: RequirementState.present,
  RequirementKey.proposition: RequirementState.present,
  RequirementKey.relation: RequirementState.present,
  RequirementKey.how: RequirementState.missing,
  RequirementKey.tacit: RequirementState.notExternalizable,
});

/// 一个可学节点（`planet` 槽位）。默认三维取「角色轴 / 陈述 / 持久层」。
LearnableNode learnableNode({
  String id = 'pkg:n1',
  Axis axis = Axis.occupation,
  LearnableType type = LearnableType.declarative,
  Layer layer = Layer.persistent,
}) => LearnableNode(
  id: id,
  axis: axis,
  name: '夹具节点',
  slug: 'jujujiedian',
  scope: Scope.s1,
  packId: 'pkg',
  status: NodeStatus.live,
  tags: const <String>[],
  catalogRefs: const <String>[],
  type: type,
  layer: layer,
  requirements: _requirements,
);

/// 一个结构节点。`(discipline, group)` 是 `legalSkeletonSlots` 里的合法对。
StructuralNode structuralNode({
  String id = 'skeleton:n1',
  Axis axis = Axis.discipline,
  LevelSlot slot = LevelSlot.group,
}) => StructuralNode(
  id: id,
  axis: axis,
  levelSlot: slot,
  name: '夹具门类',
  slug: 'jujumenlei',
  scope: Scope.s0,
  packId: 'skeleton',
  status: NodeStatus.live,
  tags: const <String>[],
  catalogRefs: const <String>[],
);

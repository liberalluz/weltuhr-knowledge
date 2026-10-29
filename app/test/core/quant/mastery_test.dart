/// 掌握度取数层的判据（`B6` 笔 2）。
///
/// 三条口径各对应一条裁定：`d` 的分母是可外化格（`QUANT-006`）· `s` 用 `S` 不用
/// `R`（`QUANT-005`）· 打卡式乘封顶系数（`QUANT-008`）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/entities/requirement.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/quant/mastery.dart';

/// 六格里一格「不可外化」、一格缺 —— 分母 5、分子 4 ⇒ `d = 0.8`。
const Requirements _fiveOfSix = Requirements(<RequirementKey, RequirementState>{
  RequirementKey.boundary: RequirementState.present,
  RequirementKey.justification: RequirementState.present,
  RequirementKey.proposition: RequirementState.present,
  RequirementKey.relation: RequirementState.present,
  RequirementKey.how: RequirementState.missing,
  RequirementKey.tacit: RequirementState.notExternalizable,
});

/// 六格全「不可外化」—— 构建期应当已拒收，运行期是防御线。
const Requirements _allTacit = Requirements(<RequirementKey, RequirementState>{
  RequirementKey.boundary: RequirementState.notExternalizable,
  RequirementKey.justification: RequirementState.notExternalizable,
  RequirementKey.proposition: RequirementState.notExternalizable,
  RequirementKey.relation: RequirementState.notExternalizable,
  RequirementKey.how: RequirementState.notExternalizable,
  RequirementKey.tacit: RequirementState.notExternalizable,
});

LearnableNode _node(Requirements requirements) => LearnableNode(
  id: 'pkg:quant',
  axis: Axis.occupation,
  name: '量化夹具',
  slug: 'lianghua',
  scope: Scope.s1,
  packId: 'pkg',
  status: NodeStatus.live,
  tags: const <String>[],
  catalogRefs: const <String>[],
  type: LearnableType.declarative,
  layer: Layer.persistent,
  requirements: requirements,
);

void main() {
  group('掌握度与三层状态（B6 笔 2）', () {
    test('TC-QUANT-032 mastery = d × s：d 按可外化格算，打卡式乘封顶（SPEC-QUANT-004 / SPEC-QUANT-008）', () {
      final LearnableNode node = _node(_fiveOfSix);

      // 分母是 5 不是 6：不可外化那一格不入分母（`QUANT-006`）。
      expect(depthOf(node), closeTo(0.8, 1e-9));
      // `s` 用 `S` 的饱和归一：`S = 30` ⇒ 恰好 0.5（`C-01`）。
      expect(memoryStrengthOf(30), closeTo(0.5, 1e-9));
      expect(
        masteryOf(node: node, stability: 30, isCheckin: false),
        closeTo(0.4, 1e-9),
      );
      // 打卡式照算但乘 0.5，不归零、也不与验证式同值（`QUANT-007` / `QUANT-008`）。
      expect(
        masteryOf(node: node, stability: 30, isCheckin: true),
        closeTo(0.2, 1e-9),
      );
      // 还没有 `SrsState` ⇒ 掌握度为 0，不是「未知」。
      expect(masteryOf(node: node, stability: null, isCheckin: false), 0);
    });

    test('TC-QUANT-033 可外化格为 0 即抛错，不返回默认深度（SPEC-QUANT-006）', () {
      // 构建期拒收之后这条路径不可达；真到这里说明内容侧漏了校验 —— 抛错
      // 而不是给默认值，否则这类项会安静地算出一个假深度且再也没人发现。
      expect(() => depthOf(_node(_allTacit)), throwsStateError);
    });
  });
}

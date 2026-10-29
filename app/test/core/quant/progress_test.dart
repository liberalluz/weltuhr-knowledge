/// 空间进度取数层的判据（`B6` 笔 3）。
///
/// 四条口径各对应一条裁定：进度是离散分数（`QUANT-001`）· 分母原样取
/// `PlanScope.denominator`、分子只数圈内（`QUANT-002`）· 已学只认 `item_passed`
/// （`QUANT-003`）· 两档分开给（`QUANT-015`）。
///
/// 这里**不重复验**「分母不随体系变化」那个算法的本身 —— 那是 `PlanScope` 的
/// 事，`TC-PLAN-032` 已验。本文件只验 `progressOf` **没有自己数分母**。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/entities/requirement.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/plan/scope.dart';
import 'package:project_knowledge/core/quant/progress.dart';

const Requirements _complete = Requirements(<RequirementKey, RequirementState>{
  RequirementKey.boundary: RequirementState.present,
  RequirementKey.justification: RequirementState.present,
  RequirementKey.proposition: RequirementState.present,
  RequirementKey.relation: RequirementState.present,
  RequirementKey.how: RequirementState.present,
  RequirementKey.tacit: RequirementState.present,
});

LearnableNode _node(String id) => LearnableNode(
  id: id,
  axis: Axis.occupation,
  name: '进度夹具',
  slug: 'jindu',
  scope: Scope.s1,
  packId: 'pkg',
  status: NodeStatus.live,
  tags: const <String>[],
  catalogRefs: const <String>[],
  type: LearnableType.declarative,
  layer: Layer.persistent,
  requirements: _complete,
);

/// 有判据 ⇒ `verified`；[isCheckin] 为真（`criteria` 为空）⇒ `checked`。
NodeEntry _entry(String nodeId, {required bool isCheckin}) => NodeEntry(
  nodeId: nodeId,
  summary: null,
  outcomes: const <String>[],
  resources: const <Resource>[],
  aliases: const <String>[],
  keywords: const <String>[],
  body: null,
  steps: const <EntryStep>[],
  selfCheck: const <String>[],
  criteria: isCheckin
      ? const <Criterion>[]
      : const <Criterion>[Criterion(id: 'c1', statement: '能说明')],
  quiz: const <QuizItem>[],
  sourceRefs: const <String>[],
);

void main() {
  test('TC-QUANT-039 进度是离散分数：四项两档已学三 ⇒ (2,1,4)（SPEC-QUANT-001）', () {
    final PlanScope scope = PlanScope(
      nodes: <LearnableNode>[_node('a'), _node('b'), _node('c'), _node('d')],
      denominator: 4,
    );
    final Map<String, NodeEntry> entries = <String, NodeEntry>{
      'a': _entry('a', isCheckin: false),
      'b': _entry('b', isCheckin: false),
      'c': _entry('c', isCheckin: true),
      'd': _entry('d', isCheckin: false),
    };

    final ProgressCounts counts = progressOf(
      scope: scope,
      passed: <String>{'a', 'b', 'c'},
      entryOf: (String id) => entries[id],
    );

    // 三个整数，不存在「四舍五入到 0.75」这一步 —— 这是离散分数不是连续值。
    expect(counts, (verified: 2, checked: 1, total: 4));
    expect(counts.verified + counts.checked, 3);
  });

  test('TC-QUANT-040 分母原样取 scope.denominator、圈外已学项不进分子（SPEC-QUANT-002）', () {
    // 只落两项，但分母是 4 ⇒ total 必须还是 4。若实现自己去数 nodes.length，
    // 这里会得到 2。
    final PlanScope narrow = PlanScope(
      nodes: <LearnableNode>[_node('a'), _node('b')],
      denominator: 4,
    );
    final Map<String, NodeEntry> entries = <String, NodeEntry>{
      'a': _entry('a', isCheckin: false),
      'b': _entry('b', isCheckin: true),
      'zzz': _entry('zzz', isCheckin: false),
    };

    final ProgressCounts scopeOnly = progressOf(
      scope: narrow,
      passed: <String>{'a', 'b'},
      entryOf: (String id) => entries[id],
    );
    expect(scopeOnly.total, 4);
    expect(scopeOnly.verified + scopeOnly.checked, 2);

    // 同一分母、换一套更大的体系（项多两个）⇒ 分母不变，符合「分母是范围规模」。
    final PlanScope wide = PlanScope(
      nodes: <LearnableNode>[_node('a'), _node('b'), _node('c'), _node('d')],
      denominator: 4,
    );
    expect(
      progressOf(
        scope: wide,
        passed: <String>{'a', 'b'},
        entryOf: (String id) => entries[id],
      ).total,
      4,
    );

    // `passed` 里留着换体系后落到线外的旧项 `zzz` —— 它不进分子，否则「已学」
    // 会超过「总数」。
    final ProgressCounts withOutside = progressOf(
      scope: narrow,
      passed: <String>{'a', 'b', 'zzz'},
      entryOf: (String id) => entries[id],
    );
    expect(withOutside.verified + withOutside.checked, 2);
  });

  test('TC-QUANT-041 已学只认 item_passed，与判据有无无关（SPEC-QUANT-003）', () {
    final PlanScope scope = PlanScope(
      nodes: <LearnableNode>[_node('a'), _node('b')],
      denominator: 2,
    );
    final Map<String, NodeEntry> entries = <String, NodeEntry>{
      'a': _entry('a', isCheckin: false),
      'b': _entry('b', isCheckin: false),
    };

    // 在 `passed` 里 ⇒ 计入。
    expect(
      progressOf(
        scope: scope,
        passed: <String>{'a'},
        entryOf: (String id) => entries[id],
      ),
      (verified: 1, checked: 0, total: 2),
    );

    // 不在 `passed` 里 ⇒ 不计，**哪怕这一项有判据**。判据说明「能不能验」，
    // 不说明「验过」—— 用它推已学会让进度凭空涨。
    expect(
      progressOf(
        scope: scope,
        passed: const <String>{},
        entryOf: (String id) => entries[id],
      ),
      (verified: 0, checked: 0, total: 2),
    );
  });

  test('TC-QUANT-042 两档按 criteria 是否为空分计（SPEC-QUANT-015）', () {
    final PlanScope scope = PlanScope(
      nodes: <LearnableNode>[_node('a'), _node('b')],
      denominator: 2,
    );
    final Map<String, NodeEntry> entries = <String, NodeEntry>{
      'a': _entry('a', isCheckin: false),
      'b': _entry('b', isCheckin: true),
    };

    final ProgressCounts counts = progressOf(
      scope: scope,
      passed: <String>{'a', 'b'},
      entryOf: (String id) => entries[id],
    );

    // 两项都已学，但一档一项 —— 合成一个「2/2」就等于抹掉了可信度差异。
    expect(counts, (verified: 1, checked: 1, total: 2));
  });

  test('TC-QUANT-043 圈内为空返回 (0,0,0) 且不抛（SPEC-QUANT-002）', () {
    // 还没选体系 / 体系覆盖 0 —— 合法空态，与 `depthOf` 的「数据坏了」不同。
    const PlanScope empty = PlanScope(nodes: <LearnableNode>[], denominator: 0);

    expect(
      progressOf(
        scope: empty,
        passed: <String>{'a'},
        entryOf: (String id) => null,
      ),
      (verified: 0, checked: 0, total: 0),
    );
  });

  test('TC-QUANT-044 同一项多次 item_passed 仍计 1（SPEC-QUANT-002）', () {
    final PlanScope scope = PlanScope(
      nodes: <LearnableNode>[_node('a')],
      denominator: 1,
    );
    final Map<String, NodeEntry> entries = <String, NodeEntry>{
      'a': _entry('a', isCheckin: false),
    };

    // 两台设备各学一遍 ⇒ `item_passed` 两条事件，但项只有一个：进度按项计，
    // 不按事件计，所以不翻倍。
    final Set<String> passed = <String>{'a'}..add('a');
    expect(
      progressOf(
        scope: scope,
        passed: passed,
        entryOf: (String id) => entries[id],
      ),
      (verified: 1, checked: 0, total: 1),
    );
  });
}

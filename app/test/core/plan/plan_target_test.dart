/// 选择式解算的单元回归（`SPEC-PLAN-016` / `SPEC-PLAN-002` / `SPEC-PLAN-004`）。
///
/// 夹具刻意做成「两个域、其中一项圈外」：
///
/// ```
/// a1 协程      python/async  圈内
/// a2 异步编程   python/async  圈内
/// a3 事件循环   python/async  圈外   ← 邻项，任何选择式都不该收它
/// b1 变量      python/basic  圈内
/// ```
///
/// 圈外那项是本组用例的关键：四种 kind 里**每一种**都要把它挡在外面。只验
/// 「选得对」不验「不越界」，等于只验了一半 —— 而越界那一半没有任何断言会红
/// （预览那边会筛掉，界面报 3、事件里存 4）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/plan/plan_target.dart';

import '../../support/pack_fixture.dart';

LoadedPack _pack() => fixturePack(<FixtureItem>[
  const FixtureItem('a1', '协程', domainId: 'python/async'),
  const FixtureItem('a2', '异步编程', domainId: 'python/async'),
  const FixtureItem('a3', '事件循环', domainId: 'python/async', inScope: false),
  const FixtureItem('b1', '变量', domainId: 'python/basic'),
]);

void main() {
  test('TC-PLAN-062 space 式 = 全部圈内项，顺序按包（SPEC-PLAN-002）', () {
    final PlanTarget target = resolvePlanTarget(
      pack: _pack(),
      selector: const PlanSelector.space(),
    );

    expect(target.resolved, <String>['a1', 'a2', 'b1']);
    expect(target.count, 3);
  });

  test('TC-PLAN-063 domain 式只收该域的圈内项（SPEC-PLAN-002）', () {
    final PlanTarget target = resolvePlanTarget(
      pack: _pack(),
      selector: const PlanSelector.domain('python/async'),
    );

    expect(target.resolved, <String>['a1', 'a2']);
    expect(target.resolved, isNot(contains('a3')), reason: '圈外项是邻项，不进计划');
    expect(target.resolved, isNot(contains('b1')), reason: '别的域不该被带进来');
  });

  test('TC-PLAN-064 item 式：圈内给一项，圈外给空集（SPEC-PLAN-004）', () {
    final PlanTarget inside = resolvePlanTarget(
      pack: _pack(),
      selector: const PlanSelector.item('a2'),
    );
    expect(inside.resolved, <String>['a2']);

    final PlanTarget outside = resolvePlanTarget(
      pack: _pack(),
      selector: const PlanSelector.item('a3'),
    );
    expect(
      outside.resolved,
      isEmpty,
      reason: 'selector 与 resolved 必须自洽：留一项圈外 id，count 会与预览对不上',
    );
  });

  test('TC-PLAN-065 query 式：项命中与域命中都折算成项集，筛选类不计（SPEC-PLAN-016）', () {
    // 项命中：搜标题原文。
    final PlanTarget byItem = resolvePlanTarget(
      pack: _pack(),
      selector: const PlanSelector.query('异步编程'),
    );
    expect(byItem.resolved, <String>['a2']);

    // 域命中：搜域名 —— 用户要的是「为这个域建计划」，不是「为这个名字」。
    final PlanTarget byDomain = resolvePlanTarget(
      pack: _pack(),
      selector: const PlanSelector.query('async'),
    );
    expect(byDomain.resolved, <String>['a1', 'a2']);
    expect(byDomain.resolved, isNot(contains('a3')));

    // 筛选类（轴取值）不算范围：只搜到一个轴值时圈不出任何项。
    final PlanTarget byAxis = resolvePlanTarget(
      pack: _pack(),
      selector: const PlanSelector.query('基础语法'),
    );
    expect(byAxis.resolved, isEmpty);
  });

  test('TC-PLAN-066 selector 往返 JSON，未知 kind 抛（SPEC-PLAN-016）', () {
    const List<PlanSelector> all = <PlanSelector>[
      PlanSelector.space(),
      PlanSelector.domain('python/async'),
      PlanSelector.item('a1'),
      PlanSelector.query('异步'),
    ];
    for (final PlanSelector selector in all) {
      expect(PlanSelector.fromJson(selector.toJson()), selector);
    }

    expect(
      () => PlanSelector.fromJson(<String, Object?>{'kind': 'subgraph'}),
      throwsArgumentError,
      reason: '回落成 space 会让「按子图建的计划」静默变成「整个空间」',
    );
  });

  test('TC-PLAN-067 解算结果存进 target 的 selector 原样保留（SPEC-PLAN-016）', () {
    final PlanTarget target = resolvePlanTarget(
      pack: _pack(),
      selector: const PlanSelector.query('异步'),
    );

    expect(target.toJson()['selector'], <String, Object?>{
      'kind': 'query',
      'query': '异步',
    });
    expect(target.toJson().containsKey('count'), isFalse);
  });
}

/// `planEntryFor` / `packVersionsOf` 的判据回归（`SPEC-PLAN-016` 第三入口）。
///
/// 夹具是一棵两轴的骨架 + 一个载荷包：
///
/// ```
/// sk:root(major) ── sk:sys ── sk:a 甲 / sk:b 乙
/// sk:root-i(interest) ── sk:sys-i ── sk:d 丁
/// python ── py:x 戊（挂在 sk:sys 下）
/// ```
///
/// 三件事各自可验：「公共根 + 主轴」「跨轴不给范围」「包版本现拼、缺就抛」。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/plan/plan_entry.dart';

import '../../support/pack_fixture.dart';

final PackContent _skeleton = fixturePack(
  const <FixtureNode>[
    FixtureNode('sk:root', '学科', slot: LevelSlot.star),
    FixtureNode('sk:sys', '系', slot: LevelSlot.system, parentId: 'sk:root'),
    FixtureNode('sk:a', '甲', parentId: 'sk:sys'),
    FixtureNode('sk:b', '乙', parentId: 'sk:sys'),
    FixtureNode('sk:root-i', '兴趣', slot: LevelSlot.star, axis: Axis.occupation),
    FixtureNode(
      'sk:sys-i',
      '兴趣系',
      slot: LevelSlot.system,
      parentId: 'sk:root-i',
      axis: Axis.occupation,
    ),
    FixtureNode('sk:d', '丁', parentId: 'sk:sys-i', axis: Axis.occupation),
  ],
  pluginId: skeletonPluginId,
  packName: '骨架',
  kinds: const <String>[],
  attachTo: '',
);

final PackContent _payload = fixturePack(
  const <FixtureNode>[FixtureNode('py:x', '戊', parentId: 'sk:sys')],
  pluginId: 'python',
  packName: 'Python',
);

List<PackContent> get _contents => <PackContent>[_skeleton, _payload];

LocateHit _hit(String target, {String packId = skeletonPluginId}) => LocateHit(
  kind: LocateKind.item,
  target: target,
  label: target,
  strength: MatchStrength.exact,
  packId: packId,
  packName: packId,
);

LocateResult _result(List<LocateHit> hits) =>
    LocateResult(query: 'q', hits: hits, state: LocateState.located);

void main() {
  test('两条命中在同一系统下：根是公共父，主轴取该根所在轴（SPEC-PLAN-016）', () {
    final PlanEntry? entry = planEntryFor(
      result: _result(<LocateHit>[_hit('sk:a'), _hit('sk:b')]),
      contents: _contents,
    );

    expect(entry, isNotNull);
    expect(entry!.subtreeRoot, 'sk:sys');
    expect(entry.primaryAxis, Axis.major);
    // 空间取第一条可用命中所在的包。
    expect(entry.spaceId, skeletonPluginId);
  });

  test('单条命中：范围就是它自己（SPEC-PLAN-016）', () {
    final PlanEntry? entry = planEntryFor(
      result: _result(<LocateHit>[_hit('sk:a')]),
      contents: _contents,
    );

    expect(entry?.subtreeRoot, 'sk:a');
    expect(entry?.primaryAxis, Axis.major);
  });

  test('跨轴命中圈不出单一子树 —— 不给范围（SPEC-PLAN-015）', () {
    // `sk:a` 在 major、`sk:d` 在 interest：公共祖先只能是两条轴之上，
    // 按它建计划等于「按全部内容建」（`PLAN-015` 禁止的范围放大）。
    expect(
      planEntryFor(
        result: _result(<LocateHit>[_hit('sk:a'), _hit('sk:d')]),
        contents: _contents,
      ),
      isNull,
    );
  });

  test('筛选类命中（axis）不算范围（SPEC-VIEW-028）', () {
    final LocateHit axisHit = LocateHit(
      kind: LocateKind.axis,
      target: 'major',
      label: '学科',
      strength: MatchStrength.exact,
      packId: skeletonPluginId,
      packName: '骨架',
      axisKey: 'major',
    );
    expect(
      planEntryFor(result: _result(<LocateHit>[axisHit]), contents: _contents),
      isNull,
    );
    // 与落点类混在一起时，只按落点类算范围。
    expect(
      planEntryFor(
        result: _result(<LocateHit>[axisHit, _hit('sk:a')]),
        contents: _contents,
      )?.subtreeRoot,
      'sk:a',
    );
  });

  test('命中指向本进程没装载的节点：不猜根（SPEC-PLAN-016）', () {
    expect(
      planEntryFor(
        result: _result(<LocateHit>[_hit('nope:missing')]),
        contents: _contents,
      ),
      isNull,
    );
  });

  test('跨包命中同轴：取第一条命中所在的包当空间（SPEC-VIEW-031）', () {
    final PlanEntry? entry = planEntryFor(
      result: _result(<LocateHit>[
        _hit('py:x', packId: 'python'),
        _hit('sk:a'),
      ]),
      contents: _contents,
    );

    expect(entry?.spaceId, 'python');
    expect(entry?.subtreeRoot, 'sk:sys');
    expect(entry?.packVersions.payloads['python'], isNotNull);
  });

  test('packVersions 现拼：骨架单独一格，其余进 payloads（SPEC-FND-014）', () {
    final PackVersions versions = packVersionsOf(_contents);
    expect(versions.skeleton, _skeleton.pack.version);
    expect(versions.payloads.keys, <String>['python']);
    expect(versions.payloads['python'], _payload.pack.version);
  });

  test('没有骨架包：抛错，不填默认骨架版本（SPEC-FND-014）', () {
    expect(
      () => packVersionsOf(<PackContent>[_payload]),
      throwsA(isA<StateError>()),
    );
  });

  test('装载了两个骨架包：抛错（SPEC-FND-014）', () {
    expect(
      () => packVersionsOf(<PackContent>[_skeleton, _skeleton]),
      throwsA(isA<StateError>()),
    );
  });
}

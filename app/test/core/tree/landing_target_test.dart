import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/landing.dart';
import 'package:project_knowledge/core/tree/landing_target.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';

import '../../support/tree_fixture.dart';

/// 夹具里骨架是学科三级（`d` → `d-01` → `d-0101`）、专业与角色各一个轴根，
/// 载荷 `python` 挂在 `skeleton:d-0101`。落点用例全部按这张地图走。
void main() {
  late List<PackContent> contents;
  late TreeIndex tree;
  late LandingResolver resolver;

  setUp(() {
    contents = <PackContent>[skeletonFixture(), payloadFixture()];
    tree = TreeIndex.build(contents: contents);
    resolver = LandingResolver(tree, packRootsOf(tree: tree, contents: contents));
  });

  TreeTarget? land(
    Landing landing, {
    String rootId = 'skeleton:d',
    String addressId = 'skeleton:d',
  }) => landInTree(
    tree: tree,
    resolver: resolver,
    landing: landing,
    currentRootId: rootId,
    currentAddressId: addressId,
  );

  test('TC-TREE-044 包根由包自身算，不由调用方注入（`SPEC-TREE-010`）', () {
    final Map<String, List<String>> roots = packRootsOf(
      tree: tree,
      contents: contents,
    );

    // 骨架 `kinds` 为空 ⇒ 三条轴根按轴序；载荷有 `payload.attach_to` ⇒ 只有一个根。
    expect(roots['skeleton'], <String>['skeleton:d', 'skeleton:m', 'skeleton:o']);
    expect(roots['python'], <String>['skeleton:d-0101']);
  });

  test('TC-TREE-045 落点在当前根子树内 ⇒ 根不动，只改地址（`SPEC-TREE-013`）', () {
    final TreeTarget? target = land(const NodeLanding('skeleton:d-0101'));

    expect(target?.rootId, 'skeleton:d', reason: '同地不动根');
    expect(target?.addressId, 'skeleton:d-0101');
    expect(target?.filterTag, isNull);
  });

  test('TC-TREE-046 落点在别的轴 ⇒ 根换到目标所在轴根，不换到目标自己（`SPEC-TREE-013`）', () {
    // 从学科轴根落到角色轴：目标所在轴是角色轴，根跟着到 `skeleton:o`。
    final TreeTarget? target = land(const AxisLanding(Axis.occupation));

    expect(target?.rootId, 'skeleton:o');
    expect(target?.addressId, 'skeleton:o');
  });

  test('TC-TREE-047 包落点跨轴时同样换根（`SPEC-TREE-010` / `013`）', () {
    // 当前根已经在角色轴上，载荷却挂在学科轴上 ⇒ 异地 ⇒ 根回到学科轴根。
    final TreeTarget? target = land(
      const PackLanding('python'),
      rootId: 'skeleton:o',
      addressId: 'skeleton:o',
    );

    expect(target?.rootId, 'skeleton:d');
    expect(target?.addressId, 'skeleton:d-0101');
  });

  test('TC-TREE-048 标签值落点地址与根都原样返回（`SPEC-TREE-010` / `014`）', () {
    final TreeTarget? target = land(
      const TagLanding('green'),
      rootId: 'skeleton:m',
      addressId: 'skeleton:m',
    );

    // 判据是「不变」，所以要断言**原值原样回来** —— 只断言「没抛错」等于没测。
    expect(target?.rootId, 'skeleton:m');
    expect(target?.addressId, 'skeleton:m');
    expect(target?.filterTag, 'green');
  });

  test('TC-TREE-049 未命中的落点返回 `null`，不改任何状态（`SPEC-TREE-010`）', () {
    expect(land(const NodeLanding('skeleton:不存在')), isNull);
    expect(land(const PackLanding('没装的包')), isNull);
  });

  test(
    'TC-TREE-050 落点解析两态互斥：改地址必带节点 id，只筛选必不带（`SPEC-TREE-010`）'
    '（无 SPEC：`TREE-010` 只定「改不改地址」，未规定结果里带哪些字段）',
    () {
      final LandingResult? node = resolver.resolve(
        const NodeLanding('skeleton:d-0101'),
      );
      expect(node?.changesAddress, isTrue);
      // `path` 与 `nodeId` 同带：界面按 id 存地址，只给 `path` 就得反查。
      expect(node?.nodeId, 'skeleton:d-0101');
      expect(node?.path, 'd/d-01/d-0101');

      final LandingResult? tag = resolver.resolve(const TagLanding('digital'));
      expect(tag?.changesAddress, isFalse);
      expect(tag?.nodeId, isNull);
      expect(tag?.path, isNull);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/tree/landing.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';

import '../../support/tree_fixture.dart';

void main() {
  late TreeIndex tree;
  late LandingResolver resolver;

  setUp(() {
    tree = treeFixture();
    resolver = LandingResolver(tree, const <String, List<String>>{
      // 骨架覆盖三轴，落到轴序第一个；载荷只有一个根（`attach_to` 的恒星）。
      'skeleton': <String>['skeleton:d', 'skeleton:m', 'skeleton:o'],
      'python': <String>['skeleton:d-0101'],
    });
  });

  test('节点落点：改地址，落到该节点的 `path`（`SPEC-TREE-010`）', () {
    final LandingResult? result = resolver.resolve(const NodeLanding('skeleton:d-0101'));
    expect(result?.changesAddress, isTrue);
    expect(result?.path, 'd/d-01/d-0101');
    expect(result?.filterTag, isNull);
  });

  test('包落点：改地址，落到该包覆盖子树的根（`SPEC-TREE-010`）', () {
    expect(resolver.resolve(const PackLanding('python'))?.path, 'd/d-01/d-0101');
    expect(resolver.resolve(const PackLanding('skeleton'))?.path, 'd');
  });

  test('轴落点：改地址，换根到该轴根（`SPEC-TREE-010`）', () {
    expect(resolver.resolve(const AxisLanding(Axis.occupation))?.path, 'o');
    expect(resolver.resolve(const AxisLanding(Axis.major))?.path, 'm');
  });

  test('标签值落点：不改地址，只加筛选条件（`SPEC-TREE-010`）', () {
    final LandingResult? result = resolver.resolve(const TagLanding('green'));
    expect(result?.changesAddress, isFalse);
    expect(result?.path, isNull);
    expect(result?.filterTag, 'green');
  });

  test('四类之间只有前三类改地址（`SPEC-TREE-010`）', () {
    expect(
      <Landing>[
        const NodeLanding('skeleton:d'),
        const PackLanding('python'),
        const AxisLanding(Axis.discipline),
      ].every((Landing l) => resolver.resolve(l)!.changesAddress),
      isTrue,
    );
    expect(resolver.resolve(const TagLanding('digital'))!.changesAddress, isFalse);
  });

  test(
    '未命中返回 `null` 而不是抛错'
    '（无 SPEC：`TREE-010` 只定「改不改地址」，未定未命中形态）',
    () {
      expect(resolver.resolve(const NodeLanding('skeleton:不存在')), isNull);
      expect(resolver.resolve(const PackLanding('未安装的包')), isNull);
    },
  );
}

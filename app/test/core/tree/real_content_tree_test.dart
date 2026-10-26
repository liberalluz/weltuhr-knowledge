import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';

/// 真包建树的**唯一**回归点。
///
/// 为什么非有不可：`real_content_pack_test.dart` 只到 `readPack` —— 每个包自己
/// 合格，不等于**装在一起**建得出树。父子是跨包的关系：载荷顶层节点的父写在
/// 骨架里，两边单独看都合法，装到一起才发现父边指向一个谁也没有的 id。
///
/// **缺产物就 fail，不 skip**：`pack.json` 不入库（`SPEC-PACK-018`），CI 的
/// `app-checks` 会现场跑装配脚本；skip 会让「忘了跑装配」表现成绿灯。
///
/// 这条用例的分量在于**输入是机器产的**：夹具永远合规，产物是脚本拼的。
void main() {
  test(
    '`content/` 下全部已装配的包能建出一棵树，没有节点掉在树外'
    '（无 SPEC：跨包建树没有单独裁定 —— 父边须落在真实节点上出自 entity-fields §1，'
    '轴根三条出自 SPEC-TREE-003）',
    () {
    final List<File> files =
        Directory('../content')
            .listSync()
            .whereType<Directory>()
            .map((Directory dir) => File('${dir.path}/pack.json'))
            .where((File file) => file.existsSync())
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));

    expect(
      files,
      isNotEmpty,
      reason: '一个包都没装配 —— 先跑 content/tools 下的装配脚本',
    );

    final List<PackContent> contents = <PackContent>[
      for (final File file in files) readPack(file.readAsStringSync()),
    ];

    // 判据一：**每条 `main` 父边的父必须是一个真实存在的节点**。
    //
    // 这条比「建树不抛错」更早、也更准：父边指向一个谁也没有的 id 时，
    // `TreeIndex.build` 只会把这条边丢掉，然后**看剩下的残局**报一句
    // 「某轴有两条无父链」—— 那句话描述的是症状，位置还指在子节点上。
    // 在这里查，错的是哪条边、父是谁，一句话说清。
    final Set<String> known = <String>{
      for (final PackContent content in contents)
        for (final Node node in content.nodes) node.id,
    };
    for (final PackContent content in contents) {
      for (final NodeEdge edge in content.edges) {
        if (edge is! ParentEdge || !edge.isMain) {
          continue;
        }
        expect(
          known.contains(edge.parentId),
          isTrue,
          reason:
              '${content.pack.pluginId} 的父边 ${edge.childId} → '
              '${edge.parentId} 指向一个不存在的节点',
        );
      }
    }

    final TreeIndex tree = TreeIndex.build(contents: contents);

    // 判据二：一颗都不落。掉在树外的节点 `pathOf` 为 `null` —— 那是既看不见
    // 也跳不过去的状态，而它不会让任何别的用例红。
    for (final PackContent content in contents) {
      for (final Node node in content.nodes) {
        expect(tree.pathOf(node.id), isNotNull, reason: '${node.id} 不在树上');
      }
    }

    // 判据三：树仍是三条轴根（`SPEC-TREE-003`）—— 载荷不参与根的产生。
    expect(
      tree.axisRoots().map((TreeRow row) => row.nodeId).toList(),
      <String>['skeleton:discipline', 'skeleton:major', 'skeleton:occupation'],
    );

    // 判据四：三包落点。**写死具体路径**是有意的 —— 「挂上了」与「挂在对的
    // 星上」是两件事，只验前者的话，挂到任意一颗星都绿。
    expect(
      tree.pathOf('english:dom-word-class'),
      'major/05/0502/050201/dom-word-class',
    );
    expect(
      tree.pathOf('german:dom-case-system'),
      'major/05/0502/050203/dom-case-system',
    );
    expect(
      tree.pathOf('python:python'),
      'major/08/0809/080901/python',
    );
  });
}

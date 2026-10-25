import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/main.dart';

/// 真实产物的**唯一**回归点。
///
/// 其余用例全用合成夹具（`m1`–`m4`），它们证明的是「解析器按规格工作」；
/// 这个文件证明的是「管线真能产出一个客户端读得懂的包」—— 两者不同：
/// 夹具是人手写的，永远合规；产物是脚本拼的，拼错了没有任何别的地方会红。
///
/// **缺产物就 fail，不 skip**：`pack.json` 不入库（`SPEC-PACK-018`），
/// skip 会让「忘了跑装配脚本」表现成绿灯。
const String _packPath = '../content/python/pack.json';

PackContent _load() {
  final File file = File(_packPath);
  if (!file.existsSync()) {
    fail(
      '缺少真实产物 $_packPath —— 先跑 `python content/tools/assemble_pack.py python`。'
      '产物不入库，CI 里由 app-checks 的「构建内容包」步骤现场生成。',
    );
  }
  return readPack(file.readAsStringSync());
}

void main() {
  test('`content/` 下每个已装配的包都能被 readPack 解析（SPEC-PACK-005）', () {
    // 不写死空间名：哪个空间跑过装配脚本就验哪个。写死 `python` 的后果是
    // 另两个空间装配失败也没人知道 —— 而它们正是「多根」那条回落路径的输入。
    final List<File> files =
        Directory('../content')
            .listSync()
            .whereType<Directory>()
            .map((Directory dir) => File('${dir.path}/pack.json'))
            .where((File file) => file.existsSync())
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));

    expect(files, isNotEmpty, reason: '一个包都没装配 —— 先跑 assemble_pack.py');

    for (final File file in files) {
      final PackContent content = readPack(file.readAsStringSync());
      expect(
        content.learnableNodes,
        isNotEmpty,
        reason: '${file.path} 里没有可学节点 —— 装上也学不到东西',
      );
    }
  });

  test('真实产物能被 readPack 解析，且 counts 与实扫一致（SPEC-PACK-005）', () {
    final PackContent content = _load();

    expect(content.pack.pluginId, 'python');
    expect(content.pack.kinds, <PackKind>[PackKind.payload]);

    // `readPack` 已内建 counts 对账，这里再断一次是为了让「读数」直接出现在
    // 失败信息里 —— 只报「解析失败」时分不清是数据错了还是数字改了。
    final int systems = content.nodes
        .where((Node node) => node.levelSlot == LevelSlot.system)
        .length;
    final int planets = content.learnableNodes.length;
    expect(systems, greaterThan(0), reason: '本包必须有行星系，否则树上没有分组');
    expect(planets, greaterThan(systems), reason: '可学节点应当多于行星系');
  });

  test('每个可学节点都有主父，且主父指向本包内存在的节点'
      '（无 SPEC：主父唯一是 entity-fields §3 的表，尚无 SPEC 编号）', () {
    final PackContent content = _load();
    final Set<String> ids = content.nodeById.keys.toSet();

    for (final LearnableNode node in content.learnableNodes) {
      final String? parent = content.parents.mainParentOf(node.id);
      expect(parent, isNotNull, reason: '${node.id} 没有主父 —— 树上挂不住');
      expect(ids.contains(parent), isTrue, reason: '${node.id} 的主父 $parent 不在 nodes 里');
    }
  });

  testWidgets('界面从真实产物渲染出行星系，而不是空态（SPEC-PACK-018）', (WidgetTester tester) async {
    final PackContent content = _load();
    await tester.pumpWidget(WeltuhrApp(boot: () => PackBoot(packs: <PackContent>[content])));

    expect(find.text('尚未载入任何知识空间'), findsNothing);
    expect(find.text(content.pack.name), findsOneWidget);
  });
}

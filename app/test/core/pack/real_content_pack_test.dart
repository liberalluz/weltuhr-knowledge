import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/pack/skeleton_pack.dart';
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
      final String text = file.readAsStringSync();
      final PackContent content = readPack(text);
      if (content.pack.pluginId == 'skeleton') {
        // 骨架包**不是**载荷包（`ADR-0005` 决策 2：内置、不走插件）⇒ 它没有
        // 可学节点，也不该有。反过来要求它「有行星」等于逼装配器造假数据。
        expect(
          content.learnableNodes,
          isEmpty,
          reason: '${file.path} 是骨架包，不该出现行星',
        );
        // 骨架包的判据在 `loadSkeleton`：五项包级校验 + `path` 注入表。
        final SkeletonPack skeleton = loadSkeleton(text);
        expect(
          skeleton.nodeCount,
          greaterThan(0),
          reason: '${file.path} 一个骨架节点都没有',
        );
        expect(skeleton.paths.length, skeleton.nodeCount);
        continue;
      }
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

  test('写出来的内容真的进了 entries 段：摘要 / 正文 / 步骤 / 时长（SPEC-PACK-005）', () {
    // 这一条盯的是 `entries.json` → `pack.json` 这一跳。跳丢了不会有人发现：
    // 界面对空内容一律显示「暂无」，看起来跟「还没写」一模一样。
    final PackContent content = _load();
    final List<NodeEntry> filled =
        content.entries.where((NodeEntry e) => e.steps.isNotEmpty).toList();

    expect(filled, isNotEmpty, reason: '一个带步骤的条目都没有 —— entries.json 没进产物');
    for (final NodeEntry entry in filled) {
      expect(entry.summary, isNotNull, reason: '${entry.nodeId} 有步骤却没有摘要');
      expect(entry.body, isNotNull, reason: '${entry.nodeId} 有步骤却没有正文');
      expect(entry.estMinutes, isNotNull, reason: '${entry.nodeId} 有步骤却没有预计时长');
      expect(
        entry.steps.every((EntryStep step) => step.instruction.trim().isNotEmpty),
        isTrue,
        reason: '${entry.nodeId} 有空指令的步骤',
      );
    }
  });

  test('每条带步骤的条目至少一步复习，且算子合法'
      '（无 SPEC：这条校验在 entity-fields §9.1，尚无 SPEC 编号）', () {
    // 全是「读 / 例」的配方跑得通、进度也涨，只是「学过就忘」不会被任何东西发现
    // ⇒ 只能在装载这一侧拦（同 `SPEC-STEP-027` 对自建方法的处置）。
    final PackContent content = _load();
    final List<NodeEntry> withSteps =
        content.entries.where((NodeEntry e) => e.steps.isNotEmpty).toList();

    expect(withSteps, isNotEmpty);
    for (final NodeEntry entry in withSteps) {
      expect(
        entry.hasReviewStep,
        isTrue,
        reason: '${entry.nodeId} 的步骤全是首学算子（read / example），遗忘曲线被静默绕过',
      );
      for (final EntryStep step in entry.steps) {
        expect(
          ExecutionOperator.values.contains(step.operator),
          isTrue,
          reason: '${entry.nodeId} 出现六类之外的算子',
        );
      }
    }
  });

  test('能力断言与题目严格 1:1，且存在真写的断言而不是模板兜底'
      '（无 SPEC：1:1 是 entity-fields §9.3 的注，尚无 SPEC 编号）', () {
    // 上一笔如实登记过「`criteria` 与 `quiz` 的 1:1 没有任何用例锁住」，
    // 拆开两者的配对四条用例仍全绿。这一条把它补上。
    //
    // 过滤条件是**两侧任一非空**，不是「有题才算」：只剩断言没有题的条目同样是
    // 1:1 被破坏，按「有题」筛会把它整个跳过 —— 判据漏在最该抓的那一侧。
    final PackContent content = _load();
    final List<NodeEntry> paired = content.entries
        .where((NodeEntry e) => e.quiz.isNotEmpty || e.criteria.isNotEmpty)
        .toList();

    expect(paired, isNotEmpty);
    for (final NodeEntry entry in paired) {
      expect(
        entry.criteria.length,
        entry.quiz.length,
        reason: '${entry.nodeId} 的断言数与题目数不等 —— 1:1 被破坏',
      );
      final Set<String> criteriaIds =
          entry.criteria.map((Criterion c) => c.id).toSet();
      for (final QuizItem item in entry.quiz) {
        expect(
          criteriaIds.contains(item.criterionId),
          isTrue,
          reason: '${entry.nodeId} 的题 ${item.id} 指向不存在的断言 ${item.criterionId}',
        );
      }
    }

    // 「能说出：」是装配器在源数据没写断言时的兜底前缀。它还能出现，但不该
    // 一个人都不剩 —— 全剩说明没有一句断言是写出来的。
    final bool hasAuthored = paired.any(
      (NodeEntry e) => e.criteria.any((Criterion c) => !c.statement.startsWith('能说出：')),
    );
    expect(hasAuthored, isTrue, reason: '所有断言都是「能说出：+答案」的模板兜底，没人写真的断言');
  });

  testWidgets('详情页渲染真实步骤，不是「暂无」（SPEC-PACK-005）', (WidgetTester tester) async {
    final PackContent content = _load();
    final NodeEntry entry = content.entries.firstWhere(
      (NodeEntry e) => e.steps.isNotEmpty,
      orElse: () => throw StateError('没有带步骤的条目'),
    );
    final Node node = content.nodeById[entry.nodeId]!;

    await tester.pumpWidget(MaterialApp(home: PlanetScreen(content: content, node: node)));

    expect(find.text('暂无（本包不含步骤）'), findsNothing);
    expect(find.textContaining(entry.steps.first.instruction), findsOneWidget);
  });
}

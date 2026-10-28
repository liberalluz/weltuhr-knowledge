import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/entities/pack.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/graph/terrain_graph.dart';
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
      if (content.pack.hasKind(PackKind.terrain)) {
        // 地形包**没有节点**（`ADR-0005` 决策 4：它只装边，边指向别的包的
        // 节点）⇒ 拿「有没有可学节点」判它，等于逼装配器造假数据。
        // 该判的反过来是「它到底有没有边」：一个没有边的地形包装上也什么都不做。
        expect(content.nodes, isEmpty, reason: '${file.path} 是地形包，不该有节点');
        expect(
          content.edges.whereType<PrerequisiteEdge>(),
          isNotEmpty,
          reason: '${file.path} 是地形包，却一条先修边都没有',
        );
        continue;
      }
      expect(
        content.learnableNodes,
        isNotEmpty,
        reason: '${file.path} 里没有可学节点 —— 装上也学不到东西',
      );
    }
  });

  test('真实地形包与载荷包合成后无跨包环，且强度与必学集合一致（SPEC-FND-005）', () {
    // 这一条盯「跨包合成」在**真实数据**上成立。`TC-FND-021`–`026` 用的是合成
    // 夹具，证明的是「按规格工作」；这里证明的是「管线真能产出一个跨包的地形包、
    // 装载层合得起来」—— 两者的证据力不同。
    //
    // **缺地形包就 fail，不 skip**：`pack.json` 不入库，skip 会让「忘了跑
    // assemble_terrain.py」表现成绿灯，而它正是这条用例的唯一输入。
    final File terrainFile = File('../content/terrain/pack.json');
    if (!terrainFile.existsSync()) {
      fail(
        '缺少真实地形包 ../content/terrain/pack.json —— '
        '先跑 `python content/tools/assemble_terrain.py`。',
      );
    }

    final List<PackContent> packs = Directory('../content')
        .listSync()
        .whereType<Directory>()
        .map((Directory dir) => File('${dir.path}/pack.json'))
        .where((File file) => file.existsSync())
        .map((File file) => readPack(file.readAsStringSync()))
        .toList();

    final TerrainGraph graph = TerrainGraph.of(packs);

    // 跨包环只在合图之后看得见：单看任何一边都只是一条普通边（`B15` 笔 3）。
    expect(graph.cycles, isEmpty, reason: '真实包合成后出现跨包环');

    String prefixOf(String id) => id.split(':').first;
    final List<PrerequisiteEdge> crossing = graph.edges
        .whereType<PrerequisiteEdge>()
        .where((PrerequisiteEdge e) => prefixOf(e.fromId) != prefixOf(e.toId))
        .toList();
    expect(crossing, isNotEmpty, reason: '地形包里没有跨包边 —— 那它就不是地形包');

    // 断的是**不变量**而不是本批那条边的取值：进不进必学集合必须与强度一致。
    // 写死「首条边是 recommended」会随数据改动就红，而它管的是另一件事。
    for (final PrerequisiteEdge edge in crossing) {
      final bool inRequired = graph.requiredEdges.any(
        (PrerequisiteEdge e) => e.fromId == edge.fromId && e.toId == edge.toId,
      );
      expect(
        inRequired,
        edge.isRequired,
        reason:
            '${edge.fromId} → ${edge.toId}：强度是 ${edge.strength.name}，'
            '但${inRequired ? '在' : '不在'}必学集合里',
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
      expect(
        ids.contains(parent),
        isTrue,
        reason: '${node.id} 的主父 $parent 不在 nodes 里',
      );
    }
  });

  testWidgets('界面从真实产物渲染出行星系，而不是空态（SPEC-PACK-018）', (
    WidgetTester tester,
  ) async {
    final PackContent content = _load();
    await tester.pumpWidget(
      WeltuhrApp(boot: () => PackBoot(packs: <PackContent>[content])),
    );

    expect(find.text('尚未载入任何知识空间'), findsNothing);
    expect(find.text(content.pack.name), findsOneWidget);
  });

  test('写出来的内容真的进了 entries 段：摘要 / 正文 / 步骤 / 时长（SPEC-PACK-005）', () {
    // 这一条盯的是 `entries.json` → `pack.json` 这一跳。跳丢了不会有人发现：
    // 界面对空内容一律显示「暂无」，看起来跟「还没写」一模一样。
    final PackContent content = _load();
    final List<NodeEntry> filled = content.entries
        .where((NodeEntry e) => e.steps.isNotEmpty)
        .toList();

    expect(filled, isNotEmpty, reason: '一个带步骤的条目都没有 —— entries.json 没进产物');
    for (final NodeEntry entry in filled) {
      expect(entry.summary, isNotNull, reason: '${entry.nodeId} 有步骤却没有摘要');
      expect(entry.body, isNotNull, reason: '${entry.nodeId} 有步骤却没有正文');
      expect(entry.estMinutes, isNotNull, reason: '${entry.nodeId} 有步骤却没有预计时长');
      expect(
        entry.steps.every(
          (EntryStep step) => step.instruction.trim().isNotEmpty,
        ),
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
    final List<NodeEntry> withSteps = content.entries
        .where((NodeEntry e) => e.steps.isNotEmpty)
        .toList();

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
      final Set<String> criteriaIds = entry.criteria
          .map((Criterion c) => c.id)
          .toSet();
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
      (NodeEntry e) =>
          e.criteria.any((Criterion c) => !c.statement.startsWith('能说出：')),
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

    await tester.pumpWidget(
      MaterialApp(
        home: PlanetScreen(content: content, node: node),
      ),
    );

    expect(find.text('暂无（本包不含步骤）'), findsNothing);
    expect(find.textContaining(entry.steps.first.instruction), findsOneWidget);
  });

  test('TC-PACK-071 域名字表覆盖节点上出现的全部 dom-* 标签（SPEC-PACK-005）', () {
    // 反向覆盖：节点上的标签是**实际用到**的那一批，表里多写几个没人用的名字
    // 无所谓，少写一个就会让界面上那一类退回显示 slug —— 而这条路径不报错。
    final PackContent content = _load();
    final Map<String, String> names = content.pack.domainNames;
    expect(names, isNotEmpty, reason: 'python 压平了域，域名只能靠这张表');

    final Set<String> onNodes = <String>{
      for (final Node node in content.nodes)
        for (final String tag in node.tags)
          if (tag.startsWith('dom-')) tag,
    };
    expect(onNodes, isNotEmpty, reason: '一个 dom-* 标签都没有 —— 那这张表就是死的');
    expect(
      names.keys.toSet().containsAll(onNodes),
      isTrue,
      reason: '查不到名字：${onNodes.difference(names.keys.toSet())}',
    );
    expect(
      names.values.every((String value) => value.trim().isNotEmpty),
      isTrue,
      reason: '有域的名字是空白 —— 那与没有名字一样看不见',
    );
  });

  testWidgets('TC-PACK-072 详情页多一行「所属域」，写中文名而不是 slug（SPEC-PACK-005）', (
    WidgetTester tester,
  ) async {
    final PackContent content = _load();
    final Node withDomain = content.nodes.firstWhere(
      (Node node) => node.tags.any((String tag) => tag.startsWith('dom-')),
    );
    final String? label = domainLabelOf(content, withDomain);
    expect(label, isNotNull);
    // 表里有名字就不许退回 slug —— 退回是「查不到」的降级，不是正常态。
    expect(label!.startsWith('dom-'), isFalse, reason: '仍显示 slug：$label');

    await tester.pumpWidget(
      MaterialApp(
        home: PlanetScreen(content: content, node: withDomain),
      ),
    );
    expect(find.byKey(const Key('planet-domain')), findsOneWidget);
    expect(find.text('所属域：$label'), findsOneWidget);

    // 没有 `dom-*` 标签的节点（骨架 / 不压平的包）整行不出现，而不是写「未知」。
    final Node withoutDomain = content.nodes.firstWhere(
      (Node node) => node.tags.every((String tag) => !tag.startsWith('dom-')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlanetScreen(content: content, node: withoutDomain),
      ),
    );
    expect(find.byKey(const Key('planet-domain')), findsNothing);
  });

  test('TC-PACK-073 表里查不到名字时退回显示标签本身，不显示空白（无 SPEC：降级形态未入册）', () {
    // 真实包里十个域都有名字 ⇒ 上面那条走不到「查不到」这一支。把同一份包换成
    // 空名字表再问一次：降级必须是「显示 slug」，因为空白会被读成「这个节点
    // 不属于任何域」，而真实情况是「属于，只是名字还没写」。
    final PackContent content = _load();
    final Node node = content.nodes.firstWhere(
      (Node n) => n.tags.any((String tag) => tag.startsWith('dom-')),
    );
    final String tag = node.tags.firstWhere((String t) => t.startsWith('dom-'));
    final PackContent withoutNames = PackContent(
      pack: Pack.fromJson(<String, Object?>{
        ...content.pack.toJson(),
        'domainNames': <String, String>{},
      }),
      nodes: content.nodes,
      edges: content.edges,
      entries: content.entries,
      sources: content.sources,
      schemes: content.schemes,
      methods: content.methods,
    );

    expect(domainLabelOf(withoutNames, node), tag);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/entities/entry.dart';
import 'core/entities/node.dart';
import 'core/enums.dart';
import 'core/errors.dart';
import 'core/events/event_store.dart';
import 'core/events/journal_event_store.dart';
import 'core/pack/dart_io_pack_fs.dart';
import 'core/pack/pack_fs.dart';
import 'core/pack/pack_probe.dart';
import 'core/pack/pack_reader.dart';
import 'core/storage/store_layout.dart';
import 'core/tree/landing.dart';
import 'features/tree/tree_screen.dart';

void main() {
  runApp(WeltuhrApp(eventStore: localEventStore()));
}

/// 开发期的事件日志去处。
///
/// 三区仍由 [StoreLayout] 定：只读区就是包根，可写区与事件区落在用户数据目录下
/// （`%APPDATA%\Weltuhr`，非 Windows 退 `$HOME`）。`null` = 这台机器上取不到根，
/// 或者三区撞在一起 —— 此时代码不猜一个路径出来，界面会在建计划后如实说没落盘。
///
/// **制品形态不在这里定**：exe 同级 / bundle 内的目录归 `B8`，与 [devPackRoots]
/// 同口径 —— 开发期只给一个「可改的位置」。
EventStore? localEventStore() {
  final Map<String, String> env = Platform.environment;
  final String? base = env['APPDATA'] ?? env['HOME'];
  if (base == null || base.isEmpty) {
    return null;
  }
  const DartIoPackFs fs = DartIoPackFs();
  final StoreLayout layout;
  try {
    layout = StoreLayout(
      readOnlyRoot: devPackRoots().values.first.first,
      writableRoot: '$base/Weltuhr/writable',
      eventRoot: '$base/Weltuhr/events',
    );
  } on InvalidStoreLayoutError {
    return null;
  }
  final String? path = layout.pathIn(StoreZone.event, journalEventFileName);
  if (path == null || !fs.ensureDir(layout.eventRoot)) {
    return null;
  }
  return JournalEventStore(fs: fs, path: path);
}

/// 启动期装载的结果。**三态，不是一个 `bool`**：
///
/// - 有包：渲染内容；
/// - 一个包都没探到：候选根下没有 `pack.json`（多半是没跑装配脚本）；
/// - 探到了但读不出来：文件在，解析或 IO 有问题。
///
/// 后两种的修法完全不同，所以 [problems] 原样带到界面上，不塌成一句「加载失败」
/// （`SPEC-FND-014`：没数据不许补默认值）。
class PackBoot {
  const PackBoot({
    this.packs = const <PackContent>[],
    this.problems = const <String>[],
  });

  final List<PackContent> packs;
  final List<String> problems;

  bool get isEmpty => packs.isEmpty;
}

/// 开发期装载：按 `devPackRoots()` 的候选根探测，再逐个解析。
///
/// 探测层按 `kind` 分组，同一个包会在四类查询里各出现一次（`Pack.kinds[]` 可多值，
/// 目录名不承载 kind）—— 这里按 `packRoot` 合并，权威的类别以解析出的 `kinds[]`
/// 为准，与 [PackLocation] 的注释同口径。
PackBoot loadDevPacks() {
  const PackFs fs = DartIoPackFs();
  const PackProbe probe = PackProbe(fs);

  final ProbeResult probed = probe.scanRoots(devPackRoots());
  final Map<String, PackLocation> byRoot = <String, PackLocation>{};
  for (final PackLocation location in probed.locations) {
    byRoot.putIfAbsent(location.packRoot, () => location);
  }

  final List<PackContent> packs = <PackContent>[];
  final List<String> problems = <String>[
    // 只报「没探到」的那一类：每个包会在四类查询里各报一次，全列出来是噪音。
    for (final PackProblem problem in probed.problems)
      if (!byRoot.containsKey(_parentOf(problem.path))) problem.toString(),
  ];

  for (final String root in byRoot.keys.toList()..sort()) {
    final PackLocation location = byRoot[root]!;
    final String? text = fs.readString(location.packPath);
    if (text == null) {
      problems.add('读不出来：${location.packPath}');
      continue;
    }
    try {
      packs.add(readPack(text));
    } on PackContentException catch (error) {
      // 只带前三条：一个包坏了通常坏一片，界面不是日志。
      final String head = error.problems.take(3).join('；');
      problems.add(
        '${location.packPath}：${error.problems.length} 处不合格'
        '${head.isEmpty ? '' : '（$head）'}',
      );
    }
  }

  return PackBoot(packs: packs, problems: problems);
}

/// `a/b/pack.json` → `a/b`。探测层报的是文件路径，装载层按目录合并，得回退一级。
String _parentOf(String filePath) {
  final int cut = filePath.lastIndexOf('/');
  return cut < 0 ? filePath : filePath.substring(0, cut);
}

/// 应用外壳。
///
/// [boot] 可注入：`test` 里不碰真实磁盘（`flutter test` 的 CWD 下没有内容包，
/// 真去读只会得到一条「探不到」—— 那样测的就不是界面，而是本机目录结构）。
class WeltuhrApp extends StatefulWidget {
  const WeltuhrApp({super.key, this.boot, this.eventStore});

  final PackBoot Function()? boot;

  /// 事件存储。一路传到 `TreeScreen` —— 建计划要写 `plan_created`，而写事件
  /// 归最上面这一层决定（`planner_screen.dart` 文件头：面板只交草稿）。
  /// `null` = 没接（测试 / 取不到数据目录），界面会如实说没落盘。
  final EventStore? eventStore;

  @override
  State<WeltuhrApp> createState() => _WeltuhrAppState();
}

class _WeltuhrAppState extends State<WeltuhrApp> {
  late final PackBoot _boot = (widget.boot ?? loadDevPacks)();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weltuhr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF534AB7),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: _boot.isEmpty
          ? EmptySpaceScreen(problems: _boot.problems)
          : (_boot.packs.length == 1
                ? SpaceScreen(
                    content: _boot.packs.first,
                    contents: _boot.packs,
                    eventStore: widget.eventStore,
                  )
                : PackListScreen(
                    packs: _boot.packs,
                    eventStore: widget.eventStore,
                  )),
    );
  }
}

/// 空态页。
///
/// 两句话是分开的：「尚未载入」是常态，`problems` 是**具体原因**。把两者合成
/// 一句「加载失败」，用户就分不清该去跑装配脚本，还是该查那个文件为什么读不出。
class EmptySpaceScreen extends StatelessWidget {
  const EmptySpaceScreen({super.key, this.problems = const <String>[]});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Weltuhr', style: text.headlineMedium),
              const SizedBox(height: 12),
              Text('尚未载入任何知识空间', style: text.bodyLarge),
              if (problems.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                Text(
                  '候选根下没有可用的包：',
                  style: text.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                for (final String problem in problems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(problem, style: text.bodySmall),
                  ),
                const SizedBox(height: 16),
                Text(
                  '先跑 python content/tools/assemble_pack.py',
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 装了多个包时才出现的一层：先选包，再进它的树。
class PackListScreen extends StatelessWidget {
  const PackListScreen({super.key, required this.packs, this.eventStore});

  final List<PackContent> packs;
  final EventStore? eventStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weltuhr')),
      body: ListView.builder(
        itemCount: packs.length,
        itemBuilder: (BuildContext context, int index) {
          final PackContent content = packs[index];
          return ListTile(
            title: Text(content.pack.name),
            subtitle: Text('${content.learnableNodes.length} 个可学节点'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => SpaceScreen(
                  content: content,
                  contents: packs,
                  eventStore: eventStore,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 一个包的树：行星系 → 行星。
///
/// 这只是**按包**的一层导航（先选包，再看它的行星系）。跨包的那棵容器树是另一
/// 个界面（`features/tree`），入口在标题栏 —— 两者不是同一件事：这里回答「这个
/// 包里有什么」，容器树回答「我在知识体系的哪个位置」。
class SpaceScreen extends StatelessWidget {
  const SpaceScreen({
    super.key,
    required this.content,
    this.contents,
    this.eventStore,
  });

  final PackContent content;

  /// 全部已装载的包。容器树是跨包的，只喂本包会得到一片没有父的森林 ——
  /// 载荷的 `attach_to` 指在骨架里。`null` = 只有 [content]。
  final List<PackContent>? contents;

  /// 建计划要写的那条事件归谁存。见 [WeltuhrApp.eventStore]。
  final EventStore? eventStore;

  @override
  Widget build(BuildContext context) {
    // 只取 `system` 槽位当分组：`subtree_root = system` 是本包的声明，
    // 再往上的父（`attach_to` 指向的骨架恒星）不在本包数据里，界面没有它可画。
    final List<Node> systems =
        content.nodes
            .where((Node node) => node.levelSlot == LevelSlot.system)
            .toList()
          ..sort((Node a, Node b) => a.slug.compareTo(b.slug));

    return Scaffold(
      appBar: AppBar(
        title: Text(content.pack.name),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: '容器树',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => TreeScreen(
                  contents: contents ?? <PackContent>[content],
                  // 落点是**包**（`SPEC-TREE-010` 第二类）：从哪个包进来就落到
                  // 它覆盖子树的根。不给的话永远落在轴序第一个根 —— 从载荷包
                  // 进来却看见学科轴根，是「跳到了树里但不是我那个位置」。
                  initialLanding: PackLanding(content.pack.pluginId),
                  eventStore: eventStore,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${content.pack.version} · ${content.learnableNodes.length} 个可学节点',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: systems.length,
        itemBuilder: (BuildContext context, int index) {
          final Node system = systems[index];
          final List<Node> planets =
              content.nodes
                  .where(
                    (Node node) =>
                        node.levelSlot == LevelSlot.planet &&
                        content.parents.mainParentOf(node.id) == system.id,
                  )
                  .toList()
                ..sort((Node a, Node b) => a.slug.compareTo(b.slug));

          return ExpansionTile(
            title: Text(system.name),
            subtitle: Text('${planets.length} 个节点'),
            children: <Widget>[
              for (final Node planet in planets)
                ListTile(
                  dense: true,
                  title: Text(planet.name),
                  subtitle: Text(planetSubtitle(content.entryOf(planet.id))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => PlanetScreen(
                        content: content,
                        node: planet,
                        contents: contents,
                        eventStore: eventStore,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 单个可学节点：能力断言、步骤、题目。
///
/// **空缺照实显示**（「暂无步骤」），不倒推一个默认值：旧数据里 steps / body
/// 一栏都没有，界面若补上"看起来有内容"的占位，读者会把缺数据当成已完成。
class PlanetScreen extends StatelessWidget {
  const PlanetScreen({
    super.key,
    required this.content,
    required this.node,
    this.contents,
    this.eventStore,
  });

  final PackContent content;
  final Node node;

  /// 全部已装载的包 —— 容器树是跨包的，只喂本包会得到一片没有父的森林。
  /// `null` = 只有 [content]，容器树按钮就按单包打开。
  final List<PackContent>? contents;

  /// 建计划要写的那条事件归谁存。见 [WeltuhrApp.eventStore]。
  final EventStore? eventStore;

  @override
  Widget build(BuildContext context) {
    final NodeEntry? entry = content.entryOf(node.id);
    final TextTheme text = Theme.of(context).textTheme;
    // 先落成局部变量再判类型：`node` 是公开字段，Dart 不对它做类型提升。
    final Node current = node;
    final LearnableNode? learnable = current is LearnableNode ? current : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(node.name),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: '在容器树里定位',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => TreeScreen(
                  contents: contents ?? <PackContent>[content],
                  // 落到**节点**（`SPEC-TREE-010` 第一类）：这一页回答「它是
                  // 什么」，进了树才回答「它在知识体系的哪个位置」。
                  initialLanding: NodeLanding(node.id),
                  eventStore: eventStore,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(node.id, style: text.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              Chip(label: Text(node.levelSlot.name)),
              Chip(label: Text(node.scope.wire)),
              if (learnable != null) ...<Widget>[
                Chip(label: Text(learnable.type.name)),
                Chip(label: Text(learnable.layer.name)),
              ],
            ],
          ),
          const Divider(height: 32),
          _Section(title: '概要', body: entry?.summary ?? '暂无'),
          _Section(title: '正文', body: entry?.body ?? '暂无'),
          _Section(
            title: '学习步骤',
            body: (entry == null || entry.steps.isEmpty)
                ? '暂无（本包不含步骤）'
                : entry.steps.map(stepLine).join('\n'),
          ),
          _Section(
            title: '能力断言',
            body: (entry == null || entry.criteria.isEmpty)
                ? '暂无（无断言的条目按打卡式处理，永不毕业）'
                : entry.criteria
                      .map((Criterion criterion) => '· ${criterion.statement}')
                      .join('\n'),
          ),
          _Section(
            title: '题目',
            body: (entry == null || entry.quiz.isEmpty)
                ? '暂无'
                : entry.quiz.map(quizLine).join('\n\n'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: text.bodyMedium),
        ],
      ),
    );
  }
}

/// 一步的显示行：`· 读（首次）读 get 被动一节，记下两条…`
///
/// 抽成函数是为了**锁得住**：判据是「界面上不出现 `read` / `first` 这类内部
/// 枚举」，写在 `build` 里就只能靠 widget 测试翻渲染树去凑，改回 `.name`
/// 也可能因为测试只挑了一条而漏掉。现在它是个纯函数，负例直接打在这上面。
///
/// 兜底写 `?? …wire` / `?? …name` 与 `detail_panel` 的 `?? …name` 同形：
/// 表是覆盖全集的，兜底永不触发；真触发了说明新增了枚举值没补表 ——
/// 那种情形由 `planet_screen_labels_test.dart` 的全集遍历用例先红。
String stepLine(EntryStep step) {
  final String operatorName =
      operatorLabels[step.operator] ?? step.operator.wire;
  final StepPhase phase = step.effectivePhase;
  final String phaseName = stepPhaseLabels[phase] ?? phase.name;
  return '· $operatorName（$phaseName）${step.instruction}';
}

/// 一题的显示块：问 / 答 / 来源括号 `（自由作答 · 自评）`。
///
/// 括号里原本是 `（${item.type.name} · ${item.judge.name}）`，界面上直接露出
/// `freeform` 与 `self` —— 与 [stepLine] 同一个病，同一个修法。
String quizLine(QuizItem item) {
  final String typeName = quizTypeLabels[item.type] ?? item.type.name;
  final String judgeName = quizJudgeLabels[item.judge] ?? item.judge.name;
  return '问：${item.prompt}\n答：${item.answer}\n（$typeName · $judgeName）';
}

/// 节点副标题：**只报 entry 里真有的东西**。
///
/// 判据是「这一条有没有正文/步骤、有没有题」，不是「有没有 entry」：
/// entry 是内容容器，写满正文与五步之后它照样不含题；把「有 entry」读成
/// 「有题目」，列表上就会整片显示「有题目」，点进去第一句却是「暂无」。
///
/// 三态各自可核：无 entry = 暂无内容；有正文无题 = 有正文与步骤；
/// 有正文有题 = 有正文与步骤 · 题目 N。题数取 `quiz.length`，不写死。
String planetSubtitle(NodeEntry? entry) {
  if (entry == null) {
    return '暂无内容';
  }
  final int quizCount = entry.quiz.length;
  final bool hasText = (entry.body ?? '').isNotEmpty || entry.steps.isNotEmpty;
  if (!hasText) {
    return quizCount == 0 ? '暂无内容' : '仅题目 $quizCount';
  }
  return quizCount == 0 ? '有正文与步骤' : '有正文与步骤 · 题目 $quizCount';
}

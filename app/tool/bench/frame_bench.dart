/// 帧预算实测装置（`R-22`）：跑一次，出一行读数。
///
/// ```
/// cd app
/// flutter run --profile -d windows -t tool/bench/frame_bench.dart
/// ```
///
/// ## 它量的到底是什么
///
/// 容器树的**滚动**：地址固定在沿第一条子链下钻到底的那一层（行集合最大，且对
/// 同一份骨架恒定），列表以固定周期上下匀速扫过整个可滚动范围。选滚动而不是
/// 「点开一级」的理由是持续帧 —— 一次性交互只产生两三帧，凑不满一个窗口，而
/// 帧率是**稳态**读数（`STP` §八：中位 fps 承载稳态、p95 承载卡顿）。
///
/// ## 为什么读数是「可复跑」的
///
/// 四件事都被钉住：**窗口**（`C-33`，跑前把窗口调成 `1920×1080` 客户区 ——
/// 装置拿不到窗口就改尺寸，所以它把实测尺寸写进读数行，由 `premiseOk` 判这个
/// 尺寸算不算基准）· **样本**（同一份骨架 + 同一条下钻链 ⇒ 同一个行集合）·
/// **剧本**（固定周期匀速扫，不依赖手势）· **算法**（`core/bench/frame_stats.dart`，
/// 与采集分离、可离线验）。
///
/// ## 退出码
///
/// - `0` —— 出读数了。
/// - `1` —— 没有可用的包（没跑装配脚本），或树建不起来（数据坏了）。
/// - `2` —— 跑完了但这份样本**不能出读数**：样本不足、可滚动范围是 0（没东西
///   可滚 ⇒ 每帧几乎不重绘 ⇒ 读数没有意义）。**不给读数比给一份读不懂的读数好。**
///
/// ## 本装置不在 CI
///
/// 真实 `FrameTiming` 只在真设备上产生（`STP` §八.1）。CI 里跑它只能得到「样本
/// 不足」，那不是判据。故它只出现在 `app/tool/bench/`，不进任何 workflow。
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:project_knowledge/core/bench/frame_stats.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';
import 'package:project_knowledge/core/tree/tree_outline.dart';
import 'package:project_knowledge/features/tree/tree_breadcrumb.dart';
import 'package:project_knowledge/features/tree/tree_view.dart';
import 'package:project_knowledge/main.dart' as app;

import 'frame_report.dart';

/// 场景标识的前缀。读数行里的 `scenario` 由它拼出，细节（根 / 深度 / 行数 /
/// 周期）一并写进去 —— 换一份骨架就是另一组读数，不能与前一组混着比。
const String benchScenarioPrefix = 'tree-scroll';

/// 热身时长：这段时间的帧不进读数（着色器编译、首帧建树都在这段里）。
const Duration benchWarmup = Duration(seconds: 3);

/// 测量时长。取 20 秒：`C-32` 的判据是稳态，样本太短会被一次 GC 带走。
const Duration benchMeasure = Duration(seconds: 20);

/// 一次完整上下来回的周期。
const Duration benchSweep = Duration(seconds: 8);

/// 沿子链最多下钻多少级（到不了就停在叶子上）。
const int benchMaxDrillDepth = 8;

/// 基准窗口提示 —— 打印给人看，不参与任何判据。
const String benchWindowHint = '请把窗口客户区调成 1920x1080（C-33），否则读数只作参考';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: _TreeBench(),
  ));
}

class _TreeBench extends StatefulWidget {
  const _TreeBench();

  @override
  State<_TreeBench> createState() => _TreeBenchState();
}

class _TreeBenchState extends State<_TreeBench>
    with SingleTickerProviderStateMixin {
  final FrameStats _stats = FrameStats();
  final ScrollController _scroll = ScrollController();

  late final AnimationController _sweep;
  Timer? _warmupTimer;
  Timer? _stopTimer;

  TreeIndex? _tree;
  String? _rootId;
  String? _address;
  int _drillDepth = 0;

  bool _collecting = false;
  bool _finished = false;
  Size _windowSize = Size.zero;
  double _devicePixelRatio = 1;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _sweep = AnimationController(vsync: this, duration: benchSweep)
      ..addListener(_sweepTo)
      ..repeat();
    _boot();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _warmupTimer?.cancel();
    _stopTimer?.cancel();
    _sweep.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 装包与建树。**复用产品的那条装载路径**（`main.dart` 的 `loadDevPacks`）：
  /// 装置另写一份探测，量到的就不是用户会看到的那棵树了。
  void _boot() {
    stdout.writeln('frame_bench: $benchWindowHint');
    final app.PackBoot boot = app.loadDevPacks();
    if (boot.packs.isEmpty) {
      _fail(1, '没有可用的包：${boot.problems.join(' / ')}');
      return;
    }
    final TreeIndex tree;
    try {
      tree = TreeIndex.build(contents: boot.packs);
    } on ArgumentError catch (error) {
      _fail(1, '树建不起来（数据坏了）：$error');
      return;
    }
    final String? rootId = firstAxisRootId(tree);
    if (rootId == null) {
      _fail(1, '骨架里没有轴根 —— 装配脚本跑了但装的是载荷包？');
      return;
    }
    final List<String> chain = _chainOf(tree, rootId);
    setState(() {
      _tree = tree;
      _rootId = rootId;
      _address = chain.last;
      _drillDepth = chain.length - 1;
    });
    _warmupTimer = Timer(benchWarmup, _startMeasuring);
  }

  /// 沿**第一条**子链下钻。子序按 `SPEC-TREE-011` 排（官方码升序），所以这条链
  /// 在同一份骨架上是确定的 —— 换一份骨架才换链。
  List<String> _chainOf(TreeIndex tree, String rootId) {
    final List<String> chain = <String>[rootId];
    String current = rootId;
    for (int i = 0; i < benchMaxDrillDepth; i++) {
      final List<TreeRow> children = tree.childrenOf(current);
      if (children.isEmpty) {
        break;
      }
      current = children.first.nodeId;
      chain.add(current);
    }
    return chain;
  }

  void _startMeasuring() {
    if (_finished) {
      return;
    }
    _stats.reset();
    _collecting = true;
    _stopTimer = Timer(benchMeasure, _report);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_collecting) {
      return;
    }
    for (final FrameTiming timing in timings) {
      _stats.add(FrameSample(
        vsyncUs: timing.timestampInMicroseconds(FramePhase.vsyncStart),
        rasterUs: timing.rasterDuration.inMicroseconds,
      ));
    }
  }

  /// 每帧把列表挪到「周期进度 × 可滚动范围」。
  ///
  /// 用 `jumpTo` 而不是 `animateTo`：后者的曲线会把速度分布也带进读数，而
  /// 本装置要的是匀速扫。
  void _sweepTo() {
    if (!_scroll.hasClients) {
      return;
    }
    final double max = _scroll.position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    _scroll.jumpTo(_sweep.value * max);
  }

  Future<void> _report() async {
    if (_finished) {
      return;
    }
    _finished = true;
    _collecting = false;
    final TreeIndex? tree = _tree;
    final String? rootId = _rootId;
    final String? address = _address;
    final FrameSnapshot? snapshot = _stats.snapshot();
    if (tree == null || rootId == null || address == null || snapshot == null) {
      _fail(2, '样本不足：只有 ${_stats.intervals} 个帧间隔'
          '（至少要 $frameStatsMinIntervals 个）');
      return;
    }
    final double extents = _scroll.hasClients
        ? _scroll.position.maxScrollExtent
        : 0;
    if (extents <= 0) {
      _fail(2, '可滚动范围是 0 —— 树没有超出视口，每帧几乎不重绘，读数不可能有意义');
      return;
    }
    final int rows = treeOutline(
      tree: tree,
      rootId: rootId,
      selectedId: address,
    ).length;
    final BenchReport report = BenchReport(
      scenario: '$benchScenarioPrefix/root=$rootId/depth=$_drillDepth'
          '/rows=$rows/sweepMs=${benchSweep.inMilliseconds}',
      windowWidth: _windowSize.width,
      windowHeight: _windowSize.height,
      devicePixelRatio: _devicePixelRatio,
      snapshot: snapshot,
    );
    stdout.writeln('frame_bench: 场景 ${report.scenario}');
    stdout.writeln('frame_bench: 窗口 ${_windowSize.width.toInt()}x'
        '${_windowSize.height.toInt()} @${_devicePixelRatio}x'
        ' ⇒ premiseOk=${report.premiseOk}');
    stdout.writeln(report.toLine());
    await stdout.flush();
    exit(0);
  }

  void _fail(int code, String message) {
    _finished = true;
    _collecting = false;
    stdout.writeln('frame_bench: $message');
    stdout.flush().then((_) => exit(code));
  }

  @override
  Widget build(BuildContext context) {
    _windowSize = MediaQuery.sizeOf(context);
    _devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final TreeIndex? tree = _tree;
    final String? address = _address;
    final String? rootId = _rootId;
    if (tree == null || address == null || rootId == null) {
      return const Scaffold(
        body: Center(child: Text('frame_bench 正在装载包…')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: TreeBreadcrumb(tree: tree, nodeId: address, onJump: _noop),
      ),
      body: TreeView(
        tree: tree,
        rootId: rootId,
        selectedId: address,
        scrollController: _scroll,
        onDrill: _noop,
        onChangeRoot: _noop,
      ),
    );
  }

  /// 装置里不接手势：剧本是滚，不是点。空实现比「假装能点」诚实。
  void _noop(String _) {}
}

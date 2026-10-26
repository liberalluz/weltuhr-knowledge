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
import 'package:project_knowledge/core/bench/bench_gate.dart';
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

/// 等窗口进基准的最长时间（`C-33`）。
///
/// 3 秒的 [benchWarmup] 是给渲染管线热身的，不是给人调窗口的 —— 装置原来在这里
/// 直接开测，于是人手还没拖完窗口，采样已经开始了。等多久是**耐心**而不是判据：
/// 到点仍不是基准就照测，读数标 `premiseOk=false`，不让一次真机运行白跑。
const Duration benchPremisePatience = Duration(seconds: 90);

/// 等待期间多久看一次视口尺寸。取 200 ms：人手拖窗口是「松手才变」的，
/// 再密也看不出更多，而每帧都查等于给待机状态凭空加负担。
const Duration benchGatePoll = Duration(milliseconds: 200);

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
  Timer? _gateTimer;

  /// 从「进入等待」开始计时，交给 [benchGate] 判耐心。
  final Stopwatch _waited = Stopwatch();

  /// 最近一次闸门判定，只用于界面提示（判据在 [benchGate] 里）。
  BenchGate? _gate;

  TreeIndex? _tree;
  String? _rootId;
  String? _address;
  int _drillDepth = 0;

  bool _collecting = false;
  bool _finished = false;
  Size _windowSize = Size.zero;
  double _devicePixelRatio = 1;

  /// 开测那一刻的视口尺寸 —— **读数行写它，不写「出读数时」的尺寸**。
  ///
  /// 采样跨 20 秒，这期间窗口完全可能被拖动；用末帧尺寸写进读数行，等于把
  /// 一段跨两个尺寸的样本标成单一前提。冻结之后中途变过就记进 [_sizeDrifted]，
  /// 由 [_report] 明说这组数不可解释，而不是悄悄取最后一帧。
  Size _measureSize = Size.zero;
  bool _sizeDrifted = false;

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
    _gateTimer?.cancel();
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
    _awaitPremise();
  }

  /// 等视口进基准窗口（`C-33`）再开测。
  ///
  /// 判据本身在 [benchGate]，这里只管「每隔一会儿问一次、并把答案说给人听」。
  /// 等的时候把当前尺寸与剩余时间显示在界面上：只往 stdout 打一行提示，等人的人
  /// 看不见还剩几秒，于是会在采样开始之后才拖窗口 —— 那正是这一笔要修的东西。
  void _awaitPremise() {
    if (_finished) {
      return;
    }
    _waited
      ..reset()
      ..start();
    _gateTimer = Timer.periodic(benchGatePoll, (_) => _pollGate());
    _pollGate();
  }

  void _pollGate() {
    if (_finished) {
      _gateTimer?.cancel();
      return;
    }
    final BenchGate gate = benchGate(
      width: _windowSize.width,
      height: _windowSize.height,
      waited: _waited.elapsed,
      patience: benchPremisePatience,
    );
    if (gate == BenchGate.wait) {
      setState(() => _gate = gate);
      return;
    }
    _gateTimer?.cancel();
    _waited.stop();
    stdout.writeln(gate == BenchGate.start
        ? 'frame_bench: 视口 ${_windowSize.width.toInt()}x'
            '${_windowSize.height.toInt()} 已进基准窗口，预热 '
            '${benchWarmup.inSeconds} s 后开测'
        : 'frame_bench: 等了 ${benchPremisePatience.inSeconds} s 视口仍不是基准'
            '（当前 ${_windowSize.width.toInt()}x'
            '${_windowSize.height.toInt()}）—— 照测，但读数不可按 C-32 解释');
    setState(() => _gate = gate);
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
    _measureSize = _windowSize;
    _sizeDrifted = false;
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
      windowWidth: _measureSize.width,
      windowHeight: _measureSize.height,
      devicePixelRatio: _devicePixelRatio,
      snapshot: snapshot,
    );
    stdout.writeln('frame_bench: 场景 ${report.scenario}');
    stdout.writeln('frame_bench: 窗口 ${_measureSize.width.toInt()}x'
        '${_measureSize.height.toInt()} @${_devicePixelRatio}x'
        ' ⇒ premiseOk=${report.premiseOk}');
    if (_sizeDrifted) {
      // 不进读数行：行里写的是开测时的尺寸，而这一句说的是「这组数跨了两个尺寸」。
      // 两者放同一行的话，读的人会以为尺寸就是行里那个、只是标了一个 false。
      stdout.writeln('frame_bench: ⚠️ 测中窗口变过（开测 '
          '${_measureSize.width.toInt()}x${_measureSize.height.toInt()} → 现在 '
          '${_windowSize.width.toInt()}x${_windowSize.height.toInt()}）'
          '—— 本组读数不可按 C-33 解释');
    }
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
    if (_collecting && _windowSize != _measureSize) {
      _sizeDrifted = true;
    }
    final TreeIndex? tree = _tree;
    final String? address = _address;
    final String? rootId = _rootId;
    if (tree == null || address == null || rootId == null) {
      return const Scaffold(
        body: Center(child: Text('frame_bench 正在装载包…')),
      );
    }
    final Widget treeView = TreeView(
      tree: tree,
      rootId: rootId,
      selectedId: address,
      scrollController: _scroll,
      onDrill: _noop,
      onChangeRoot: _noop,
    );
    return Scaffold(
      appBar: AppBar(
        title: TreeBreadcrumb(tree: tree, nodeId: address, onJump: _noop),
      ),
      // 提示是**浮层**，不进 `Column`：它是给人在等待时看的，而任何改视口高度的
      // 东西都会改掉被量的面积 —— 开测那一刻提示消失，读数就会与「没提示」时不同。
      body: Stack(
        children: <Widget>[
          treeView,
          if (_gate == BenchGate.wait && !_collecting)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _GateNotice(
                width: _windowSize.width.toInt(),
                height: _windowSize.height.toInt(),
                remainSeconds: (benchPremisePatience - _waited.elapsed)
                    .inSeconds
                    .clamp(0, benchPremisePatience.inSeconds),
              ),
            ),
        ],
      ),
    );
  }

  /// 装置里不接手势：剧本是滚，不是点。空实现比「假装能点」诚实。
  void _noop(String _) {}
}

/// 等待提示条：当前尺寸、还差多少、还剩几秒。
///
/// 不给「还差多少」的话，人会去猜 `C-33` 的容差；不给「还剩几秒」的话，人不知道
/// 这件事故意会到期 —— 到点照测，不是失败。
class _GateNotice extends StatelessWidget {
  const _GateNotice({
    required this.width,
    required this.height,
    required this.remainSeconds,
  });

  final int width;
  final int height;
  final int remainSeconds;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          '把窗口客户区调成 ${frameBenchWidth.toInt()}x${frameBenchHeight.toInt()}'
          '（C-33）后自动开测 —— 当前 $width x $height · 还剩 $remainSeconds s',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

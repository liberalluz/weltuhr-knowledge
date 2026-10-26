/// 帧预算实测装置（`R-22`）：跑一次，出一行读数。
///
/// ```
/// cd app
/// flutter run --profile -d windows -t tool/bench/frame_bench.dart
/// ```
///
/// ## 它量的到底是什么
///
/// 容器树的**滚动**：地址取「行集合最大」的那一层（[_pickHeaviestAddress]，
/// 对同一份骨架恒定），列表以固定周期上下匀速扫过整个可滚动范围。选滚动而不是
/// 「点开一级」的理由是持续帧 —— 一次性交互只产生两三帧，凑不满一个窗口，而
/// 帧率是**稳态**读数（`STP` §八：中位 fps 承载稳态、p95 承载卡顿）。
///
/// ## 前提由装置自己保证（`C-33`）
///
/// `C-33` 要 `1920×1080` **物理**客户区。原先的写法是「打印一句提示、等人手把窗口
/// 拖好」，于是四件事里钉住了三件、最关键的第四件靠人 —— 换台机器就是另一组数，
/// 而 `R-22` 要的正是可复跑。现在装置启动时自己把窗口设成那个尺寸（`window_fit.dart`
/// 去掉边框后客户区等于窗口矩形），判定一律读视口的 `physicalSize`。
///
/// ⚠️ 设完之后还要把窗口**提到前台**。这不是锦上添花：后台窗口会被 Windows 判成
/// 被遮挡（occluded），引擎跳过光栅 ⇒ 采样期一个 `FrameTiming` 都收不到。实测过
/// 一次「尺寸全对、20 秒 0 个帧间隔」，报出来的却是「样本不足」—— 那句话把人引向
/// 采样时长，而问题在窗口没到前台。
///
/// ⚠️ **逻辑像素不是物理像素**：`MediaQuery.sizeOf` 给的是逻辑尺寸。两者在 100%
/// 缩放下恰好相等，于是「读错了单位」在那种机器上永远看不见 —— 到 125% 缩放的
/// 机器上逻辑宽 `1536` 永远够不到基准 `1920`，装置只会安静地等到超时，而那段
/// 时间里界面上没有任何东西提示「这不是在等窗口，是永远等不到」。
///
/// ## 为什么地址不能取「沿第一条子链下钻到底」
///
/// `treeOutline` 只沿**选中路径**逐级展开（`SPEC-TREE-003`），不是全展开。学科轴
/// 第一个门类下只有一个一级学科，沿第一条链走八级累计不到二十行 —— 在一屏
/// 三十几行的视口里根本不滚，装置跑完只会报「可滚动范围是 0」。行集合必须由
/// 「哪个地址展开出来的行最多」决定，而不是由「哪条链最简单」决定。
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
import 'dart:ui' show FlutterView, FramePhase, FrameTiming, Size;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:project_knowledge/core/bench/bench_address.dart';
import 'package:project_knowledge/core/bench/bench_gate.dart';
import 'package:project_knowledge/core/bench/frame_stats.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/tree/tree_index.dart';
import 'package:project_knowledge/core/tree/tree_outline.dart';
import 'package:project_knowledge/features/tree/tree_breadcrumb.dart';
import 'package:project_knowledge/features/tree/tree_view.dart';
import 'package:project_knowledge/main.dart' as app;

import 'frame_report.dart';
import 'window_fit.dart';

/// 场景标识的前缀。读数行里的 `scenario` 由它拼出，细节（根 / 深度 / 行数 /
/// 周期）一并写进去 —— 换一份骨架就是另一组读数，不能与前一组混着比。
const String benchScenarioPrefix = 'tree-scroll';

/// 热身时长：这段时间的帧不进读数（着色器编译、首帧建树都在这段里）。
const Duration benchWarmup = Duration(seconds: 3);

/// 测量时长。取 20 秒：`C-32` 的判据是稳态，样本太短会被一次 GC 带走。
const Duration benchMeasure = Duration(seconds: 20);

/// 一次完整上下来回的周期。
const Duration benchSweep = Duration(seconds: 8);

/// 贪心下钻最多走多少级（找行集合最大的地址时用，到不了就停在叶子上）。
const int benchMaxDrillDepth = 8;

/// 等窗口进基准的最长时间（`C-33`）。
///
/// 3 秒的 [benchWarmup] 是给渲染管线热身的，不是给人调窗口的。等多久是**耐心**
/// 而不是判据：到点仍不是基准就照测，读数标 `premiseOk=false`，不让一次真机运行
/// 白跑。
const Duration benchPremisePatience = Duration(seconds: 90);

/// 等待期间多久看一次视口尺寸。取 200 ms：窗口尺寸是「松手才变」的，再密也看
/// 不出更多，而每帧都查等于给待机状态凭空加负担。
const Duration benchGatePoll = Duration(milliseconds: 200);

/// 最多尝试自动设窗几次。
///
/// 正常情况下第一次就成 —— `EnumWindows` 找的是**本进程**的窗口，不看谁在前台
/// （第一版用 `GetForegroundWindow`，从终端 `flutter run` 起来时拿到的永远是终端）。
/// 留多次是为了「窗口还没建出来」这类启动竞态：15 次 × 200 ms ≈ 3 秒。再久就不再
/// 反复调 `SetWindowPos` 了 —— 那会跟人抢焦点，而失败原因该由一行日志说清。
const int benchFitTries = 15;

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

  /// 当前视口（**物理像素**）。基准判定与读数都只认它。
  Size _physical = Size.zero;

  /// 当前视口（逻辑像素）—— 只给人看，不参与任何判据。
  Size _logical = Size.zero;

  double _devicePixelRatio = 1;

  /// 开测那一刻冻结的视口 —— **读数行写它，不写「出读数时」的尺寸**。
  ///
  /// 采样跨 20 秒，这期间窗口完全可能被拖动；用末帧尺寸写进读数行，等于把
  /// 一段跨两个尺寸的样本标成单一前提。冻结之后中途变过就记进 [_sizeDrifted]，
  /// 由 [_report] 明说这组数不可解释，而不是悄悄取最后一帧。
  Size _measurePhysical = Size.zero;
  double _measureDpr = 1;
  bool _sizeDrifted = false;

  /// 已经试过几次自动设窗（见 [benchFitTries]）。
  int _fitTries = 0;

  /// 设窗结果；`null` = 没设上。
  BenchWindowFit? _fit;

  /// 「窗口设上了、视口没跟上」只往 `stdout` 说一次 —— 每 200 ms 说一遍会淹掉
  /// 真正有用的行。
  bool _warnedStale = false;

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
    stdout.writeln('frame_bench: 目标客户区 ${frameBenchWidth.toInt()}x'
        '${frameBenchHeight.toInt()} 物理像素（C-33）');
    _tryFitWindow();
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
    final String address = _addressOf(tree, rootId);
    final List<OutlineRow> rows = treeOutline(
      tree: tree,
      rootId: rootId,
      selectedId: address,
    );
    setState(() {
      _tree = tree;
      _rootId = rootId;
      _address = address;
      _drillDepth =
          (tree.depthOf(address) ?? 0) - (tree.depthOf(rootId) ?? 0);
    });
    stdout.writeln('frame_bench: 行集合 ${rows.length} 行'
        '（根 $rootId · 地址 $address · 相对深度 $_drillDepth）');
    _awaitPremise();
  }

  /// 把窗口设成基准客户区。失败不阻断 —— 只把「为什么等不到」说出来。
  ///
  /// 设上了就不再试：反复调 `SetWindowPos` + `SetForegroundWindow` 会跟人抢焦点，
  /// 而窗口一旦对了，后面只该由闸门判「视口跟上没跟上」。
  void _tryFitWindow() {
    if (!Platform.isWindows || _fit != null || _fitTries >= benchFitTries) {
      return;
    }
    _fitTries++;
    final BenchWindowFit fit = fitBenchWindow(
      width: frameBenchWidth.toInt(),
      height: frameBenchHeight.toInt(),
    );
    if (fit.ok) {
      _fit = fit;
      stdout.writeln('frame_bench: ${fit.reason}并提到前台'
          '${fit.frameless ? '（无边框）' : '（边框没去掉，客户区会比设定值小）'}');
      return;
    }
    if (_fitTries >= benchFitTries) {
      // ⚠️ 这一行以前是**猜**的（「枚举不到本进程的可见顶层窗口？」），而真实原因
      // 是 `GetSystemMetrics` 从 kernel32 查导致绑定在构造期就抛、被吞成 null ——
      // 猜错方向就把人引去查窗口可见性。现在由 [BenchWindowFit.reason] 说清
      // 卡在绑定 / 找窗口 / 改尺寸哪一步，原始错误文本一并带出。
      stdout.writeln('frame_bench: 没能自动设窗口 —— ${fit.reason}'
          '；请手动把客户区调成 ${frameBenchWidth.toInt()}x'
          '${frameBenchHeight.toInt()} 物理像素，否则本组读数不可按 C-32 解释');
    }
  }

  /// 窗口设上了、视口报的尺寸却不是设定值 —— 说清楚，别让人一直等。
  ///
  /// 最常见的原因是显示缩放刚改过而应用没重启（Windows 自己在设置页就提示
  /// 「某些应用在关闭并重新打开后才会响应缩放更改」），此时引擎仍在用旧的 DPR
  /// 换算尺寸。这种情况下等 90 秒也不会变，唯一的处置是重启 app。
  void _warnIfViewStale() {
    if (_warnedStale || _fit == null) {
      return;
    }
    if (_physical.width.toInt() == frameBenchWidth.toInt() &&
        _physical.height.toInt() == frameBenchHeight.toInt()) {
      return;
    }
    _warnedStale = true;
    stdout.writeln('frame_bench: 窗口已设成 ${frameBenchWidth.toInt()}x'
        '${frameBenchHeight.toInt()}，但视口报 ${_physical.width.toInt()}x'
        '${_physical.height.toInt()} —— 改过显示缩放的话请重启 app'
        '（引擎可能在用旧 DPR 换算尺寸）');
  }

  /// 等视口进基准窗口（`C-33`）再开测。
  ///
  /// 判据本身在 [benchGate]，这里只管「每隔一会儿问一次、并把答案说给人听」。
  /// 等的时候把当前尺寸、缩放比与剩余时间显示在界面上：只往 `stdout` 打一行提示，
  /// 等人的人看不见还剩几秒，于是会在采样开始之后才动窗口 —— 那正是这一笔要修的。
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
      physicalWidth: _physical.width,
      physicalHeight: _physical.height,
      waited: _waited.elapsed,
      patience: benchPremisePatience,
    );
    if (gate == BenchGate.wait) {
      // 起来的第一帧里窗口可能还没抢到前台，设不上；等待期间补几次就有了。
      _tryFitWindow();
      _warnIfViewStale();
      setState(() => _gate = gate);
      return;
    }
    _gateTimer?.cancel();
    _waited.stop();
    stdout.writeln(gate == BenchGate.start
        ? 'frame_bench: 视口 ${_physical.width.toInt()}x'
            '${_physical.height.toInt()} 物理已进基准窗口，预热 '
            '${benchWarmup.inSeconds} s 后开测'
        : 'frame_bench: 等了 ${benchPremisePatience.inSeconds} s 视口仍不是基准'
            '（当前 ${_physical.width.toInt()}x${_physical.height.toInt()} 物理'
            ' @${_devicePixelRatio}x）—— 照测，但读数不可按 C-32 解释');
    setState(() => _gate = gate);
    _warmupTimer = Timer(benchWarmup, _startMeasuring);
  }

  /// 挑一个「行集合最大」的地址。
  ///
  /// 判据在 `core/bench/bench_address.dart`（纯函数，`TC-INF-060` 守它）：这里
  /// 只把树、根与步数上限交过去。为什么不在这里就地算 —— 选错地址不会报错，
  /// 装置照样跑满二十秒，错法与「读数怎么算」完全不同，得能离线验。
  String _addressOf(TreeIndex tree, String rootId) => heaviestOutlineAddress(
        tree,
        rootId: rootId,
        maxDepth: benchMaxDrillDepth,
      );

  void _startMeasuring() {
    if (_finished) {
      return;
    }
    _stats.reset();
    _measurePhysical = _physical;
    _measureDpr = _devicePixelRatio;
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
    final ScrollPosition position = _scroll.position;
    // ⚠️ `hasClients` 为真**不等于**尺寸已算出来：首帧里列表已经 attach，而
    // `applyContentDimensions` 还没跑，此时读 `maxScrollExtent` 会撞在内部
    // `_maxScrollExtent!` 的空断言上（实测崩在 `scroll_position.dart` 的
    // null check，整条 `flutter run` 就断在启动那一秒）。判据是
    // `hasContentDimensions`，不是 `hasClients`。
    if (!position.hasContentDimensions) {
      return;
    }
    final double max = position.maxScrollExtent;
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
          '（至少要 $frameStatsMinIntervals 个）'
          '${_stats.intervals == 0 ? ' —— 一帧都没有，先看窗口在不在前台：'
              '后台窗口会被判成被遮挡，引擎跳过光栅，帧时序根本不产生' : ''}');
      return;
    }
    final double extents = _scroll.hasClients &&
            _scroll.position.hasContentDimensions
        ? _scroll.position.maxScrollExtent
        : 0;
    if (extents <= 0) {
      final int rows = treeOutline(
        tree: tree,
        rootId: rootId,
        selectedId: address,
      ).length;
      _fail(2, '可滚动范围是 0 —— 行集合只有 $rows 行，没超出视口，'
          '每帧几乎不重绘，读数不可能有意义');
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
      physicalWidth: _measurePhysical.width,
      physicalHeight: _measurePhysical.height,
      logicalWidth: _measureDpr == 0 ? 0 : _measurePhysical.width / _measureDpr,
      logicalHeight:
          _measureDpr == 0 ? 0 : _measurePhysical.height / _measureDpr,
      devicePixelRatio: _measureDpr,
      snapshot: snapshot,
    );
    stdout.writeln('frame_bench: 场景 ${report.scenario}');
    stdout.writeln('frame_bench: 窗口 ${_measurePhysical.width.toInt()}x'
        '${_measurePhysical.height.toInt()} 物理'
        '（逻辑 ${report.logicalWidth.toInt()}x${report.logicalHeight.toInt()}'
        ' @${_measureDpr}x）⇒ premiseOk=${report.premiseOk}');
    if (_sizeDrifted) {
      // 不进读数行：行里写的是开测时的尺寸，而这一句说的是「这组数跨了两个尺寸」。
      // 两者放同一行的话，读的人会以为尺寸就是行里那个、只是标了一个 false。
      stdout.writeln('frame_bench: ⚠️ 测中窗口变过（开测 '
          '${_measurePhysical.width.toInt()}x${_measurePhysical.height.toInt()}'
          ' → 现在 ${_physical.width.toInt()}x${_physical.height.toInt()}）'
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
    final FlutterView view = View.of(context);
    _physical = view.physicalSize;
    _devicePixelRatio = view.devicePixelRatio;
    _logical = _devicePixelRatio <= 0
        ? _physical
        : Size(
            _physical.width / _devicePixelRatio,
            _physical.height / _devicePixelRatio,
          );
    if (_collecting && _physical != _measurePhysical) {
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
                physicalWidth: _physical.width.toInt(),
                physicalHeight: _physical.height.toInt(),
                logicalWidth: _logical.width.toInt(),
                logicalHeight: _logical.height.toInt(),
                devicePixelRatio: _devicePixelRatio,
                remainSeconds: (benchPremisePatience - _waited.elapsed)
                    .inSeconds
                    .clamp(0, benchPremisePatience.inSeconds),
                fitted: _fit != null,
              ),
            ),
        ],
      ),
    );
  }

  /// 装置里不接手势：剧本是滚，不是点。空实现比「假装能点」诚实。
  void _noop(String _) {}
}

/// 等待提示条：现在多大、该多大、还差多少、还剩几秒。
///
/// 不给「还差多少」的话，人会去猜 `C-33` 的容差；不给「还剩几秒」的话，人不知道
/// 这件事故意会到期 —— 到点照测，不是失败。**尺寸一律标单位**：这台机器上是
/// `1920×1110 @1.25x` 还是 `1536×888`，两句话都对，但只有一句是基准判据要的数。
class _GateNotice extends StatelessWidget {
  const _GateNotice({
    required this.physicalWidth,
    required this.physicalHeight,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.devicePixelRatio,
    required this.remainSeconds,
    required this.fitted,
  });

  final int physicalWidth;
  final int physicalHeight;
  final int logicalWidth;
  final int logicalHeight;
  final double devicePixelRatio;
  final int remainSeconds;

  /// 装置是否已自动把窗口设成基准尺寸。
  final bool fitted;

  @override
  Widget build(BuildContext context) {
    final bool stale = fitted &&
        (physicalWidth != frameBenchWidth.toInt() ||
            physicalHeight != frameBenchHeight.toInt());
    final String head = fitted
        ? '装置已把窗口设成 ${frameBenchWidth.toInt()}x${frameBenchHeight.toInt()}'
            ' 物理（C-33），等视口刷新后自动开测'
        : '没能自动设窗口 —— 请把客户区调成 ${frameBenchWidth.toInt()}x'
            '${frameBenchHeight.toInt()} 物理（C-33）';
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          '$head —— 当前 $physicalWidth x $physicalHeight 物理'
          '（逻辑 $logicalWidth x $logicalHeight @${devicePixelRatio}x）'
          ' · 还剩 $remainSeconds s'
          // 窗口设上了而视口没跟着变，只有一种常见原因：显示缩放刚改过，
          // 引擎还在用旧 DPR 算尺寸（Windows 自己也提示「某些应用要重新打开」）。
          // 不说这一句，人会一直等一个永远不会变的数。
          '${stale ? ' · 视口还没跟上，若一直不动请重启 app（改过显示缩放？）' : ''}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

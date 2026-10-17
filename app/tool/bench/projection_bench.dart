/// 投影帧预算实测（`B2` 第 4 笔 · `ADR-0002` §决策 2 的风险前置）。
///
/// 跑法（在 `app/` 目录下，`content/python/dist/pack.json` 需先由 `build.py` 生成）：
///
/// ```bash
/// dart run tool/bench/projection_bench.dart          # 只出数
/// dart run tool/bench/projection_bench.dart --strict # 超出预算即退出码 1
/// ```
///
/// ## 这个数能说明什么、不能说明什么
///
/// **能**：150 节点 + 170 边在**真实图密度**下的 CPU 侧每帧成本（`ADR-0002` 明确
/// 禁止用随机节点算帧预算 —— 合成分布与真包差一个量级，结论不可迁移）。
///
/// **不能**：真实帧率。帧率取决于 Canvas 绘制调用数、栅格化、合成与 GPU，
/// 那些是 `dart:ui` 的事，`lib/core/` 里测不到（`R1` 也不允许 import Flutter）。
/// 所以本文件只回答「CPU 预算够不够」，帧率归第 5 笔在用户终端 `flutter run --profile`。
///
/// **还要注意**：`dart run` 是 JIT，App 是 AOT。JIT 稳态一般慢于 AOT，
/// 因此这里量出的数偏保守；若本机已预热仍超预算，AOT 也救不回来。
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/frame/projection.dart';
import 'package:project_knowledge/core/frame/scene.dart';
import 'package:project_knowledge/core/pack/dart_io_pack_fs.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/pack/pack_probe.dart';

/// 预热帧数：让 JIT 把热路径编译完，否则 p50 里混着编译时间。
const int warmupFrames = 60;

/// 统计帧数。1000 帧 ≈ 16 秒 @60fps，足以看出抖动。
const int measuredFrames = 1000;

/// 每个节点的绘制指令宽度（x · y · depth · size · brightness · colorIndex · flags）。
const int nodeCommandStride = 7;

/// 每条边的绘制指令宽度（x1 · y1 · x2 · y2）。
const int edgeCommandStride = 4;

void main(List<String> args) {
  final bool strict = args.contains('--strict');

  final LoadedPack pack = _loadPack();
  final List<SceneNode> nodes = buildSceneNodes(pack, sectorCount: 6);
  final List<EdgeSpan> edges = buildEdgeSpans(pack, nodes);

  int maxPhi = 0;
  for (final SceneNode node in nodes) {
    if (node.phiLevel > maxPhi) {
      maxPhi = node.phiLevel;
    }
  }

  final Camera camera = Camera(
    yawRadians: 0.35,
    pitchRadians: 0.42,
    distance: 3,
    focal: 1.6,
    // `VIEW-002`：`r` 是 7 段径向分层。
    radialSegments: 7,
    sectorCount: 6,
    // φ 归一到一个世界单位高度：本包最大层号 63，固定 phiGap 会把最深那批
    // 节点推到相机后面，量到的是钳制分支而不是正常路径。投影成本与坐标取值
    // 无关，所以这个换算只影响「量的是哪条分支」，不影响结论的量级。
    phiHeight: 1.6,
    minDepth: 0.05,
  );

  _printInput(pack, nodes, edges);

  for (int i = 0; i < warmupFrames; i++) {
    projectFrame(nodes: nodes, edges: edges, camera: camera);
  }

  final Stopwatch watch = Stopwatch();
  final Uint32List micros = Uint32List(measuredFrames);
  for (int i = 0; i < measuredFrames; i++) {
    watch
      ..reset()
      ..start();
    final ProjectedFrame frame = projectFrame(nodes: nodes, edges: edges, camera: camera);
    watch.stop();
    micros[i] = watch.elapsedMicroseconds;
    // 消费一下，避免整段被优化掉（Dart 不会做死代码消除，但别赌）。
    if (frame.nodes.length != nodes.length) {
      stderr.writeln('投影结果数量不符：${frame.nodes.length} != ${nodes.length}');
      exitCode = 1;
      return;
    }
  }

  final _Stats projection = _Stats.of(micros);
  _printStats('① 投影（极坐标 → 3D → 2D + 深度排序）', projection, nodes.length, edges.length);

  final ProjectedFrame sample = projectFrame(nodes: nodes, edges: edges, camera: camera);
  int clamped = 0;
  double minDepthSeen = camera.minDepth;
  double maxDepthSeen = camera.minDepth;
  for (final ProjectedNode node in sample.nodes) {
    if (node.depth <= camera.minDepth) {
      clamped += 1;
    }
    if (node.depth < minDepthSeen) {
      minDepthSeen = node.depth;
    }
    if (node.depth > maxDepthSeen) {
      maxDepthSeen = node.depth;
    }
  }
  stdout.writeln('  深度范围 ${minDepthSeen.toStringAsFixed(3)} … ${maxDepthSeen.toStringAsFixed(3)}'
      ' · 贴到相机平面被钳制的节点 $clamped');
  stdout.writeln('  φ 最大层号 $maxPhi ⇒ phiHeight ${camera.phiHeight.toStringAsFixed(2)}');
  stdout.writeln('');

  // ② 指令编码：把投影结果压成 painter 直接可用的扁平数组。
  //    这一步是「批量绘制」的 CPU 侧落点 —— Canvas 调用数取决于它，而不是取决于
  //    有多少个 Dart 对象。
  final Float64List commands = Float64List(
    nodes.length * nodeCommandStride + edges.length * edgeCommandStride,
  );
  for (int i = 0; i < warmupFrames; i++) {
    _encode(projectFrame(nodes: nodes, edges: edges, camera: camera), commands);
  }
  final Uint32List encodeMicros = Uint32List(measuredFrames);
  for (int i = 0; i < measuredFrames; i++) {
    final ProjectedFrame frame = projectFrame(nodes: nodes, edges: edges, camera: camera);
    watch
      ..reset()
      ..start();
    _encode(frame, commands);
    watch.stop();
    encodeMicros[i] = watch.elapsedMicroseconds;
  }
  final _Stats encode = _Stats.of(encodeMicros);
  _printStats('② 指令编码（扁平化到 Float64List）', encode, nodes.length, edges.length);

  final double totalP95 = projection.p95Ms + encode.p95Ms;
  stdout.writeln('');
  stdout.writeln('=== 结论 ===');
  stdout.writeln('  CPU 单帧 p95 合计 = ${totalP95.toStringAsFixed(4)} ms'
      '（① ${projection.p95Us.toStringAsFixed(2)} µs + ② ${encode.p95Us.toStringAsFixed(2)} µs）');
  stdout.writeln('  预算 ${frameCpuBudgetMs.toStringAsFixed(2)} ms（p95）⇒ '
      '${totalP95 <= frameCpuBudgetMs ? "通过" : "未通过"}');
  stdout.writeln('  ⚠️ 本数不含 Canvas 绘制调用与栅格化 —— 帧率实测归第 5 笔（终端 `flutter run --profile`）');

  if (strict && totalP95 > frameCpuBudgetMs) {
    exitCode = 1;
  }
}

LoadedPack _loadPack() {
  const PackProbe probe = PackProbe(DartIoPackFs());
  final ProbeResult result = probe.scanRoots(devPackRoots());

  if (result.isEmpty) {
    for (final PackProblem problem in result.problems) {
      stderr.writeln('探测问题：$problem');
    }
    stderr.writeln('没找到内容包。先在仓根跑 `python content/tools/build.py python`。');
    exit(1);
  }

  // 优先用 α 包；没有就取第一个，并把名字打出来（不静默换包）。
  PackLocation chosen = result.locations.first;
  for (final PackLocation location in result.locations) {
    if (location.spaceRoot.endsWith('/python')) {
      chosen = location;
      break;
    }
  }

  const DartIoPackFs fs = DartIoPackFs();
  final String? manifest = fs.readString(chosen.manifestPath);
  final String? body = fs.readString(chosen.packPath);
  if (manifest == null || body == null) {
    stderr.writeln('读不出包文件：${chosen.spaceRoot}');
    exit(1);
  }
  return parsePack(manifestJson: manifest, packJson: body);
}

/// 打包成一维指令数组。布局：节点在前（`nodeCommandStride` 宽），边在后。
void _encode(ProjectedFrame frame, Float64List out) {
  int cursor = 0;
  for (final ProjectedNode node in frame.nodes) {
    out[cursor] = node.x;
    out[cursor + 1] = node.y;
    out[cursor + 2] = node.depth;
    out[cursor + 3] = node.size01;
    out[cursor + 4] = node.brightness01;
    out[cursor + 5] = node.colorIndex.toDouble();
    out[cursor + 6] = (node.dashed ? 1 : 0) + (node.ringClosed ? 2 : 0);
    cursor += nodeCommandStride;
  }
  for (final EdgeSpan edge in frame.edges) {
    final ProjectedNode from = frame.nodes[edge.fromIndex];
    final ProjectedNode to = frame.nodes[edge.toIndex];
    out[cursor] = from.x;
    out[cursor + 1] = from.y;
    out[cursor + 2] = to.x;
    out[cursor + 3] = to.y;
    cursor += edgeCommandStride;
  }
}

void _printInput(LoadedPack pack, List<SceneNode> nodes, List<EdgeSpan> edges) {
  final Map<String, int> degrees = <String, int>{};
  for (final EdgeSpan edge in edges) {
    final String from = nodes[edge.fromIndex].id;
    final String to = nodes[edge.toIndex].id;
    degrees[from] = (degrees[from] ?? 0) + 1;
    degrees[to] = (degrees[to] ?? 0) + 1;
  }
  int minDegree = nodes.length;
  int maxDegree = 0;
  int sum = 0;
  for (final SceneNode node in nodes) {
    final int degree = degrees[node.id] ?? 0;
    if (degree < minDegree) {
      minDegree = degree;
    }
    if (degree > maxDegree) {
      maxDegree = degree;
    }
    sum += degree;
  }

  int maxPhi = 0;
  for (final SceneNode node in nodes) {
    if (node.phiLevel > maxPhi) {
      maxPhi = node.phiLevel;
    }
  }
  int dashed = 0;
  int ringed = 0;
  for (final SceneNode node in nodes) {
    if (node.dashed) {
      dashed += 1;
    }
    if (node.ringFill01 > 0) {
      ringed += 1;
    }
  }

  stdout.writeln('=== 输入（真实内容包，非合成） ===');
  stdout.writeln('  空间 ${pack.space.id} · ${pack.space.name} v${pack.space.version}');
  stdout.writeln('  项 ${nodes.length} · 边 ${edges.length} · 域 ${pack.space.domainIds.length}'
      ' · 边密度 ${(edges.length / math.max(nodes.length, 1)).toStringAsFixed(2)} 条/项');
  stdout.writeln('  连接度 min $minDegree · mean ${(sum / math.max(nodes.length, 1)).toStringAsFixed(2)}'
      ' · max $maxDegree');
  stdout.writeln('  φ 最大层号 $maxPhi · 虚化项 $dashed · 有轨道环的项 $ringed');
  stdout.writeln('  （无事件流输入 ⇒ 环填充与脉动为 0，与真实首启一致）');
  stdout.writeln('');
}

void _printStats(String title, _Stats stats, int nodeCount, int edgeCount) {
  stdout.writeln('=== $title ===');
  stdout.writeln('  帧数 $measuredFrames（预热 $warmupFrames）'
      ' · 每帧 $nodeCount 节点 / $edgeCount 边');
  stdout.writeln('  p50 ${stats.p50Us.toStringAsFixed(2)} µs · '
      'p95 ${stats.p95Us.toStringAsFixed(2)} µs · '
      'p99 ${stats.p99Us.toStringAsFixed(2)} µs · '
      'max ${stats.maxUs.toStringAsFixed(2)} µs');
  stdout.writeln('  mean ${stats.meanUs.toStringAsFixed(2)} µs · '
      'sd ${stats.sdUs.toStringAsFixed(2)} µs');
  if (stats.p95Us < 1) {
    stdout.writeln('  注：p95 < 1 µs，低于 Stopwatch 分辨率 ⇒ 只能判定「可忽略」，不报具体值');
  }
  stdout.writeln('');
}

class _Stats {
  const _Stats({
    required this.p50Us,
    required this.p95Us,
    required this.p99Us,
    required this.maxUs,
    required this.meanUs,
    required this.sdUs,
  });

  factory _Stats.of(Uint32List micros) {
    final List<int> sorted = <int>[...micros]..sort();
    double sum = 0;
    for (final int value in sorted) {
      sum += value;
    }
    final double mean = sum / sorted.length;
    double variance = 0;
    for (final int value in sorted) {
      final double diff = value - mean;
      variance += diff * diff;
    }
    return _Stats(
      p50Us: _percentileUs(sorted, 0.50),
      p95Us: _percentileUs(sorted, 0.95),
      p99Us: _percentileUs(sorted, 0.99),
      maxUs: sorted.last.toDouble(),
      meanUs: mean,
      sdUs: math.sqrt(variance / sorted.length),
    );
  }

  final double p50Us;
  final double p95Us;
  final double p99Us;
  final double maxUs;
  final double meanUs;
  final double sdUs;

  double get p95Ms => p95Us / 1000;

  static double _percentileUs(List<int> sorted, double ratio) {
    final int index = (sorted.length * ratio).floor();
    final int clamped = index >= sorted.length ? sorted.length - 1 : index;
    return sorted[clamped].toDouble();
  }
}

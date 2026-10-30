/// `B17b` 笔 1 的最小场景：天球贴图 + 1,200 个 billboard 点 + bloom。
///
/// 这条链只回答一个问题：**这套引擎在你这台机器上能不能跑到 30 帧**
/// （`ADR-0006` §3）。它不判断好不好看 —— 那属段 2 的观感调校。
///
/// 相机按 `ADR-0006` 决策 2 定死在球心、**只旋转不平移**：平移会让同心球壳
/// 的透视崩掉，那是一个看起来很小、改起来很贵的错误。
///
/// 引擎类型一律带 `fs.` 前缀：`flutter_scene` 的 `Node` / `Scene` 与本项目
/// 领域模型同名，不加前缀时 `R8`（不得直接构造领域 `Node`）会误判 —— 加前缀
/// 既让规则分得清，也让读代码的人一眼知道这是引擎的类。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import 'frame_stats.dart';
import 'sky_image.dart';

/// `ADR-0006` §3 规定的同屏点数。
const int kSpikeBillboardCount = 1200;

/// 星点所在球壳的半径（世界单位）。相机在原点，所以这也是星点到相机的距离。
const double kSpikeSphereRadius = 100.0;

/// 预热帧数。前若干帧含着 shader 编译与贴图上传，拿它们算分位会把 P95 拖成
/// 一个与稳态无关的数 —— 丢掉。
const int kWarmupFrames = 30;

/// 稳态采样帧数。300 帧在 30 fps 下是 10 秒，足够压住抖动，又不至于让你
/// 在终端前干等。
const int kSampleFrames = 300;

class SpikeSceneView extends StatefulWidget {
  const SpikeSceneView({super.key});

  @override
  State<SpikeSceneView> createState() => _SpikeSceneViewState();
}

class _SpikeSceneViewState extends State<SpikeSceneView> {
  final fs.Scene _scene = fs.Scene();
  final List<double> _frames = <double>[];
  final ValueNotifier<FrameStats?> _stats = ValueNotifier<FrameStats?>(null);

  bool _ready = false;
  String? _error;
  int _seen = 0;
  bool _samplingDone = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _build();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _stats.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    try {
      // 引擎的静态资源要在建几何、材质之前就绪，否则它们拿不到 shader。
      await fs.Scene.initializeStaticResources();

      // 天球：一张运行期画的 equirect 图，不落盘（`ADR-0006` 决策 4）。
      final ui.Image image = await paintSkyImage();
      final fs.EnvironmentMap env = await fs.EnvironmentMap.fromUIImages(
        radianceImage: image,
      );
      _scene.environment = env;
      // 背景直接用环境本身：星空的「亮」由贴图决定，不额外打光。
      _scene.skybox = fs.Skybox(fs.EnvironmentSkySource());

      // bloom 是全案唯一的「必须」后处理（`ADR-0006` 决策 2）：亮星光晕靠它，
      // 而纯 shader 方案做不出多 pass。这段开不起来，spike 就算失败。
      _scene.postProcess.bloom
        ..enabled = true
        ..threshold = 1.0
        ..intensity = 0.35
        ..scatter = 0.75;

      _addBillboards();

      if (mounted) {
        setState(() => _ready = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  /// 1,200 个点均匀铺在球壳上，亮度按幂律压向暗端 —— 与真实星空的分布同向。
  ///
  /// 用**一个** `BillboardGeometry` 装 1,200 个实例，不是 1,200 个节点：后者
  /// 会变成 1,200 次 draw call，测出来的是调度开销而不是渲染开销。
  void _addBillboards() {
    final fs.BillboardGeometry geometry = fs.BillboardGeometry(
      capacity: kSpikeBillboardCount,
    );
    final math.Random rng = math.Random(20261030);

    for (int i = 0; i < kSpikeBillboardCount; i++) {
      // 球面均匀采样：`z` 均匀、`θ` 均匀，避免在极点堆积。
      final double z = rng.nextDouble() * 2 - 1;
      final double theta = rng.nextDouble() * 2 * math.pi;
      final double r = math.sqrt(1 - z * z);
      final vm.Vector3 center =
          vm.Vector3(r * math.cos(theta), z, r * math.sin(theta)) *
          kSpikeSphereRadius;

      final double u = rng.nextDouble();
      final double lum = u * u * u;
      // 0.10 在半径 100 处约合 1 像素，亮星再放大几倍。
      final double size = 0.10 + lum * 0.26;

      geometry.setInstance(
        i,
        center: center,
        width: size,
        height: size,
        color: vm.Vector4(1, 0.98, 0.94, 0.35 + lum * 0.65),
      );
    }
    geometry.commit(kSpikeBillboardCount);

    _scene.add(fs.Node(mesh: fs.Mesh(geometry, fs.SpriteMaterial())));
  }

  /// 球心视角：只看方向，不平移。
  fs.PerspectiveCamera _cameraAt(Duration elapsed) {
    final double t = elapsed.inMicroseconds / 1e6;
    final double yaw = t * 0.10;
    final double pitch = math.sin(t * 0.31) * 0.16;
    final vm.Vector3 dir = vm.Vector3(
      math.sin(yaw) * math.cos(pitch),
      math.sin(pitch),
      math.cos(yaw) * math.cos(pitch),
    );
    return fs.PerspectiveCamera(
      position: vm.Vector3.zero(),
      target: dir * kSpikeSphereRadius,
      // 视场稍宽，一屏能装下的星多些，帧预算更接近真实使用。
      fovRadiansY: 70 * math.pi / 180,
      fovFar: kSpikeSphereRadius * 4,
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_samplingDone) {
      return;
    }
    for (final FrameTiming timing in timings) {
      _seen++;
      if (_seen <= kWarmupFrames) {
        continue;
      }
      _frames.add(timing.totalSpan.inMicroseconds / 1000.0);
      if (_frames.length >= kSampleFrames) {
        _samplingDone = true;
        _stats.value = summarize(_frames);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _error != null
                ? _ErrorPane(message: _error!)
                : (_ready
                      ? fs.SceneView(_scene, cameraBuilder: _cameraAt)
                      : const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: _Readout(
              stats: _stats,
              sampled: _frames.length,
              total: kSampleFrames,
            ),
          ),
        ],
      ),
    );
  }
}

/// 左上角读数。spike 的产物就是这个面板上的四个数 —— 记下来回填 `ADR`。
class _Readout extends StatelessWidget {
  const _Readout({
    required this.stats,
    required this.sampled,
    required this.total,
  });

  final ValueNotifier<FrameStats?> stats;
  final int sampled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FrameStats?>(
      valueListenable: stats,
      builder: (BuildContext context, FrameStats? value, _) {
        final String body;
        if (value == null) {
          body = '采样中 $sampled / $total';
        } else {
          body =
              'P50 ${value.p50Ms.toStringAsFixed(1)} ms '
              '(${value.p50Fps.toStringAsFixed(1)} fps)\n'
              'P95 ${value.p95Ms.toStringAsFixed(1)} ms\n'
              '样本 ${value.samples}\n'
              '${value.passesGate ? "闸门通过" : "闸门未过"}';
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              body,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.5,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SelectableText(
          'spike 装配失败：\n\n$message',
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      ),
    );
  }
}

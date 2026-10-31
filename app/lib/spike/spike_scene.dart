/// `B17b` 段 2 的最小场景：真实星表天球 + 亮星光斑 + 5 层同心球壳 + bloom。
///
/// 与笔 1 的差别只有一处但很关键：**星星不再是随机撒的了**。位置、亮度、颜色
/// 全部取自 `V/50` 星表（`star_catalog.dart`），抬头能真的找到北斗七星。
///
/// 分工沿 `ADR-0006` 的结论：**暗星烘进贴图、亮星做成 billboard**。理由是实测
/// 出来的 —— 像素翻 1.6 倍帧时间只涨 0.1 ms，说明填充率不是瓶颈；而几何实例数
/// 会直接把帧时间顶上去（1,200 个 billboard 是当前唯一的几何负载）。
/// 所以 9,096 颗星里最亮的 1,200 颗占几何，其余 7,896 颗留在贴图里。
///
/// 相机按 `ADR-0006` 决策 2 定死在球心、**只旋转不平移**：平移会让同心球壳的
/// 透视崩掉。
///
/// 引擎类型一律带 `fs.` 前缀：`flutter_scene` 的 `Node` / `Scene` 与本项目领域
/// 模型同名，不加前缀时 `R8`（不得直接构造领域 `Node`）会误判。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import 'frame_stats.dart';
import 'sky_image.dart';
import 'sphere_shells.dart';
import 'star_catalog.dart';
import 'star_sprite.dart';

/// `ADR-0006` §3 规定的同屏点数。
const int kSpikeBillboardCount = 1200;

/// 星点所在球壳的半径（世界单位）。相机在原点，所以这也是星点到相机的距离。
const double kSpikeSphereRadius = 100.0;

/// 预热帧数。前若干帧含着 shader 编译与贴图上传，拿它们算分位会把 P95 拖成
/// 一个与稳态无关的数 —— 丢掉。
const int kWarmupFrames = 30;

/// 亮星光斑的世界尺寸端点：按星等线性映射，最亮的给 [kBrightStarMaxSize]。
const double kBrightStarMinSize = 0.18;
const double kBrightStarMaxSize = 0.62;

/// 亮星光斑的亮度倍数端点。超过 1 才会被 bloom 的阈值（1.0）吃到，
/// 所以最亮的星给到 2.6，让光晕在画面上真的散开。
const double kBrightStarMinGain = 0.7;
const double kBrightStarMaxGain = 2.6;

class SpikeSceneView extends StatefulWidget {
  const SpikeSceneView({super.key});

  @override
  State<SpikeSceneView> createState() => _SpikeSceneViewState();
}

class _SpikeSceneViewState extends State<SpikeSceneView> {
  final fs.Scene _scene = fs.Scene();
  final List<double> _frames = <double>[];
  final ValueNotifier<FrameStats?> _stats = ValueNotifier<FrameStats?>(null);
  final ValueNotifier<double> _elapsed = ValueNotifier<double>(0);

  bool _ready = false;
  String? _error;
  int _seen = 0;
  int? _sampleStartUs;
  bool _samplingDone = false;
  int _starCount = 0;

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
    _elapsed.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    try {
      // 引擎的静态资源要在建几何、材质之前就绪，否则它们拿不到 shader。
      await fs.Scene.initializeStaticResources();

      final StarCatalog catalog = await loadBsc5Catalog();
      final List<StarRecord> sorted = <StarRecord>[...catalog.stars]
        ..sort((StarRecord a, StarRecord b) {
          final double ma = a.vMag ?? kFaintestMag;
          final double mb = b.vMag ?? kFaintestMag;
          return ma.compareTo(mb);
        });
      final List<StarRecord> bright = sorted
          .take(kSpikeBillboardCount)
          .toList(growable: false);
      final List<StarRecord> faint = sorted
          .skip(bright.length)
          .toList(growable: false);
      _starCount = catalog.stars.length;

      // 天球：只画暗星。亮星交给下面的 billboard，两边都画会重影。
      final ui.Image image = await paintSkyImage(stars: faint);
      final fs.EnvironmentMap env = await fs.EnvironmentMap.fromUIImages(
        radianceImage: image,
      );
      _scene.environment = env;
      _scene.skybox = fs.Skybox(fs.EnvironmentSkySource());

      // bloom 是全案唯一的「必须」后处理（`ADR-0006` 决策 2）：亮星光晕靠它，
      // 而纯 shader 方案做不出多 pass。这段开不起来，spike 就算失败。
      _scene.postProcess.bloom
        ..enabled = true
        ..threshold = 1.0
        ..intensity = 0.42
        ..scatter = 0.78;

      await _addBrightStars(bright);
      _scene.add(buildShellsNode());

      if (mounted) {
        setState(() => _ready = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  /// 最亮的 [kSpikeBillboardCount] 颗星铺在球壳上，位置取真实赤经赤纬。
  ///
  /// 用**一个** `BillboardGeometry` 装全部实例，不是每颗一个节点：后者会变成
  /// 上千次 draw call，测出来的是调度开销而不是渲染开销。
  Future<void> _addBrightStars(List<StarRecord> bright) async {
    final fs.Texture2D texture = await buildStarSpriteTexture();
    final fs.BillboardGeometry geometry = fs.BillboardGeometry(
      capacity: bright.length,
    );

    for (int i = 0; i < bright.length; i++) {
      final StarRecord star = bright[i];
      final Vec3 dir = unitVector(star.raHours, star.decDeg);
      // 场景是 Y 轴朝上，而星表的 `z` 指向北天极 ⇒ 换轴时才不会躺在赤道面上。
      final vm.Vector3 center =
          vm.Vector3(dir.x, dir.z, dir.y) * kSpikeSphereRadius;

      final double mag = star.vMag ?? kFaintestMag;
      final double t = ((kFaintestMag - mag) / (kFaintestMag - kBrightestMag))
          .clamp(0.0, 1.0);
      final double size =
          kBrightStarMinSize + t * (kBrightStarMaxSize - kBrightStarMinSize);
      final double gain =
          kBrightStarMinGain + t * (kBrightStarMaxGain - kBrightStarMinGain);

      final ui.Color color = starColor(star);
      geometry.setInstance(
        i,
        center: center,
        width: size,
        height: size,
        color: vm.Vector4(color.r * gain, color.g * gain, color.b * gain, 0.85),
      );
    }
    geometry.commit(bright.length);

    _scene.add(fs.Node(mesh: fs.Mesh(geometry, buildStarMaterial(texture))));
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
      final int nowUs = timing.timestampInMicroseconds(
        ui.FramePhase.vsyncStart,
      );
      _sampleStartUs ??= nowUs;
      _frames.add(timing.totalSpan.inMicroseconds / 1000.0);
      final double elapsed = (nowUs - _sampleStartUs!) / 1000000.0;
      _elapsed.value = elapsed;
      if (shouldStopSampling(
        elapsedSeconds: elapsed,
        samples: _frames.length,
      )) {
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
              elapsed: _elapsed,
              stars: _starCount,
            ),
          ),
        ],
      ),
    );
  }
}

/// 左上角读数。spike 的产物就是这个面板上的几个数 —— 记下来回填 `ADR`。
class _Readout extends StatelessWidget {
  const _Readout({
    required this.stats,
    required this.elapsed,
    required this.stars,
  });

  final ValueNotifier<FrameStats?> stats;
  final ValueNotifier<double> elapsed;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FrameStats?>(
      valueListenable: stats,
      builder: (BuildContext context, FrameStats? value, _) {
        final String body;
        if (value == null) {
          body =
              '采样中 ${elapsed.value.toStringAsFixed(1)} / '
              '${kSampleSeconds.toStringAsFixed(1)} 秒\n'
              '星表 $stars 颗';
        } else {
          body =
              'P50 ${value.p50Ms.toStringAsFixed(1)} ms '
              '(${value.p50Fps.toStringAsFixed(1)} fps)\n'
              'P95 ${value.p95Ms.toStringAsFixed(1)} ms\n'
              '样本 ${value.samples} · '
              '${kSampleSeconds.toStringAsFixed(1)} 秒\n'
              '星表 $stars 颗 · $kShellCount 层球壳\n'
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

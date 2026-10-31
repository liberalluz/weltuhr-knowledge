/// `B17b` 段 3 的场景：Hipparcos 全量星表天球 + 亮星光斑 + 5 层同心球壳 +
/// 可旋转可缩放的天球 + bloom。
///
/// 与段 2 的差别：星源从 `V/50`（9,096 颗）换成 Hipparcos（118,217 颗），
/// 相机从「按时间自动绕行」换成**手势驱动**，贴图的极区畸变在绘制期补偿。
///
/// 分工沿 `ADR-0006` 的结论：**暗星烘进贴图、亮星做成 billboard**。理由是实测
/// 出来的 —— 像素翻 1.6 倍帧时间只涨 0.1 ms，说明填充率不是瓶颈；而几何实例数
/// 会直接把帧时间顶上去（1,200 个 billboard 是当前唯一的几何负载）。
/// 所以 118,217 颗里最亮的 1,200 颗占几何，其余 117,017 颗留在贴图里。
///
/// 相机按 `ADR-0006` 决策 2 定死在球心、**只旋转不平移**：平移会让同心球壳的
/// 透视崩掉。
///
/// 引擎类型一律带 `fs.` 前缀：`flutter_scene` 的 `Node` / `Scene` 与本项目领域
/// 模型同名，不加前缀时 `R8`（不得直接构造领域 `Node`）会误判。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import 'constellations.dart';
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

/// 拖动灵敏度：一个屏幕像素转多少弧度。
///
/// 1920 像素宽、fov 70°（1.22 弧度）时，整屏拖一遍转过 0.96 弧度 ≈ 55°，
/// 比「拖到头刚好转过一屏」略钝一点 —— 太灵敏会很难对准一颗星。
const double kDragRadiansPerPixel = 0.0005;

/// 滚轮一格改变多少视场角（度）。
const double kZoomDegreesPerNotch = 4.0;

/// 视场角上下限。上限比段 2 的 70° 宽一档，下限留给「看清一片天区」。
const double kMinFovDeg = 20.0;
const double kMaxFovDeg = 100.0;

/// 自动绕行的角速度（弧度/秒）。**用户一拖动就永久停** —— 自转与手势抢方向
/// 是最烦的一种手感。
const double kAutoSpinRadiansPerSecond = 0.02;

/// 重采按钮用的采样时长（秒）。默认 [kSampleSeconds] 只够看个大概，
/// 要判断 P95 是否收敛得拉长窗口。
const double kResampleSeconds = 30.0;

/// 球心相机的状态：只转、不平移。
///
/// 单独成类而不是散在 State 里，是因为它**能在 `flutter test` 里验**：真机画面
/// 采不到，但「拖 100 像素转多少度」「滚轮夹不夹」这些算术可以逐条断言。
class SkyCamera implements SkyView {
  SkyCamera({
    this.yaw = 0,
    this.pitch = 0,
    this.fovDeg = 70,
    this.autoSpin = true,
  });

  /// 水平朝向，弧度，`[0, 2π)`。**只经 [drag] / [spin] 改** —— 字段公开是为了
  /// 让测试能直读与构造，不是因为允许外部乱写。
  @override
  double yaw;

  /// 俯仰，弧度，夹在 ±(π/2 − 0.01) —— 正对极点时 `target` 与视线同向，
  /// 相机退化成「看不出在转」。
  @override
  double pitch;

  /// 视场角，度。
  @override
  double fovDeg;

  /// 自动绕行是否还在生效。用户拖过一次就永久关掉。
  bool autoSpin;

  /// 视线方向（单位向量）。
  vm.Vector3 get direction {
    final double cosPitch = math.cos(pitch);
    return vm.Vector3(
      math.sin(yaw) * cosPitch,
      math.sin(pitch),
      math.cos(yaw) * cosPitch,
    );
  }

  /// 拖动。像素位移 → 角度：手指往右拖，天球跟着往右走（视线左转）。
  void drag(ui.Offset delta) {
    autoSpin = false;
    yaw = _wrap(yaw - delta.dx * kDragRadiansPerPixel);
    pitch = (pitch + delta.dy * kDragRadiansPerPixel).clamp(
      -_maxPitch,
      _maxPitch,
    );
  }

  /// 滚轮 / 触控板缩放。`delta` 为正表示放大（视场角变小）。
  void zoom(double delta) {
    autoSpin = false;
    fovDeg = (fovDeg - delta * kZoomDegreesPerNotch / 100).clamp(
      kMinFovDeg,
      kMaxFovDeg,
    );
  }

  /// 自动绕行一帧。返回值表示有没有动过 —— 动了才需要重绘。
  bool spin(double dtSeconds) {
    if (!autoSpin || dtSeconds <= 0) {
      return false;
    }
    yaw = _wrap(yaw + kAutoSpinRadiansPerSecond * dtSeconds);
    return true;
  }

  static const double _maxPitch = math.pi / 2 - 0.01;

  static double _wrap(double radians) {
    const double twoPi = 2 * math.pi;
    final double wrapped = radians % twoPi;
    return wrapped < 0 ? wrapped + twoPi : wrapped;
  }
}

/// 手势层：把手势翻译成 [SkyCamera] 的调用。
///
/// 单独一个 widget 是为了**能测** —— 真正的 `SceneView` 要 GPU，在
/// `flutter test` 里挂不起来，而「手势有没有被识别、有没有落到相机上」
/// 这一层不需要 GPU。
class SkyGestureLayer extends StatefulWidget {
  const SkyGestureLayer({
    required this.camera,
    required this.child,
    this.onChanged,
    super.key,
  });

  final SkyCamera camera;
  final Widget child;

  /// 相机变化后的回调（画面要重绘）。
  final VoidCallback? onChanged;

  @override
  State<SkyGestureLayer> createState() => _SkyGestureLayerState();
}

class _SkyGestureLayerState extends State<SkyGestureLayer> {
  ui.Offset _lastPan = ui.Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          widget.camera.zoom(event.scrollDelta.dy);
          widget.onChanged?.call();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (DragStartDetails details) {
          _lastPan = details.localPosition;
        },
        onPanUpdate: (DragUpdateDetails details) {
          final ui.Offset delta = details.localPosition - _lastPan;
          _lastPan = details.localPosition;
          widget.camera.drag(delta);
          widget.onChanged?.call();
        },
        child: widget.child,
      ),
    );
  }
}

class SpikeSceneView extends StatefulWidget {
  const SpikeSceneView({super.key});

  @override
  State<SpikeSceneView> createState() => _SpikeSceneViewState();
}

class _SpikeSceneViewState extends State<SpikeSceneView>
    with SingleTickerProviderStateMixin {
  final fs.Scene _scene = fs.Scene();
  final List<double> _frames = <double>[];
  final ValueNotifier<FrameStats?> _stats = ValueNotifier<FrameStats?>(null);
  final ValueNotifier<double> _elapsed = ValueNotifier<double>(0);
  final SkyCamera _camera = SkyCamera();

  /// 每帧递增。连线层挂在这个 notifier 上重绘 —— 相机是原地改字段的对象，
  /// 靠 `setState` 重画会连带把 `SceneView` 整棵子树重建一遍。
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  /// HIP 号 → 星表记录，连线按号取坐标用。
  Map<int, StarRecord> _starsByHip = const <int, StarRecord>{};

  late final Ticker _ticker;

  bool _ready = false;
  String? _error;
  int _seen = 0;
  int? _sampleStartUs;
  int? _lastFrameUs;
  bool _samplingDone = false;
  double _sampleSeconds = kSampleSeconds;
  int _starCount = 0;
  int _lostStars = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _ticker = createTicker((_) => _tick.value++)..start();
    _build();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    _tick.dispose();
    _stats.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    try {
      // 引擎的静态资源要在建几何、材质之前就绪，否则它们拿不到 shader。
      await fs.Scene.initializeStaticResources();

      final StarCatalog catalog = await loadHipparcosCatalog();
      _starsByHip = <int, StarRecord>{
        for (final StarRecord star in catalog.stars) star.hip: star,
      };
      final List<StarRecord> sorted = <StarRecord>[...catalog.stars]
        ..sort((StarRecord a, StarRecord b) => a.vMag.compareTo(b.vMag));
      final List<StarRecord> bright = sorted
          .take(kSpikeBillboardCount)
          .toList(growable: false);
      final List<StarRecord> faint = sorted
          .skip(bright.length)
          .toList(growable: false);
      _starCount = catalog.stars.length;
      _lostStars = catalog.skipped;

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
      final Vec3 dir = unitVector(star.raDeg, star.decDeg);
      // 场景是 Y 轴朝上，而星表的 `z` 指向北天极 ⇒ 换轴时才不会躺在赤道面上。
      final vm.Vector3 center =
          vm.Vector3(dir.x, dir.z, dir.y) * kSpikeSphereRadius;

      final double t =
          ((kFaintestMag - star.vMag) / (kFaintestMag - kBrightestMag)).clamp(
            0.0,
            1.0,
          );
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

  /// 球心视角：只看方向，不平移。方向取 [SkyCamera]，每帧推进一次自动绕行。
  fs.PerspectiveCamera _cameraAt(Duration elapsed) {
    final int nowUs = elapsed.inMicroseconds;
    final int previousUs = _lastFrameUs ?? nowUs;
    _lastFrameUs = nowUs;
    final double dt = (nowUs - previousUs) / 1e6;
    _camera.spin(dt.clamp(0.0, 0.25));

    return fs.PerspectiveCamera(
      position: vm.Vector3.zero(),
      target: _camera.direction * kSpikeSphereRadius,
      fovRadiansY: _camera.fovDeg * math.pi / 180,
      fovFar: kSpikeSphereRadius * 4,
    );
  }

  /// 重采：清空样本、拉长窗口。用来判断 P95 是「首帧上传」还是「稳态抖动」——
  /// 只在 8 秒窗口里看，这两种分不开。
  void _resample() {
    setState(() {
      _frames.clear();
      _seen = 0;
      _sampleStartUs = null;
      _samplingDone = false;
      _sampleSeconds = kResampleSeconds;
      _stats.value = null;
      _elapsed.value = 0;
    });
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
        minSeconds: _sampleSeconds,
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
                      ? SkyGestureLayer(
                          camera: _camera,
                          onChanged: () => setState(() {}),
                          child: fs.SceneView(_scene, cameraBuilder: _cameraAt),
                        )
                      : const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )),
          ),
          // 星座连线画在场景之上、读数之下：`IgnorePointer` 让手势照旧落到下层。
          if (_ready)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  size: ui.Size.infinite,
                  painter: ConstellationPainter(
                    view: _camera,
                    starsByHip: _starsByHip,
                    repaint: _tick,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            top: 16,
            child: _Readout(
              stats: _stats,
              elapsed: _elapsed,
              camera: _camera,
              stars: _starCount,
              lost: _lostStars,
              window: () => _sampleSeconds,
              onResample: _ready ? _resample : null,
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
    required this.camera,
    required this.stars,
    required this.lost,
    required this.window,
    required this.onResample,
  });

  final ValueNotifier<FrameStats?> stats;
  final ValueNotifier<double> elapsed;
  final SkyCamera camera;
  final int stars;
  final int lost;
  final double Function() window;
  final VoidCallback? onResample;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FrameStats?>(
      valueListenable: stats,
      builder: (BuildContext context, FrameStats? value, _) {
        final double seconds = window();
        final String head = value == null
            ? '采样中 ${elapsed.value.toStringAsFixed(1)} / '
                  '${seconds.toStringAsFixed(0)} 秒'
            : 'P50 ${value.p50Ms.toStringAsFixed(1)} ms '
                  '(${value.p50Fps.toStringAsFixed(1)} fps)\n'
                  'P95 ${value.p95Ms.toStringAsFixed(1)} ms\n'
                  '样本 ${value.samples} · ${seconds.toStringAsFixed(0)} 秒';
        final String tail = value == null
            ? ''
            : '\n${value.passesGate ? "闸门通过" : "闸门未过"}';
        final String body =
            '$head\n'
            '星 $stars 颗'
            '${lost > 0 ? "（跳 $lost）" : ""} · $kShellCount 层球壳\n'
            'fov ${camera.fovDeg.toStringAsFixed(0)}°'
            '${camera.autoSpin ? " · 自转中" : ""}'
            ' · 拖动转 / 滚轮缩放$tail';

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.5,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                if (onResample != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton(
                      onPressed: onResample,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: Text(
                        '重采 ${kResampleSeconds.toStringAsFixed(0)} 秒',
                      ),
                    ),
                  ),
              ],
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

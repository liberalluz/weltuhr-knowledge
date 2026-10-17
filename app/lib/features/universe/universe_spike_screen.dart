/// 帧率 spike 的屏幕 —— `B2` 第 5 笔，`ADR-0002` §决策 2 的最后一块闭环。
///
/// 这一页不是产品界面，是**测量装置**：宇宙缓慢自转、每帧朴素绘制、
/// 角上实时报数。判据是 `C-32` 的 30 / 50 fps。
///
/// ## 为什么要有这一页，而不是直接跑 DevTools
///
/// DevTools 的 timeline 能给更细的分解，但它要连、要选、要会看。这一页把
/// 三个数直接怼到屏幕上（fps · p95 帧间隔 · 光栅 p95），并且**自带档位切换**：
/// 150 / 300 项各点一下就有数，不需要在终端和 DevTools 之间来回切。
/// 细粒度归 DevTools，判据归这一页。
///
/// ## 读数纪律（写在页面上，因为第一次看一定会犯错）
///
/// - 切档后**至少等 2 秒**再读：`FrameRateMonitor` 的窗口是 120 帧，
///   切档那一帧的 IO 会把 p95 拉高；
/// - HUD 每 15 帧刷新一次 —— 低频刷新是为了不让 HUD 自己的重建混进读数；
/// - 看 `p95 帧间隔`，不要只看平均 fps：平均 58 而 p95 40 ms 的体验比
///   稳定 45 差。
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/constants.dart';
import 'frame_draw_target.dart';
import 'frame_painter.dart';
import 'frame_stats.dart';
import 'scene_source.dart';

/// 面板底色 —— 比纯黑亮一点，让半透明边线看得见。
const Color _background = Color(0xFF0B0D12);
const Color _panelBackground = Color(0xE6181C26);
const Color _textPrimary = Color(0xFFE6EAF2);
const Color _textSecondary = Color(0xFF8D96A8);
const Color _verdictGood = Color(0xFF3DD98B);
const Color _verdictWarn = Color(0xFFE0A63C);
const Color _verdictBad = Color(0xFFE4574C);
const Color _chipSelected = Color(0xFF2E3648);
const Color _chipIdle = Color(0xFF151922);

/// 自转一圈的时长。慢到能看清，快到 2 秒内覆盖几个不同遮挡关系。
const Duration _spinPeriod = Duration(seconds: 24);

/// HUD 刷新间隔（帧）。见文件头「读数纪律」。
const int _hudEveryNFrames = 15;

/// 一屏读数。`null` 表示该项还没产出（刚切档 / 样本不足）。
class HudSnapshot {
  const HudSnapshot({
    required this.originLabel,
    required this.itemCount,
    required this.edgeCount,
    required this.notes,
    required this.report,
    required this.projectMs,
    required this.paintMs,
    required this.stats,
    required this.fallbackReason,
  });

  const HudSnapshot.empty()
    : originLabel = '—',
      itemCount = 0,
      edgeCount = 0,
      notes = const <String>[],
      report = null,
      projectMs = 0,
      paintMs = 0,
      stats = null,
      fallbackReason = null;

  final String originLabel;
  final int itemCount;
  final int edgeCount;
  final List<String> notes;
  final FrameDrawReport? report;
  final double projectMs;
  final double paintMs;
  final FrameRateSnapshot? stats;
  final String? fallbackReason;
}

class UniverseSpikeScreen extends StatefulWidget {
  const UniverseSpikeScreen({super.key});

  @override
  State<UniverseSpikeScreen> createState() => _UniverseSpikeScreenState();
}

class _UniverseSpikeScreenState extends State<UniverseSpikeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  final FrameRateMonitor _monitor = FrameRateMonitor();
  final ValueNotifier<HudSnapshot> _hud = ValueNotifier<HudSnapshot>(
    const HudSnapshot.empty(),
  );

  late SceneBundle _scene;
  SceneOrigin _requested = SceneOrigin.synthetic;
  String? _fallbackReason;

  FrameDrawReport? _report;
  double _projectMs = 0;
  double _paintMs = 0;
  int _framesSinceHud = 0;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: _spinPeriod)..repeat();
    // 默认走合成：一进页面就有画面，不会因为 dist/ 没构建而黑屏。
    _scene = buildSyntheticScene();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    // 先 stop 再 dispose：`repeat()` 的 ticker 还活着时直接 dispose 会撞
    // `Ticker` 的 active 断言。
    _spin
      ..stop()
      ..dispose();
    _hud.dispose();
    super.dispose();
  }

  /// 每帧的绘制报告。**只写字段，不 setState** —— 这里在 paint 阶段。
  void _onRepaint(FrameDrawReport report, double projectMs, double paintMs) {
    _report = report;
    _projectMs = projectMs;
    _paintMs = paintMs;
  }

  void _onTimings(List<FrameTiming> timings) {
    _monitor.add(timings);
    _framesSinceHud += timings.length;
    if (_framesSinceHud < _hudEveryNFrames) {
      return;
    }
    _framesSinceHud = 0;
    _hud.value = HudSnapshot(
      originLabel: _scene.origin.label,
      itemCount: _scene.itemCount,
      edgeCount: _scene.edgeCount,
      notes: _scene.notes,
      report: _report,
      projectMs: _projectMs,
      paintMs: _paintMs,
      stats: _monitor.snapshot(),
      fallbackReason: _fallbackReason,
    );
  }

  void _select(SceneOrigin origin) {
    if (origin == _requested) {
      return;
    }
    final SceneResolution resolution = switch (origin) {
      SceneOrigin.alphaPack => resolveAlphaScene(),
      SceneOrigin.synthetic => SceneResolution(bundle: buildSyntheticScene()),
      SceneOrigin.syntheticDoubled => SceneResolution(
        bundle: buildSyntheticScene(copies: 2),
      ),
    };

    // 旧窗口的样本属于上一份场景，留着会污染新档的 p95。
    _monitor.reset();
    setState(() {
      _requested = origin;
      _scene = resolution.bundle;
      _fallbackReason = resolution.fallbackReason;
      _report = null;
      _hud.value = const HudSnapshot.empty();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: FramePainter(
                  scene: _scene,
                  spin: _spin,
                  onRepaint: _onRepaint,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: ValueListenableBuilder<HudSnapshot>(
              valueListenable: _hud,
              builder: (BuildContext context, HudSnapshot hud, Widget? child) {
                return _HudPanel(hud: hud);
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _Controls(requested: _requested, onSelect: _select),
          ),
        ],
      ),
    );
  }
}

/// 左上角的读数面板。
class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.hud});

  final HudSnapshot hud;

  @override
  Widget build(BuildContext context) {
    final FrameRateSnapshot? stats = hud.stats;
    final Color verdict = _verdictColor(stats);
    final List<Widget> rows = <Widget>[
      _row('数据源', '${hud.originLabel}（${hud.itemCount} 项 · ${hud.edgeCount} 边）'),
    ];

    final FrameDrawReport? report = hud.report;
    if (report != null) {
      rows.add(
        _row(
          'draw call',
          '${report.dots} 圆 + ${report.strokes} 线 = ${report.total}'
          '（虚线 ${report.dashedEdges} 条 → ${report.dashedSegments} 段）',
        ),
      );
      rows.add(
        _row(
          '耗时',
          '投影 ${hud.projectMs.toStringAsFixed(2)} ms'
          ' · 绘制 ${hud.paintMs.toStringAsFixed(2)} ms',
        ),
      );
      if (report.offscreenDots > 0) {
        rows.add(_row('屏外节点', '${report.offscreenDots}（仍发绘制调用）'));
      }
    }

    if (stats == null) {
      rows.add(_row('帧率', '采样中…（需 ≥20 帧）'));
    } else {
      rows.add(
        _row(
          '帧率',
          '${stats.fps.toStringAsFixed(1)} fps'
          '（中位 ${stats.frameP50Ms.toStringAsFixed(1)} ms'
          ' · p95 ${stats.frameP95Ms.toStringAsFixed(1)} ms · ${stats.samples} 帧）',
          valueColor: verdict,
        ),
      );
      rows.add(
        _row(
          '线程耗时 p95',
          'UI ${stats.buildP95Ms.toStringAsFixed(2)} ms'
          ' · 光栅 ${stats.rasterP95Ms.toStringAsFixed(2)} ms',
        ),
      );
      rows.add(
        _row(
          '判据 C-32',
          stats.meetsGood
              ? '≥$frameGoodFps fps（优线）'
              : stats.meetsTarget
              ? '≥$frameTargetFps fps（达标，未到优线 $frameGoodFps）'
              : '未达 $frameTargetFps fps ⇒ 需回写 adr/0002',
          valueColor: verdict,
        ),
      );
    }

    final String? fallback = hud.fallbackReason;
    if (fallback != null) {
      rows.add(_row('回落', fallback, valueColor: _verdictBad));
    }
    for (final String note in hud.notes.take(2)) {
      rows.add(_row('·', note));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _panelBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? _textPrimary,
              fontSize: 12,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static Color _verdictColor(FrameRateSnapshot? stats) {
    if (stats == null) {
      return _textSecondary;
    }
    if (stats.meetsGood) {
      return _verdictGood;
    }
    return stats.meetsTarget ? _verdictWarn : _verdictBad;
  }
}

/// 底部档位条。
class _Controls extends StatelessWidget {
  const _Controls({required this.requested, required this.onSelect});

  /// 档位顺序（理由见 `build` 里的注释）。
  static const List<SceneOrigin> _chipOrder = <SceneOrigin>[
    SceneOrigin.synthetic,
    SceneOrigin.syntheticDoubled,
    SceneOrigin.alphaPack,
  ];

  final SceneOrigin requested;
  final void Function(SceneOrigin origin) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '切档后等 2 秒再读 · HUD 每 $_hudEveryNFrames 帧刷新 · 判据 C-32（$frameTargetFps / $frameGoodFps fps）',
          style: const TextStyle(color: _textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            // 顺序刻意是「合成 → 合成 ×2 → 真实包」：先在无 IO 的两档建立基线，
            // 再看真实包这一档 —— 反过来会把 IO 与几何的成本混在一起读。
            for (final SceneOrigin origin in _chipOrder)
              _Chip(
                label: '${origin.label}（${origin == SceneOrigin.syntheticDoubled ? 300 : 150} 项）',
                selected: origin == requested,
                onTap: () => onSelect(origin),
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _chipSelected : _chipIdle,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _textPrimary : _textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// 宇宙视图（`SPEC-VIEW-001` / `VIEW-018`）。**`B3` 笔 2 的 UI 半边。**
///
/// 与 spike 共用同一条渲染路径（`FramePainter` + `projectProjection`），
/// 差别只在：这里挂的是**正式界面**（五档刻度 + HUD 七区块），而
/// `universe_spike_screen` 是测量装置，保留下来供 `STR` 轮次 `R1` 复跑。
///
/// ## 七区块的显示规则（`SPEC-VIEW-018` / `VIEW-019`）
///
/// | # | 位置 | 何时显示 |
/// |---|---|---|
/// | ① | 顶部左 | 常显（面包屑） |
/// | ② | 顶部第二行 | **有筛选才出现**（`axisFilter` 非空） |
/// | ③ | 右上 | 常显 |
/// | ④ | 右侧 | **仅 `Z4`**（详情是 `Z4` 的形态，`VIEW-013`） |
/// | ⑤ | 中心偏左 | 常显（焦点星） |
/// | ⑥ | 左下 | 常显（六轴罗盘，输入器） |
/// | ⑦ | 底部中央 | 常显（视距刻度，主导航） |
library;

import 'package:flutter/material.dart';

import '../../core/view/zoom.dart';
import 'frame_painter.dart';
import 'scene_source.dart';

/// 七区块的 `Key` —— widget test 靠它断言「该出现的出现了、不该出现的没出现」。
const Key hudBreadcrumbKey = Key('hud-breadcrumb');
const Key hudFilterChipsKey = Key('hud-filter-chips');
const Key hudScopeSettingsKey = Key('hud-scope-settings');
const Key hudDetailDrawerKey = Key('hud-detail-drawer');
const Key hudFocusStarKey = Key('hud-focus-star');
const Key hudAxisCompassKey = Key('hud-axis-compass');
const Key hudZoomScaleKey = Key('hud-zoom-scale');

const Color _background = Color(0xFF0B0D12);
const Color _panelColor = Color(0xE6181C26);
const Color _textPrimary = Color(0xFFE6EAF2);
const Color _textSecondary = Color(0xFF8D96A8);

/// 自转一圈的时长。慢到能看清，又不至于让人以为界面卡住。
const Duration _spinPeriod = Duration(seconds: 24);

const double _cameraPitch = 0.42;

class UniverseScreen extends StatefulWidget {
  const UniverseScreen({required this.scene, this.initialZoom = ZoomLevel.z1, super.key});

  final SceneBundle scene;

  /// 进入时的档位。真实入口由「当前上下文」决定，本笔先给默认。
  final ZoomLevel initialZoom;

  @override
  State<UniverseScreen> createState() => _UniverseScreenState();
}

class _UniverseScreenState extends State<UniverseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  late CameraState _camera;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: _spinPeriod)..repeat();
    _camera = CameraState(
      zoom: widget.initialZoom,
      yawRadians: 0,
      pitchRadians: _cameraPitch,
    );
  }

  @override
  void dispose() {
    // 先 stop 再 dispose：`repeat()` 的 ticker 还活着时直接 dispose 会撞断言。
    _spin
      ..stop()
      ..dispose();
    super.dispose();
  }

  void _switchZoom(ZoomLevel next) {
    if (next == _camera.zoom) {
      return;
    }
    // `withZoom` 保留 yaw / pitch —— 切档不重置视角（`SPEC-VIEW-009`）。
    setState(() => _camera = _camera.withZoom(next));
  }

  @override
  Widget build(BuildContext context) {
    final bool showDetail = _camera.zoom == ZoomLevel.z4;
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: FramePainter(
                  scene: widget.scene,
                  spin: _spin,
                  baseYaw: _camera.yawRadians,
                  onRepaint: (_, _, _) {},
                ),
                size: Size.infinite,
              ),
            ),
          ),
          _positioned(
            left: 16,
            top: 16,
            child: _panel(
              key: hudBreadcrumbKey,
              child: Text(
                '宇宙 › ${_camera.zoom.code} ${_camera.zoom.label}',
                style: const TextStyle(color: _textPrimary, fontSize: 12),
              ),
            ),
          ),
          // ② 筛选 chips：按 `VIEW-019` 是**状态栏，激活才出现**。本笔还没有
          // `axisFilter` 状态，故按规格**不渲染** —— 留一个常显的占位框会让
          // 「有筛选才出现」这条规则从第一天起就失效。
          _positioned(
            right: 16,
            top: 16,
            child: _panel(
              key: hudScopeSettingsKey,
              child: const Text('圈内 · 设置', style: TextStyle(color: _textSecondary, fontSize: 12)),
            ),
          ),
          _positioned(
            right: 16,
            top: 80,
            child: showDetail
                ? _panel(
                    key: hudDetailDrawerKey,
                    child: const Text('详情', style: TextStyle(color: _textPrimary, fontSize: 12)),
                  )
                : const SizedBox.shrink(),
          ),
          Center(
            child: _hiddenSlot(hudFocusStarKey, '焦点星'),
          ),
          _positioned(
            left: 16,
            bottom: 72,
            child: _panel(
              key: hudAxisCompassKey,
              child: const Text('六轴罗盘', style: TextStyle(color: _textSecondary, fontSize: 12)),
            ),
          ),
          _positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _panel(
              key: hudZoomScaleKey,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final ZoomLevel level in ZoomLevel.values)
                    _zoomChip(level),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomChip(ZoomLevel level) {
    final bool selected = level == _camera.zoom;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () => _switchZoom(level),
        style: TextButton.styleFrom(
          backgroundColor: selected ? const Color(0xFF2E3648) : null,
          foregroundColor: selected ? _textPrimary : _textSecondary,
          minimumSize: const Size(56, 32),
        ),
        child: Text('${level.code} ${level.label}', style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _positioned({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required Widget child,
  }) => Positioned(left: left, right: right, top: top, bottom: bottom, child: child);

  Widget _panel({Key? key, required Widget child}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: _panelColor, borderRadius: BorderRadius.circular(8)),
    child: child,
  );

  /// 占位槽：本笔不实现内容，但**保留可见的落位**（否则七区块的规则无从测起）。
  Widget _hiddenSlot(Key key, String label) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10)),
  );
}

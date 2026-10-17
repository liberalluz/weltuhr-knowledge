/// 宇宙 / 树两种视图的宿主（`SPEC-VIEW-001` / `010` / `012` / `018`）。
///
/// ## 七区块在各模式下的显示规则
///
/// | # | 位置 | 宇宙 | 树 |
/// |---|---|---|---|
/// | ① | 顶部左 | 常显（面包屑 + **模式切换**） | 同左 |
/// | ② | 顶部第二行 | 有筛选才出现 | 同左 |
/// | ③ | 右上 | 常显 | 常显 |
/// | ④ | 右侧 | **仅 `Z4`** | **常驻右栏**（`VIEW-012`） |
/// | ⑤ | 中心偏左 | 常显（焦点星） | **不渲染** —— 树里选中行就是焦点 |
/// | ⑥ | 左下 | 常显（六轴罗盘） | **不渲染**（`VIEW-011`：二维没有方位） |
/// | ⑦ | 底部中央 | 常显（视距刻度） | 常显，点击 = 切回宇宙并定档 |
///
/// ## 切换为什么是交叉淡入
///
/// `VIEW-010`：宇宙位置由 `r/θ/φ` 决定、树位置由 `⪯` 缩进决定，两者**不同构**。
/// 任何「宇宙收拢成一棵树」的过渡都在造一个既不是宇宙也不是树的中间状态，
/// 所以只做 `C-22` 区间的交叉淡入。
///
/// **相机状态跨模式保留**（`VIEW-009` 末句）：来回切换不重置 yaw / pitch。
/// 树 → 宇宙的档位由**选中项的 `φ`** 定，不由「树里展开到第几层」定。
///
/// ## 本笔没有做的
///
/// - 跨空间搜索（`VIEW-031`）：`Locator` 现在只收一个 `LoadedPack`，要收
///   `List<LoadedPack>` 才能「在全部空间中搜索」。归笔 7。
///
/// ## 绘制表面封顶（`C-33` / `ADR-0002` 修订三）
///
/// 窗口再大，绘制表面也只到 `C-33` 的基准面积为止，然后靠 `FittedBox` 放大贴满
/// —— 光栅成本跟的是**绘制表面**，不是窗口。判据用**物理面积**
/// （`w·h·dpr²`，见 `planViewport`）：只看逻辑尺寸的话，高分屏上这条封顶等于
/// 不存在。拾取因此必须吃**画布坐标**而不是窗口坐标，同时手势不能拿
/// `details.localPosition`（`FittedBox` 下命中的 RenderBox 不一定是画布盒）。
///
/// ## 点星与罗盘（本笔接上的两个输入器）
///
/// 这个宿主此前是**只读**的：宇宙画得出来，但点不动 —— 所有输入只能从树或
/// 定位浮层走。`VIEW-014` 的六入口里，宇宙点星是第一个；`VIEW-019` 把 ⑥ 定成
/// 「加筛选」的输入器、② 定成「看和删」的状态栏，此前只有后者是真的。
///
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/entities/content.dart';
import '../../core/enums.dart';
import '../../core/locate/locator.dart';
import '../../core/pack/pack_parse.dart';
import '../../core/view/detail.dart';
import '../../core/view/filter.dart';
import '../../core/view/tree.dart';
import '../../core/view/viewport.dart';
import '../../core/view/zoom.dart';
import '../detail/detail_panel.dart';
import '../locate/locate_overlay.dart';
import '../palette.dart';
import 'filter_chips.dart';
import 'frame_painter.dart';
import 'scene_pick.dart';
import 'scene_source.dart';
import 'tree_view.dart';

/// 七区块的 `Key` —— widget test 靠它断言「该出现的出现了、不该出现的没出现」。
const Key hudBreadcrumbKey = Key('hud-breadcrumb');
const Key hudFilterChipsKey = Key('hud-filter-chips');
const Key hudScopeSettingsKey = Key('hud-scope-settings');
const Key hudDetailDrawerKey = Key('hud-detail-drawer');
const Key hudFocusStarKey = Key('hud-focus-star');
const Key hudAxisCompassKey = Key('hud-axis-compass');
const Key hudZoomScaleKey = Key('hud-zoom-scale');

/// 模式切换的容器（在 ① 内，见文件头表格）。
const Key hudModeSwitchKey = Key('hud-mode-switch');

/// ⑥ 罗盘里某个轴按钮（点它展开 / 收起该轴的取值）。`VIEW-020`。
Key compassAxisKey(String axisKey) => Key('compass-axis-$axisKey');

/// ⑥ 罗盘展开后，某个轴取值的那一行（点它写 / 取消筛选）。
Key compassValueKey(String axisKey, String value) =>
    Key('compass-value-$axisKey-$value');

/// ⑥ 罗盘面板宽度。六个轴名一行排得下，取值列表也不至于把画面挤没。
const double _compassWidth = 236;

/// ⑥ 罗盘展开取值列表的最大高度。超出就滚动 —— 一个轴的取值可能几十个，
/// 不封顶会把整块画面吃掉（而它是左下角的**输入器**，不是主视图）。
const double _compassValuesMaxHeight = 220;

/// 自转一圈的时长。慢到能看清，又不至于让人以为界面卡住。
const Duration _spinPeriod = Duration(seconds: 24);

const double _cameraPitch = 0.42;

/// 树模式右栏（详情常驻）的宽度。
const double _drawerWidth = 380;

/// 树模式给右栏让出的横向空间（含右外边距）。
const double _drawerReserve = _drawerWidth + 32;

/// ② 所在的一行占多高。树视图要在有筛选时把顶部让出这么多，
/// 否则 chips 会压在树的第一行上（`VIEW-018` 把 ② 定在顶部第二行）。
const double _filterRowHeight = 40;

class UniverseScreen extends StatefulWidget {
  const UniverseScreen({
    required this.scene,
    this.pack,
    this.initialZoom = ZoomLevel.z1,
    this.initialMode = ViewMode.universe,
    super.key,
  });

  final SceneBundle scene;

  /// 真实内容包。`null` = 合成回落 ⇒ 树视图与详情都拿不到 `Item`，界面降级成
  /// 「没有可展开的树」，而不是画一棵空树（`SPEC-FND-014` 未声明即不渲染）。
  final LoadedPack? pack;

  /// 进入时的档位。真实入口由「当前上下文」决定，本笔先给默认。
  final ZoomLevel initialZoom;

  /// 进入时的模式。默认宇宙。
  final ViewMode initialMode;

  @override
  State<UniverseScreen> createState() => _UniverseScreenState();
}

class _UniverseScreenState extends State<UniverseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  late CameraState _camera;
  late ViewMode _mode;

  /// 当前选中项。**与 `CameraState.selectedItemId` 分开存**：后者是「宇宙里
  /// Z4 聚焦谁」，退出 Z4 就该清（`VIEW-013`）；而选中项跨模式保留，否则
  /// 树 → 宇宙 → 树 一走，用户还得重新找自己刚才在看什么。
  String? _selectedItemId;

  /// ② 的筛选表达式（DNF）。空 = 不过滤，② 整块不渲染（`VIEW-018`）。
  AxisFilter _axisFilter = emptyAxisFilter;

  /// 定位浮层是否打开（`VIEW-026`：浮层，不常驻）。
  bool _locating = false;

  /// ⑥ 罗盘当前展开的轴（`VIEW-020` 就地展开）。`null` = 六个轴都收起。
  ///
  /// 一次只展开一个轴：罗盘是「选一个轴、挑几个值」的短流程，同时摊开六个
  /// 轴的取值会变成长列表，而 `VIEW-020` 否掉的正是「让用户在两处往返挑」。
  String? _compassAxis;

  /// 屏幕根的焦点节点。`⌘K` / `Ctrl+K` 靠它接键（见 `_closeLocate`）。
  final FocusNode _rootFocus = FocusNode(debugLabel: 'universe-root');

  /// 画布盒。拾取要用 `globalToLocal` 把指针位置映到它上面（见 `_universeBody`）。
  final GlobalKey _canvasKey = GlobalKey(debugLabel: 'universe-canvas');

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: _spinPeriod)..repeat();
    _camera = CameraState(
      zoom: widget.initialZoom,
      yawRadians: 0,
      pitchRadians: _cameraPitch,
    );
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    // 先 stop 再 dispose：`repeat()` 的 ticker 还活着时直接 dispose 会撞断言。
    _spin
      ..stop()
      ..dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  void _switchZoom(ZoomLevel next) {
    if (next == _camera.zoom && _mode == ViewMode.universe) {
      return;
    }
    setState(() {
      // `withZoom` 保留 yaw / pitch —— 切档不重置视角（`SPEC-VIEW-009`）。
      _camera = _camera.withZoom(next, selectedItemId: _selectedItemId);
      // 视距是宇宙的导航层级：点刻度即回宇宙（树里没有「Z2 的树」这种东西）。
      _mode = ViewMode.universe;
    });
  }

  void _switchMode(ViewMode next) {
    if (next == _mode) {
      return;
    }
    setState(() {
      if (next == ViewMode.universe) {
        // `VIEW-009`：树 → 宇宙按选中项的 `φ` 定档，不按展开深度。
        _camera = _camera.withZoom(
          _zoomForSelection(),
          selectedItemId: _selectedItemId,
        );
      }
      _mode = next;
    });
  }

  /// 选中项决定回宇宙时落哪一档。没有选中 ⇒ 留在当前档。
  ZoomLevel _zoomForSelection() {
    final LoadedPack? pack = widget.pack;
    final String? id = _selectedItemId;
    if (pack == null || id == null) {
      return _camera.zoom;
    }
    final bool hasChildren = pack.edges.any((Edge edge) => edge.from == id);
    return zoomForPhi(phiLevelsOf(pack)[id] ?? 0, hasChildren: hasChildren);
  }

  void _select(String itemId) => setState(() => _selectedItemId = itemId);

  // ── 快速定位（`SPEC-VIEW-024`–`033`） ───────────────────────────────────

  void _openLocate() => setState(() => _locating = true);

  /// 关浮层，并把焦点收回屏幕根。
  ///
  /// 为什么必须收：浮层里的输入框占着主焦点，浮层一拆，那个 `FocusNode` 就被
  /// 销毁 —— 主焦点落空之后 `⌘K` 没有节点接着冒泡，**第二次搜索打不开**
  /// （表现是「快捷键只灵一次」）。等到这一帧拆完再请求焦点，否则收上来的焦点
  /// 会在同一帧里被「销毁输入框」这一步又推走。
  void _closeLocate() {
    setState(() => _locating = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rootFocus.requestFocus();
      }
    });
  }

  /// 一条命中的落点。**这是整个搜索唯一的行为出口**。
  ///
  /// 浮层只负责「输入 → 命中集 → 用户选了哪条」，跳哪一档、写不写筛选都在这里。
  /// 拆开的好处是浮层能单独测，而「点完之后世界怎么变」只有一处可读。
  void _applyHit(LocateResult result, LocateHit hit) {
    _closeLocate();
    switch (hit.kind) {
      case LocateKind.item:
        _jumpToItem(hit.target);
      case LocateKind.domain:
        _jumpToDomain(hit.target);
      case LocateKind.space:
        // 空间是 `Z0` 那一层（`VIEW-001` 末句：`Z0` 展示全部空间）。
        setState(() {
          _mode = ViewMode.universe;
          _camera = _camera.withZoom(ZoomLevel.z0);
        });
      case LocateKind.axis:
        // 筛选类：**只写 `axisFilter`，不换根**（`VIEW-028`）。视距与模式
        // 一律不动 —— 用户是在收窄当前视野，不是要去别处。
        final String? axisKey = hit.axisKey;
        if (axisKey == null) {
          return;
        }
        setState(() {
          _axisFilter = toggleAxisValue(_axisFilter, axisKey, hit.target);
        });
    }
  }

  /// 落点：选中该项并**直接推到 `Z4`**（`VIEW-014` / `027`）。
  ///
  /// ⚠️ 这里**不用** `zoomForPhi`。`VIEW-009` 的「按 `φ` 定档」管的是
  /// 「树 → 宇宙」—— 那是在问「我在树里翻到的位置，换算成宇宙的哪一层」。
  /// 搜索是相反的问题：「我要这一项」。按 `φ` 定档会把用户送到它所在的
  /// 星云（`Z2`），而他要找的那颗星只有 `Z4` 才看得见 —— 那等于搜完还得
  /// 再点一次，`VIEW-027`「唯一命中直接跳转」就白写了。
  void _jumpToItem(String itemId) {
    if (widget.pack == null) {
      return;
    }
    setState(() {
      _selectedItemId = itemId;
      _mode = ViewMode.universe;
      _camera = _camera.withZoom(ZoomLevel.z4, selectedItemId: itemId);
    });
  }

  /// 域是落点类（`VIEW-028`），但宇宙里没有「选中一个域」这个状态 ——
  /// 落到 `Z2`（星云 = 域那一层，`SPEC-VIEW-001` 的面包屑示例）并顺手选中
  /// 该域最浅的一项：档位给出「这个域有多大」，选中项给出「从哪开始看」。
  ///
  /// **不推到 `Z4`**：域不是一项，推到单星等于替用户挑了一颗星，而他刚才
  /// 问的是「这个域在哪」。
  void _jumpToDomain(String domainId) {
    final LoadedPack? pack = widget.pack;
    if (pack == null) {
      return;
    }
    final Map<String, int> levels = phiLevelsOf(pack);
    final List<Item> inDomain = <Item>[
      for (final Item item in pack.items)
        if (item.domainId == domainId) item,
    ];
    if (inDomain.isEmpty) {
      return;
    }
    inDomain.sort((Item a, Item b) {
      final int phiA = levels[a.id] ?? 0;
      final int phiB = levels[b.id] ?? 0;
      return phiA == phiB ? a.title.compareTo(b.title) : phiA.compareTo(phiB);
    });
    setState(() {
      _selectedItemId = inDomain.first.id;
      _mode = ViewMode.universe;
      _camera = _camera.withZoom(
        ZoomLevel.z2,
        selectedItemId: inDomain.first.id,
      );
    });
  }

  /// 类 ②「措辞不同」的邻近候选（`VIEW-030`）：**先关门再落点**。
  ///
  /// 与命中走同一条落点路径（`_jumpToItem`）—— 它虽然不是命中，但用户选它
  /// 就是要那一项；区别只在「选完要不要关浮层」，而命中的那条在 `_applyHit`
  /// 开头已经关了。
  void _pickNear(String itemId) {
    _closeLocate();
    _jumpToItem(itemId);
  }

  // ── 宇宙点星（`SPEC-VIEW-014` 入口 1） ──────────────────────────────────

  /// 点星 → 进详情。
  ///
  /// 落点与搜索命中**完全一致**（`_jumpToItem`：选中 + 推到 `Z4`），因为
  /// `VIEW-013` 把详情定义成「`Z4` 的渲染形态」，而不是另一个页面。两处若
  /// 各判各的档，同一个项从搜索进去和从星图点进去会落在不同视距上 —— 用户
  /// 会以为点错了东西。
  ///
  /// **点空白什么都不做**（见 `core/frame/pick.dart` 文件头）：清掉选中会让
  /// 详情抽屉毫无预警地消失，而点歪是常态。
  ///
  /// [point] 是**画布坐标**（手势挂在画布内部，见 `_universeBody`）。
  /// [surface] 是画布尺寸 —— 降采样后它与窗口不等，拾取必须用画布这一套。
  void _pickAt(Offset point, Size surface, Set<String>? visibleIds) {
    final String? id = pickSceneNode(
      scene: widget.scene,
      viewport: surface,
      // 自转一直在动：用**这一刻**的偏航，不是基准偏航。
      yawRadians: spunYaw(_camera.yawRadians, _spin.value),
      point: point,
      visibleIds: visibleIds,
    );
    if (id == null) {
      return;
    }
    _jumpToItem(id);
  }

  void _removeFilter(AxisFilterChip chip) {
    setState(() {
      _axisFilter = withoutAxisValue(_axisFilter, chip.axisKey, chip.value);
    });
  }

  void _clearFilter() => setState(() => _axisFilter = emptyAxisFilter);

  // ── ⑥ 罗盘（`SPEC-VIEW-019` / `020`） ───────────────────────────────────

  /// 展开 / 收起某个轴的取值。再点同一个轴就收起。
  void _toggleCompassAxis(String axisKey) {
    setState(() => _compassAxis = _compassAxis == axisKey ? null : axisKey);
  }

  /// 点一个取值：已选则去掉，未选则加上。
  ///
  /// 与 ② 的 `×` 是**同一个操作的两处入口**（`VIEW-019`：⑥ 负责加、② 负责
  /// 看和删，「删除与取消等价」）。两处都调 `withoutAxisValue` —— 若在这里
  /// 另写「从列表里摘掉」，空轴就不会被删键，`axisFilter` 里会留下一个
  /// 没有值的幽灵轴，而 ② 会数出一个空 chip。
  void _toggleCompassValue(String axisKey, String value) {
    final bool selected = (_axisFilter[axisKey] ?? const <String>[]).contains(
      value,
    );
    setState(() {
      _axisFilter = selected
          ? withoutAxisValue(_axisFilter, axisKey, value)
          : toggleAxisValue(_axisFilter, axisKey, value);
    });
  }

  /// 当前筛选下可见的项 id。`null` = 没筛（**不是空集**）。
  Set<String>? _visibleIds() {
    final LoadedPack? pack = widget.pack;
    if (pack == null) {
      return null;
    }
    return visibleIdsOf(pack, _axisFilter);
  }

  ItemDetail? _detail() {
    final LoadedPack? pack = widget.pack;
    final String? id = _selectedItemId;
    if (pack == null || id == null) {
      return null;
    }
    return buildItemDetail(pack, id);
  }

  @override
  Widget build(BuildContext context) {
    final ItemDetail? detail = _detail();
    final bool tree = _mode == ViewMode.tree;
    final bool showDetail = tree || _camera.zoom == ZoomLevel.z4;
    final Set<String>? visibleIds = _visibleIds();
    final bool filtered = visibleIds != null;

    // `⌘K` / `Ctrl+K` 挂在屏幕根上（`VIEW-026`）：搜索的价值是「手不离开键盘」，
    // 先找一个按钮就等于把那一步省下的时间又还回去了。
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openLocate,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openLocate,
      },
      child: Focus(
        focusNode: _rootFocus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: paletteBackground,
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: viewTransitionMs),
                  // 默认 transitionBuilder 就是 FadeTransition，两个 child 叠着淡入淡出。
                  // **不加任何形变**（`VIEW-010`）：滑动 / 缩放都会让「不同构」这件事
                  // 看起来像「同一个东西的两种形态」。
                  child: KeyedSubtree(
                    key: ValueKey<ViewMode>(_mode),
                    child: tree
                        ? _treeBody(filtered)
                        : _universeBody(visibleIds),
                  ),
                ),
              ),
              if (showDetail)
                Positioned(
                  right: 16,
                  top: tree ? 64 : 80,
                  bottom: tree ? 72 : null,
                  width: _drawerWidth,
                  child: DetailPanel(
                    key: hudDetailDrawerKey,
                    detail: detail,
                    // 树里是「右栏常驻」，宽壳归整页入口（笔 4）—— 两种形态用同一个
                    // widget，只换紧凑度（`VIEW-017`）。
                    compact: true,
                    onSelectItem: _select,
                  ),
                ),
              _positioned(
                left: 16,
                top: 16,
                child: _panel(
                  key: hudBreadcrumbKey,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tree
                                ? '树 › 全空间'
                                : '宇宙 › ${_camera.zoom.code} ${_camera.zoom.label}',
                            style: const TextStyle(
                              color: paletteTextPrimary,
                              fontSize: 12,
                            ),
                          ),
                          // 诊断行：**空画面时先看这一行**。若写「合成」，说明内容包没找到
                          // （运行期 CWD 不在 `app/`），而不是渲染坏了。
                          Text(
                            '${widget.scene.origin.label} · ${widget.scene.itemCount} 项'
                            ' · ${widget.scene.edgeCount} 边'
                            ' · ${widget.scene.radialSegments} 段',
                            style: const TextStyle(
                              color: paletteTextSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      // 模式切换挂在 ① 内：面包屑是「我在哪」，模式也是「我在哪」的
                      // 一部分；进 ⑦ 会污染「视距刻度」的单一职责，进 ③ 会把它变成
                      // 用户找不到的功能。
                      _modeSwitch(),
                    ],
                  ),
                ),
              ),
              _positioned(
                right: 16,
                top: 16,
                child: _panel(
                  key: hudScopeSettingsKey,
                  child: const Text(
                    '圈内 · 设置',
                    style: TextStyle(color: paletteTextSecondary, fontSize: 12),
                  ),
                ),
              ),
              // ⑤ 焦点星：树里不渲染 —— 树里「选中行」就是焦点（见文件头表格）。
              if (!tree) Center(child: _hiddenSlot(hudFocusStarKey, '焦点星')),
              // ⑥ 六轴罗盘：`VIEW-011` 树里没有方位，保留即成假控件。
              if (!tree) _positioned(left: 16, bottom: 72, child: _compass()),
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
              // ② 筛选状态栏：**有筛选才出现**（`VIEW-018`），放在 ① 下方。
              if (filtered)
                _positioned(
                  left: 16,
                  top: 72,
                  child: FilterChips(
                    key: hudFilterChipsKey,
                    filter: _axisFilter,
                    matched: visibleIds.length,
                    total: widget.pack?.items.length,
                    onRemove: _removeFilter,
                    onClear: _clearFilter,
                  ),
                ),
              // 定位浮层盖在最上层：它打开时是模态的，底下的一切都只是参照。
              if (_locating) Positioned.fill(child: _locateLayer()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locateLayer() => LocateOverlay(
    pack: widget.pack,
    domainId: _domainId(),
    // `VIEW-033`：只有一个空间时不给前缀 —— 每行都写一遍同一个空间名是噪音，
    // 而它要解决的问题（同名项分不清是哪个空间的）在单空间下不存在。
    onPick: _applyHit,
    // 类 ②「措辞不同」的邻近候选：点了就是真落点，与命中同一条路径。
    onPickNear: _pickNear,
    onDismiss: _closeLocate,
  );

  /// 当前视图的域上下文 = **选中项所在的域**（`VIEW-030` ③ / ④ 的分野）。
  ///
  /// 为什么不用档位：档位只说「离得多近」。在 `Z1` 上看着一堆星系、什么都
  /// 没选时，硬说「你在某个域里」会让分诊凭空多出一个 ③，于是把新项塞进
  /// 一个用户并没有在看的域 —— 那比只记一句需求更糟。
  String? _domainId() {
    final LoadedPack? pack = widget.pack;
    final String? id = _selectedItemId;
    if (pack == null || id == null) {
      return null;
    }
    return pack.itemOf(id)?.domainId;
  }

  Widget _universeBody(Set<String>? visibleIds) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      // 视口尺寸要**与 painter 拿到的一致**。用 `constraints` 而不是
      // `context.size`：后者在首帧是 null，而首帧就点是不该崩的。
      final Size window = Size(constraints.maxWidth, constraints.maxHeight);
      // 绘制表面按**物理面积**封顶（`C-33` / `ADR-0002` 修订二）：4K、以及
      // Retina 这类高分屏，都靠这一步把光栅成本拉回基准窗口的量级。
      final ViewportPlan plan = planViewport(
        window.width,
        window.height,
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      final Size surface = Size(plan.surfaceWidth, plan.surfaceHeight);

      final Widget canvas = RepaintBoundary(
        // ⚠️ 尺寸必须由 `SizedBox` **强制**给，不能只写 `CustomPaint.size`：
        // `size` 只是 preferred，父级给的 tight 约束会把它推翻 —— 那样绘制按
        // 窗口尺寸画、拾取按画布尺寸算，两边错开。
        child: SizedBox.fromSize(
          key: _canvasKey,
          size: surface,
          child: CustomPaint(
            painter: FramePainter(
              scene: widget.scene,
              spin: _spin,
              baseYaw: _camera.yawRadians,
              visibleIds: visibleIds,
              onRepaint: (_, _, _) {},
            ),
          ),
        ),
      );

      // ⚠️ 外层 `SizedBox` 不是多余：`AnimatedSwitcher` 的 `Stack` 给的是
      // **loose 约束**，`FittedBox` 在 loose 下只会「保持比例地缩到装得下」——
      // 于是画布停在 554×416、居中显示，四周留底，降采样后的放大根本没发生
      // （实测画布盒在窗口里居中，点击坐标整体偏 (123, 92)）。
      // 给它一个 tight 的窗口尺寸，`BoxFit.fill` 才会把它铺满。
      return SizedBox.fromSize(
        size: window,
        child: GestureDetector(
          // `opaque`：空白处也要接住点击，否则点在星与星的缝里会穿透到底下。
          behavior: HitTestBehavior.opaque,
          // ⚠️ **不能用 `details.localPosition`**。它相对的是「手势命中的那个
          // RenderBox」，而 `FittedBox` 下不保证落在画布盒上。把全局坐标显式
          // 映到画布盒，不依赖命中路径怎么走。
          onTapUp: (TapUpDetails details) {
            final RenderBox? box =
                _canvasKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null || !box.hasSize) {
              return;
            }
            _pickAt(
              box.globalToLocal(details.globalPosition),
              surface,
              visibleIds,
            );
          },
          // `FittedBox` 只在真降了分辨率时才包一层：`scale == 1` 时它是纯开销，
          // 而宇宙每帧都在重绘。
          child: plan.isDownscaled
              ? FittedBox(fit: BoxFit.fill, child: canvas)
              : canvas,
        ),
      );
    },
  );

  Widget _treeBody(bool filtered) => Padding(
    padding: EdgeInsets.only(
      // 右栏是浮层（`hudDetailDrawerKey`），树要给它让位，否则末端的 φ 标签被盖住。
      right: _drawerReserve,
      // 有筛选时 ② 占着顶部第二行，树整体下移 —— 树自己的 margin 只留出了 ① 的高度。
      top: filtered ? _filterRowHeight : 0,
    ),
    child: TreeView(
      pack: widget.pack,
      selectedItemId: _selectedItemId,
      visibleIds: _visibleIds(),
      onSelect: _select,
    ),
  );

  /// 宇宙 ⇄ 树。两个按钮而不是一个 toggle：**当前在哪**应该一眼看到，而不是
  /// 从「按钮上的字是什么」倒推。
  Widget _modeSwitch() => Padding(
    key: hudModeSwitchKey,
    padding: const EdgeInsets.only(left: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ViewMode mode in <ViewMode>[
          ViewMode.universe,
          ViewMode.tree,
        ])
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: TextButton(
              onPressed: () => _switchMode(mode),
              style: TextButton.styleFrom(
                backgroundColor: _mode == mode ? paletteSelected : null,
                foregroundColor: _mode == mode
                    ? paletteTextPrimary
                    : paletteTextSecondary,
                minimumSize: const Size(48, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                mode == ViewMode.universe ? '宇宙' : '树',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
      ],
    ),
  );

  // ── ⑥ 罗盘的渲染 ────────────────────────────────────────────────────────

  /// ⑥ = **输入器**（`VIEW-019`）：六个轴名 → 就地展开取值 → 点一次选、再点取消。
  ///
  /// 不做「点 ⑥ 唤起 ② 再在 ② 上选」：`VIEW-020` 明确否掉了那条路 ——
  /// 六个轴各 5–8 个值，本来是一屏装得下的短选择，变成两处往返之后就没人用了。
  Widget _compass() {
    final LoadedPack? pack = widget.pack;
    final String? openAxis = _compassAxis;
    return SizedBox(
      width: _compassWidth,
      child: _panel(
        key: hudAxisCompassKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              // 没有包就没有轴值可选。写清原因而不是给一排按不动的按钮 ——
              // 按不动的控件会被读成「功能坏了」。
              pack == null ? '六轴罗盘 · 没有内容包' : '六轴罗盘',
              style: const TextStyle(color: paletteTextSecondary, fontSize: 10),
            ),
            if (pack != null) ...<Widget>[
              const SizedBox(height: 4),
              Wrap(
                spacing: 2,
                runSpacing: 2,
                children: <Widget>[
                  for (final String axisKey in sixAxisKeys)
                    _compassAxisChip(axisKey),
                ],
              ),
              if (openAxis != null) ...<Widget>[
                const Divider(height: 14, color: paletteLine),
                _compassValues(pack, openAxis),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 一个轴按钮。带「·N」= 这个轴已选了多少个值（`VIEW-019` 要求不看 ②
  /// 也知道自己筛了什么 —— ② 会被滚出视线的场景就是「筛完继续看星」）。
  Widget _compassAxisChip(String axisKey) {
    final int count = (_axisFilter[axisKey] ?? const <String>[]).length;
    final bool open = _compassAxis == axisKey;
    return TextButton(
      key: compassAxisKey(axisKey),
      onPressed: () => _toggleCompassAxis(axisKey),
      style: TextButton.styleFrom(
        backgroundColor: open ? paletteSelected : null,
        foregroundColor: count > 0 ? paletteTextPrimary : paletteTextSecondary,
        minimumSize: const Size(0, 26),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        count > 0
            ? '${sixAxisLabels[axisKey] ?? axisKey} ·$count'
            : sixAxisLabels[axisKey] ?? axisKey,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  /// 展开后的取值列表。取值域来自包（`axisValuesOf`），**不写死任何选项**：
  /// 换个包就是另一批值，预设选项在第二个包上立刻过时。
  Widget _compassValues(LoadedPack pack, String axisKey) {
    final List<String> values = axisValuesOf(pack, axisKey);
    final List<String> selected = _axisFilter[axisKey] ?? const <String>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${sixAxisLabels[axisKey] ?? axisKey} · 再点一次取消',
          style: const TextStyle(color: paletteTextSecondary, fontSize: 10),
        ),
        const SizedBox(height: 2),
        if (values.isEmpty)
          const Text(
            '这一轴在包里没有取值',
            style: TextStyle(color: paletteTextSecondary, fontSize: 11),
          )
        else
          ConstrainedBox(
            // 上限 + 滚动，而不是 `Flexible`：外层是 `mainAxisSize.min` 的
            // `Column`，`Flexible` 在那里会拿到 0 高度（笔 4a 踩过）。
            constraints: const BoxConstraints(
              maxHeight: _compassValuesMaxHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final String value in values)
                    _compassValueRow(axisKey, value, selected.contains(value)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _compassValueRow(String axisKey, String value, bool selected) {
    return InkWell(
      key: compassValueKey(axisKey, value),
      onTap: () => _toggleCompassValue(axisKey, value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 13,
              color: selected ? paletteTextPrimary : paletteTextSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? paletteTextPrimary : paletteTextSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomChip(ZoomLevel level) {
    final bool selected = level == _camera.zoom && _mode == ViewMode.universe;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () => _switchZoom(level),
        style: TextButton.styleFrom(
          backgroundColor: selected ? paletteSelected : null,
          foregroundColor: selected ? paletteTextPrimary : paletteTextSecondary,
          minimumSize: const Size(56, 32),
        ),
        child: Text(
          '${level.code} ${level.label}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _positioned({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required Widget child,
  }) => Positioned(
    left: left,
    right: right,
    top: top,
    bottom: bottom,
    child: child,
  );

  Widget _panel({Key? key, required Widget child}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: palettePanel,
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );

  /// 占位槽：本笔不实现内容，但**保留可见的落位**（否则七区块的规则无从测起）。
  Widget _hiddenSlot(Key key, String label) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Text(
      label,
      style: const TextStyle(color: paletteTextSecondary, fontSize: 10),
    ),
  );
}

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
/// - 宇宙里点星拾取（`VIEW-014` 的第一个入口）：`FramePainter` 还没有
///   hit test，选中只能从树里来。归下一笔（点选）。
/// - 无命中的四类分诊与表单兜底（`VIEW-030` / `032`）：浮层先如实说「没有命中」。
///   在「搜不到」上直接挂「新增」正是规格要防的事，所以宁愿先不给。
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
import '../../core/view/zoom.dart';
import '../detail/detail_panel.dart';
import '../locate/locate_overlay.dart';
import '../palette.dart';
import 'filter_chips.dart';
import 'frame_painter.dart';
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

  void _closeLocate() => setState(() => _locating = false);

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

  void _removeFilter(AxisFilterChip chip) {
    setState(() {
      _axisFilter = withoutAxisValue(_axisFilter, chip.axisKey, chip.value);
    });
  }

  void _clearFilter() => setState(() => _axisFilter = emptyAxisFilter);

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
              if (!tree)
                _positioned(
                  left: 16,
                  bottom: 72,
                  child: _panel(
                    key: hudAxisCompassKey,
                    child: const Text(
                      '六轴罗盘',
                      style: TextStyle(
                        color: paletteTextSecondary,
                        fontSize: 12,
                      ),
                    ),
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
    // `VIEW-033`：只有一个空间时不给前缀 —— 每行都写一遍同一个空间名是噪音，
    // 而它要解决的问题（同名项分不清是哪个空间的）在单空间下不存在。
    onPick: _applyHit,
    onDismiss: _closeLocate,
  );

  Widget _universeBody(Set<String>? visibleIds) => RepaintBoundary(
    child: CustomPaint(
      painter: FramePainter(
        scene: widget.scene,
        spin: _spin,
        baseYaw: _camera.yawRadians,
        visibleIds: visibleIds,
        onRepaint: (_, _, _) {},
      ),
      size: Size.infinite,
    ),
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

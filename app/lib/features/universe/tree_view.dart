/// 树视图（`SPEC-VIEW-006` / `007` / `008` / `011` / `012`）。
///
/// 树与宇宙的面包屑**同构**：四层，`知识` → 空间 → 域 → 项（`VIEW-006` 修订）。
/// 行模型在 `core/view/tree.dart`（`buildTree`），这里只负责把它画出来并管展开态
/// —— 域内排序、四类行的归属、首屏展开到 `φ` 几层全在核心层，因为那些都是
/// 可判定的规则，不是手感。
///
/// ## 两个可点区（`VIEW-006` 修订第 3 条）
///
/// 层级节点（空间 / 域）一行里有两个可点区：**箭头折叠、名字选中**。合成一个
/// 的话，想收起一个展开着的域就得先把选中挪过去 —— 用户按的是「收起」，不是
/// 「进这个域」。
///
/// | 行 | 箭头 | 名字 |
/// |---|---|---|
/// | `知识` | **没有**（恒展开） | 不可点 —— 树里没有「比知识更外」的地方 |
/// | 空间 | 折叠该空间的域 | **换根**（`_onSwitchRoot`），留在树里 |
/// | 域 | 折叠该域的项 | 选中该域（面包屑第 3 段，抽屉不开） |
/// | 项 | — | 选中该项（详情右栏） |
///
/// ## 四类行的视觉（`VIEW-007`「必须可区分」）
///
/// | 类 | 视觉 |
/// |---|---|
/// | 层级行（空间 / 域） | 白字 + 展开箭头（`expandable` 才有） |
/// | 圈内项 | 实心、正常字重 |
/// | 黑洞 | 斜体 + 虚线行底 + **无箭头** |
/// | 圈外邻项 | 次要字色 + 尾部「圈外」+ 虚线标记 |
///
/// 靠**文字标记**而不只靠线型：线型在小尺寸下糊成一片时，至少「圈外」两个字
/// 还在。规格只要求可区分，没规定只能靠线。
///
/// ## 没有罗盘
///
/// `VIEW-011`：六轴罗盘承载 `θ` 扇区方位，二维树没有方位 —— 保留即成假控件。
/// 本 widget 因此**不画罗盘**，由 `universe_screen` 在树模式下不渲染 ⑥。
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/pack/pack_parse.dart';
import '../../core/view/tree.dart';
import '../palette.dart';

/// 树视图根节点。
const Key treeViewKey = Key('tree-view');

/// 缺包时的空态（合成回落路径）。
const Key treeEmptyKey = Key('tree-empty');

/// 某一行的**名字区** `Key` —— 点它等于「选中这一行」（`VIEW-012`）。
Key treeRowKey(TreeRow row) => Key('tree-row-${row.kind.name}-${row.id}');

/// 某一行的**折叠箭头** `Key` —— 点它等于「展开 / 收起」（`VIEW-006` 修订）。
///
/// 与 [treeRowKey] 分开：合成一个就等于把「选中」和「展开」绑成同一件事，
/// 而这两件事在空间行上**后果完全不同**（换根 / 只是展开）。
Key treeArrowKey(TreeRow row) => Key('tree-arrow-${row.kind.name}-${row.id}');

/// 一行离左边的距离。
///
/// 层间差恒为 `C-91`（0 / 14 / 28 / 42 px，`VIEW-006` 修订），项内再按 `φ`
/// 追加、封顶 `C-92` 级。⚠️ 不在这里加统一内边距：那会让「第 3 层 = 28 px」
/// 这条判据量出来是 36，而验收表写的是 28。
double rowIndentOf(TreeRow row) {
  final double base = row.depth * treeLevelIndent;
  if (row.kind != TreeRowKind.item &&
      row.kind != TreeRowKind.outsideNeighbor) {
    return base;
  }
  final int phi = row.phiLevel > treePhiIndentCap
      ? treePhiIndentCap
      : row.phiLevel;
  return base + phi * treeLevelIndent;
}

/// 树里点了一行：回传**它属于哪个空间**与它自己。
///
/// 必须带空间：树里能展开别的空间，点它的项 / 域就得先换根 —— 而屏幕层只靠 id
/// 反推空间，等于假定 id 全局唯一（包格式没这么规定）。
typedef TreePick = void Function(String spaceId, String id);

const double _leadWidth = 24;
const double _rowVerticalPadding = 5;

class TreeView extends StatefulWidget {
  const TreeView({
    required this.packs,
    required this.spaceId,
    required this.onSelectItem,
    required this.onSelectDomain,
    required this.onSwitchRoot,
    this.selectedItemId,
    this.selectedDomainId,
    this.visibleIds,
    super.key,
  });

  /// 全部根。`知识` = 所有空间，所以这里收一组而不是一个（`VIEW-006` 修订）。
  /// 空 ⇒ 合成回落，画空态。
  final List<LoadedPack> packs;

  /// 当前根的空间 id。
  final String? spaceId;

  final String? selectedItemId;

  /// 当前选中的域（`null` = 没选中域）。只影响那一行的字色 —— 选中域不开抽屉
  /// （`VIEW-006` 修订第 4 条），所以「选上了」这件事必须在行上看得见。
  final String? selectedDomainId;

  final TreePick onSelectItem;
  final TreePick onSelectDomain;

  /// 树里换根（`VIEW-006` 修订第 2 条）：换到该空间，**仍停在树里**。
  final ValueChanged<String> onSwitchRoot;

  /// ② 的筛选结果（`SPEC-VIEW-021`），`null` = 不过滤。只作用于当前根。
  final Set<String>? visibleIds;

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> {
  /// 展开的空间 / 域。
  ///
  /// 初值：空间只展开**当前根**，域展开当前根的全部域 —— 与补上空间层之前
  /// 「首屏全展开」的观感一致，只是别的空间收着一行。
  ///
  /// ⚠️ **在 `initState` 里就落成具体值**，不留「`null` 就按默认算」的回落：
  /// 回落式写法下，「换根后把新根补进展开集」这一步永远不会被触发（默认值本来
  /// 就跟着 `spaceId` 走），于是那一步是死代码 —— 而它一死，用户在树里收起过
  /// 任何一个空间之后，再换根就再也展不开新根。两种写法在「从没点过」的路径上
  /// 结果完全相同，反证也分不出来；区别只在点过一次之后。
  late Set<String> _expandedSpaces;
  late Set<String> _expandedDomains;

  @override
  void initState() {
    super.initState();
    _expandedSpaces = <String>{if (widget.spaceId != null) widget.spaceId!};
    _expandedDomains = _currentPack?.space.domainIds.toSet() ?? <String>{};
  }

  LoadedPack? get _currentPack {
    for (final LoadedPack pack in widget.packs) {
      if (pack.space.id == widget.spaceId) {
        return pack;
      }
    }
    return widget.packs.isEmpty ? null : widget.packs.first;
  }


  @override
  void didUpdateWidget(TreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId == widget.spaceId) {
      return;
    }
    // 换根之后必须把新根**补进展开集**：不补的话，用户在树里点了空间名，
    // 根换了、那一行却仍是收起的 —— 点击的唯一可见后果是「什么都没发生」。
    _expandedSpaces = <String>{
      ..._expandedSpaces,
      if (widget.spaceId != null) widget.spaceId!,
    };
    _expandedDomains = <String>{
      ..._expandedDomains,
      ...?_currentPack?.space.domainIds,
    };
  }

  void _toggleSpace(String spaceId) {
    final Set<String> current = <String>{..._expandedSpaces};
    if (!current.remove(spaceId)) {
      current.add(spaceId);
    }
    setState(() => _expandedSpaces = current);
  }

  void _toggleDomain(String domainId) {
    final Set<String> current = <String>{..._expandedDomains};
    if (!current.remove(domainId)) {
      current.add(domainId);
    }
    setState(() => _expandedDomains = current);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.packs.isEmpty) {
      return Container(
        key: treeEmptyKey,
        padding: const EdgeInsets.all(16),
        color: palettePanel,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '没有可展开的树',
              style: TextStyle(color: paletteTextPrimary, fontSize: 13),
            ),
            SizedBox(height: 6),
            Text(
              '当前是合成场景（内容包未找到），节点是凭空造的编号，没有域与项。'
              '请在 app/ 下启动，或先构建内容包。',
              style: TextStyle(
                color: paletteTextSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    final LoadedPack? current = _currentPack;
    final List<TreeRow> rows = buildTree(
      widget.packs,
      spaceId: widget.spaceId,
      expandedSpaces: _expandedSpaces,
      expandedDomains: _expandedDomains,
      visibleIds: widget.visibleIds,
    );
    final int shown = widget.visibleIds?.length ?? current?.items.length ?? 0;

    return Container(
      key: treeViewKey,
      margin: const EdgeInsets.fromLTRB(16, 64, 8, 72),
      decoration: BoxDecoration(
        color: palettePanel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              // 「展开到 φ」按**当前根**算：别的空间各有自己的 `maxφ`，报一个
              // 与屏幕上的项数对不上的数，用户会以为树坏了。
              '树 · $shown 项 · ${current?.space.domainIds.length ?? 0} 域'
              ' · 展开到 φ=${current == null ? 0 : initialExpandPhi(maxPhiOf(current))}',
              style: const TextStyle(color: paletteTextSecondary, fontSize: 11),
            ),
          ),
          const Divider(height: 1, color: paletteLine),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: rows.length,
              itemBuilder: (BuildContext context, int index) =>
                  _row(rows[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(TreeRow row) {
    return Container(
      // 左内边距 = 层缩进，右内边距固定：右边留的是给「圈外」「φN」标签的地方，
      // 它不该跟着缩进走 —— 跟着走的会让深层行的标签顶到屏幕外。
      padding: EdgeInsets.only(left: 8 + rowIndentOf(row), right: 12),
      decoration: row.kind == TreeRowKind.blackHole
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: paletteLine, width: 1),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _lead(row),
          Expanded(
            child: InkWell(
              key: treeRowKey(row),
              onTap: _onNameTapOf(row),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _rowVerticalPadding,
                ),
                child: Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _colorOf(row),
                    fontSize: row.depth <= 1 ? 13 : 12,
                    fontWeight: row.depth <= 1
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontStyle: row.kind == TreeRowKind.blackHole
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ),
          ),
          // 当前根那一行挂「当前」：树里同时列着所有空间，而面包屑只写当前那一个
          // —— 没有这个标记，用户点完一行只能靠面包屑确认换没换成。
          if (row.kind == TreeRowKind.space && row.id == widget.spaceId)
            _tag('当前'),
          if (row.kind == TreeRowKind.outsideNeighbor) _tag('圈外'),
          if (row.phiLevel > 0) _tag('φ${row.phiLevel}'),
        ],
      ),
    );
  }

  /// 行首：折叠箭头 / 虚线标记 / 空白。
  Widget _lead(TreeRow row) {
    final bool isLevelRow =
        row.kind == TreeRowKind.root ||
        row.kind == TreeRowKind.space ||
        row.kind == TreeRowKind.domain;
    if (isLevelRow) {
      // `知识` 恒展开 ⇒ 不给箭头（`VIEW-006` 修订第 3 条）。给了就是一个
      // 点下去什么都不变的东西 —— 假控件。
      if (!row.expandable) {
        return const SizedBox(width: _leadWidth);
      }
      return SizedBox(
        width: _leadWidth,
        child: InkResponse(
          key: treeArrowKey(row),
          onTap: row.kind == TreeRowKind.space
              ? () => _toggleSpace(row.id)
              : () => _toggleDomain(row.id),
          radius: _leadWidth / 2,
          child: Icon(
            row.expanded
                ? Icons.keyboard_arrow_down
                : Icons.keyboard_arrow_right,
            size: 16,
            color: paletteTextSecondary,
          ),
        ),
      );
    }
    if (row.dashed) {
      return SizedBox(
        width: _leadWidth,
        child: CustomPaint(
          painter: _DashedStubPainter(
            color: row.kind == TreeRowKind.blackHole
                ? paletteGap
                : paletteTextSecondary,
          ),
          child: const SizedBox(height: 10),
        ),
      );
    }
    return const SizedBox(width: _leadWidth);
  }

  Widget _tag(String text) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Text(
      text,
      style: const TextStyle(color: paletteTextSecondary, fontSize: 10),
    ),
  );

  Color _colorOf(TreeRow row) {
    switch (row.kind) {
      case TreeRowKind.root:
      case TreeRowKind.space:
        return paletteTextPrimary;
      case TreeRowKind.domain:
        return row.id == widget.selectedDomainId
            ? paletteAccent
            : paletteTextPrimary;
      case TreeRowKind.item:
        return row.id == widget.selectedItemId
            ? paletteAccent
            : paletteTextPrimary;
      case TreeRowKind.blackHole:
        return paletteGap;
      case TreeRowKind.outsideNeighbor:
        return paletteTextSecondary;
    }
  }

  /// 名字区点了做什么。`null` = 这一行没有「选中」这件事。
  VoidCallback? _onNameTapOf(TreeRow row) {
    // 空间行没有 `spaceId` 才奇怪：它是被构树时写上去的。缺了就当没点，
    // 不拿 `widget.spaceId` 兜底 —— 那会把「别的空间的一项」错算进当前根。
    final String? spaceId = row.spaceId;
    switch (row.kind) {
      case TreeRowKind.root:
        // 树里没有「比知识更外」的地方：回 `Z0` 的入口在面包屑第 1 段
        // （`VIEW-018` 修订 2）。这里再放一个，等于同一个去处开两个门。
        return null;
      case TreeRowKind.space:
        return () => widget.onSwitchRoot(row.id);
      case TreeRowKind.domain:
        return spaceId == null
            ? null
            : () => widget.onSelectDomain(spaceId, row.id);
      case TreeRowKind.item:
      case TreeRowKind.outsideNeighbor:
        return spaceId == null
            ? null
            : () => widget.onSelectItem(spaceId, row.id);
      case TreeRowKind.blackHole:
        // 黑洞没有实体，点了也没有详情可看（`VIEW-007`：无展开箭头、不进详情）。
        return null;
    }
  }
}

/// 虚线短划 —— 圈外邻项与黑洞的行首标记。
class _DashedStubPainter extends CustomPainter {
  const _DashedStubPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    final double mid = size.height / 2;
    for (double x = 0; x + 3 < size.width; x += 6) {
      canvas.drawLine(Offset(x, mid), Offset(x + 3, mid), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedStubPainter oldDelegate) =>
      oldDelegate.color != color;
}

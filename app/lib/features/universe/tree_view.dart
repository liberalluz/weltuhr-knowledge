/// 树视图（`SPEC-VIEW-006` / `007` / `008` / `011` / `012`）。
///
/// 树只画**容器层级**：域 → 项。行模型在 `core/view/tree.dart`（`buildTree`），
/// 这里只负责把它画出来并管展开态 —— 域内排序、四类行的归属、首屏展开到 `φ`
/// 几层全在核心层，因为那些都是可判定的规则，不是手感。
///
/// ## 四类行的视觉（`VIEW-007`「必须可区分」）
///
/// | 类 | 视觉 |
/// |---|---|
/// | 域 | 白字 + 展开箭头（`expandable` 才有） |
/// | 圈内项 | 实心、正常字重 |
/// | 黑洞 | 斜体 + 前置 `?` + 虚线行底 + **无箭头** |
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

import '../../core/pack/pack_parse.dart';
import '../../core/view/tree.dart';
import '../palette.dart';

/// 树视图根节点。
const Key treeViewKey = Key('tree-view');

/// 缺包时的空态（合成回落路径）。
const Key treeEmptyKey = Key('tree-empty');

/// 某一行的 `Key`。
Key treeRowKey(TreeRow row) => Key('tree-row-${row.kind.name}-${row.id}');

class TreeView extends StatefulWidget {
  const TreeView({
    required this.pack,
    required this.selectedItemId,
    required this.onSelect,
    this.visibleIds,
    super.key,
  });

  /// `null` = 走的是合成回落，没有可展开的项。
  final LoadedPack? pack;
  final String? selectedItemId;
  final ValueChanged<String> onSelect;

  /// ② 的筛选结果（`SPEC-VIEW-021`），`null` = 不过滤。
  final Set<String>? visibleIds;

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> {
  /// 展开的域。**首屏全展开**（`VIEW-008`：根 + 域 + `φ=1` 层）—— 域是根的
  /// 第一层，初始就展开；展开到 `φ` 几层由 `initialExpandPhi` 管，与域展开是两个维度。
  Set<String>? _expanded;

  Set<String> _expandedOf(LoadedPack pack) =>
      _expanded ?? pack.space.domainIds.toSet();

  void _toggleDomain(String domainId) {
    final LoadedPack? pack = widget.pack;
    if (pack == null) {
      return;
    }
    final Set<String> current = <String>{..._expandedOf(pack)};
    if (!current.remove(domainId)) {
      current.add(domainId);
    }
    setState(() => _expanded = current);
  }

  @override
  Widget build(BuildContext context) {
    final LoadedPack? pack = widget.pack;
    if (pack == null) {
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

    final int maxPhi = maxPhiOf(pack);
    final List<TreeRow> rows = buildTree(
      pack,
      expandedDomains: _expandedOf(pack),
      expandToPhi: initialExpandPhi(maxPhi),
      visibleIds: widget.visibleIds,
    );
    final int shown = widget.visibleIds?.length ?? pack.items.length;

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
              '树 · $shown 项 · ${pack.space.domainIds.length} 域'
              ' · 展开到 φ=${initialExpandPhi(maxPhi)}',
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
    final double indent = row.depth == 0 ? 8 : 26;
    return InkWell(
      key: treeRowKey(row),
      onTap: _onTapOf(row),
      child: Container(
        padding: EdgeInsets.fromLTRB(indent, 5, 12, 5),
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
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _colorOf(row),
                  fontSize: row.depth == 0 ? 13 : 12,
                  fontWeight: row.depth == 0
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontStyle: row.kind == TreeRowKind.blackHole
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
            if (row.kind == TreeRowKind.outsideNeighbor) _tag('圈外'),
            if (row.phiLevel > 0) _tag('φ${row.phiLevel}'),
          ],
        ),
      ),
    );
  }

  /// 行首：展开箭头 / 虚线标记。
  Widget _lead(TreeRow row) {
    if (row.kind == TreeRowKind.domain) {
      return SizedBox(
        width: 18,
        child: row.expandable
            ? Icon(
                _expandedOf(widget.pack!).contains(row.id)
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 16,
                color: paletteTextSecondary,
              )
            // 空域：没有可展开的东西，也就不给箭头（给了就是假控件）。
            : const SizedBox.shrink(),
      );
    }
    if (row.dashed) {
      return SizedBox(
        width: 18,
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
    return const SizedBox(width: 18);
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
      case TreeRowKind.domain:
        return paletteTextPrimary;
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

  VoidCallback? _onTapOf(TreeRow row) {
    switch (row.kind) {
      case TreeRowKind.domain:
        return row.expandable ? () => _toggleDomain(row.id) : null;
      case TreeRowKind.item:
      case TreeRowKind.outsideNeighbor:
        return () => widget.onSelect(row.id);
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

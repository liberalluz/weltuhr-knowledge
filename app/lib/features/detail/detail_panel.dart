/// 详情面板：**三区 + 笔记区**（`SPEC-VIEW-013` / `VIEW-014` / `VIEW-017`）。
///
/// ```
/// 页头：标题 · 域 · 层级 · 类型 ·（差 N 格）
/// ① 关系   前置 / 后继 / 缺口         ← 可点跳转（VIEW-014）
/// ② 要件   六要件三态
/// ③ 来源   源名 + 等级 + 摘录
/// ④ 笔记   本笔为空壳（NOTE 笔填充，NOTE-007 定的第四分区）
/// ```
///
/// ## 为什么两壳共用一个 widget
///
/// `VIEW-017` 要求宽壳（整页）与窄壳（右侧抽屉）**三区 + 笔记区字段与顺序完全
/// 一致**。做成两个 widget 之后，一致性靠「改一处记得改另一处」—— 那是
/// `R-08` 说的「形状保证挡得住改、挡不住加」。所以只留一个，窄壳靠 [compact]
/// 收窄内边距与来源摘录的行数，不动字段、不动顺序。
///
/// ## 返回（`VIEW-015` / `VIEW-016`）
///
/// 面板只负责**画**那个按钮并把点击原样交出去。有没有可退的地方、退到哪一项，
/// 全在屏幕的 [`_goBack`] —— 面板不知道 `trail` 有多长，也不该知道：让它算
/// 「能不能退」就等于把导航状态复制进了视图层，而复制品会与原件不同步。
///
/// `onBack` 为 `null` 时不渲染按钮。给一个按下去没反应的按钮，用户会读成
/// 「功能坏了」而不是「这里就是起点」。
///
/// ## 本笔没有做的
///
/// - 笔记区内容（`SPEC-NOTE-007`）：只留落位与 `Key`，不造空输入框 ——
///   可输入的框会让人以为写完能存。
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/view/detail.dart';
import '../palette.dart';

/// 面板根节点。
const Key detailPanelKey = Key('detail-panel');

/// 三个分区 + 笔记区，按显示顺序。
const Key detailRelationsSectionKey = Key('detail-section-relations');
const Key detailRequirementsSectionKey = Key('detail-section-requirements');
const Key detailProvenanceSectionKey = Key('detail-section-provenance');
const Key detailNotesSectionKey = Key('detail-section-notes');

/// 某一行的 `Key`。缺口行没有 `itemId` ⇒ 用标题兜底，同一次渲染里仍然唯一。
Key detailRelationRowKey(RelationRow row) =>
    Key('detail-relation-${row.itemId ?? 'gap:${row.label}'}');

/// 返回按钮（`VIEW-015` / `VIEW-016`）。`onBack` 为 `null` 时整块不渲染。
const Key detailBackKey = Key('detail-back');

/// 按钮文案。抽出来是给测试断言用，也免得「返回」与「←」两处各写一份。
const String detailBackLabel = '返回';

/// 关系分组的小标题（顺序即显示顺序）。
const List<RelationKind> _relationOrder = <RelationKind>[
  RelationKind.prerequisite,
  RelationKind.successor,
  RelationKind.gap,
];

/// 六要件的显示名（`docs/reference/entity-fields.md` §1）。
const Map<RequirementKey, String> _requirementLabels = <RequirementKey, String>{
  RequirementKey.boundary: '边界',
  RequirementKey.justification: '证成',
  RequirementKey.proposition: '命题',
  RequirementKey.relation: '关联',
  RequirementKey.how: 'How',
  RequirementKey.tacit: 'Tacit',
};

/// 三态的显示名。**不合格的写「缺」而不是留空** —— 空着读不出是「缺」还是
/// 「没查」。
const Map<RequirementState, String> _requirementStateLabels =
    <RequirementState, String>{
      RequirementState.present: '齐',
      RequirementState.missing: '缺',
      RequirementState.notExternalizable: '不可外化',
    };

/// 层级与类型的显示名已上收到 `core/constants.dart`（`P-8`：候选卡的「适用
/// 范围」是第二处要用的地方，两份副本会分叉），这里直接用 `layerLabels` /
/// `itemTypeLabels`。

class DetailPanel extends StatelessWidget {
  const DetailPanel({
    required this.detail,
    this.compact = false,
    this.onSelectItem,
    this.onBack,
    super.key,
  });

  /// `null` = 没有选中项（或选中的 id 不在包里）⇒ 空态。
  final ItemDetail? detail;

  /// 窄壳（右侧抽屉）：内边距收窄、来源摘录只显示第一段。
  final bool compact;

  /// 关系行点击 ⇒ 跳到对方项（`VIEW-014`）。
  final ValueChanged<String>? onSelectItem;

  /// 返回一步（`VIEW-015` / `VIEW-016`）。
  ///
  /// `null` = 没有可退的地方 ⇒ **不渲染按钮**。给一个按下去没反应的按钮，用户
  /// 会读成「功能坏了」，而不是「这里就是起点」。
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ItemDetail? current = detail;
    if (current == null) {
      return Container(
        key: detailPanelKey,
        padding: EdgeInsets.all(compact ? 12 : 20),
        decoration: _decoration,
        child: const Text(
          '未选中知识项',
          style: TextStyle(color: paletteTextSecondary, fontSize: 12),
        ),
      );
    }

    final double pad = compact ? 12 : 20;
    return Container(
      key: detailPanelKey,
      padding: EdgeInsets.all(pad),
      decoration: _decoration,
      // `SingleChildScrollView` + `Column`，不是 `ListView`：详情是**固定结构**的
      // 四段，不是长列表。用惰性列表时下面的分区要等滚到才存在 —— 顺序断言与
      // 「两壳内容一致」都只能靠滚动去凑，而那是布局行为，不是内容契约。
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _header(current),
            SizedBox(height: pad),
            _relationsSection(current),
            SizedBox(height: pad),
            _requirementsSection(current),
            SizedBox(height: pad),
            _provenanceSection(current),
            SizedBox(height: pad),
            _notesSection(),
          ],
        ),
      ),
    );
  }

  BoxDecoration get _decoration => BoxDecoration(
    color: palettePanel,
    borderRadius: BorderRadius.circular(8),
  );

  Widget _header(ItemDetail detail) {
    final List<String> facts = <String>[
      detail.domainLabel,
      layerLabels[detail.layer] ?? detail.layer.name,
      itemTypeLabels[detail.type] ?? detail.type.name,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          _backRow(onBack!),
          const SizedBox(height: 6),
        ],
        Text(
          detail.title,
          style: const TextStyle(
            color: paletteTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          facts.join(' · '),
          style: const TextStyle(color: paletteTextSecondary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: <Widget>[
            if (detail.gapCount > 0)
              _badge('差 ${detail.gapCount} 格', paletteGap)
            else
              _badge('六要件齐', paletteTextSecondary),
            if (detail.gapRelationCount > 0)
              _badge('${detail.gapRelationCount} 处缺口', paletteGap),
            if (!detail.inScope) _badge('圈外', paletteTextSecondary),
          ],
        ),
      ],
    );
  }

  /// 返回行。做成一行小字而不是 `IconButton`：详情面板窄（320），一个 48×48
  /// 的按钮会把标题挤成两行，而「返回」在这里是低优先级的出口。
  Widget _backRow(VoidCallback onBack) => InkWell(
    key: detailBackKey,
    onTap: onBack,
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '←',
            style: TextStyle(color: paletteTextSecondary, fontSize: 12),
          ),
          SizedBox(width: 4),
          Text(
            detailBackLabel,
            style: TextStyle(color: paletteTextSecondary, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 10)),
  );

  /// ① 关系。按 [RelationKind] 分组，组内保持包的边序（内容作者的顺序）。
  Widget _relationsSection(ItemDetail detail) {
    final List<Widget> children = <Widget>[_sectionTitle('关系')];
    if (detail.relations.isEmpty) {
      children.add(_muted('没有任何前置或后继 —— 它是孤点'));
    }
    for (final RelationKind kind in _relationOrder) {
      final List<RelationRow> rows = detail.relations
          .where((RelationRow r) => r.kind == kind)
          .toList();
      if (rows.isEmpty) {
        continue;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${kind.label} · ${rows.length}',
            style: const TextStyle(color: paletteTextSecondary, fontSize: 10),
          ),
        ),
      );
      for (final RelationRow row in rows) {
        children.add(_relationRow(row));
      }
    }
    return _section(detailRelationsSectionKey, children);
  }

  Widget _relationRow(RelationRow row) {
    final bool tappable = row.tappable && onSelectItem != null;
    final Color color = row.kind == RelationKind.gap
        ? paletteGap
        : paletteTextPrimary;
    final Widget label = Row(
      children: <Widget>[
        // 虚线 = 弱依赖 / 指向未知，与宇宙的线型同源（`VIEW-002` 的线型规则）。
        SizedBox(
          width: 14,
          child: CustomPaint(
            painter: _DashMarkPainter(dashed: row.dashed, color: color),
            child: const SizedBox(height: 12),
          ),
        ),
        Expanded(
          child: Text(
            row.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontStyle: row.kind == RelationKind.gap
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ),
        if (row.outside)
          Text(
            '圈外',
            style: TextStyle(color: paletteTextSecondary, fontSize: 10),
          ),
      ],
    );

    return Padding(
      key: detailRelationRowKey(row),
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: tappable
          ? InkWell(
              onTap: () => onSelectItem!(row.itemId!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: label,
              ),
            )
          : label,
    );
  }

  /// ② 要件。六格顺序固定为 [RequirementKey.values]。
  Widget _requirementsSection(ItemDetail detail) =>
      _section(detailRequirementsSectionKey, <Widget>[
        _sectionTitle('要件'),
        for (final RequirementRow row in detail.requirements)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 44,
                  child: Text(
                    _requirementLabels[row.key] ?? row.key.name,
                    style: const TextStyle(
                      color: paletteTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  _requirementStateLabels[row.state] ?? row.state.wire,
                  style: TextStyle(
                    color: row.isGap
                        ? paletteGap
                        : row.isTacit
                        ? paletteTextSecondary
                        : paletteTextPrimary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ]);

  /// ③ 来源。**只列文本，不参与任何视觉编码**（`SPEC-VIEW-004`）—— 换一本教材
  /// 这里会变，星星不会。
  Widget _provenanceSection(ItemDetail detail) =>
      _section(detailProvenanceSectionKey, <Widget>[
        _sectionTitle('来源'),
        if (detail.provenance.isEmpty) _muted('未标注来源'),
        for (final ProvenanceRow row in detail.provenance) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    row.name,
                    style: TextStyle(
                      color: row.missing ? paletteGap : paletteTextPrimary,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  row.levelLabel,
                  style: const TextStyle(
                    color: paletteTextSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          for (final ProvenanceSegment segment
              in compact ? row.segments.take(1) : row.segments)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    segment.locator,
                    style: const TextStyle(
                      color: paletteTextSecondary,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    segment.text,
                    style: const TextStyle(
                      color: paletteTextSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ]);

  /// ④ 笔记区空壳。**不放输入框**：能输入会让人以为写完能存。
  Widget _notesSection() => _section(detailNotesSectionKey, <Widget>[
    _sectionTitle('笔记'),
    _muted('笔记功能未开放（NOTE 笔）'),
  ]);

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: paletteTextPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _muted(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: const TextStyle(color: paletteTextSecondary, fontSize: 11),
    ),
  );

  Widget _section(Key key, List<Widget> children) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  );
}

/// 关系行左侧的线型标记：实线 / 虚线一望可辨。
class _DashMarkPainter extends CustomPainter {
  const _DashMarkPainter({required this.dashed, required this.color});

  final bool dashed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final double mid = size.height / 2;
    final double width = size.width - 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, mid), Offset(width, mid), paint);
      return;
    }
    // 三个短划：够看出「虚」，又不至于在小尺寸下糊成实线。
    for (double x = 0; x < width; x += 5) {
      canvas.drawLine(Offset(x, mid), Offset(x + 2, mid), paint);
    }
  }

  @override
  bool shouldRepaint(_DashMarkPainter oldDelegate) =>
      oldDelegate.dashed != dashed || oldDelegate.color != color;
}

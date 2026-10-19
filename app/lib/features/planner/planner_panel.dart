/// Planner 面板骨架（`SPEC-PLAN-014`）：左栏四段竖排 + 右栏实时预览。
///
/// ## 顺序是规格定的，不是排版偏好
///
/// 源 → 体系 → 方法 → 确认。**理由不是「源决定体系」**（那条在 `P-2` 被实证
/// 推翻，两段是双向收窄），而是「改任一段都会重算另一段的候选」：三栏并列会让
/// 人同时改两端、而不知道哪一次生效。
///
/// ## 「需重选」是态，不是错
///
/// 用户改了源之后，原先选的体系可能一条都覆盖不到。此时**不静默保留、也不悄悄
/// 换个默认值** —— 该段回到未选并显式标出来。静默保留会造出一个「界面上选着、
/// 实际不存在」的组合，那是规划里最贵的一类错。
///
/// ## 为什么三段共用一套卡片代码
///
/// `SPEC-PLAN-008`：三段候选卡元素相同（名字 · 出处 · 读数 · 尾部「+ 自建」），
/// 用户在第三段看到的东西与第一段长得一样，不用重新学。差异化只放在「读数」那
/// 一行 —— 源看等级、体系看逆序、方法看类型覆盖（`SPEC-PLAN-020`）。
library;

import 'package:flutter/material.dart';

import '../../core/pack/pack_parse.dart';
import '../../core/plan/candidates.dart';
import '../../core/plan/method_bundle.dart';
import '../../core/plan/preview.dart';
import '../../core/enums.dart';

/// 四段的分节标题。**顺序即 `PlanSegment.values` + 末段「确认」。**
const Map<PlanSegment, String> segmentTitles = <PlanSegment, String>{
  PlanSegment.source: '① 源 · 知识从哪来',
  PlanSegment.scheme: '② 体系 · 先学哪个',
  PlanSegment.method: '③ 方法 · 每项怎么学',
};

const String confirmTitle = '④ 确认';

/// 出处标签的显示名（`SPEC-PLAN-006` 三处出处）。三段共用一份，避免各写各的。
const Map<CandidateOrigin, String> originLabels = <CandidateOrigin, String>{
  CandidateOrigin.platform: '平台内置',
  CandidateOrigin.pack: '空间包',
  CandidateOrigin.user: '自建',
};

String originLabel(CandidateOrigin origin) => originLabels[origin]!;

class PlannerPanel extends StatefulWidget {
  const PlannerPanel({
    required this.pack,
    this.initialSourceId,
    this.initialSchemeId,
    this.initialMethodId,
    super.key,
  });

  final LoadedPack pack;

  /// 重入时预填（`SPEC-PLAN-019`）。预填值若不在候选里，按「需重选」处理。
  final String? initialSourceId;
  final String? initialSchemeId;
  final String? initialMethodId;

  @override
  State<PlannerPanel> createState() => PlannerPanelState();
}

class PlannerPanelState extends State<PlannerPanel> {
  String? _sourceId;
  String? _schemeId;
  String? _methodId;

  /// 上一次选过、这次不在候选里的段。只在用户改动之后出现。
  final Set<PlanSegment> _needsReselect = <PlanSegment>{};

  /// 被清掉的旧值，用于「需重选」那句说明（`已选的 X 在…下覆盖 0`）。
  final Map<PlanSegment, String> _droppedNames = <PlanSegment, String>{};

  late CandidateSet _candidates;

  String? get selectedSourceId => _sourceId;
  String? get selectedSchemeId => _schemeId;
  String? get selectedMethodId => _methodId;

  bool get needsReselect => _needsReselect.isNotEmpty;

  MethodBundle? get _selectedBundle {
    for (final MethodCandidate c in _candidates.methods) {
      if (c.id == _methodId) {
        return c.bundle;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _sourceId = widget.initialSourceId;
    _schemeId = widget.initialSchemeId;
    _methodId = widget.initialMethodId;
    _reload();
    // 预填值可能已经过时（`SPEC-PLAN-019` 的重入）：两端一起给时，若它们在
    // 当下覆盖矩阵里互不相容，先给的那一端会被筛掉。**不能静默留着**。
    _dropChecks();
  }

  void _reload() {
    _candidates = loadCandidates(
      widget.pack,
      schemeId: _schemeId,
      sourceId: _sourceId,
    );
  }

  /// 选中某段的一项（`id == null` 表示清空）。
  void _select(PlanSegment segment, String? id) {
    setState(() {
      if (segment == PlanSegment.source) {
        _sourceId = id;
      } else if (segment == PlanSegment.scheme) {
        _schemeId = id;
      } else {
        _methodId = id;
      }
      _needsReselect.clear();
      _droppedNames.clear();
      _reload();
      _dropChecks();
    });
  }

  /// 两段都查一遍：被筛掉的那一段清空并登记「需重选」。
  ///
  /// 顺序是源 → 体系：先清掉失效的源，再用放宽后的候选重算体系。反过来会让
  /// 「源被清空后体系本该恢复」这一步留在错误的收窄状态里。
  void _dropChecks() {
    _dropIfGone(PlanSegment.source, _sourceId, (String v) {
      _sourceId = null;
    }, _candidates.sources.map((SourceCandidate c) => c.id));
    _dropIfGone(PlanSegment.scheme, _schemeId, (String v) {
      _schemeId = null;
    }, _candidates.schemes.map((SchemeCandidate c) => c.id));
  }

  /// 另一端如果被筛掉了，清空它并登记「需重选」。
  void _dropIfGone(
    PlanSegment segment,
    String? current,
    void Function(String) clear,
    Iterable<String> remaining,
  ) {
    if (current == null) {
      return;
    }
    if (remaining.contains(current)) {
      return;
    }
    _droppedNames[segment] = _nameOf(segment, current);
    clear(current);
    _needsReselect.add(segment);
    // 清掉之后候选会再宽一档，重算一次，否则列表仍是收窄后的旧结果。
    _reload();
  }

  String _nameOf(PlanSegment segment, String id) {
    for (final PlanCandidate c in _candidates.of(segment)) {
      if (c.id == id) {
        return c.name;
      }
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final PlannerPreview preview = computePlannerPreview(
      pack: widget.pack,
      schemeId: _schemeId,
      bundle: _selectedBundle,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: ListView(
            key: const Key('planner-left'),
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              for (final PlanSegment segment in PlanSegment.values)
                _segment(segment),
              _confirm(preview),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(flex: 2, child: _preview(preview)),
      ],
    );
  }

  // ─────────────────────────── 左栏 ───────────────────────────

  Widget _segment(PlanSegment segment) {
    final List<PlanCandidate> list = _candidates.of(segment);
    final String? selected = switch (segment) {
      PlanSegment.source => _sourceId,
      PlanSegment.scheme => _schemeId,
      PlanSegment.method => _methodId,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            segmentTitles[segment]!,
            key: Key('planner-title-${segment.name}'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (_needsReselect.contains(segment))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '需重选：已选的「${_droppedNames[segment]}」在当前另一端下覆盖 0',
                key: Key('planner-reselect-${segment.name}'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 6),
          if (list.isEmpty)
            Text(
              '无可用候选',
              key: Key('planner-empty-${segment.name}'),
              style: const TextStyle(fontSize: 12),
            ),
          for (final PlanCandidate c in list)
            _card(segment, c, selected == c.id),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '+ 自建（P-8 开放）',
              key: Key('planner-create-${segment.name}'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).disabledColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(PlanSegment segment, PlanCandidate candidate, bool selected) {
    return InkWell(
      key: Key('planner-${segment.name}-${candidate.id}'),
      onTap: () => _select(segment, selected ? null : candidate.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    candidate.name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '· ${originLabel(candidate.origin)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${_readout(segment, candidate)} · ${_version(segment, candidate)}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  /// 卡片的读数行 —— 三段各看各的键（`SPEC-PLAN-020`），也是「为何推荐」。
  String _readout(PlanSegment segment, PlanCandidate candidate) {
    switch (segment) {
      case PlanSegment.source:
        final SourceCandidate c = candidate as SourceCandidate;
        return '${c.authorityLevel} · 覆盖 ${c.coverage.covered}/${c.coverage.total}';
      case PlanSegment.scheme:
        final SchemeCandidate c = candidate as SchemeCandidate;
        final String cover = c.coverage == null
            ? ''
            : ' · 覆盖 ${c.coverage!.covered}/${c.coverage!.total}';
        return '${c.orderCost.display}$cover';
      case PlanSegment.method:
        return (candidate as MethodCandidate).typeCoverage.display;
    }
  }

  String _version(PlanSegment segment, PlanCandidate candidate) {
    switch (segment) {
      case PlanSegment.source:
        return 'v${(candidate as SourceCandidate).version}';
      case PlanSegment.scheme:
        return '包 v${(candidate as SchemeCandidate).packVersion}';
      case PlanSegment.method:
        return '内置';
    }
  }

  // ─────────────────────────── 确认段 ───────────────────────────

  Widget _confirm(PlannerPreview preview) {
    final bool ready =
        _sourceId != null && _schemeId != null && _methodId != null;
    final String? blocked = _blockedReason(preview, ready);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          confirmTitle,
          key: const Key('planner-title-confirm'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        for (final PlanSegment segment in PlanSegment.values)
          Text(
            '${segmentTitles[segment]!.substring(0, 1)} '
            '${_chosenName(segment) ?? '未选'}',
            key: Key('planner-confirm-${segment.name}'),
            style: const TextStyle(fontSize: 12),
          ),
        const SizedBox(height: 6),
        FilledButton(
          key: const Key('planner-confirm-button'),
          onPressed: blocked == null ? () {} : null,
          child: const Text('建计划'),
        ),
        if (blocked != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              blocked,
              key: const Key('planner-blocked'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }

  String? _chosenName(PlanSegment segment) {
    final String? id = switch (segment) {
      PlanSegment.source => _sourceId,
      PlanSegment.scheme => _schemeId,
      PlanSegment.method => _methodId,
    };
    if (segment == PlanSegment.method) {
      return _selectedBundle?.name;
    }
    for (final PlanCandidate c in _candidates.of(segment)) {
      if (c.id == id) {
        return c.name;
      }
    }
    return null;
  }

  String? _blockedReason(PlannerPreview preview, bool ready) {
    if (_needsReselect.isNotEmpty) {
      return '有 ${_needsReselect.length} 段需重选';
    }
    if (!ready) {
      return '三段选齐才能建计划';
    }
    if (preview.uncoveredItems > 0) {
      return '这套方法未覆盖 ${preview.uncoveredItems} 项，换一套或先自建';
    }
    return null;
  }

  // ─────────────────────────── 右栏 ───────────────────────────

  Widget _preview(PlannerPreview preview) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        key: const Key('planner-preview'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('实时预览', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text('项数 ${preview.itemCount}', key: const Key('preview-items')),
          Text('分母 ${preview.denominator}', key: const Key('preview-denominator')),
          Text(
            '预计 ${preview.minutes} 分钟',
            key: const Key('preview-minutes'),
          ),
          if (preview.usingDefaultMethod)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '按默认方法估算（尚未选 ③）',
                key: Key('preview-default'),
                style: TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

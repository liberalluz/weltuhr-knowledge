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
/// `SPEC-PLAN-008`：三段候选卡元素相同（名字 · 出处 · **适用范围** · 读数 · 尾部
/// 「+ 自建」），用户在第三段看到的东西与第一段长得一样，不用重新学。差异化只
/// 放在「读数」那一行 —— 源看等级、体系看逆序、方法看类型覆盖（`SPEC-PLAN-020`）。
///
/// ## 自建的内容住在这里，不落盘
///
/// `SPEC-PLAN-007` 的链路是「草稿（本机）→ 立刻可选 → 提审 → 合并进 overlay」。
/// 本笔只做前两段：自建的三份留在 [PlannerPanelState] 的字段里，`origin = user`，
/// 关掉面板即丢。**跨会话持久化要等本地 overlay 存储**（`SPEC-GOV-008` /
/// `PACK-011`，均未开工）—— 写一个临时 JSON 文件会与将来的 overlay 变成两份
/// 判据，比重建更贵。
library;

// `Axis` 与 `core/enums.dart` 的 `Axis`（三条容器轴）撞名。本文件用到的是
// 后者，而 flutter 那一份（水平/垂直）在这里一次都用不到。
import 'package:flutter/material.dart' hide Axis;

import '../../core/constants.dart';
import '../../core/entities/method.dart';
import '../../core/entities/plan.dart';
import '../../core/entities/scheme.dart';
import '../../core/entities/source.dart';
import '../../core/enums.dart';
import '../../core/json.dart';
import '../../core/pack/pack_reader.dart';
import '../../core/plan/candidates.dart';
import '../../core/plan/plan_draft.dart';
import '../../core/plan/plan_events.dart';
import '../../core/plan/platform_candidates.dart';
import '../../core/plan/preview.dart';
import '../../core/plan/user_content.dart';
import 'user_draft_dialogs.dart';

/// 四段的分节标题。**顺序即 `PlanSegment.values` + 末段「确认」。**
const Map<PlanSegment, String> segmentTitles = <PlanSegment, String>{
  PlanSegment.source: '① 源 · 知识从哪来',
  PlanSegment.scheme: '② 体系 · 先学哪个',
  PlanSegment.method: '③ 方法 · 每项怎么学',
};

const String confirmTitle = '④ 确认';

/// 横排 / 堆叠的断点（`B4-R`）。
///
/// 低于它就改上下堆叠：原先 `Row(Expanded(3), Divider, Expanded(2))` 没有下限，
/// 窗口一窄两栏各分到几十像素，文字**逐字竖排**且卡片挂 `RIGHT OVERFLOWED BY
/// 52 PIXELS`（走查实拍）。堆叠后每栏都是全宽，不需要再给两栏各设最小宽度 ——
/// 那只是把溢出换成裁切。
const double _stackBreakpoint = 720;

/// 出处标签的显示名（`SPEC-PLAN-006` 三处出处）。三段共用一份，避免各写各的。
const Map<CandidateOrigin, String> originLabels = <CandidateOrigin, String>{
  CandidateOrigin.platform: '平台内置',
  CandidateOrigin.pack: '空间包',
  CandidateOrigin.user: '自建',
};

String originLabel(CandidateOrigin origin) => originLabels[origin]!;

/// 「适用范围」那一行的人话（`SPEC-PLAN-008` 五元素之一）。
///
/// **不显示 `appliesTo` 的 JSON 键值**：那一段是给作者看的机器口径（`type` /
/// `axes` / `layer`），用户要看的是「这套东西管哪些项」。空 `appliesTo` 读作
/// 「不限」—— 不是「没填」，是**声明过的不限**（`appliesToNode` 对空 map 恒真）。
///
/// 笔 5c-1：`sixAxis` 与 `spaceId` 两个渲染分支删掉了。前者随 `ADR-0005`
/// 失效、后者随「一空间一包已废」失效，而 `appliesToNode` 已把它们判成
/// **未认的键直接抛错** —— 渲染层还认它们，等于界面承认一对匹配器不承认的键。
/// 命中的轴改由 `axes` 分支渲染。
String appliesToText(JsonMap appliesTo) {
  if (appliesTo.isEmpty) {
    return '不限';
  }
  final List<String> parts = <String>[];
  final Object? type = appliesTo['type'];
  if (type != null) {
    parts.add(_namesOf(type, _typeNameLabels));
  }
  final Object? layer = appliesTo['layer'];
  if (layer != null) {
    parts.add(_namesOf(layer, _layerNameLabels));
  }
  final Object? axes = appliesTo['axes'];
  if (axes != null) {
    parts.add(_namesOf(axes, _axisNameLabels));
  }
  return parts.isEmpty ? '不限' : parts.join(' · ');
}

/// 源侧「适用范围」的人话（`entity-fields` §11 的 `{axes[], node_scope[]}`）。
///
/// ⚠️ **不能与方法侧 [appliesToText] 共用**（`entity-fields` §12 那条注记）：
/// 源那侧两键**必填**、过滤依据是「`node_scope` ∩ 子树」；方法那侧三键可省、
/// 按节点自身取值过滤。同一个函数渲染两处，会得到一份"看着都对、实际永远为真"
/// 的说明。
///
/// `axes` 是 `node_scope` 的简写（「学科轴下全部节点」），所以有轴就报轴；
/// 两者都空读作**不限** —— 与自建源的默认值一致（自建源没有绑定，见
/// `buildUserSource`）。
String sourceAppliesToText(SourceAppliesTo appliesTo) {
  final List<String> parts = <String>[
    for (final Axis axis in appliesTo.axes) axisLabels[axis]!,
  ];
  if (appliesTo.nodeScope.isNotEmpty) {
    parts.add('点名 ${appliesTo.nodeScope.length} 个节点');
  }
  return parts.isEmpty ? '不限' : parts.join(' · ');
}

/// 枚举名 → 中文名。`appliesTo` 里存的是**名字**（JSON 口径），标签表却是按
/// 枚举建的，这里翻一次。
final Map<String, String> _typeNameLabels = <String, String>{
  for (final MapEntry<LearnableType, String> entry in learnableTypeLabels.entries)
    entry.key.name: entry.value,
};

final Map<String, String> _layerNameLabels = <String, String>{
  for (final MapEntry<Layer, String> entry in layerLabels.entries)
    entry.key.name: entry.value,
};

// ⚠️ 不写 `MapEntry<Axis, String>`：`Axis` 与 `flutter/material.dart` 导出的
// `Axis`（布局方向）同名，在视图层逐个点名会撞成 `ambiguous_import`。
// 走 `.map()` 让键类型由 `axisLabels` 推出来 —— 这里只需要键的**名字**。
final Map<String, String> _axisNameLabels = axisLabels.map(
  (k, String label) => MapEntry<String, String>(k.name, label),
);

String _namesOf(Object raw, Map<String, String> labels) {
  if (raw is List) {
    return raw.map((Object? v) => labels['$v'] ?? '$v').join(' / ');
  }
  return labels['$raw'] ?? '$raw';
}

/// 类型集合 → 「陈述 / 流程」这样的一句。**按枚举声明序**输出，不按集合的
/// 迭代序 —— 同一套内容每次渲染都该是同一句话。
String typesText(Iterable<LearnableType> types) {
  final Set<LearnableType> set = types.toSet();
  final List<String> parts = <String>[
    for (final LearnableType type in LearnableType.values)
      if (set.contains(type)) learnableTypeLabels[type]!,
  ];
  return parts.isEmpty ? '不限' : parts.join(' / ');
}

class PlannerPanel extends StatefulWidget {
  const PlannerPanel({
    required this.pack,
    required this.spaceId,
    required this.subtreeRoot,
    required this.primaryAxis,
    required this.packVersions,
    this.initialSourceId,
    this.initialSchemeId,
    this.initialMethodId,
    this.onCreate,
    super.key,
  });

  final PackContent pack;

  /// 事件信封上的空间 id。**不进 payload**（`event-types.md` §二 B），
  /// 但 `PlanDraft` 要拿它填信封，所以面板得知道。
  final String spaceId;

  /// 这份计划的范围根（节点 id）。取代旧的 `PlanTarget.selector`。
  ///
  /// **必填**：`inScope` 是派生的（`entity-fields` §2），没有根就无从算圈内，
  /// 而「缺省 = 圈内全量」在新本体里不存在 —— 全量也得有个根（轴根）。
  final String subtreeRoot;

  /// 主序轴的默认值（由模式给出，可被体系显式覆盖）。
  final Axis primaryAxis;

  /// 建计划那一刻的包版本组合。
  final PackVersions packVersions;

  /// 点「建计划」时交出草稿。**事件由上层写** —— 面板不该知道 `EventStore`、
  /// `HlcClock`、`userId` 这些东西，它只回答「用户选了什么」。
  ///
  /// 为 `null` 时按钮仍可点，但什么也不发生 —— 用于纯展示与骨架测试。
  final void Function(PlanDraft draft)? onCreate;

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

  /// 被清掉的旧值，用于「需重选」那句说明（`X 在…下覆盖 0，已取消选择`）。
  final Map<PlanSegment, String> _droppedNames = <PlanSegment, String>{};

  /// 刚加入的自建内容的一条说明（`B4-R`）。`null` = 不显示。
  ///
  /// 自建源在已选体系下覆盖恒 0（客户端写不了 `NodeEntry.sourceRefs`）。原先建完
  /// **立刻选中**，随即被筛掉再清空 —— 用户看到的是「对话框关了、列表里什么
  /// 都没多出来、顶上多一句提到没见过的名字」。现在它留在列表里标「覆盖 0」，
  /// 用这句话说清「已加入，但当前用不上」。
  String? _userNotice;

  /// 用户自建的三段内容（`SPEC-PLAN-007`）。**只活在这个 `State` 里**，见文件头。
  final List<SourceRef> _userSources = <SourceRef>[];
  final List<Scheme> _userSchemes = <Scheme>[];
  final List<MethodProfile> _userProfiles = <MethodProfile>[];
  final List<MethodBundle> _userBundles = <MethodBundle>[];

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
      // 自建的三份必须喂进来，否则「立刻可选」只是一句文档。**通道 `P-2` 就
      // 打通了**，这里一直没接 —— `P-8` 补的就是这一行起。
      userSources: _userSources,
      userSchemes: _userSchemes,
      userMethodBundles: _userBundles,
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
      _userNotice = null;
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
    // 自建的项一旦被筛出候选列表，就查不到名字了 —— 而「需重选」那句正是要说
    // 「哪一项掉了」。退回自建表里找，否则用户看到的是 `user:src:内规` 这种
    // 内部 id，等于让他自己去猜。
    final List<String> names = switch (segment) {
      PlanSegment.source => <String>[
        for (final SourceRef s in _userSources)
          if (s.id == id) s.name,
      ],
      PlanSegment.scheme => <String>[
        for (final Scheme s in _userSchemes)
          if (s.id == id) s.name,
      ],
      PlanSegment.method => <String>[
        for (final MethodBundle b in _userBundles)
          if (b.id == id) b.name,
      ],
    };
    return names.isEmpty ? id : names.first;
  }

  @override
  Widget build(BuildContext context) {
    final PlannerPreview preview = computePlannerPreview(
      pack: widget.pack,
      subtreeRoot: widget.subtreeRoot,
      parents: widget.pack.parents,
      schemeId: _schemeId,
      bundle: _selectedBundle,
      userProfiles: _userProfiles,
      userSchemes: _userSchemes,
    );
    final MethodBundle? bundle = _selectedBundle;
    // `entity-fields` §一.7 校验 ③：全步骤无 `hint` 时**不禁止**，但要说出代价。
    final bool noHint =
        bundle != null &&
        !bundleHasAnyHint(bundle, <MethodProfile>[
          ...platformMethodProfiles,
          ..._userProfiles,
        ]);

    // 横排只在够宽时用（`B4-R`）：窄窗口下左右两栏会各分到几十像素，文字逐字
    // 竖排并溢出。堆叠后每栏都是全宽，判据只有总宽一个。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget left = _leftColumn(preview, noHint);
        final Widget right = _preview(preview);
        if (constraints.maxWidth < _stackBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: 3, child: left),
              const Divider(height: 1),
              Expanded(flex: 2, child: right),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(flex: 3, child: left),
            const VerticalDivider(width: 1),
            Expanded(flex: 2, child: right),
          ],
        );
      },
    );
  }

  // ─────────────────────────── 左栏 ───────────────────────────

  /// 左栏：三段清单可滚，**④ 确认固定在底部**（`B4-R`）。
  ///
  /// 为什么确认段不能跟着滚：它是建计划的唯一出口。原先排在 `ListView` 末尾，
  /// 候选 4+2+3 条就要滚一屏多才看得到（走查实拍「滚到顶看不到 ④ 确认和
  /// 建计划」）。一个页面的唯一出口不该靠用户去发现 —— 候选再多它也得在。
  ///
  /// 反过来说，阻断原因（「三段选齐才能建计划」）跟着一起常驻，用户不用滚回去
  /// 找「为什么按钮是灰的」。
  Widget _leftColumn(PlannerPreview preview, bool noHint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            key: const Key('planner-left'),
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              for (final PlanSegment segment in PlanSegment.values)
                _segment(segment, noHint),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: _confirm(preview),
        ),
      ],
    );
  }

  Widget _segment(PlanSegment segment, bool noHint) {
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
                // 措辞（`B4-R`）：那一项**已经被清空了**，原文案说「已选的 X」
                // 会让人去找一张已经不在选中态的卡片。先给名字（用户要认的是
                // 它），再说原因与结果。另一端按段取名：被清的是源，另一端
                // 就是体系 —— 换成「当前另一端」等于让用户自己翻译。
                '「${_droppedNames[segment]}」在当前'
                '${segment == PlanSegment.source ? '体系' : '源'}下覆盖 0，已取消选择',
                key: Key('planner-reselect-${segment.name}'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (segment == PlanSegment.source && _userNotice != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _userNotice!,
                key: const Key('planner-user-notice'),
                style: const TextStyle(fontSize: 12),
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
          if (segment == PlanSegment.method && noHint)
            Text(
              '本方法无提示可给，熟练档不受约束',
              key: const Key('planner-no-hint'),
              style: const TextStyle(fontSize: 11),
            ),
          // `SPEC-PLAN-007`：**不是独立页面**，就是列表尾部这一个动作。
          //
          // 文字不带加号（`B4-R`）：图标已经是 `Icons.add`，两处各写一个就成了
          // 「＋ + 自建」（走查实拍）。
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              key: Key('planner-create-${segment.name}'),
              onPressed: () => _createUser(segment),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('自建'),
            ),
          ),
        ],
      ),
    );
  }

  /// 三段的自建入口（`SPEC-PLAN-007`）。建完**立刻选中** —— 建完还要回头找
  /// 一遍才叫「把建和选拆成两处」。
  Future<void> _createUser(PlanSegment segment) async {
    switch (segment) {
      case PlanSegment.source:
        final SourceRef? source = await showUserSourceDialog(
          context,
          takenIds: <String>[for (final SourceRef s in _userSources) s.id],
        );
        if (!mounted || source == null) {
          return;
        }
        _userSources.add(source);
        // 先重算一次候选，才判得出这个自建源在当前体系下覆盖几项。
        _reload();
        final bool usable = _candidates.sources.any(
          (SourceCandidate c) => c.id == source.id && c.coverage.isUsable,
        );
        // 判据是「**已选体系**且覆盖 0」，不是「覆盖 0」：没选体系时它本来
        // 就能用（不收窄就不筛），建完立刻选中是对的。
        if (_schemeId == null || usable) {
          // 建完**立刻选中**，这是 `SPEC-PLAN-007` 里「建和选不该拆成两处」。
          _select(PlanSegment.source, source.id);
        } else {
          // 已选体系下自建源覆盖恒 0（客户端写不了 `NodeEntry.sourceRefs`）。
          // **不选中**：选了立刻会被判「需重选」再清掉，用户看到的是
          // 「建了、然后消失」。留在列表里标「覆盖 0」并给一句话，
          // 比反复清空诚实（`B4-R` 走查实拍）。
          setState(() {
            _userNotice = '已加入候选；当前体系下覆盖 0，换一套体系后才能选';
          });
        }
      case PlanSegment.scheme:
        final Scheme? scheme = await showUserSchemeDialog(
          context,
          pack: widget.pack,
          subtreeRoot: widget.subtreeRoot,
          takenIds: <String>[for (final Scheme s in _userSchemes) s.id],
        );
        if (!mounted || scheme == null) {
          return;
        }
        _userSchemes.add(scheme);
        _select(PlanSegment.scheme, scheme.id);
      case PlanSegment.method:
        final UserMethodDraft? draft = await showUserMethodDialog(
          context,
          takenIds: <String>[
            for (final MethodProfile p in _userProfiles) p.id,
          ],
        );
        if (!mounted || draft == null) {
          return;
        }
        final ({MethodProfile profile, MethodBundle bundle}) built =
            buildUserMethod(draft);
        _userProfiles.add(built.profile);
        _userBundles.add(built.bundle);
        _select(PlanSegment.method, built.bundle.id);
    }
  }

  Widget _card(PlanSegment segment, PlanCandidate candidate, bool selected) {
    // 自建源可能覆盖 0 却仍留在列表里（`B4-R`）。它不该被点 —— 选了立刻会被
    // 判「需重选」再清掉，等于让用户白点一次、还多读一句红字。
    final bool blocked =
        candidate is SourceCandidate && !candidate.coverage.isUsable;
    return Opacity(
      opacity: blocked ? 0.5 : 1,
      child: InkWell(
        key: Key('planner-${segment.name}-${candidate.id}'),
        onTap: blocked
            ? null
            : () => _select(segment, selected ? null : candidate.id),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 出处用 `Flexible`：极窄时它先让位，否则这一行会溢出
                  // （走查实拍每张卡片挂 `RIGHT OVERFLOWED BY 52 PIXELS`）。
                  Flexible(
                    child: Text(
                      '· ${originLabel(candidate.origin)}',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // `SPEC-PLAN-008` 的「适用范围」—— 五元素里此前一直缺这一项。
              Text(
                '适用 ${_scope(segment, candidate)}',
                key: Key('planner-scope-${segment.name}-${candidate.id}'),
                style: const TextStyle(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${_readout(segment, candidate)} · ${_version(segment, candidate)}'
                '${blocked ? ' · 不可选' : ''}',
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 卡片的读数行 —— 三段各看各的键（`SPEC-PLAN-020`），也是「为何推荐」。
  String _readout(PlanSegment segment, PlanCandidate candidate) {
    switch (segment) {
      case PlanSegment.source:
        final SourceCandidate c = candidate as SourceCandidate;
        final AuthorityLevel? level = c.authorityLevel;
        // `catalog` 源不标等级（`entity-fields` §11），所以这一格可能为空。
        final String label = level == null ? '目录' : authorityLabels[level]!;
        return '$label · 覆盖 ${c.coverage.covered}/${c.coverage.total}';
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

  /// 卡片的「适用范围」—— 三段各由**自己的字段**派生，没有一个是编的：
  ///
  /// - 源：`SourceRef.appliesTo`（`entity-fields` §11 的 `{axes[], node_scope[]}`）
  /// - 体系：`Scheme` 没有 `appliesTo`，改由 `nodes` 里实际出现的
  ///   `LearnableNode.type` 说
  /// - 方法：`MethodBundle.byType` 覆盖到的类型
  String _scope(PlanSegment segment, PlanCandidate candidate) {
    switch (segment) {
      case PlanSegment.source:
        return sourceAppliesToText(
          (candidate as SourceCandidate).source.appliesTo,
        );
      case PlanSegment.scheme:
        final SchemeCandidate c = candidate as SchemeCandidate;
        return typesText(<LearnableType>{
          for (final String nodeId in c.scheme.nodes)
            if (widget.pack.learnableOf(nodeId) != null)
              widget.pack.learnableOf(nodeId)!.type,
        });
      case PlanSegment.method:
        return typesText((candidate as MethodCandidate).bundle.byType.keys);
    }
  }

  String _version(PlanSegment segment, PlanCandidate candidate) {
    switch (segment) {
      case PlanSegment.source:
        return 'v${(candidate as SourceCandidate).version}';
      case PlanSegment.scheme:
        return '包 v${(candidate as SchemeCandidate).packVersion}';
      case PlanSegment.method:
        // 平台档是内置的，自建档没有包版本可读 —— 写「内置」会让两处混成一句。
        return candidate.origin == CandidateOrigin.user ? '自建' : '内置';
    }
  }

  // ─────────────────────────── 确认段 ───────────────────────────

  /// 把三段选择交出去。范围与包版本原样透传 —— 面板不解算范围，
  /// `composePlanDraft` 与预览走的是同一个模型（子树根 + 派生 `inScope`）。
  void _create() {
    final MethodBundle? bundle = _selectedBundle;
    final String? sourceId = _sourceId;
    final String? schemeId = _schemeId;
    // 按钮在「未选齐」时本就是 disabled，这里再判一次是因为 `onCreate` 为 null
    // 与选择不全走了两条不同的路径，不能让 null 断言混进来。
    if (bundle == null || sourceId == null || schemeId == null) {
      return;
    }
    widget.onCreate?.call(
      composePlanDraft(
        pack: widget.pack,
        spaceId: widget.spaceId,
        subtreeRoot: widget.subtreeRoot,
        primaryAxis: widget.primaryAxis,
        packVersions: widget.packVersions,
        sourceId: sourceId,
        schemeId: schemeId,
        bundle: bundle,
        // 与预览那次必须是同一份自建体系，否则「预览 12 项、事件存 4 项」。
        userSchemes: _userSchemes,
      ),
    );
  }

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
          onPressed: blocked == null ? _create : null,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

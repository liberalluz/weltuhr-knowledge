/// 快速定位浮层（`SPEC-VIEW-024`–`033`）。
///
/// ## 为什么是浮层而不是常驻输入框
///
/// `VIEW-026`：搜索是「用完即走」的动作。常驻输入框会长期占住中央内容区，
/// 而这块画布的全部意义是「位置即语义」—— 让一个文本框抢走它，等于把
/// 语义区降级成工具栏。
///
/// ## 浮层只做「输入 → 命中集 / 分诊 → 选择」的呈现
///
/// 跳不跳、跳到哪一档、写不写 `axisFilter`，全在 `universe_screen` 的
/// `_applyHit` 里 —— 那是**行为**，而这层是**显示**。分开的好处是浮层可以
/// 脱离整个屏幕单独测：给一句输入，看它列了什么。
///
/// ## 唯一命中为什么要回车而不是自动跳
///
/// `VIEW-027` 说「唯一命中 → 直接跳转」，说的是**不必先选列表再点一次**。
/// 但它不等于「边打字边跳」：打到「装饰器」时命中集只有一条，再打一个字变成
/// 两条，中间每一次按键都跳一次的话，用户会被界面拽着跑。所以 `located`
/// 的呈现是「一行直达 + 回车」，回车是一次显式动作。
///
/// ## 无命中为什么不是一句话，而是四个分支
///
/// `VIEW-030`：「搜不到」有四种事实，其中三种的正确出口都不是新增。一句话
/// 「没有命中」把四种压成一种，用户唯一能做的动作就是离开 —— 而他要的东西
/// 可能就在圈外、可能叫别的名字。分诊的判据在 `core/locate/diagnose.dart`，
/// 这里只负责把结论说出来，并守住那条闸门：
///
/// > **新增入口不能挂在「搜不到」上**，只能挂在「已给过邻近候选且用户说都不对」
/// > 之后。
///
/// 落到代码上就是：类 ③ 的新增按钮在候选为空时直接出现（本来就没有候选可给），
/// 类 ② 必须先经过一次「都不对」；而任何表单都在第二个动作之后才展开。
///
/// ## 表单为什么填完也不落库
///
/// `VIEW-032` 要求表单**不写 `axisFilter`**（一次性查询）—— 这一条本笔守住了：
/// 表单从头到尾不碰筛选。但「提交审核」要写进审核队列，而队列要 `entries` 表与
/// 事件流（`B4` 的数据层）。所以按钮照出，按下去如实说「没有写入任何数据」——
/// 比藏起来强（藏起来会被读成「这个功能不存在」），比假装成功更必需。
///
/// ## 跨包：命中集可跨，落点归调用方
///
/// `VIEW-031` 要求作用域跟随视图，`VIEW-033` 要求同名项带空间前缀。两条都只
/// 关乎命中集与展示 —— **换不换根是行为，在 `universe_screen` 的 `_applyHit`
/// 里**，浮层不拦。此前这里会拦下跨空间命中并说明「本笔只有一个根」，那是
/// 单根时代的过渡态；多根之后拦下来反而成了 bug（搜得到却点不动）。
///
/// ⚠️ **「空间」这个词在这里已经是 `Pack`**（`ADR-0005` §影响一：`KnowledgeSpace`
/// → `Pack`）。标识符已换成 `otherPacks` / `scopePluginId`，但
/// [locateSpaceSeparator] 与界面文案「在全部空间中搜索」**保持原文** —— 它们
/// 逐字对应 `VIEW-031` / `VIEW-033`，`SPEC-VIEW-*` 整片待重写（`ADR-0005`
/// §影响二），词要跟着 spec 一起改，不在这里先改一半。
///
/// 前缀同理**不做成入参**：要不要写是命中集自身的事实（同一名字出现在两个
/// 以上包里），由 [_LocateOverlayState._ambiguousLabels] 从 `hits` 里算出来。
/// 交给调用方注入的话，调用方得先知道「会不会撞名」才能传对 —— 而它手里的信息
/// 并不比这里多。
library;

// `Axis` 两边都有（Flutter 的绘制轴 / `core/enums.dart` 的知识轴），这里要后者。
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter/services.dart';

import '../../core/enums.dart';
import '../../core/locate/diagnose.dart';
import '../../core/locate/locator.dart';
import '../../core/pack/pack_reader.dart';
import '../palette.dart';

/// 浮层根节点。
const Key locateOverlayKey = Key('locate-overlay');

/// 输入框。
const Key locateFieldKey = Key('locate-field');

/// 结果列表。
const Key locateResultsKey = Key('locate-results');

/// 提示行（空输入 / 包缺失）。
const Key locateHintKey = Key('locate-hint');

/// 分诊面板（无命中时取代结果列表）。
const Key locateTriageKey = Key('locate-triage');

/// 分诊面板底部的那个动作按钮（申请纳入 / 都不对 / 新增这一项 / 记下需求）。
const Key locateTriageActionKey = Key('locate-triage-action');

/// 新增表单（`VIEW-032` 的一次性查询）。
const Key locateFormKey = Key('locate-form');

/// 表单里的标题输入框。
const Key locateFormTitleKey = Key('locate-form-title');

/// 表单的「提交审核」。
const Key locateFormSubmitKey = Key('locate-form-submit');

/// 「没有写入任何数据」的如实说明。
const Key locateNoticeKey = Key('locate-notice');

/// 结果区顶部那一行「在全部空间中搜索」（`SPEC-VIEW-031`）。
const Key locateSearchAllKey = Key('locate-search-all');

/// 定位结果底部的「按此范围建计划」（`SPEC-PLAN-016` 第三入口，`B4` `P-7`）。
const Key locatePlanHereKey = Key('locate-plan-here');

/// 轴命中行上的「按此轴看」（`SPEC-TREE-010` 轴落点的界面入口）。
///
/// 按轴名定 key：一个包内每条轴至多贡献一条轴命中，不会撞。
Key locateAxisHereKey(String axisKey) => Key('locate-axis-here-$axisKey');

/// 空间前缀与标题之间的分隔符。抽出来是因为测试要断言「没有它」。
///
/// 名字里的「空间」保持原样：它对应 `VIEW-033` 的原文措辞（`SPEC-VIEW-*` 待
/// 重写，见文件头），不是「忘了改成 pack」。
const String locateSpaceSeparator = ' › ';

/// 邻近候选最多列几条。
///
/// 候选是给人**换词**用的，超过一掌之数就变回「自己再翻一遍」；而排序已经把
/// 共享片段最多的放前面，截断丢掉的正是最不像的那几条。
const int _nearLimit = 5;

/// 某一命中行的 `Key`。
///
/// 带 `kind` 而不只带 `target`：同一个词可能同时命中域与项（域 id 末段 =
/// 项名），两条都出现在列表里时 `Key` 撞车会让 widget test 里
/// `findsOneWidget` 假红。**带 `packId`** 同理 —— 跨包命中集里两个包
/// 可以有同一个 `target`。
Key locateRowKey(LocateHit hit) => Key(
  'locate-row-${hit.packId}-${hit.kind.name}-${hit.axisKey ?? ''}-${hit.target}',
);

/// 某条邻近候选行的 `Key`。
Key locateNearRowKey(String nodeId) => Key('locate-near-$nodeId');

class LocateOverlay extends StatefulWidget {
  const LocateOverlay({
    required this.pack,
    required this.subtreeRoot,
    required this.onPick,
    required this.onPickNear,
    required this.onDismiss,
    this.onPlanHere,
    this.canPlanHere,
    this.onPickAxis,
    this.otherPacks = const <PackContent>[],
    this.scopePacks = const <PackContent>[],
    this.scopePluginId,
    this.domainId,
    this.initialQuery = '',
    super.key,
  });

  /// 本包的包内容 —— 也就是宇宙与树此刻的根。`null` = 合成回落，没有可搜的东西。
  /// 浮层仍然打开并说明原因 —— 不给入口比给了不响应好，但两者都比「静默无反应」好。
  final PackContent? pack;

  /// 除本包外、也能被搜到的其它包（`SPEC-VIEW-031`）。
  ///
  /// 多出来的包参与命中集与展示，**落点也照常交给调用方** —— 换根是屏幕层的
  /// 事，浮层只管「用户选了哪条」。给不出来时留空：空列表等于「只有一个包」，
  /// 那一行「在全部空间中搜索」也就不会出现。
  final List<PackContent> otherPacks;

  /// 窄态要搜的那一组包 —— 作用域 = 当前地址子树覆盖到的包（`SPEC-VIEW-031`）。
  ///
  /// 与 [otherPacks] 的区别是**谁算在里面**：这里放的是「圈内」的包，可以是
  /// 两个以上（选中骨架星时，骨架与挂在它下面的载荷都在圈内）；[otherPacks]
  /// 放的是「圈外、点了那一行才搜」的。空表退回「只搜 [pack]」，与单包时代一致。
  final List<PackContent> scopePacks;

  /// 当前视图的作用域（`SPEC-VIEW-031`）：`null` = 全部（`Z0` 本就是跨包
  /// 视角）；非 `null` = 默认只搜本包，结果区顶部给一行「在全部空间中搜索」。
  final String? scopePluginId;

  /// 当前视图圈定范围的根（`Plan.subtree_root`）。
  ///
  /// 必填：判「圈外」的唯一依据就是它（`inScopeOf`），不给的话类 ① 永远不会
  /// 出现 —— 那会让「库里有、只是不在圈内」和「库里根本没有」在界面上长得
  /// 一模一样，而它们的正确出口是两件事（申请纳入 vs 记个需求）。
  ///
  /// 只对**本包**生效：宽到全部包时由 [_LocateOverlayState._scopeRoot] 置空，
  /// 否则别的包的命中会被一律判成圈外。
  final String subtreeRoot;

  /// 选中一条命中。第二个参数是**这次定位的完整结果** —— 路由要它来判断
  /// 是不是「唯一命中」。
  final void Function(LocateResult result, LocateHit hit) onPick;

  /// 选中一条**邻近候选**（类 ② 的「换词」出口）。
  ///
  /// 单独一个回调而不是包进 [LocateHit]：邻近候选没有「强度」，而跳转又是
  /// 真跳转 —— 两条语义拼在一条类型里，下次读代码的人会以为它也是命中。
  final void Function(String nodeId) onPickNear;

  final VoidCallback onDismiss;

  /// 底部「按此范围建计划」（`SPEC-PLAN-016` 第三入口）。
  ///
  /// 交出的是**整次定位结果**，不是某一行的命中：这条入口的语义是「为这一轮
  /// 搜索圈出的范围建一份计划」，范围由 `query` 唯一确定（`PlanSelector.query`），
  /// 与用户点了哪一行无关。行内跳转仍走 [onPick]。
  ///
  /// `null` = 没有上层接收，按钮不渲染 —— 与 `PlannerPanel.onCreate` 同口径：
  /// 一个按下没反应的按钮比没有按钮更糟。
  final void Function(LocateResult result)? onPlanHere;

  /// 这一轮命中**圈不圈得出单一子树**。`null` = 只看 [onPlanHere] 在不在。
  ///
  /// 为什么不在浮层里自己判：判据是「命中集的公共根 + 同轴」，它要一棵跨包合并
  /// 的父链树，而浮层手里只有 `pack` 与 `otherPacks` 两份内容 —— 在界面层再算
  /// 一遍等于把 `core/plan/plan_entry.dart` 的判据抄第二份，两份迟早分叉。
  ///
  /// 交给上层判的后果是：跨子树时按钮**不出现**，而不是「出现但点了没反应」
  /// （`SPEC-PLAN-016` 第三入口的验收口径）。
  final bool Function(LocateResult result)? canPlanHere;

  /// 轴命中行上的「按此轴看」：换根到该轴根、退回单轴态（`SPEC-TREE-010`）。
  ///
  /// 为什么挂在**行**上而不是底部 CTA：一条轴命中说的是「这一条轴」，而底部那条
  /// CTA 说的是「这一轮搜索圈出的范围」—— 两件事的范围不同，混到一处就只能取并，
  /// 取并之后「按此轴看」就成了「按三轴看」。
  ///
  /// `null` = 没有上层接收，按钮不渲染（与 [onPlanHere] 同口径）。
  final ValueChanged<Axis>? onPickAxis;

  /// 当前视图的域上下文（选中项所在的域）。只影响分诊的 ③ / ④ 分野
  /// （`VIEW-030`）：知道往哪放才谈得上新增。
  final String? domainId;

  /// 打开时预填的词（`VIEW-015` 的 `selector`）。
  ///
  /// 只由「从搜索进详情、再返回」这一条路径给：快照存的是**当时搜了什么**，
  /// 返回时把词填回去、结果按当下重算 —— 存结果列表会还给用户一份已经过时的
  /// 命中集（见 `core/view/navigation.dart` 文件头）。
  ///
  /// 只在 `initState` 读一次。调用方换了词要换 `key`，否则 `State` 复用、新词
  /// 不生效。
  final String initialQuery;

  @override
  State<LocateOverlay> createState() => _LocateOverlayState();
}

class _LocateOverlayState extends State<LocateOverlay> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _formTitle = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();

  LocateResult? _result;
  LocateDiagnosis? _diagnosis;

  /// 是否已经被那一行「在全部空间中搜索」放宽到全部空间（`SPEC-VIEW-031`）。
  ///
  /// 是**一次查询内**的状态：关掉浮层就没了。搜索是「用完即走」的动作
  /// （`VIEW-026`），把「我上次选了全部空间」跨次记住，会让下一次在 `Z1` 里
  /// 搜索的用户莫名收到别的空间的结果 —— 而那一行正是用来当场表达的。
  bool _searchAll = false;

  /// 表单是否展开。**只在第二个动作之后**为真（见文件头闸门）。
  bool _formOpen = false;

  /// 按下写操作后留下的如实说明（没有落库）。
  String? _notice;

  @override
  void initState() {
    super.initState();
    // 打开即能打字：进浮层还要先点一下输入框，是把两步并成一步的机会丢了。
    _fieldFocus.requestFocus();
    final String preset = widget.initialQuery;
    if (preset.isNotEmpty) {
      // `VIEW-015`：返回时把当时搜的词填回来。**重算而不是还原结果** ——
      // 命中集会随内容包变，还给用户一份旧列表比没有列表更糟。
      _controller.text = preset;
      // `initState` 里不调 `setState`：首帧还没 build，直接给字段赋值就是结果。
      _compute(preset);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _formTitle.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  /// 这一轮查哪些包（`SPEC-VIEW-031`）。
  ///
  /// 作用域宽 = `Z0`（`scopePluginId == null`）**或**用户点了那一行。两者都宽时
  /// 不必再分，因为「全部」只有一种含义。
  ///
  /// 窄态给的是 [LocateOverlay.scopePacks]（地址子树覆盖的一组包），**不是**
  /// 「一个包」：骨架星下面挂着别的包，只搜骨架等于把子树里另一半丢掉。
  List<PackContent> get _searchedPacks {
    final PackContent? pack = widget.pack;
    if (pack == null) {
      return const <PackContent>[];
    }
    if (widget.scopePluginId != null && !_searchAll) {
      final List<PackContent> scoped = widget.scopePacks;
      if (scoped.isEmpty) {
        return <PackContent>[pack];
      }
      if (scoped.any((PackContent content) => identical(content, pack))) {
        return scoped;
      }
      return <PackContent>[pack, ...scoped];
    }
    // 宽态 = 全部包。三份来源要并起来：本包、覆盖集外的、以及覆盖集本身
    // （`pack` 可能不在覆盖集里，那时它会漏掉自己的子树）。
    final List<PackContent> all = <PackContent>[];
    void add(PackContent content) {
      if (!all.any((PackContent seen) => identical(seen, content))) {
        all.add(content);
      }
    }

    add(pack);
    for (final PackContent content in widget.otherPacks) {
      add(content);
    }
    for (final PackContent content in widget.scopePacks) {
      add(content);
    }
    return all;
  }

  /// 传给引擎的圈定根。
  ///
  /// 窄态**一律给**：那里的包是地址子树覆盖到的（[LocateOverlay.scopePacks]），
  /// 每个包都在这棵子树里有节点，判圈内不会误伤。判据不能写成「包有几个 =
  /// 一个」—— 选中骨架星时圈内跨两个包，按包数判会把这种情形误判成宽态，
  /// `inScopeOf` 整段失效，「圈外」与「库里没有」在界面上长得一样。
  ///
  /// 宽态沿用旧判据：只有一个包时才给。多个包时别的包的树根不可能出现在这个
  /// 子树下，硬传会让每一条跨包命中都被判成「圈外」，于是「搜得到」变成
  /// 「点不动」。这条规则归调用方（也就是这里）决定，引擎不替它猜。
  String? get _scopeRoot {
    if (widget.subtreeRoot.isEmpty) {
      return null;
    }
    final bool wide = widget.scopePluginId == null || _searchAll;
    if (!wide || _searchedPacks.length == 1) {
      return widget.subtreeRoot;
    }
    return null;
  }

  /// 作用域是否还窄着 —— 也就是那一行「在全部空间中搜索」该不该出现。
  bool get _canWiden =>
      widget.scopePluginId != null &&
      !_searchAll &&
      widget.pack != null &&
      widget.otherPacks.isNotEmpty;

  /// 按 [query] 重算命中与分诊。
  ///
  /// 不碰「展开的表单」「留着的说明」—— 那两样是**改输入**这件事的连带后果，
  /// 由 `_onChanged` 清。预填路径没有「上一轮」，清它们没有意义。
  void _compute(String query) {
    final PackContent? pack = widget.pack;
    if (pack == null) {
      _result = null;
      _diagnosis = null;
      return;
    }
    final LocateResult result = Locator(
      _searchedPacks,
      subtreeRoot: _scopeRoot,
    ).locate(query);
    _result = result;
    // 分诊仍读**本包**：类 ② 的邻近候选是「换词」出口，跨包换词没有意义
    // （用户要的是本包的叫法），而类 ③ 的新增更是只能落在本包的域里。
    _diagnosis = diagnose(
      pack: pack,
      result: result,
      domainId: widget.domainId,
      subtreeRoot: widget.subtreeRoot,
    );
  }

  void _onChanged(String query) {
    setState(() {
      // 改了输入就是一次新的查询：展开的表单与留着的说明都作废 ——
      // 留着它们会让新输入带着旧结论走。
      _formOpen = false;
      _notice = null;
      _compute(query);
    });
  }

  void _pick(LocateHit hit) {
    final LocateResult? result = _result;
    if (result == null) {
      return;
    }
    // 跨空间命中照常交给调用方：换根与否是屏幕层的事（见文件头）。浮层在这里
    // 再拦一道，就会把「搜得到」变成「点不动」—— 那是单根时代的过渡态。
    widget.onPick(result, hit);
  }

  /// 把作用域放宽到全部包，并**立刻用当前输入重查**。
  void _widenToAllSpaces() {
    final String query = _controller.text;
    setState(() {
      _searchAll = true;
      final LocateResult result = Locator(
        _searchedPacks,
        subtreeRoot: _scopeRoot,
      ).locate(query);
      _result = result;
      final PackContent? pack = widget.pack;
      _diagnosis = pack == null
          ? null
          : diagnose(
              pack: pack,
              result: result,
              domainId: widget.domainId,
              subtreeRoot: widget.subtreeRoot,
            );
    });
  }

  /// 回车：有命中就选最强的那条（`located` 时它就是唯一落点）。
  ///
  /// **无命中时回车不做任何事** —— 回车不该等于「点一下主按钮」。类 ② 的主
  /// 按钮是「都不对」，如果回车也走它，用户只是想把输入交出去，却被告知
  /// 「你要的那个不存在」。
  void _submit() {
    final List<LocateHit> hits = _result?.usableHits ?? const <LocateHit>[];
    if (hits.isNotEmpty) {
      _pick(hits.first);
    }
  }

  /// 类 ② 的「都不对」：候选全被否掉，才谈得上新增（`VIEW-030` 闸门）。
  ///
  /// 没有域上下文时**不给表单**，只留一句需求信号 —— 表单第一格就得填「放到哪个
  /// 域」，替他挑一个域比不挑更糟（把新项塞进错的域，审核还得先改分类）。
  void _rejectNear() {
    if (widget.domainId != null) {
      _openForm();
      return;
    }
    setState(() => _notice = _notStored('需求信号'));
  }

  void _openForm() {
    _formTitle.text = _controller.text.trim();
    setState(() {
      _formOpen = true;
      _notice = null;
    });
  }

  /// 所有「写」动作共用的说明。**不写「已提交」** —— 没有落库就不能那么说。
  String _notStored(String what) =>
      '「$what」要写审核队列，而队列在 B4 才接入（entries 表 + 事件流）。'
      '本次没有写入任何数据。';

  void _submitForm() {
    setState(() {
      _formOpen = false;
      _notice = _notStored('新增项');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: locateOverlayKey,
      children: <Widget>[
        // 遮罩：点它关闭。不做模糊 —— 搜索时用户还想看见背后的星图，
        // 那是「我在找的东西大概在哪」的参照。
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(color: const Color(0x99000000)),
          ),
        ),
        Center(
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape):
                  widget.onDismiss,
            },
            child: Focus(
              // 让 Esc 有接住的地方：焦点在输入框时按键先冒泡到这里。
              //
              // **回车不在这里绑**：输入框的 `onSubmitted` 已经覆盖它。两处都绑
              // 会在同一帧里触发两次 `onPick` —— 第二次把第一次定好的档位又推一遍。
              autofocus: true,
              child: Container(
                width: 520,
                constraints: const BoxConstraints(maxHeight: 420),
                decoration: BoxDecoration(
                  color: paletteBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: paletteLine),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _field(),
                    const Divider(height: 1, color: paletteLine),
                    // **不能用 `Flexible`**：外层 `Column` 是 `mainAxisSize.min`，
                    // `Flexible` 在收缩高度下会拿到 0，而列表是惰性的 —— 此时
                    // 一行都不构建，界面看起来是「搜了但没结果」。给个上限让
                    // `shrinkWrap` 自己量。
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: _body(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field() => TextField(
    key: locateFieldKey,
    controller: _controller,
    focusNode: _fieldFocus,
    onChanged: _onChanged,
    onSubmitted: (_) => _submit(),
    style: const TextStyle(color: paletteTextPrimary, fontSize: 14),
    cursorColor: paletteAccent,
    decoration: const InputDecoration(
      hintText: '定位：项 / 域 / 空间 / 轴取值',
      hintStyle: TextStyle(color: paletteTextSecondary, fontSize: 13),
      border: InputBorder.none,
      contentPadding: EdgeInsets.fromLTRB(14, 14, 14, 14),
    ),
  );

  Widget _body() {
    if (widget.pack == null) {
      return _hint('没有内容包，无处可搜。请在 app/ 下启动。');
    }
    final LocateResult? result = _result;
    if (result == null || result.query.trim().isEmpty) {
      return _hint('输入关键词：完整标题直接定位，轴取值只筛选不换根。');
    }
    final String? notice = _notice;
    if (notice != null) {
      return _noticeView(notice);
    }
    if (_formOpen) {
      return _form();
    }
    if (!result.isEmpty) {
      return _results(result);
    }
    final LocateDiagnosis? diagnosis = _diagnosis;
    if (diagnosis == null) {
      // 非空输入一定会有分诊结论；留下兜底是为了不在将来某次改动后崩掉。
      return _hint('没有命中。');
    }
    return _triage(diagnosis);
  }

  Widget _results(LocateResult result) {
    final List<LocateHit> hits = result.usableHits;
    final Set<String> ambiguous = _ambiguousLabels(hits);
    // 列表头部的说明行。**不造假的命中行**：造出来的会被点，而点了没有 target
    // 可跳。「唯一命中」那一句也是一样的道理。
    final List<Widget> lead = <Widget>[
      if (_canWiden) _widenRow(),
      if (result.state == LocateState.located) _directHint(),
    ];
    // 底部 CTA 只在**至少有一条落点类命中**时出现。
    //
    // 筛选类（`LocateKind.axis`）不算：它写的是 `axisFilter`、不换根
    // （`VIEW-028`），不是范围 —— 只搜到一个轴值时圈不出任何项，给了按钮
    // 就是「按此范围建一份 0 项的计划」。
    final bool canPlan =
        widget.onPlanHere != null &&
        (widget.canPlanHere?.call(result) ?? true) &&
        hits.any((LocateHit hit) => hit.kind != LocateKind.axis);
    return ListView.builder(
      key: locateResultsKey,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: hits.length + lead.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index < lead.length) {
          return lead[index];
        }
        final int row = index - lead.length;
        if (row < hits.length) {
          return _row(hits[row], prefix: ambiguous.contains(hits[row].label));
        }
        return canPlan ? _planHere(result) : const SizedBox.shrink();
      },
    );
  }

  /// 「按此范围建计划」（`SPEC-PLAN-016` 第三行）。
  ///
  /// 放底部而不是每行一个：这一行说的是「为**这一轮搜索**建计划」，范围是
  /// 命中集的并，与单行无关。每行各挂一个会让用户以为点了只学那一项。
  Widget _planHere(LocateResult result) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: locatePlanHereKey,
        onPressed: () => widget.onPlanHere?.call(result),
        style: TextButton.styleFrom(
          backgroundColor: paletteSelected,
          foregroundColor: paletteTextPrimary,
          minimumSize: const Size(96, 30),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('按此范围建计划', style: TextStyle(fontSize: 12)),
      ),
    ),
  );

  /// 「在全部空间中搜索」那一行（`SPEC-VIEW-031`）。
  ///
  /// 只在**还有别的包可搜**时出现：只有一个包时它按下去什么也不会变，
  /// 而「按了没反应」的按钮比没有这个按钮更糟。
  ///
  /// [flush] 用于分诊面板 —— 那里外层已经有一圈 14 的留白，再叠一层左边距
  /// 会让这一行看起来比下面的正文缩进更多。
  Widget _widenRow({bool flush = false}) {
    final int others = widget.otherPacks.length;
    return InkWell(
      key: locateSearchAllKey,
      onTap: _widenToAllSpaces,
      child: Padding(
        padding: flush
            ? const EdgeInsets.only(bottom: 6)
            : const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.travel_explore,
              size: 14,
              color: paletteTextSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '在全部空间中搜索'
                '（另有 $others 个空间，共 '
                '${widget.otherPacks.length + 1} 个）',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: paletteTextSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directHint() => const Padding(
    padding: EdgeInsets.fromLTRB(14, 6, 14, 4),
    child: Text(
      '唯一命中 · 回车直接定位',
      style: TextStyle(color: paletteTextSecondary, fontSize: 10),
    ),
  );

  /// 需要写包名的那些标签（`SPEC-VIEW-033`）。
  ///
  /// 判据是「**同一名字出现在两个以上包**」—— 不是「有没有两个包」。
  /// 每行都写一遍包名是噪音，而它要解决的问题只在同名时存在；反过来，只搜
  /// 一个包时这个集合恒为空，也就不需要任何开关来控制前缀。
  Set<String> _ambiguousLabels(List<LocateHit> hits) {
    final Map<String, Set<String>> packsByLabel = <String, Set<String>>{};
    for (final LocateHit hit in hits) {
      packsByLabel.putIfAbsent(hit.label, () => <String>{}).add(hit.packId);
    }
    return <String>{
      for (final MapEntry<String, Set<String>> entry in packsByLabel.entries)
        if (entry.value.length > 1) entry.key,
    };
  }

  Widget _row(LocateHit hit, {required bool prefix}) {
    final bool filter = hit.kind == LocateKind.axis;
    // 「按此轴看」只在有上层接收时渲染（与 `onPlanHere` 同口径），而「哪条轴」
    // 得从命中行反解 —— 键不认识就不出按钮，让这一行退回纯筛选入口。
    final Axis? axis = filter ? _axisOf(hit) : null;
    return InkWell(
      key: locateRowKey(hit),
      onTap: () => _pick(hit),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: <Widget>[
            _badge(_badgeOf(hit)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // `VIEW-033`：同名项跨包时带前缀，否则只写原文。
                prefix
                    ? '${hit.packName}$locateSpaceSeparator${hit.label}'
                    : hit.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: paletteTextPrimary, fontSize: 13),
              ),
            ),
            // 两件事并排出现在一行，所以必须各说各的：整行点下去是**筛选**
            // （`VIEW-028`，不换根），右边那个按钮才是**换根去看这条轴**。
            // 只留按钮会让人以为点行也是换根，只留「筛选」则这条入口根本不存在。
            if (filter)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  '筛选',
                  style: TextStyle(color: paletteTextSecondary, fontSize: 10),
                ),
              ),
            if (axis != null && widget.onPickAxis != null) _axisHere(axis),
          ],
        ),
      ),
    );
  }

  /// 轴命中行上的「按此轴看」（`SPEC-TREE-010` 轴落点的界面入口）。
  ///
  /// 换根这件事归调用方（这里是**显示**层，见文件头）：浮层只把「用户要看哪条
  /// 轴」交出去 —— 轴根 id 是树的结构事实，浮层手里没有那棵树。
  Widget _axisHere(Axis axis) => TextButton(
    key: locateAxisHereKey(axis.name),
    onPressed: () => widget.onPickAxis?.call(axis),
    style: TextButton.styleFrom(
      backgroundColor: paletteSelected,
      foregroundColor: paletteTextPrimary,
      minimumSize: const Size(76, 26),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: const Text('按此轴看', style: TextStyle(fontSize: 11)),
  );

  /// 轴命中行说的是哪一条轴；`null` = 键不在册。
  ///
  /// 不用 `Axis.fromWire`：它按「包级数据坏了」的思路抛 `FormatException`，
  /// 而这里只是**少画一个按钮**。界面不该因为一条命中的元数据异常就整片红。
  Axis? _axisOf(LocateHit hit) {
    final String? key = hit.axisKey;
    if (key == null) {
      return null;
    }
    for (final Axis axis in Axis.values) {
      if (axis.name == key) {
        return axis;
      }
    }
    return null;
  }

  /// 分诊面板（`VIEW-030`）。四类各说各的事实与出口。
  Widget _triage(LocateDiagnosis diagnosis) {
    final String? domainId = diagnosis.domainId;
    final (
      String text,
      String action,
      VoidCallback onAction,
    ) = switch (diagnosis.kind) {
      DiagnoseClass.outOfScope => (
        '库里有 ${diagnosis.outside.length} 项对得上，但都不在圈内。'
            '它们在树里是虚线支线，宇宙里不画。',
        '申请纳入',
        () => setState(() => _notice = _notStored('纳入申请')),
      ),
      DiagnoseClass.differentWording => ('没有这个说法。最接近的是：', '都不对', _rejectNear),
      DiagnoseClass.absentInDomain => (
        '${domainId ?? ''} 里没有这一项。',
        '新增这一项',
        _openForm,
      ),
      DiagnoseClass.absentInSpace => (
        '整个空间都没有这一项。只能先记下这个需求 —— 不承诺何时会有。',
        '记下这个需求',
        () => setState(() => _notice = _notStored('需求信号')),
      ),
    };

    return SingleChildScrollView(
      key: locateTriageKey,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 本空间没有命中时，这一行比「新增」更值得先给：用户要找的东西很可能
          // 就在另一个空间（`VIEW-031` 放宽作用域的初衷）。
          if (_canWiden) _widenRow(flush: true),
          if (diagnosis.kind == DiagnoseClass.outOfScope)
            for (final LocateHit hit in diagnosis.outside)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    _badge(('圈外', paletteGap)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hit.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: paletteTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (diagnosis.kind == DiagnoseClass.differentWording)
            for (final NearItem near
                in diagnosis.near.take(_nearLimit).toList(growable: false))
              InkWell(
                key: locateNearRowKey(near.nodeId),
                onTap: () => widget.onPickNear(near.nodeId),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      _badge(('邻近', paletteTextSecondary)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          near.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: paletteTextPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Text(
              text,
              style: const TextStyle(
                color: paletteTextSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          _action(action, onAction),
        ],
      ),
    );
  }

  /// 一次性查询表单（`VIEW-032`）。
  ///
  /// **不碰 `axisFilter`**：填表是「我找不到，帮我建一个」，不是筛选；写进筛选
  /// 的话，退出搜索后视图还是被筛过的，而用户早已不记得自己筛过什么。
  Widget _form() {
    final String domain = widget.domainId ?? '';
    final bool canSubmit = _formTitle.text.trim().isNotEmpty;
    return SingleChildScrollView(
      key: locateFormKey,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '新增到 $domain（提交审核）',
            style: const TextStyle(color: paletteTextSecondary, fontSize: 11),
          ),
          TextField(
            key: locateFormTitleKey,
            controller: _formTitle,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: paletteTextPrimary, fontSize: 13),
            cursorColor: paletteAccent,
            decoration: const InputDecoration(
              hintText: '标题',
              hintStyle: TextStyle(color: paletteTextSecondary, fontSize: 12),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              TextButton(
                key: locateFormSubmitKey,
                onPressed: canSubmit ? _submitForm : null,
                style: TextButton.styleFrom(
                  backgroundColor: paletteSelected,
                  foregroundColor: paletteTextPrimary,
                  minimumSize: const Size(72, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('提交审核', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _formOpen = false),
                style: TextButton.styleFrom(
                  foregroundColor: paletteTextSecondary,
                  minimumSize: const Size(48, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('返回', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap) => TextButton(
    key: locateTriageActionKey,
    onPressed: onTap,
    style: TextButton.styleFrom(
      backgroundColor: paletteSelected,
      foregroundColor: paletteTextPrimary,
      minimumSize: const Size(96, 30),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(label, style: const TextStyle(fontSize: 12)),
  );

  Widget _noticeView(String text) => Padding(
    key: locateNoticeKey,
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
    child: Align(
      alignment: Alignment.topLeft,
      child: Text(
        text,
        style: const TextStyle(color: paletteGap, fontSize: 12, height: 1.6),
      ),
    ),
  );

  /// 类徽标。**筛选类必须和落点类长得不一样** —— 点前者不换根、点后者跳走，
  /// 两者长得一样就是让人猜自己按下去会发生什么。
  Widget _badge((String, Color) spec) {
    final (String text, Color color) = spec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10)),
    );
  }

  (String, Color) _badgeOf(LocateHit hit) => switch (hit.kind) {
    LocateKind.space => ('空间', paletteAccent),
    LocateKind.domain => ('域', paletteAccent),
    LocateKind.item => ('项', paletteTextSecondary),
    LocateKind.axis => ('轴值', paletteGap),
  };

  Widget _hint(String text) => Padding(
    key: locateHintKey,
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
    child: Align(
      alignment: Alignment.topLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: paletteTextSecondary,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    ),
  );
}

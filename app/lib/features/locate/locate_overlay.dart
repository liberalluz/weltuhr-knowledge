/// 快速定位浮层（`SPEC-VIEW-024` / `026` / `027` / `028` / `029` / `033`）。
///
/// ## 为什么是浮层而不是常驻输入框
///
/// `VIEW-026`：搜索是「用完即走」的动作。常驻输入框会长期占住中央内容区，
/// 而这块画布的全部意义是「位置即语义」—— 让一个文本框抢走它，等于把
/// 语义区降级成工具栏。
///
/// ## 浮层只做「输入 → 命中集」的呈现与选择
///
/// 跳不跳、跳到哪一档、写不写 `axisFilter`，全在 `universe_screen` 的
/// `_applyHit` 里 —— 那是**行为**，而这层是**显示**。分开的好处是浮层可以
/// 脱离整个屏幕单独测：给一句输入，看它列了什么。
///
/// ## 唯一命中为什么要回车而不是自动跳
///
/// `VIEW-027` 说「唯一命中 → 直接跳转」，说的是**不必先选列表再点一次**。
/// 但它不等于「边打字边跳」：打到「装饰」时命中集只有一条，再打一个字变成
/// 两条，中间每一次按键都跳一次的话，用户会被界面拽着跑。所以 `located`
/// 的呈现是「一行直达 + 回车」，回车是一次显式动作。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locate/locator.dart';
import '../../core/pack/pack_parse.dart';
import '../palette.dart';

/// 浮层根节点。
const Key locateOverlayKey = Key('locate-overlay');

/// 输入框。
const Key locateFieldKey = Key('locate-field');

/// 结果列表。
const Key locateResultsKey = Key('locate-results');

/// 提示行（空输入 / 无命中 / 包缺失）。
const Key locateHintKey = Key('locate-hint');

/// 某一命中行的 `Key`。
///
/// 带 `kind` 而不只带 `target`：同一个词可能同时命中域与项（域 id 末段 =
/// 项标题），两条都出现在列表里时 `Key` 撞车会让 widget test 里
/// `findsOneWidget` 假红。
Key locateRowKey(LocateHit hit) =>
    Key('locate-row-${hit.kind.name}-${hit.axisKey ?? ''}-${hit.target}');

class LocateOverlay extends StatefulWidget {
  const LocateOverlay({
    required this.pack,
    required this.onPick,
    required this.onDismiss,
    this.spacePrefix,
    super.key,
  });

  /// `null` = 合成回落，没有可搜的东西。浮层仍然打开并说明原因 ——
  /// 不给入口比给了不响应好，但两者都比「静默无反应」好。
  final LoadedPack? pack;

  /// 选中一条命中。第二个参数是**这次定位的完整结果** —— 路由要它来判断
  /// 是不是「唯一命中」。
  final void Function(LocateResult result, LocateHit hit) onPick;

  final VoidCallback onDismiss;

  /// `VIEW-033`：多个空间存在同名项时，结果行必须带空间前缀。
  /// 只有一个空间时传 `null` —— 每行都写一遍同样的前缀是噪音。
  final String? spacePrefix;

  @override
  State<LocateOverlay> createState() => _LocateOverlayState();
}

class _LocateOverlayState extends State<LocateOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();

  LocateResult? _result;

  @override
  void initState() {
    super.initState();
    // 打开即能打字：进浮层还要先点一下输入框，是把两步并成一步的机会丢了。
    _fieldFocus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    final LoadedPack? pack = widget.pack;
    setState(() {
      _result = pack == null ? null : Locator(pack).locate(query);
    });
  }

  void _pick(LocateHit hit) {
    final LocateResult? result = _result;
    if (result == null) {
      return;
    }
    widget.onPick(result, hit);
  }

  /// 回车：有命中就选最强的那条（`located` 时它就是唯一落点）。
  void _submit() {
    final List<LocateHit> hits = _result?.hits ?? const <LocateHit>[];
    if (hits.isNotEmpty) {
      _pick(hits.first);
    }
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
    if (result.isEmpty) {
      // 无命中的四类分诊归第二笔（`VIEW-030`）。这里先如实说「没有」，
      // 不在这里造一个「新增」入口 —— 那正是规格要防的事。
      return _hint('没有命中。');
    }
    return _results(result);
  }

  Widget _results(LocateResult result) {
    final List<LocateHit> hits = result.hits;
    final bool direct = result.state == LocateState.located;
    return ListView.builder(
      key: locateResultsKey,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: hits.length + (direct ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (direct && index == 0) {
          // 「直达」不是另造一条结果，而是在真结果上方说一句「回车就跳」。
          // 造一条假结果的话，它会被点，而点了之后没有 target 可跳。
          return const Padding(
            padding: EdgeInsets.fromLTRB(14, 6, 14, 4),
            child: Text(
              '唯一命中 · 回车直接定位',
              style: TextStyle(color: paletteTextSecondary, fontSize: 10),
            ),
          );
        }
        final LocateHit hit = hits[direct ? index - 1 : index];
        return _row(hit);
      },
    );
  }

  Widget _row(LocateHit hit) {
    final bool filter = hit.kind == LocateKind.axis;
    return InkWell(
      key: locateRowKey(hit),
      onTap: () => _pick(hit),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: <Widget>[
            _badge(hit),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // `VIEW-033`：同名项跨空间时带前缀，否则只写原文。
                widget.spacePrefix == null
                    ? hit.label
                    : '${widget.spacePrefix} › ${hit.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: paletteTextPrimary, fontSize: 13),
              ),
            ),
            if (filter)
              const Text(
                '筛选',
                style: TextStyle(color: paletteTextSecondary, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  /// 类徽标。**筛选类必须和落点类长得不一样** —— 点前者不换根、点后者跳走，
  /// 两者长得一样就是让人猜自己按下去会发生什么。
  Widget _badge(LocateHit hit) {
    final (String text, Color color) = switch (hit.kind) {
      LocateKind.space => ('空间', paletteAccent),
      LocateKind.domain => ('域', paletteAccent),
      LocateKind.item => ('项', paletteTextSecondary),
      LocateKind.axis => ('轴值', paletteGap),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10)),
    );
  }

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

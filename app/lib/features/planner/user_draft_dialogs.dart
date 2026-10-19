/// 三段「+ 自建」的表单（`SPEC-PLAN-007` / `008` / `011`）。
///
/// ## 为什么是三张表、不是一张通用表
///
/// 三段要填的东西**没有交集**：源要名字 / 等级 / 版本 / 适用类型；体系要「挑哪
/// 些项、什么次序」；方法要「步骤表」。做成一张「通用元数据表」只能取三者的
/// 最小公倍数，结果是三段都填不全，还得在提交处按类型分支 —— 那比三个小表更
/// 难读，也更容易漏掉某个段的必填项。
///
/// ## 形态仍然是「列表尾部的一个动作」
///
/// `SPEC-PLAN-007` 明写自建**不是独立页面**：三张表都以对话框出现，提交后立刻
/// 回到同一个列表并被选中。没有「我的题库」这类页面 —— 那等于把「建」和「选」
/// 拆成两处，用户建完还得回来找它。
///
/// ## 校验放在提交处，不放在每个字段上
///
/// `SPEC-PLAN-011` 的「只能自定配方」和 `entity-fields` §一.7 的校验 ② 都是
/// **整份**的性质（至少一个 review 步），逐字段校验表达不出来。所以 [trySubmit]
/// 一次性收口，失败时**把原话显示在表里**而不是静默吞掉 —— 用户填了三步全是
/// 「读」，需要知道为什么不让存。
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/entities/content.dart';
import '../../core/enums.dart';
import '../../core/pack/pack_parse.dart';
import '../../core/plan/user_content.dart';

const Key userDialogCancelKey = Key('user-dialog-cancel');
const Key userDialogAddKey = Key('user-dialog-add');
const Key userDialogErrorKey = Key('user-dialog-error');

// ───────────────────────────── 源 ─────────────────────────────

const Key userSourceNameKey = Key('user-source-name');
const Key userSourceVersionKey = Key('user-source-version');
const Key userSourceLevelKey = Key('user-source-level');

Key userSourceTypeKey(ItemType type) => Key('user-source-type-${type.name}');

/// 自建的源。返回 `null` = 取消。
Future<SourceRef?> showUserSourceDialog(
  BuildContext context, {
  required List<String> takenIds,
}) {
  return showDialog<SourceRef>(
    context: context,
    builder: (BuildContext context) =>
        _SourceForm(takenIds: takenIds),
  );
}

class _SourceForm extends StatefulWidget {
  const _SourceForm({required this.takenIds});

  final List<String> takenIds;

  @override
  State<_SourceForm> createState() => _SourceFormState();
}

class _SourceFormState extends State<_SourceForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _version = TextEditingController(text: '1');
  String _level = 'L2';
  final Set<ItemType> _types = <ItemType>{};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _version.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final SourceRef source = buildUserSource(
        id: uniqueContentId('$userSourceIdPrefix${_name.text.trim()}', widget.takenIds),
        name: _name.text,
        authorityLevel: _level,
        version: _version.text,
        // 没勾任何类型 = 不限（`normalizeAppliesTo` 会把空集丢掉）。
        appliesTo: <String, Object?>{
          'type': <String>[for (final ItemType t in _types) t.name],
        },
      );
      Navigator.of(context).pop(source);
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('+ 自建 · 源'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: userSourceNameKey,
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '名字',
                  hintText: '如「公司内部规范」',
                ),
              ),
              TextField(
                key: userSourceVersionKey,
                controller: _version,
                decoration: const InputDecoration(labelText: '版本'),
              ),
              DropdownButton<String>(
                key: userSourceLevelKey,
                value: _level,
                items: <DropdownMenuItem<String>>[
                  for (final String level in const <String>['L0', 'L1', 'L2', 'L4'])
                    DropdownMenuItem<String>(value: level, child: Text('出处等级 $level')),
                ],
                onChanged: (String? v) => setState(() => _level = v ?? _level),
              ),
              const SizedBox(height: 8),
              const Text('适用类型（不勾 = 不限）', style: TextStyle(fontSize: 12)),
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final ItemType type in ItemType.values)
                    FilterChip(
                      key: userSourceTypeKey(type),
                      label: Text(itemTypeLabels[type]!),
                      selected: _types.contains(type),
                      onSelected: (bool on) => setState(() {
                        if (on) {
                          _types.add(type);
                        } else {
                          _types.remove(type);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '自建的源暂时只作登记：它还没有摘录正文，也不会有项引用它。',
                style: TextStyle(fontSize: 11),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: userDialogErrorKey,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: userDialogCancelKey,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: userDialogAddKey,
          onPressed: _submit,
          child: const Text('加入候选'),
        ),
      ],
    );
  }
}

// ──────────────────────────── 体系 ────────────────────────────

const Key userSchemeNameKey = Key('user-scheme-name');
const Key userSchemeLevelKey = Key('user-scheme-level');

Key userSchemePickKey(String itemId) => Key('user-scheme-pick-$itemId');
Key userSchemeUpKey(String itemId) => Key('user-scheme-up-$itemId');
Key userSchemeDownKey(String itemId) => Key('user-scheme-down-$itemId');
Key userSchemeRemoveKey(String itemId) => Key('user-scheme-remove-$itemId');

/// 自建的体系。返回 `null` = 取消。
Future<Scheme?> showUserSchemeDialog(
  BuildContext context, {
  required LoadedPack pack,
  required List<String> takenIds,
}) {
  return showDialog<Scheme>(
    context: context,
    builder: (BuildContext context) =>
        _SchemeForm(pack: pack, takenIds: takenIds),
  );
}

class _SchemeForm extends StatefulWidget {
  const _SchemeForm({required this.pack, required this.takenIds});

  final LoadedPack pack;
  final List<String> takenIds;

  @override
  State<_SchemeForm> createState() => _SchemeFormState();
}

class _SchemeFormState extends State<_SchemeForm> {
  final TextEditingController _name = TextEditingController();
  String _level = 'L2';

  /// **顺序即学习次序** —— 挑选的先后就是 `nodes` 的次序。
  final List<String> _picked = <String>[];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _move(String itemId, int delta) {
    final int from = _picked.indexOf(itemId);
    final int to = from + delta;
    if (from < 0 || to < 0 || to >= _picked.length) {
      return;
    }
    setState(() {
      _picked.removeAt(from);
      _picked.insert(to, itemId);
    });
  }

  void _submit() {
    try {
      final Scheme scheme = buildUserScheme(
        id: uniqueContentId('$userSchemeIdPrefix${_name.text.trim()}', widget.takenIds),
        name: _name.text,
        nodes: _picked,
        authorityLevel: _level,
      );
      Navigator.of(context).pop(scheme);
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Item> items = <Item>[
      for (final Item item in widget.pack.items)
        if (item.inScope) item,
    ];
    return AlertDialog(
      title: const Text('+ 自建 · 体系'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: userSchemeNameKey,
                controller: _name,
                decoration: const InputDecoration(labelText: '名字'),
              ),
              DropdownButton<String>(
                key: userSchemeLevelKey,
                value: _level,
                items: <DropdownMenuItem<String>>[
                  for (final String level in const <String>['L0', 'L1', 'L2', 'L4'])
                    DropdownMenuItem<String>(value: level, child: Text('出处等级 $level')),
                ],
                onChanged: (String? v) => setState(() => _level = v ?? _level),
              ),
              const SizedBox(height: 8),
              Text('已选 ${_picked.length} 项（次序即学习次序）',
                  style: const TextStyle(fontSize: 12)),
              for (final String itemId in _picked) _pickedRow(itemId),
              const Divider(),
              const Text('圈内项（点一下加入尾部）', style: TextStyle(fontSize: 12)),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  for (final Item item in items)
                    if (!_picked.contains(item.id))
                      ActionChip(
                        key: userSchemePickKey(item.id),
                        label: Text(item.title),
                        onPressed: () => setState(() => _picked.add(item.id)),
                      ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: userDialogErrorKey,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: userDialogCancelKey,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: userDialogAddKey,
          onPressed: _submit,
          child: const Text('加入候选'),
        ),
      ],
    );
  }

  Widget _pickedRow(String itemId) {
    final Item? item = widget.pack.itemOf(itemId);
    return Row(
      key: Key('user-scheme-picked-$itemId'),
      children: <Widget>[
        Expanded(
          child: Text(item?.title ?? itemId, style: const TextStyle(fontSize: 12)),
        ),
        IconButton(
          key: userSchemeUpKey(itemId),
          icon: const Icon(Icons.arrow_upward, size: 16),
          onPressed: () => _move(itemId, -1),
        ),
        IconButton(
          key: userSchemeDownKey(itemId),
          icon: const Icon(Icons.arrow_downward, size: 16),
          onPressed: () => _move(itemId, 1),
        ),
        IconButton(
          key: userSchemeRemoveKey(itemId),
          icon: const Icon(Icons.close, size: 16),
          onPressed: () => setState(() => _picked.remove(itemId)),
        ),
      ],
    );
  }
}

// ──────────────────────────── 方法 ────────────────────────────

const Key userMethodNameKey = Key('user-method-name');
const Key userMethodAddStepKey = Key('user-method-add-step');

Key userMethodTypeKey(ItemType type) => Key('user-method-type-${type.name}');
Key userMethodOpKey(int index, ExecutionOperator op) =>
    Key('user-method-step-$index-op-${op.name}');
Key userMethodCriteriaKey(int index) => Key('user-method-step-$index-criteria');
Key userMethodHintKey(int index) => Key('user-method-step-$index-hint');
Key userMethodPhaseKey(int index) => Key('user-method-step-$index-phase');
Key userMethodRemoveStepKey(int index) => Key('user-method-step-$index-remove');

/// 六类算子的中文名（`entity-fields` §一.7 表格原文：读 / 例 / 忆 / 练 / 讲 / 做）。
const Map<ExecutionOperator, String> operatorLabels = <ExecutionOperator, String>{
  ExecutionOperator.read: '读',
  ExecutionOperator.example: '例',
  ExecutionOperator.recall: '忆',
  ExecutionOperator.practice: '练',
  ExecutionOperator.teach: '讲',
  ExecutionOperator.build: '做',
};

/// 自建的方法。返回 `null` = 取消。
Future<UserMethodDraft?> showUserMethodDialog(
  BuildContext context, {
  required List<String> takenIds,
}) {
  return showDialog<UserMethodDraft>(
    context: context,
    builder: (BuildContext context) => _MethodForm(takenIds: takenIds),
  );
}

/// 表单里的一步。**不直接建 [MethodStep]**：`phase` 需要「未覆盖（派生）」这个
/// 第三态，而 `MethodStep.phase` 的 `null` 已经表示它 —— 用一个可空字段表达即可。
class _StepForm {
  _StepForm(this.operator);

  ExecutionOperator operator;
  StepPhase? phase;
  final TextEditingController criteria = TextEditingController();
  final TextEditingController hint = TextEditingController();

  MethodStep toStep() => MethodStep(
    operator: operator,
    phase: phase,
    criteria: criteria.text.trim().isEmpty ? null : criteria.text.trim(),
    hint: hint.text.trim().isEmpty ? null : hint.text.trim(),
  );

  void dispose() {
    criteria.dispose();
    hint.dispose();
  }
}

class _MethodForm extends StatefulWidget {
  const _MethodForm({required this.takenIds});

  final List<String> takenIds;

  @override
  State<_MethodForm> createState() => _MethodFormState();
}

class _MethodFormState extends State<_MethodForm> {
  final TextEditingController _name = TextEditingController();
  ItemType _type = ItemType.declarative;

  /// 起手就是「读」—— 它是最常见的第一步，但**单独一步不够**：校验 ② 会拦。
  final List<_StepForm> _steps = <_StepForm>[ _StepForm(ExecutionOperator.read) ];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    for (final _StepForm step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  void _submit() {
    try {
      final UserMethodDraft draft = UserMethodDraft(
        id: uniqueContentId('$userMethodIdPrefix${_name.text.trim()}', widget.takenIds),
        name: _name.text,
        type: _type,
        steps: <MethodStep>[for (final _StepForm s in _steps) s.toStep()],
      );
      // 校验在校验函数里，不在这里：建的时候拦一次，等于规则只有一处。
      buildUserMethod(draft);
      Navigator.of(context).pop(draft);
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('+ 自建 · 方法'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: userMethodNameKey,
                controller: _name,
                decoration: const InputDecoration(labelText: '名字'),
              ),
              const SizedBox(height: 8),
              const Text('适用类型（一份自建只覆盖一个类型）',
                  style: TextStyle(fontSize: 12)),
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final ItemType type in ItemType.values)
                    ChoiceChip(
                      key: userMethodTypeKey(type),
                      label: Text(itemTypeLabels[type]!),
                      selected: _type == type,
                      onSelected: (bool on) {
                        if (on) {
                          setState(() => _type = type);
                        }
                      },
                    ),
                ],
              ),
              const Divider(),
              for (int i = 0; i < _steps.length; i++) _stepRow(i),
              TextButton.icon(
                key: userMethodAddStepKey,
                onPressed: () => setState(
                  () => _steps.add(_StepForm(ExecutionOperator.recall)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('加一步'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: userDialogErrorKey,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: userDialogCancelKey,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: userDialogAddKey,
          onPressed: _submit,
          child: const Text('加入候选'),
        ),
      ],
    );
  }

  Widget _stepRow(int index) {
    final _StepForm step = _steps[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('第 ${index + 1} 步',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                key: userMethodRemoveStepKey(index),
                icon: const Icon(Icons.delete_outline, size: 16),
                onPressed: _steps.length == 1
                    ? null
                    : () => setState(() {
                        _steps.removeAt(index).dispose();
                      }),
              ),
            ],
          ),
          // 算子只给六类，**没有自由输入**（`SPEC-PLAN-011`：6 类之外不得新增）。
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (final ExecutionOperator op in ExecutionOperator.values)
                ChoiceChip(
                  key: userMethodOpKey(index, op),
                  label: Text(operatorLabels[op]!),
                  selected: step.operator == op,
                  onSelected: (bool on) {
                    if (on) {
                      setState(() => step.operator = op);
                    }
                  },
                ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: userMethodCriteriaKey(index),
                  controller: step.criteria,
                  decoration: const InputDecoration(
                    labelText: '判据（留空 = 打卡式）',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: userMethodHintKey(index),
                  controller: step.hint,
                  decoration: const InputDecoration(
                    labelText: '提示（可空）',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          DropdownButton<StepPhase?>(
            key: userMethodPhaseKey(index),
            value: step.phase,
            items: const <DropdownMenuItem<StepPhase?>>[
              DropdownMenuItem<StepPhase?>(child: Text('phase · 按算子派生')),
              DropdownMenuItem<StepPhase?>(
                value: StepPhase.first,
                child: Text('phase · first'),
              ),
              DropdownMenuItem<StepPhase?>(
                value: StepPhase.review,
                child: Text('phase · review'),
              ),
              DropdownMenuItem<StepPhase?>(
                value: StepPhase.both,
                child: Text('phase · both'),
              ),
            ],
            onChanged: (StepPhase? v) => setState(() => step.phase = v),
          ),
        ],
      ),
    );
  }
}

/// 方法（配方）—— `entity-fields` §12，第五类包。
///
/// 笔 5c 之前它与 `content.dart` 里的旧 `MethodProfile` 同名并存，旧类已随
/// `Item` 一并删除。
///
/// 独立成包的理由：一份配方可服务多个载荷包（N:M），语言类配方不必跟着每个
/// 语言包各发一份。
library;

import '../enums.dart';
import '../json.dart';
import 'entry.dart';

/// 一份配方。
class MethodProfile {
  const MethodProfile({
    required this.id,
    required this.name,
    required this.steps,
    required this.appliesTo,
    required this.origin,
  });

  factory MethodProfile.fromJson(JsonMap json) => MethodProfile(
    id: requireString(json, 'id'),
    name: requireString(json, 'name'),
    steps: requireMapList(
      json,
      'steps',
    ).map(EntryStep.fromJson).toList(growable: false),
    appliesTo: requireMap(json, 'appliesTo'),
    origin: CandidateOrigin.fromWire(requireString(json, 'origin')),
  );

  final String id;
  final String name;

  /// 与 `NodeEntry.steps[]` **同一算子集**，所以复用 [EntryStep] ——
  /// 两处各写一个步骤类，算子表改一次就要改两个地方。
  final List<EntryStep> steps;

  /// **必填**：适用哪类节点（`LearnableType` / 轴 / 层）。
  final JsonMap appliesTo;

  /// 合并优先级 `user > pack > platform`。
  final CandidateOrigin origin;

  /// 校验 ②：至少有一个 `review` 步骤（防静默绕过遗忘曲线）。
  bool get hasReviewStep =>
      steps.any((EntryStep s) => s.effectivePhase != StepPhase.first);

  /// 校验 ③：全步骤无 `hint` ⇒ Planner ③ 须提示「本方法无提示可给」。
  bool get hasAnyHint => steps.any((EntryStep s) => s.hint != null);

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'steps': steps.map((EntryStep s) => s.toJson()).toList(),
    'appliesTo': appliesTo,
    'origin': origin.name,
  };
}

/// 一份绑定：四个可学类型各指一份分支。
///
/// **允许不齐** —— 缺分支 = 不覆盖该类型，确认段须拦住并说明。不齐之所以
/// 合法：一份「语言类配方」不必对 `tacit` 有话说，而强行要求四类齐全只会
/// 逼作者写一条凑数的分支。
class MethodBundle {
  const MethodBundle({
    required this.id,
    required this.name,
    required this.origin,
    required this.byType,
  });

  factory MethodBundle.fromJson(JsonMap json) {
    final JsonMap byType = requireMap(json, 'byType');
    return MethodBundle(
      id: requireString(json, 'id'),
      name: requireString(json, 'name'),
      origin: CandidateOrigin.fromWire(requireString(json, 'origin')),
      byType: <LearnableType, String>{
        for (final MapEntry<String, Object?> entry in byType.entries)
          LearnableType.fromWire(entry.key): '${entry.value}',
      },
    );
  }

  final String id;
  final String name;
  final CandidateOrigin origin;

  /// `LearnableType` → `MethodProfile.id`。
  final Map<LearnableType, String> byType;

  /// 该类型有没有分支（缺 = 不覆盖）。
  String? profileOf(LearnableType type) => byType[type];

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'origin': origin.name,
    'byType': <String, Object?>{
      for (final MapEntry<LearnableType, String> e in byType.entries)
        e.key.name: e.value,
    },
  };
}

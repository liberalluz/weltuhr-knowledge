/// 方法「组合」—— Planner ③ 段被选中的那个东西。
///
/// **为什么需要这一层**（`B4` `P-2` 定）：`SPEC-PLAN-010` 要求「用户选**一套**，
/// 具体到每一项时按 `Item.type` 自动派生」，而 `MethodProfile` 一个 id 只装得下
/// **一份**步骤表 + 一份 `appliesTo`。一个 id 指不到四个类型分支。
///
/// 于是拆成两层：
///
/// ```
/// MethodBundle（被选中，Plan.methodProfileId 存它的 id）
///   └── byType: ItemType → MethodProfile.id   ← 按类型派生就发生在这一跳
///         MethodProfile（分支：费曼 / 间隔重复 / 刻意练习 / 跟读模仿 / 项目驱动）
/// ```
///
/// **`Plan.methodProfileId` 一字未改**，仍是一个 `String`，只是它指向组合而非
/// 分支。这样 `event-types.md` 里 `plan_created` 的 payload 不用动，事件已经
/// 开始写盘，改字段是不可逆的迁移面。
library;

import '../enums.dart';

/// 一套方法 = 一张「类型 → 分支」的映射。
class MethodBundle {
  const MethodBundle({
    required this.id,
    required this.name,
    required this.origin,
    required this.byType,
  });

  final String id;
  final String name;
  final CandidateOrigin origin;

  /// 四个 `ItemType` 各指到一份 `MethodProfile.id`。
  ///
  /// **允许不齐**：包或缺某一类，届时该项由平台默认分支兜底（`P-6` 落事件时
  /// 若 `profileIdFor` 为 `null` 即视为不可用于该型项，`Planner` 须拦住确认）。
  final Map<ItemType, String> byType;

  /// 该类型走哪份分支；`null` = 这套方法未覆盖该类型。
  String? profileIdFor(ItemType type) => byType[type];

  /// 覆盖到的类型集合（排序键的原料，`SPEC-PLAN-020`）。
  Set<ItemType> get coveredTypes => byType.keys.toSet();
}

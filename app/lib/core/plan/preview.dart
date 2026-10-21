/// Planner 右栏的实时预览（`SPEC-PLAN-015`）：**只三项** —— 项数 · 分母 · 预计时长。
///
/// ## 为什么不给难度分布
///
/// `D` 在建计划时**还不存在**（FSRS 首次评分才初始化），而 `φ` 不能当难度代理。
/// 硬画一张分布图，等于把一个尚未产生的量画出来给人看。
///
/// ## 分母为什么与项数分开
///
/// 分母 = **圈内项数**，不随体系覆盖度变化（`SPEC-PLAN-015`）。选中一套只覆盖
/// 一半节点的体系时，项数变小、分母不变 —— 那个差值本身就是信息：「这套序漏了
/// 一半内容」，而不是「这个空间只有一半内容」。
///
/// ## 项数与分母回答两个不同的问题
///
/// 分母答「这个空间一共多大」，项数答「这次要走多少」。两者相减是**两笔不同的
/// 差额**，混成一笔就再也分不开：
///
/// ```text
/// 分母 150（圈内）
///  ├─ 体系覆盖 120   ← 项数，这套序真正要走的部分
///  └─ 游离 30        ← 分母 − 120，这套序没安排
/// ```
///
/// 分母若跟着体系缩，「范围只有 150 项」与「这套序只覆盖 120 项」就变成一个数，
/// 用户看不出是哪种情况。
///
/// ## 范围只有一处：`subtreeRoot`
///
/// 旧实现还有第二次收窄（`PlanTarget.selector`，`PLAN-016` 的定位结果入口），
/// 于是同一句话要区分「这空间多大」与「这份计划走多少」。`ADR-0007` 决策 2 把
/// `inScope` 改成派生值之后，范围只能由子树根回答 —— **收窄子树根，分母跟着
/// 一起收**，两个读数不再能各说各的（`TC-PLAN-045` 验的就是这一条）。剩下的项
/// 靠**另建一份 `Plan`**（`SPEC-PLAN-003` 允许同一子树并存多份），不存在一份会
/// 自己长大的计划。
///
/// ## 时长
///
/// `Σ(算子系数 × 步骤数 × 项数)`，系数见 `C-14`…`C-19`。逐项按 `Item.type`
/// 派生到分支 profile 再累加 —— 同一套方法对不同类型可以给不同步骤数，先乘平均
/// 再乘项数会把这件事抹平。
///
/// 未选方法时按**平台默认组合**估，并把 [usingDefaultMethod] 置真，让界面能写
/// 「按默认估算」而不是假装这是用户选出来的读数。
library;

import '../constants.dart';
import '../entities/entry.dart';
import '../entities/method.dart';
import '../entities/node.dart';
import '../entities/scheme.dart';
import '../graph/parent_index.dart';
import '../pack/pack_reader.dart';
import 'platform_candidates.dart';
import 'scope.dart';

/// 预览的三个读数 + 两个「这个数有多可信」的标记。
class PlannerPreview {
  const PlannerPreview({
    required this.itemCount,
    required this.denominator,
    required this.minutes,
    required this.usingDefaultMethod,
    required this.uncoveredItems,
  });

  /// 本次计划覆盖多少项 = 圈内可学节点 ∩ 体系节点。
  ///
  /// 两者都是「有则收窄、无则不收」：没选体系 = 圈内全量。**它恒 ≤
  /// [denominator]** —— 体系节点若含圈外项，那部分会被 `resolvePlanScope` 剔掉。
  final int itemCount;

  /// 分母 = 圈内可学节点数。**不随体系覆盖度变化。**
  final int denominator;

  /// 预计分钟数。
  final int minutes;

  /// 未选方法，时长按平台默认组合估算。
  final bool usingDefaultMethod;

  /// 方法未覆盖类型的项数。`> 0` 时确认段必须拦住 —— 那些项没有可用步骤。
  final int uncoveredItems;

}

/// 算一次预览。纯函数：不读盘、不看时钟。
///
/// [schemeId] 不存在时抛 `ArgumentError`（与 `loadCandidates` 同一口径：那是
/// 调用方拿错了 id，静默回落到全量会让人以为这套体系覆盖了全部）。
///
/// [subtreeRoot] + [parents] 给出**圈内**范围：`inScope` 是派生值
/// （`entity-fields` §2），不存字段，所以每次算都要这两样。本函数**没有第二处
/// 收窄** —— 子树根本身就是计划范围。
///
/// [userSchemes] / [userProfiles] 是用户自建档（`SPEC-PLAN-007`）。**不传自建
/// 分支，自建的方法会被算成「未覆盖」** —— 预览报「未覆盖 N 项」、确认段据此
/// 拦住，用户刚建的方法反而用不了。两处都按 `user > platform` 覆盖同 id。
PlannerPreview computePlannerPreview({
  required PackContent pack,
  required String subtreeRoot,
  required ParentIndex parents,
  String? schemeId,
  MethodBundle? bundle,
  List<MethodProfile> profiles = platformMethodProfiles,
  List<MethodProfile> userProfiles = const <MethodProfile>[],
  List<Scheme> userSchemes = const <Scheme>[],
}) {
  final PlanScope scope = resolvePlanScope(
    pack: pack,
    subtreeRoot: subtreeRoot,
    parents: parents,
    schemeId: schemeId,
    userSchemes: userSchemes,
  );

  final MethodBundle effective = bundle ?? platformMethodBundles.first;
  final Map<String, MethodProfile> byId = <String, MethodProfile>{
    for (final MethodProfile p in profiles) p.id: p,
    for (final MethodProfile p in userProfiles) p.id: p,
  };

  int minutes = 0;
  int uncovered = 0;
  for (final LearnableNode node in scope.nodes) {
    final String? profileId = effective.profileOf(node.type);
    final MethodProfile? profile = profileId == null ? null : byId[profileId];
    if (profile == null) {
      uncovered++;
      continue;
    }
    for (final EntryStep step in profile.steps) {
      minutes += operatorMinutes[step.operator] ?? 0;
    }
  }

  return PlannerPreview(
    itemCount: scope.nodes.length,
    denominator: scope.denominator,
    minutes: minutes,
    usingDefaultMethod: bundle == null,
    uncoveredItems: uncovered,
  );
}

/// 用户自建的三段内容（`SPEC-PLAN-007` / `011`）。
///
/// ## 「+ 自建」不是独立功能，是三段列表尾部的一个动作
///
/// `SPEC-PLAN-007` 把它定为每段候选列表尾部的「+ 自建」，链路一律：
///
/// ```text
/// 草稿（本机） → 立刻可选但仅自己可见 → 提审（GOV 四裁定） → 合并进 overlay
/// ```
///
/// 本文件只做**第一段**：把表单里的取值变成一份可进候选列表的对象。第二、三段
/// （提审与合并）属治理链路，规格在 `GOV-007` / `GOV-008`，本地 overlay 存储
/// 尚未开工 —— **不在这里留残桩**。
///
/// ## 为什么自建的 id 带 `user:` 前缀
///
/// 候选是**合并**出来的（`mergeByOrigin`，优先级 `user > pack > platform`），
/// 同 id 后者覆盖前者。用户自建的 id 若形如 `src-1`，与包内 id 撞上时会**静默
/// 覆盖掉一条真材料**，而且看不出来。带前缀之后，撞 id 只可能发生在两处自建
/// 之间，而那两处由 [uniqueContentId] 在同一个 `taken` 集合上判重。
///
/// ## 只能自定「配方」
///
/// `SPEC-PLAN-011`：可自定步骤数 / 先后 / 循环 / 每步判据与参数 / `phase` /
/// 是否有 `hint`；**不可**自定执行算子（6 类之外不得新增）、事件类型、SRS 时钟、
/// 进度口径。落到这里就是一个硬约束：[UserMethodDraft] 的步骤只收
/// [MethodStep]，而它的 `operator` 是枚举 —— 想自创算子必须先改枚举，那已经
/// 不是「自建」了。
library;

import '../entities/content.dart';
import '../enums.dart';
import '../json.dart';
import 'applies_to.dart';
import 'method_bundle.dart';

/// 自建 id 的前缀，见文件头。**三段各一个**，避免不同类的自建互相撞号。
const String userSourceIdPrefix = 'user:src:';
const String userSchemeIdPrefix = 'user:sch:';
const String userMethodIdPrefix = 'user:method:';

/// 自建 method 的 bundle id 由 profile id 派生。
///
/// 一份自建只产出一个类型分支（`P-8` 裁定），所以「组合」与「分支」是**一一
/// 对应**的 —— 派生而不另起一个 id 空间，回到重入时只要知道
/// `Plan.methodProfileId` 就能反查是哪一份自建。
String userBundleIdOf(String profileId) => '$profileId#bundle';

/// 造一个没被占用的 id。
///
/// [prefix] 本身可用就用它，否则追加 `-N`。**不用随机数也不用时间戳**：同一份
/// 输入必须给出同一个 id，否则「建了两次」与「改了一次」在事件流里分不开，而
/// 用例也没法断言。
///
/// ⚠️ 起点取 `taken.length` 而不是常数 `2`：`R2` 禁止核心层散落数字字面量，而
/// 「从几开始试」本来也不需要定死 —— 撞了就往后走。
String uniqueContentId(String prefix, Iterable<String> taken) {
  final Set<String> used = taken.toSet();
  if (!used.contains(prefix)) {
    return prefix;
  }
  int n = used.length;
  while (used.contains('$prefix-$n')) {
    n = n + 1;
  }
  return '$prefix-$n';
}

/// 规整 `appliesTo`：**丢掉空值**，并拒绝未认的键。
///
/// 空容器必须丢，不是洁癖：`appliesTo.type = []` 在 [appliesToItem] 里走
/// 「数组取任一命中」，空数组恒不命中 —— 用户在表单里**一个类型都没勾**，本该
/// 读成「不限」，留着空列表会读成「任何类型都不适用」，把全部项筛空。
JsonMap normalizeAppliesTo(JsonMap raw) {
  final JsonMap out = <String, Object?>{};
  for (final MapEntry<String, Object?> entry in raw.entries) {
    if (!appliesToKeys.contains(entry.key)) {
      throw FormatException('`appliesTo` 出现未认的键 `${entry.key}`');
    }
    final Object? value = entry.value;
    if (value == null) {
      continue;
    }
    if (value is List && value.isEmpty) {
      continue;
    }
    out[entry.key] = value;
  }
  return out;
}

/// 造一条自建的源（`SPEC-PLAN-007`）。
///
/// `segments` 恒空：自建的源在**内容绑定**落地前拿不到摘录正文，覆盖率也恒为
/// `0`（绑定关系住在 `Item.sourceRefs`，属内容侧）。这不是留白，是登记 ——
/// 规格修订已如实写明「源的自建在内容绑定落地前只作登记」。
SourceRef buildUserSource({
  required String id,
  required String name,
  required String authorityLevel,
  required String version,
  JsonMap appliesTo = const <String, Object?>{},
}) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('自建的源必须有名字');
  }
  final String ver = version.trim();
  if (ver.isEmpty) {
    throw ArgumentError('自建的源必须有版本号');
  }
  return SourceRef(
    id: id,
    name: trimmed,
    authorityLevel: authorityLevel,
    version: ver,
    segments: const <SourceSegment>[],
    appliesTo: normalizeAppliesTo(appliesTo),
  );
}

/// 造一套自建的体系（`SPEC-PLAN-007`）。
///
/// [nodes] 的顺序**就是**学习次序 —— 体系段选的正是「先学哪个」，所以这里不
/// 排序、不去重之外的任何处理。重复节点去重但**保留首次位置**：同一项在一套
/// 序里出现两次没有意义，而删掉第二次不该改变其余各项的相对次序。
Scheme buildUserScheme({
  required String id,
  required String name,
  required List<String> nodes,
  required String authorityLevel,
}) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('自建的体系必须有名字');
  }
  if (nodes.isEmpty) {
    throw ArgumentError('自建的体系至少要有一项 —— 空序等于没有体系');
  }
  final Set<String> seen = <String>{};
  final List<String> ordered = <String>[
    for (final String node in nodes)
      if (seen.add(node)) node,
  ];
  return Scheme(
    id: id,
    name: trimmed,
    nodes: List<String>.unmodifiable(ordered),
    authorityLevel: authorityLevel,
  );
}

/// 一份自建方法草稿：**一份只覆盖一个类型**（`P-8` 裁定）。
///
/// 为什么不一次填四个类型分支：`PLAN-010` 的「按类型派生」可以由**再建一份**
/// 实现 —— 同名不同型的两份自建会各自成为一个单类型 bundle，用户在 ③ 段选
/// 覆盖最全的那份即可。反过来做成四 tab，是把「按类型派生」提前到了建的时候，
/// 而那时用户还不知道自己要建几份。
class UserMethodDraft {
  const UserMethodDraft({
    required this.id,
    required this.name,
    required this.type,
    required this.steps,
  });

  final String id;
  final String name;
  final ItemType type;
  final List<MethodStep> steps;
}

/// 校验配方（`entity-fields` §一.7 的 ① ② + `SPEC-PLAN-011`）。
///
/// ① 算子在册 —— 由枚举天然保证，不需要运行时检查（想自创算子得先改枚举）。
/// ② **至少一个 `review` 步骤** —— 等价于「至少有一个 `both` 类算子」。全是
///    「读 / 例」的配方**不报错地**绕过遗忘曲线：它跑得通、日志也写、进度也涨，
///    但「学过就忘」不会被任何东西发现。所以放在建的时候拦，而不是事后统计。
/// ③ 全步骤无 `hint` —— **不拦**，只在 ③ 段提示代价（`PlannerPanel` 那条
///    「本方法无提示可给」）。
void validateMethodRecipe(List<MethodStep> steps) {
  if (steps.isEmpty) {
    throw ArgumentError('配方至少要有一个步骤');
  }
  final bool hasReview = steps.any(
    (MethodStep step) => step.effectivePhase != StepPhase.first,
  );
  if (!hasReview) {
    throw ArgumentError(
      '配方至少要有一个「忆 / 练 / 讲 / 做」步骤 —— 全是「读 / 例」会在不报错的'
      '情况下绕过遗忘曲线（entity-fields §一.7 校验 ②）',
    );
  }
}

/// 一份自建方法 → （分支，单类型组合）。
///
/// 两个都返回而不只返回分支：③ 段被选中的是**组合**（`Plan.methodProfileId`
/// 存 bundle 的 id），只给分支的话调用方还得自己现编一个 bundle id —— 那是
/// 第二处「组合怎么造」的知识，迟早与这里不同。
({MethodProfile profile, MethodBundle bundle}) buildUserMethod(
  UserMethodDraft draft,
) {
  final String trimmed = draft.name.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('自建的方法必须有名字');
  }
  validateMethodRecipe(draft.steps);
  final MethodProfile profile = MethodProfile(
    id: draft.id,
    name: trimmed,
    steps: List<MethodStep>.unmodifiable(draft.steps),
    // `appliesTo` 必填（`entity-fields` §7）：一份自建只覆盖一个类型，就写这一个。
    appliesTo: <String, Object?>{'type': draft.type.name},
    origin: CandidateOrigin.user,
  );
  final MethodBundle bundle = MethodBundle(
    id: userBundleIdOf(draft.id),
    name: trimmed,
    origin: CandidateOrigin.user,
    byType: <ItemType, String>{draft.type: draft.id},
  );
  return (profile: profile, bundle: bundle);
}

/// 一份方法组合里**有没有任何 `hint`**（`entity-fields` §一.7 校验 ③）。
///
/// 全无提示时不拦，但要能说出来。判断要落在**组合里所有被指到的分支**上：
/// 只看某一个分支，「这套方法在另一个类型上其实有提示」就会漏。
bool bundleHasAnyHint(MethodBundle bundle, List<MethodProfile> profiles) {
  final Map<String, MethodProfile> byId = <String, MethodProfile>{
    for (final MethodProfile profile in profiles) profile.id: profile,
  };
  for (final String profileId in bundle.byType.values) {
    final MethodProfile? profile = byId[profileId];
    if (profile != null && profile.hasAnyHint) {
      return true;
    }
  }
  return false;
}

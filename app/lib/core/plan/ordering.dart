/// 三段候选的排序键与逆序代价（`SPEC-PLAN-020` / `012` / `013`）。
///
/// ## 三段各用各的键 —— 不能统一
///
/// | 段 | 键 | 方向 |
/// |---|---|---|
/// | 源 | 出处等级 `L0 > L1 > L2 > L4` | 秩小者靠前 |
/// | 体系 | 逆序数 `inversions` | 少者靠前 |
/// | 方法 | `LearnableNode.type` 覆盖率 | 高者靠前 |
///
/// 理由写在 `SPEC-PLAN-020`：方法**没有权威谱系**（`PLAN-009`），强给 L 级就是
/// 编的；体系的好坏是「代价小」，不是「谁说的」；源的好坏恰恰是「谁说的」。
/// 用一个键衡量三种东西，只能靠把其中两种硬塞进第三种的口径里。
///
/// ## 排序不是降权（`SPEC-PLAN-013`）
///
/// 体系按逆序数升序后，「工程路线」这类逆序多的候选会沉到末尾，但它**必须仍在
/// 列表里完整可见**。实现若为「列表干净」把它折叠或置灰，就等于把 `PLAN-012`
/// 的「不禁止」改成了硬禁。本文件只**重排**：输入几个，输出几个。
library;

import '../entities/edge.dart';
import '../entities/method.dart';
import '../entities/node.dart';
import '../entities/scheme.dart';
import '../enums.dart';
import '../graph/precedence.dart';

// ────────────────────────────── 源 ──────────────────────────────

/// 出处等级的正序（`entity-fields` §11 映射表）。
///
/// **`L0`–`L4` 编号已废**：`L` 前缀在项目内撞过三处名（节点层级 / 源等级 /
/// 出处等级）。语义值本身即排序键，所以列表里放枚举而不是字符串。
///
/// 旧实现里 `L3` 不在本表（「未定义、数据中零出现」），新表**有** `reference`
/// —— 枚举既然给了这一档，排序就必须认得它，否则一份 `reference` 级的材料会
/// 被当成未知档排到最后，而它不是坏的，只是少见。
const List<AuthorityLevel> authorityLevelOrder = <AuthorityLevel>[
  AuthorityLevel.official,
  AuthorityLevel.standard,
  AuthorityLevel.textbook,
  AuthorityLevel.reference,
  AuthorityLevel.community,
];

/// 等级的秩：越小越靠前。
///
/// **`null` 与未知等级都排最后，不抛错。** 源那侧 `authority_level` 可空
/// （`kind = catalog` 自带权威，不标等级），而枚举封闭后「未知」理论上不会
/// 命中 —— 兜底留着是防「列表被误删一档」：宁可把那一档排到最后，也不要让它
/// 因为 `-1` 静默跑到第一位去。
int authorityRank(AuthorityLevel? level) {
  if (level == null) {
    return authorityLevelOrder.length;
  }
  final int index = authorityLevelOrder.indexOf(level);
  return index < 0 ? authorityLevelOrder.length : index;
}

// ────────────────────────────── 体系 ──────────────────────────────

/// 一套体系在当前序列下的**代价读数**（`SPEC-PLAN-012`）。
///
/// 逆序的定义：`⪯` 的一条前提边 `from ⪯ to`，在序列里 `to` 排到了 `from`
/// 前面。**只数两端都在序列里的边** —— 一端不在序列里不是「倒置」，是
/// 「那条前置不在这份计划的范围里」，与 `kahnLevels` 忽略缺端点边同一判据。
class SchemeOrderCost {
  const SchemeOrderCost({
    required this.inversions,
    this.firstBlockedStep,
    this.firstBlockedItemName,
  });

  /// 被倒置的**前提边**条数。
  final int inversions;

  /// 最早会卡住的那一步，**1 起计**（`null` = 无逆序）。
  ///
  /// 取所有被倒置边里 `to` 位置最小者：那一步的前置还没学，读到它就卡住。
  final int? firstBlockedStep;

  /// 卡住的那一项的名字（取不到名字时回落到 id）。
  final String? firstBlockedItemName;

  /// `nodes` 是否为 `⪯` 的一个线性扩展。
  bool get isLinearExtension => inversions == 0;

  /// 卡片上那行代价说明（`SPEC-PLAN-012` 的原文举例：
  /// 「本序 4 处逆序，第 3 步会卡在装饰器」）。
  String get display {
    if (isLinearExtension) {
      return '本序无逆序';
    }
    return '本序 $inversions 处逆序，第 $firstBlockedStep 步会卡在 $firstBlockedItemName';
  }
}

/// 算一套体系的逆序代价。
///
/// [nodeById] 只用来把卡住那一步的 id 换成名字；缺项时回落 id，不抛 ——
/// 名字取不到不影响「几处逆序」这个数。
///
/// **只数 `strength == required` 的边**：`recommended` 不构成「前置没学就卡住」
/// —— 建议而已，跳过它不损失可达性。与 `kahnLevels` 同一口径（`⪯` 是
/// `required` 的传递闭包）。
SchemeOrderCost schemeOrderCost({
  required Scheme scheme,
  required Iterable<PrerequisiteEdge> edges,
  required Map<String, Node> nodeById,
}) {
  final Map<String, int> position = <String, int>{
    for (int i = 0; i < scheme.nodes.length; i++) scheme.nodes[i]: i,
  };

  int inversions = 0;
  int? blockedAt;
  String? blockedId;

  for (final PrerequisiteEdge edge in requiredEdgesOf(edges)) {
    final int? fromPos = position[edge.fromId];
    final int? toPos = position[edge.toId];
    if (fromPos == null || toPos == null) {
      continue;
    }
    if (toPos > fromPos) {
      continue;
    }
    inversions += 1;
    // 位置越小越早卡住；同位置时取 id 较小者，让同一份包每次算出的都是同一句。
    if (blockedAt == null ||
        toPos < blockedAt ||
        (toPos == blockedAt && edge.toId.compareTo(blockedId ?? '') < 0)) {
      blockedAt = toPos;
      blockedId = edge.toId;
    }
  }

  return SchemeOrderCost(
    inversions: inversions,
    firstBlockedStep: blockedAt == null ? null : blockedAt + 1,
    firstBlockedItemName: blockedId == null
        ? null
        : (nodeById[blockedId]?.name ?? blockedId),
  );
}

// ────────────────────────────── 方法 ──────────────────────────────

/// 一套方法对参照集合的类型覆盖读数（`SPEC-PLAN-020` 第三行）。
///
/// **分母是本集合里实际出现的类型数，不是恒 4。** α 包的 `python` 空间若一个
/// `tacit` 项都没有，用 4 作分母等于给每套方法凭空扣掉四分之一 —— 那读数不反映
/// 任何事实，只反映分母写死了。
class TypeCoverage {
  const TypeCoverage({required this.covered, required this.total});

  /// 本集合里出现、且该方法有分支的类型。
  final Set<LearnableType> covered;

  /// 本集合里出现过的类型总数。
  final int total;

  int get coveredCount => covered.length;

  double get ratio => total == 0 ? 0 : coveredCount / total;

  String get display => '覆盖 $coveredCount/$total 类';
}

/// 算一套方法对一组节点的覆盖。
TypeCoverage methodTypeCoverage({
  required MethodBundle bundle,
  required Iterable<LearnableNode> nodes,
}) {
  final Set<LearnableType> present = <LearnableType>{
    for (final LearnableNode node in nodes) node.type,
  };
  final Set<LearnableType> covered = <LearnableType>{
    for (final LearnableType type in present)
      if (bundle.profileOf(type) != null) type,
  };
  return TypeCoverage(covered: covered, total: present.length);
}

// ────────────────────────────── 排序 ──────────────────────────────

/// 稳定排序：并列时**保持输入的相对顺序**。
///
/// `List.sort` 不保证稳定，而这里的输入顺序正是 `mergeByOrigin` 刻意保住的
/// 「包声明顺序」—— 一旦被不稳定的排序打乱，同一份包两次运行可能给出不同的
/// 列表，排查时会被当成数据在变。
List<T> stableSorted<T>(List<T> items, int Function(T a, T b) compare) {
  final List<int> order = <int>[for (int i = 0; i < items.length; i++) i];
  order.sort((int a, int b) {
    final int result = compare(items[a], items[b]);
    return result != 0 ? result : a - b;
  });
  return <T>[for (final int i in order) items[i]];
}

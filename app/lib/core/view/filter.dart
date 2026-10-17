/// 筛选表达式（DNF）—— `SPEC-VIEW-019` / `021` / `028` / `032`。
///
/// 一个 `axisFilter` 的语义：**同轴多选取 OR，跨轴取 AND**（`VIEW-021`）。
/// 若同轴也取 AND，由于「一项一轴只取一值」，同轴多选恒为空集 —— 该能力
/// 等于不可用，所以这条不是口味而是唯一自洽的读法。
///
/// 这里只做**可判定的计算**：把 filter 应用到项上、增删一个取值、列出 chip。
/// 不碰界面、不碰 `Locator`（后者负责「输入 → 命中集」，本文件负责
/// 「命中集里筛选类的那条 → 一组可见项」）。
library;

import '../constants.dart';
import '../entities/content.dart';
import '../pack/pack_parse.dart';

/// 轴键 → 允许的取值集合。
///
/// 用 `List` 而不是 `Set`：chip 的显示顺序 = 用户点选的先后（后点的排后面），
/// 用 `Set` 就得再存一份顺序，等于同一件事记两遍。
typedef AxisFilter = Map<String, List<String>>;

/// 空筛选。**空不等于「全不匹配」**，等于「不过滤」。
const AxisFilter emptyAxisFilter = <String, List<String>>{};

/// 一项是否通过筛选。空筛选恒真。
///
/// 某个轴的取值集为空时按「该轴未参与」处理，不按「无值可配」处理 ——
/// 后者会让「点开又点掉」留下一个把全空间筛空的幽灵轴。
bool matchesAxisFilter(Item item, AxisFilter filter) {
  for (final MapEntry<String, List<String>> entry in filter.entries) {
    if (entry.value.isEmpty) {
      continue;
    }
    final String? value = item.sixAxis[entry.key];
    if (value == null || !entry.value.contains(value)) {
      return false;
    }
  }
  return true;
}

/// 加一个取值（已存在则原样返回，不重复加）。
AxisFilter toggleAxisValue(AxisFilter filter, String axisKey, String value) {
  final List<String> current = filter[axisKey] ?? const <String>[];
  if (current.contains(value)) {
    return filter;
  }
  return <String, List<String>>{
    ...filter,
    axisKey: <String>[...current, value],
  };
}

/// 去掉一个取值。轴空了就把整个键删掉 —— 留一个空列表会让 `axisFilter`
/// 里沉淀下「用户碰过但这轴没选」的痕迹，而 ② 的 chips 会数出一个空 chip。
AxisFilter withoutAxisValue(AxisFilter filter, String axisKey, String value) {
  final List<String> current = filter[axisKey] ?? const <String>[];
  if (!current.contains(value)) {
    return filter;
  }
  final List<String> next = current.where((String v) => v != value).toList();
  if (next.isEmpty) {
    final Map<String, List<String>> copy = <String, List<String>>{...filter}
      ..remove(axisKey);
    return copy;
  }
  return <String, List<String>>{...filter, axisKey: next};
}

/// 清空整个轴的筛选（② 上「这一轴全删」）。
AxisFilter withoutAxis(AxisFilter filter, String axisKey) {
  if (!filter.containsKey(axisKey)) {
    return filter;
  }
  final Map<String, List<String>> copy = <String, List<String>>{...filter}
    ..remove(axisKey);
  return copy;
}

/// 一个 chip：轴 + 取值。
class AxisFilterChip {
  const AxisFilterChip({required this.axisKey, required this.value});

  final String axisKey;
  final String value;

  /// 界面上的轴名（「学科」而不是 `subject`）。
  ///
  /// 轴键是给代码看的（`sixAxis` 的键），chip 是给人看的。中文名从常量表取，
  /// 不在界面层另起一份 —— 否则改一条轴的中文名要翻两处。
  String get axisLabel => sixAxisLabels[axisKey] ?? axisKey;
}

/// 展开成 chip 列表。顺序 = **轴序（`sixAxisKeys`）→ 取值点选序**。
///
/// 按轴序而不是按点选先后排轴：跨轴筛选至少两条 chip，若轴序随点选变，
/// 同一组筛选条件在不同操作顺序下会长得不一样，用户没法靠位置记。
List<AxisFilterChip> filterChipsOf(AxisFilter filter) {
  final List<AxisFilterChip> chips = <AxisFilterChip>[];
  for (final String axisKey in sixAxisKeys) {
    for (final String value in filter[axisKey] ?? const <String>[]) {
      chips.add(AxisFilterChip(axisKey: axisKey, value: value));
    }
  }
  // 表里没有的轴（未来的新轴）也照出，不静默吞掉 —— 吞掉的表现是
  // 「筛了但 ② 不显示」，比多一条 chip 难查得多。
  for (final MapEntry<String, List<String>> entry in filter.entries) {
    if (sixAxisKeys.contains(entry.key)) {
      continue;
    }
    for (final String value in entry.value) {
      chips.add(AxisFilterChip(axisKey: entry.key, value: value));
    }
  }
  return chips;
}

/// 通过筛选的项 id 集。`null` = 没有筛选（**调用方按「全显示」处理**）。
///
/// 返回 `null` 而不是全量集合：绘制层拿 `null` 就走原来的全量路径，
/// 不筛也要白造一个 150 元素的集合，是每帧都在做的事。
Set<String>? visibleIdsOf(LoadedPack pack, AxisFilter filter) {
  if (!_hasActiveAxis(filter)) {
    return null;
  }
  return <String>{
    for (final Item item in pack.items)
      if (matchesAxisFilter(item, filter)) item.id,
  };
}

/// 命中数（`②` 的状态栏要显示「筛掉多少」，用户才知道视野窄了）。
int matchedCount(LoadedPack pack, AxisFilter filter) {
  if (!_hasActiveAxis(filter)) {
    return pack.items.length;
  }
  return pack.items
      .where((Item item) => matchesAxisFilter(item, filter))
      .length;
}

/// 某一轴在包里的**全部取值**（`SPEC-VIEW-019` / `020` 的 ⑥ 罗盘据此展开）。
///
/// 取值域只能从内容来，不能写死：六轴的取值随包而变（`subject` 的取值是学科名，
/// 换一本就是另一批），任何「预设选项」都会在第二个包上立刻过时。
///
/// 顺序 = **出现次数降序，同次数按字典序**：
/// - 降序是因为罗盘一屏放得下 5–8 个值，常用的必须在前；
/// - 同次数按字典序是为了两次打开顺序不变 —— 若沿用 `Map` 的插入序，顺序会
///   跟着 `pack.items` 的排列走，换一份同内容的包（不同项序）就换个样。
///
/// 空串按「没声明」处理，不进候选（`VIEW-007`：未声明即不渲染）。
List<String> axisValuesOf(LoadedPack pack, String axisKey) {
  final Map<String, int> counts = <String, int>{};
  for (final Item item in pack.items) {
    final String? value = item.sixAxis[axisKey];
    if (value == null || value.isEmpty) {
      continue;
    }
    counts[value] = (counts[value] ?? 0) + 1;
  }
  final List<String> values = counts.keys.toList(growable: false);
  return values..sort((String a, String b) {
    final int byCount = counts[b]!.compareTo(counts[a]!);
    return byCount != 0 ? byCount : a.compareTo(b);
  });
}

/// 是否至少有一个轴带着取值。
///
/// **不能只看 `filter.isEmpty`**：`{'ability': []}` 不是空 map，但它一个值都
/// 没筛 —— 按「非空」处理会返回一个 150 元素的集合，调用方（绘制层）于是
/// 以为在筛选，而 ② 会数出一个空 chip。
bool _hasActiveAxis(AxisFilter filter) {
  for (final List<String> values in filter.values) {
    if (values.isNotEmpty) {
      return true;
    }
  }
  return false;
}

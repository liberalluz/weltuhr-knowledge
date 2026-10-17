/// 导航记忆 —— `SPEC-VIEW-015`（`returnTo` 快照）与 `SPEC-VIEW-016`（`trail`）。
///
/// 两件事放一个文件，是因为它们回答的是同一个问题：「用户是怎么走到现在这一项
/// 的」。拆开会各存一半答案 —— 快照记「进详情之前在哪」，`trail` 记「详情里经过
/// 了哪几项」，而返回恰好先按 `trail` 退、退完了才用快照。
///
/// ## 为什么快照存 `selector` 不存结果列表
///
/// `VIEW-015` 的原文给了理由：命中集会变。存了结果列表，用户返回时会看到一个
/// 「当时那十条」的列表，而其中一半已经与当前内容包不匹配 —— 一个不会随时间更新
/// 的搜索结果是比没有更糟的东西。存 query，返回时**重算**，列表永远与当下一致。
///
/// ## 为什么 `trail` 丢**最旧**的那端
///
/// 从 A 一路点到 F（`C-21` = 5），返回时用户要的是 E，不是 B。丢最新那端，第一个
/// 「返回」就落空；丢最旧那端，最近 5 步永远在。栈溢出时用户失去的是「最远的那
/// 一步」，而那是他最不可能想回去的地方。
library;

import '../constants.dart';
import '../enums.dart';
import '../json.dart';
import 'filter.dart';
import 'zoom.dart';

/// 进详情前的一帧视图。`VIEW-015` 列的五个字段一一对应。
///
/// 值类：`==` 按字段比 —— 快照是「还原目标」，两个字段都一样的快照还原出同样的
/// 画面，不重写 `==` 会让「有没有变过」只能靠引用比，而引用在每次 `setState`
/// 里都会换。
class ViewSnapshot {
  const ViewSnapshot({
    required this.mode,
    required this.zoomLevel,
    this.selectedItemId,
    this.axisFilter = emptyAxisFilter,
    this.selector,
  });

  /// 从 [ViewState.returnTo] 那种形状还原。
  ///
  /// 缺字段一律报错、不猜默认值：快照是 `setState` 之前亲手存下的，缺字段说明
  /// 存的代码漏了项，猜一个默认值会把 bug 变成「返回后位置有点怪」这种查不动的
  /// 现象。
  factory ViewSnapshot.fromJson(JsonMap json) => ViewSnapshot(
    mode: ViewMode.values.byName(requireString(json, 'mode')),
    zoomLevel: ZoomLevel.values.byName(requireString(json, 'zoomLevel')),
    selectedItemId: optionalString(json, 'selectedItemId'),
    axisFilter: _filterFromJson(json),
    selector: optionalString(json, 'selector'),
  );

  final ViewMode mode;
  final ZoomLevel zoomLevel;
  final String? selectedItemId;
  final AxisFilter axisFilter;

  /// 进详情时**正在搜的词**。`null` = 不是从搜索进来的。
  ///
  /// 返回时按它重开浮层并重算，而不是还原一份旧结果 —— 见文件头。
  final String? selector;

  JsonMap toJson() => <String, Object?>{
    'mode': mode.name,
    'zoomLevel': zoomLevel.name,
    if (selectedItemId != null) 'selectedItemId': selectedItemId,
    'axisFilter': <String, Object?>{
      for (final MapEntry<String, List<String>> entry in axisFilter.entries)
        entry.key: entry.value,
    },
    if (selector != null) 'selector': selector,
  };

  @override
  bool operator ==(Object other) =>
      other is ViewSnapshot &&
      other.mode == mode &&
      other.zoomLevel == zoomLevel &&
      other.selectedItemId == selectedItemId &&
      other.selector == selector &&
      _sameFilter(other.axisFilter, axisFilter);

  /// 必须先排序再算：`==` 是按集合比的（键序、同轴取值顺序都不影响），
  /// 而 `hashCode` 若照 `entries` 的顺序算，两份「相等」的快照会给出两个
  /// hash —— 违反 Dart 的等价约定，表现是 `Set` / `Map` 里同一份快照存两份
  /// 或者查不到。这个 bug 是被「比对相等还要比 hash」的用例抓出来的。
  @override
  int get hashCode {
    final List<String> keys = axisFilter.keys.toList()..sort();
    return Object.hash(
      mode,
      zoomLevel,
      selectedItemId,
      selector,
      Object.hashAll(<Object>[
        for (final String key in keys)
          Object.hash(
            key,
            Object.hashAll(<String>[...?axisFilter[key]]..sort()),
          ),
      ]),
    );
  }
}

/// `axisFilter` 是 `Map<String, List<String>>`，`requireMap` 只给一层。
AxisFilter _filterFromJson(JsonMap json) {
  final Object? raw = json['axisFilter'];
  if (raw == null) {
    return emptyAxisFilter;
  }
  if (raw is! Map) {
    throw const FormatException('字段 `axisFilter` 缺失或类型不符（期望 Map）');
  }
  final AxisFilter filter = <String, List<String>>{};
  for (final MapEntry<Object?, Object?> entry in raw.entries) {
    final Object? key = entry.key;
    final Object? value = entry.value;
    if (key is! String || value is! List) {
      throw const FormatException(
        '字段 `axisFilter` 缺失或类型不符（期望 Map<String, List<String>>）',
      );
    }
    filter[key] = <String>[
      for (final Object? each in value)
        if (each is String)
          each
        else
          throw const FormatException(
            '字段 `axisFilter` 缺失或类型不符（期望 Map<String, List<String>>）',
          ),
    ];
  }
  return filter;
}

/// 两个筛选等价：**键序与同轴取值顺序都不影响结果**。
///
/// 直接 `==` 比会读成「不等」——`Map` 的 `==` 是引用比，而 `toggleAxisValue`
/// 每次都造新 map。按集合比才对应「筛出来的可见集一样」这个真问题。
bool _sameFilter(AxisFilter a, AxisFilter b) {
  final Set<String> keys = <String>{...a.keys, ...b.keys};
  for (final String key in keys) {
    final List<String> left = a[key] ?? const <String>[];
    final List<String> right = b[key] ?? const <String>[];
    if (left.length != right.length) {
      return false;
    }
    if (!left.toSet().containsAll(right)) {
      return false;
    }
  }
  return true;
}

/// 往 `trail` 尾部压一项，超出 `C-21` 时丢最旧的那端。
///
/// **不去重**：A → B → A 是用户真走过两次的路，去重会让「返回」从 A 直接跳到
/// 别处。详情页内部历史学的是「来过这里」，不是「这里在不在集合里」——
/// 那是 `visited` 的语义，不是 `trail` 的。
List<String> pushTrail(List<String> trail, String? itemId) {
  if (itemId == null) {
    return trail;
  }
  final List<String> next = <String>[...trail, itemId];
  if (next.length <= trailCap) {
    return next;
  }
  return next.sublist(next.length - trailCap);
}

/// 退一步：给出上一项与剩下的栈。
///
/// 栈空时 `itemId` 为 `null` —— 调用方据此决定是否改用 `returnTo` 快照。
({String? itemId, List<String> trail}) popTrail(List<String> trail) {
  if (trail.isEmpty) {
    return (itemId: null, trail: const <String>[]);
  }
  return (itemId: trail.last, trail: trail.sublist(0, trail.length - 1));
}

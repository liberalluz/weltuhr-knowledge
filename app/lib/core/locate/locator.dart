/// 定位引擎：把一句输入变成「命中集 + 三态」。
///
/// 唯一一个引擎，宇宙 / 树 / 详情 / 搜索是**同一份数据的四种投影**
/// （`SPEC-FND-009`）—— 所以这里不出渲染信息、不关心结果画在哪，只给 id
/// 与命中的原文。幂等的纯计算：同一份包 + 同一句输入，结果永远一致。
///
/// 三处判据的选择都在下面逐条写了理由，因为它们各自与一处 spec 的字面读法
/// 不同，选错会让整个视图层的行为歪掉。
library;

import '../entities/content.dart';
import '../pack/pack_parse.dart';

/// 定位三态（`SPEC-FND-008`）：衡量的只是「定位成没成」。
///
/// 与「无命中四类分诊」（`SPEC-VIEW-030`）**正交**：三态说成没成，
/// 分诊说没成之后怎么办。引擎不碰分诊。
enum LocateState { located, partial, none }

/// 匹配强度（`SPEC-VIEW-029` 主排序键）：精确 > 前缀 > 模糊。
///
/// **模糊 = 子串包含**。相似度阈值 `C-28` 至今未裁定（`TbdConstantError`），
/// 所以这里既不读它、也不假装有它 —— 首期只做「包含」，等 `C-28` 有值
/// 再换实现，届时 `MatchStrength.fuzzy` 的判定是唯一要改的一行。
enum MatchStrength { exact, prefix, fuzzy }

/// 命中档位（`SPEC-VIEW-029` 次排序键）+ 筛选类（`SPEC-VIEW-028`）。
///
/// 声明顺序就是档位顺序：空间 > 域 > 项。`axis` 排在最后 —— 它不是落点，
/// 是筛选（只写 `axisFilter`，不换根）。
enum LocateKind { space, domain, item, axis }

/// 一条命中。
class LocateHit {
  const LocateHit({
    required this.kind,
    required this.target,
    required this.label,
    required this.strength,
    this.axisKey,
    this.inScope = true,
  });

  final LocateKind kind;

  /// 落点类 = 目标 id（空间 / 域 / 项 id）；筛选类 = 轴取值。
  final String target;

  /// 命中的**原文**（空间名 / 域名 / 标题 / 轴值）。
  ///
  /// 引擎只回传原文，不做「取 id 尾段」「加粗命中词」这类打扮 —— 那是视图的事，
  /// 混进引擎就会变成第二处文案事实源。
  final String label;

  final MatchStrength strength;

  /// 仅筛选类：轴键（`subject` / `ability` …）。落点类为 `null`。
  final String? axisKey;

  /// 这一条**能不能直接落点**。只有项命中可能是 `false` —— `Item.inScope` 为
  /// `false` 的项（圈外邻项）在库里、在树里（虚线支线，`VIEW-007`）都有，
  /// 但宇宙只画圈内，跳到它就是跳到一片空白。
  ///
  /// 于是它在 `hits` 里、却进不了 `usableHits`：存在性归引擎，可用性归分诊
  /// （`VIEW-030` 类 ①「项存在但属圈外 → 申请纳入」）。
  final bool inScope;
}

/// 一次定位的结果。
class LocateResult {
  const LocateResult({
    required this.query,
    required this.hits,
    required this.state,
  });

  final String query;

  /// 已按「可用 → 强度 → 档位 → id」排好序。
  final List<LocateHit> hits;

  final LocateState state;

  /// 能直接落点的那些命中（`LocateHit.inScope` 为 `true`）。
  ///
  /// 视图列的就是这一份；`hits` 里余下的圈外项只在分诊里出现（`VIEW-030` ①）。
  List<LocateHit> get usableHits =>
      hits.where((LocateHit hit) => hit.inScope).toList(growable: false);

  /// 「没成」 —— 判的是**有没有能落点的**，不是 `hits` 空不空。
  bool get isEmpty => usableHits.isEmpty;

  /// 最强的那一条（`located` 时即落点）。
  LocateHit? get top {
    final List<LocateHit> usable = usableHits;
    return usable.isEmpty ? null : usable.first;
  }
}

/// 定位引擎。
class Locator {
  const Locator(this._pack);

  final LoadedPack _pack;

  /// 定位。
  ///
  /// 匹配面严格限定 `C-27` 的五项（`SPEC-VIEW-025`：**不扩 schema**）：
  /// `Item.title` · `Item.domainId` · `Space.name` · `Item.sixAxis` 取值 ·
  /// `Scheme.nodes`。别名与拼音延后。
  LocateResult locate(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      // 空输入不是「搜不到」：没有输入就没有定位结果，也不该触发四类分诊。
      return LocateResult(
        query: query,
        hits: const <LocateHit>[],
        state: LocateState.none,
      );
    }

    final Map<String, LocateHit> best = <String, LocateHit>{};

    void consider(
      LocateKind kind,
      String target,
      String label, {
      String? axisKey,
      bool inScope = true,
    }) {
      final MatchStrength? strength = _match(label, needle);
      if (strength == null) {
        return;
      }
      final String key = '${kind.name}|${axisKey ?? ''}|$target';
      final LocateHit? known = best[key];
      // 同一目标被多处命中（如标题与 `scheme.nodes` 的 id 都中）只留最强那条。
      if (known != null && known.strength.index <= strength.index) {
        return;
      }
      best[key] = LocateHit(
        kind: kind,
        target: target,
        label: label,
        strength: strength,
        axisKey: axisKey,
        inScope: inScope,
      );
    }

    consider(LocateKind.space, _pack.space.id, _pack.space.name);
    for (final String domainId in _pack.space.domainIds) {
      consider(LocateKind.domain, domainId, domainId);
    }
    for (final Item item in _pack.items) {
      consider(LocateKind.item, item.id, item.title, inScope: item.inScope);
      for (final MapEntry<String, String> axis in item.sixAxis.entries) {
        consider(LocateKind.axis, axis.value, axis.value, axisKey: axis.key);
      }
    }
    for (final Scheme scheme in _pack.schemes) {
      for (final String nodeId in scheme.nodes) {
        // 体系的节点可能就是圈外项的 id：`inScope` 要与项命中的判法一致，
        // 否则同一个项会在这里被当成「可用」。
        consider(
          LocateKind.item,
          nodeId,
          nodeId,
          inScope: _pack.itemOf(nodeId)?.inScope ?? true,
        );
      }
    }

    final List<LocateHit> hits = best.values.toList()..sort(_compare);
    return LocateResult(query: query, hits: hits, state: _stateOf(hits));
  }

  /// 三态判在**最强匹配强度那一档**上。
  ///
  /// 为什么不是「命中集总数」：α 包里有 `装饰器`（精确）与 `装饰器参数`（子串）
  /// 这样的一对。按总数判就是「多命中 → 给候选列表」，可用户打的是
  /// **完整标题**，`SPEC-VIEW-027` 明确「唯一命中直接跳转」—— 让他在列表里
  /// 再点一次，是把引擎的保守当成了产品行为。按最强档判，`装饰器` 唯一精确命中
  /// ⇒ 直接落点；弱一档的那条仍在 `hits` 里，视图要在无命中的分诊里才用得到。
  ///
  /// 判在 `usableHits` 上：只命中圈外项时三态是 `none`（**没成**），而「为什么
  /// 没成」归分诊 —— 见 [LocateHit.inScope]。
  LocateState _stateOf(List<LocateHit> hits) {
    final List<LocateHit> usable = hits
        .where((LocateHit hit) => hit.inScope)
        .toList(growable: false);
    if (usable.isEmpty) {
      return LocateState.none;
    }
    final MatchStrength strongest = usable.first.strength;
    final List<LocateHit> top = usable
        .where((LocateHit hit) => hit.strength == strongest)
        .toList(growable: false);
    if (top.length > 1) {
      return LocateState.partial;
    }
    // 唯一命中但不是「项」：命中上层（空间 / 域）按 `SPEC-FND-008` 归部分命中；
    // 轴值是筛选类，只写 `axisFilter`、不换根（`SPEC-VIEW-028`），
    // 也就没有「直接落点」这回事。
    return top.single.kind == LocateKind.item
        ? LocateState.located
        : LocateState.partial;
  }

  /// 排序：**可用优先**，再强度、再档位、再 id。
  ///
  /// 可用优先是分诊的地基：一个圈外项精确命中、一个圈内项前缀命中时，用户要的
  /// 是后者 —— 前者跳出屏幕外（宇宙只画圈内）。放在同一把排序键里，`top` 才
  /// 无需再判一次，也就不会出现「`top` 与列表首行不是同一条」。
  int _compare(LocateHit a, LocateHit b) {
    if (a.inScope != b.inScope) {
      return a.inScope ? -1 : 1;
    }
    final int byStrength = a.strength.index.compareTo(b.strength.index);
    if (byStrength != 0) {
      return byStrength;
    }
    final int byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) {
      return byKind;
    }
    return a.target.compareTo(b.target);
  }

  /// `SPEC-VIEW-029` 的第三键「未学优先」**未实现**：它要掌握度，而掌握度由
  /// `fold(events, asOf)` 派生（`SPEC-FND-010`），`B6` 之前没有这个输入。
  /// 不塞假数据替代 —— 排序少了第三键只是并列时顺序不同，塞错会变成
  /// 「已学的排在前面」而没人看得出来。
  MatchStrength? _match(String label, String needle) {
    final String value = label.toLowerCase();
    if (value == needle) {
      return MatchStrength.exact;
    }
    if (value.startsWith(needle)) {
      return MatchStrength.prefix;
    }
    if (value.contains(needle)) {
      return MatchStrength.fuzzy;
    }
    return null;
  }
}

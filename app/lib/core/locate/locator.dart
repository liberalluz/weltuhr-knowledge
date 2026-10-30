/// 定位引擎：把一句输入变成「命中集 + 三态」。
///
/// 唯一一个引擎，宇宙 / 树 / 详情 / 搜索是**同一份数据的四种投影**
/// （`SPEC-FND-009`）—— 所以这里不出渲染信息、不关心结果画在哪，只给 id
/// 与命中的原文。幂等的纯计算：同一份包 + 同一句输入，结果永远一致。
///
/// 三处判据的选择都在下面逐条写了理由，因为它们各自与一处 spec 的字面读法
/// 不同，选错会让整个视图层的行为歪掉。
///
/// ## 一组的包，一个作用域
///
/// `SPEC-VIEW-031` 要两种覆盖面：`Z0` 搜全部、`Z1` 内只搜本包。入参因此是
/// 「装进内存的全部包」+ 可选作用域 —— 收单包的写法只能表达后者，而前者迟早
/// 要改签名。
///
/// **旧的「空间」概念已由 `Pack` 取代**（`ADR-0005` §影响一：`KnowledgeSpace`
/// → `Pack`），所以「一个空间」在这里读作「一个包」：`Pack.pluginId` 永久唯一，
/// 正是跨包去重与展示前缀需要的那个键。视图层那行「在全部空间中搜索」的
/// **文案没有跟着改** —— 它是 `VIEW-031` 的原文，而 `SPEC-VIEW-*` 整片待
/// `ADR-0005` §影响二 之后重写；代码先按新本体走，词等 spec 定了再统一。
///
/// 作用域只影响**搜哪几个包**，不影响任何判据：三态、排序、可用性都还在
/// 同一份逻辑里。这也意味着「跨包」不需要第二套引擎。
library;

import '../constants.dart';
import '../entities/node.dart';
import '../entities/scheme.dart';
import '../enums.dart';
import '../graph/in_scope.dart';
import '../graph/parent_index.dart';
import '../pack/pack_reader.dart';

/// 定位三态（`SPEC-FND-008`）：衡量的只是「定位成没成」。
///
/// 与「无命中四类分诊」（`SPEC-VIEW-030`）**正交**：三态说成没成，
/// 分诊说没成之后怎么办。引擎不碰分诊。
enum LocateState { located, partial, none }

/// 匹配强度（`SPEC-VIEW-029` 主排序键）：精确 > 前缀 > 模糊。
///
/// **模糊 = 子串包含**。`C-28` 已于 2026-10-18 裁定为「v0.1 不适用」，即首期
/// **不设相似度阈值** —— 那一档只参与三档排序，不是召回门槛。给这一档加阈值
/// 的方向只有一个：用户已经打出连续的一段字，却因为「相似度不够」被告知没
/// 找到。将来若真做编辑距离，`_match` 的最后一步是唯一要改的地方。
enum MatchStrength { exact, prefix, fuzzy }

/// 命中档位（`SPEC-VIEW-029` 次排序键）+ 筛选类（`SPEC-VIEW-028`）。
///
/// 声明顺序就是档位顺序：根 > 域 > 项。`axis` 排在最后 —— 它不是落点，
/// 是筛选（只写 `axisFilter`，不换根）。
enum LocateKind { space, domain, item, axis }

/// 一条命中。
class LocateHit {
  const LocateHit({
    required this.kind,
    required this.target,
    required this.label,
    required this.strength,
    required this.packId,
    required this.packName,
    this.axisKey,
    this.inScope = true,
  });

  final LocateKind kind;

  /// 落点类 = 目标 id（节点 id / 包 id）；筛选类 = 轴取值。
  final String target;

  /// 命中的**原文**（包名 / 节点名 / 轴值）。
  ///
  /// 引擎只回传原文，不做「取 id 尾段」「加粗命中词」这类打扮 —— 那是视图的事，
  /// 混进引擎就会变成第二处文案事实源。
  final String label;

  final MatchStrength strength;

  /// 这条命中**属于哪个包**（`SPEC-VIEW-031` 起命中集可跨包）。
  ///
  /// 不给它的话，两个包里同名的节点在命中集里长得一模一样，而 `target` 是
  /// 包内唯一的 id —— 跨包撞 id 时连去重都会把它们并成一条。
  /// 取值来自 `Pack.pluginId`（**永久唯一、不可复用**，`entity-fields` §1），
  /// 不像包名那样可以重。
  final String packId;

  /// 包名，供结果行写前缀（`SPEC-VIEW-033`）。取值来自 `Pack.name`。
  final String packName;

  /// 仅筛选类：轴键（`discipline` / `major` / `occupation`）。落点类为 `null`。
  final String? axisKey;

  /// 这一条**能不能直接落点**。只有节点命中可能是 `false` —— 不在
  /// `subtreeRoot` 子树下的节点（圈外邻项）在库里、在树里（虚线支线，
  /// `VIEW-007`）都有，但宇宙只画圈内，跳到它就是跳到一片空白。
  ///
  /// 于是它在 `hits` 里、却进不了 `usableHits`：存在性归引擎，可用性归分诊
  /// （`VIEW-030` 类 ①「项存在但属圈外 → 申请纳入」）。
  ///
  /// **`inScope` 是派生值，不是字段**（`ADR-0007` 决策 2）：同一节点在不同
  /// `Plan.subtree_root` 下取值不同，存下来必然出现两份真相。这里存的是
  /// **算好的结果**，不是可以被再次解释的判据 —— 判据只有
  /// [`inScopeOf`](../graph/in_scope.dart) 一处。
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
///
/// ## 为什么收的是「一组包」而不是一个包
///
/// `SPEC-VIEW-031`：`Z0` 下搜全部（它本就是跨包视角），`Z1` 内默认只搜本包。
/// 两件事都要能表达，于是引擎的入参是**已经装进内存的全部包** + 一个可选的
/// 作用域。收单个包的写法只能表达后者，而前者要改函数签名 —— 迟早要改，
/// 不如一开始就收一组。
///
/// 这也顺带吃掉了旧 `LoadedPack` 那一层：包自带身份（`PackContent.pack`），
/// 再包一个「装载记录」只是把 `name` 抄第二遍。
class Locator {
  const Locator(this.packs, {this.pluginId, this.subtreeRoot, this.parents});

  /// 只有一个包时的退化写法：此刻「全部包」就等于「本包」。
  Locator.single(PackContent pack, {String? subtreeRoot, ParentIndex? parents})
    : this(<PackContent>[pack], subtreeRoot: subtreeRoot, parents: parents);

  /// 装进内存的全部包。空列表是合法的（返回空命中集，不抛）。
  final List<PackContent> packs;

  /// 作用域：只搜这个包。`null` = 全部包（`SPEC-VIEW-031`）。
  ///
  /// 传进来的 id 不在 [packs] 里时结果为空，顺序与集合不匹配时**不**放宽成
  /// 「全部包」—— 静默放宽会让「本包没搜到」变成「全部包没搜到」，
  /// 而这两种结论对用户的含义完全不同。
  final String? pluginId;

  /// 圈定范围的根。`null` = 不判圈内（每条命中都算可用）。
  ///
  /// 跨包搜索时它只对本包有意义 —— 别的包的树根不可能出现在这个子树下，
  /// 硬传会让所有跨包命中都被判成「圈外」。所以可空，且由调用方决定给不给。
  final String? subtreeRoot;

  /// 判圈内用的父链索引。`null` = 各包拿自己的 [PackContent.parents]。
  ///
  /// ## 为什么必须能换
  ///
  /// `PackContent.parents` 只装本包父边，父链到骨架节点就断；而树是跨包的
  /// （载荷域挂骨架星）。拿单包索引配一个**骨架**根判圈内，载荷项永远上溯不
  /// 到根，于是整片被判「圈外」—— 那不是数据在圈外，是索引少了那一段。
  ///
  /// 跨包合并表由 `TreeIndex.parents` 给（与 `packsUnderRoot` 同一张表）。
  /// 不给时退回单包索引：单包场景（详情页邻项）本来就是包内的，行为不变。
  final ParentIndex? parents;

  /// 定位。
  ///
  /// 匹配面严格限定 `C-27` 的四项，**不扩 schema**（`SPEC-VIEW-025`）：
  /// `Node.name` · `Node.axis` 取值 · `Pack.name` · `Scheme.nodes`。
  /// 别名与拼音延后。
  ///
  /// ⚠️ **节点 id 也算命中**，它不是第五个字段，而是 `Scheme.nodes` 那一项的实现
  /// 形态：体系里存的本来就是 id，要按体系查就必须拿 id 比。既然要有这一条，
  /// 就一并让每个节点都按自己的 id 参与 —— 否则「体系里列了的项可以按 id 搜、
  /// 没列的不能」会成为一条没人说得清来历的差别。**轴键名（`major`）不在匹配面**：
  /// 轴只按中文值（「专业」）命中，那是用户看得见的写法。
  ///
  /// 旧的 `Item.domainId` 没有了 —— 它的角色由「域节点的名字」顶上：
  /// `group` / `galaxy` / `cluster` 三个槽位就是原来的「门类 / 类 / 中类」。
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

    final String? scope = pluginId;
    final Iterable<PackContent> searched = scope == null
        ? packs
        : packs.where((PackContent pack) => pack.pack.pluginId == scope);

    final Map<String, LocateHit> best = <String, LocateHit>{};

    for (final PackContent pack in searched) {
      // 不用 `pluginId` 作局部名：它与本类的 `pluginId`（作用域）同名，读代码时
      // 两个东西会混成一件。
      final String hitPackId = pack.pack.pluginId;
      final String hitPackName = pack.pack.name;

      bool nodeInScope(Node node) {
        final String? root = subtreeRoot;
        if (root == null) {
          return true;
        }
        // 跨包索引优先：单包索引在包边界断链，而圈定根常在骨架里、命中常在
        // 载荷里 —— 用错那一份会把整片子树的项判成圈外。
        return inScopeOf(
          node,
          subtreeRoot: root,
          parents: parents ?? pack.parents,
        );
      }

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
        // 去重键必须带包：`target` 只在包内唯一，跨包撞 id 时同一把键
        // 会把两条命中并成一条（用户会看到「只有一个包有」）。
        final String key = '$hitPackId|${kind.name}|${axisKey ?? ''}|$target';
        final LocateHit? known = best[key];
        // 同一目标被多处命中（如节点名与 `scheme.nodes` 的 id 都中）只留最强那条。
        if (known != null && known.strength.index <= strength.index) {
          return;
        }
        best[key] = LocateHit(
          kind: kind,
          target: target,
          label: label,
          strength: strength,
          packId: hitPackId,
          packName: hitPackName,
          axisKey: axisKey,
          inScope: inScope,
        );
      }

      /// 一个节点贡献的落点命中：**名字与 id 各算一条**，去重键相同故只留最强。
      ///
      /// id 也是可搜的：`C-27` 的 `scheme.nodes` 一项命中的就是 id，而骨架 id
      /// 里带官方码（`skeleton:major/080901`）—— 用户手里常常只有那个码。
      void considerNode(LocateKind kind, Node node) {
        final bool scoped = nodeInScope(node);
        consider(kind, node.id, node.name, inScope: scoped);
        consider(kind, node.id, node.id, inScope: scoped);
      }

      consider(LocateKind.space, pack.pack.pluginId, pack.pack.name);
      for (final Node node in pack.nodes) {
        final LocateKind? kind = locateKindOf(node);
        if (kind != null) {
          considerNode(kind, node);
        }
        // 轴命中：三轴单值，所以一个节点最多贡献一条。
        consider(
          LocateKind.axis,
          node.axis.name,
          axisLabels[node.axis]!,
          axisKey: node.axis.name,
        );
      }
      for (final Scheme scheme in pack.schemes) {
        for (final String nodeId in scheme.nodes) {
          final Node? node = pack.nodeOf(nodeId);
          if (node != null) {
            // 已在上面按自己的档位命过 —— 再算一遍会多出一条「同名但档位不同」
            // 的命中（域 id 写进体系时尤其明显），用户看到两条指向同一个地方。
            continue;
          }
          // 包外引用（跨包体系）：`inScope` 判不了父链，只能算可用 —— 判成圈外
          // 会让「体系里写着、包里没有」的东西既搜得到又点不动。
          consider(LocateKind.item, nodeId, nodeId);
        }
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
  ///
  /// 跨包命中集下这条判据不用改：两个包各有一处精确命中时 `top.length == 2`
  /// ⇒ `partial`，用户确实要在两条之间选一次。
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
    // 唯一命中但不是「项」：命中上层（轴根 / 包 / 域）按 `SPEC-FND-008` 归部分
    // 命中；轴值是筛选类，只写 `axisFilter`、不换根（`SPEC-VIEW-028`），
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
    final int byTarget = a.target.compareTo(b.target);
    if (byTarget != 0) {
      return byTarget;
    }
    // 同 id 跨包：最后按包 id 定序。跨包命中集里这是唯一能同时满足
    // 「与输入顺序无关」和「两次查询顺序一致」的收尾键。
    return a.packId.compareTo(b.packId);
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

/// 一个节点在定位里算哪一档；`null` = 不参与落点（轴值仍单独算一条）。
///
/// 放在**引擎里**而不让视图各判一次：档位直接决定排序与三态（[Locator._stateOf]
/// 只把 `item` 判成 `located`），判据散出去就会出现「搜索里算域、树里算项」
/// 这种两处不一致，而它不会抛异常，只会让同一个词在两处跳到不同地方。
LocateKind? locateKindOf(Node node) {
  if (node is LearnableNode) {
    return LocateKind.item;
  }
  return switch (node.levelSlot) {
    // 轴根就是旧的「空间」档：点它换的是整棵树，不是某一段。
    LevelSlot.supercluster => LocateKind.space,
    // 「域」= 门类 / 类 / 中类三档。
    LevelSlot.group ||
    LevelSlot.galaxy ||
    LevelSlot.cluster => LocateKind.domain,
    // 恒星归「项」：它是骨架里唯一能直接落到的东西 —— 官方目录最细的正式
    // 条目，是内容本身而不是分类容器。
    LevelSlot.star => LocateKind.item,
    // 行星系是恒星与行星之间的载荷容器，停在那里没有可看的内容。
    // `planet` 走不到这里（它恒为 `LearnableNode`，上面已返回），列出只为穷尽。
    LevelSlot.system || LevelSlot.planet => null,
  };
}

/// 无命中的四类分诊（`SPEC-VIEW-030`）与表单兜底的前置判据（`SPEC-VIEW-032`）。
///
/// ## 为什么分诊在 `core/` 而不在浮层里
///
/// 判断「措辞不同」要把用户输入与每一项的名字做片段比对 —— 那需要遍历节点。
/// 放在 `features/locate/` 里就是视图层读实体做业务判断，`R1` 会拦；而这道判据
/// 迟早要出现在第二处（树里搜不到也要分诊），写两遍就会分叉成两套「像不像」。
///
/// ## 四类的**顺序**本身就是判据
///
/// | 类 | 判据 | 为什么排这个位置 |
/// |---|---|---|
/// | ① 圈外 | 命中了项，但那些项 `inScope == false` | 最确定的一条事实：东西在库里，只是不在圈内。有它就轮不到「换词」 |
/// | ② 措辞不同 | 一项都没命中，但有共享片段的圈内项 | 比 ③/④ 强：库里大概有这么个东西，只是叫法不同 |
/// | ③ 域内没有 | ② 也没有，且**知道该放哪个域** | 知道往哪放才谈得上「新增」 |
/// | ④ 全空间没有 | ② 也没有，且**不知道该放哪个域** | 什么都不知道，就只能记个信号 |
///
/// ## ③ 与 ④ 的分野是「有没有域上下文」，不是「搜了多大范围」
///
/// 规格说 ③ 的出口是「新增项（提交审核）」、④ 的出口是「只记需求信号，不承诺」。
/// 两者的差别不在找得有多深 —— 一次定位查的永远是整个包 —— 而在**新项该挂到哪**：
/// 有域上下文（用户已经站在某个域里）⇒ 能填表；没有（还在 `Z1` 上看星系）⇒
/// 替他挑一个域比不挑更糟，只能是④。
///
/// ## 新增入口的闸门
///
/// `VIEW-030` 末句：新增入口只能挂在「已给过邻近候选且用户明确说都不对」之后。
/// 所以本模块**从不**直接返回表单所需的全部信息并让视图立刻弹表单 —— 视图必须
/// 先经过 [DiagnoseClass.differentWording] 的候选列表与一个「都不对」，或者根本没
/// 有候选可给。分诊只回答「是哪一类」，不回答「要不要现在弹表单」。
library;

import '../constants.dart';
import '../entities/node.dart';
import '../graph/in_scope.dart';
import '../pack/pack_reader.dart';
import 'locator.dart';

/// 无命中的四种事实（`SPEC-VIEW-030`）。
enum DiagnoseClass {
  /// ① 项存在但属圈外 —— 出口是「申请纳入」，不是跳转。
  outOfScope,

  /// ② 项存在，措辞不同 —— 出口是邻近候选 / 换词。
  differentWording,

  /// ③ 域内确实没有 —— 出口是新增项（提交审核）。
  absentInDomain,

  /// ④ 整个空间都没有 —— 出口是只记需求信号，不承诺。
  absentInSpace,
}

/// 一条邻近候选：**没命中**，但和输入共享片段。
///
/// 不复用 [LocateHit]：那条类型的意思里有 `strength`（命中强度），而这里的东西
/// 恰恰是**没命中**的。借用会让「强度」字段开始撒谎，而下一个读代码的人会照着
/// 它写排序。
class NearItem {
  const NearItem({
    required this.nodeId,
    required this.name,
    required this.overlap,
  });

  final String nodeId;

  final String name;

  /// 与输入共享的片段数 —— **排序依据，不是阈值**：只要有共享就算候选，
  /// 多与少的差别只体现在先后上。`C-28` 管的是「命中」的模糊阈值（且 v0.1
  /// 已裁定不适用）；这里是「没命中之后找相似」，两件事不共用一条线
  /// （见 `C-43`）。
  final int overlap;
}

/// 一次分诊的结论。
class LocateDiagnosis {
  const LocateDiagnosis({
    required this.kind,
    this.outside = const <LocateHit>[],
    this.near = const <NearItem>[],
    this.domainId,
  });

  final DiagnoseClass kind;

  /// 仅类 ①：命中的圈外项（好让界面说得出「库里有「元类」，但不在圈内」）。
  final List<LocateHit> outside;

  /// 仅类 ②：邻近候选，已按共享片段数降序（同分按名字）。
  final List<NearItem> near;

  /// 仅类 ③：新增项该挂到的域（结构节点 id）。
  final String? domainId;
}

/// 分诊。
///
/// 返回 `null` = **不需要分诊**，有两种情形：
/// - 输入为空：没有输入就没有「搜不到」，弹分诊会让空输入看起来像失败；
/// - 已经有能落点的命中：[LocateResult.isEmpty] 为 `false`，那是正向路径。
///
/// [domainId] 是当前视图的域上下文（用户在哪个域里），只影响 ③ 与 ④ 的分野。
///
/// [subtreeRoot] 与 `Locator` 同口径：`null` = 不判圈内（每条候选都算圈内）。
/// 两个参数必须一起传 —— 定位时说「这一条在圈外」、分诊时又说「圈内没有相近的
/// 项」，用的若是两个不同的根，结论会自相矛盾。
LocateDiagnosis? diagnose({
  required PackContent pack,
  required LocateResult result,
  String? domainId,
  String? subtreeRoot,
}) {
  if (result.query.trim().isEmpty) {
    return null;
  }
  if (!result.isEmpty) {
    return null;
  }

  final List<LocateHit> outside = result.hits
      .where((LocateHit hit) => hit.kind == LocateKind.item && !hit.inScope)
      .toList(growable: false);
  if (outside.isNotEmpty) {
    return LocateDiagnosis(kind: DiagnoseClass.outOfScope, outside: outside);
  }

  final List<NearItem> near = nearItemsOf(
    pack,
    result.query,
    subtreeRoot: subtreeRoot,
  );
  if (near.isNotEmpty) {
    return LocateDiagnosis(kind: DiagnoseClass.differentWording, near: near);
  }

  if (domainId != null) {
    return LocateDiagnosis(
      kind: DiagnoseClass.absentInDomain,
      domainId: domainId,
    );
  }
  return const LocateDiagnosis(kind: DiagnoseClass.absentInSpace);
}

/// 邻域候选：圈内项里与 [query] 共享片段的那些，按共享片段数降序。
///
/// **只看圈内项**：圈外的相似项帮不上「换词」—— 它列出来也只能申请纳入，
/// 而那是类 ① 的出口，已经在前面判过了。
///
/// 只收**项档**（`LocateKind.item`），不收域与轴根：域是容器，把它列进「你要找的
/// 是不是这个」会把用户带到一片还没下钻的空树；而轴取值是筛选类，命中了就走
/// 不到这里，在这里扩面只会让「最接近的」被一堆同轴的项占满。
///
/// 只比对**名字**：`C-27` 的匹配面里有轴取值与域，但那些是「这个词是不是某个
/// 轴值」的判定，在这里扩面同样是噪音 —— 用户要找的是**一个东西**。
List<NearItem> nearItemsOf(
  PackContent pack,
  String query, {
  String? subtreeRoot,
}) {
  final Set<String> wanted = _gramsOf(query);
  if (wanted.isEmpty) {
    // 一个字（或一个字母）连片段都构不成：此时任何「像不像」都是猜，
    // 猜错的代价是把用户引到一个毫不相干的地方，不如不给候选（退到 ③/④）。
    return const <NearItem>[];
  }

  final List<NearItem> found = <NearItem>[];
  for (final Node node in pack.nodes) {
    if (locateKindOf(node) != LocateKind.item) {
      continue;
    }
    final String? root = subtreeRoot;
    if (root != null && !inScopeOf(node, subtreeRoot: root, parents: pack.parents)) {
      continue;
    }
    final int overlap = _gramsOf(node.name).intersection(wanted).length;
    if (overlap == 0) {
      continue;
    }
    found.add(NearItem(nodeId: node.id, name: node.name, overlap: overlap));
  }
  found.sort((NearItem a, NearItem b) {
    final int byOverlap = b.overlap.compareTo(a.overlap);
    if (byOverlap != 0) {
      return byOverlap;
    }
    return a.name.compareTo(b.name);
  });
  return List<NearItem>.unmodifiable(found);
}

/// 只留字母、数字与东亚文字，再取定长片段。
///
/// 标点与空白的处理必须是**两个都抹掉再切**：抹一边时「装饰器 参数」会切出
/// 「器 」这种跨空白的片段，而标题里没有那个空格 —— 明明是同一个词，却因为
/// 一个空格变成零重合。
final RegExp _wordRune = RegExp(
  r'[0-9a-z\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7af]',
);

Set<String> _gramsOf(String value) {
  final String flat = _wordRune
      .allMatches(value.toLowerCase())
      .map((RegExpMatch match) => match[0]!)
      .join();
  final Set<String> grams = <String>{};
  for (int i = 0; i < flat.length; i++) {
    final int end = i + locateNearGramSize;
    if (end > flat.length) {
      break;
    }
    grams.add(flat.substring(i, end));
  }
  return grams;
}

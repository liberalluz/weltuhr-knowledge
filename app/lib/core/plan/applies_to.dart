/// `appliesTo` 的匹配器 —— 一条方法候选「适不适用于这个节点」。
///
/// ## 两个形状，不是一个
///
/// `entity-fields` 里叫 `appliesTo` 的字段有**两处**，键集不同，别混：
///
/// | 位置 | 形状 | 谁判 |
/// |---|---|---|
/// | `SourceRef.appliesTo`（§11） | `{axes[], node_scope[]}`，两键**都必填** | 解析层 [`SourceAppliesTo`](../entities/source.dart) 用 `requireStringList` 强制；语义过滤（`nodeScope ∩ 子树`）归候选装载 |
/// | `MethodProfile.appliesTo`（§12） | `{type, axes, layer}`，**均可省**，省 = 不限 | 本文件 [`appliesToNode`] |
///
/// 源那一侧不在这里判：它的过滤依据是「`node_scope` 与计划子树的交集」，
/// 需要子树集合，而本文件的入参只有一个节点。
///
/// ## 为什么 `spaceId` / `sixAxis` 不在册
///
/// `spaceId` 随「一空间一包已废」（`entity-fields` §11 附注）失效，
/// `sixAxis` 随 `ADR-0005` 六轴降为「三条容器轴 + 四类标签」失效。两者都
/// **落进「未认的键 ⇒ 抛错」**，不静默忽略：静默忽略一个新键（或一个废键），
/// 等于让作者以为约束生效了，而实际没有任何一处会检查它。
///
/// ⚠️ **本函数当前没有生产调用方**（`B13a` 笔 5c-1 如实登记）。生产里的源过滤
/// 是 `candidates.dart` 的私有 `_spaceAllows`，而它只查已废的 `spaceId`。
/// 接线点是那里：笔 5c-2 把它换成「`nodeScope ∩ 子树`」时，本函数就是方法那一侧
/// 的判据。**在接线之前，本函数的行为由测试保证、由生产无涉** —— 这一句
/// 写在文件里而不是只写在提交信息里，因为「有测试、没调用方」是绿灯全绿却
/// 什么都不管的形态，读代码的人必须先看到它。
library;

import '../entities/node.dart';
import '../json.dart';

/// 已认的三个键。**未认的键直接报错**：静默忽略一个新键，等于让作者
/// 以为约束生效了，而实际没有任何一处会检查它。
///
/// `axes` 取代了旧的 `spaceId`：一空间一包废掉之后，「适用哪条轴」才是
/// 用户与作者都说得出口的那一句。
const Set<String> appliesToKeys = <String>{'type', 'axes', 'layer'};

/// 一条方法候选对节点 [node] 是否适用。
///
/// - 未给的键 ⇒ 不构成限制（空 map ⇒ 恒真，即「声明过的不限」）
/// - **给了空数组 ⇒ 恒不命中**：`type = []` 读作「任何类型都不适用」，
///   不是「不限」。写入口 `normalizeAppliesTo` 会先把空数组丢掉，所以它只在
///   手工构造的 map 上出现 —— 那正是要拦的情况
/// - `type` / `layer` 只对可学节点有意义：结构节点上声明了这两个键 ⇒ 不命中
///   （结构节点本来就不是「可学的项」，不是缺字段）
/// - 出现不认的键 ⇒ 抛 [FormatException]
bool appliesToNode(JsonMap appliesTo, {required Node node}) {
  for (final String declared in appliesTo.keys) {
    if (!appliesToKeys.contains(declared)) {
      throw FormatException(
        '`appliesTo` 出现未认的键 `$declared`（只认 ${appliesToKeys.join(" / ")}）',
      );
    }
  }

  final List<String>? types = _declared(appliesTo, 'type');
  final List<String>? layers = _declared(appliesTo, 'layer');
  final List<String>? axes = _declared(appliesTo, 'axes');

  if (types == null && layers == null && axes == null) {
    return true;
  }

  // `LearnableNode` 才带 `type` / `layer`；结构节点恒为 null，于是
  // 「声明了就没得匹配」自然落成 `false`，不必单独写一条分支。
  final LearnableNode? learnable = node is LearnableNode ? node : null;

  if (types != null && !types.contains(learnable?.type.name)) {
    return false;
  }
  if (layers != null && !layers.contains(learnable?.layer.name)) {
    return false;
  }
  if (axes != null && !axes.contains(node.axis.name)) {
    return false;
  }
  return true;
}

/// 读出某个键的候选名单。返回 `null` 表示**该键未声明**（不构成限制）。
///
/// 先校验形状再比较，不把「传错了类型」和「匹配不上」压成同一个 `false`：
/// 前者是作者的错，应当当场报；后者是正常结论。
List<String>? _declared(JsonMap appliesTo, String key) {
  final Object? raw = appliesTo[key];
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    return <String>[raw];
  }
  if (raw is! List) {
    throw FormatException(
      '`appliesTo.$key` 必须是 String 或 String[]，实际是 ${raw.runtimeType}',
    );
  }
  // 逐项校验：`<int>[1]` 这种要在比较之前就报，而不是拿运行时字符串去比。
  final List<String> out = <String>[];
  for (final Object? item in raw) {
    if (item is! String) {
      throw FormatException(
        '`appliesTo.$key` 必须是 String 或 String[]，实际含 ${item.runtimeType}',
      );
    }
    out.add(item);
  }
  return out;
}

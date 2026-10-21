/// `inScope` 的**唯一实现**。
///
/// `entity-fields` §2 把 `inScope` 写成派生字段 =「是否在 `Plan.subtree_root`
/// 子树下」。既然是派生的，就必须**只有这一个定义**：每处各写一遍 `ancestors
/// .contains(root)`，迟早出现「候选列表按一份算、预览按另一份算」—— 那种错
/// 不会抛异常，只会让预览报 12 项而事件里存 4 项。
///
/// ## 为什么收 `subtreeRoot` 而不是整个 `Plan`
///
/// `ADR-0007` 决策 2 的示例签名写的是 `inScopeOf(Node, Plan, ParentIndex)`。
/// 这里收窄成 `subtreeRoot`：`composePlanDraft` 组装草稿时**还没有 `Plan`
/// 实例**（`Plan` 的身份就是 `plan_created` 事件的 id，由落盘才产生），
/// 硬收 `Plan` 会逼调用方先造一个假 Plan 再拆出根节点 —— 那个假 Plan 的其余
/// 字段全是垃圾，而它们本该不可构造。
///
/// 只收根节点与索引，语义不变：判定依据仍**只有** `Plan.subtree_root`。
///
/// ## 边界
///
/// - **根自己算圈内**（子树含根）。`subtreeRoot` 若是恒星，其下全部行星都在圈内。
/// - **跨包**由 `ParentIndex` 承担：装包时 `attach_to` 物化为跨包 `main` 父边
///   （`minimal-pack.md` §4.1），因此父链在包边界处不断。
/// - **未知节点算圈外**：`ancestorsOf` 对无父边节点返回空表，于是只有「它就是
///   根」这一条能命中。不在这里区分「未知」与「确定不在圈内」—— 前者是装载
///   层的问题（`nodeById` 查不到），到这一层已无信息可判。
library;

import '../entities/node.dart';
import 'parent_index.dart';

/// 该节点是否落在 [subtreeRoot] 的子树下（含根本身）。
///
/// 纯函数：不读盘、不看时钟、不查 `PackContent` —— 圈定范围与包内容无关，
/// 只与树形有关。这条约束让它在「包装到一半」时也能算。
bool inScopeOf(
  Node node, {
  required String subtreeRoot,
  required ParentIndex parents,
}) {
  if (node.id == subtreeRoot) {
    return true;
  }
  // `ancestorsOf` 自带环保护（遇环即停），因此坏数据在这里不表现为死循环。
  return parents.ancestorsOf(node.id).contains(subtreeRoot);
}

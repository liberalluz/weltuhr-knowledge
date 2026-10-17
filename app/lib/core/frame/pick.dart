/// 屏幕点 → 节点 id（`SPEC-VIEW-014` 六入口的第 1 个：宇宙点星）。
///
/// ## 为什么拾取不自己算几何
///
/// 这里的输入是**已经投影好的一帧**。拾取只做一件事：把 `ProjectedNode` 的
/// 屏幕坐标与半径拿来，问「这个点在谁身上」。投影、取景、自转都不属于它 ——
/// 重算一遍的话，画面与拾取就有两套几何，任何一处改口径都会让「看得见点不中」
/// 变成偶发 bug（而不是编译错误）。
///
/// 半径由调用方以 `screenRadiusOf` 注入，理由同上：绘制用透视收缩后的半径，
/// 拾取若用另一份公式，两个圆的差就是「点边缘无效」的那一圈。
///
/// ## 为什么不处理「点空白」
///
/// 点空白**不清选中**。清掉意味着详情抽屉会毫无预警地消失，而「点歪了」
/// 是常态；用户要取消选中时手上有明确的出口（树里换行、⑦ 换档、`Esc` 关浮层），
/// 不需要靠「点准空白」这件难事。
library;

import '../constants.dart';
import 'projection.dart';

/// 一帧里被 [pointX] / [pointY] 点中的节点 id。`null` = 没有点到任何节点。
///
/// [visibleIds] 非 `null` 时只考虑可见节点：屏幕上没画的星不该能点中 ——
/// 否则选中一个「看不见的项」，详情会打开一片用户从未见过的内容。
String? pickNodeAt({
  required ProjectedFrame frame,
  required double originX,
  required double originY,
  required double pixelsPerUnit,
  required double pointX,
  required double pointY,
  required double Function(ProjectedNode node) screenRadiusOf,
  Set<String>? visibleIds,
}) {
  // `drawOrder` 是**远 → 近**（画家算法）。拾取要反过来问：最上面那个先说话。
  // 顺序决定重叠时谁赢 —— 用远 → 近会点到被压住的那颗，而用户点的是看得见的。
  final List<int> order = frame.drawOrder;
  for (int i = order.length - 1; i >= 0; i--) {
    final ProjectedNode node = frame.nodes[order[i]];
    if (visibleIds != null && !visibleIds.contains(node.id)) {
      continue;
    }
    final double cx = originX + node.x * pixelsPerUnit;
    final double cy = originY + node.y * pixelsPerUnit;
    final double radius = screenRadiusOf(node);
    // 小星的可点下限（`C-44`）：1.6 px 的圆点得中才叫怪事。
    final double reach = radius < pickMinHitRadius ? pickMinHitRadius : radius;
    final double dx = pointX - cx;
    final double dy = pointY - cy;
    if (dx * dx + dy * dy <= reach * reach) {
      return node.id;
    }
  }
  return null;
}

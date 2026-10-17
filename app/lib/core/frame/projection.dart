/// `r` / `θ` / `φ` → 3D → 2D 的**计算层**（`SPEC-VIEW-002` · `SPEC-VIEW-005`）。
///
/// 纯数学，不 import Flutter、不碰 `dart:ui` —— 这是 `R1` 的要求，也是本笔
/// 能在沙箱里测出数的前提。真正把像素画到屏幕上的事归 `B3` 的 painter
/// 与 `B2` 第 5 笔的帧率实测。
///
/// ## 坐标系（明确假设，`B3` 可改）
///
/// | 坐标 | 含义 | 落点 |
/// |---|---|---|
/// | `r` | 复合轴，**7 段径向分层** | `radial01` 量化到 `radialSegments` 个同心环，段内取环中线 |
/// | `θ` | 六轴扇区（含轴内递归区间分割） | 扇区序号 × 扇区角 + 扇区内归一偏移 |
/// | `φ` | `⪯` 上的 Kahn 层号，**越深越靠外** | 沿轴向偏移 `phiLevel × phiGap` |
///
/// `r` 与 `φ` 都读作「径向」时必然冲突（一个是环带、一个是深度）。本笔把 `φ`
/// 放在**轴向外**（赤道面之外），于是「越深越靠外」在三维里成立、且与 `r` 的
/// 环带不打架。**这是解释而非规格**：`VIEW-002` 只写了三个坐标各承载一个维度，
/// 没写它们怎么合成 3D 点；`B3` 若定别的合成方式，改本文件的 `_toWorld` 一处即可。
library;

import 'dart:math' as math;

import '../constants.dart';

/// 一个待投影的节点。**极坐标与通道取值都由调用方算好**。
///
/// 为什么不让本层从 `Item` 反推：`r` 的「复合轴」怎么构造（`layer`？
/// `layer × type`？）规格没定，属 `B3` 的设计范围；把它塞进计算层等于
/// 冻结一个还没定的设计。所以本层只做**几何与打包**，分布由调用方给。
class SceneNode {
  const SceneNode({
    required this.id,
    required this.radial01,
    required this.sector,
    required this.sectorFraction01,
    required this.phiLevel,
    required this.size01,
    required this.brightness01,
    required this.dashed,
    required this.colorIndex,
    required this.ringFill01,
    required this.ringClosed,
    required this.pulse,
    this.phiFraction01 = 0,
    this.isPlaceholder = false,
  });

  final String id;

  /// `r` 的归一取值：0 在圆心，1 在最外环。
  final double radial01;

  /// `θ` 的扇区序号（0 起，`< sectorCount`）。
  final int sector;

  /// 扇区内的归一偏移，0 = 扇区起始边，1 = 结束边。
  final double sectorFraction01;

  /// `φ` = `kahnLevels()` 的结果。
  final int phiLevel;

  /// `φ` 的**轴向归一位置**（0 = 最内层起点，1 = 最深层的末端）。
  ///
  /// 按「该层起始项的累计分位」算（`ADR-0003` §决策 4）：半径（这里是轴向
  /// 高度）正比于项数，密度自然均匀。**不用等距展开** —— α 包 `φ` 铺到 63 层、
  /// 0 层只 3 项，等距会把层间距压到 `~0.025`；也不能用固定阈值折叠 ——
  /// `φ ≥ 10` 的层装了 126/150 项（84%）。
  ///
  /// ⚠️ 本笔（`B3` 笔 1）只算不消费：投影层仍按 `phiLevel × phiGap` 定位。
  /// 改由本字段驱动属于笔 2 的相机改造，届时同步四处调用点。
  final double phiFraction01;

  /// 是否为「指向未知」的**占位节点**（`ADR-0003` §决策 5 的黑洞）。
  ///
  /// 这类节点没有对应的 `Item`：它的 id 是合成的，只承载「这里缺一个东西」
  /// 这一条信息。绘制成虚线空心点（与树视图的黑洞同一套语言）。
  final bool isPlaceholder;

  /// 大小通道：连接度归一。
  final double size01;

  /// 亮度通道：可外化要件完整度（分母已扣除不可外化格）。
  final double brightness01;

  /// 虚实通道：高比例不可外化。
  final bool dashed;

  /// 颜色通道：`Item.sixAxis` 主取值在取值表里的序号。
  final int colorIndex;

  /// 轨道环填充比例 = 掌握度。
  final double ringFill01;

  /// 轨道环线型：已毕业 = 实线闭合。
  final bool ringClosed;

  /// 脉动通道：0 = 未来 · 1 = 今天到期 · 2 = 已逾期。
  final int pulse;
}

/// 一条边的端点索引与线型。索引指 `nodes` 的下标（边不持有 id，省掉一次查表）。
class EdgeSpan {
  const EdgeSpan({
    required this.fromIndex,
    required this.toIndex,
    required this.dashed,
  });

  final int fromIndex;
  final int toIndex;

  /// `EdgeType.strong` 为实线，其余为虚线（`channel-table.md` 通道 6）。
  final bool dashed;
}

/// 相机与几何参数。
///
/// **全部由调用方给**，本层不内置默认值 —— 相机参数属设计决策，写死在核心层
/// 会让「换个取景」变成改代码。
class Camera {
  const Camera({
    required this.yawRadians,
    required this.pitchRadians,
    required this.distance,
    required this.focal,
    required this.radialSegments,
    required this.sectorCount,
    required this.phiHeight,
    required this.minDepth,
  });

  /// 绕竖轴旋转（宇宙缓慢自转就是改它）。
  final double yawRadians;

  /// 俯仰角。
  final double pitchRadians;

  /// 相机到原点的距离（世界单位）。
  final double distance;

  /// 焦距，决定缩放。
  final double focal;

  /// 径向分层段数（`VIEW-002` 的「7 段」）。
  final int radialSegments;

  /// 扇区数（= 六轴）。
  final int sectorCount;

  /// `φ` 的**满量程**轴向高度（世界单位）。
  ///
  /// 与 `SceneNode.phiFraction01` 相乘得到高度 —— 不再按「每层固定偏移」算，
  /// 因为层数会随内容变（α 包 63 层、别的包可能只有 5 层），固定偏移必然
  /// 要么挤扁要么穿到相机后面。分位归一后，`φ01 ∈ [0,1]` 的含义与包无关。
  final double phiHeight;

  /// 透视除法的下限。**必须 > 0**：节点贴到相机平面上时不做钳制会算出 `Infinity`，
  /// 而 painter 拿到 `Infinity` 的表现是整帧消失，不是报错。
  final double minDepth;
}

/// 投影后的节点。屏幕坐标 + 打包好的通道值，painter 直接照单绘制。
class ProjectedNode {
  const ProjectedNode({
    required this.sourceIndex,
    required this.id,
    required this.x,
    required this.y,
    required this.depth,
    required this.size01,
    required this.brightness01,
    required this.dashed,
    required this.colorIndex,
    required this.ringFill01,
    required this.ringClosed,
    required this.pulse,
  });

  /// 在入参 `nodes` 里的下标 —— 边用它定位两端。
  final int sourceIndex;
  final String id;
  final double x;
  final double y;

  /// 到相机的距离，**越大越远**。绘制顺序与 LOD 都用它。
  final double depth;
  final double size01;
  final double brightness01;
  final bool dashed;
  final int colorIndex;
  final double ringFill01;
  final bool ringClosed;
  final int pulse;
}

/// 一帧的投影结果。`nodes` 保持入参顺序（边按下标索引），绘制顺序另给。
class ProjectedFrame {
  const ProjectedFrame({
    required this.nodes,
    required this.edges,
    required this.drawOrder,
  });

  final List<ProjectedNode> nodes;
  final List<EdgeSpan> edges;

  /// 绘制顺序：**远 → 近**（画家算法）。`nodes` 的下标序列。
  ///
  /// 不直接排序 `nodes`：边按下标引用两端，重排会让边指错点。
  final List<int> drawOrder;
}

/// 投影一帧。
///
/// 每节点的计算量 = 2 次三角 + 量化 + 两次旋转 + 1 次除法 + 通道打包。
/// 顺序固定、无分支依赖数据，所以每帧成本与坐标取值无关，只与节点数有关。
ProjectedFrame projectFrame({
  required List<SceneNode> nodes,
  required List<EdgeSpan> edges,
  required Camera camera,
}) {
  final double cosYaw = math.cos(camera.yawRadians);
  final double sinYaw = math.sin(camera.yawRadians);
  final double cosPitch = math.cos(camera.pitchRadians);
  final double sinPitch = math.sin(camera.pitchRadians);

  // 扇区宽 = 一整圈 / 扇区数（`C-29`）。
  final double sectorWidth = fullTurnRadians / camera.sectorCount;

  final List<ProjectedNode> projected = <ProjectedNode>[];

  for (int i = 0; i < nodes.length; i++) {
    final SceneNode node = nodes[i];

    // `r`：量化到环带，取环中线 —— 同一段的项坐在同一个环上，否则「7 段」
    // 退化成一圈连续半径，段与段之间看不出层次。
    final int band = _clampInt(
      (node.radial01 * camera.radialSegments).floor(),
      0,
      camera.radialSegments - 1,
    );
    final double radius =
        (band + radialBandCenterOffset) / camera.radialSegments;

    final double theta =
        node.sector * sectorWidth + node.sectorFraction01 * sectorWidth;

    final double worldX = radius * math.cos(theta);
    final double worldZ = radius * math.sin(theta);
    final double worldY = node.phiFraction01 * camera.phiHeight;

    // 先绕竖轴（yaw），再绕横轴（pitch）。
    final double yawX = worldX * cosYaw - worldZ * sinYaw;
    final double yawZ = worldX * sinYaw + worldZ * cosYaw;
    final double pitchY = worldY * cosPitch - yawZ * sinPitch;
    final double pitchZ = worldY * sinPitch + yawZ * cosPitch;

    final double depth = camera.distance - pitchZ;
    final double safeDepth = depth < camera.minDepth ? camera.minDepth : depth;
    final double scale = camera.focal / safeDepth;

    projected.add(
      ProjectedNode(
        sourceIndex: i,
        id: node.id,
        x: yawX * scale,
        y: pitchY * scale,
        depth: safeDepth,
        size01: node.size01,
        brightness01: node.brightness01,
        dashed: node.dashed,
        colorIndex: node.colorIndex,
        ringFill01: node.ringFill01,
        ringClosed: node.ringClosed,
        pulse: node.pulse,
      ),
    );
  }

  final List<int> order = <int>[for (int i = 0; i < projected.length; i++) i];
  order.sort(
    (int a, int b) => projected[b].depth.compareTo(projected[a].depth),
  );

  return ProjectedFrame(
    nodes: projected,
    edges: List<EdgeSpan>.unmodifiable(edges),
    drawOrder: order,
  );
}

int _clampInt(int value, int low, int high) {
  if (value < low) {
    return low;
  }
  return value > high ? high : value;
}

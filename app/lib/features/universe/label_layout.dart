/// 屏幕空间标注的落点与避让（`V-1d2`）。
///
/// `Z0` / `Z1` / `Z2` 三档都有标注层，此前各写各的落点，且**一律落在正下方**
/// （`top = 锚点.dy + gap`，水平居中）—— 不感知邻居，也不感知自己的物体有多大。
/// 后果在真机截图里立刻可见：`Z1` 的 `verb-conjugation` 与 `verb-frame` 中心距
/// 58 px、标签宽 132，实测压了约 8 px；`Z0` 的 `80 项 · 8 域` 副行正好卡在
/// German 盘与 Python 盘之间那条 36 px 的缝里。
///
/// 三处各写一遍的代价不是「三份代码」，而是**改一处不会有任何东西变红**
/// （`R-08`）：`Z3` 恒星系一上来就是恒星名 + 九颗行星，标签密度比 `Z1` 翻倍，
/// 那时把「固定下方」复制到第三处，就再也没机会收回来了。所以先收在这里。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../../core/constants.dart';

/// 判定「正对上 / 正对下 / 正对左右」的余弦阈值。
///
/// `0.35 ≈ sin(20°)`：方位与坐标轴偏 20° 以内算「正对」，走贴边对齐；再大就
/// 转成垂直居中。**不是观感参数**，是矩阵切换阈值 —— 改它只会让标签在两个对齐
/// 方式之间跳边，所以不进常量表。
const double _axisBias = 0.35;

/// 锚点与中心重合的判据（px）。小于它就当作「没有方位」，退化成正下方。
const double _noDirectionDistance = 0.5;

/// 一个待摆放的标注。
class LabelAnchor {
  const LabelAnchor({
    required this.key,
    required this.anchor,
    required this.size,
    this.payload,
  });

  /// 调用方的标识（`Z0` 用 `spaceId`、`Z1` 用 `domainId`、`Z2` 用 `knot:` /
  /// `exit:` 前缀）。只用于**回传对应**，不参与主排序 —— 同一份几何换个传入
  /// 顺序不该改变布局，方位角才是判据（见 [placeLabels] 第 2 条）。
  final String key;

  /// 它标注的物体在**窗口坐标**里的位置。
  final Offset anchor;

  /// 期望盒尺寸。宽度由调用方统一给（一律用同一个 `_xxxLabelWidth`），高度按
  /// 行数算 —— 三档的行高口径不同，由调用方说，不由这里猜。
  final Size size;

  /// 原样带回给调用方的载荷（样式、正文等）。放在这里而不是让调用方按 `key`
  /// 前缀反解，是因为「前缀即类型」这种约定正是 `R-08` 要消掉的东西。
  final Object? payload;
}

/// 摆放结果。
class LabelPlacement {
  const LabelPlacement({
    required this.key,
    required this.rect,
    required this.outwardSteps,
    this.overlaps = false,
    this.payload,
  });

  final String key;
  final Rect rect;

  /// 被挤开了几格。`0` = 第一落点就空着。
  final int outwardSteps;

  /// **最终是否仍与别人重叠**。
  ///
  /// 与「用尽外推」（`outwardSteps == labelAvoidMaxSteps`）**不是一回事**：四个
  /// 同位锚点恰好能各占一格，用尽上限却没压住。规划时先写的是前者，四个同位点
  /// 的用例一跑就露了 —— 所以判据改成「结果」，不是「过程」。
  final bool overlaps;

  final Object? payload;
}

/// 摆放全部标注，返回顺序与传入顺序一致。
///
/// 三条口径写在这里，而不是散进三个调用方：
///
/// 1. **方向 = 从 [center] 指向锚点的方位角**，标签落在锚点**外侧**，按方位选
///    九宫格对齐（朝下就顶部贴上、朝右就左侧贴上）。锚点落在 [center] 上时
///    退化成「正下方、水平居中」—— 与 `V-1d` 之前的行为一致，这正是本函数是
///    推广而不是改变的地方。
/// 2. **冲突按方位角圆周序处理，不按传入顺序**。传入顺序即数据顺序，换个包顺序
///    就换布局；方位角是几何量，同一份几何只会有一种结果。
/// 3. **外推有上限**（`C-71`），超限就接受重叠。一路往外推会把标签推到离自己
///    物体很远的地方，「哪个标签对哪个点」反而更糊 —— 那比两个标签挨着更糟。
List<LabelPlacement> placeLabels({
  required Offset center,
  required List<LabelAnchor> anchors,
  required Size viewport,
  required double gap,
}) {
  final List<_Pending> pending = <_Pending>[];
  for (int i = 0; i < anchors.length; i++) {
    final LabelAnchor a = anchors[i];
    final double dx = a.anchor.dx - center.dx;
    final double dy = a.anchor.dy - center.dy;
    final double distance = math.sqrt(dx * dx + dy * dy);
    final Offset unit = distance < _noDirectionDistance
        ? const Offset(0, 1)
        : Offset(dx / distance, dy / distance);
    pending.add(
      _Pending(
        index: i,
        anchor: a,
        unit: unit,
        angle: math.atan2(unit.dy, unit.dx),
      ),
    );
  }
  pending.sort((_Pending a, _Pending b) {
    final int byAngle = a.angle.compareTo(b.angle);
    return byAngle != 0 ? byAngle : a.anchor.key.compareTo(b.anchor.key);
  });

  final List<Rect> placed = <Rect>[];
  final List<bool> placedOverlaps = <bool>[];
  final List<LabelPlacement> out = List<LabelPlacement>.filled(
    anchors.length,
    const LabelPlacement(
      key: '',
      rect: Rect.zero,
      outwardSteps: 0,
    ),
  );

  for (final _Pending p in pending) {
    // 每外推一格就多让 `size.height`（或 `gap`）的 `C-70` 倍 —— 用高度而不是
    // 宽度，是因为标签是**单行**的，挤开时真正需要的那一维就是行高。
    final double stepUnit =
        math.max(p.anchor.size.height, gap) * labelAvoidStepRatio;
    Rect chosen = _clampInside(
      _boxAt(
        point: p.anchor.anchor + p.unit * (gap + labelAvoidMaxSteps * stepUnit),
        size: p.anchor.size,
        unit: p.unit,
      ),
      viewport,
    );
    int steps = labelAvoidMaxSteps;
    bool overlaps = false;
    for (int k = 0; k <= labelAvoidMaxSteps; k++) {
      final Rect raw = _boxAt(
        point: p.anchor.anchor + p.unit * (gap + k * stepUnit),
        size: p.anchor.size,
        unit: p.unit,
      );
      final Rect rect = _clampInside(raw, viewport);
      if (!placed.any(rect.overlaps)) {
        chosen = rect;
        steps = k;
        break;
      }
    }
    // 用尽上限：接受重叠，但**说出来**。`overlaps` 判的是结果，不是过程 ——
    // 见 `LabelPlacement.overlaps` 的注释。
    overlaps = placed.any(chosen.overlaps);
    placed.add(chosen);
    placedOverlaps.add(overlaps);
    out[p.index] = LabelPlacement(
      key: p.anchor.key,
      rect: chosen,
      outwardSteps: steps,
      overlaps: overlaps,
      payload: p.anchor.payload,
    );
  }

  return out;
}

/// 标签盒：沿方位贴在落点外侧。
///
/// 「外侧」在这里落成对齐方式，而不是再往外挪一段距离 —— 挪距离会把标签推离
/// 锚点，对齐则是让它**从锚点向外长**。朝下时顶部贴上，锚点就不会被文字盖住。
Rect _boxAt({
  required Offset point,
  required Size size,
  required Offset unit,
}) {
  final double top = unit.dy > _axisBias
      ? point.dy
      : unit.dy < -_axisBias
      ? point.dy - size.height
      : point.dy - size.height / 2;
  final double left = unit.dx > _axisBias
      ? point.dx
      : unit.dx < -_axisBias
      ? point.dx - size.width
      : point.dx - size.width / 2;
  return Rect.fromLTWH(left, top, size.width, size.height);
}

/// 把盒平移进视口。**只平移不缩放** —— 缩字会让同一档出现两种字号，而
/// `VIEW-036` 明写「字号统一」。
Rect _clampInside(Rect rect, Size viewport) {
  double left = rect.left;
  double top = rect.top;
  if (rect.width >= viewport.width) {
    left = 0;
  } else if (left < 0) {
    left = 0;
  } else if (left + rect.width > viewport.width) {
    left = viewport.width - rect.width;
  }
  if (rect.height >= viewport.height) {
    top = 0;
  } else if (top < 0) {
    top = 0;
  } else if (top + rect.height > viewport.height) {
    top = viewport.height - rect.height;
  }
  return Rect.fromLTWH(left, top, rect.width, rect.height);
}

/// 排序期的工作副本。`index` 只为「按传入顺序返回」保留。
class _Pending {
  const _Pending({
    required this.index,
    required this.anchor,
    required this.unit,
    required this.angle,
  });

  final int index;
  final LabelAnchor anchor;
  final Offset unit;
  final double angle;
}

/// 五层同心球壳 —— 语义节点将来待的地方。
///
/// `ADR-0006` 决策表的「布局」写的是**同心球壳，半径按对数等比**：同一层上的
/// 节点到球心等距，层与层之间按固定倍数放大。相机固定在球心、只旋转不平移，
/// 所以**壳本身在画面上是看不见的**（看不见一个与自己同心的球面），能看到的
/// 只有落在壳上的点。这里画经纬网格，是让「结构成立」这件事在节点还没有的
/// 时候就能验：一眼能数出几层、每层的半径比例对不对。
///
/// **层数按三轴的真实深度取最大值，不为视觉对称造层**。学科与专业只有 4 层
/// （根 / 门类或大类 / 一级或中类 / 学位类别或小类或细类），角色轴 5 层；
/// 若为了「三轴一样深」凑成 7 层，等于给编目里不存在的层级造壳 ——
/// 那是 `MEMORY-rules` §三 明确禁止的做法（「深度是编目的函数」）。
/// 浅轴用不满 5 层，最外层留空：空壳上没有点，看不出来，但结构不撒谎。
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

/// 球壳层数 = 三轴深度的最大值（角色轴 5 层）。
const int kShellCount = 5;

/// 最内层半径（世界单位）。星空在 100，五层最外层约 55，仍在天球之内 ——
/// 节点是「近处的东西」，星空是「无穷远的背景」，这个层次不能反。
const double kInnermostShellRadius = 8.0;

/// 相邻两层的半径倍数（对数等比的「等比」）。
const double kShellRadiusRatio = 1.62;

/// 每层画多少条经线。
const int kShellMeridianCount = 12;

/// 每层画多少条纬线（不含两极的点）。
const int kShellLatitudeCount = 5;

/// 每条圆分成多少段。段数少会看出多边形折角，多则纯属浪费 —— 48 段在
/// 这个视场下已经看不出棱。
const int kShellCircleSegments = 48;

/// 网格线的世界宽度。
const double kShellLineWidth = 0.055;

/// 网格线的透明度。压得很低：它是「结构参考线」，不该盖过星空。
const double kShellLineAlpha = 0.10;

/// 三轴各自的层级深度。键用轴名，与 `enums.dart` 的 `Axis` 取值一致。
///
/// `level_slot` 的 12 个合法对是「学科 3 / 专业 4 / 角色 5」，加上轴根即
/// 4 / 5 / 6；这里记的是**不含虚拟根 `知识`** 的层数 —— 虚拟根不在球壳上，
/// 它没有位置（与面包屑第 1 段同判据）。
const Map<String, int> kAxisDepth = <String, int>{
  'discipline': 4,
  'major': 4,
  'occupation': 5,
};

/// 第 [index] 层（0 起）的半径。
double shellRadius(int index) {
  assert(index >= 0 && index < kShellCount, '层号取 0..${kShellCount - 1}');
  return kInnermostShellRadius * math.pow(kShellRadiusRatio, index).toDouble();
}

/// 全部五层的半径，内到外。
List<double> shellRadii() => <double>[
  for (int i = 0; i < kShellCount; i++) shellRadius(i),
];

/// 某条轴实际用得上几层。取不到轴名时按最深轴给 —— 未知轴不缩水。
int shellDepthForAxis(String axis) => kAxisDepth[axis] ?? kShellCount;

/// 组装一层球壳的线段集合：纬线若干 + 经线若干。
///
/// 线段是「两两一对」的端点，所以每条圆要拆成 `段数` 个独立线段。
/// 极点上不画纬线（半径为零，画出来是一个点）。
Float32List shellSegments(double radius) {
  final List<double> vertices = <double>[];

  void addSegment(vm.Vector3 a, vm.Vector3 b) {
    vertices.addAll(<double>[a.x, a.y, a.z, b.x, b.y, b.z]);
  }

  vm.Vector3 onSphere(double latRad, double lonRad) {
    final double cosLat = math.cos(latRad);
    return vm.Vector3(
      radius * cosLat * math.cos(lonRad),
      radius * math.sin(latRad),
      radius * cosLat * math.sin(lonRad),
    );
  }

  // 纬线：从 −60° 到 +60° 均分，避开两极。
  for (int i = 0; i < kShellLatitudeCount; i++) {
    final double lat =
        (-60 + 120 * i / (kShellLatitudeCount - 1)) * math.pi / 180;
    for (int s = 0; s < kShellCircleSegments; s++) {
      final double lonA = 2 * math.pi * s / kShellCircleSegments;
      final double lonB = 2 * math.pi * (s + 1) / kShellCircleSegments;
      addSegment(onSphere(lat, lonA), onSphere(lat, lonB));
    }
  }

  // 经线：整圈分 `经线数` 条，每条从南极到北极。
  for (int m = 0; m < kShellMeridianCount; m++) {
    final double lon = 2 * math.pi * m / kShellMeridianCount;
    for (int s = 0; s < kShellCircleSegments; s++) {
      final double latA = -math.pi / 2 + math.pi * s / kShellCircleSegments;
      final double latB =
          -math.pi / 2 + math.pi * (s + 1) / kShellCircleSegments;
      addSegment(onSphere(latA, lon), onSphere(latB, lon));
    }
  }

  return Float32List.fromList(vertices);
}

/// 把五层网格装进一个节点。
///
/// 一个 `LineSegmentsGeometry` 装全部五层，不是五个几何：五个节点就是五次
/// draw call，而这里要测的正是渲染开销，不该把调度开销混进来。
/// 线段在 GPU 上展开成面向相机的带子，CPU 每帧零成本。
fs.Node buildShellsNode() {
  final List<double> vertices = <double>[];
  for (final double radius in shellRadii()) {
    vertices.addAll(shellSegments(radius));
  }

  final fs.LineSegmentsGeometry geometry = fs.LineSegmentsGeometry(
    fs.LineSegmentData(positions: Float32List.fromList(vertices)),
    width: kShellLineWidth,
  );

  // 半透明：网格是参考线，不能挡住背后的星。透明材质要显式声明
  // `alphaMode`，默认 `opaque` 会把 alpha 直接丢掉。
  final fs.UnlitMaterial material = fs.UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.52, 0.60, 0.78, kShellLineAlpha)
    ..alphaMode = fs.AlphaMode.blend;

  return fs.Node(mesh: fs.Mesh(geometry, material));
}

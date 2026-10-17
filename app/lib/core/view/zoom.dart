/// 五档视距（`SPEC-VIEW-001`）与 `φ` → 档位的判据（`SPEC-VIEW-009`）。
///
/// 这一层只放**可判定的规则**，不放取景参数 —— 相机距离、俯仰这些属设计，
/// 写进核心层会让「换个取景」变成改代码（同 `projection.dart` 的口径）。
library;

import '../constants.dart';

/// 五档视距。**是唯一主导导航层级**（`SPEC-VIEW-001`），底部刻度即它。
enum ZoomLevel {
  z0('Z0', '宇宙'),
  z1('Z1', '星系'),
  z2('Z2', '星云'),
  z3('Z3', '恒星系'),
  z4('Z4', '单星');

  const ZoomLevel(this.code, this.label);

  /// 界面上的刻度名（`Z0`…`Z4`）。
  final String code;

  /// 档位中文名，HUD 与面包屑都用它。
  final String label;

  /// 只有 `Z0` 是跨空间的「全部空间」视角；`Z1` 起开始换根。
  bool get isAllSpaces => this == ZoomLevel.z0;

  /// `Z1` 是「进入某个空间」的那一档，切档时换根。
  bool get changesRoot => this == ZoomLevel.z1;
}

/// `φ` → 视距档（`SPEC-VIEW-009`）。
///
/// 判据是 **`φ`**，不是「树里展开到第几层」—— 展开深度是翻阅习惯的副产品，
/// 不代表观察意图。因此树 → 宇宙的档位只读 `φ`，允许有损（树深宇宙浅）。
///
/// | 条件 | 档位 |
/// |---|---|
/// | 仅选中、无子树 | `Z4`（单星） |
/// | `φ = 0` | `Z1`（星系） |
/// | `φ ∈ 1…2` | `Z2`（星云） |
/// | `φ ≥ 3` | `Z3`（恒星系） |
ZoomLevel zoomForPhi(int phi, {bool hasChildren = true}) {
  if (!hasChildren) {
    return ZoomLevel.z4;
  }
  if (phi <= 0) {
    return ZoomLevel.z1;
  }
  return phi <= zoomPhiMaxForNebula ? ZoomLevel.z2 : ZoomLevel.z3;
}

/// 视角状态。切换视距 / 视图时**必须保留**它（`SPEC-VIEW-009` 末句）：
/// 来回切换不重置视角，否则用户每次都要重新找回方向。
///
/// 不可变：切档用 [copyWith] 派生新实例，避免「改了一处忘了通知」。
class CameraState {
  const CameraState({
    required this.zoom,
    required this.yawRadians,
    required this.pitchRadians,
    this.selectedItemId,
  });

  final ZoomLevel zoom;

  /// 绕竖轴的旋转角。宇宙缓慢自转改的就是它。
  final double yawRadians;

  /// 俯仰角。
  final double pitchRadians;

  /// `Z4` 才有的聚焦项；其余档位为 `null`。
  final String? selectedItemId;

  /// 换档位，其余字段原样保留 —— 这就是「切换不重置视角」的机制。
  ///
  /// 离开 `Z4` 时清空 `selectedItemId`：详情是 `Z4` 的形态（`SPEC-VIEW-013`），
  /// 非 `Z4` 还带着选中项会让「进详情 = 推进到 Z4」这条裁定失真。
  CameraState withZoom(ZoomLevel next, {String? selectedItemId}) => CameraState(
    zoom: next,
    yawRadians: yawRadians,
    pitchRadians: pitchRadians,
    selectedItemId: selectedItemId ?? (next == ZoomLevel.z4 ? this.selectedItemId : null),
  );

  @override
  String toString() =>
      'CameraState(${zoom.code} · yaw $yawRadians · pitch $pitchRadians'
      '${selectedItemId == null ? '' : ' · $selectedItemId'})';
}

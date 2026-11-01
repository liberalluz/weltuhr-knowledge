/// 虫洞过渡 —— `B17b` 笔 7。
///
/// 点一个子级点 ⇒ 相机沿**大圆弧**转向它 ⇒ 到达那一刻换到新的一片天、点层
/// 从最暗值渐亮回满。
///
/// 为什么是「弧线」而不是「yaw / pitch 各走各的直线」：两者在视场上都不跳，
/// 但直线的角速度不均匀，转过 170° 时中段会甩得很快。方向向量做球面插值，
/// 相机走的是球面上的最短弧 —— 与「抬头看那颗星」这个动作本身同构。
///
/// ## 判据落在 [nodeOpacity] 上
///
/// `ADR-0006:100` 要求「中途不出现空白帧」。星空（天球贴图 + 亮星）始终在，
/// 所以严格意义上的黑帧不会出现；但换片那一下若点层从满亮直接归零再涨回，
/// 观感上就是「空了一下」—— 与判据要防的是同一件事。因此点层不透明度全程有
/// 下界 [universeWormholeFadeFrom]：转向时渐暗到它，换片后从它渐亮回 1。
///
/// ## 不碰相机、不碰画布
///
/// 本类只回答三个问题：现在朝向哪、点层该多亮、转完了没有。写回相机与触发
/// 换地址都由 [SpikeSceneView] 做 —— 这样它能在 `flutter test` 里跑，而
/// `SceneView` 那套要 GPU 的东西一个都不在依赖里。
library;

import 'dart:math' as math;

import '../../../core/constants.dart';
import 'sky_image.dart';

/// 相机姿态（度）。与 `SkyCamera` 的 `yaw` / `pitch` 同一口径。
class SkyPose {
  const SkyPose({required this.yawDeg, required this.pitchDeg});

  final double yawDeg;
  final double pitchDeg;
}

/// 一条单位方向 → 相机姿态。
///
/// 与 `SkyCamera.directionOf` 互为反函数：那里是
/// `(sin yaw · cos pitch, sin pitch, cos yaw · cos pitch)`，所以这里是
/// `pitch = asin(y)`、`yaw = atan2(x, z)`。
///
/// 反解而不是对 `yaw` / `pitch` 直接插值，是为了让相机走大圆 —— 直接插值两个
/// 角度会走一条「纬度不变的斜线」，转过 170° 时中段明显甩快。
SkyPose poseOfDirection(Vec3 direction) {
  final double y = direction.y.clamp(-1.0, 1.0);
  return SkyPose(
    yawDeg: math.atan2(direction.x, direction.z) * 180 / math.pi,
    pitchDeg: math.asin(y) * 180 / math.pi,
  );
}

/// 单位方向的大圆插值（`t` 夹在 0..1）。
///
/// 两个方向几乎重合时（`sin θ` 趋近 0）直接返回 `to`：此时除法会把浮点噪声
/// 放大成随机方向 —— 点中正前方的点时正好会走到这一支。
Vec3 slerpDirection(Vec3 from, Vec3 to, double t) {
  final double k = t.clamp(0.0, 1.0);
  final double dot = (from.x * to.x + from.y * to.y + from.z * to.z).clamp(
    -1.0,
    1.0,
  );
  final double theta = math.acos(dot);
  if (theta < 1e-6) {
    return to;
  }
  final double sinTheta = math.sin(theta);
  final double wa = math.sin((1 - k) * theta) / sinTheta;
  final double wb = math.sin(k * theta) / sinTheta;
  return Vec3(
    from.x * wa + to.x * wb,
    from.y * wa + to.y * wb,
    from.z * wa + to.z * wb,
  );
}

/// 过渡所处的阶段。
enum WormholePhase {
  /// 屏幕上还是旧的一片天，相机正在转向目标。
  turning,

  /// 已经换到新的一片天，点层正在渐亮。
  fading,

  /// 两段都走完，本对象可以丢弃。
  idle,
}

/// 一次虫洞过渡的进度。
class WormholeTransition {
  WormholeTransition({required this.from, required this.to});

  /// 起点朝向（点中那个子级之前，相机在哪）。
  final Vec3 from;

  /// 终点朝向 —— 就是被点中那颗子级的方向。
  ///
  /// 换片之后新片天把「新的当前节点」定义在 0°，而相机此时正对着它，
  /// 所以换片那一步不必再摆相机：视觉上方向是连续的。
  final Vec3 to;

  double _turnElapsed = 0;
  double _fadeElapsed = 0;
  bool _arrived = false;

  WormholePhase get phase {
    if (!_arrived) {
      return WormholePhase.turning;
    }
    return _fadeElapsed >= universeWormholeFadeSeconds
        ? WormholePhase.idle
        : WormholePhase.fading;
  }

  /// 转向进度（0..1，已缓动）。
  double get turnProgress =>
      _easeInOut((_turnElapsed / universeWormholeTurnSeconds).clamp(0.0, 1.0));

  /// 淡入进度（0..1，已缓动）。转向阶段恒为 0。
  double get fadeProgress => _arrived
      ? _easeInOut((_fadeElapsed / universeWormholeFadeSeconds).clamp(0.0, 1.0))
      : 0.0;

  /// 当前朝向。
  Vec3 get direction => _arrived ? to : slerpDirection(from, to, turnProgress);

  /// 点层此刻该用的不透明度（0..1）—— 见文件头的判据说明。
  double get nodeOpacity {
    if (!_arrived) {
      return 1 + (universeWormholeFadeFrom - 1) * turnProgress;
    }
    return universeWormholeFadeFrom +
        (1 - universeWormholeFadeFrom) * fadeProgress;
  }

  /// 是否已经转到目标（调用方据此换地址）。
  bool get hasArrived => _arrived;

  /// 两段都走完。
  bool get isDone => phase == WormholePhase.idle;

  /// 推进 [dtSeconds]。
  ///
  /// 返回值只在**刚转完的那一帧**为 `true` —— 换地址是有副作用的动作，
  /// 不能每帧都做。`dt` 由调用方提供而不是自己读时钟，是为了让用例能一次
  /// 推进一整段。
  bool advance(double dtSeconds) {
    if (isDone) {
      return false;
    }
    final double dt = dtSeconds <= 0 ? 0.0 : dtSeconds;
    if (!_arrived) {
      _turnElapsed += dt;
      if (_turnElapsed >= universeWormholeTurnSeconds) {
        _turnElapsed = universeWormholeTurnSeconds;
        _arrived = true;
        return true;
      }
      return false;
    }
    _fadeElapsed += dt;
    return false;
  }

  static double _easeInOut(double t) =>
      t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;
}

/// 帧时序统计 —— 这一笔的**判据侧**。
///
/// 只回答三个问题：稳态多少 fps、帧间隔的 p95 是多少、光栅化吃掉多少。
/// 判据线来自 `constants.dart` 的 `C-32`（30 / 50 fps），本文件不另立标准。
///
/// ## 为什么 fps 用「帧间隔中位数」而不是平均数
///
/// 平均数会被一次 200 ms 的卡顿拉垮，而那一次卡顿恰恰是要被看见的事 ——
/// 但把它混进 fps 又会让「稳态其实很好」的画面说不清。所以两个都给：
/// `fps` 用中位数承载稳态，`frameP95Ms` 承载卡顿。只看一个都会误判。
library;

import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';

import '../../core/constants.dart';

/// 一帧时间片的统计快照。
class FrameRateSnapshot {
  const FrameRateSnapshot({
    required this.fps,
    required this.frameP50Ms,
    required this.frameP95Ms,
    required this.buildP95Ms,
    required this.rasterP95Ms,
    required this.samples,
  });

  /// 稳态帧率 = `1000 / 帧间隔中位数`。
  final double fps;

  final double frameP50Ms;
  final double frameP95Ms;

  /// UI 线程耗时 p95（`FrameTiming.buildDuration`）。
  final double buildP95Ms;

  /// 光栅线程耗时 p95（`FrameTiming.rasterDuration`）。**这是本笔最想看的一列**
  /// —— CPU 侧投影已实测 0.02 ms，剩下的时间只可能在这里。
  final double rasterP95Ms;

  final int samples;

  bool get meetsTarget => fps >= frameTargetFps;

  bool get meetsGood => fps >= frameGoodFps;
}

/// 滚动窗口的帧时序收集器。
///
/// 只保留最近 [capacity] 帧：切档 / 起播的抖动不该永久污染读数，
/// 而窗口够长才能让 p95 有意义（120 帧 ≈ 2 秒 @60fps）。
class FrameRateMonitor {
  FrameRateMonitor({this.capacity = 120});

  final int capacity;

  final List<int> _vsyncUs = <int>[];
  final List<double> _intervalMs = <double>[];
  final List<double> _buildMs = <double>[];
  final List<double> _rasterMs = <double>[];

  /// 少于这个样本数不出快照：两帧之间的「帧率」没有意义。
  static const int _minSamples = 20;

  void add(List<FrameTiming> timings) {
    for (final FrameTiming timing in timings) {
      final int vsync = timing.timestampInMicroseconds(FramePhase.vsyncStart);
      if (_vsyncUs.isNotEmpty) {
        final int previous = _vsyncUs.last;
        if (vsync > previous) {
          _intervalMs.add((vsync - previous) / 1000);
        }
      }
      _vsyncUs.add(vsync);
      _buildMs.add(timing.buildDuration.inMicroseconds / 1000);
      _rasterMs.add(timing.rasterDuration.inMicroseconds / 1000);
    }
    _trim();
  }

  void reset() {
    _vsyncUs.clear();
    _intervalMs.clear();
    _buildMs.clear();
    _rasterMs.clear();
  }

  FrameRateSnapshot? snapshot() {
    if (_intervalMs.length < _minSamples) {
      return null;
    }
    final List<double> median = <double>[..._intervalMs]..sort();
    final double middle = median[median.length ~/ 2];
    return FrameRateSnapshot(
      fps: middle <= 0 ? 0 : 1000 / middle,
      frameP50Ms: middle,
      frameP95Ms: _percentile(_intervalMs, 0.95),
      buildP95Ms: _percentile(_buildMs, 0.95),
      rasterP95Ms: _percentile(_rasterMs, 0.95),
      samples: _intervalMs.length,
    );
  }

  void _trim() {
    _cut(_vsyncUs);
    _cut(_intervalMs);
    _cut(_buildMs);
    _cut(_rasterMs);
  }

  /// 每个列表各自裁到 `capacity`（间隔样本比帧样本少一个，不能共用同一个计数）。
  void _cut<T>(List<T> values) {
    final int drop = values.length - capacity;
    if (drop > 0) {
      values.removeRange(0, drop);
    }
  }

  static double _percentile(List<double> values, double ratio) {
    if (values.isEmpty) {
      return 0;
    }
    final List<double> sorted = <double>[...values]..sort();
    final int index = (sorted.length * ratio).floor();
    final int clamped = index >= sorted.length ? sorted.length - 1 : index;
    return sorted[clamped];
  }
}

/// 语义节点的标注层 —— `B17b` 笔 5。
///
/// 光点（笔 3）只回答「这一片有几个节点」，不回答「哪个是哪个」。本文件把
/// 名字写到点旁边，且只在视场足够小的时候写 —— 广角下一屏几十个点，标了
/// 也是糊的。
///
/// **画在 Canvas 层、用 `dart:ui.Paragraph` 缓存**。`ADR-0006` §5 那格原写
/// 「Flutter Widget 叠加，≤60 条，`Paragraph` LRU 200」，那半句内部就是矛盾的：
/// `Paragraph` 是 `dart:ui` 的底层对象，只能 `canvas.drawParagraph`，Widget 层
/// 根本接不到它。本笔按「Canvas 层 + Paragraph 缓存」实现，修订十六已改。
///
/// **为什么必须缓存**：`Paragraph` 建一次要走一遍字形排版（几百微秒量级），
/// 一屏 60 条每帧重建就是把帧时间全吃掉。缓存之后每帧只剩 `drawParagraph`。
library;

import 'dart:ui' as ui;

// `Axis` 两边都有（Flutter 的绘制轴 / `core/enums.dart` 的知识轴），要后者。
import 'package:flutter/widgets.dart' hide Axis;

import '../../../core/constants.dart';
import '../../../core/universe/placement.dart';
import 'constellations.dart';
import 'sky_nodes.dart';

/// 一条待画的标注：画谁、写什么、锚在哪。
class SkyLabel {
  const SkyLabel({
    required this.id,
    required this.text,
    required this.center,
    required this.dotRadius,
  });

  final String id;

  /// 显示文字。空串在 [labelTargetsOf] 里已被滤掉，走到这里必非空。
  final String text;

  /// 对应光点的屏幕圆心。
  final ui.Offset center;

  /// 该点所在档的点径 —— 偏移量要加上它，否则大点会把字吃掉。
  final double dotRadius;

  /// 文字左下角该落的位置：点的**右上方**，让开点本身与它的模糊晕。
  ///
  /// 取右上而不是段 4 星座名那种「压在图形中央」：那里线会从字上穿过
  /// （`ADR-0006:303` 记的遗留问题）。一个点旁边写名字，唯一的错法就是压住点。
  ui.Offset get anchor => ui.Offset(
    center.dx + universeLabelGapPx + dotRadius * universeDotCoreScale,
    center.dy - universeLabelGapPx - dotRadius * universeDotCoreScale,
  );
}

/// 挑出这一帧该画哪几条标注，按屏幕顺序返回。
///
/// **当前节点与来路恒在**：它们回答「你在哪、你从哪来」，被条数上限挤掉
/// 就等于没标。子级按到屏幕中心的距离由近及远补满
/// [universeLabelMaxCount]，距离相同时按 id 排 —— 让同一个视角每次算出的
/// 保留集合完全一致，否则每帧的截断结果会随遍历顺序抖动。
List<SkyLabel> labelTargetsOf({
  required UniverseLayout layout,
  required SkyProjection projection,
  required ui.Size size,
  required String anchorId,
}) {
  if (size.isEmpty) {
    return const <SkyLabel>[];
  }

  final List<SkyLabel> pinned = <SkyLabel>[];
  void pin(String id, SkyPoint point, double dotRadius) {
    final String? text = layout.names[id];
    // 名字缺失不是错误：树里查不到这个 id、或那张表本来就没装，
    // 结果是「这个点没有名字」，不是画一个空串。
    if (text == null || text.isEmpty) {
      return;
    }
    final ui.Offset? center = projection.project(directionOfSkyPoint(point));
    // `null` = 落在镜头后方，这一帧看不见它，也就无从标注。
    if (center == null) {
      return;
    }
    pinned.add(
      SkyLabel(id: id, text: text, center: center, dotRadius: dotRadius),
    );
  }

  pin(anchorId, layout.current, universeCurrentDotSize);
  for (int i = 0; i < layout.ancestors.length; i++) {
    pin(layout.ancestorIds[i], layout.ancestors[i], universeAncestorDotSize);
  }
  if (pinned.length >= universeLabelMaxCount) {
    return pinned.sublist(0, universeLabelMaxCount);
  }

  final ui.Offset middle = size.center(ui.Offset.zero);
  double distanceTo(ui.Offset offset) => (offset - middle).distance;

  final List<SkyLabel> candidates = <SkyLabel>[];
  layout.children.forEach((String id, SkyPoint point) {
    final String? text = layout.names[id];
    if (text == null || text.isEmpty) {
      return;
    }
    final ui.Offset? center = projection.project(directionOfSkyPoint(point));
    if (center == null) {
      return;
    }
    candidates.add(
      SkyLabel(
        id: id,
        text: text,
        center: center,
        dotRadius: universeChildDotSize,
      ),
    );
  });
  candidates.sort((SkyLabel a, SkyLabel b) {
    final int byDistance = distanceTo(a.center).compareTo(distanceTo(b.center));
    return byDistance != 0 ? byDistance : a.id.compareTo(b.id);
  });

  final int budget = universeLabelMaxCount - pinned.length;
  return <SkyLabel>[...pinned, ...candidates.take(budget)];
}

/// 排好版的文字缓存（`ADR-0006:98` 的「LRU 200」）。
///
/// 键只有文字本身：颜色一变就整体作废 —— 把颜色编进键，会让「同一个词换个
/// 轴」也占一条新缓存，而一屏最多 60 条、上限 200，换几次轴就把它挤爆了。
class SkyLabelCache {
  SkyLabelCache();

  final Map<String, ui.Paragraph> _entries = <String, ui.Paragraph>{};
  ui.Color? _color;
  int _hits = 0;
  int _misses = 0;

  /// 缓存命中次数。只给用例断言用 —— 界面上没有读数。
  int get hits => _hits;

  /// 缓存未命中次数（即真正 build 了几次）。
  int get misses => _misses;

  /// 当前缓存了多少条。
  int get length => _entries.length;

  /// 取一段文字排好版的结果；同一段文字第二次调用返回同一个实例。
  ui.Paragraph paragraphOf(String text, ui.Color color) {
    if (_color != color) {
      _clear();
      _color = color;
    }
    final ui.Paragraph? cached = _entries.remove(text);
    if (cached != null) {
      _hits++;
      // 重插回末尾 —— `Map` 保持插入序，末尾即最近使用，首位即最久未用。
      _entries[text] = cached;
      return cached;
    }
    _misses++;
    final ui.Paragraph paragraph = _build(text, color);
    _entries[text] = paragraph;
    if (_entries.length > universeLabelCacheLimit) {
      final String oldest = _entries.keys.first;
      _entries.remove(oldest)?.dispose();
    }
    return paragraph;
  }

  void _clear() {
    for (final ui.Paragraph paragraph in _entries.values) {
      paragraph.dispose();
    }
    _entries.clear();
  }

  /// 释放缓存。**不调也不会漏**（进程退出即回收），但换页时主动调一下，
  /// 免得一张 200 条的排版表跟着一个已经不在屏幕上的视图活着。
  void dispose() {
    _clear();
    _color = null;
  }

  ui.Paragraph _build(String text, ui.Color color) {
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: universeLabelFontSize,
        textDirection: ui.TextDirection.ltr,
      ),
    )..pushStyle(ui.TextStyle(color: color, fontSize: universeLabelFontSize));
    builder.addText(text);
    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
  }
}

/// 标注层。每帧重画，文字本身走 [SkyLabelCache]。
class SkyLabelsPainter extends CustomPainter {
  SkyLabelsPainter({
    required this.view,
    required this.universe,
    required this.cache,
    super.repaint,
  });

  final SkyView view;

  /// `null` = 这一片天画不出来，与 [SkyNodesPainter] 同一处置：什么都不画。
  final UniverseView? universe;

  final SkyLabelCache cache;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // 广角下不标：这一条与星座名用同一个阈值口径（[universeLabelFovDeg]）。
    if (view.fovDeg > universeLabelFovDeg) {
      return;
    }
    final UniverseView? universe = this.universe;
    if (universe == null || size.isEmpty) {
      return;
    }
    final SkyProjection projection = SkyProjection(view: view, size: size);
    final List<SkyLabel> labels = labelTargetsOf(
      layout: universe.layout,
      projection: projection,
      size: size,
      anchorId: universe.anchorId,
    );
    final ui.Color color = axisNodeColor(universe.axis)
        .withValues(alpha: universeLabelAlpha);

    for (final SkyLabel label in labels) {
      final ui.Paragraph paragraph = cache.paragraphOf(label.text, color);
      // 文字整块落在锚点上方：锚点是左下角，减去自身高度才是绘制原点。
      canvas.drawParagraph(
        paragraph,
        label.anchor.translate(0, -paragraph.height),
      );
    }
  }

  /// 恒返回 `true`：相机是原地改字段的对象，比较引用永远相等；真正的重绘
  /// 信号来自 `repaint`（每帧递增的计数器），与另两个 painter 同理。
  @override
  bool shouldRepaint(covariant SkyLabelsPainter oldDelegate) => true;
}

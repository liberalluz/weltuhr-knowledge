import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/features/universe/label_layout.dart';

/// 视口固定成 800×600、中心固定成它的正中 —— 三个标注层共用同一把尺子，
/// 断言里的坐标都按这两个值算出来，不留「大概在那一带」。
const Size _viewport = Size(800, 600);
const Offset _center = Offset(400, 300);

const Size _box = Size(120, 14);
const double _gap = 10;

List<LabelPlacement> _place(
  List<LabelAnchor> anchors, {
  Offset center = _center,
  double gap = _gap,
}) => placeLabels(
  center: center,
  anchors: anchors,
  viewport: _viewport,
  gap: gap,
);

LabelAnchor _anchor(
  String key,
  Offset at, {
  Size size = _box,
  Object? payload,
}) => LabelAnchor(key: key, anchor: at, size: size, payload: payload);

void main() {
  group('落点方向（V-1d2）', () {
    // 裁定来源统一写「无 SPEC」：`placeLabels()` 是 `VIEW-036` / `037` / `038`
    // 三处标注层的**共用实现细节**。那三份规格只规定「标注在屏幕空间、不随画面
    // 旋转、字号统一」，没规定落点方向 —— 方向是本笔选定的做法，不是规格条文。
    // 硬凑一个 `SPEC-VIEW-0xx` 会把实现细节冒充成判据（`R-09`：标错比不标更糟）。

    test('锚点在中心正下方 ⇒ 顶部贴上、水平居中（之前三档的落法逐像素保留）（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('a', const Offset(400, 380)),
      ]);

      expect(out.single.rect.left, closeTo(340, 0.01));
      expect(out.single.rect.top, closeTo(390, 0.01));
      expect(out.single.outwardSteps, 0);
      expect(out.single.overlaps, isFalse);
    });

    test('锚点在正右 ⇒ 标签从点的右侧长出去，垂直居中对齐（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('b', const Offset(520, 300)),
      ]);

      expect(out.single.rect.left, closeTo(530, 0.01));
      expect(out.single.rect.top, closeTo(293, 0.01));
    });

    test('锚点在正上 ⇒ 标签从点的上侧长出去，不压住它标的那个点（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('c', const Offset(400, 220)),
      ]);

      expect(out.single.rect.left, closeTo(340, 0.01));
      expect(out.single.rect.top, closeTo(196, 0.01));
      expect(out.single.rect.bottom, closeTo(210, 0.01));
    });

    test('锚点与中心重合 ⇒ 退化成「正下方」，而不是除零后飞到 NaN（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('d', _center),
      ]);

      final Rect rect = out.single.rect;
      expect(rect.left.isFinite, isTrue);
      expect(rect.top.isFinite, isTrue);
      expect(rect.left, closeTo(340, 0.01));
      expect(rect.top, closeTo(310, 0.01));
    });
  });

  group('冲突与外推（V-1d2）', () {
    test('两个同位锚点 ⇒ 第二个沿方位挤开一格，两盒不相交（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('a', const Offset(400, 380)),
        _anchor('b', const Offset(400, 380)),
      ]);

      expect(out[0].outwardSteps, 0);
      expect(out[1].outwardSteps, 1);
      expect(out[0].rect.overlaps(out[1].rect), isFalse);
      // 挤开而不是挪到旁边：两个盒的 x 仍然一样。
      expect(out[1].rect.left, closeTo(out[0].rect.left, 0.01));
    });

    test('四个同位锚点各占一格：用尽上限却没压住 ⇒ overlaps 是结果不是过程（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('a', const Offset(400, 380)),
        _anchor('b', const Offset(400, 380)),
        _anchor('c', const Offset(400, 380)),
        _anchor('d', const Offset(400, 380)),
      ]);

      expect(
        out.map((LabelPlacement p) => p.outwardSteps).toList(),
        <int>[0, 1, 2, labelAvoidMaxSteps],
      );
      for (final LabelPlacement p in out) {
        expect(p.overlaps, isFalse);
      }
    });

    test('五个同位锚点 ⇒ 最后一个接受重叠，并且把这件事说出来（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        for (final String key in <String>['a', 'b', 'c', 'd', 'e'])
          _anchor(key, const Offset(400, 380)),
      ]);

      expect(out.last.outwardSteps, labelAvoidMaxSteps);
      expect(out.last.overlaps, isTrue);
      // 前四个仍然互不相交 —— 上限是**最后一处**让的，不是全体的借口。
      for (int i = 0; i < 4; i++) {
        expect(out[i].overlaps, isFalse);
      }
    });

    test('外推只沿方位方向，不换象限（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('a', const Offset(400, 380)),
        _anchor('b', const Offset(400, 380)),
      ]);

      // 两盒中心相对锚点的方位都是**正下**：dx 相同，dy 递增。
      final Offset first = out[0].rect.center;
      final Offset second = out[1].rect.center;
      expect(second.dx, closeTo(first.dx, 0.01));
      expect(second.dy, greaterThan(first.dy));
    });
  });

  group('视口与顺序（V-1d2）', () {
    test('靠右缘的锚点被平移回视口内，且不缩字（宽高不变）（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('a', const Offset(790, 300)),
      ]);

      final Rect rect = out.single.rect;
      expect(rect.right, closeTo(_viewport.width, 0.01));
      expect(rect.width, closeTo(_box.width, 0.01));
      expect(rect.height, closeTo(_box.height, 0.01));
    });

    test('打乱传入顺序，每个 key 落到的矩形不变 —— 方位角是判据、下标不是（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelAnchor> anchors = <LabelAnchor>[
        _anchor('a', const Offset(400, 380)),
        _anchor('b', const Offset(520, 300)),
        _anchor('c', const Offset(300, 300)),
      ];
      final List<LabelPlacement> forward = _place(anchors);
      final List<LabelPlacement> reversed = _place(anchors.reversed.toList());

      for (final String key in <String>['a', 'b', 'c']) {
        final Rect x = forward
            .firstWhere((LabelPlacement p) => p.key == key)
            .rect;
        final Rect y = reversed
            .firstWhere((LabelPlacement p) => p.key == key)
            .rect;
        expect(y, x, reason: 'key=$key 的落点不该跟着传入顺序变');
      }
    });

    test('返回顺序与传入顺序一致 —— 调用方这样才能按下标取（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('z', const Offset(400, 380)),
        _anchor('a', const Offset(520, 300)),
        _anchor('m', const Offset(300, 300)),
      ]);

      expect(
        out.map((LabelPlacement p) => p.key).toList(),
        <String>['z', 'a', 'm'],
      );
    });

    test('载荷原样带回 —— 调用方不必按 key 前缀反解类型（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      final List<LabelPlacement> out = _place(<LabelAnchor>[
        _anchor('a', const Offset(400, 380), payload: 'knot'),
        _anchor('b', const Offset(520, 300), payload: 42),
      ]);

      expect(out[0].payload, 'knot');
      expect(out[1].payload, 42);
    });

    test('没有锚点就没有摆放，也不抛（无 SPEC：placeLabels 是标注层的共用实现细节，落点与避让规则由 V-1d2 裁定）', () {
      expect(_place(const <LabelAnchor>[]), isEmpty);
    });
  });
}

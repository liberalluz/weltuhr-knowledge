/// 节点光点层的用例（`B17b` 笔 3）。
///
/// 守四件事：**方位角与仰角对应的投影轴向不反**、**三轴三色互不相同**、
/// **落在镜头后方的点被剔除而不是画到反方向**、**算不出落位时一个点都不画**。
///
/// 画出来好不好看（点够不够亮、105 个子级会不会糊成一片）只能实机看，这里
/// 不断言观感 —— 能断言的是「该出现的出现了、不该出现的一个没有」。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

// `flutter_test` 不导出 Flutter 的绘制轴 `Axis`，所以这里不必 `hide` ——
// 能拿到的只有 `core/enums.dart` 的知识轴，两套同名枚举不会撞。
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/universe/placement.dart';
import 'package:project_knowledge/features/universe/presentation/constellations.dart';
import 'package:project_knowledge/features/universe/presentation/sky_nodes.dart';

/// 只带姿态的假相机：投影只需要 yaw / pitch / fov 三个数。
class _View implements SkyView {
  _View({required this.yaw, required this.pitch, required this.fovDeg});

  @override
  final double yaw;

  @override
  final double pitch;

  @override
  final double fovDeg;
}

const ui.Size _size = ui.Size(800, 600);

SkyProjection _projection() =>
    SkyProjection(view: _View(yaw: 0, pitch: 0, fovDeg: 70), size: _size);

SkyPoint _point({double radius = 8, double az = 0, double el = 0}) =>
    SkyPoint(radius: radius, azimuthDeg: az, elevationDeg: el);

UniverseView _universe({
  SkyPoint? current,
  List<SkyPoint> ancestors = const <SkyPoint>[],
  Map<String, SkyPoint> children = const <String, SkyPoint>{},
  Axis axis = Axis.discipline,
}) => UniverseView(
  layout: UniverseLayout(
    current: current ?? _point(),
    ancestors: ancestors,
    children: children,
  ),
  axis: axis,
  anchorId: 'x',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TC-UNIVERSE-003 方位角 0 / 仰角 0 正落在屏幕中心（ADR-0006 修订十四）', () {
    // 落位把当前节点放在「正前方」，相机 `yaw = 0` 的视线也正是正前方 ——
    // 这一条断了，进宇宙看见的就是一片空天，而其实什么都没算错。
    final List<ui.Offset> offsets = screenPointsOf(_projection(), <SkyPoint>[
      _point(),
    ]);
    expect(offsets, hasLength(1));
    expect(offsets.single.dx, closeTo(_size.width / 2, 0.001));
    expect(offsets.single.dy, closeTo(_size.height / 2, 0.001));
  });

  test('TC-UNIVERSE-004 方位角加在右边、仰角加在上边（ADR-0006 修订十四）', () {
    // 投影层的三处轴口径错一处，点就会上下颠倒或左右镜像 —— 错的方向看着
    // 仍然「像一片天」，只有拿已知方位去对才能发现。
    final List<ui.Offset> offsets = screenPointsOf(_projection(), <SkyPoint>[
      _point(az: 30),
      _point(el: 45),
    ]);
    expect(offsets, hasLength(2));
    expect(offsets[0].dx, greaterThan(_size.width / 2), reason: '方位角 +30° 在右侧');
    expect(offsets[0].dy, closeTo(_size.height / 2, 0.001));
    expect(offsets[1].dx, closeTo(_size.width / 2, 0.001));
    expect(offsets[1].dy, lessThan(_size.height / 2), reason: '仰角 +45° 在上方');
  });

  test('TC-UNIVERSE-005 三条轴取三种互不相同的实色（ADR-0006 修订十四）', () {
    final Set<int> values = <int>{
      for (final Axis axis in Axis.values) axisNodeColor(axis).toARGB32(),
    };
    expect(values, hasLength(Axis.values.length), reason: '三轴撞色等于没有轴色');

    for (final Axis axis in Axis.values) {
      expect(axisNodeColor(axis).a, 1.0, reason: '${axis.name} 的光点不该是半透明的');
    }
  });

  test('TC-UNIVERSE-006 三档点径：当前 > 来路 > 子级（ADR-0006 修订十四）', () {
    // 守的是「别把三档写反」：反了以后当前节点变成最小的那个点，而它恰恰是
    // 唯一恒在视野正中的点。
    expect(universeCurrentDotSize, greaterThan(universeAncestorDotSize));
    expect(universeAncestorDotSize, greaterThan(universeChildDotSize));
    expect(universeChildDotSize, greaterThan(0));
  });

  test('TC-UNIVERSE-007 镜头后方的点被剔除，不画到反方向去（ADR-0006 修订十四）', () {
    // 方位角 ±90° 之外就是背后。球心视角下「背后」没有别的说法 —— 照画的话
    // 会在正前方叠出一个本不该出现的点，看起来像多了个节点。
    final List<ui.Offset> offsets = screenPointsOf(_projection(), <SkyPoint>[
      _point(az: 0),
      _point(az: 90),
      _point(az: 180),
      _point(az: -180),
    ]);
    expect(offsets, hasLength(1), reason: '只有方位角 0 那一个该留下来');
  });

  test(
    'TC-UNIVERSE-008 骨架最大同父 105 个子级不崩；fov 70 下朝前的 54 个全在（ADR-0006 修订十四）',
    () {
      // 105 是实测出来的最大同父子数（专业轴）。这里不假设别的数：少于它，
      // 这一条就测不到「格数用满」的情形。
      //
      // 54 不是拍出来的：12 列里方位角落在 ±90° 以内的有 6 列（±15° / ±45° /
      // ±75°），105 个按列回卷后每列 9 个 —— 6 × 9 = 54。剩下 51 个在背后，
      // 剔除是对的。⚠️ 这个数同时说明一件事：**进来默认只看得见一半子级**，
      // 与视场角有关，与落位无关（见 `ADR-0006` 修订十四的遗留项）。
      final List<SkyPoint> points = <SkyPoint>[
        for (int i = 0; i < 105; i++) childPointOf(index: i, radius: 21),
      ];
      final List<ui.Offset> offsets = screenPointsOf(_projection(), points);
      expect(offsets, hasLength(54));
    },
  );

  test('TC-UNIVERSE-009 半径不改变屏幕位置（球心视角，ADR-0006 修订十四）', () {
    // 相机在球心 ⇒ 投影只看方向。半径要真能改变屏幕位置，说明有人在投影里
    // 混进了平移 —— 而平移会让同心球壳的透视整个崩掉（`ADR-0006` 决策 2）。
    final List<ui.Offset> offsets = screenPointsOf(_projection(), <SkyPoint>[
      _point(radius: 8, az: 30, el: 20),
      _point(radius: 55.1, az: 30, el: 20),
    ]);
    expect(offsets, hasLength(2));
    expect(offsets[0].dx, closeTo(offsets[1].dx, 0.001));
    expect(offsets[0].dy, closeTo(offsets[1].dy, 0.001));
  });

  test('TC-UNIVERSE-010 算不出落位时一个像素都不画（ADR-0006 修订十四）', () async {
    // 空天不等于错误：树没装载时只留星空，不该有一层看不见但存在的东西。
    expect(await _inkedPixels(universe: null), 0);
    // 反向对照：同样的画布，给一个节点就应该有像素 —— 否则上面那个 0 是
    // 「画布根本没工作」而不是「确实没画」。
    expect(await _inkedPixels(universe: _universe()), greaterThan(0));
  });
}

/// 画一遍，数出有多少个非透明像素。
Future<int> _inkedPixels({required UniverseView? universe}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  SkyNodesPainter(
    view: _View(yaw: 0, pitch: 0, fovDeg: 70),
    universe: universe,
  ).paint(canvas, _size);
  final ui.Image image = await recorder.endRecording().toImage(
    _size.width.toInt(),
    _size.height.toInt(),
  );
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  image.dispose();
  if (data == null) {
    return 0;
  }
  int inked = 0;
  for (int i = 3; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i) != 0) {
      inked++;
    }
  }
  return inked;
}

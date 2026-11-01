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
  SkyAggregate? aggregate,
  Axis axis = Axis.discipline,
}) => UniverseView(
  layout: UniverseLayout(
    current: current ?? _point(),
    ancestors: ancestors,
    // 逐位对齐的 id：只影响亮度查表，不影响坐标，因此按序号造即可。
    ancestorIds: <String>[
      for (int i = 0; i < ancestors.length; i++) 'ancestor-$i',
    ],
    children: children,
    aggregate: aggregate,
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
  test('TC-UNIVERSE-011 亮度分档单调不减、端点落对（ADR-0006 修订十五）', () {
    // 分档只为一件事：让 paint 能复用。但「谁比谁亮」这个顺序不能被分档改掉 ——
    // 改了的话，界面会显示成「学得更多反而更暗」。
    expect(brightnessStepOf(0), 0);
    expect(brightnessStepOf(1), universeBrightnessSteps - 1);
    int previous = -1;
    for (double b = 0; b <= 1.0001; b += 0.02) {
      final int step = brightnessStepOf(b);
      expect(step, greaterThanOrEqualTo(previous), reason: '亮度 $b 的档位回退了');
      previous = step;
    }
    // 越界不炸：调用方从没保证过 0..1（浮点累加会出 1.0000000000000002）。
    expect(brightnessStepOf(1.4), universeBrightnessSteps - 1);
    expect(brightnessStepOf(-0.4), 0);
  });

  test('TC-UNIVERSE-012 未学仍留可见下限，全学满才到满不透明（ADR-0006 修订十五）', () {
    // 未学不是「不透明度 0」：一片没学过的天会变成空的，与新用户分不清
    // 「还没学」和「没装载」。
    expect(alphaFactorOfStep(0), closeTo(universeBrightnessFloor, 1e-9));
    expect(alphaFactorOfStep(universeBrightnessSteps - 1), closeTo(1, 1e-9));
    for (int i = 1; i < universeBrightnessSteps; i++) {
      expect(alphaFactorOfStep(i), greaterThan(alphaFactorOfStep(i - 1)));
    }
  });

  test('TC-UNIVERSE-013 取不到数据比「确实没学」更亮（ADR-0006 修订十五）', () async {
    // `null` 是「不知道」，空表是「知道了，一项都没学」。两者画成一样的话，
    // 日志读不出来时界面就在说「你什么都没学」——那是假话。
    final double unknown = await _inkAlpha(
      universe: _universe(),
      brightness: null,
    );
    final double none = await _inkAlpha(
      universe: _universe(),
      brightness: <String, double>{'x': 0},
    );
    final double all = await _inkAlpha(
      universe: _universe(),
      brightness: <String, double>{'x': 1},
    );
    expect(none, greaterThan(0), reason: '未学也不该一点像素都不留');
    expect(unknown, greaterThan(none));
    expect(all, greaterThan(unknown));
  });

  group('聚合点（B17b 笔 6）', () {
    SkyAggregate aggregateOf(List<String> ids) =>
        SkyAggregate(point: _point(), memberIds: ids);

    test('TC-UNIVERSE-036 聚合点的字是「+N」，N 是被合并的个数（ADR-0006 修订十七）', () {
      final SkyAggregate aggregate = aggregateOf(<String>['a', 'b', 'c']);
      expect(aggregate.count, 3);
      expect(aggregateLabelOf(aggregate), '+3');
    });

    test('TC-UNIVERSE-037 取不到亮度表时，聚合点走「不知道」那一档（ADR-0006 修订十七）', () {
      // 与单点口径一致：整张表为 null 是「取不到学习数据」，
      // 不能拿它当「成员都没学过」——那是 `C-145` 要分开的两件事。
      expect(
        aggregateAlphaFactorOf(aggregateOf(<String>['a', 'b']), null),
        alphaFactorOfStep(brightnessStepOf(universeBrightnessUnknown)),
      );
    });

    test('TC-UNIVERSE-038 聚合点的亮度取成员均值（ADR-0006 修订十七）', () {
      expect(
        aggregateAlphaFactorOf(
          aggregateOf(<String>['a', 'b']),
          <String, double>{'a': 1.0, 'b': 0.0},
        ),
        alphaFactorOfStep(brightnessStepOf(0.5)),
      );
    });

    test('TC-UNIVERSE-039 成员里查不到亮度的按 0 计，不跳过（ADR-0006 修订十七）', () {
      // 跳过的话「a = 1.0、b 缺失」会算成 1.0（全亮），而实际只学了一半 ——
      // 与单点口径 `table[id] ?? 0` 对齐。
      expect(
        aggregateAlphaFactorOf(
          aggregateOf(<String>['a', 'b']),
          <String, double>{'a': 1.0},
        ),
        alphaFactorOfStep(brightnessStepOf(0.5)),
      );
    });

    test('TC-UNIVERSE-040 空成员表不除零：有表按 0 档，无表按「不知道」（ADR-0006 修订十七）', () {
      // 正常路径构造不出空成员（聚合要 >120 个才出现，count ≥ 2），
      // 这条守的是函数本身别在边界上抛。
      final SkyAggregate empty = aggregateOf(const <String>[]);
      expect(
        aggregateAlphaFactorOf(empty, <String, double>{}),
        alphaFactorOfStep(brightnessStepOf(0)),
      );
      expect(
        aggregateAlphaFactorOf(empty, null),
        alphaFactorOfStep(brightnessStepOf(universeBrightnessUnknown)),
      );
    });
  });

  group('命中判定（B17b 笔 7 的可下钻目标）', () {
    /// 某个落位点在屏幕上的位置。
    ui.Offset screenOf(SkyPoint point) =>
        _projection().project(directionOfSkyPoint(point))!;

    test('TC-UNIVERSE-050 点中子级点返回它的 id（ADR-0006 修订十八）', () {
      final UniverseView universe = _universe(
        children: <String, SkyPoint>{'c1': _point()},
      );
      // 子级落在正前方 ⇒ 屏幕中心。
      expect(screenOf(_point()).dx, closeTo(_size.width / 2, 0.5));
      expect(
        hitTestChildAt(_projection(), universe, screenOf(_point())),
        'c1',
        reason: '点中了却返回 null，等于宇宙里一颗都下钻不了',
      );
    });

    test('TC-UNIVERSE-051 超出判定半径返回 null，不误伤邻近的空白处（ADR-0006 修订十八）', () {
      final UniverseView universe = _universe(
        children: <String, SkyPoint>{'c1': _point()},
      );
      final ui.Offset center = screenOf(_point());
      // 半径 = 点径 + 容差；往外再多 2 px 就不该命中。
      final ui.Offset outside = center.translate(
        0,
        universeChildDotSize + universeHitSlopPx + 2,
      );
      expect(hitTestChildAt(_projection(), universe, outside), isNull);
      // 边界之内仍要命中：容差是给手指留的，不是给空白留的。
      final ui.Offset inside = center.translate(
        0,
        universeChildDotSize + universeHitSlopPx - 2,
      );
      expect(hitTestChildAt(_projection(), universe, inside), 'c1');
    });

    test('TC-UNIVERSE-052 两个子级都够近时取屏幕上更近的那个（ADR-0006 修订十八）', () {
      // 方位角差 1°：fov 70° / 800 px 宽 ≈ 9 px，两个判定圈会重叠。
      final SkyPoint near = _point(az: 0);
      final SkyPoint far = _point(az: 1);
      final UniverseView universe = _universe(
        children: <String, SkyPoint>{'near': near, 'far': far},
      );
      final ui.Offset a = screenOf(near);
      final ui.Offset b = screenOf(far);
      // 取靠近 far 的那一边，但仍在 near 的判定圈内 —— 两个都算候选。
      final ui.Offset between = ui.Offset.lerp(a, b, 0.7)!;
      expect(
        hitTestChildAt(_projection(), universe, between),
        'far',
        reason: '两根手指点不中一颗，模型只能取「离指尖更近的那一颗」',
      );
    });

    test('TC-UNIVERSE-053 当前节点与来路不可下钻，只有子级是目标（ADR-0006 修订十八）', () {
      // 当前节点在正前方、来路在它旁边，子级放在 20° 外。
      final UniverseView universe = _universe(
        ancestors: <SkyPoint>[_point(az: 3)],
        children: <String, SkyPoint>{'c1': _point(az: 20)},
      );
      expect(
        hitTestChildAt(_projection(), universe, screenOf(_point())),
        isNull,
        reason: '点当前节点不该触发下钻 —— 它已经是「你在这」',
      );
      expect(
        hitTestChildAt(_projection(), universe, screenOf(_point(az: 20))),
        'c1',
        reason: '同一条用例里子级仍要命中，否则这条只证明了「什么都不响应」',
      );
    });
  });
}

/// 画一遍，数出有多少个非透明像素。
Future<int> _inkedPixels({
  required UniverseView? universe,
  Map<String, double>? brightness,
}) async {
  final ByteData? data = await _render(
    universe: universe,
    brightness: brightness,
  );
  int inked = 0;
  for (int i = 3; i < data!.lengthInBytes; i += 4) {
    if (data.getUint8(i) != 0) {
      inked++;
    }
  }
  return inked;
}

/// 画一遍，把全部像素的 alpha 加起来 —— 亮度差表现为 alpha 差，像素数看不出。
Future<double> _inkAlpha({
  required UniverseView? universe,
  Map<String, double>? brightness,
}) async {
  final ByteData? data = await _render(
    universe: universe,
    brightness: brightness,
  );
  double total = 0;
  for (int i = 3; i < data!.lengthInBytes; i += 4) {
    total += data.getUint8(i);
  }
  return total;
}

Future<ByteData?> _render({
  required UniverseView? universe,
  Map<String, double>? brightness,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  SkyNodesPainter(
    view: _View(yaw: 0, pitch: 0, fovDeg: 70),
    universe: universe,
    brightness: brightness,
  ).paint(canvas, _size);
  final ui.Image image = await recorder.endRecording().toImage(
    _size.width.toInt(),
    _size.height.toInt(),
  );
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  image.dispose();
  return data;
}

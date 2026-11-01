/// 节点标注层的用例（`B17b` 笔 5）。
///
/// 守四件事：**fov 阈值是硬边界**、**当前与来路不被条数上限挤掉**、
/// **截断结果与遍历顺序无关**、**文字只排版一次**。
///
/// 最后一类（缓存）是这个文件的重心：没有缓存的话一屏 60 条每帧要重建
/// 60 个 `Paragraph`，帧时间直接打满 —— 而这件事在画面上完全看不出来，
/// 只能靠 `hits` / `misses` 断言。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/universe/placement.dart';
import 'package:project_knowledge/features/universe/presentation/constellations.dart';
import 'package:project_knowledge/features/universe/presentation/sky_labels.dart';
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

SkyProjection _projection({double fovDeg = 50}) => SkyProjection(
  view: _View(yaw: 0, pitch: 0, fovDeg: fovDeg),
  size: _size,
);

/// 造一份落位：当前在正前方、来路沿走廊、子级按格心铺开。
UniverseLayout _layout({
  int ancestorCount = 0,
  int childCount = 0,
  bool withNames = true,
}) {
  final List<SkyPoint> ancestors = <SkyPoint>[
    for (int i = 0; i < ancestorCount; i++)
      SkyPoint(radius: 8, azimuthDeg: 0, elevationDeg: ancestorElevationOf(i)),
  ];
  final Map<String, SkyPoint> children = <String, SkyPoint>{
    for (int i = 0; i < childCount; i++)
      'c$i': childPointOf(index: i, radius: 13),
  };
  return UniverseLayout(
    current: const SkyPoint(radius: 8, azimuthDeg: 0, elevationDeg: 0),
    ancestors: ancestors,
    ancestorIds: <String>[for (int i = 0; i < ancestorCount; i++) 'a$i'],
    children: children,
    names: withNames
        ? <String, String>{
            'cur': '当前',
            for (int i = 0; i < ancestorCount; i++) 'a$i': '来路$i',
            for (int i = 0; i < childCount; i++) 'c$i': '子级$i',
          }
        : const <String, String>{},
  );
}

UniverseView _universe(UniverseLayout layout) =>
    UniverseView(layout: layout, axis: Axis.discipline, anchorId: 'cur');

List<SkyLabel> _targets(UniverseLayout layout, {double fovDeg = 50}) =>
    labelTargetsOf(
      layout: layout,
      projection: _projection(fovDeg: fovDeg),
      size: _size,
      anchorId: 'cur',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TC-UNIVERSE-021 fov 超过阈值一条都不画，等于阈值才画（ADR-0006 修订十六）', () async {
    // 阈值是硬边界不是渐变：广角下一屏几十个点挤在一起，标了也是糊的。
    // 这一条断了会表现为「一进来满屏名字」，而没人会把它当成 bug 去查。
    final UniverseLayout layout = _layout(childCount: 6);
    final SkyLabelCache cache = SkyLabelCache();

    expect(
      await _inkedPixels(
        fovDeg: universeLabelFovDeg + 1,
        universe: _universe(layout),
        cache: cache,
      ),
      0,
      reason: 'fov 大于阈值时不该有一个像素',
    );
    expect(
      await _inkedPixels(
        fovDeg: universeLabelFovDeg,
        universe: _universe(layout),
        cache: cache,
      ),
      greaterThan(0),
      reason: 'fov 正好等于阈值时必须画 —— 边界取闭区间',
    );
    cache.dispose();
  });

  test('TC-UNIVERSE-022 当前与来路恒标，子级按屏幕距离补满上限（ADR-0006 修订十六）', () {
    // 最大同父实测 105 个子级，必然超上限。挤掉的必须是**子级里远的那些**，
    // 不能是当前节点 —— 当前节点的名字被挤掉，用户就不知道自己站在哪。
    final UniverseLayout layout = _layout(ancestorCount: 3, childCount: 105);
    final List<SkyLabel> targets = _targets(layout);

    // 先算出「屏幕上有几个子级」：落在镜头后方的子级本来就不显示，也不该标。
    // 所以 60 是上限而不是保证 —— fov 50° 时只有 54 个进得了画面。
    final SkyProjection projection = _projection();
    final ui.Offset middle = _size.center(ui.Offset.zero);
    final List<MapEntry<String, double>> visible = <MapEntry<String, double>>[];
    layout.children.forEach((String id, SkyPoint point) {
      final ui.Offset? offset = projection.project(directionOfSkyPoint(point));
      if (offset != null) {
        visible.add(MapEntry<String, double>(id, (offset - middle).distance));
      }
    });
    expect(
      visible.length,
      lessThan(layout.children.length),
      reason: '必然有子级在镜头后方',
    );
    visible.sort(
      (MapEntry<String, double> a, MapEntry<String, double> b) =>
          a.value != b.value
          ? a.value.compareTo(b.value)
          : a.key.compareTo(b.key),
    );

    const int pinned = 4;
    final int expectedCount = visible.length + pinned > universeLabelMaxCount
        ? universeLabelMaxCount
        : visible.length + pinned;
    expect(targets, hasLength(expectedCount));
    expect(targets.take(pinned).map((SkyLabel l) => l.id), <String>[
      'cur',
      'a0',
      'a1',
      'a2',
    ], reason: '当前在最前、来路按由近到远紧跟其后，一条都不许被挤掉');

    // 只断言条数不够：条数对了但取的是最远的那些，同样是一条坏实现。
    // 真正要守的是「保留集合等于最近的若干个」。
    const int budget = universeLabelMaxCount - pinned;
    final Set<String> expected = visible
        .take(budget)
        .map((MapEntry<String, double> e) => e.key)
        .toSet();
    expect(
      targets.skip(pinned).map((SkyLabel l) => l.id).toSet(),
      expected,
      reason: '补进来的必须是离屏幕中心最近的那批',
    );
  });

  test('TC-UNIVERSE-023 同一份布局两次算出的保留集合完全一致（ADR-0006 修订十六）', () {
    // 距离相同时若不按 id 兜底，保留集合会随 Map 的遍历顺序抖动 ——
    // 表现为「同一个视角，两帧之间标注会闪」。点重合的子级必然有距离相同的。
    final UniverseLayout layout = _layout(ancestorCount: 2, childCount: 105);
    final List<String> first = _targets(layout)
        .map((SkyLabel l) => l.id)
        .toList();
    final List<String> second = _targets(layout)
        .map((SkyLabel l) => l.id)
        .toList();
    expect(second, first);
  });

  test('TC-UNIVERSE-024 同一段文字只排版一次（ADR-0006 修订十六 · LRU）', () {
    // 「每帧重建 Paragraph」在画面上看不出来，只体现在帧时间 ——
    // 而这是 `ADR-0006` 唯一实测过的负载维度。
    final SkyLabelCache cache = SkyLabelCache();
    const ui.Color color = ui.Color(0xFF000000);

    final ui.Paragraph first = cache.paragraphOf('语文', color);
    expect(cache.misses, 1);
    expect(cache.hits, 0);

    final ui.Paragraph second = cache.paragraphOf('语文', color);
    expect(identical(first, second), isTrue, reason: '第二次必须是同一个实例');
    expect(cache.misses, 1, reason: '不许重新排版');
    expect(cache.hits, 1);
    cache.dispose();
  });

  test('TC-UNIVERSE-025 缓存超过上限时淘汰最久未用（ADR-0006 修订十六）', () {
    // 上限 200 条。不做淘汰的话，视角转一圈缓存会无界增长；
    // 而淘汰错端（去掉刚用过的）会让每帧命中率掉到 0，等于没缓存。
    final SkyLabelCache cache = SkyLabelCache();
    const ui.Color color = ui.Color(0xFF000000);
    for (int i = 0; i < universeLabelCacheLimit; i++) {
      cache.paragraphOf('词$i', color);
    }
    expect(cache.length, universeLabelCacheLimit);

    // 复用第 0 条，让它变成「最近使用」，再塞一条新的把别人挤掉。
    cache.paragraphOf('词0', color);
    final int missesBefore = cache.misses;
    cache.paragraphOf('新词', color);

    expect(cache.length, universeLabelCacheLimit, reason: '超出上限要淘汰，不是扩容');
    expect(cache.misses, missesBefore + 1);
    // 第 1 条最久未用，已被淘汰；再取它必定 miss。
    cache.paragraphOf('词1', color);
    expect(cache.misses, missesBefore + 2, reason: '被淘汰的应当是最久未用的那条');
    cache.dispose();
  });

  test('TC-UNIVERSE-026 颜色变化时整个缓存作废（ADR-0006 修订十六）', () {
    // 键只有文字。不整表作废的话，换了轴色仍会取到旧颜色的排版结果 ——
    // 表现为「换了学科，名字还是上一个学科的颜色」。
    final SkyLabelCache cache = SkyLabelCache();
    const ui.Color warm = ui.Color(0xFFFF0000);
    const ui.Color cold = ui.Color(0xFF0000FF);

    cache.paragraphOf('语文', warm);
    cache.paragraphOf('数学', warm);
    expect(cache.length, 2);

    cache.paragraphOf('语文', cold);
    expect(cache.length, 1, reason: '颜色一变应清空后只留这一条');
    expect(cache.misses, 3);
    cache.dispose();
  });

  test('TC-UNIVERSE-027 标签落在点的右上方，不压住点本身（ADR-0006 修订十六）', () {
    // 段 4 的星座名把字压在图形中央、线从字上穿过（ADR-0006:303）。
    // 一个点旁边写名字，唯一的错法就是压住点 —— 那条遗留问题不许重犯。
    const SkyLabel label = SkyLabel(
      id: 'x',
      text: '语文',
      center: ui.Offset(400, 300),
      dotRadius: universeChildDotSize,
    );
    expect(label.anchor.dx, greaterThan(label.center.dx), reason: '往右');
    expect(label.anchor.dy, lessThan(label.center.dy), reason: '往上');
    // 偏移必须把点径算进去：大点的晕半径更大，贴边画会被晕吃掉半行字。
    expect(
      label.anchor.dx - label.center.dx,
      greaterThanOrEqualTo(universeLabelGapPx),
    );
    expect(
      label.anchor.dy - label.center.dy,
      lessThanOrEqualTo(-universeLabelGapPx),
    );
  });

  test('TC-UNIVERSE-028 名字缺失时跳过，不画空串也不抛（ADR-0006 修订十六）', () {
    // 树里查不到这个 id、或那张表根本没装 —— 结果是「这个点没有名字」，
    // 不是往屏幕上写一个空串，也不是抛出来把整片天弄没。
    expect(_targets(_layout(childCount: 4, withNames: false)), isEmpty);

    final UniverseLayout partial = UniverseLayout(
      current: const SkyPoint(radius: 8, azimuthDeg: 0, elevationDeg: 0),
      ancestors: const <SkyPoint>[],
      ancestorIds: const <String>[],
      children: const <String, SkyPoint>{
        '有名字': SkyPoint(radius: 13, azimuthDeg: 0, elevationDeg: 10),
        '没名字': SkyPoint(radius: 13, azimuthDeg: 0, elevationDeg: -10),
      },
      names: const <String, String>{'有名字': '有名字'},
    );
    final List<SkyLabel> targets = labelTargetsOf(
      layout: partial,
      projection: _projection(),
      size: _size,
      anchorId: 'cur',
    );
    expect(targets, hasLength(1), reason: '缺名字的那个不进标注，另一个照画');
    expect(targets.single.text, '有名字');
  });
}

/// 画一遍，数出有多少个非透明像素。
Future<int> _inkedPixels({
  required double fovDeg,
  required UniverseView universe,
  required SkyLabelCache cache,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  SkyLabelsPainter(
    view: _View(yaw: 0, pitch: 0, fovDeg: fovDeg),
    universe: universe,
    cache: cache,
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

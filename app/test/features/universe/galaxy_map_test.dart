/// `Z0` 星系布局与绘制的判据（`SPEC-VIEW-036` · `V-1b`）。
///
/// 这一层全是纯函数，所以断言不用起 widget：盘半径比值、确定性、遮挡、
/// 点击命中都能直接算。widget 侧只验「屏幕上真有几个星系」与「点它换根」，
/// 那些在 `universe_screen_test.dart` 里。
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/features/universe/galaxy_map.dart';
import 'package:project_knowledge/features/universe/galaxy_painter.dart';
import 'package:project_knowledge/features/universe/scene_source.dart';

import '../../support/pack_fixture.dart';

/// 一个「N 项 / M 域」的空间，只用来喂布局。
LoadedPack _pack(String spaceId, int itemCount, {int domains = 2}) => fixturePack(
  <FixtureItem>[
    for (int i = 0; i < itemCount; i++)
      FixtureItem(
        '$spaceId-$i',
        '$spaceId 第 $i 项',
        domainId: '$spaceId/d${i % domains}',
      ),
  ],
  spaceId: spaceId,
  spaceName: spaceId,
);

SceneResolution _root(LoadedPack pack) => SceneResolution(
  bundle: buildSyntheticScene(),
  pack: pack,
);

/// 三个空间的默认盘子（150 / 80 / 80）—— 与三个真实内容空间的项数同形。
List<SceneResolution> _threeSpaces() => <SceneResolution>[
  _root(_pack('python', 150, domains: 10)),
  _root(_pack('english', 80, domains: 8)),
  _root(_pack('german', 80, domains: 8)),
];

const Size _viewport = Size(800, 600);

/// 记录绘制指令 —— 于是「画了几个盘」「谁描了边」是断言出来的，不是看截图猜的。
class _RecordingTarget implements GalaxyDrawTarget {
  final List<({double x, double y, double rx, double ry, bool rim})> ops =
      <({double x, double y, double rx, double ry, bool rim})>[];

  @override
  void disc({
    required double x,
    required double y,
    required double rx,
    required double ry,
    required int argb,
    required bool rim,
  }) {
    ops.add((x: x, y: y, rx: rx, ry: ry, rim: rim));
  }
}

void main() {
  group('Z0 星系布局（SPEC-VIEW-036）', () {
    test('一个空间一个星系；主星系居中、其余按项数降序（SPEC-VIEW-036）', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: _viewport,
      );

      expect(layout.discs.length, 3, reason: '一个 KnowledgeSpace 一个星系');
      expect(
        layout.discs.map((GalaxyDisc d) => d.spaceId).toList(),
        <String>['python', 'english', 'german'],
        reason: '主星系是项数最多的那个；矮星系从大到小排（并列按 id）',
      );
      expect(layout.discs.first.centerX, _viewport.width / 2);
      expect(layout.discs.first.centerY, _viewport.height / 2);
      // 盘中心两两不同 —— 都堆在圆心就不叫成团构型了。
      expect(
        layout.discs.map((GalaxyDisc d) => d.centerX).toSet().length,
        3,
      );
    });

    test('盘半径承载**比值**：r_i / r_j = √(n_i / n_j)（容差 5%）（SPEC-VIEW-036）', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: _viewport,
      );
      final GalaxyDisc python = layout.discOf('python')!;
      final GalaxyDisc english = layout.discOf('english')!;

      const double expected = 150 / 80;
      final double actual =
          (python.radius * python.radius) / (english.radius * english.radius);
      expect(
        (actual - expected).abs() / expected,
        lessThan(0.05),
        reason: 'r = k·√n ⇒ r² 之比 = 项数之比',
      );
    });

    test('分布确定性：同一输入两次布局，坐标逐分量相等（SPEC-VIEW-036）', () {
      final GalaxyLayout a = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: _viewport,
      );
      final GalaxyLayout b = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: _viewport,
      );

      for (int i = 0; i < a.discs.length; i++) {
        expect(a.discs[i].spaceId, b.discs[i].spaceId);
        expect(a.discs[i].centerX, b.discs[i].centerX);
        expect(a.discs[i].centerY, b.discs[i].centerY);
        expect(a.discs[i].radius, b.discs[i].radius);
      }
    });

    test('盘半径不低于 C-53 下限，且不判退化', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: _viewport,
      );

      expect(layout.degenerate, isFalse);
      for (final GalaxyDisc disc in layout.discs) {
        expect(
          disc.radius,
          greaterThanOrEqualTo(spacePlateMinRadiusPx - 1e-9),
          reason: '低于 40 px 时旋臂画不出（观测上退化为一个点）',
        );
      }
    });

    test('视口小到 k 触底 ⇒ 判退化，且盘按 C-53 下限画', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: const Size(240, 240),
      );

      expect(layout.degenerate, isTrue, reason: 'VIEW-036：该档应改为列表式');
      for (final GalaxyDisc disc in layout.discs) {
        expect(
          disc.radius,
          greaterThanOrEqualTo(spacePlateMinRadiusPx - 1e-9),
          reason: '退化不等于把盘画没 —— 仍按最下半径画，并另给提示',
        );
      }
    });

    test('没有包的根不出星系（不凭空造空间）（SPEC-VIEW-036）', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: <SceneResolution>[
          SceneResolution(bundle: buildSyntheticScene()),
        ],
        viewport: _viewport,
      );

      expect(layout.isEmpty, isTrue);
      expect(layout.degenerate, isFalse, reason: '空布局不构成退化');
    });

    test('标注口径：space.id 首字母大写，副行给项数与域数（SPEC-VIEW-036）', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: _viewport,
      );

      expect(layout.discOf('python')!.label, 'Python');
      expect(layout.discOf('python')!.itemCount, 150);
      expect(layout.discOf('python')!.domainCount, 10);
    });
  });

  group('Z0 绘制与拾取（SPEC-VIEW-036）', () {
    test('一个盘一次绘制，且**不画均分圆**（SPEC-VIEW-036）', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: _viewport,
      );
      final _RecordingTarget target = _RecordingTarget();

      paintGalaxies(target: target, layout: layout);

      expect(target.ops.length, layout.discs.length);
      // 均分圆的特征是**圆心不在任何星系中心上**（它绕的是构型中心）。
      // 所以「每个 op 的圆心都等于某个盘的中心」就排除了它。
      final Set<String> centers = <String>{
        for (final GalaxyDisc disc in layout.discs)
          '${disc.centerX.toStringAsFixed(6)},${disc.centerY.toStringAsFixed(6)}',
      };
      for (final ({double x, double y, double rx, double ry, bool rim}) op
          in target.ops) {
        expect(
          centers.contains(
            '${op.x.toStringAsFixed(6)},${op.y.toStringAsFixed(6)}',
          ),
          isTrue,
          reason: '画出来会被读成「公转轨道」—— 间距本来不是等分的',
        );
      }
    });

    test('未被遮不描边；被遮才描边（SPEC-VIEW-036）', () {
      final GalaxyLayout clear = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: _viewport,
      );
      final _RecordingTarget clearTarget = _RecordingTarget();
      paintGalaxies(target: clearTarget, layout: clear);
      expect(
        clearTarget.ops.every((({double x, double y, double rx, double ry, bool rim}) op) => !op.rim),
        isTrue,
        reason: '每个盘都描边会让轮廓失去信息量',
      );

      // 240×240 下盘半径触底、构型半径缩小 ⇒ 矮星系压在主星系上。
      final GalaxyLayout packed = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: const Size(240, 240),
      );
      expect(
        packed.discs.where((GalaxyDisc d) => d.occluded).length,
        greaterThanOrEqualTo(1),
        reason: '这一形状下必然发生遮挡',
      );
      final _RecordingTarget packedTarget = _RecordingTarget();
      paintGalaxies(target: packedTarget, layout: packed);
      for (int i = 0; i < packed.discs.length; i++) {
        expect(
          packedTarget.ops[i].rim,
          packed.discs[i].occluded,
          reason: '描边跟着遮挡标志走，不是「画好看点」',
        );
      }
    });

    test('点圆心命中该星系；点空白返回 null（SPEC-VIEW-036）', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: _viewport,
      );

      for (final GalaxyDisc disc in layout.discs) {
        expect(
          pickGalaxyAt(layout: layout, point: disc.center),
          disc.spaceId,
        );
      }
      expect(pickGalaxyAt(layout: layout, point: Offset.zero), isNull);
    });

    test('重叠区命中**最近**那个（绘制序在前）（SPEC-VIEW-036）', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: const Size(240, 240),
      );
      final GalaxyDisc main = layout.discs.first;
      final GalaxyDisc buried = layout.discs[1];
      final Offset between = Offset(
        (main.centerX + buried.centerX) / 2,
        (main.centerY + buried.centerY) / 2,
      );

      expect(
        pickGalaxyAt(layout: layout, point: between),
        main.spaceId,
        reason: 'VIEW-036：重叠区点中前面那个是可接受的',
      );
    });

    test('点击目标不小于 24 px（C-53 兜底后仍成立）', () {
      final GalaxyLayout layout = layoutGalaxies(
        roots: _threeSpaces(),
        viewport: const Size(240, 240),
      );

      for (final GalaxyDisc disc in layout.discs) {
        expect(
          disc.radius * 2,
          greaterThanOrEqualTo(galaxyMinTapDiameter),
          reason: '看得见点不中是这一档最坏的失效形态',
        );
      }
    });
  });
}

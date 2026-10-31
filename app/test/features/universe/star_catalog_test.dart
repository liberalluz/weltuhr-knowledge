import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/features/universe/presentation/star_catalog.dart';

/// Hipparcos 主表解析的用例。
///
/// 星表一旦解析错，画面上**看不出错** —— 星星会照样铺满天空，只是位置全错、
/// 亮度全错，而那种错只有在「抬头找不到北斗」的时候才暴露。所以这里逐条对着
/// 已知恒星的公开数据核，不核「总数对不对」就算完。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 全量读一次给所有用例共用 —— 118,218 行、解压后约 60 MB，
  /// 每条用例各读一次会让这套测试慢到没人愿意跑。
  late StarCatalog catalog;
  setUpAll(() async {
    catalog = await loadHipparcosCatalog(cwd: Directory.current.path);
  });

  test('TC-SPIKE-007 全表 118,218 行，其中 118,217 颗有星等（ADR-0006 决策表·背景）', () {
    expect(catalog.rows, kHipparcosRowCount);
    expect(catalog.stars.length, kHipparcosStarCount);
    expect(
      catalog.skipped,
      kHipparcosMissingMagCount,
      reason: '实测只有 1 条缺 vmag；缺星等就画不出亮度，整条跳过',
    );
    expect(catalog.objects, catalog.stars.length + catalog.skipped);
  });

  test('TC-SPIKE-008 六颗已知恒星的坐标与星等对得上（ADR-0006 决策表·背景）', () {
    final Map<int, StarRecord> byHip = <int, StarRecord>{
      for (final StarRecord star in catalog.stars) star.hip: star,
    };

    // 每行：HIP 号、名称、赤经（度）、赤纬（度）、视星等。数值取自表内实测。
    const List<(int, String, double, double, double)> expected =
        <(int, String, double, double, double)>[
          (32349, '天狼星', 101.28854105, -16.71314306, -1.44),
          (91262, '织女星', 279.23410832, 38.78299311, 0.03),
          (69673, '大角星', 213.91811403, 19.18726997, -0.05),
          (27989, '参宿四', 88.79287161, 7.40703634, 0.45),
          (54061, '天枢（北斗一）', 165.93265365, 61.75111888, 1.81),
          (11767, '北极星', 37.94614689, 89.26413805, 1.97),
        ];

    for (final (int hip, String name, double ra, double dec, double mag)
        in expected) {
      final StarRecord? star = byHip[hip];
      expect(star, isNotNull, reason: 'HIP $hip $name 应在表内');
      expect(star!.raDeg, closeTo(ra, 1e-6), reason: 'HIP $hip $name 赤经');
      expect(star.decDeg, closeTo(dec, 1e-6), reason: 'HIP $hip $name 赤纬');
      expect(star.vMag, closeTo(mag, 1e-6), reason: 'HIP $hip $name 星等');
    }
  });

  test('TC-SPIKE-009 全表最亮的是天狼星（ADR-0006 决策表·背景）', () {
    final StarRecord brightest = catalog.stars.reduce(
      (StarRecord a, StarRecord b) => a.vMag <= b.vMag ? a : b,
    );

    expect(brightest.hip, 32349);
    expect(brightest.vMag, closeTo(-1.44, 1e-6));
  });

  test('TC-SPIKE-010 所有坐标落在定义域内（ADR-0006 决策表·背景）', () {
    for (final StarRecord star in catalog.stars) {
      expect(
        star.raDeg,
        inInclusiveRange(0.0, 360.0),
        reason: 'HIP ${star.hip} 赤经越界 ⇒ 列位置错了',
      );
      expect(star.raDeg, lessThan(360.0), reason: '赤经是 [0, 360)');
      expect(star.decDeg, inInclusiveRange(-90.0, 90.0));
    }
  });

  test('TC-SPIKE-011 缺星等的记录整条跳过，不编一个亮度（ADR-0006 决策表·背景）', () {
    final String text = _tdat(<List<String>>[
      <String>['HIP 1', '10.0', '20.0', '1', ''],
      <String>['HIP 32349', '101.28854105', '-16.71314306', '32349', '-1.44'],
    ]);

    final StarCatalog parsed = parseHipparcos(text);

    expect(parsed.rows, 2);
    expect(parsed.skipped, 1, reason: '第四列空 = 缺 vmag，算跳过');
    expect(parsed.stars.single.hip, 32349);
    expect(parsed.stars.single.vMag, closeTo(-1.44, 1e-9));
  });

  test('TC-SPIKE-023 坐标越界的记录整条跳过（ADR-0006 决策表·背景）', () {
    final String text = _tdat(<List<String>>[
      <String>['HIP 2', '400.0', '20.0', '2', '5.0'],
      <String>['HIP 3', '10.0', '-91.0', '3', '5.0'],
      <String>['HIP 4', '10.0', '20.0', '4', '5.0'],
    ]);

    final StarCatalog parsed = parseHipparcos(text);

    expect(parsed.skipped, 2);
    expect(parsed.stars.single.hip, 4);
  });

  test('TC-SPIKE-024 表头缺必需字段就抛，不静默错位（ADR-0006 决策表·背景）', () {
    // 去掉 `ra` 这一列 —— 硬编码列号的实现会安然无恙地拿错列，
    // 而按名字反查的实现必须当场炸。
    final String text = _tdat(
      <List<String>>[
        <String>['HIP 1', '20.0', '1', '5.0'],
      ],
      fields: <String>['name', 'dec', 'hip_number', 'vmag'],
    );

    expect(() => parseHipparcos(text), throwsFormatException);
  });

  test('TC-SPIKE-025 声明行数与实测不等就抛，不静默少几千颗（ADR-0006 决策表·背景）', () {
    final String text = _tdat(<List<String>>[
      <String>['HIP 1', '10.0', '20.0', '1', '5.0'],
    ], declaredRows: 99);

    expect(() => parseHipparcos(text), throwsFormatException);
  });
}

/// 拼一份最小的 `.tdat`（表头 + 数据 + `<END>`）。
///
/// 字段顺序刻意**不等于**真实表里的顺序：按名字反查的实现必须能扛住任意顺序，
/// 按列号硬编码的实现在这里就会错位。
String _tdat(
  List<List<String>> rows, {
  List<String>? fields,
  int? declaredRows,
}) {
  final List<String> names =
      fields ?? <String>['name', 'ra', 'dec', 'hip_number', 'vmag'];
  final StringBuffer buffer = StringBuffer()
    ..writeln('<HEADER>')
    ..writeln('#         TABLE: heasarc_hipparcos')
    ..writeln('#    TOTAL ROWS: ${declaredRows ?? rows.length}')
    ..writeln('#');
  for (final String name in names) {
    buffer.writeln('field[$name] = char10  // $name');
  }
  buffer.writeln('<DATA>');
  for (final List<String> row in rows) {
    buffer.writeln(row.join('|'));
  }
  buffer.writeln('<END>');
  return buffer.toString();
}

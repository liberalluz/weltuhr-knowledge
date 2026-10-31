import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/spike/star_catalog.dart';

/// `V/50` 星表解析的用例。
///
/// 星表一旦解析错，画面上**看不出错** —— 星星会照样铺满天空，只是位置全错、
/// 亮度全错，而那种错只有在「抬头找不到北斗」的时候才暴露。所以这里逐条对着
/// 已知恒星的公开数据核，不核「总数对不对」就算完。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TC-SPIKE-007 全表 9,110 个对象，其中 9,096 颗有坐标（ADR-0006 决策表·背景）', () async {
    final StarCatalog catalog = await loadBsc5Catalog(
      cwd: Directory.current.path,
    );

    expect(catalog.objects, kBsc5ObjectCount);
    expect(catalog.stars.length, kBsc5StarCount);
    expect(catalog.skipped, 14, reason: '14 个是 1908 年初版保留编号的客星与河外星系，坐标为空');
  });

  test('TC-SPIKE-008 六颗已知恒星的赤经赤纬与星等对得上（ADR-0006 决策表·背景）', () async {
    final StarCatalog catalog = await loadBsc5Catalog(
      cwd: Directory.current.path,
    );
    final Map<int, StarRecord> byHr = <int, StarRecord>{
      for (final StarRecord star in catalog.stars) star.hr: star,
    };

    // 每行：HR 号、名称、赤经（小时）、赤纬（度）、视星等。数值取自星表的公开数据。
    const List<(int, String, double, double, double)> expected =
        <(int, String, double, double, double)>[
          (2491, '天狼星', 6.752472, -16.716111, -1.46),
          (7001, '织女星', 18.615639, 38.783611, 0.03),
          (5340, '大角星', 14.261028, 19.182500, -0.04),
          (1713, '参宿四', 5.242306, -8.201667, 0.12),
          (4301, '天枢（北斗一）', 11.062139, 61.750833, 1.79),
          (4295, '天璇（北斗二）', 11.030694, 56.382500, 2.37),
        ];

    for (final (int hr, String name, double ra, double dec, double mag)
        in expected) {
      final StarRecord? star = byHr[hr];
      expect(star, isNotNull, reason: 'HR $hr $name 应在表内');
      expect(star!.raHours, closeTo(ra, 1e-4), reason: 'HR $hr $name 赤经');
      expect(star.decDeg, closeTo(dec, 1e-4), reason: 'HR $hr $name 赤纬');
      expect(star.vMag, closeTo(mag, 1e-2), reason: 'HR $hr $name 星等');
    }
  });

  test('TC-SPIKE-009 全表最亮的是天狼星（ADR-0006 决策表·背景）', () async {
    final StarCatalog catalog = await loadBsc5Catalog(
      cwd: Directory.current.path,
    );

    final StarRecord brightest = catalog.stars.reduce(
      (StarRecord a, StarRecord b) => (a.vMag ?? 99) <= (b.vMag ?? 99) ? a : b,
    );

    expect(brightest.hr, 2491);
    expect(brightest.vMag, closeTo(-1.46, 1e-6));
  });

  test('TC-SPIKE-010 所有坐标落在定义域内（ADR-0006 决策表·背景）', () async {
    final StarCatalog catalog = await loadBsc5Catalog(
      cwd: Directory.current.path,
    );

    for (final StarRecord star in catalog.stars) {
      expect(
        star.raHours,
        inInclusiveRange(0.0, 24.0),
        reason: 'HR ${star.hr} 赤经越界 ⇒ 列切错了',
      );
      expect(star.raHours, lessThan(24.0), reason: '赤经是 [0, 24)');
      expect(star.decDeg, inInclusiveRange(-90.0, 90.0));
    }
  });

  test('TC-SPIKE-011 坐标缺失的记录整条跳过，不编一个位置（ADR-0006 决策表·背景）', () {
    // 两条合成记录：一条坐标全空（表里那 14 条的形态），一条是真实的天狼星。
    final String blank = _record(hr: 1);
    final String full = _record(
      hr: 2491,
      raHour: '06',
      raMinute: '45',
      raSecond: '08.9',
      decSign: '-',
      decDegree: '16',
      decMinute: '42',
      decSecond: '58',
      vMag: '-1.46',
      bv: '+0.00',
    );

    final StarCatalog catalog = parseBsc5('$blank\n$full\n');

    expect(catalog.skipped, 1, reason: '坐标空的算跳过，不算恒星');
    expect(catalog.stars.length, 1);
    final StarRecord star = catalog.stars.single;
    expect(star.hr, 2491);
    expect(star.raHours, closeTo(6.752472, 1e-4));
    expect(star.decDeg, closeTo(-16.716111, 1e-4));
    expect(star.vMag, closeTo(-1.46, 1e-2));
  });
}

/// 按 `bsc5.readme` 的字节表拼一条定宽记录。
///
/// 手写空格对齐极易数错一格，而列错一格的症状是「解析成功但位置错」——
/// 正好是这套用例要防的那类错，所以用列号写、不用肉眼数。
String _record({
  required int hr,
  String? raHour,
  String? raMinute,
  String? raSecond,
  String? decSign,
  String? decDegree,
  String? decMinute,
  String? decSecond,
  String? vMag,
  String? bv,
}) {
  final List<String> cols = List<String>.filled(160, ' ');
  void put(int column, String? text) {
    if (text == null) {
      return;
    }
    for (int i = 0; i < text.length; i++) {
      cols[column - 1 + i] = text[i];
    }
  }

  put(1, hr.toString().padLeft(4));
  put(76, raHour);
  put(78, raMinute);
  put(80, raSecond);
  put(84, decSign);
  put(85, decDegree);
  put(87, decMinute);
  put(89, decSecond);
  put(103, vMag);
  put(110, bv);
  return cols.join();
}

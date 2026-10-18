/// `core/view/filter.dart` —— 筛选表达式（DNF）的计算。
///
/// α 包的分布是这几条用例的数据源：`subject` 只有一个取值（全 150 项），
/// `ability` 有 9 个取值 × 每值 15 项，`role` / `industry` / `topic` / `stack`
/// 全是 `null`。三个形状刚好够验「同轴 OR」「跨轴 AND」「有轴无值」。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/view/filter.dart';

import '../../support/alpha_pack.dart';
import '../../support/pack_fixture.dart';

void main() {
  late LoadedPack pack;

  setUpAll(() {
    pack = loadAlphaPack();
  });

  /// 某个轴取值对应的项数（从真实包里数，不写死 —— 包会长）。
  int countOf(String axisKey, String value) =>
      pack.items.where((Item item) => item.sixAxis[axisKey] == value).length;

  String firstValueOf(String axisKey) => pack.items
      .firstWhere((Item item) => item.sixAxis[axisKey] != null)
      .sixAxis[axisKey]!;

  group('DNF 语义', () {
    test('同轴多选取 OR：两个取值并起来是两者之和（SPEC-VIEW-021）', () {
      final String a = firstValueOf('ability');
      final String b = pack.items
          .firstWhere(
            (Item item) =>
                item.sixAxis['ability'] != null && item.sixAxis['ability'] != a,
          )
          .sixAxis['ability']!;

      final AxisFilter filter = <String, List<String>>{
        'ability': <String>[a, b],
      };
      final int expected = countOf('ability', a) + countOf('ability', b);

      expect(matchedCount(pack, filter), expected);
      expect(visibleIdsOf(pack, filter)!.length, expected);
    });

    test('跨轴取 AND：两轴各取一个值只剩交集（SPEC-VIEW-021）', () {
      // `subject` 全 150 项都同值 ⇒ 与任一 `ability` 相交后条数不变。
      // 这不是空验：若实现错成 OR，这里会变成 150 + 15。
      final String ability = firstValueOf('ability');
      final AxisFilter filter = <String, List<String>>{
        'subject': <String>[firstValueOf('subject')],
        'ability': <String>[ability],
      };

      expect(matchedCount(pack, filter), countOf('ability', ability));
      final Set<String> ids = visibleIdsOf(pack, filter)!;
      expect(
        ids.every(
          (String id) => pack.itemOf(id)!.sixAxis['ability'] == ability,
        ),
        isTrue,
        reason: 'AND 的每一项必须同时满足两轴',
      );
    });

    test('轴上有筛选但项里没这个轴 ⇒ 不匹配，不是「忽略」（SPEC-VIEW-021）', () {
      // α 包的 `role` 全为 null：拿它当「有这个轴筛选、但没有任何项有值」。
      expect(
        pack.items.every((Item item) => item.sixAxis['role'] == null),
        isTrue,
        reason: '前提：α 包里没有任何项声明 role',
      );
      final AxisFilter filter = <String, List<String>>{
        'role': <String>['后端'],
      };
      expect(matchedCount(pack, filter), 0);
      expect(visibleIdsOf(pack, filter), isEmpty);
    });

    test('空筛选不算筛选：visibleIds 返回 null 而不是空集（C-27）', () {
      // 返回 null 让绘制层走全量路径 —— 空集会被读成「一项都不显示」。
      expect(visibleIdsOf(pack, emptyAxisFilter), isNull);
      expect(matchedCount(pack, emptyAxisFilter), pack.items.length);
    });

    test('某轴取值集为空 ⇒ 该轴不参与，不把全空间筛空（无 SPEC：留空列表会让 ② 数出一个空 chip）', () {
      final AxisFilter filter = <String, List<String>>{'ability': <String>[]};
      expect(visibleIdsOf(pack, filter), isNull);
      expect(matchedCount(pack, filter), pack.items.length);
    });
  });

  group('增删取值', () {
    test('加已有取值是幂等的，不重复（无 SPEC：重复会让 chip 出现两条一样的）', () {
      final AxisFilter once = toggleAxisValue(emptyAxisFilter, 'ability', '抽象');
      final AxisFilter twice = toggleAxisValue(once, 'ability', '抽象');
      expect(twice['ability'], <String>['抽象']);
    });

    test('删掉最后一个取值会把整个轴删掉，不留空列表（无 SPEC：空列表会沉淀成幽灵轴）', () {
      final AxisFilter filter = toggleAxisValue(
        emptyAxisFilter,
        'ability',
        '抽象',
      );
      final AxisFilter empty = withoutAxisValue(filter, 'ability', '抽象');
      expect(empty.containsKey('ability'), isFalse);
      expect(empty, isEmpty);
      expect(visibleIdsOf(pack, empty), isNull);
    });

    test('删不存在的取值不动原值（无 SPEC：删不存在的键不该静默改状态）', () {
      final AxisFilter filter = toggleAxisValue(
        emptyAxisFilter,
        'ability',
        '抽象',
      );
      expect(withoutAxisValue(filter, 'ability', '不存在'), same(filter));
      expect(withoutAxis(filter, 'topic'), same(filter));
    });
  });

  group('⑥ 罗盘的取值域（SPEC-VIEW-020）', () {
    test('取值只从包里来：一个轴的全部取值等于去重后的实际取值（SPEC-VIEW-020）', () {
      final List<String> values = axisValuesOf(pack, 'ability');
      final Set<String> actual = <String>{
        for (final Item item in pack.items)
          if ((item.sixAxis['ability'] ?? '').isNotEmpty)
            item.sixAxis['ability']!,
      };
      expect(values.toSet(), actual);
      expect(values.length, actual.length, reason: '不能有重复值');
    });

    test('按出现次数降序 —— 一屏放得下时常用的必须在前面（SPEC-VIEW-020）', () {
      final List<String> values = axisValuesOf(pack, 'ability');
      for (int i = 1; i < values.length; i++) {
        expect(
          countOf('ability', values[i - 1]),
          greaterThanOrEqualTo(countOf('ability', values[i])),
          reason: '${values[i - 1]} 比 ${values[i]} 少，序就错了',
        );
      }
    });

    test('同次数按字典序 —— 两次打开顺序不变（SPEC-VIEW-020）', () {
      final List<String> values = axisValuesOf(pack, 'ability');
      for (int i = 1; i < values.length; i++) {
        if (countOf('ability', values[i - 1]) !=
            countOf('ability', values[i])) {
          continue;
        }
        expect(
          values[i - 1].compareTo(values[i]),
          lessThan(0),
          reason: '同频的两个值没有按字典序排，顺序会随包内项序漂',
        );
      }
    });

    test('这一轴全空 ⇒ 空列表，不造一个占位值（SPEC-VIEW-020）', () {
      // α 包的 `role` 全为 null：罗盘该说「这一轴没有取值」，而不是给个空串。
      expect(axisValuesOf(pack, 'role'), isEmpty);
      expect(axisValuesOf(pack, '不存在的轴'), isEmpty);
    });

    test('空串按未声明处理，不进候选（SPEC-VIEW-007）', () {
      final LoadedPack packWithBlank = fixturePack(<FixtureItem>[
        const FixtureItem('a', '甲', ability: ''),
        const FixtureItem('b', '乙', ability: '控制流'),
      ]);
      expect(axisValuesOf(packWithBlank, 'ability'), <String>['控制流']);
    });

    test('多根合并：每个根的取值都在，同值跨包累加计数（SPEC-VIEW-020 修订 5）', () {
      // 形状照真实三包：α 是计算机科学，另外两个是语言。合并前罗盘只读当前
      // 根 ⇒ 站在 α 上永远看不到「语言」，而盘上明明并着三个星系。
      final LoadedPack python = fixturePack(<FixtureItem>[
        for (int i = 0; i < 4; i++) FixtureItem('p$i', 'Py 第 $i 项'),
      ]);
      final LoadedPack german = fixturePack(<FixtureItem>[
        for (int i = 0; i < 3; i++)
          FixtureItem('d$i', 'De 第 $i 项', domainId: 'de/grammar'),
      ], spaceId: 'german', spaceName: '德语', subject: '语言');
      final LoadedPack english = fixturePack(<FixtureItem>[
        for (int i = 0; i < 3; i++)
          FixtureItem('e$i', 'En 第 $i 项', domainId: 'en/grammar'),
      ], spaceId: 'english', spaceName: '英语', subject: '语言');

      expect(
        axisValuesOfAll(<LoadedPack>[python, german, english], 'subject'),
        <String>['语言', '计算机科学'],
        reason: '语言 3+3 = 6 次 > 计算机科学 4 次：序仍按合并后的计数排',
      );
      expect(
        axisValuesOf(german, 'subject'),
        <String>['语言'],
        reason: '单包口径不变 —— 缺陷本体正是「只读当前根」',
      );
    });

    test('空列表 ⇒ 空取值域，不抛（SPEC-VIEW-020 修订 5）', () {
      expect(axisValuesOfAll(const <LoadedPack>[], 'subject'), isEmpty);
    });
  });

  group('chip 列表', () {
    test('chip 顺序 = 轴序（sixAxisKeys）→ 取值点选序（SPEC-VIEW-019）', () {
      // 点选顺序故意与轴序相反：`ability` 在 `sixAxisKeys` 里排第 4，
      // `subject` 排第 1。若按点选先后排，`ability` 会跑到前面。
      AxisFilter filter = toggleAxisValue(emptyAxisFilter, 'ability', '抽象');
      filter = toggleAxisValue(filter, 'subject', '计算机科学');

      final List<AxisFilterChip> chips = filterChipsOf(filter);
      expect(chips.map((AxisFilterChip c) => c.axisKey).toList(), <String>[
        'subject',
        'ability',
      ]);
    });

    test('同一轴内保持点选先后（SPEC-VIEW-019）', () {
      AxisFilter filter = toggleAxisValue(emptyAxisFilter, 'ability', '抽象');
      filter = toggleAxisValue(filter, 'ability', '控制流');

      expect(
        filterChipsOf(filter).map((AxisFilterChip c) => c.value).toList(),
        <String>['抽象', '控制流'],
      );
    });

    test('chip 的轴名是中文，不是 key（SPEC-VIEW-019）', () {
      final AxisFilter filter = toggleAxisValue(
        emptyAxisFilter,
        'ability',
        '抽象',
      );
      expect(filterChipsOf(filter).single.axisLabel, '能力');
    });

    test('表外的轴也照出 chip，不静默吞掉（无 SPEC：吞掉的表现是筛了但 ② 不显示）', () {
      final AxisFilter filter = <String, List<String>>{
        'futureAxis': <String>['x'],
      };
      final List<AxisFilterChip> chips = filterChipsOf(filter);
      expect(chips.length, 1);
      expect(chips.single.axisKey, 'futureAxis');
      // 没有中文名时退回 key 本身 —— 显示英文 key 比显示空串可查。
      expect(chips.single.axisLabel, 'futureAxis');
    });
  });
}

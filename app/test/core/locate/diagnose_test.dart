import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/locate/diagnose.dart';
import 'package:project_knowledge/core/locate/locator.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';

import '../../support/pack_fixture.dart';

/// 一个能造出四类分诊的包：
///
/// | id | 标题 | 圈内 | 用途 |
/// |---|---|---|---|
/// | `python/fn-decorator` | 装饰器 | ✅ | 类 ② 的邻近候选（共享 2 片段） |
/// | `python/fn-decorator-params` | 装饰器的参数 | ✅ | 类 ② 里重叠最多的那条 |
/// | `python/fn-metaclass` | 元类 | ❌ | 类 ①：命中了，但在圈外 |
/// | `python/fn-decorator-protocol` | 装饰器协议 | ❌ | 类 ① 的干扰项：也与「装饰器参数」共享 2 片段，但**不得**进邻近候选 |
/// | `python/lex-keyword` | 关键字 | ✅ | 有命中的正向路径 |
LoadedPack _pack() => fixturePack(const <FixtureItem>[
  FixtureItem(
    'python/fn-decorator',
    '装饰器',
    domainId: 'python/func',
    ability: '抽象',
  ),
  FixtureItem(
    'python/fn-decorator-params',
    '装饰器的参数',
    domainId: 'python/func',
    ability: '抽象',
  ),
  FixtureItem(
    'python/fn-metaclass',
    '元类',
    domainId: 'python/func',
    inScope: false,
  ),
  FixtureItem(
    'python/fn-decorator-protocol',
    '装饰器协议',
    domainId: 'python/func',
    inScope: false,
  ),
  FixtureItem('python/lex-keyword', '关键字'),
]);

void main() {
  late LoadedPack pack;

  setUpAll(() {
    pack = _pack();
  });

  LocateDiagnosis? of(String query, {String? domainId}) => diagnose(
    pack: pack,
    result: Locator(pack).locate(query),
    domainId: domainId,
  );

  group('不该分诊的情形', () {
    test('空输入不分诊 —— 没有输入就没有「搜不到」（SPEC-VIEW-030）', () {
      expect(of(''), isNull);
      expect(of('   '), isNull);
    });

    test('有能落点的命中就不分诊，正向路径由浮层负责（SPEC-VIEW-030）', () {
      expect(of('关键字'), isNull);
    });

    test('命中轴取值也算「成了」，不进分诊（SPEC-VIEW-028）', () {
      // `抽象` 是两个项的 `ability` 取值：命中集非空但都不是项，
      // 三态是 partial —— 依然可以落点（写筛选），不该被当成「搜不到」。
      expect(of('抽象'), isNull);
    });
  });

  group('四类分诊', () {
    test('只有圈外项对得上 ⇒ 类 ① 圈外，出口是申请纳入（SPEC-VIEW-030）', () {
      final LocateDiagnosis diagnosis = of('元类')!;
      expect(diagnosis.kind, DiagnoseClass.outOfScope);
      expect(
        diagnosis.outside.map((LocateHit hit) => hit.label),
        contains('元类'),
      );
    });

    test('圈外项先于「措辞不同」判 —— 它是更硬的事实（SPEC-VIEW-030）', () {
      // `装饰器协` 是圈外项「装饰器协议」的前缀（①成立），同时与圈内的
      // 「装饰器」共享 2 个片段（②也成立）。两条都成立时先判 ①：东西在库里，
      // 只是不在圈内，这比「你要的可能是另一个叫法」明确得多。
      final LocateDiagnosis diagnosis = of('装饰器协')!;
      expect(diagnosis.kind, DiagnoseClass.outOfScope);
      expect(diagnosis.near, isEmpty, reason: '判到 ① 就不该再算候选');
    });

    test('零命中但有共享片段的圈内项 ⇒ 类 ② 措辞不同（SPEC-VIEW-030）', () {
      final LocateDiagnosis diagnosis = of('装饰器参数')!;
      expect(diagnosis.kind, DiagnoseClass.differentWording);
      expect(diagnosis.near.first.title, '装饰器的参数');
      expect(
        diagnosis.near.map((NearItem near) => near.title),
        isNot(contains('装饰器协议')),
        reason: '圈外项不作候选：它只能申请纳入（那是类 ① 的出口）',
      );
    });

    test('邻近候选按共享片段数降序，多者在前（SPEC-VIEW-030）', () {
      final List<NearItem> near = of('装饰器参数')!.near;
      expect(near.first.overlap, greaterThanOrEqualTo(near.last.overlap));
      expect(near.first.title, '装饰器的参数', reason: '共享 3 片段 vs 装饰器的 2 片段');
    });

    test('知道该放哪个域 ⇒ 类 ③ 域内没有（SPEC-VIEW-030）', () {
      final LocateDiagnosis diagnosis = of('虚拟环境', domainId: 'python/func')!;
      expect(diagnosis.kind, DiagnoseClass.absentInDomain);
      expect(diagnosis.domainId, 'python/func');
    });

    test('不知道往哪放 ⇒ 类 ④ 全空间没有，只记需求（SPEC-VIEW-030）', () {
      final LocateDiagnosis diagnosis = of('虚拟环境')!;
      expect(diagnosis.kind, DiagnoseClass.absentInSpace);
      expect(diagnosis.domainId, isNull);
    });
  });

  group('三态与可用性', () {
    test('只命中圈外项：三态是 none，那条命中仍在集里（SPEC-VIEW-030）', () {
      final LocateResult result = Locator(pack).locate('元类');
      expect(result.state, LocateState.none, reason: '跳过去是一片空白，不能算「成了」');
      expect(result.hits, isNotEmpty, reason: '存在性归引擎 —— 它确实在库里');
      expect(result.usableHits, isEmpty);
      expect(result.top, isNull);
    });
  });

  group('邻近候选的判据', () {
    test('共享片段为 0 就不是候选，宁可去 ③/④（SPEC-VIEW-030）', () {
      expect(nearItemsOf(pack, 'zzz'), isEmpty);
    });

    test('不读 C-28：模糊阈值未裁定也不阻塞类 ②（C-28）', () {
      // `C-28` 的取值是 `TbdConstantError`；这条用例只要跑到结论就算过。
      // 邻近候选判的是「共享片段 > 0」，排序按共享数 —— 没有阈值可读。
      final List<NearItem> near = nearItemsOf(pack, '装饰器参数');
      expect(near, isNotEmpty);
    });

    test('一段字都构不成片段时不猜（无 SPEC：单字与任何标题的「像」都是猜）', () {
      expect(nearItemsOf(pack, '装'), isEmpty);
    });
  });
}

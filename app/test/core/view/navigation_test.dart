import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/view/filter.dart';
import 'package:project_knowledge/core/view/navigation.dart';
import 'package:project_knowledge/core/view/zoom.dart';

/// 同一个空间里的第 [id] 步。多数用例只关心「走了哪几步」，空间固定。
TrailStep _step(String id, {String? space = 'python'}) =>
    TrailStep(spaceId: space, itemId: id);

void main() {
  group('详情页内部历史 trail（SPEC-VIEW-016）', () {
    test('压栈追加到尾部，返回时读到的就是上一次停的那一项（SPEC-VIEW-016）', () {
      expect(pushTrail(const <TrailStep>[], _step('a')), <TrailStep>[
        _step('a'),
      ]);
      expect(pushTrail(<TrailStep>[_step('a')], _step('b')), <TrailStep>[
        _step('a'),
        _step('b'),
      ]);
    });

    test('超出 C-21 丢最旧的那端 —— 最近 5 步永远在（C-21）', () {
      List<TrailStep> trail = const <TrailStep>[];
      for (final String id in <String>['a', 'b', 'c', 'd', 'e', 'f']) {
        trail = pushTrail(trail, _step(id));
      }
      expect(trail.length, trailCap);
      expect(trail.map((TrailStep step) => step.itemId), <String>[
        'b',
        'c',
        'd',
        'e',
        'f',
      ]);
      expect(trail.last.itemId, 'f', reason: '刚离开的那一项必须在栈顶，否则第一次返回就落空');
    });

    test('null 不压栈 —— 从「没有选中」进详情不该在历史里留一个空洞（SPEC-VIEW-016）', () {
      const List<TrailStep> trail = <TrailStep>[_stepEmpty];
      expect(pushTrail(trail, null), same(trail));
    });

    test('不去重：A → B → A 是走过两次的路，两次都得记（SPEC-VIEW-016）', () {
      List<TrailStep> trail = pushTrail(const <TrailStep>[], _step('a'));
      trail = pushTrail(trail, _step('b'));
      trail = pushTrail(trail, _step('a'));
      expect(trail.map((TrailStep step) => step.itemId), <String>[
        'a',
        'b',
        'a',
      ]);

      final ({TrailStep? step, List<TrailStep> trail}) first = popTrail(trail);
      expect(first.step?.itemId, 'a');
      final ({TrailStep? step, List<TrailStep> trail}) second = popTrail(
        first.trail,
      );
      expect(second.step?.itemId, 'b', reason: '再退一步该是 B，去重会让它跳过 B');
    });

    test('空栈退步给 null，剩下的还是空栈（SPEC-VIEW-016）', () {
      final ({TrailStep? step, List<TrailStep> trail}) stepped = popTrail(
        const <TrailStep>[],
      );
      expect(stepped.step, isNull);
      expect(stepped.trail, isEmpty);
    });

    test('每一步都带空间 —— 同名项跨空间是两条不同的路（SPEC-VIEW-016）', () {
      // 多根之后 `go/fn-closure` 与 `python/fn-closure` 是两个项：只记 `itemId`
      // 的话「返回」会落进另一个空间，而那里恰好有一个同 id 的项 ⇒ 错得不留痕迹。
      List<TrailStep> trail = pushTrail(
        const <TrailStep>[],
        _step('fn-closure', space: 'python'),
      );
      trail = pushTrail(trail, _step('fn-closure', space: 'go'));

      expect(trail, <TrailStep>[
        _step('fn-closure', space: 'python'),
        _step('fn-closure', space: 'go'),
      ]);
      expect(
        trail.first == trail.last,
        isFalse,
        reason: '同一 id 不同空间不是同一步 —— `==` 必须比空间',
      );

      final ({TrailStep? step, List<TrailStep> trail}) back = popTrail(trail);
      expect(back.step?.spaceId, 'go');
      final ({TrailStep? step, List<TrailStep> trail}) again = popTrail(
        back.trail,
      );
      expect(again.step?.spaceId, 'python', reason: '再退一步回到出发的那个空间');
    });
  });

  group('returnTo 快照（SPEC-VIEW-015）', () {
    test('六个字段往返 JSON 不丢（SPEC-VIEW-015）', () {
      const ViewSnapshot snapshot = ViewSnapshot(
        mode: ViewMode.tree,
        zoomLevel: ZoomLevel.z2,
        spaceId: 'python',
        selectedItemId: 'python/fn-decorator',
        axisFilter: <String, List<String>>{
          'ability': <String>['抽象', '具象'],
        },
        selector: '装饰器',
      );
      final ViewSnapshot back = ViewSnapshot.fromJson(snapshot.toJson());
      expect(back, snapshot);
      expect(back.mode, ViewMode.tree);
      expect(back.zoomLevel, ZoomLevel.z2);
      expect(back.spaceId, 'python');
      expect(back.selectedItemId, 'python/fn-decorator');
      expect(back.selector, '装饰器');
      expect(back.axisFilter, <String, List<String>>{
        'ability': <String>['抽象', '具象'],
      });
    });

    test('可缺的三项是真缺：没选中项、不是从搜索进来、合成根没有空间（SPEC-VIEW-015）', () {
      const ViewSnapshot snapshot = ViewSnapshot(
        mode: ViewMode.universe,
        zoomLevel: ZoomLevel.z1,
      );
      final Map<String, Object?> json = snapshot.toJson();
      expect(json.containsKey('spaceId'), isFalse, reason: '合成回落的根没有空间 id');
      expect(json.containsKey('selectedItemId'), isFalse);
      expect(json.containsKey('selector'), isFalse);

      final ViewSnapshot back = ViewSnapshot.fromJson(json);
      expect(back.spaceId, isNull);
      expect(back.selectedItemId, isNull);
      expect(back.selector, isNull);
      expect(back.axisFilter, isEmpty);
    });

    test('筛选按集合比：键序与同轴取值顺序都不影响（SPEC-VIEW-015）', () {
      const ViewSnapshot left = ViewSnapshot(
        mode: ViewMode.universe,
        zoomLevel: ZoomLevel.z1,
        axisFilter: <String, List<String>>{
          'ability': <String>['抽象', '具象'],
          'subject': <String>['函数'],
        },
      );
      const ViewSnapshot right = ViewSnapshot(
        mode: ViewMode.universe,
        zoomLevel: ZoomLevel.z1,
        axisFilter: <String, List<String>>{
          'subject': <String>['函数'],
          'ability': <String>['具象', '抽象'],
        },
      );
      expect(left, right, reason: '两种写法筛出来的可见集完全一样');
      expect(left.hashCode, right.hashCode);
    });

    test(
      '缺字段报错而不是猜默认值 —— 猜会把 bug 变成「返回后位置有点怪」（无 SPEC：判据取自 VIEW-015 的字段清单，无独立编号）',
      () {
        expect(
          () => ViewSnapshot.fromJson(<String, Object?>{'mode': 'universe'}),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => ViewSnapshot.fromJson(<String, Object?>{
            'mode': 'universe',
            'zoomLevel': 'z9',
          }),
          throwsA(anything),
          reason: '枚举名不在范围内同样不可猜',
        );
      },
    );

    test('快照里的筛选是快照，不是活引用（SPEC-VIEW-015）', () {
      final Map<String, List<String>> mutable = <String, List<String>>{
        'ability': <String>['抽象'],
      };
      final ViewSnapshot snapshot = ViewSnapshot(
        mode: ViewMode.universe,
        zoomLevel: ZoomLevel.z1,
        axisFilter: mutable,
      );
      mutable['ability']!.add('具象');
      // 快照不做深拷贝（它拿到的 map 由 `toggleAxisValue` 新建，本来就不会被改），
      // 这条用例守的是「构造时不另外造一份」这个事实 —— 若哪天改成深拷贝，
      // 这里的断言会红，提醒把理由写进注释。
      expect(snapshot.axisFilter['ability'], <String>['抽象', '具象']);
      expect(emptyAxisFilter, isEmpty, reason: '空筛选仍是不过滤（C-27）');
    });
  });
}

/// `pushTrail` 的 `null` 分支要一个「已有的栈」做对照，但不能是空列表
/// （空列表与 `same` 的差别看不出来）。
const TrailStep _stepEmpty = TrailStep(spaceId: 'python', itemId: 'a');

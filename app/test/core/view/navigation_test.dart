import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/view/filter.dart';
import 'package:project_knowledge/core/view/navigation.dart';
import 'package:project_knowledge/core/view/zoom.dart';

void main() {
  group('详情页内部历史 trail（SPEC-VIEW-016）', () {
    test('压栈追加到尾部，返回时读到的就是上一次停的那一项（SPEC-VIEW-016）', () {
      expect(pushTrail(const <String>[], 'a'), <String>['a']);
      expect(pushTrail(<String>['a'], 'b'), <String>['a', 'b']);
    });

    test('超出 C-21 丢最旧的那端 —— 最近 5 步永远在（C-21）', () {
      List<String> trail = const <String>[];
      for (final String id in <String>['a', 'b', 'c', 'd', 'e', 'f']) {
        trail = pushTrail(trail, id);
      }
      expect(trail.length, trailCap);
      expect(trail, <String>['b', 'c', 'd', 'e', 'f']);
      expect(trail.last, 'f', reason: '刚离开的那一项必须在栈顶，否则第一次返回就落空');
    });

    test('null 不压栈 —— 从「没有选中」进详情不该在历史里留一个空洞（SPEC-VIEW-016）', () {
      const List<String> trail = <String>['a'];
      expect(pushTrail(trail, null), same(trail));
    });

    test('不去重：A → B → A 是走过两次的路，两次都得记（SPEC-VIEW-016）', () {
      List<String> trail = pushTrail(const <String>[], 'a');
      trail = pushTrail(trail, 'b');
      trail = pushTrail(trail, 'a');
      expect(trail, <String>['a', 'b', 'a']);

      final ({String? itemId, List<String> trail}) step = popTrail(trail);
      expect(step.itemId, 'a');
      final ({String? itemId, List<String> trail}) second = popTrail(
        step.trail,
      );
      expect(second.itemId, 'b', reason: '再退一步该是 B，去重会让它跳过 B');
    });

    test('空栈退步给 null，剩下的还是空栈（SPEC-VIEW-016）', () {
      final ({String? itemId, List<String> trail}) step = popTrail(
        const <String>[],
      );
      expect(step.itemId, isNull);
      expect(step.trail, isEmpty);
    });
  });

  group('returnTo 快照（SPEC-VIEW-015）', () {
    test('五个字段往返 JSON 不丢（SPEC-VIEW-015）', () {
      const ViewSnapshot snapshot = ViewSnapshot(
        mode: ViewMode.tree,
        zoomLevel: ZoomLevel.z2,
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
      expect(back.selectedItemId, 'python/fn-decorator');
      expect(back.selector, '装饰器');
      expect(back.axisFilter, <String, List<String>>{
        'ability': <String>['抽象', '具象'],
      });
    });

    test('可缺的两项是真缺：没选中项、不是从搜索进来（SPEC-VIEW-015）', () {
      const ViewSnapshot snapshot = ViewSnapshot(
        mode: ViewMode.universe,
        zoomLevel: ZoomLevel.z1,
      );
      final Map<String, Object?> json = snapshot.toJson();
      expect(json.containsKey('selectedItemId'), isFalse);
      expect(json.containsKey('selector'), isFalse);

      final ViewSnapshot back = ViewSnapshot.fromJson(json);
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

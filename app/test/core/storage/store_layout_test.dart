import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/errors.dart';
import 'package:project_knowledge/core/storage/store_layout.dart';

/// 存储三区的物理落点（`entity-fields.md` §〇 · `B13a` 笔 3）。
///
/// 这些用例锁的全是**布局层面的判据**，一条也不碰磁盘：三区的价值在于
/// 「可写区碰不到只读区」，而这件事在拼路径的时候就已经能判死。
void main() {
  group('存储三区 · 布局校验', () {
    test('三根互不包含即成立，且三个根都被归一化（ADR-0005 决策 5）', () {
      final StoreLayout layout = StoreLayout(
        readOnlyRoot: 'data/packs/',
        writableRoot: './data/user',
        eventRoot: 'data/events',
      );

      expect(layout.readOnlyRoot, 'data/packs');
      expect(layout.writableRoot, 'data/user');
      expect(layout.eventRoot, 'data/events');
    });

    test('两区根相同即拒 —— 同一目录不可能同时只读与可写（ADR-0005 决策 5）', () {
      expect(
        () => StoreLayout(
          readOnlyRoot: 'data',
          writableRoot: 'data',
          eventRoot: 'events',
        ),
        throwsA(isA<InvalidStoreLayoutError>()),
      );
    });

    test('一区包含另一区即拒 —— 否则可写区的原子写能落到只读区里（ADR-0005 决策 5）', () {
      expect(
        () => StoreLayout(
          readOnlyRoot: 'data',
          writableRoot: 'data/user',
          eventRoot: 'events',
        ),
        throwsA(
          isA<InvalidStoreLayoutError>().having(
            (InvalidStoreLayoutError e) => e.other,
            'other',
            'data/user',
          ),
        ),
      );
    });

    test('字符串同前缀但段不同不算重叠 —— `/data` 与 `/database` 是两个目录（无 SPEC：段级判据）', () {
      // 这条是反证：若实现写成 `path.startsWith(root)`，本用例立刻红。
      // 误报的代价不是「多一条警告」，是合法布局被拒、应用起不来。
      final StoreLayout layout = StoreLayout(
        readOnlyRoot: '/data',
        writableRoot: '/database',
        eventRoot: '/events',
      );
      expect(layout.writableRoot, '/database');
    });

    test('归一化后相等也算重叠 —— `data/user/..` 与 `data` 是同一个目录（无 SPEC：归一化）', () {
      expect(
        () => StoreLayout(
          readOnlyRoot: 'data',
          writableRoot: 'data/user/..',
          eventRoot: 'events',
        ),
        throwsA(isA<InvalidStoreLayoutError>()),
      );
    });

    test('Windows 反斜杠与正斜杠是同一个根（无 SPEC：跨平台归一化）', () {
      expect(
        () => StoreLayout(
          readOnlyRoot: r'C:\app\data',
          writableRoot: 'C:/app/data',
          eventRoot: 'C:/app/events',
        ),
        throwsA(isA<InvalidStoreLayoutError>()),
      );
    });

    test('空根即拒 —— 空串拼出来是 `/x`，会把整棵树当成一个区（ADR-0005 决策 5）', () {
      expect(
        () => StoreLayout(
          readOnlyRoot: '',
          writableRoot: 'data/user',
          eventRoot: 'data/events',
        ),
        throwsA(isA<InvalidStoreLayoutError>()),
      );
    });
  });

  group('存储三区 · 区内路径', () {
    StoreLayout layout() => StoreLayout(
      readOnlyRoot: 'data/packs',
      writableRoot: 'data/user',
      eventRoot: 'data/events',
    );

    test('区内相对路径拼到对应区的根下（ADR-0005 决策 5）', () {
      expect(layout().pathIn(StoreZone.writable, 'claims.json'), 'data/user/claims.json');
      expect(layout().pathIn(StoreZone.event, '2026-10-20.jsonl'), 'data/events/2026-10-20.jsonl');
    });

    test('`..` 逃出本区即拒 —— 相对路径是插件作者可控的输入（无 SPEC：越区即三区分离失效）', () {
      // 反证：若实现接受 `..`，可写区就能写到只读区里去，三区分离只剩三个变量名。
      expect(layout().pathIn(StoreZone.writable, '../packs/pack.json'), isNull);
      expect(layout().pathIn(StoreZone.event, '../../etc/passwd'), isNull);
    });

    test('区内上跳再回来不算逃逸 —— 归一化后仍在本区（无 SPEC：归一化）', () {
      expect(
        layout().pathIn(StoreZone.writable, 'a/../claims.json'),
        'data/user/claims.json',
      );
    });
  });
}

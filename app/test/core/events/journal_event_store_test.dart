/// `JournalEventStore` 的落盘回归（`SPEC-FND-010` / `012`）。
///
/// 三条口径在这里各验一次，因为它们是「事件是唯一事实源」的全部支点：
/// 1. **只追加**：写完一条，文件里恰好多一行、行尾恰一个 `\n`；
/// 2. **重开还在**：换一个实例读同一份存储，`readAll` 与 `byId` 都命中；
/// 3. **写失败会喊**：`appendLine` 返回 `false` 时抛，不静默吞。
///
/// 用内存假件而不是真磁盘：这里验的是**本类**的拼装（一行一条、排序、过滤），
/// 真磁盘的追加语义归 `DartIoPackFs` 自己的测试（`store_fs_test.dart`）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/events/event.dart';
import 'package:project_knowledge/core/events/hlc_clock.dart';
import 'package:project_knowledge/core/events/journal_event_store.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';
import 'package:project_knowledge/core/storage/store_fs.dart';

const String _path = 'events/events.jsonl';

/// 一份内存里的追加区。`appendLine` 按 `AppendOnlyStoreFs` 的约定**自己补行尾**。
class _MemoryLog implements AppendOnlyStoreFs {
  final Map<String, String> files = <String, String>{};

  /// 置真后模拟「写不进去」（只读挂载 / 磁盘满）。
  bool failAppend = false;

  @override
  String? readString(String path) => files[path];

  @override
  bool isFile(String path) => files.containsKey(path);

  @override
  List<String> listDirs(String path) => const <String>[];

  @override
  bool appendLine(String path, String line) {
    if (failAppend) {
      return false;
    }
    final String payload = line.endsWith('\n') ? line : '$line\n';
    files[path] = '${files[path] ?? ''}$payload';
    return true;
  }
}

PlanDraft _draft({String spaceId = 'python'}) => PlanDraft(
  spaceId: spaceId,
  subtreeRoot: 'skeleton:major/080901',
  primaryAxis: Axis.major,
  packVersions: const PackVersions(
    skeleton: '1.0.0',
    payloads: <String, String>{'python': '0.1.0'},
  ),
  sourcePolicy: const <String, Object?>{'primary': 'src-a'},
  schemeId: 'sch-full',
  methodProfileId: 'm-1',
);

Event _planCreated({required DateTime now, String spaceId = 'python'}) =>
    buildPlanCreated(
      draft: _draft(spaceId: spaceId),
      clock: HlcClock(deviceId: 'dev-a'),
      now: now,
      userId: 'local',
    );

void main() {
  test('追加一行 plan_created，行尾恰一个换行、可原样解析回事件（SPEC-FND-012）', () async {
    final _MemoryLog fs = _MemoryLog();
    final JournalEventStore store = JournalEventStore(fs: fs, path: _path);
    final DateTime now = DateTime.utc(2026, 10, 28, 3, 0);

    await store.append(_planCreated(now: now));

    final String text = fs.files[_path] ?? '';
    expect(text.endsWith('\n'), isTrue);
    expect(text.endsWith('\n\n'), isFalse);
    expect('\n'.allMatches(text).length, 1);
    final Map<String, Object?> json =
        jsonDecode(text.trim()) as Map<String, Object?>;
    expect(json['type'], 'plan_created');
    expect(
      (json['payload']! as Map<String, Object?>)['subtreeRoot'],
      'skeleton:major/080901',
    );
  });

  test('同一份存储换实例重开：readAll 读回、byId 命中（SPEC-FND-010）', () async {
    final _MemoryLog fs = _MemoryLog();
    final JournalEventStore first = JournalEventStore(fs: fs, path: _path);
    final Event event = _planCreated(now: DateTime.utc(2026, 10, 28, 3, 0));
    await first.append(event);

    // 「重开」= 新实例、同一份存储。不是同一个对象再读一遍。
    final JournalEventStore reopened = JournalEventStore(fs: fs, path: _path);
    final List<Event> events = await reopened.readAll().toList();
    expect(events, hasLength(1));
    expect(events.single.id, event.id);
    expect(events.single.hlc, event.hlc);

    expect((await reopened.byId(event.id))?.id, event.id);
    expect(await reopened.byId('nope'), isNull);
  });

  test('readAll 按 hlc 全序，不按写入顺序（SPEC-FND-011）', () async {
    final _MemoryLog fs = _MemoryLog();
    final JournalEventStore store = JournalEventStore(fs: fs, path: _path);
    final Event later = _planCreated(now: DateTime.utc(2026, 10, 28, 4, 0));
    final Event earlier = _planCreated(now: DateTime.utc(2026, 10, 28, 2, 0));

    await store.append(later);
    await store.append(earlier);

    final List<String> ids = (await store.readAll().toList())
        .map((Event e) => e.id)
        .toList();
    expect(ids, <String>[earlier.id, later.id]);
  });

  test('spaceId 过滤只留下该空间的事件（SPEC-ACC-013）', () async {
    final _MemoryLog fs = _MemoryLog();
    final JournalEventStore store = JournalEventStore(fs: fs, path: _path);
    await store.append(
      _planCreated(now: DateTime.utc(2026, 10, 28, 3, 0), spaceId: 'python'),
    );
    await store.append(
      _planCreated(now: DateTime.utc(2026, 10, 28, 3, 1), spaceId: 'german'),
    );

    final List<Event> python = await store.readAll(spaceId: 'python').toList();
    expect(python, hasLength(1));
    expect(python.single.spaceId, 'python');
    expect(await store.readAll().toList(), hasLength(2));
  });

  test('文件还不存在时给空流，不是报错（无 SPEC：日志尚未创建属实现细节）', () async {
    final JournalEventStore store = JournalEventStore(
      fs: _MemoryLog(),
      path: _path,
    );
    expect(await store.readAll().toList(), isEmpty);
    expect(await store.byId('x'), isNull);
  });

  test(
    'appendLine 返回 false 时抛 StateError，不静默丢事实（无 SPEC：接口无返回值，抛错是本笔的选择）',
    () async {
      final _MemoryLog fs = _MemoryLog()..failAppend = true;
      final JournalEventStore store = JournalEventStore(fs: fs, path: _path);

      await expectLater(
        store.append(_planCreated(now: DateTime.utc(2026, 10, 28, 3, 0))),
        throwsA(isA<StateError>()),
      );
      expect(fs.files, isEmpty);
    },
  );

  test('坏行直接抛，不当成「没有那条」（无 SPEC：跳过坏行会让「被改过」与「没那条」混淆）', () async {
    final _MemoryLog fs = _MemoryLog()..files[_path] = '{"id":"half"\n';
    final JournalEventStore store = JournalEventStore(fs: fs, path: _path);

    await expectLater(
      store.readAll().toList(),
      throwsA(isA<FormatException>()),
    );
  });
}

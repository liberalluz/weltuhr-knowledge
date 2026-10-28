/// 事件存储的**落盘实现**：一行一个事件，只追加（`SPEC-FND-012`）。
///
/// ## 为什么文件形态是 jsonl
///
/// [EventStore] 的语义是「读完再排」—— 排序依据是 `hlc`，不是写入顺序。于是物理
/// 形态只承担两件事：**一行一条**（半行写入会在下一次读时整段解析失败），
/// **追加不改旧行**（改了就不再是「历史」）。jsonl 同时满足这两条，代价是
/// 读全量再排 —— 本地日志量级下这是可接受的，而换成索引文件会引入第二个可写
/// 事实源，与 `SPEC-FND-010` 直接冲突。
///
/// ## 写失败为什么抛
///
/// [EventStore.append] 没有返回值，接口本身不说「写成了没有」。但事件是唯一
/// 的可写事实源，**静默丢弃等于丢事实** —— 学完一步没记上，界面却往下走了，
/// 用户事后无处申诉。所以这里选择抛 [StateError]，让调用方当场知道。
/// 这个选择不影响接口形状：接口仍然只有三个方法，没有 `update` / `delete`。
library;

import 'dart:convert';

import '../json.dart';
import '../storage/store_fs.dart';
import 'event.dart';
import 'event_store.dart';

/// 事件日志的文件名。
///
/// 与 `claimsFileName` 同级：落在 [StoreLayout.pathIn] 的 `event` 区里。
const String journalEventFileName = 'events.jsonl';

/// 本机设备标识的默认值（`Hlc.deviceId`）。
///
/// 单机阶段不需要真 id —— `deviceId` 只在 **物理时间与 counter 都相同**时用来
/// 打破平局，换设备同步（`B9`）才需要把它换成安装级标识。现在写死一个常量，
/// 好过在界面层随手拼一个 `DateTime.now()` 进去（那样同一毫秒内两次启动会撞）。
const String localDeviceId = 'local-device';

/// 把 [Event] 追加进 `AppendOnlyStoreFs` 的一份日志。
///
/// 只拿得到 [AppendOnlyStoreFs]（读 + `appendLine`），拿不到原子写 —— 这是接口
/// 形状给的保证，不是自觉：覆盖历史在这条路径上物理上写不出来。
class JournalEventStore implements EventStore {
  const JournalEventStore({required this.fs, required this.path});

  final AppendOnlyStoreFs fs;

  /// 事件日志的**完整路径**。由调用方从 `StoreLayout.pathIn(StoreZone.event, …)`
  /// 取来，本层不解析平台目录（与 `StoreLayout` 同口径）。
  final String path;

  @override
  Future<void> append(Event event) async {
    // `jsonEncode` 会把正文里的换行转义成 `\n`，所以一条事件只会占一行。
    final String line = jsonEncode(event.toJson());
    if (!fs.appendLine(path, line)) {
      throw StateError('事件未落盘：$path');
    }
  }

  /// 按 `hlc` 全序读出。
  ///
  /// [spaceId] 是过滤维度（`Event.spaceId`），不是排序依据 —— 过滤在排序之后
  /// 做只是为了让「同一空间的事件里谁先谁后」这条读起来不需要再想一遍。
  @override
  Stream<Event> readAll({String? spaceId}) async* {
    final String? text = fs.readString(path);
    if (text == null) {
      // 文件还不存在 = 一条都没写过。空流，不是错误：首次启动就是这个状态。
      return;
    }
    final List<Event> events = <Event>[];
    for (final String raw in const LineSplitter().convert(text)) {
      final String line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      events.add(Event.fromJson(_decode(line)));
    }
    events.sort((Event a, Event b) => a.hlc.compareTo(b.hlc));
    for (final Event event in events) {
      if (spaceId == null || event.spaceId == spaceId) {
        yield event;
      }
    }
  }

  @override
  Future<Event?> byId(String id) async {
    await for (final Event event in readAll()) {
      if (event.id == id) {
        return event;
      }
    }
    return null;
  }

  /// 解析一行。**坏行直接抛**：跳过坏行会让「日志被改过」与「日志没那条」长得
  /// 一样，而这两件事的处置完全不同（前者要人去看文件，后者只是还没发生）。
  JsonMap _decode(String line) {
    final Object? decoded = jsonDecode(line);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('事件行不是 JSON 对象：$line');
    }
    return decoded;
  }
}

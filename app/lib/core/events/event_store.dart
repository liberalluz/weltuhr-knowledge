/// 事件存储的**形状约束**。
///
/// 本文件是 W0 五条约束里「事件只 append」的落点：这条不靠 lint，靠**接口形状**——
/// 只要不提供 `update` / `delete` / `upsert` / `clear`，调用方就写不出违规代码。
/// 给已经不可能发生的写法装报警器，是给自己看的表演。
library;

import 'event.dart';

abstract interface class EventStore {
  /// 追加一条事件。**没有返回值、没有回写、没有覆盖语义。**
  Future<void> append(Event event);

  /// 按 `hlc` 全序读出（不是按 `at`，也不是按插入顺序）。
  Stream<Event> readAll({String? spaceId});

  /// 按 `id` 取单条 —— **上传幂等**用（服务端 `id` UNIQUE 索引的服务端同构）。
  ///
  /// 幂等只拦「同一条事件被传两次」；「两台设备各学一遍」是两个不同 id，不去重。
  Future<Event?> byId(String id);
}

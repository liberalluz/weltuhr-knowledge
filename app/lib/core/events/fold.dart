/// `fold(events, asOf)` —— 唯一的状态派生入口（`SPEC-FND-010`）。
///
/// 铁律：**everything 都是派生值**。会话游标、已学门槛、笔记版本、下线标记
/// 都在这里算出来，不存在第二份可写状态表。凡是「既能从表读、又能从事件算」
/// 的东西，都是两份可能不一致的真相。
///
/// 本文件只折叠**事件直接决定**的东西。两处刻意不做：
/// - `S` / `D` / 掌握度 —— 归 `B6` 的 FSRS；这里只把迁移账本备好
///   （[FoldedState.carries] / [FoldedState.merges]），折算规则在
///   `migration.dart` 一处。
/// - `Plan` 实体 —— 归 `B4`。本笔只保证 `plan_created` / `plan_revised`
///   进不了游标与判定（事件类型已登记，不代表现在就要实现它）。
library;

import '../enums.dart';
import '../json.dart';
import 'event.dart';
import 'migration.dart';

/// 一节笔记折叠后的样子。
class FoldedNote {
  const FoldedNote({required this.version, required this.text});

  /// 该节的 `note_revised` 计数 —— **回滚也计数**，历史只增不删。
  final int version;

  /// 当前生效正文（回滚已解析成具体文本，不是「指向某个版本」的指针）。
  final String text;
}

/// 折叠结果。**全部只读**，且只由 [fold] 构造。
class FoldedState {
  FoldedState({
    required Map<String, int> cursors,
    required Set<String> passed,
    required Set<String> graduated,
    required Map<String, Grade> lastGrade,
    required Set<String> retired,
    required Map<String, FoldedNote> notes,
    required List<CarryLink> carries,
    required List<MergeLink> merges,
  }) : cursors = Map<String, int>.unmodifiable(cursors),
       passed = Set<String>.unmodifiable(passed),
       graduated = Set<String>.unmodifiable(graduated),
       lastGrade = Map<String, Grade>.unmodifiable(lastGrade),
       retired = Set<String>.unmodifiable(retired),
       notes = Map<String, FoldedNote>.unmodifiable(notes),
       carries = List<CarryLink>.unmodifiable(carries),
       merges = List<MergeLink>.unmodifiable(merges);

  /// 空态：一条事件都没有时用它，不必特判。
  FoldedState.empty()
    : cursors = const <String, int>{},
      passed = const <String>{},
      graduated = const <String>{},
      lastGrade = const <String, Grade>{},
      retired = const <String>{},
      notes = const <String, FoldedNote>{},
      carries = const <CarryLink>[],
      merges = const <MergeLink>[];

  /// 项 → **下一步**的步骤序号。折叠规则：`max(已完成 stepIndex) + 1`。
  ///
  /// 不建 `SessionCursor` 表（`event-types.md` §三）。也**不因回退而减小**：
  /// 回到上一步重看是纯视图操作，不写事件，游标不动。
  final Map<String, int> cursors;

  /// 已学门槛。`item_passed` 一写即**不可撤销** —— 复习未过只降 `S`、提前
  /// `due`，进度分母不动（`event-types.md` §二 A 第 3 条）。
  final Set<String> passed;

  /// 已毕业（`S ≥ 180`）。状态转换**不可逆**。
  final Set<String> graduated;

  /// 项 → 最近一次验收成绩。`item_skipped` **不写这里**（`C-11`）。
  final Map<String, Grade> lastGrade;

  /// 已在包升级中下线。**这些项的进度仍然保留** —— 孤儿项的事件全部保留，
  /// 只标「已下线」（`SPEC-FND-012`）。
  final Set<String> retired;

  /// 笔记，键由 [noteKey] 生成。
  final Map<String, FoldedNote> notes;

  /// 拆分账本（按事件时间序）。
  final List<CarryLink> carries;

  /// 合并账本（按事件时间序）。
  final List<MergeLink> merges;

  /// 下一步步骤序号；没学过返回 `0`（= 第一步）。
  int cursorOf(String itemId) => cursors[itemId] ?? 0;

  bool isPassed(String itemId) => passed.contains(itemId);

  bool isGraduated(String itemId) => graduated.contains(itemId);

  bool isRetired(String itemId) => retired.contains(itemId);

  /// 某节笔记；没写过返回 `null`（**不返回空对象**，否则「没笔记」与「空笔记」
  /// 分不开，`SPEC-FND-014` 要求缺失表现为空位）。
  FoldedNote? noteOf({required String? itemId, required String sectionKey}) =>
      notes[noteKey(itemId: itemId, sectionKey: sectionKey)];
}

/// 笔记的折叠键。`itemId` 为空 = 空间级自由笔记（`entity-fields` §8）。
///
/// 用 `\u0000` 分隔：`itemId` 与 `sectionKey` 都允许含连字符，
/// 用 `-` / `:` 之类会把「a-b + c」与「a + b-c」折叠成同一节。
String noteKey({required String? itemId, required String sectionKey}) =>
    '${itemId ?? ''}\u0000$sectionKey';

/// 折叠：按 `hlc` 全序重放事件，得到派生状态。
///
/// - [asOf] 给出时**只折到那一刻**（含），用于「回看某天」与增量重放；
/// - [spaceId] 给出时只折该空间的事件；
/// - [userId] 给出时只折该用户的事件。**同一设备切账号必须传它**，否则 A 的
///   进度会算进 B（`SPEC-ACC-014`）。不传 = 全量折，只用于迁移与导出 ——
///   那里要的是「这条事件存在过」，不是「谁的进度」。
///
/// 幂等：同一 `id` 的事件出现多次只算一次（`event-types.md` §一）。
/// **但「两台设备各学一遍同一项」是两个不同 `id`，都要重放** —— 你确实
/// 复习了两次，`S` 就该变长。
FoldedState fold(
  Iterable<Event> events, {
  Hlc? asOf,
  String? spaceId,
  String? userId,
}) {
  final List<Event> ordered = <Event>[];
  final Set<String> seenIds = <String>{};

  for (final Event event in events) {
    if (spaceId != null && event.spaceId != spaceId) {
      continue;
    }
    if (userId != null && event.userId != userId) {
      continue;
    }
    if (asOf != null && event.hlc.compareTo(asOf) > 0) {
      continue;
    }
    ordered.add(event);
  }

  // HLC 已保证全序；同 `(physical, counter, deviceId)` 的两条不同事件是
  // 发号器的 bug，但排序仍要确定 —— 用 `id` 兜底，别让 `List.sort`
  // 的稳定性成为事实上的定序依据。
  ordered.sort((Event a, Event b) {
    final int byHlc = a.hlc.compareTo(b.hlc);
    return byHlc != 0 ? byHlc : a.id.compareTo(b.id);
  });

  final Map<String, int> cursors = <String, int>{};
  final Set<String> passed = <String>{};
  final Set<String> graduated = <String>{};
  final Map<String, Grade> lastGrade = <String, Grade>{};
  final Set<String> retired = <String>{};
  final Map<String, List<String>> noteTexts = <String, List<String>>{};
  final List<CarryLink> carries = <CarryLink>[];
  final List<MergeLink> merges = <MergeLink>[];

  for (final Event event in ordered) {
    if (!seenIds.add(event.id)) {
      continue;
    }

    switch (event.type) {
      case EventType.stepCompleted:
        final String itemId = _requireItem(event);
        final int stepIndex = requireInt(event.payload, 'stepIndex');
        final int next = stepIndex + 1;
        final int current = cursors[itemId] ?? 0;
        if (next > current) {
          cursors[itemId] = next;
        }

      case EventType.itemGraded:
        lastGrade[_requireItem(event)] = Grade.fromWire(requireString(event.payload, 'score'));

      case EventType.itemPassed:
        passed.add(_requireItem(event));

      case EventType.itemSkipped:
        // 跳过：不写判定、不计 fail、不计已学（`C-11`）。
        // 这里**故意什么都不做** —— 「移出本次会话」是 Runner 的队列状态，
        // 不是派生事实。写成空分支是为了让「跳过为什么没有状态」有落点。
        break;

      case EventType.graduated:
        graduated.add(_requireItem(event));

      case EventType.planCreated:
      case EventType.planRevised:
        // `Plan` 归 `B4`。现在折它 = 提前冻结一个还没设计的实体。
        break;

      case EventType.stateCarried:
        carries.add(CarryLink.fromPayload(eventId: event.id, payload: event.payload));

      case EventType.stateMerged:
        merges.add(MergeLink.fromPayload(eventId: event.id, payload: event.payload));

      case EventType.itemRetired:
        // 信封 `itemId` 可为空（迁移类），故先看 payload。
        final Object? fromPayload = event.payload['itemId'];
        final String itemId = fromPayload is String ? fromPayload : _requireItem(event);
        retired.add(itemId);

      case EventType.noteRevised:
        _applyNoteRevision(event, noteTexts);
    }
  }

  final Map<String, FoldedNote> notes = <String, FoldedNote>{};
  for (final MapEntry<String, List<String>> entry in noteTexts.entries) {
    notes[entry.key] = FoldedNote(
      version: entry.value.length,
      text: entry.value.last,
    );
  }

  return FoldedState(
    cursors: cursors,
    passed: passed,
    graduated: graduated,
    lastGrade: lastGrade,
    retired: retired,
    notes: notes,
    carries: carries,
    merges: merges,
  );
}

/// 收一条 `note_revised`。
///
/// 「版本 = 该节事件计数」由这里保证；回滚（带 `targetVersion`）**追加**一条
/// 事件并把目标版本的正文重新记到新版本上，历史一条不删。
void _applyNoteRevision(Event event, Map<String, List<String>> noteTexts) {
  final String key = noteKey(itemId: event.itemId, sectionKey: requireString(event.payload, 'sectionKey'));
  final List<String> texts = noteTexts.putIfAbsent(key, () => <String>[]);

  final Object? rawTarget = event.payload['targetVersion'];
  if (rawTarget == null) {
    texts.add(requireString(event.payload, 'text'));
    return;
  }

  final int target = rawTarget is int ? rawTarget : _badTargetVersion(event, rawTarget);
  if (target < 1 || target > texts.length) {
    throw FormatException(
      '事件 `${event.id}` 的 `targetVersion` 为 $target，该节当前只有 ${texts.length} 个版本',
    );
  }
  texts.add(texts[target - 1]);
}

Never _badTargetVersion(Event event, Object? raw) =>
    throw FormatException('事件 `${event.id}` 的 `targetVersion` 不是整数：$raw');

/// 需要 `itemId` 的事件若没有它，就是坏事件 —— **不补默认值**（`SPEC-FND-014`）。
String _requireItem(Event event) {
  final String? itemId = event.itemId;
  if (itemId == null) {
    throw FormatException('事件 `${event.id}`（${eventTypeWireName(event.type)}）缺 `itemId`');
  }
  return itemId;
}

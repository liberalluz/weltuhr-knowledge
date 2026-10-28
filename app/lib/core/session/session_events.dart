/// 学习执行类事件的构造（`event-types.md` §二 A）。
///
/// ## 判定只有一处写入点
///
/// `item_graded` 是**唯一**写判定的地方（`SPEC-STEP-017`）：步内自检不写事件，
/// 步的完成只写 `step_completed`（`event-types.md` 标它「不写判定」）。本文件
/// 因此不提供「步内打分」的构造器 —— 有那个方法，迟早有人拿它当判定用。
///
/// ## 打卡项写两条
///
/// `item_passed` 的 payload 必填 `gradedEventId`，指向那条 `item_graded`。
/// 所以判据为空（打卡）时也要先写一条 `item_graded(score=pass, progressKind=checked)`
/// 再写 `item_passed` —— 只写后者的话，`gradedEventId` 没有落点，`fold` 的
/// `lastGrade` 也永远是空。
///
/// ## 顺序由 `hlc` 保证，不靠调用顺序
///
/// 两条事件必须一条在另一条之前，而 `HlcClock.next` 递增 `counter`，
/// 所以「先造 graded 再造 passed」在事件流里也是这个顺序。反过来写会得到
/// 一条指向「未来事件」的 `gradedEventId`。
library;

import '../enums.dart';
import '../events/event.dart';
import '../events/hlc_clock.dart';
import '../events/id.dart';

/// 判定来源（`event-types.md`：`progressKind`）。
///
/// `verified` = 判据可被系统核验；`checked` = 只被本人核对过（打卡 / 自评）。
/// 它由判据类型派生（`SPEC-STEP-019`），不由用户标注。
enum ProgressKind { verified, checked }

/// 脚手架档位（`event-types.md`：`scaffold`）。
///
/// `SPEC-STEP-022`：用了提示或看过答案，最高只能判「合格」—— 所以这个字段
/// 必须随判定一起落盘，否则事后无法解释「那一档熟练是怎么来的」。
enum ScaffoldLevel { none, hint, answer }

/// 造一条 `step_completed`。
///
/// [stepIndex] 是**刚走完**的那一步。`fold` 据此把游标推到 `stepIndex + 1`，
/// 所以它必须是「已完成步的下标」，不能写成「下一步的下标」。
Event buildStepCompleted({
  required String spaceId,
  required String itemId,
  required int stepIndex,
  required ExecutionOperator operator,
  required HlcClock clock,
  required DateTime now,
  required String userId,
}) => _build(
  type: EventType.stepCompleted,
  spaceId: spaceId,
  itemId: itemId,
  clock: clock,
  now: now,
  userId: userId,
  payload: <String, Object?>{'stepIndex': stepIndex, 'operator': operator.wire},
);

/// 造一条 `item_graded` —— 项末验收，判定的唯一写入点。
Event buildItemGraded({
  required String spaceId,
  required String itemId,
  required Grade score,
  required ProgressKind progressKind,
  required HlcClock clock,
  required DateTime now,
  required String userId,
  ScaffoldLevel scaffold = ScaffoldLevel.none,
}) => _build(
  type: EventType.itemGraded,
  spaceId: spaceId,
  itemId: itemId,
  clock: clock,
  now: now,
  userId: userId,
  payload: <String, Object?>{
    'score': score.name,
    'progressKind': progressKind.name,
    'scaffold': scaffold.name,
  },
);

/// 造一条 `item_passed` —— 首次验收合格，已学门槛。
///
/// [gradedEventId] 必须是那条 `item_graded` 的 `id`。调用方拿不到它就别写这条
/// 事件：一个指向不存在判定的「已学」，回放时无从解释。
Event buildItemPassed({
  required String spaceId,
  required String itemId,
  required String gradedEventId,
  required HlcClock clock,
  required DateTime now,
  required String userId,
}) => _build(
  type: EventType.itemPassed,
  spaceId: spaceId,
  itemId: itemId,
  clock: clock,
  now: now,
  userId: userId,
  payload: <String, Object?>{'gradedEventId': gradedEventId},
);

Event _build({
  required EventType type,
  required String spaceId,
  required String itemId,
  required HlcClock clock,
  required DateTime now,
  required String userId,
  required Map<String, Object?> payload,
}) {
  final Hlc hlc = clock.next(now);
  return Event(
    id: eventIdFor(hlc),
    type: type,
    hlc: hlc,
    spaceId: spaceId,
    userId: userId,
    itemId: itemId,
    at: DateTime.fromMillisecondsSinceEpoch(hlc.physical, isUtc: true),
    payload: payload,
  );
}

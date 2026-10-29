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
/// `verified` = 判据可被系统核验；`checked` = 只被本人核对过（自评）。
///
/// ⚠️ **它不承载「是不是打卡项」** —— 那是 [`buildItemGraded`] 的 `checkin`
/// 参数。两个维度压进一个字段，结果是「有判据但自评」的项被当成打卡项，`S`
/// 从此冻结（`QUANT-007` 的冻结只对判据为空的项成立）。
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
///
/// [progressKind] 与 [checkin] 是**两个维度**，不可互相顶替：
/// - `progressKind` 管「谁判」：系统能核验的题 → `verified`，本人核对的 → `checked`；
/// - `checkin` 管「有没有判据」：判据为空 = 打卡项 ⇒ `S` 冻结、永不毕业
///   （`QUANT-007` / `N-05`）。
///
/// 一个「讲给别人听」的项完全可以是 `checked` + `checkin: false` —— 它有判据
/// （讲完了），只是判定由本人做，`S` 应当照常增长。
Event buildItemGraded({
  required String spaceId,
  required String itemId,
  required Grade score,
  required ProgressKind progressKind,
  required bool checkin,
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
    'checkin': checkin,
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

/// 造一条 `graduated` —— 记忆强度首次达到毕业阈值（`S ≥ ` `C-02`）。
///
/// [sAtGraduation] 是**毕业那一刻**的 `S`。事后 `S` 还会继续涨，事件里不记这个
/// 值，回放时就答不出「靠多少毕业的」。它是状态转换的观测值、不是派生值 ——
/// 派生值（`R` / `due`）一律不入库。
///
/// **只有判分写入点造这条事件**，且顺序固定在 `item_graded` → `item_passed` →
/// `graduated`：毕业以「已学」为前提，事件流里能直接读出这个前置。
Event buildGraduated({
  required String spaceId,
  required String itemId,
  required double sAtGraduation,
  required HlcClock clock,
  required DateTime now,
  required String userId,
}) => _build(
  type: EventType.graduated,
  spaceId: spaceId,
  itemId: itemId,
  clock: clock,
  now: now,
  userId: userId,
  payload: <String, Object?>{'sAtGraduation': sAtGraduation},
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

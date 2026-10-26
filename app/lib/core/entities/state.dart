/// 用户态实体。标记「派生」的一律不入库 —— 由 `fold(events, asOf)` 算出。
library;

import '../enums.dart';
import '../json.dart';

/// 每项的记忆状态（**派生**，由事件折叠）。
///
/// `R(t)` 不入库：由 `D`、`S` 与经过时间算得。存了就会有第二份可能不一致的真相。
class SrsState {
  const SrsState({
    required this.itemId,
    required this.difficulty,
    required this.stability,
    required this.lastReviewAt,
    required this.due,
    required this.failCount,
    required this.reps,
    required this.skipStreak,
  });

  factory SrsState.fromJson(JsonMap json) => SrsState(
    itemId: requireString(json, 'itemId'),
    difficulty: requireDouble(json, 'd'),
    stability: requireDouble(json, 's'),
    lastReviewAt: DateTime.parse(requireString(json, 'lastReviewAt')),
    due: DateTime.parse(requireString(json, 'due')),
    failCount: requireInt(json, 'failCount'),
    reps: requireInt(json, 'reps'),
    skipStreak: requireInt(json, 'skipStreak'),
  );

  final String itemId;

  /// `D`：难度。**首次评分时才初始化** —— 建计划时不存在。
  final double difficulty;

  /// `S`：稳定度（天）。
  final double stability;

  final DateTime lastReviewAt;
  final DateTime due;

  /// 连续未过计数，合格即清零（跨会话）。**与 [skipStreak] 不可互相折算。**
  final int failCount;
  final int reps;
  final int skipStreak;

  JsonMap toJson() => <String, Object?>{
    'itemId': itemId,
    'd': difficulty,
    's': stability,
    'lastReviewAt': lastReviewAt.toIso8601String(),
    'due': due.toIso8601String(),
    'failCount': failCount,
    'reps': reps,
    'skipStreak': skipStreak,
  };
}

/// 笔记。锚点是 `itemId`：两套笔记共用同一锚点，这是「随时切换」成立的前提。
class Note {
  const Note({
    required this.itemId,
    required this.sectionKey,
    required this.layers,
    required this.noteVersion,
    required this.origin,
  });

  factory Note.fromJson(JsonMap json) => Note(
    itemId: optionalString(json, 'itemId'),
    sectionKey: requireString(json, 'sectionKey'),
    layers: requireStringMap(json, 'layers'),
    noteVersion: requireInt(json, 'noteVersion'),
    origin: NoteOrigin.values.byName(requireString(json, 'origin')),
  );

  /// 为空 = 空间级自由笔记（不参与两套切换）。
  final String? itemId;
  final String sectionKey;

  /// `generated` / `autoFilled` / `authored` —— **三层都保留**。
  final Map<String, String> layers;

  /// **按节独立计数**，不是整本一个号。
  final int noteVersion;
  final NoteOrigin origin;

  /// 显示优先级：`authored > autoFilled > generated`。
  String? get displayText {
    for (final String key in const <String>['authored', 'autoFilled', 'generated']) {
      final String? value = layers[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  JsonMap toJson() => <String, Object?>{
    if (itemId != null) 'itemId': itemId,
    'sectionKey': sectionKey,
    'layers': layers,
    'noteVersion': noteVersion,
    'origin': origin.name,
  };
}

/// 提交（治理）。**最小三字段即可提交**，四件套是「过审」的必要条件。
class Submission {
  const Submission({
    required this.id,
    required this.targetType,
    required this.title,
    required this.domainId,
    required this.description,
    required this.status,
    this.verdict,
  });

  factory Submission.fromJson(JsonMap json) {
    final Object? verdict = json['verdict'];
    return Submission(
      id: requireString(json, 'id'),
      targetType: requireString(json, 'targetType'),
      title: requireString(json, 'title'),
      domainId: requireString(json, 'domainId'),
      description: requireString(json, 'description'),
      status: SubmissionStatus.values.byName(requireString(json, 'status')),
      verdict: verdict == null ? null : SubmissionVerdict.values.byName('$verdict'),
    );
  }

  final String id;

  /// `item / domain / source / scheme / method / note`，**首期只开 `item`**。
  final String targetType;
  final String title;
  final String domainId;
  final String description;
  final SubmissionStatus status;
  final SubmissionVerdict? verdict;

  /// 提交后**立即进本地 overlay，立刻可学** —— 不等审核。
  bool get isLearnableNow =>
      status == SubmissionStatus.localOverlay || status == SubmissionStatus.publicOverlay;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'targetType': targetType,
    'title': title,
    'domainId': domainId,
    'description': description,
    'status': status.name,
    if (verdict != null) 'verdict': verdict!.name,
  };
}

/// 界面状态（**本地，不入事件流**）。
class ViewState {
  const ViewState({
    this.mode = ViewMode.universe,
    this.focusSlot = LevelSlot.supercluster,
    this.selectedItemId,
    this.focusChain = const <String>[],
    this.expandedNodes = const <String>[],
    this.cameraState = const <String, Object?>{},
    this.axisFilter = const <String, List<String>>{},
    this.returnTo,
    this.trail = const <String>[],
  });

  final ViewMode mode;

  /// 当前聚焦的 `level_slot`（`entity-fields` §18）。
  ///
  /// **取代旧的 `zoomLevel`（`Z0`–`Z4`）**：五档径向随 `ADR-0005` 决策 3 作废，
  /// 同心球壳没有「第几档」这回事。槽位是**语义**不是深度序号 —— 同一个
  /// `star` 在学科轴是层深 2、在角色轴是层深 4（`SPEC-TREE-001`）。
  ///
  /// 默认最外层：界面首帧没有地址，能说的只有「聚焦在槽位全集的最浅一档」。
  final LevelSlot focusSlot;

  final String? selectedItemId;
  final List<String> focusChain;
  final List<String> expandedNodes;
  final JsonMap cameraState;

  /// **DNF**：轴内 OR、轴间 AND。
  final Map<String, List<String>> axisFilter;

  /// 进详情时的快照。**存 selector 而非结果列表**（结果会变）。
  final JsonMap? returnTo;

  /// 详情页**内部**历史，上限 `C-21`。
  final List<String> trail;
}

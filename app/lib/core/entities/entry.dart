/// 载荷内容（`entity-fields` §9）。**键 = `node_id`**。
///
/// 与 `Node` 分离的理由（台账原话）：`nodes[]` 进地址空间，改动要校验父子与
/// DAG；`entries[]` 只是文本，改动不影响结构。混在一起**无法单独升级** ——
/// 改一句 `summary` 也要过一遍父子校验，而父链校验的代价随树规模走。
///
/// 拆开的代价是「一个节点可能没有 entry」：骨架节点就没有。所以这里**不做**
/// 「每个 Node 必须有 entry」的校验，那是包构建期的判据（`content/tools`）。
library;

import '../enums.dart';
import '../json.dart';

/// 一种可推荐的资源（`entity-fields` §9 `resources[]`）。
class Resource {
  const Resource({
    required this.kind,
    required this.title,
    required this.url,
    required this.license,
    required this.lang,
  });

  factory Resource.fromJson(JsonMap json) => Resource(
    kind: requireString(json, 'kind'),
    title: requireString(json, 'title'),
    url: requireString(json, 'url'),
    license: requireString(json, 'license'),
    lang: requireString(json, 'lang'),
  );

  /// 取值域「课程 / 书 / 视频 / 工具 / 规范」。
  ///
  /// ⚠️ **存原文不建枚举**：台账只给了中文表述、没有给线上英文取值
  /// （对照 `SourceKind` 是有英文取值的）。凭空造一套 `course/book/...`
  /// 等于**自己定义一个取值域**，而这份数据的作者按哪一套写，只有台账说了算。
  /// 待 `entity-fields` 补齐英文取值后再收成枚举 —— 那时是一次机械替换。
  final String kind;

  final String title;
  final String url;
  final String license;
  final String lang;

  JsonMap toJson() => <String, Object?>{
    'kind': kind,
    'title': title,
    'url': url,
    'license': license,
    'lang': lang,
  };
}

/// 执行步骤（`entity-fields` §9.1）。
///
/// **不含 `estMinutes`**：时长由「步数 × 算子系数」派生（`C-14`–`C-19`），
/// 项级覆盖已足够；步级再留一个字段会与系数表打架。
class EntryStep {
  const EntryStep({
    required this.operator,
    required this.instruction,
    this.phase,
    this.hint,
  });

  factory EntryStep.fromJson(JsonMap json) {
    final Object? phase = json['phase'];
    return EntryStep(
      operator: ExecutionOperator.fromWire(
        requireString(json, 'operator'),
      ),
      instruction: requireString(json, 'instruction'),
      phase: phase == null ? null : StepPhase.fromWire('$phase'),
      hint: optionalString(json, 'hint'),
    );
  }

  final ExecutionOperator operator;

  /// 本步指令。
  final String instruction;

  /// 为空时由 [effectivePhase] 派生。
  final StepPhase? phase;

  /// **脚手架能被观测的前提**：未声明则本步无提示可给。
  final String? hint;

  /// 派生规则（`entity-fields` §9.1）：`read` / `example` → `first`；
  /// 其余四类 → `both`。作者可覆盖。
  StepPhase get effectivePhase {
    final StepPhase? explicit = phase;
    if (explicit != null) {
      return explicit;
    }
    return switch (operator) {
      ExecutionOperator.read || ExecutionOperator.example => StepPhase.first,
      ExecutionOperator.recall ||
      ExecutionOperator.practice ||
      ExecutionOperator.explain ||
      ExecutionOperator.doStep => StepPhase.both,
    };
  }

  JsonMap toJson() => <String, Object?>{
    'operator': operator.wire,
    'instruction': instruction,
    if (phase != null) 'phase': phase!.name,
    if (hint != null) 'hint': hint,
  };
}

/// 项末验收的一条能力断言（`entity-fields` §9.2）。
///
/// **不设 `judge_type`**：`criteria` 与 `quiz` 1:1，判定方由 `quiz[].judge`
/// 派生即可。留两个同义字段等于给不一致留一条合法路径。
class Criterion {
  const Criterion({required this.id, required this.statement});

  factory Criterion.fromJson(JsonMap json) => Criterion(
    id: requireString(json, 'id'),
    statement: requireString(json, 'statement'),
  );

  /// 段内唯一。
  final String id;

  /// 能力断言（「能解释 Transformer 的注意力机制」）。
  final String statement;

  JsonMap toJson() => <String, Object?>{'id': id, 'statement': statement};
}

/// 题库的一项（`entity-fields` §9.3）。
///
/// 模型生成的题**不入包**：不可复现、不参与 SRS 判定。
class QuizItem {
  const QuizItem({
    required this.id,
    required this.criterionId,
    required this.type,
    required this.prompt,
    required this.answer,
    required this.judge,
  });

  factory QuizItem.fromJson(JsonMap json) => QuizItem(
    id: requireString(json, 'id'),
    criterionId: requireString(json, 'criterion_id'),
    type: QuizType.fromWire(requireString(json, 'type')),
    prompt: requireString(json, 'prompt'),
    answer: requireString(json, 'answer'),
    judge: QuizJudge.fromWire(requireString(json, 'judge')),
  );

  final String id;

  /// 指向 [Criterion.id]，**1:1**：每条 `criteria` 恰有一题。
  final String criterionId;

  final QuizType type;
  final String prompt;
  final String answer;

  /// `auto`（前四类题型）/ `self`（自评 + 可选留证）。
  final QuizJudge judge;

  /// `progressKind`（`verified` / `checked`）**不入库**，由这里派生。
  bool get isAutoJudged => judge == QuizJudge.auto;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'criterion_id': criterionId,
    'type': type.name,
    'prompt': prompt,
    'answer': answer,
    'judge': judge.name,
  };
}

/// 载荷内容。字段集以 `docs/specs/entity-fields.md` §9 为唯一权威处。
class NodeEntry {
  const NodeEntry({
    required this.nodeId,
    required this.summary,
    required this.outcomes,
    required this.resources,
    required this.aliases,
    required this.keywords,
    required this.body,
    required this.steps,
    required this.selfCheck,
    required this.criteria,
    required this.quiz,
    required this.sourceRefs,
    this.estMinutes,
    this.methodId,
  });

  factory NodeEntry.fromJson(JsonMap json) {
    final Object? estMinutes = json['estMinutes'];
    return NodeEntry(
      nodeId: requireString(json, 'node_id'),
      summary: optionalString(json, 'summary'),
      outcomes: requireStringList(json, 'outcomes'),
      resources: requireMapList(
        json,
        'resources',
      ).map(Resource.fromJson).toList(growable: false),
      aliases: requireStringList(json, 'aliases'),
      keywords: requireStringList(json, 'keywords'),
      body: optionalString(json, 'body'),
      steps: requireMapList(
        json,
        'steps',
      ).map(EntryStep.fromJson).toList(growable: false),
      selfCheck: requireStringList(json, 'selfCheck'),
      criteria: requireMapList(
        json,
        'criteria',
      ).map(Criterion.fromJson).toList(growable: false),
      quiz: requireMapList(
        json,
        'quiz',
      ).map(QuizItem.fromJson).toList(growable: false),
      sourceRefs: requireStringList(json, 'source_refs'),
      estMinutes: estMinutes == null ? null : requireInt(json, 'estMinutes'),
      methodId: optionalString(json, 'methodId'),
    );
  }

  /// 本 entry 描述的 `Node.id`。
  final String nodeId;

  /// 一句话。
  final String? summary;

  /// 能做什么。
  final List<String> outcomes;

  /// **推荐去哪学** —— 与 [sourceRefs] 不是一回事。
  final List<Resource> resources;

  /// 别名：检索与虫洞对齐用。
  final List<String> aliases;

  /// 自由文本，**与骨架 `Node.tags` 不是一回事**（那里是编目事实标签）。
  final List<String> keywords;

  /// Markdown 整块。
  final String? body;

  final List<EntryStep> steps;

  /// 步内自检（形成性），**不写判定**。
  final List<String> selfCheck;

  /// 项末验收（终结性）。**空 = 打卡式**：跳过 ⑤、记 `checked`、`S` 永不增长、
  /// **永不毕业** —— 它是学习痕迹，不通往出口。
  final List<Criterion> criteria;

  final List<QuizItem> quiz;

  /// 本节点内容**引自**哪几份材料（引用 `SourceRef.id`）。
  ///
  /// ⚠️ 这个字段是 `B13a` 笔 4 **补裁**的（2026-10-21）：旧 `Item.sourceRefs`
  /// 迁移时在新体系里没有落点 —— `Node` 表没有它（源引用不影响结构，进
  /// `nodes[]` 会让「改一条引用」也要过父子与 DAG 校验），`NodeEntry` 原表
  /// 也没有。落这里而不是 `resources[]`：`resources` 回答「推荐去哪学」，
  /// `source_refs` 回答「我这句话引自哪份材料的哪一段」，两者的受众与
  /// 校验方式都不同（后者要能追到 `segments[].locator`）。已补进
  /// `entity-fields` §9 表。
  final List<String> sourceRefs;

  /// 项级预计时长；为空则由步数 × 系数派生。
  final int? estMinutes;

  /// 指定配方；为空用默认。
  final String? methodId;

  /// 至少一个 `review`（含 `both`）步骤 —— 防静默绕过遗忘曲线。
  bool get hasReviewStep =>
      steps.any((EntryStep s) => s.effectivePhase != StepPhase.first);

  /// 打卡式：没有任何 `criteria`。
  bool get isCheckin => criteria.isEmpty;

  /// `criteria` 与 `quiz` 是否 1:1 对齐（`entity-fields` §9.3）。
  ///
  /// **返回判据而不是抛错**：这条不是类型级不变式，坏数据的表象是「验收
  /// 永远判不过」，归包构建期校验（`content/tools/validator.py`）。客户端
  /// 拿它做自检，不当门。
  bool get isQuizAligned {
    final Set<String> criterionIds = <String>{
      for (final Criterion c in criteria) c.id,
    };
    if (criterionIds.length != criteria.length) {
      return false;
    }
    final Set<String> covered = <String>{
      for (final QuizItem q in quiz) q.criterionId,
    };
    // **比长度不比「题数」**：`covered.length == quiz.length` 保证两题不指向同一条，
    // `containsAll` 保证每条都有题 —— 两条合起来蕴含「题数 == 条数」，所以不需要
    // 再单独比一次 `criteria.length != quiz.length`。
    //
    // 这条是反证逼出来的：那个长度检查原本在，**撤掉它没有任何用例变红** ——
    // 因为它被下面两行完全覆盖，是一个没有对家的判据（`R-08` 的镜像：
    // 撤掉它也不会变红，它就是多余的）。已删，只留双向判据。
    return covered.length == quiz.length && covered.containsAll(criterionIds);
  }

  JsonMap toJson() => <String, Object?>{
    'node_id': nodeId,
    'summary': summary,
    'outcomes': outcomes,
    'resources': resources.map((Resource r) => r.toJson()).toList(),
    'aliases': aliases,
    'keywords': keywords,
    'body': body,
    'steps': steps.map((EntryStep s) => s.toJson()).toList(),
    'selfCheck': selfCheck,
    'criteria': criteria.map((Criterion c) => c.toJson()).toList(),
    'quiz': quiz.map((QuizItem q) => q.toJson()).toList(),
    'source_refs': sourceRefs,
    if (estMinutes != null) 'estMinutes': estMinutes,
    if (methodId != null) 'methodId': methodId,
  };
}

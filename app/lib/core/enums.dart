/// 核心层共用的枚举。取值与 `docs/reference/entity-fields.md` 逐项对应。
library;

/// 三层：径向属性，不是层级（`SPEC-FND-003`）。
enum Layer { persistent, view, quick }

/// 知识项类型：决定方法派发（`entity-fields` §2）。
enum ItemType { statement, procedure, skill, tacit }

/// 六要件三态（`SPEC-FND-004`）。
enum RequirementState { complete, missing, notExternalizable }

/// 六要件：**只有这六个键**，顺序固定。
enum RequirementKey { boundary, justification, proposition, relation, how, tacit }

/// 六类执行算子（`SPEC-STEP-012`）。**不得自创第七类。**
enum ExecutionOperator { read, example, recall, practice, teach, build }

/// 步骤相位：默认由算子派生，作者可覆盖（`entity-fields` §6）。
enum StepPhase { first, review, both }

/// 三档刻度（`SPEC-STEP-018`）。
enum Grade { fail, pass, proficient }

/// 边类型：驱动边样式（实线 = 强依赖、虚线 = 弱依赖 / 指向未知）。
enum EdgeType { strong, weak, unknownTarget }

/// 笔记出处（`SPEC-NOTE-005`）。
enum NoteOrigin { standard, selfBuilt }

/// 提交状态（`entity-fields` §11）。
enum SubmissionStatus { draft, pending, localOverlay, publicOverlay, rejected }

/// 提交裁定（`SPEC-GOV-001`）。
enum SubmissionVerdict { approved, rejected, mergedAsAlias, demotedOutOfScope }

/// 方法出处：合并优先级 `user > pack > platform`。
enum MethodOrigin { platform, pack, user }

/// 视图模式：底部导航是视距刻度，不是功能标签栏（`N-11`）。
enum ViewMode { universe, tree, detail, locateResult, progress, practice }

/// 五档视距（`SPEC-VIEW-001`）。
enum ZoomLevel { z0, z1, z2, z3, z4 }

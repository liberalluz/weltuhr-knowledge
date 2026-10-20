/// 核心层共用的枚举。取值与 `docs/reference/entity-fields.md` 逐项对应。
///
/// ⚠️ **枚举名就是 JSON 取值**（`RequirementState` 是唯一例外，走蛇形
/// `not_externalizable`）。这不是风格问题：`values.byName` 与数据取值域
/// 差一个字母，加载真实包时当场抛错，而此前的测试全用内联 JSON、
/// 与真包同错，所以一直是绿的。B2 第 2 笔把四处不一致一次改齐，
/// 并用「真包解析」用例锁住（见 `test/core/pack/alpha_pack_test.dart`）。
library;

/// 三层：径向属性，不是层级（`SPEC-FND-003`）。JSON 取值 `persistent` / `view` / `ephemeral`。
enum Layer {
  persistent,
  view,
  ephemeral;

  static Layer fromWire(String raw) {
    for (final Layer value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('Layer', raw, values.map((Layer v) => v.name));
  }
}

/// 知识项类型：决定方法派发（`entity-fields` §2）。JSON 取值 `declarative` / `procedural` / `skill` / `tacit`。
enum ItemType {
  declarative,
  procedural,
  skill,
  tacit;

  static ItemType fromWire(String raw) {
    for (final ItemType value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('ItemType', raw, values.map((ItemType v) => v.name));
  }
}

/// 六要件三态（`SPEC-FND-004`）。JSON 取值为蛇形小写。
enum RequirementState {
  present,
  missing,
  notExternalizable;

  /// 线上取值：`notExternalizable` → `not_externalizable`，其余与枚举名同形。
  String get wire => this == notExternalizable ? _notExternalizableWire : name;

  static RequirementState fromWire(String raw) {
    for (final RequirementState value in values) {
      if (value.wire == raw) {
        return value;
      }
    }
    _unknownWire(
      'RequirementState',
      raw,
      values.map((RequirementState v) => v.wire),
    );
  }
}

const String _notExternalizableWire = 'not_externalizable';

/// 取值不在册时的统一报错。
///
/// 不用 `values.byName`：它抛 `ArgumentError`，报错里没有「允许哪些值」，
/// 而加载器是最需要看清取值域的地方。
Never _unknownWire(String enumName, String raw, Iterable<String> allowed) =>
    throw FormatException('$enumName 取值不在册：`$raw`（允许 ${allowed.join(" / ")}）');

/// 六要件：**只有这六个键**，顺序固定。
enum RequirementKey {
  boundary,
  justification,
  proposition,
  relation,
  how,
  tacit,
}

/// 六类执行算子（`SPEC-STEP-012`）。**不得自创第七类。**
enum ExecutionOperator { read, example, recall, practice, teach, build }

/// 步骤相位：默认由算子派生，作者可覆盖（`entity-fields` §6）。
enum StepPhase { first, review, both }

/// 三档刻度（`SPEC-STEP-018`）。JSON 取值 `fail` / `pass` / `proficient`
/// （`item_graded.score`，见 `docs/reference/event-types.md` §二 A）。
enum Grade {
  fail,
  pass,
  proficient;

  static Grade fromWire(String raw) {
    for (final Grade value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('Grade', raw, values.map((Grade v) => v.name));
  }
}

/// 边类型：驱动边样式（实线 = 强依赖、虚线 = 弱依赖 / 指向未知）。
///
/// JSON 取值 `unknown`（`entity-fields` §3）。**不要**写成 `unknownTarget` ——
/// 那是本枚举曾经的名字，与数据差一个词，导致 `unknown` 边一条都解析不了。
enum EdgeType {
  strong,
  weak,
  unknown;

  static EdgeType fromWire(String raw) {
    for (final EdgeType value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('EdgeType', raw, values.map((EdgeType v) => v.name));
  }
}

/// 笔记出处（`SPEC-NOTE-005`）。
enum NoteOrigin { standard, selfBuilt }

/// 提交状态（`entity-fields` §11）。
enum SubmissionStatus { draft, pending, localOverlay, publicOverlay, rejected }

/// 提交裁定（`SPEC-GOV-001`）。
enum SubmissionVerdict { approved, rejected, mergedAsAlias, demotedOutOfScope }

/// 候选出处：合并优先级 `user > pack > platform`（`SPEC-PLAN-006`）。
///
/// **三段共用** —— 源 / 体系 / 方法各有这三处出处（`SPEC-PLAN-006` 的「三线对称」），
/// 值域相同。原名为 `MethodOrigin`：名字把共用的东西说成了方法专用，`B4` `P-2`
/// 要给源与体系的候选挂同一个标签时才暴露。改名不改值，也不改
/// `MethodProfile.origin` 的字段名。
enum CandidateOrigin { platform, pack, user }

/// 视图模式：底部导航是视距刻度，不是功能标签栏（`N-11`）。
enum ViewMode { universe, tree, detail, locateResult, progress, practice }

// `ZoomLevel` **不在这里** —— 它带 `code` / `label` 两个界面字段，是
// `core/view/zoom.dart` 的 `enum ZoomLevel`。两个同名枚举并存过一阵，
// 两边一起 import 就 `ambiguous_import`；唯一出处比「枚举都放 enums.dart」重要。

// ───────────────────── 三轴容器树（`ADR-0005` · `ADR-0007`） ─────────────────────

/// 三轴：**容器树的轴**，不是四项标签（`ADR-0005` 决策 1）。JSON 取值同枚举名。
enum Axis {
  discipline,
  major,
  occupation;

  static Axis fromWire(String raw) {
    for (final Axis value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('Axis', raw, values.map((Axis v) => v.name));
  }
}

/// 节点槽位（`entity-fields` §2）：**语义槽位，不是深度序号**。
///
/// 三轴实际占用的槽位不同 —— 学科轴只到 `star`（研究生目录没有全国统一的
/// 二级目录），角色轴多出 `cluster`。所以任何「第 n 层就是某某」的写法都是错的，
/// 只能按槽位判断。合法组合见 `constants.dart` 的 `legalSkeletonSlots`。
///
/// ⚠️ 台账写「八个语义槽位」，表里实际只列出**七个**：`supercluster` / `group` /
/// `galaxy` / `cluster` / `star` / `system` / `planet`。差额疑为「可观测宇宙（根）」
/// 那一级，而根已由 `supercluster` 承担，故本枚举按实测七个建。
enum LevelSlot {
  supercluster,
  group,
  galaxy,
  cluster,
  star,
  system,
  planet;

  static LevelSlot fromWire(String raw) {
    for (final LevelSlot value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('LevelSlot', raw, values.map((LevelSlot v) => v.name));
  }
}

/// 可见范围 / 可写性（`entity-fields` §2）。`S0`–`S3` 来自包或治理流程，
/// **代码层只直写 `S4`**（`ADR-0007` 决策 3：可写性是纯函数，不是类型）。
///
/// 线上取值是大写的 `S0`–`S4`，与枚举名不同形 —— 所以走 [wire]，不用 `name`。
enum Scope {
  s0,
  s1,
  s2,
  s3,
  s4;

  /// 线上取值：`S0`–`S4`。
  String get wire => name.toUpperCase();

  static Scope fromWire(String raw) {
    for (final Scope value in values) {
      if (value.wire == raw) {
        return value;
      }
    }
    _unknownWire('Scope', raw, values.map((Scope v) => v.wire));
  }
}

/// 节点状态（`entity-fields` §2）。`tombstone` 是**软删** —— 目录撤条目时
/// 节点不消失，否则既有学习进度会指向空。
enum NodeStatus {
  live,
  tombstone,
  revoked;

  static NodeStatus fromWire(String raw) {
    for (final NodeStatus value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('NodeStatus', raw, values.map((NodeStatus v) => v.name));
  }
}

/// 可学节点的知识类型（`entity-fields` §2「仅可学项」）。
///
/// 与 [ItemType] **同值域、不同名**：`Item` 是旧实体，`ADR-0007` 定 `LearnableNode`
/// 的字段类型为 `LearnableType`。两者会并存到 `B13a` 笔 5（`Item` 删除时 [ItemType]
/// 一并消失），**不得让 `ItemType` 出现在 `LearnableNode` 上** —— 那会让「旧实体零残留」
/// 变成一句空话。
enum LearnableType {
  declarative,
  procedural,
  skill,
  tacit;

  static LearnableType fromWire(String raw) {
    for (final LearnableType value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('LearnableType', raw, values.map((LearnableType v) => v.name));
  }
}

/// 核心层共用的枚举。取值与 `docs/specs/entity-fields.md` 逐项对应。
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
///
/// ⚠️ ⑤⑥ 的标识符**已裁定为 `explain` / `do`**（`2026-10-20`，原 `OD-03`）：
/// `teach` / `build` 案被否 —— `build` 与 `content/tools/build.py`、`build/` 目录、
/// CI 的 `build` 步骤**同词异义**。代码曾与裁定脱节（写 `teach`/`build`），
/// `B13a` 笔 4 改齐；M1 夹具的 `steps[].operator` 一直是裁定值，改前拿它解析会抛
/// 「取值不在册」。
///
/// ⚠️ **成员名是 `doStep` 而不是 `do`**：`do` 是 Dart 的**保留字**，不能作标识符
/// （`enum X { do }` 直接编译不过）。这是本项目**第二处**「枚举名 ≠ JSON 取值」
/// （第一处是 `RequirementState` 的蛇形）—— 与它同构：**线上取值由 [wire] 给出**，
/// 序列化与反序列化都必须走 `wire` / `fromWire`，不得用 `name` / `values.byName`。
/// 判据的精神（「差一个字母就解析不了」）在这里反而更硬：用 `name` 序列化会把
/// `doStep` 写进数据，那份数据没有任何一方能读回。
enum ExecutionOperator {
  read,
  example,
  recall,
  practice,
  explain,
  doStep;

  /// 线上取值：`doStep` → `do`，其余与枚举名同形。
  String get wire => this == doStep ? _doWire : name;

  static ExecutionOperator fromWire(String raw) {
    for (final ExecutionOperator value in values) {
      if (value.wire == raw) {
        return value;
      }
    }
    _unknownWire(
      'ExecutionOperator',
      raw,
      values.map((ExecutionOperator v) => v.wire),
    );
  }
}

const String _doWire = 'do';

/// 步骤相位：默认由算子派生，作者可覆盖（`entity-fields` §9.1）。
enum StepPhase {
  first,
  review,
  both;

  static StepPhase fromWire(String raw) {
    for (final StepPhase value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('StepPhase', raw, values.map((StepPhase v) => v.name));
  }
}

/// 三档刻度（`SPEC-STEP-018`）。JSON 取值 `fail` / `pass` / `proficient`
/// （`item_graded.score`，见 `docs/specs/event-types.md` §二 A）。
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
enum CandidateOrigin {
  platform,
  pack,
  user;

  static CandidateOrigin fromWire(String raw) {
    for (final CandidateOrigin value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire(
      'CandidateOrigin',
      raw,
      values.map((CandidateOrigin v) => v.name),
    );
  }
}

/// 视图模式：底部导航是视距刻度，不是功能标签栏（`N-11`）。
///
/// **没有 `universe`** —— 宇宙视图整层已删，`B17b` 重建时按那时的形态加回。
/// 留一个指向不存在视图的默认值，编译期不会有任何东西变红。
enum ViewMode { tree, detail, locateResult, progress, practice }

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
/// 笔 5c 之前这里还有个 `ItemType`（同值域、为旧 `Item` 而设）。它已随
/// `content.dart` 一并删除 —— 两个同值域的枚举并存，代码里就永远存在
/// 「这个位置该用哪个」的判断题，而答错的表象是类型不匹配，只在跨实体拼接时
/// 才暴露。
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

// ────────────────────── 三类边（`entity-fields` §3–§5） ──────────────────────

/// 父子边形态（`entity-fields` §3）。
///
/// `main` **每节点恰好一条**，`secondary` 是 0..N 的附加归属。
/// 主父不可覆盖（`S0`–`S4` 任何一层都不得改），这条由 `ParentIndex` 与
/// 三元校验器的「父链可达 + 跨包」两面共同守。
enum ParentEdgeKind {
  main,
  secondary;

  static ParentEdgeKind fromWire(String raw) {
    for (final ParentEdgeKind value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire(
      'ParentEdgeKind',
      raw,
      values.map((ParentEdgeKind v) => v.name),
    );
  }
}

/// 虫洞边形态（`entity-fields` §4）：**单值**，判定顺序
/// `sameName` > `manyToMany` > `granularity`。
///
/// 单值而非数组：三形态本身会重叠（`0812 ↔ 080901` 既像同名异编又像粒度错位），
/// 多值等于把「这条边画成什么样」的矛盾推给渲染层。
enum WormholeKind {
  sameName,
  manyToMany,
  granularity;

  /// 线上取值走蛇形 —— 与枚举名不同形，故走 [wire] 而非 `name`。
  String get wire {
    switch (this) {
      case WormholeKind.sameName:
        return 'same_name';
      case WormholeKind.manyToMany:
        return 'many_to_many';
      case WormholeKind.granularity:
        return 'granularity';
    }
  }

  static WormholeKind fromWire(String raw) {
    for (final WormholeKind value in values) {
      if (value.wire == raw) {
        return value;
      }
    }
    _unknownWire('WormholeKind', raw, values.map((WormholeKind v) => v.wire));
  }
}

/// 先修强度（`entity-fields` §5）。
///
/// `⪯` = `required` 边的传递闭包，是**全项目唯一偏序源**；
/// `recommended` 只影响排序建议与 UI 提示，不构成可达性约束。
enum EdgeStrength {
  required,
  recommended;

  static EdgeStrength fromWire(String raw) {
    for (final EdgeStrength value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('EdgeStrength', raw, values.map((EdgeStrength v) => v.name));
  }
}

/// 存储三区（`entity-fields.md` §〇）。
///
/// 取值与那张表逐行对应。**这里只给区的身份，不给区的路径** —— 路径归
/// `StoreLayout`（三个根由调用方注入），访问能力归 `core/storage/store_fs.dart`
/// 的三个接口。三者分开的理由：同一份代码要能在「开发期仓内目录」「用户数据
/// 目录」「将来的云端挂载」上跑，而**区的位置会变、能力不变**。
enum StoreZone {
  /// 骨架 / 载荷 / 地形 / 方法 / 覆盖包正文 —— 只能读。
  readOnly,

  /// `S4` 自建节点 · 个人 `OverlayPatch` · `PathClaim` 墓碑 —— 读 + 原子写。
  writable,

  /// 学 / 评 / 复习 / 访问 —— 只 append。
  event,
}

/// 包的类别（`entity-fields` §1）。
///
/// `kinds[]` **可多值**：一个分发单元既可以提供载荷也能提供地形。所以它不是
/// 判别符 —— 判别符是「这段数据是什么」（边有 `type`、节点有 `level_slot`），
/// 而 `kind` 描述的是「这个包干几件事」。四类各自的特化字段见 [Pack]。
enum PackKind {
  payload,
  overlay,
  terrain,
  method;

  static PackKind fromWire(String raw) {
    for (final PackKind value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('PackKind', raw, values.map((PackKind v) => v.name));
  }
}

/// 审核状态（`entity-fields` §1）。
///
/// `revoked` 只**停止分发**，不远程删除已装副本 —— 卸载与否归用户。
enum ReviewState {
  pending,
  approved,
  rejected,
  revoked;

  static ReviewState fromWire(String raw) {
    for (final ReviewState value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('ReviewState', raw, values.map((ReviewState v) => v.name));
  }
}

/// 源的种类（`entity-fields` §11）。
///
/// `catalog` 绑 `Node.catalog_refs[]`，回答「这个 `0812` 依据哪份文件」；
/// `material` 才是「去哪学」。两者混进同一张候选卡会让「教育部目录」与
/// 「Python Tutorial」并列，用户无从选择。
enum SourceKind {
  catalog,
  material;

  static SourceKind fromWire(String raw) {
    for (final SourceKind value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('SourceKind', raw, values.map((SourceKind v) => v.name));
  }
}

/// 源的权威度（`entity-fields` §11）。
///
/// **废除 `L` 编号**：`L` 前缀在项目内已三处撞名（节点层级 / 源等级 / 出处等级）。
/// 语义值本身即排序键，未知档排最后的逻辑不变。
enum AuthorityLevel {
  official,
  standard,
  textbook,
  reference,
  community;

  static AuthorityLevel fromWire(String raw) {
    for (final AuthorityLevel value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire(
      'AuthorityLevel',
      raw,
      values.map((AuthorityLevel v) => v.name),
    );
  }
}

/// 题型（`entity-fields` §9.3）。前四类可机器判定。
enum QuizType {
  choice,
  fill,
  code,
  audio,
  freeform;

  static QuizType fromWire(String raw) {
    for (final QuizType value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('QuizType', raw, values.map((QuizType v) => v.name));
  }
}

/// 判定方（`entity-fields` §9.3）。
///
/// `progressKind`（`verified` / `checked`）**不入库**，由这里派生；`criteria`
/// 也不再设 `judge_type`，同由此处派生 —— 1:1 关系下留两个同义字段，
/// 等于给不一致留一条合法路径。
enum QuizJudge {
  auto,
  self;

  static QuizJudge fromWire(String raw) {
    for (final QuizJudge value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('QuizJudge', raw, values.map((QuizJudge v) => v.name));
  }
}

/// 路径重定向的原因（`entity-fields` §7）。线上取值为蛇形。
enum PathAliasReason {
  parentChange,
  slugChange;

  /// 线上取值：`parentChange` → `parent_change`，`slugChange` → `slug_change`。
  String get wire => switch (this) {
    PathAliasReason.parentChange => 'parent_change',
    PathAliasReason.slugChange => 'slug_change',
  };

  static PathAliasReason fromWire(String raw) {
    for (final PathAliasReason value in values) {
      if (value.wire == raw) {
        return value;
      }
    }
    _unknownWire(
      'PathAliasReason',
      raw,
      values.map((PathAliasReason v) => v.wire),
    );
  }
}

/// path 占用状态（`entity-fields` §6）。
///
/// **墓碑必须留在可写内容区**：卸载插件只删节点、不删 claim —— 否则
/// 「A 卸载 → B 装上 → A 再装回」时 A 会以为自己是首次占用。
enum ClaimState {
  live,
  tombstone;

  static ClaimState fromWire(String raw) {
    for (final ClaimState value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('ClaimState', raw, values.map((ClaimState v) => v.name));
  }
}

/// 补丁状态（`entity-fields` §8）。
///
/// `stale` = `base_hash` 与目标现值失配，**不自动应用** —— 自动应用等于让
/// 一次静默的数据漂移改写作者的表述。
enum PatchState {
  applied,
  stale;

  static PatchState fromWire(String raw) {
    for (final PatchState value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    _unknownWire('PatchState', raw, values.map((PatchState v) => v.name));
  }
}

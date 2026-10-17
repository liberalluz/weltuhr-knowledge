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
    _unknownWire('RequirementState', raw, values.map((RequirementState v) => v.wire));
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
enum RequirementKey { boundary, justification, proposition, relation, how, tacit }

/// 六类执行算子（`SPEC-STEP-012`）。**不得自创第七类。**
enum ExecutionOperator { read, example, recall, practice, teach, build }

/// 步骤相位：默认由算子派生，作者可覆盖（`entity-fields` §6）。
enum StepPhase { first, review, both }

/// 三档刻度（`SPEC-STEP-018`）。
enum Grade { fail, pass, proficient }

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

/// 方法出处：合并优先级 `user > pack > platform`。
enum MethodOrigin { platform, pack, user }

/// 视图模式：底部导航是视距刻度，不是功能标签栏（`N-11`）。
enum ViewMode { universe, tree, detail, locateResult, progress, practice }

/// 五档视距（`SPEC-VIEW-001`）。
enum ZoomLevel { z0, z1, z2, z3, z4 }

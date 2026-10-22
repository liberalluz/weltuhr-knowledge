# ADR-0007 · `Node` 的类型形态：按槽位分型，不按 scope

- **状态**：已接受
- **日期**：2026-10-20
- **决策人**：liberal
- **覆盖范围**：[`entity-fields.md`](../specs/entity-fields.md) §1.2 `Node` 的**字段集不变**，本 ADR 只定「这些字段在 Dart 里如何组织成类型」；`B13a` 出口判据的可观测形式

## 背景

`entity-fields.md` 定的是**字段**，没定**类型形态**。「`Node` 一表多 `scope`」在 SQL 里就是一张表加一个列，在 Dart 里必须选一种组织方式，而这个选择会传播到每一个构造点。

选错的返工面实测过：`core/entities/` 三文件、**34 个文件**命中旧概念、**647 个用例**里的构造点。

先厘清两件事 —— 它们在上一轮讨论里被混为一谈，而混错的后果是分型轴选反：

### 一、`scope` 不决定字段集

| scope | 字段集 | 差异 |
|---|---|---|
| `S0` 官方 / `S1` 平台 | **完全相同** | 只有"谁产出、能否改" |
| `S2` 机构 / `S3` 团队 | 与上面相同；对既有节点的修改走 `OverlayPatch`，不产生新的字段形态 | 同上 |
| `S4` 个人 | 同上，`pack_id` 为空、`official_code` 为空 | 同上 |

五个 scope 的字段**一个都不差**。按 scope 分型会得到五个字段完全一样的类，收益为零、`pattern match` 成本五倍。

### 二、`level_slot` 决定字段集

台账里 `type` / `layer` / `requirements` 三个字段标着「**仅可学项**」，而台账同时写明「**行星层 = `Item`（可学项）**」。两条合起来，判据是：

```
level_slot == planet  ⇔  type / layer / requirements 有值
```

与 `scope` 无关，与 `status` 无关。

### 三、于是分型轴只有一个

**结构节点（`supercluster` / `group` / `galaxy` / `cluster` / `star`）vs 可学节点（`planet`）**。

这不是为了类型好看。项目里唯一有行为分叉的概念就是「可学」：七步 Runner、FSRS 排程、掌握度 `d × s`、`Plan` 的候选集，**全部只对 `planet` 有意义**。把它变成类型，这些地方就不必再逐处判 `type != null`。

## 决策

### 1. `Node` 为 `sealed`，按槽位两分

```dart
sealed class Node {
  const Node({
    required this.id,
    required this.axis,
    required this.levelSlot,
    required this.name,
    required this.slug,
    required this.scope,
    required this.packId,
    required this.status,
    required this.tags,
    required this.catalogRefs,
    this.officialCode,
  });

  final String id;              // {plugin_id}:{local_id}；骨架 skeleton:{local_id}
  final Axis axis;              // discipline / major / occupation
  final LevelSlot levelSlot;    // 语义槽位，不是深度序号
  final String name;
  final String slug;            // path 段
  final Scope scope;            // S0..S4，只影响可写性，不影响字段集
  final String packId;          // 骨架为 skeleton；S4 为空
  final NodeStatus status;      // live / tombstone / revoked
  final List<String> tags;
  final List<String> catalogRefs;
  final String? officialCode;   // 可空：S4 自建、载荷行星系与行星无官方码
}

/// 结构节点：五槽位之一，**没有** type / layer / requirements
final class StructuralNode extends Node { ... }

/// 可学节点：恒为 planet，三者**非空**
final class LearnableNode extends Node {
  const LearnableNode({
    required super.id, /* ... 基类十二项 ... */
    required this.type,
    required this.layer,
    required this.requirements,
  }) : super(levelSlot: LevelSlot.planet);

  final LearnableType type;     // declarative / procedural / skill / tacit
  final Layer layer;            // persistent / view / ephemeral
  final Requirements requirements;  // 六要件 × 三态，null 不是合法取值
}
```

`LearnableNode` 的 `levelSlot` 由构造函数固定，不开放给调用方 —— 它只有一个合法值，开放就等于留一个能写错的口子。

> **实现修订（`B13a` 笔 1，2026-10-20）**：`levelSlot` 落地为**抽象 getter**，而不是上面片段里的基类字段。
> 原因就是上一句话本身 —— 基类字段必然是构造函数参数，`LearnableNode` 就得接收它、再在构造体里
> 校验「必须是 `planet`」，那正是「开放了、但希望你别传错」。改成 getter 后：`StructuralNode`
> 用自己的 `final LevelSlot levelSlot` 提供实现（槽位对它是**数据**，五种），`LearnableNode` 用
> `LevelSlot get levelSlot => LevelSlot.planet`（槽位对它是**类型的一部分**）。**参数在签名里根本不存在**，
> 这条口子不是「被校验住」，而是「不存在」。字段集不变，`node.levelSlot` 的读法也不变。


### 2. 派生字段不成为字段

台账标「派生」的三项，**不作为 `Node` 的成员**，改为纯函数：

| 派生项 | 形态 | 理由 |
|---|---|---|
| `path` | `String pathOf(Node, ParentIndex)` | 父链 `slug` 串联。父节点改名后 path 就变，存下来必然出现两份真相 |
| `inScope` | `bool inScopeOf(Node, Plan, ParentIndex)` | 依赖 `Plan.subtree_root`，同一节点在不同 Plan 下取值不同 |
| `depth` | `int depthOf(LevelSlot, Axis)` | 台账原文「**仅供展示，不得用于判据**」。存成字段等于邀请别人拿它判据 |

`ParentIndex` 是 B13a 的产出：由 `ParentEdge` 建的 `Map<String, String>`（child → main parent），一次构建、多处复用。

### 3. `scope` 不进类型，进可写性判定

可写性是一个纯函数，不是类型：

```dart
bool isWritable(Scope scope) => scope == Scope.s4;  // S0-S3 来自包或治理流程，代码层不直写
```

若将来 S2/S3 需要区分"谁有权提交"，那是**治理层**的判定（`Submission` + 角色），不是实体层的类型问题。把它做成类型会把治理规则编译进实体，两处都要改。

### 4. `(axis, level_slot)` 的合法组合由静态表守

八槽位 × 三轴并非全笛卡尔积，实际合法 **12 对**：

| 轴 | 合法槽位 | 数 |
|---|---|---|
| `discipline` | `supercluster` · `group` · `star` | 3 |
| `major` | `supercluster` · `group` · `galaxy` · `star` | 4 |
| `occupation` | `supercluster` · `group` · `galaxy` · `cluster` · `star` | 5 |

这张表在代码里是 `const Set<(Axis, LevelSlot)>`，`StructuralNode` 构造时校验、反序列化时也走同一处。**这是唯一一处允许在运行期抛错的类型约束** —— 因为它在编译期无法表达（轴是运行期读取的数据，不是类型参数）。

> **实现修订（`B13a` 笔 1，2026-10-20）**：本表只覆盖**骨架**五槽位，`system`（行星系）不在其中 ——
> 它是载荷容器，轴继承自父恒星，三轴都合法。上面「结构节点 = 五槽位之一」漏了 `system`，
> 而它确实属 `StructuralNode`（没有 `type` / `layer` / `requirements`）。落地口径因此是
> **「`system` 放行 ∨ 命中 12 对表」**，而不是把 `system` 补进表里做成 15 对：
> 列进表里的后果是每新增一级载荷容器都要回来改表，而「不限轴」只需一个判断。
> 枚举里 `LevelSlot` 共七值（五骨架 + `system` + `planet`）。

## 被否方案

### A. 单平坦类 + 可空字段

```dart
class Node { ... final LearnableType? type; final Layer? layer; final Requirements? requirements; }
```

改动最小、JSON 往返最直白、`List<Node>` 不需要 `pattern match`。

**否掉的理由**：`level_slot: star` 配 `type: procedural` 这种非法组合**编译期不可见、运行期不报错**。真实后果是 Runner 看到 `type != null` 就当成可学项，于是在恒星上跑七步流程 —— 而且一路绿灯。这正是 `R-19` 同族的失败形态：**错的状态可表达，就一定会有人表达出来**。

### C. 泛型 `Node<T extends SlotData>`

**否掉的理由**：泛型会传染 —— 凡持有 `Node` 的签名都要写 `Node<SlotData>`，最终被迫退化成 `Node<dynamic>`，等于 A 案却多一层间接。而且合法槽位有 12 种组合、却只需两分，`SlotData` 的粒度与真实分型不匹配。

### D. 单类 + 工厂校验（`factory` 返回 `Result`）

不引入继承，靠构造函数拒绝非法组合。

**否掉的理由**：把「不可表达」降级成「构造时拒绝」，只要有一条路径绕过工厂（反序列化、测试辅助、`copyWith`）就失效；而若为了堵这条路不给默认构造，序列化仍要写映射 —— 付出 B 案的成本，却拿不到 B 案的编译期保证。

## 影响

| 面 | 变化 |
|---|---|
| `core/entities/` | 三文件重建为 `Node`（sealed）+ 三类边 + 七类新增实体。`Item` 概念消失，它就是 `LearnableNode` |
| 34 个引用点 | 遍历处多数不必 `pattern match`（公共字段在基类）；判「可学」的地方由 `is LearnableNode` 替代 `type != null` |
| 647 用例 | 构造点全改。原断言 `item.type != null` 之类的，改为类型断言 |
| JSON 层 | 反序列化按 `level_slot` 分派为唯一入口，不允许旁路构造 |
| `entity-fields.md` | 加一段指针指向本 ADR（字段集仍以台账为唯一权威） |

### 闸门如何观测「非法组合不可表达」

`B13a` 的出口判据不能写成「代码里没有非法组合」—— 那不可验证。可观测形式是**静态检查**（`app/tool/docs/` 已有同类检查器的先例）：

1. `StructuralNode` 类体内不含 `type` / `layer` / `requirements` 三个标识符作为字段声明；
2. `LearnableNode` 三项字段**非可空**（类型标注不带 `?`）；
3. 全仓不存在 `Node(` 直接构造（`sealed` 已保证，检查器只需断言无 `Node` 的 `factory` 或非抽象构造）；
4. `path` / `inScope` / `depth` 不作为 `Node` 及其子类的字段出现。

四条都能用 AST 或简单正则断言，不依赖运行期。

## 后续

- **`B13a` 的范围由本 ADR 确定**：实体层 + `ParentIndex` + `id`/`path`/URI 三元校验 + JSON 原子写 + 三区物理分离。不依赖三份目录数据。
- **`B13b` 才需要数据**：3,323 个骨架节点、`slug` 生成、`official_code` 回填。见 [`skeleton-catalog.md`](../specs/skeleton-catalog.md)。
- 旧实体的**字段去向**（映射 / 合并 / 丢弃）是本 ADR 之外的施工清单，随 `B13a` 首笔写入 PR 描述，不另立文档 —— 它是一次性的，不是规范。

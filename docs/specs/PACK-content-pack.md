# PACK · 空间与内容包

> **前置阅读**：[FND](FND-foundation.md)。字段定义见 [`entity-fields.md`](entity-fields.md)，事件见 [`event-types.md`](event-types.md)。
> **明确不管**：提交审核的四裁定（→ [GOV](GOV-governance.md)）· 体系怎么选（→ [PLAN](PLAN-planning.md)）· 笔记模板（→ [NOTE](NOTE-notes.md)）。

---

## 一、边界

### SPEC-PACK-001 空间边界三判据
**裁定**：一个粒度要成为**独立知识空间**，须三条全齐，缺一条降为上位空间内的**域**：

1. **独立前提偏序 `⪯`** —— 有自己的依赖图，不是别人图上的切片
2. **独立版本** —— 可单独升级而不牵动别的空间
3. **三层结构齐全** —— 持久 / 视图 / 快消都有

**判据验证**：Python 三条全齐 ⇒ 独立空间；「计算机专业」切片不自带 `⪯` ⇒ 不成同空间（作为平级互补空间存在，不嵌套）。
`src:` N-6（原第 6 条待裁定）

### SPEC-PACK-002 上位层不升级为容器
**裁定**：「计算机专业」「编程语言」在 Z0 只作为**轴向筛选**（虚线分组框），不成为可展开的容器。**仅当它自己持有 `Item`**（如「计算机导论」这门课）时才升级为容器；届时它与 Python 的关系是**平级**。
**不引入「空间组」实体** —— 那会新增一层导航，与「六轴代替嵌套」直接相背。
`src:` N-7

### SPEC-PACK-003 一空间一包
**裁定**：内容分发的最小单位是空间，一空间一包。客户端按需加载，不加载全量。

### SPEC-PACK-004 跨空间不能合成一个 Plan
**裁定**：`Plan` 的键是 `spaceId`，系统里**不存在「跨空间总 Plan」**。因此「学完整套后端」= 多个并列 Plan（Python + 数据库 + 网络），不是一个大计划。
**连带**：Z0 搜索结果里的「按此范围建计划」必须**按空间分组**逐空间发起，禁止跨空间合并。
`src:` 第 39 轮 · DT-6 连带

---

## 二、pack 格式

### SPEC-PACK-005 pack 单文件：清单 + 六段
**裁定**：一个包 = **一个 `pack.json`**，顶层同时承载**清单字段**与**内容六段**。没有 `manifest.json`、没有 `dist/`、没有 `meta` 信封。

| 部分 | 内容 | 备注 |
|---|---|---|
| 清单字段 | `plugin_id` · `name` · `version` · `kinds[]` · `namespace` · `schema_version` · `skeleton_requires` · `deps[]` · `license` · `author` · `origin` · `review_state` · `signature`（可空）· `axes[]`，加四个**可空** facts（`payload` / `terrain` / `overlay` / `method`） | 字段集与取值**唯一权威处**是 [`entity-fields.md`](entity-fields.md) §1，此处不重述 |
| `nodes` | 树节点（`StructuralNode` / `LearnableNode` 两型） | 派生三项 `path` / `inScope` / `depth` **不入库** |
| `edges` | 三类边同段，每条带判别符 `type`（`parent` / `wormhole` / `prerequisite`） | `⪯` 必须无环（`SPEC-FND-005`） |
| `entries` | 载荷内容，键 = `node_id` | 骨架节点**没有** entry，故为稀疏表 |
| `sources` | 源（材料） | 摘录逐字准确并带许可 |
| `schemes` | 体系 | `nodes[]` 是**集合不是路线**，见 `SPEC-PLAN-012` |
| `methods` | 方法（配方） | — |

**顶层只有这两类键**：清单字段与六段之外的任何键都是非法（旧形态的 `meta` 即此列）。

**六段缺一即格式错误**，不补空数组 —— 补默认值会把「坏了」读成「空的」，而两者的修法完全不同。

**为什么没有 `meta` 信封**：旧形态吃两段文本（清单 + 产物），需要 `meta{space, version}` 回答「这两份是不是同一批」。单文件里「同一批」由「同一个文件」保证，信封失去对象；`version` 直接是清单字段。

**`version` 不含构建时间戳**：`pack.json` 不入库、tag 是唯一指针，时间戳会让同一 commit 两次构建 byte 不等。`version` 的源是源数据的版本声明，构建器**原样透传、不改写**；tag `pack/<plugin>/vX.Y.Z` 须与之逐字一致。

**作废登记**：`B13a` 笔 5c 之前是「内容五段（`items` / `edges` / `schemes` / `questions` / `excerpts`）+ `meta` 信封」。`ADR-0007` 的三轴两型落地后，那五段由本条的六段取代 —— `items` 拆成 `nodes` + `entries`，`questions` / `excerpts` 分别并进 `entries` 与 `sources`，新增 `methods`。

> ⚠️ **迁移状态（2026-10-25 第二次更新）**：管线现在是**两条线并存** ——
>
> | 脚本 | 产出 | 形态 |
> |---|---|---|
> | `content/tools/assemble_pack.py` | `<空间>/pack.json`（**客户端探的就是这个**） | 本条：单文件 = 清单 + 六段 |
> | `content/tools/assemble_skeleton.py` | `content/skeleton/pack.json`（**骨架内置，不走插件探测**） | 本条；`kinds` 为空、四个 facts 全无（`ADR-0005` 决策 2） |
> | `content/tools/build.py` | `<空间>/dist/pack.json` | 作废的「五段 + `meta` 信封」，只服务 `verify.py --suite` 的 37 个 fixture |
>
> 也就是说**客户端链路上的产物已经符合本条**，三个空间都已装出内容：`python` 10 个行星系 + 150 个行星 + 150 条内容（750 步 · **355** 条断言）；`english` 8 个行星系 + 80 个行星 + 80 条内容（400 步 · **242** 条断言）；`german` 同样 8 个行星系 + 80 个行星 + 80 条内容（400 步 · **201** 条断言）。三个空间的每条内容都带正文与五个步骤。
> 尚未迁移的是 `build.py` 那一侧与它的 fixture —— 它们连同 `validator.py` 的字段级判据随三包重建一起走，那时 `assemble_pack.py` 与 `build.py` 合成一个。
> 读到 `content/tools/` 里的「五段」时按这段理解，不要据此判本条未实现。
>
> **内容侧的源是另一个文件**：`content/<空间>/entries.json`（可选，`itemId → summary / body / steps[] / selfCheck[] / estMinutes / criteria[]`）。它是**写出来的内容**，与 `items.json`（编目事实）分开 —— 字段集仍取 `entity-fields` §9，本条不新增字段，只说明这些字段从哪来。
>
> **仍未关闭的差距**（如实登记）：三份源数据（`items` / `questions` / `edges`）仍是旧格式 —— 它们只承载编目事实与题目，装配器按空间全跑，三个空间都能读；三个空间的 `entries.json` 已各自覆盖全部节点（`payload.est_minutes_coverage` 都是 **1.0**）；`outcomes` / `resources` 两栏在三空间里仍空 —— 旧源数据没有这两栏，装配器写空数组而不补写；`edges` 里 3 条旧边的端点不在 `nodes` 中，照旧计入 `dropped`。

`src:` 第 48 轮 · E3 · V-1 · `ADR-0005` 决策 2 · `ADR-0007`

### SPEC-PACK-006 schema v0 冻结范围的两次扩大（排期提示）
**裁定**：M0 的 schema v0 冻结范围原只含 item / edge / 归位四件套 / overlay 合并规则。**两次扩大**：

| 扩 | 段 | 原因 |
|---|---|---|
| 第一次 | `questions` | ⑤ 检验需要离线可复现的题（模型生成不可复现、不参与 SRS） |
| 第二次 | `excerpts` + `license` | 「选源」必须是真实动作，源须离线可读 |

**两次都落在关键路径上，M0 排期须重估。** 第三次扩 schema 应暂停 —— 这也是「别名 / 拼音延后」的理由。

**`methods` 段不属「第三次扩」**：它随 `ADR-0007` 的两型重构一并落地（`SPEC-PACK-005` 六段之一），不是往旧五段上再凿一格。本条禁的是**在既定段集合之外**临时加段。

`src:` 第 48 轮 · 第 66 轮 · `ADR-0007`

### SPEC-PACK-007 笔记模板不进 pack
**裁定**：`pack.json` **不新增 `notes` 段**。笔记模板在**平台层声明式**定义，pack 只提供六要件内容。
**理由**：模板入包 ⇒ 每加一种笔记形态就要改包结构 ⇒ M3「零核心代码改动接入新空间」当场失效。
`src:` NB-7

### SPEC-PACK-008 稳定 `Item.id`
**裁定**：见 [FND-013](FND-foundation.md)。此为 **pack schema 的硬性约束**，校验器须拒绝任何形如 `python/decorator@2.1.0` 的 id。
`src:` GOV Z3 连带

### SPEC-PACK-009 六要件三态在包里的表达
**裁定**：`requirements` 每格取 `present / missing / not_externalizable`。「不可外化」**必须显式声明**，不得用缺失（null）表示 —— 两者语义不同：缺失是「还没写」，不可外化是「本来就没有外部形态」。
`src:` FND-004 · QUANT M2

---

## 三、overlay

### SPEC-PACK-010 双平面
**裁定**：内容有两层叠加：

| 平面 | 谁写 | 可见性 |
|---|---|---|
| **pack** | 包作者 | 所有用户 |
| **本地 overlay** | 用户自建（含已提交未审的内容） | 仅本人 |
| **公共 overlay** | 审核通过的用户内容 | 所有用户 |

**合成版本 = `pack@vX + overlay@N`**，两个版本号独立。
`src:` 早期治理裁定

### SPEC-PACK-011 提交即入本地 overlay
**裁定**：用户提交新增项后**立即写入本地 overlay，立刻可学、进宇宙、能建 Plan**；过审才进公共 overlay。
**不做「等审核通过才可学」** —— 审核是异步的，等审期间功能等于不存在，第一天就会被放弃。
`src:` DT-9

### SPEC-PACK-012 自建粗项是「暗星」
**裁定**：用户自建的项六要件全空 ⇒ 亮度极低 ⇒ 在宇宙里表现为**暗星**。这是**正确表现**，不得补光（补光会让「未声明即不渲染」与亮度通道同时失效）。
`src:` 第 76 轮 · N-12

---

## 四、版本迁移

### SPEC-PACK-013 迁移必须事件化
**裁定**：项被拆分 / 合并 / 删除时，状态迁移**必须记成事件**（`state_carried` / `state_merged` / `item_retired`），由 `fold` 应用。
**若把「复制多少状态」写在 `fold` 外面，就等于事件流之外还有一份魔法**，事件溯源出现破口。
`src:` GOV Z3

### SPEC-PACK-014 拆分：`S` 打折，笔记全额复制
**裁定**：项 `X` 拆为 `X1…Xn`：

| 对象 | 处理 | 理由 |
|---|---|---|
| `S`（记忆稳定度）、掌握状态 | 各拿 `1/n`（`C-12`） | 掌握 `X` ≠ 同时掌握 `X1` 与 `X2` |
| **笔记 / 摘录 / 题型文本** | **全额复制到各子项** | **文本不能打半份** —— 把一节 600 字拆成两节各 300 字，等于替用户重写内容 |

⚠️ 这两条是**同一次拆分中并行执行的两条规则**，不互相折算。
`src:` X-B（纠错）

### SPEC-PACK-015 合并：取较大 `S`
**裁定**：多项合并为一项时，合并项取各来源中**最大的 `S`**（`C-13`）。理由：两边都会，合起来当然会。
`src:` GOV Z3

### SPEC-PACK-016 孤儿项：事件保留 + 标已下线
**裁定**：项在包升级中被删除时：

- 它的**全部已学事件保留**（不删、不改）
- 项标 `retired`，在能力清单里**折叠到「历史」区**
- **不得从已学集合移除** —— 那会让进度倒退，直接破坏「进度永不倒退」

`src:` GOV Z4

### SPEC-PACK-017 迁移的幂等
**裁定**：迁移事件同样受 `id` UNIQUE 索引保护。同一版本迁移被重复应用时，第二次必须被拦掉（否则 `S` 会被打两次折）。
`src:` 推论（`event-types.md` 幂等）

### SPEC-PACK-018 内容包不进客户端资产
**裁定**：`pack.json` 由内容管线从源数据生成，**不入库**。客户端按**运行期 CWD** 在**候选根下的包目录**里探测它：

```text
<候选根>/<包目录>/pack.json
```

**候选根按 `kind` 分组**（`scanRoots(Map<PackKind, List<String>>)`）：`kind` 是**查询维度、不是存储位置** —— 同一个根可以同时列给多个 `kind`，同一个包因此在各 `kind` 的查询里**各出现一次**（`packRoot` 相同、`kind` 不同）；去重只在**同一 `kind` 内**按目录名进行。**目录名不承载 `kind`**：`Pack.kinds[]` 可多值（一个包既是载荷又带方法是合法形态），把 kind 写进路径必然漏掉其中一类。

**连带**：

- `flutter run` 必须在 `app/` 目录内执行，否则相对 CWD 的候选根找不到包。
- **旧形态取消**：`<仓根>/content/<空间>/dist/pack.json` 与同级 `manifest.json` 均已不再是包形态（`B14` 笔 5）。目录里**只有 `pack.json`** 才算一个包，探测的失败原因因此只剩两种 —— `missingPack`（文件不在，要么没构建、要么没随包分发）与 `unreadable`（在但读不出来）。**拆清单与产物两条失败原因已无对象**：单文件下它们是同一件事。

`src:` 第 5 轮 · `app/AGENTS.md` · `R-04` · `B14` 笔 5

---

## 验收表

| 裁定 | 可观测断言 | 测试向量 | 预期 |
|---|---|---|---|
| PACK-001 | 缺一条判据的粒度不能独立成包 | 提交只含「items 无 edges」的包 | 校验失败，提示缺独立 `⪯` |
| PACK-001 | 三判据齐全可独立成包 | `python` 包 | 校验通过 |
| PACK-005 | 六段缺一即格式错误，**不补空数组** | 删掉 `pack.json` 的 `entries` 段 | 解析失败并指名 `entries`，不产出空表 |
| PACK-005 | 顶层只允许清单字段与六段 | 加入 `meta` 或 `notes` 键 | 解析失败，报出那个键 |
| PLAN-012 | 体系顺序**不禁止**逆序，但代价必须算得出 | `nodes` 中前置排在后继之后 | 校验通过但 `inversions > 0` |
| PACK-005 | 含环的 edges 被拒 | `A→B, B→A` | 校验失败 |
| PACK-018 | 旧形态目录不算包 | 只有 `manifest.json` + `dist/pack.json`、无 `pack.json` | 不产出位置，报 `missingPack` 并指名 `pack.json` 路径 |
| PACK-007 | pack 无 notes 段 | 检索 `pack.json` 结构 | 无 `notes` 键 |
| PACK-008 | 带版本号的 id 被拒 | `id = "decorator@2.1.0"` | 校验失败 |
| PACK-011 | 提交后立即可学 | 提交一项后立即在宇宙中查找 | 该项可见（标「待审」），可建 Plan |
| PACK-014 | 拆分时笔记全额复制 | `X` 有一节 600 字笔记，拆为 `X1`/`X2` | `X1`、`X2` 各有完整 600 字（不是 300） |
| PACK-014 | 拆分时 `S` 打折 | `X` 的 `S = 100`，拆为 2 项 | `X1.S = X2.S = 50` |
| PACK-015 | 合并取大 | `A.S=40, B.S=90` 合并为 `C` | `C.S = 90` |
| PACK-016 | 孤儿项进度不倒退 | 删除一个已学项后重算进度 | 已学分子不变（项进「历史」） |
| PACK-017 | 迁移幂等 | 同一 `state_carried` 事件上传两次 | 只应用一次，`S` 只打折一次 |

# 事件类型表

> **唯一权威处**：事件类型全集与字段只在本文件定义。
> **铁律：事件是唯一事实源。** 所有可写状态必须由 `fold(events, asOf)` 得出；不得引入与之并行的可写状态表（会话游标、笔记版本、掌握度快照皆同）。

## 一、公共信封（所有事件共有）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 全局唯一。**`id` 建 UNIQUE 索引做上传幂等** —— 「同一条事件被传两次」只保留一条 |
| `type` | enum | 见 §二 |
| `hlc` | object | `{ physical: int, counter: int, deviceId: string }` —— **混合逻辑时钟**，离线也能生成且保证全序 |
| `spaceId` | string | 所属知识空间 |
| `userId` | string | **数据归属**。与 `hlc` 分工不同：`userId` 定「这条属于谁」，`hlc` 定「谁先谁后」。`v0.1.0` 取本地默认值，**非空、不写 `null`**（空值会让 `fold` 的过滤维度多出第三个分支）。见 [`ACC-013`](../design/ACC-accounts.md) |
| `itemId` | string \| null | 目标知识项；迁移类事件可为 null 或指向旧 id |
| `at` | string | ISO-8601，由 `hlc` 派生，供人阅读；**排序一律用 `hlc`，不用 `at`** |
| `payload` | object | 各类型自有字段，见 §二 |

### 全序与幂等的区分（必须分清，否则会做错）

| 问题 | 处理 |
|---|---|
| 两台设备各学了一遍**同一项** | **不去重**。你确实复习了两次，`S` 就该变长；去重反而违背复习语义。两个事件都重放 |
| **同一条事件**被上传两次（断网重传） | **幂等**。靠 `id` 的 UNIQUE 索引拦掉，只保留一条 |
| 同一台设备上**两个账号**各学了一遍同一项 | **按 `userId` 分开统计**，互不见。`fold` 必须按 `userId` 过滤，否则 A 的进度会算进 B（见 [`ACC-014`](../design/ACC-accounts.md)） |

### HLC 的一条实现约束

设备时钟偏差会污染 `physical` 部分（会出现「2031 年的事件排到今天前面」）。处置：**物理时间由服务端 clamp 校正，逻辑计数保证不倒退**。此条须在服务端实现时显式写出。

## 二、事件类型

### A. 学习执行（`STEP`）

| 类型 | 何时写 | 关键 payload | 是否写判定 | 状态 |
|---|---|---|---|---|
| `step_completed` | 某一步骤完成 | `stepIndex` · `operator`（6 类之一） | ❌ | 已定 |
| `item_graded` | **项末验收**（⑤） | `score`：`fail` / `pass` / `proficient`（未过 / 合格 / 熟练） · `progressKind`：`verified / checked` · `scaffold`：`none / hint / answer` | ✅ 唯一判定点 | 已定（字段为推论；`score` 的**线上取值**于 `B2` 第 3 笔补登记 —— 原文只写中文三档，`fold` 需要能对上的字符串） |
| `item_passed` | **首次**验收合格 | `gradedEventId` | ✅ 已学门槛，**不可撤销** | 已定 |
| `item_skipped` | 用户跳过该项 | 无 | ❌ 不写判定、不计 fail | 已定 |
| `graduated` | `S ≥ 180` 首次达成 | `sAtGraduation` | ✅ 状态转换，**不可逆** | 已定 |

**三条硬约束：**

1. **`step_completed` 不撤销**。回退到上一步是纯视图操作，只是重看；游标 fold 规则 = `max(已完成 stepIndex) + 1`。
2. **`item_graded` 是唯一的判定写入点**。步内自检是形成性的，**不写任何判定**（否则掌握度会被每步记一次污染）。
3. **复习时「未过」不改「已学」状态**。`item_passed` 一旦写入不撤销；复习未过只降 `S`、提前 `due`、降掌握度，**进度分母不动**。

### B. 计划（`PLAN`）

| 类型 | 何时写 | 关键 payload | 状态 |
|---|---|---|---|
| `plan_created` | 建计划完成 | `spaceVersion` · `target{selector, resolved}` · `sourcePolicy` · `schemeId` · `methodProfileId` | 已定（`B4` 第 6 笔补登记 —— 原文写 `target{selector, resolvedCount}` 且把 `spaceId` 也列进来，两处都错，见下） |
| `plan_revised` | Runner 暴露缺口后回 Planner 重规划 | 同上 + `planId`（指回创建事件） | 已定（原文写「`version = 前值 + 1`」，`B4` 第 6 笔改为不写 `version`，见下） |

**`Plan` 的身份 = `plan_created` 事件的 `id`。** `plan_created` 的 payload **不写 `planId`** —— 一个实体既有自己的 id、又有创建事件的 id，两者表达同一件事，迟早出现「对不上」的回放歧义，而它没有信息增量。反过来 `plan_revised` **必须**带 `planId`：同空间可并存多份（`SPEC-PLAN-003`），没有这个字段就折不出「改的是哪一份」，「建两份 Plan，两份独立存在」这条验收向量在事件层无法表达。

**`spaceId` 不进 payload。** 信封上已有（`Event.spaceId`），它还是 `fold(spaceId:)` 的过滤维度；payload 再写一份，就会出现「过滤时按信封、还原时按 payload」的分裂。

**`version` 不进 payload。** 它由 `fold` 数该 `planId` 名下的事件条数得出，与笔记版本同一口径（`noteVersion` = 该节 `note_revised` 计数）。写在 payload 里就是第二份计数：重传、乱序、或有人手改一条，两处必然打架。

**`target` 的键是 `{selector, resolved}`，`count` 派生、不序列化。** 原表写 `resolvedCount`、`PlanTarget.toJson()` 曾写 `count`，三处三个名字，同一个量变成三个字段。

> `Plan` 是**多次意图**，同一空间可并存多份（如「入门跑通」与「专攻异步」）。`Plan` 的键是 `spaceId`，**不存在跨空间的「总 Plan」**。

### C. 内容迁移（`PACK` / `GOV`）

| 类型 | 何时写 | 关键 payload | 状态 |
|---|---|---|---|
| `state_carried` | 项被**拆分**为新子项 | `fromItemId` · `toItemIds[]` · `ratio = 1/n` | 已定 |
| `state_merged` | 项被**合并** | `fromItemIds[]` · `toBeId` · `rule = maxS` | 已定 |
| `item_retired` | 项在包升级中**被删除** | `itemId` · `spaceVersion` | 已定 |

**迁移必须事件化。** 若把「复制多少状态」的折算规则写在 `fold` 外面，就等于事件流之外还有一份魔法，事件溯源出现破口。

### D. 笔记（`NOTE`）

| 类型 | 何时写 | 关键 payload | 状态 |
|---|---|---|---|
| `note_revised` | 每节内容被修改 | `itemId` · `sectionKey` · `text`（正文） · `layer = authored` · `targetVersion`（回滚时指向目标版本，此时 `text` 可缺省） | 已定（`text` 于 `B2` 第 3 笔补登记 —— 原文只说「正文走 `note_revised` 的 payload」，没定字段名；`fold` 要解析它，名字必须在表里） |

**版本由事件折叠得出**：`noteVersion` = 该节 `note_revised` 计数。**回滚 = 追加一条带 `targetVersion` 的事件，不删历史。**
回滚事件的正文由 `fold` 解析为目标版本的正文并记到新版本上 —— 这样「连续回滚两次到同一版本」与「回滚到前一版」都得出一致的当前正文，而版本号仍然只增不减。

> 任何要跨设备同步的可写状态，其修改都必须是事件 —— 这不是「要不要留版本」的选择，而是「能不能跨设备用」的前提。

### E. 账号（`ACC`）

| 类型 | 何时写 | 关键 payload | 是否写判定 | 状态 |
|---|---|---|---|---|
| `identity_adopted` | `v0.1.0` 的本地事件在 `v0.2.0` 首次登录时被认领到某个账号 | `toUserId` · `itemIdRange`（可空，为空表示整空间） · `adoptedAt` | ❌ | 推论（2026-10-18 登记，实现于 `v0.2.0`） |

**认领只追一条事件，不改写历史。** 既有事件的 `userId` 字段保持原值，`fold` 读到 `identity_adopted` 后把该范围内的事件视为归属 `toUserId`。

**为什么不批量改写**：改写违反 `R3`（事件只 append），且历史事件一旦被改写，「当时究竟是谁写的」就无法再复原 —— 而这恰恰是 `v0.2.0` 之后排查进度异常时最需要的信息。

**`itemIdRange` 为空时不是「全部空间」**：它是「认领该 `spaceId` 下的全部匿名事件」。跨空间的认领要逐空间各写一条。

## 三、不写入事件的东西（明确排除）

| 项 | 为什么 |
|---|---|
| 会话游标 | 由 `step_completed` fold 得出（`(itemId, stepIndex)`），不建 `SessionCursor` 表 —— 否则多一个「表与事件不一致以谁为准」的新问题 |
| `R(t)` 当前可提取率 | 由 `D`/`S` 与经过时间算得，派生值 |
| 掌握度 `mastery` | 由 `D`/`S` + 六要件完整度算出，派生值 |
| 进度百分比 | 由 `item_passed` 计数 / 圈内项数算得，派生值 |
| 笔记内容正文 | 正文走 `note_revised` 的 payload；**不另存一份当前态快照** |
| 界面状态（`ViewState`） | 属本地偏好，不是学习事实；跨设备同步策略另行处理 |

## 四、新增事件类型的纪律

1. 先在本表登记（含 payload 字段与是否写判定），再实现。
2. **凡写判定的事件，必须能回答「它写入哪个量化量」**；答不出的，说明它不该写判定。
3. 事件字段变更须考虑**历史事件重放**：新增字段一律可空，且 fold 时必须有默认语义。

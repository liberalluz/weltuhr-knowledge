# 软件测试说明（STD）

> **状态**：**内容第一次写进产物 —— `entries.json` 与一个域的真步骤** —— 新增 `content/python/entries.json`（15 条：摘要 · 正文 · 5 步执行序列 · 步骤自检 · 预计时长 · 6 条真写的断言），`assemble_pack.py` 由「只给有题的节点建 `entry`」改为「有题**或有内容**就建」，并在搬运期拦四类输入契约（算子不在六类 · 步骤全是首学算子 · 断言指向不存在的题 · `itemId` 错字）。同批补 `git-conventions` `§4.2` 收尾判据：`git branch` 与 `git branch -r` 都只剩 `main`，且本批手工造的 ref 一个不剩。§三 新增 §3.59 **4 条** `TC-BOOT-006`–`009`：内容进产物 · 至少一步复习 · 断言与题 1:1 且非模板兜底 · 详情页渲染真步骤。§三 用例表 **824 条**（含 66 条作废保留行），`flutter test` **444 → 448**。逐版摘要见文末「历史（迁移前版号序列）」表。
> 本文件是**用例正文**。测什么与通过判据见 [`STP`](stp.md)；**仓内当前读数见 §六**。
> **追溯补录**：2026-10-17 · §三 依据 `app/test/` 与 `content/tools/fixtures/` 的既有测试逐条反推，非当时所写。

## 一、用例编号

格式 **`TC-<域>-<NNN>`**，域与 `SPEC-*` 的八域一致（`FND` `VIEW` `PACK` `PLAN` `STEP` `QUANT` `NOTE` `GOV`），另设 `INF` 域承载跨域与基础设施用例（内容管线、CI、架构约束）。

| 项 | 规则 |
|---|---|
| 编号稳定 | 用例编号一旦被 `STR` 引用，**不得改写**；废弃用「已废弃」标注，不删号 |
| 与需求对应 | 每条用例在「对应 `SPEC`」列写出它验证的编号，**一条需求至少一条用例** |
| 与实现对应 | 「自动化位置」列写出实际测试文件与测试名，便于重跑 |

## 二、用例格式

| 列 | 填什么 |
|---|---|
| 编号 | `TC-<域>-<NNN>` |
| 对应 `SPEC` | 一条或多条编号 |
| 前置 | 数据与状态前提 |
| 步骤 | 可照做的动作序列 |
| 预期 | **可观测断言**，不得写「正常」「无误」 |
| 类型 | 单元 / Widget / 管线 / 架构 / 手工 |
| 自动化位置 | 文件路径 + 测试名；手工项写「手工」 |

## 三、用例表

**「依据」列的三档**（决定这条追溯有多可信）：

| 档 | 含义 | 能否直接用于审核 |
|---|---|---|
| **显式** | 测试代码或 fixture 的 `expect.json` 里**写了 `SPEC` 编号** | ✅ 可 |
| **语义** | 未写编号，但用例断言的内容与该 `SPEC` 标题所述语义一致，由本文件判定 | ⚠️ 需人复核一次 |
| **—** | 约束来自常量表投影或结构约定，**没有单一 `SPEC` 与之对应** | ✅ 可（对应物是 `C-xx` 或结构约定） |

> 显式档少得刺眼（见 §四），这不是用例没写，而是**测试名与代码注释几乎不标 `SPEC` 编号**。追溯链断在标号上，不在测试上。

### 3.1 `FND` 域（7 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-FND-001` | `FND-011` | 语义 | 三个 `Hlc`：`(100,0,'b')` `(100,0,'c')` `(100,1,'a')` | 两两 `compareTo` | `physical → counter → deviceId` 三级全序：`a<b`、`b<c`、`c>a` | 单元 | `app/test/core/events_test.dart` · `HLC 全序比较` |
| `TC-FND-002` | `FND-011` | 语义 | 两个三元组相同的 `Hlc` | 比 `==` 与 `hashCode` | 相等且哈希一致 | 单元 | 同上 · `相同三元组相等且哈希一致` |
| `TC-FND-003` | — | — | 一条 `itemPassed` 事件 | 取 wire 名 → `fromJson(toJson())` | wire 名 = `item_passed`；`id`/`type`/`hlc`/`itemId`/`payload` 全部往返保真 | 单元 | 同上 · `线上类型名为 snake_case，往返保真` |
| `TC-FND-004` | — | — | `EventType.values` 全集 | 逐个取 wire 名并去重 | 去重后数量 = 枚举数量；含 `step_completed`、`note_revised` | 单元 | 同上 · `事件类型全集都有唯一 wire 名` |
| `TC-FND-005` | `FND-014` | 语义 | 未注册的 wire 名 `unknown_event` | 调 `eventTypeFromWire` | 抛 `FormatException`，**不回落默认类型** | 单元 | 同上 · `未知 wire 名抛 FormatException` |
| `TC-FND-006` | — | — | 一条迁移类事件 `itemRetired`，不传 `itemId` | `fromJson(toJson())` | `itemId` 为 `null` 且不报错 | 单元 | 同上 · `itemId 可为空（迁移类事件）` |
| `TC-FND-007` | `FND-005` | 语义 | `neg-cycle`（`valid-min` + 一条闭合边） | `verify.py` 跑该 fixture | 退出码 1，含 `E-CYCLE` | 管线 | `content/tools/fixtures/neg-cycle/expect.json` |

### 3.2 `PACK` 域（10 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-PACK-001`~~ | — | — | ~~一份合法 `Item` JSON~~ | — | **已作废**（`B13a` 笔 6）：旧 `Item` 单体的往返随 `ADR-0007` 拆成 `Node` / `NodeEntry` 两分而失去对家；且 `entities_test.dart` 里从来没有「往返保真」这条用例 —— **原落点是假话**。欠账如实登记：两分的往返保真当前无自动化，落点待补 | 单元 | — |
| `TC-PACK-002` | `PACK-009` | 语义 | 同上，但 `requirements` 删掉 `tacit` 一格 | `fromJson` | 抛 `FormatException`，**不补默认值** | 单元 | `app/test/core/entities_test.dart` · `六要件缺一格即格式错误，不补默认值（SPEC-PACK-009）` |
| `TC-PACK-003` | `PACK-005` | 语义 | `valid-min`（五段齐全、六要件三态齐全、含一条 `type=unknown` 边） | `verify.py` 跑该 fixture | 退出码 0；`scheme-official-tutorial` 的 `inversions` = 0 | 管线 | `fixtures/valid-min/expect.json` |
| `TC-PACK-004` | `PACK-008` | 语义 | `neg-dupid`：两项共用同一 `Node.id` | 同上 | 退出码 1，含 `E-ID-DUP` | 管线 | `fixtures/neg-dupid/expect.json` |
| `TC-PACK-005` | `PACK-001` | **显式** | `neg-no-order`：文件在、段齐，但 `edges` 为空 | 同上 | 退出码 1，含 `E-SPACE-NO-ORDER`（无独立 `⪯` ⇒ 应降为域而非成包） | 管线 | `fixtures/neg-no-order/expect.json` |
| `TC-PACK-006` | `PACK-009` | 语义 | `neg-req-value`：三态出现 `partial` | 同上 | 退出码 1，含 `E-REQ-VALUE`（三态只允许 present/missing/not_externalizable） | 管线 | `fixtures/neg-req-value/expect.json` |
| `TC-PACK-007` | `PACK-009` | **显式** | `neg-requirements`：`function` 缺 `tacit`；`class` 的 `relation` 为 `null` | 同上 | 退出码 1，含 `E-REQ-KEY` **与** `E-REQ-STATE`（两者都要报，不是只报第一个） | 管线 | `fixtures/neg-requirements/expect.json` |
| `TC-PACK-008` | `PACK-005` | 语义 | `neg-version-space`：`manifest.version` 带前导空格 | 同上 | 退出码 1，含 `E-VERSION-FORMAT`；**不得静默 strip** | 管线 | `fixtures/neg-version-space/expect.json` |
| `TC-PACK-009` | `PACK-008` · `FND-013` | **显式** | `neg-versioned-id`：`Node.id` 写成 `python/decorator@2.1.0` | 同上 | 退出码 1，含 `E-ID-VERSIONED` | 管线 | `fixtures/neg-versioned-id/expect.json` |
| `TC-PACK-010` | `PLAN-012` | **显式** | `valid-inversion`：`nodes` 把 `class` 排在 `function` 之前 | 同上 | 退出码 0（逆序**不禁止**），但 `inversions` 必须算出 = 1 | 管线 | `fixtures/valid-inversion/expect.json` |
| `TC-PACK-011` | — | — | `neg-manifest-missing`：`drop` 掉 `manifest.json` | 同上 | 退出码 1，含 `E-MANIFEST-MISSING` | 管线 | `fixtures/neg-manifest-missing/expect.json` |
| `TC-PACK-012` | — | — | `neg-manifest-required`：删 `name` / `accent` / `order` | 同上 | 退出码 1，含 `E-MANIFEST-FIELD`（走「缺字段」路径） | 管线 | `fixtures/neg-manifest-required/expect.json` |
| `TC-PACK-013` | — | — | `neg-manifest-field`：`name` 空串 · `accent` 缺 `#` · `order=true` · `domainIds` 重复 | 同上 | 退出码 1，含 `E-MANIFEST-FIELD`（走「值非法」路径，**`order` 为 bool 也须拒**） | 管线 | `fixtures/neg-manifest-field/expect.json` |
| `TC-PACK-014` | `PACK-005` | 语义 | `neg-segment-missing`：`drop` 掉 `questions.json` | 同上 | 退出码 1，含 `E-SEGMENT-MISSING` | 管线 | `fixtures/neg-segment-missing/expect.json` |
| `TC-PACK-015` | `PACK-005` | 语义 | `neg-segment-type`：`schemes.json` 写成 object | 同上 | 退出码 1，含 `E-SEGMENT-TYPE` | 管线 | `fixtures/neg-segment-type/expect.json` |
| `TC-PACK-016` | — | — | `neg-json`：`items.json` 语法截断 | 同上 | 退出码 1，含 `E-JSON`；**单段解析失败不得终止其余段的检查** | 管线 | `fixtures/neg-json/expect.json` |
| `TC-PACK-017` | `FND-002` | 语义 | `neg-sixaxis`：manifest 多出 `level` 轴；item 的 `ability` 写成数组 | 同上 | 退出码 1，含 `E-SIXAXIS` | 管线 | `fixtures/neg-sixaxis/expect.json` |
| `TC-PACK-018` | — | — | `neg-item-field`：缺 `title` · `sourceRefs` 非数组 · `inScope` 非布尔 · `domainId` 非字符串 · 混入非 object 元素 | 同上 | 退出码 1，含 `E-ITEM-FIELD`（五条路径一次跑完） | 管线 | `fixtures/neg-item-field/expect.json` |
| `TC-PACK-019` | `FND-003` | 语义 | `neg-layer-type`：`layer=permanent` · `type=concept` | 同上 | 退出码 1，含 `E-LAYER` **与** `E-TYPE` | 管线 | `fixtures/neg-layer-type/expect.json` |
| `TC-PACK-020` | `FND-013` | 语义 | `neg-id-format`：`variable`（缺空间前缀）· `python/Variable`（slug 大写） | 同上 | 退出码 1，含 `E-ID-FORMAT` | 管线 | `fixtures/neg-id-format/expect.json` |
| `TC-PACK-021` | — | — | `neg-domain`：`domainId=python/advanced` 不在 `manifest.domainIds` | 同上 | 退出码 1，含 `E-DOMAIN` | 管线 | `fixtures/neg-domain/expect.json` |
| `TC-PACK-022` | — | — | `neg-edge-field`：边缺 `to` · 缺 `type` · id 含大写 | 同上 | 退出码 1，含 `E-EDGE-FIELD` | 管线 | `fixtures/neg-edge-field/expect.json` |
| `TC-PACK-023` | — | — | `neg-edge-type`：`type=hard` | 同上 | 退出码 1，含 `E-EDGE-TYPE` | 管线 | `fixtures/neg-edge-type/expect.json` |
| `TC-PACK-024` | — | — | `neg-edge-ref`：`from` / `to` 各指向不存在的项（`type=strong`） | 同上 | 退出码 1，含 `E-EDGE-REF`；**`type=unknown` 的悬空 `to` 不在此列** | 管线 | `fixtures/neg-edge-ref/expect.json` |
| `TC-PACK-025` | — | — | `neg-edge-dup`：同一对 `from`/`to` 出现两次（id 不同） | 同上 | 退出码 1，含 `E-EDGE-DUP` | 管线 | `fixtures/neg-edge-dup/expect.json` |
| `TC-PACK-026` | — | — | `neg-scheme-field`：缺 `name` · `nodes` 为空数组 | 同上 | 退出码 1，含 `E-SCHEME-FIELD` | 管线 | `fixtures/neg-scheme-field/expect.json` |
| `TC-PACK-027` | — | — | `neg-scheme-auth`：`authorityLevel=L3` | 同上 | 退出码 1，含 `E-SCHEME-AUTH`（`L3` 不存在） | 管线 | `fixtures/neg-scheme-auth/expect.json` |
| `TC-PACK-028` | — | — | `neg-scheme-dup`：`nodes` 里 `python/variable` 出现两次 | 同上 | 退出码 1，含 `E-SCHEME-DUP` | 管线 | `fixtures/neg-scheme-dup/expect.json` |
| `TC-PACK-029` | — | — | `neg-scheme-node-ref`：`nodes` 引用 `python/nope` | 同上 | 退出码 1，含 `E-SCHEME-NODE-REF` | 管线 | `fixtures/neg-scheme-node-ref/expect.json` |
| `TC-PACK-030` | — | — | `neg-question-field`：删 `prompt` | 同上 | 退出码 1，含 `E-QUESTION-FIELD` | 管线 | `fixtures/neg-question-field/expect.json` |
| `TC-PACK-031` | — | — | `neg-question-ref`：`itemId=python/nope` | 同上 | 退出码 1，含 `E-QUESTION-REF` | 管线 | `fixtures/neg-question-ref/expect.json` |
| `TC-PACK-032` | — | — | `neg-excerpt-field`：缺源 `version` · 段落缺 `license` | 同上 | 退出码 1，含 `E-EXCERPT-FIELD` | 管线 | `fixtures/neg-excerpt-field/expect.json` |
| `TC-PACK-033` | — | — | `neg-sourceref`：`sourceRefs` 含 `no-such-source` | 同上 | 退出码 1，含 `E-SOURCEREF`（交叉引用，须等 `excerpts` 读完才判） | 管线 | `fixtures/neg-sourceref/expect.json` |
| `TC-PACK-034` | `PACK-005` | 语义 | `pack-ok`：五段齐全 + 两键 `meta` 的产物 | `verify.py --suite` 的产物层 | 退出码 0（**正例**：没有它，负例变红说明不了问题） | 管线 | `fixtures/pack/pack-ok/expect.json` |
| `TC-PACK-035` | — | — | `pack-not-object`：产物顶层是数组 | 同上 | 退出码 1，含 `E-PACK-TYPE` | 管线 | `fixtures/pack/pack-not-object/expect.json` |
| `TC-PACK-036` | `PACK-007` | **显式** | `pack-extra-key`：产物多出 `notes` 段 | 同上 | 退出码 1，含 `E-PACK-EXTRA-KEY` | 管线 | `fixtures/pack/pack-extra-key/expect.json` |
| `TC-PACK-037` | `PACK-005` | 语义 | `pack-missing-key`：产物少 `excerpts` 段 | 同上 | 退出码 1，含 `E-PACK-MISSING-KEY` | 管线 | `fixtures/pack/pack-missing-key/expect.json` |
| `TC-PACK-038` | `PACK-005` | 语义 | `pack-meta-field`：`meta` 写成字符串 | 同上 | 退出码 1，含 `E-META-FIELD` | 管线 | `fixtures/pack/pack-meta-field/expect.json` |
| `TC-PACK-039` | `PACK-005` | **显式** | `pack-meta-extra-key`：`meta` 混进 `builtAt` | 同上 | 退出码 1，含 `E-META-EXTRA-KEY`（时间戳会破坏构建确定性） | 管线 | `fixtures/pack/pack-meta-extra-key/expect.json` |
| `TC-PACK-040` | `PACK-005` | 语义 | `pack-meta-version-mismatch`：`meta.version=0.1.1`，源为 `0.1.0` | 同上 | 退出码 1，含 `E-META-VERSION` | 管线 | `fixtures/pack/pack-meta-version-mismatch/expect.json` |
| `TC-PACK-041` | `PACK-005` | 语义 | `pack-meta-version-format`：`meta.version=0.1`（两段式） | 同上 | 退出码 1，含 `E-META-VERSION`（非三段 semver） | 管线 | `fixtures/pack/pack-meta-version-format/expect.json` |

> **`TC-PACK-011`–`041` 的「对应 `SPEC`」多为 `—`，这是有意的**：这 31 条测的是**字段级判据**，其权威处是 [`docs/specs/entity-fields.md`](../entity-fields.md) 的各节，不是 `SPEC-*`。硬凑一个编号会让追溯表看起来完整、实际指错地方 —— 那正是 `R-09` 要防的形态。能确定对应的（`PACK-005` 的**旧五段形态**与 `meta` 信封、`PACK-007` 段集合、`FND-002` 六轴、`FND-003` 三层、`FND-013` 稳定 id）已如实填。

> ✅ **`TC-PACK-010` 的标号已核（2026-10-25）**：fixture 的 note 原写「`SPEC-PACK-005`：逆序不禁止」，而 `PACK-005` 讲的是**包形态**、从不承载逆序语义。已改标 `SPEC-PLAN-012`（同一句语义的权威处），fixture note 与本行同步 —— 原挂 §五 的待核项据此关闭。

### 3.3 `QUANT` 域（9 条）

> **`TC-QUANT-007` 已改靶（`v0.25.0`）**：原来锁的是「读 `fuzzyMatchThreshold` 即抛 `TbdConstantError`」。`C-28` 于 2026-10-18 裁定为 **v0.1 不适用**后，该常量已从代码里删除、哨兵没有使用者 —— 继续锁它就是锁一个不存在的符号。现改锁**裁定内容本身**：模糊档 = 连续包含（跨字不命中）。
>
> 编号与域**不动**：编号一旦被 `STR` 引用不得改写（§一），而它测的仍然是常量表里 `C-28` 这一行所承载的判据，只是落地位置从 `constants_test.dart` 挪到了 `locator_test.dart`。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-QUANT-001` | — | — | 常量表 | 读 `sZeroDays` / `graduationSDays` | `30` / `180`（= `C-01` / `C-02`） | 单元 | `app/test/core/constants_test.dart` · `C-01 / C-02` |
| `TC-QUANT-002` | — | — | 同上 | 读 `fsrsTargetRetention` / `checkinCap` | `0.90` / `0.5`（= `C-03` / `C-25`，2026-10-17 裁定值） | 单元 | 同上 · `C-03 / C-25` |
| `TC-QUANT-003` | — | — | 同上 | 读会话、配额、失败阈值 | `sessionBudgetMinutes=25` · `reviewPoolCap=20` · `newPoolCap=5` · `failStreakToGap=2` · `skipStreakHint=3` · `skipEventsWritten=0`（`C-05`–`C-11`） | 单元 | 同上 · `C-05…C-11` |
| `TC-QUANT-004` | — | — | `carryRatio` | 传 2 / 4 / 0 | `0.5` / `0.25` / 抛 `ArgumentError`（`C-12` 拒绝非法拆分数） | 单元 | 同上 · `C-12 carryRatio` |
| `TC-QUANT-005` | `STEP-012` | 语义 | 六类算子枚举 | 比 `operatorMinutes.length` 与枚举长度；逐项读系数 | 等长；`read=3` `example=2` `recall=1` `practice=5` `teach=5` `build=30`（`C-14`–`C-19`） | 单元 | 同上 · `C-14…C-19` |
| `TC-QUANT-006` | `STEP-022` | 语义 | 常量表 | 读 `scaffoldCap` | `Grade.pass`（`C-26`：脚手架封顶到「合格」，熟练档关闭） | 单元 | 同上 · `C-26 脚手架封顶` |
| `TC-QUANT-007` | — | `C-28` | 夹具包（`装饰器` / `装饰器参数`） | 搜「饰器参」；再搜「饰器数」 | 前者命中「装饰器参数」且 `strength == fuzzy`；后者**空集** —— 连续包含才命中，不是编辑距离。这条锁的是 `C-28` 裁定的可判边界 | 单元 | `app/test/core/locate/locator_test.dart` · `模糊档 = 子串包含：连续才命中，跨字不命中（C-28：v0.1 不设相似度阈值）` |
| `TC-QUANT-008` | `QUANT-006` | **显式** | `LearnableNode` 六要件：2 格 `complete`、1 格 `notExternalizable`、3 格 `missing` | 读 `requirements.completeCount` / `externalizableCount` | `2` / `5` —— 不可外化格**不进深度分母** | 单元 | `app/test/core/entities_test.dart` · `不可外化格不进深度分母` |
| `TC-QUANT-009` | — | — | 方法全部步骤无判据；另一步骤带 `hint` | 读 `isCheckin` / `hasAnyHint` | `isCheckin=true`、`hasAnyHint=false` | 单元 | 同上 · `全部步骤无判据 ⇒ 打卡式` |

### 3.4 `STEP` 域（3 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-STEP-001` | `STEP-014` | 语义 | 两个 `MethodStep`：`operator=read` / `operator=practice`，均不写 `phase` | 读 `effectivePhase` | `read → first`、`practice → both` | 单元 | `app/test/core/entities_test.dart` · `读 → first；练 → both` |
| `TC-STEP-002` | `STEP-014` | 语义 | `operator=read` 且显式写 `phase=review` | 读 `effectivePhase` | `review` —— 作者写的值覆盖派生值 | 单元 | 同上 · `作者可覆盖派生的 phase` |
| `TC-STEP-003` | `STEP-027` | 语义 | 方法 A：`read` + `recall`；方法 B：`read` + `example` | 读 `hasReviewStep` | A `true`、B `false`（全为读/例 ⇒ 无 review 步骤） | 单元 | 同上 · `至少一个 review 步骤` |

### 3.5 `PLAN` / `NOTE` / `VIEW` 域（3 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-PLAN-001` | — | — | `Plan` 的 `target` 含 `selector` 与 `resolved`（3 项），**不写 `count`** | 读 `target.count`；再 `toJson()` | `count == 3`；序列化后 `target` 含 `count: 3` —— 由 `resolved` 派生，不单独存 | 单元 | `app/test/core/entities_test.dart` · `target.count 由 resolved 派生` |
| `TC-NOTE-001` | — | — | `Note` 三层同时有值：`generated` / `autoFilled` / `authored` | 读 `displayText` / `noteVersion` | `手写层`（`authored` 优先）、`noteVersion == 3` | 单元 | 同上 · `authored > autoFilled > generated` |
| `TC-VIEW-001` | — | — | 常量表 | 读 `deepChainPhi` / `trailCap` / `viewTransitionMinMs` / `viewTransitionMaxMs` / `lodBrightnessFar` / `lodBrightnessNear` | `5` / `5` / `180` / `220` / `3` / `7`（`C-20`–`C-23`） | 单元 | `app/test/core/constants_test.dart` · `C-20…C-23 界面阈值` |

### 3.6 `INF` 域（40 条 · 架构约束与外壳）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-INF-001` | — | — | 一段 `core/` 代码 import `package:flutter/...` | 跑 `R1` | 报违规 | 架构 | `app/test/lint/rules_test.dart` · `core 引用 Flutter 被拦` |
| `TC-INF-002` | — | — | 同上，import `dart:ui` | 跑 `R1` | 报违规 | 架构 | 同上 · `core 引用 dart:ui 被拦` |
| `TC-INF-003` | — | — | 同上，import `features/` 下文件 | 跑 `R1` | 报违规 | 架构 | 同上 · `core 引用 features/ 被拦` |
| `TC-INF-004` | — | — | `features/` 代码 import Flutter | 跑 `R1` | **不报**（UI 层本就该用） | 架构 | 同上 · `features 引用 Flutter 不拦` |
| `TC-INF-005` | — | — | `core/` 非常量表文件出现数字字面量 | 跑 `R2` | 报违规，且**行号正确** | 架构 | 同上 · `普通数字被拦，并报出行号` |
| `TC-INF-006` | — | — | 同上，文件为 `constants.dart` | 跑 `R2` | **不报**（唯一豁免点） | 架构 | 同上 · `constants.dart 豁免` |
| `TC-INF-007` | — | — | `core/` 出现 `0` 与 `1` | 跑 `R2` | **不报**（坐标原点与计数基元） | 架构 | 同上 · `0 与 1 放行` |
| `TC-INF-008` | — | — | 数字出现在注释与字符串里 | 跑 `R2` | **不误报** | 架构 | 同上 · `注释与字符串里的数字不误报` |
| `TC-INF-009` | — | — | `features/` 出现数字字面量 | 跑 `R2` | **不查**（间距属设计 token） | 架构 | 同上 · `features 层不查数字` |
| `TC-INF-010` | `FND-014` | 语义 | 无内容包 | 挂载应用外壳 | 渲染空态，标题为 `Weltuhr`；**不补默认星系、不填假数据** | Widget | `app/test/widget_test.dart` · `空态外壳可渲染` |
| `TC-INF-011` | `FND-012` | **显式** | `Event` 加了 `copyWith` | 跑 `R3` | 报违规 —— 「复制改写历史」必须被拦 | 架构 | `app/test/lint/rules_test.dart` · `Event 加 copyWith 被拦` |
| `TC-INF-012` | `FND-012` | **显式** | `Event` 出现非 `final` 字段 | 跑 `R3` | 报违规 —— 可变字段等于可变事件 | 架构 | 同上 · `Event 出现可变字段被拦` |
| `TC-INF-013` | `FND-012` | 语义 | `class StepEvent extends Event` 且含可变字段 | 跑 `R3` | 报违规 —— 子类不豁免 | 架构 | 同上 · `Event 的子类同样受限` |
| `TC-INF-014` | `FND-012` | **显式** | `EventStore` 出现 `delete()` | 跑 `R3` | 报违规 —— 删除 / 覆盖类方法一律禁 | 架构 | 同上 · `EventStore 出现 delete 被拦` |
| `TC-INF-015` | `FND-012` | 语义 | `Event` 全 `final`；`EventStore` 只有 `append` / `readAll` | 跑 `R3` | **不报**（正例：没有它，上面四条的「被拦」说明不了是规则在起作用） | 架构 | 同上 · `全 final 且只 append / readAll 不误报` |
| `TC-INF-016` | `VIEW-004` | **显式** | `frame_painter.dart` 构造参数类型为 `SourceRef` | 跑 `R4` | 报违规 —— 源不进视觉通道 | 架构 | 同上 · `绘制层按类型收源被拦（R4）` |
| `TC-INF-017` | `VIEW-004` | 语义 | `frame_painter.dart` 方法参数名为 `sourceRefs`，类型写 `Object?` | 跑 `R4` | 报违规 —— **只改类型躲不掉** | 架构 | 同上 · `绘制层按参数名收源被拦（R4：类型写成 Object 也躲不掉）` |
| `TC-INF-018` | `VIEW-004` | 语义 | `core/entities/entry.dart` 的 `NodeEntry` 构造参数收 `SourceRef` | 跑 `R4` | **不报**（源本来就该在核心层流转） | 架构 | 同上 · `core 实体层收源不拦（R4 只管视觉通道）` |
| `TC-INF-019` | `VIEW-004` | 语义 | 视图层参数名 `resourceId` | 跑 `R4` | **不误报** —— 判据是 `source` 不是 `resource` | 架构 | 同上 · `resourceId 不误报（R4：判据是 source 不是 resource）` |
| `TC-INF-024` | `VIEW-004` | 语义 | `core/frame/scene.dart` 构造参数收 `SourceSegment` | 跑 `R4` | 报违规 —— **场景装配也算视觉通道**（`v0.15.0` 收窄后补的边界） | 架构 | 同上 · `场景装配层收源被拦（R4：core/frame 也算视觉通道）` |
| `TC-INF-025` | `VIEW-004` | 语义 | `features/detail/detail_panel.dart` 构造参数收 `SourceRef` | 跑 `R4` | **不报** —— `SPEC-VIEW-004` 要求源写进详情页；收窄前这条会误判为违规 | 架构 | 同上 · `详情页显示源名不拦（R4 收窄后只管通道，SPEC-VIEW-004 要求写进详情）` |
| `TC-INF-020` | — | — | 测试名无任何标号 | 跑 `R5` | 报违规，并指名该测试 | 架构 | 同上 · `无标号的 test 被拦` |
| `TC-INF-021` | — | — | 测试名分别带 `SPEC-…` / `C-…` / `ADR-…` / `R<n>` | 跑 `R5` | 四种标号**全部放行** | 架构 | 同上 · `SPEC 编号、常量编号、ADR、规则号都算合规标号` |
| `TC-INF-022` | — | — | 测试名写「无 SPEC：<理由>」 | 跑 `R5` | **放行** —— 写不出标号时允许显式豁免，不允许静默留空 | 架构 | 同上 · `显式豁免放行` |
| `TC-INF-023` | — | — | `lib/` 下出现 `test('…')` 调用 | 跑 `R5` | **不查**（`R5` 只管 `test/`） | 架构 | 同上 · `lib 下的 test 调用不查` |
| `TC-INF-026` | — | — | `StructuralNode` 类体声明 `final String? layer;` | 跑 `R6` | 报违规，指名 `layer` | 架构 | 同上 · `StructuralNode 声明 layer 被拦` |
| `TC-INF-027` | — | — | `StructuralNode` 只声明 `slug` | 跑 `R6` | **不报** —— 三项之外随便加 | 架构 | 同上 · `StructuralNode 不带三项放行` |
| `TC-INF-028` | — | — | 类名叫 `Structural`（不是 `StructuralNode`）且声明 `layer` | 跑 `R6` | **不查** —— 判据按类名，不按字段名 | 架构 | 同上 · `同名类不在册时不管` |
| `TC-INF-029` | — | — | `LearnableNode` 的 `type` / `layer` / `requirements` 全非可空 | 跑 `R7` | **不报** | 架构 | 同上 · `三项齐全且非空放行` |
| `TC-INF-030` | — | — | 同上，但 `layer` 写成 `Layer?` | 跑 `R7` | 报违规，指名 `layer` —— `null` 不是合法取值 | 架构 | 同上 · `一项写成可空被拦` |
| `TC-INF-031` | — | — | 同上，但整条 `requirements` 没声明 | 跑 `R7` | 报违规，指名 `requirements` —— 缺字段与写成可空**同一类错** | 架构 | 同上 · `缺一项被拦` |
| `TC-INF-032` | — | — | 代码里 `Node(id: 'a')` | 跑 `R8` | 报违规 | 架构 | 同上 · `直接构造 Node 被拦` |
| `TC-INF-033` | — | — | `Node` 类体内声明 `factory Node.make()` | 跑 `R8` | 报违规 —— `factory` 会在子类槽位校验之外造实例 | 架构 | 同上 · `Node 类体内有 factory 被拦` |
| `TC-INF-034` | — | — | 代码里 `StructuralNode(id: 'a')` | 跑 `R8` | **不报** —— 建子类不等于直接构造基类 | 架构 | 同上 · `建子类不算直接构造` |
| `TC-INF-035` | — | — | `Node` 类体声明 `final String path;` | 跑 `R9` | 报违规，指名 `path` | 架构 | 同上 · `Node 声明 path 被拦` |
| `TC-INF-036` | — | — | `StructuralNode` 声明 `final int depth = 0;` | 跑 `R9` | 报违规 —— 子类同样受管 | 架构 | 同上 · `子类声明 depth 同样被拦` |
| `TC-INF-037` | — | — | 无关类 `Route` 声明 `final String path;` | 跑 `R9` | **不查** —— 只认 `Node` 及其子类 | 架构 | 同上 · `无关类声明 path 不查` |
| `TC-INF-038` | — | — | `AppendOnlyStoreFs` 接口体除 `appendLine` 外多一个 `writeStringAtomic` | 跑 `R10` | 报违规，且**行号指向新增那一行** | 架构 | 同上 · `往 AppendOnlyStoreFs 加 writeStringAtomic 被拦，并报出行号` |
| `TC-INF-039` | — | — | `EventStore` 接口体多一个 `purge()` | 跑 `R10` + `R3` | `R10` 报违规、`R3` **不报** —— 黑名单抓不到这个名字 | 架构 | 同上 · `往 EventStore 加 purge 被拦` |
| `TC-INF-040` | — | — | 现有形态：`AppendOnlyStoreFs` 只有 `appendLine` | 跑 `R10` | **不报**（防误报基线） | 架构 | 同上 · `现有接口原样放行` |
| `TC-INF-041` | — | — | `DartIoPackFs` 同时 `implements` 三个接口、带 `writeStringAtomic` | 跑 `R10` | **不报** —— 只查接口声明体，实现类的写方法合法 | 架构 | 同上 · `同时实现三个接口的实现类带写方法不报` |
| `TC-INF-042` | — | — | 接口体里有一个私有方法 `_compact()` | 跑 `R10` | **不报** —— 不在调用面上 | 架构 | 同上 · `接口体里的私有方法放行` |

### 3.7 `LOAD` 域（46 条 · 包加载与定位，`B2` 第 2 笔）

> 本节全部落在 `app/lib/core/pack/` 与 `app/lib/core/locate/`。三类里最值得看的是 **①枚举取值与包数据同源**：此前 `ItemType` / `Layer` / `RequirementState` / `EdgeType` 四个枚举与真包取值差一个词（`statement` vs `declarative`、`quick` vs `ephemeral`、`complete` vs `present`、`unknownTarget` vs `unknown`），而既有测试全用内联 JSON、与真包同错 —— **所以一直是绿的**。α 包一进来当场抛错。

#### 3.7.1 枚举取值与包数据同源（3 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-LOAD-001` | `PACK-009` | **显式** | `RequirementState` 四个候选：`present` / `missing` / `not_externalizable` / `notExternalizable` | 逐个 `fromWire` | 前三个正常解析；驼峰那个抛 `FormatException` —— 包只认蛇形 | 单元 | `app/test/core/entities_test.dart` · `三态用蛇形 not_externalizable` |
| `TC-LOAD-002` | — | — | `ItemType` / `Layer` 的取值 | `fromWire('declarative')` / `('procedural')` / `('ephemeral')`；再试 `'statement'` / `'quick'` | 前三个通过；后两个抛错 —— 旧枚举名不得再被接受 | 单元 | 同上 · `项的 type 与 layer 取数据里的值` |
| `TC-LOAD-003` | — | — | 一条 `type: "unknown"` 的边 | `Edge.fromJson` 再 `toJson` | 解析为 `EdgeType.unknown`，回写仍是 `unknown` | 单元 | 同上 · `边类型 unknown 能解析` |

#### 3.7.2 路径探测（8 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-LOAD-004` | `PACK-018` | 语义 | 两个包目录，各有 `pack.json` | `PackProbe.scanRoot('content', PackKind.payload)` | 两个位置，按目录名排序，无问题，`kind` 均为 `payload` | 单元 | `app/test/core/pack/pack_probe_test.dart` · `目录下有 pack.json 才算一个包` |
| `TC-LOAD-005` | `PACK-018` | 语义 | 旧形态目录：有 `manifest.json` + `dist/pack.json`，没有 `pack.json` | 同上 | 不产出位置，报 `missingPack` 并指名 `pack.json` 路径 | 单元 | 同上 · `目录里没有 pack.json ⇒ 报 missingPack` |
| ~~`TC-LOAD-006`~~ | `PACK-018` | 语义 | ~~只有清单，缺产物（= 忘了跑 `build.py`）~~ | — | **已作废**（`B14` 笔 1）：单文件形态下没有「清单在、产物不在」的形状，与 `TC-LOAD-005` 合并 | — | — |
| `TC-LOAD-007` | `PACK-018` | 语义 | 文件在但读不出（模拟权限 / 非 UTF-8） | 同上 | 报 `unreadable`，**不与「缺文件」混为一谈** | 单元 | 同上 · `文件在但读不出来报 unreadable` |
| `TC-LOAD-008` | `PACK-018` | 语义 | 三类候选根（`payload` 一组）：第一个不存在，后两个各有同名目录 | `scanRoots({payload: [...]})` | 同名目录只取**先出现**的那个；各自独有的目录都保留 | 单元 | 同上 · `同一个 kind 内，候选根依次探测` |
| `TC-LOAD-009` | — | — | 根目录不存在 | 同上 | 空结果、**零问题** —— 空根不是错误，缺文件才是 | 单元 | 同上 · `根目录不存在` |
| `TC-LOAD-041` | — | — | 一个包分别落在 `payload` 与 `method` 两组候选根下 | `scanRoots({payload:[…], method:[…]})` | 两条位置，`kind` 各自正确，`packRoot` 各指各的 | 单元 | 同上 · `同一包在两类候选根各探到一次` |
| `TC-LOAD-042` | — | — | 同一个根列给两个 `kind` | 同上 | 两条位置，`packRoot` 相同、`kind` 各一 —— `kind` 是查询维度，不是存储位置 | 单元 | 同上 · `同一个根列给两个 kind` |

#### 3.7.3 包解析（13 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-LOAD-010` | `PACK-005` | 语义 | 最小包：六段（`pack.json` 单文件，无清单） | `readPack` | 解析成功，`nodeOf` / `scheme.nodes` 可用 | 单元 | `app/test/core/pack/pack_reader_test.dart` · `M2 六段齐全即可解析（SPEC-PACK-005）` |
| ~~`TC-LOAD-011`~~ | `PACK-005` | **显式** | ~~`meta.space` 与清单 `id` 不同~~ | — | **已作废**（`B13a` 笔 5c）：`ADR-0007` 取消 `meta` 段，包身份改由 `Pack.pluginId` 自带，「包与清单不是同一空间」这类错不再有表达形式 | 单元 | — |
| ~~`TC-LOAD-012`~~ | `PACK-005` | **显式** | ~~`meta.version` 与清单 `version` 不同~~ | — | **已作废**（`B13a` 笔 5c）：`meta.version` 并入 `PackVersions`，版本一致性改由该复合值承载 | 单元 | — |
| `TC-LOAD-013` | `PACK-007` | **显式** | 包多出 `notes` 段 | 同上 | 抛错 —— 笔记模板不进包 | 单元 | 同上 · `顶层出现六段与清单字段之外的键即拒（SPEC-PACK-007）` |
| `TC-LOAD-014` | `PACK-005` | 语义 | 删掉 `edges` 段 | 同上 | 抛错，**不补空数组**（补默认值会把坏包读成空包） | 单元 | 同上 · `六段缺一即格式错误（SPEC-PACK-005）` |
| `TC-LOAD-015` | `PACK-008` | 语义 | 两个 `nodes` 用同一 `id` | 同上 | 抛错并指名重复的 id | 单元 | 同上 · `段内 id 唯一：nodes 重复即拒（SPEC-PACK-008）` |
| `TC-LOAD-016` | `FND-005` | 语义 | `a→b`、`b→a` 两条 `required` 边 | 同上 | 抛错，报错正文里带出环路径 | 单元 | 同上 · `先修边成环即拒（SPEC-FND-005）` |
| `TC-LOAD-017` | — | — | 同时存在三处错（缺段 / 多段 / 非法槽位） | 同上 | 一次抛出的 `problems` 至少 3 条 —— 不遇到第一个就停 | 单元 | **待补**（笔 5c 重写夹具时未带上，落点 `—`） |
| `TC-LOAD-018` | — | — | 清单是 `{`（坏 JSON） | 同上 | 抛 `PackFormatException`，文案指名哪个文件 | 单元 | **待补**（笔 5c 重写夹具时未带上，落点 `—`） |
| `TC-LOAD-043` | — | — | `overlay` 包：`kinds: ["overlay"]`，六段全为空数组 | `readPack` | 装载成功；`kinds` 只有 `overlay`、`overlay.targetScope` 落 `S4`、`patchCount` 为 0；六段为空不报错 —— `kind` 不决定段是否非空 | 单元 | `app/test/core/pack/pack_reader_test.dart` · `overlay 包六段齐全即可装载，六段内容可以为空（无 SPEC：kind 不决定段是否非空）` |
| `TC-LOAD-044` | — | — | `terrain` 包：`kinds: ["terrain"]`，`nodes` 为空、3 条先修边指向别的包的节点 | 同上 | 装载成功；`terrain.edgeCounts` 与 `edges[]` 实扫相符 —— 「不带节点只带边」是地形的正常形态 | 单元 | 同上 · `terrain 包只带边不带节点，摘要与实扫相符（无 SPEC：terrain 只贡献地形）` |
| `TC-LOAD-045` | — | — | `overlay` 包删掉 `overlay` 特化字段 | 同上 | 抛错并指名包与 `overlay` —— 声明了 `kind` 却没给 facts，装前会显示一片空白 | 单元 | 同上 · `声明了 kind 却没给特化字段即拒（无 SPEC：entity-fields §1）` |
| `TC-LOAD-046` | — | — | `terrain` 包把 `kinds` 改成空数组，`terrain` 字段保留 | 同上 | 抛错并指名包与 `terrain` —— 带了 facts 不声明 `kind`，那份数据不会被任何一方读取 | 单元 | 同上 · `带了特化字段却没声明 kind 即拒 —— 那份数据不会被任何一方读取（无 SPEC：同上）` |

#### 3.7.4 `⪯` 环检测（6 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-LOAD-019` | `FND-005` | 语义 | 链 `a→b→c` | `findCycles` | 空 | 单元 | `app/test/core/pack/cycle_check_test.dart` · `无环图返回空` |
| `TC-LOAD-020` | `FND-005` | 语义 | 菱形：`a→b`、`a→c`、`b→d`、`c→d` | 同上 | 空 —— 共享后继不是环，不能误报 | 单元 | 同上 · `菱形不是环` |
| `TC-LOAD-021` | `FND-005` | 语义 | 自环 `a→a` | 同上 | 跳过 —— 那是数据错误，构建期各码报出 | 单元 | 同上 · `自环跳过` |
| `TC-LOAD-022` | `FND-005` | 语义 | `a→b`、`b→a` | 同上 | `[[a, b, a]]` 一条，首尾闭合 | 单元 | 同上 · `二元环报一条` |
| `TC-LOAD-023` | `FND-005` | 语义 | `a→c`、`c→b`、`b→c`（环从非最小节点进入） | 同上 | `[[b, c, b]]` —— 起点归一为最小 id，同一环不重复报 | 单元 | 同上 · `环的起点归一为最小 id` |
| `TC-LOAD-024` | `FND-005` | 语义 | 两个互不相连的环 | 同上 | 两条，各自独立 | 单元 | 同上 · `两个互不相连的环各报一条` |

#### 3.7.5 定位引擎（12 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-LOAD-025` | `FND-008` | **显式** | 输入 `装饰器`（与 `装饰器参数` 同域） | `Locator.locate` | `located`，落点 `python/fn-decorator` | 单元 | `app/test/core/locate/locator_test.dart` · `完整标题 ⇒ 有定位` |
| `TC-LOAD-026` | `FND-008` | 语义 | 输入 `饰器`（只子串命中两条） | 同上 | `partial`，两条命中，强度均为 `fuzzy` | 单元 | 同上 · `只有子串命中 ⇒ 部分命中` |
| `TC-LOAD-027` | `FND-008` | 语义 | 输入 `zzz` | 同上 | `none`，命中集为空，`top` 为 `null` | 单元 | 同上 · `全不中 ⇒ 无定位` |
| `TC-LOAD-028` | `FND-008` | 语义 | 输入完整域 id `python/lexical` | 同上 | `partial`，档位 `domain` —— 命中上层归部分命中 | 单元 | 同上 · `命中域 ⇒ 部分命中` |
| `TC-LOAD-029` | `FND-008` | 语义 | 输入空间全名 `Python 语法分层` | 同上 | `partial`，档位 `space` | 单元 | 同上 · `命中空间名 ⇒ 部分命中` |
| `TC-LOAD-030` | `VIEW-028` | **显式** | 输入轴取值 `控制流` | 同上 | `partial`，档位 `axis`，带 `axisKey = ability` —— 筛选类不换根 | 单元 | 同上 · `命中轴取值 ⇒ 部分命中` |
| `TC-LOAD-031` | `VIEW-027` | 语义 | 输入 `装饰器`（精确 1 条 + 子串 1 条） | 同上看 `hits` 顺序与三态 | 精确在前、子串在后；三态仍是 `located`（**最强档唯一即唯一命中**） | 单元 | 同上 · `精确命中优先于子串命中` |
| `TC-LOAD-032` | `VIEW-029` | 语义 | 输入 `python/`（域名与节点 id 同为前缀命中） | 同上 | 所有 `domain` 排在所有 `item` 之前 | 单元 | 同上 · `强度相同看档位` |
| `TC-LOAD-033` | `VIEW-029` | 语义 | 输入 `  IF 语句 `（大小写 + 首尾空白） | 同上 | `located`，落点 `python/ctl-if` | 单元 | 同上 · `大小写与首尾空白不影响命中` |
| `TC-LOAD-034` | — | — | 输入为三个空格 | 同上 | `none`、零命中 —— 空输入不构成搜索 | 单元 | 同上 · `空输入不产生命中` |
| `TC-LOAD-035` | `VIEW-025` | **显式** | 输入轴键名 `ability`；再输入节点 id `python/lex-keyword` | 同上 | 前者 `none`（只匹配取值不匹配键名），后者 `located` | 单元 | 同上 · `匹配面只到 C-27 的五个字段` |
| `TC-LOAD-036` | `C-27` | 语义 | 常量 `searchMatchFields` | 与引擎实际覆盖的五个匹配面比对 | 完全一致 —— 常量与实现不得分叉 | 单元 | 同上 · `匹配字段常量与实现覆盖面对齐` |

#### 3.7.6 真实 α 包（4 条）

> ⚠️ **这四条已于 `B13a` 笔 5c 全部作废**（保留编号，不删行）：原读 `../content/python/dist/pack.json`（真实 α 包产物），而 α 包夹具随 `pack_parse.dart` 一并删除。⇒ **真实内容包的端到端校验当前无自动化**，各行的「欠账」即为缺口登记；别再按「缺失时明确失败而非跳过」去找这几条用例，它们已不在跑。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-LOAD-037`~~ | `PACK-005` | 语义 | ~~α 包产物~~ | — | **已作废**（`B13a` 笔 5c）：α 包夹具 `test/support/alpha_pack.dart` 随 `pack_parse.dart` 一并删除。**欠账**：真实内容包（`content/python`）的端到端四数校验（项 / 边 / 域 / id 索引）当前无自动化，待补 | 单元 | — |
| ~~`TC-LOAD-038`~~ | `FND-005` | 语义 | ~~同上~~ | — | **已作废**（`B13a` 笔 5c）：同上，夹具删除；`⪯` 环检测本身由 `cycle_check_test.dart` 的 3 条覆盖，缺的只是「真实包产物这一份」 | 单元 | — |
| ~~`TC-LOAD-039`~~ | `FND-008` | **显式** | ~~150 项，逐项用自己的标题查询~~ | — | **已作废**（`B13a` 笔 5c）：同上。**欠账**：真实包 150 项自定位 0 例外这一条随之失去自动化 | 单元 | — |
| ~~`TC-LOAD-040`~~ | — | — | ~~44 道声明式题~~ | — | **已作废**（`B13a` 笔 5c）：同上。**欠账**：题库悬空引用校验当前无自动化 | 单元 | — |

### 3.8 `EVT` 域（48 条 · 事件内核：发号与折叠，`B2` 第 3 笔）

> 全部落在 `app/lib/core/events/`（`hlc_clock.dart` · `fold.dart` · `migration.dart`）。本笔最值得看的两处：**① 幂等 ≠ 去重**（同一 `id` 重传只算一次，两台设备各学一遍**都算** —— 你确实复习了两次）；**② 时钟回拨必须 clamp**（照抄 `now` 会让新事件排到旧事件之前，而 `D` / `S` 的折叠不可交换，一旦定序错了，错的是记忆强度本身）。

#### 3.8.1 本地发号（13 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-EVT-001` | `FND-011` | **显式** | 新时钟，`now = 1000` | `next()` | `physical = 1000` · `counter = 0` · `deviceId` 为本地 | 单元 | `hlc_clock_test.dart` · `首条` |
| `TC-EVT-002` | `FND-011` | **显式** | 同一毫秒连发三次 | 逐次 `next()` | `physical` 不变，`counter` 逐次 +1，三次严格递增 | 单元 | 同上 · `同一毫秒连发` |
| `TC-EVT-003` | `FND-011` | 语义 | 先发 1000 两次，再发 1001 | `next()` | 新的 `counter` 归零 | 单元 | 同上 · `物理时间前进` |
| `TC-EVT-004` | `FND-011` | **显式** | 发到 2000 后把时钟调回 5 | `next()` | `physical` 仍 2000、`counter` +1 —— 新事件仍排在旧事件之后 | 单元 | 同上 · `时钟回拨` |
| `TC-EVT-005` | `FND-011` | 语义 | 连发 1000 条（一半前进一半持平） | 收集全部 HLC | 无重复，且按发放顺序严格递增 | 单元 | 同上 · `连发 1000 条` |
| `TC-EVT-006` | `FND-011` | 语义 | `seed` 传入 `dev-remote` 的 HLC | `next()` | 沿用其 `physical` / `counter`，**`deviceId` 仍是本地** | 单元 | 同上 · `deviceId 恒为本地` |
| `TC-EVT-007` | `FND-011` | 语义 | 本地 1000，观测远端 2000 / counter 4 | `observe()` | 跳到 2000、`counter = 5`、`deviceId` 本地 | 单元 | 同上 · `远端更晚` |
| `TC-EVT-008` | `FND-011` | **显式** | 本地 2000，观测远端 1000 / counter 99 | `observe()` | `physical` 不倒退，`counter` 只 +1 | 单元 | 同上 · `远端更早` |
| `TC-EVT-009` | `FND-011` | 语义 | 同 `physical`，远端 counter 更大 | `observe()` | `counter = max(本地, 远端) + 1` | 单元 | 同上 · `同 physical 远端 counter 更大` |
| `TC-EVT-010` | `FND-011` | 语义 | 同 `physical`，远端 counter 更小 | `observe()` | 仍取本地 +1（不能被旧事件拽住） | 单元 | 同上 · `同 physical 远端 counter 更小` |
| `TC-EVT-011` | `FND-011` | 语义 | 构造时 `seed` 高水位 | `next(now < seed)` | 接着 seed 往下走，不回退 | 单元 | 同上 · `构造时 seed` |
| `TC-EVT-012` | `FND-011` | 语义 | 本地已到 5000，`reseed` 传 100 | `reseed()` | 空操作 | 单元 | 同上 · `reseed 更低水位空操作` |
| `TC-EVT-013` | `FND-011` | 语义 | 本地为 0，`reseed` 传 7000/2 | `reseed()` 后 `next(6000)` | 停在 7000，`counter = 3` | 单元 | 同上 · `reseed 只在前进时生效` |

#### 3.8.2 折叠 · 游标与判定（10 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-EVT-014` | `FND-010` | **显式** | 零事件 | `fold([])` | 游标 0 · 已学空 · 笔记空 · 账本空 | 单元 | `fold_test.dart` · `空事件流` |
| `TC-EVT-015` | `FND-011` | 语义 | 三条事件，正序与逆序各折一次 | `fold()` | 两次结果逐字段一致 —— 定序只看 `hlc`，不看入参顺序 | 单元 | 同上 · `乱序输入按 hlc 重放` |
| `TC-EVT-016` | `FND-011` | 语义 | 同 `physical`、counter 0 / 1 两条成绩 | `fold()` | 取 counter 大的那条 | 单元 | 同上 · `同 physical 不同 counter` |
| `TC-EVT-017` | — | — | 完成 stepIndex 0、1 | `fold()` | `cursorOf = 2`（`max + 1`） | 单元 | 同上 · `游标 = max + 1` |
| `TC-EVT-018` | — | — | 完成 0/1/2 后再写一条 stepIndex 0 | `fold()` | 游标仍 3 —— 回看不倒推 | 单元 | 同上 · `step_completed 不撤销` |
| `TC-EVT-019` | — | — | 两项各自完成不同步数 | `fold()` | 按项独立计数，未学项为 0 | 单元 | 同上 · `按项独立计数` |
| `TC-EVT-020` | — | — | `item_passed` 之后又 `item_graded(fail)` | `fold()` | `isPassed` 仍真；`lastGrade` 为 `fail` —— 进度分母不动 | 单元 | 同上 · `item_passed 不可撤销` |
| `TC-EVT-021` | `C-11` | 语义 | `item_graded(pass)` 之后 `item_skipped` | `fold()` | 成绩仍是 `pass`，未标记已学，游标 0 | 单元 | 同上 · `item_skipped 不写判定` |
| `TC-EVT-022` | — | — | `graduated` 之后 `item_graded(fail)` | `fold()` | `isGraduated` 仍真 | 单元 | 同上 · `graduated 不可逆` |
| `TC-EVT-023` | `FND-010` | 语义 | 三档成绩依次写入 | `fold()` | 取时间序最后一条 | 单元 | 同上 · `item_graded 取最后一条` |

#### 3.8.3 折叠 · 幂等 / 空间 / 快照 / 孤儿项（6 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-EVT-024` | — | — | 同一条 `note_revised`（同 `id`）放入两次 | `fold()` | 该节版本 1 —— 重传幂等 | 单元 | `fold_test.dart` · `同一条事件重传两次只算一次` |
| `TC-EVT-025` | — | — | 两台设备各写同一节（不同 `id`） | `fold()` | 版本 2，正文取后一条 —— **不去重** | 单元 | 同上 · `两台设备各学一遍都算` |
| `TC-EVT-026` | `FND-010` | 语义 | 两个空间的同形事件 | `fold(spaceId: 'python')` | 只折该空间；它空间项游标 0 | 单元 | 同上 · `spaceId 过滤` |
| `TC-EVT-027` | `FND-010` | **显式** | `pass@1000`、`fail@1005` | `fold(asOf: 1000)` / `asOf: 1005` | 前者 `pass`，后者 `fail` —— `asOf` 含端点 | 单元 | 同上 · `asOf 截断` |
| `TC-EVT-028` | `FND-012` | **显式** | 学过并合格后 `item_retired` | `fold()` | `isRetired` 真，**游标与已学都还在** | 单元 | 同上 · `item_retired 之后进度仍在` |
| `TC-EVT-029` | `FND-012` | 语义 | `item_retired` 的信封 `itemId` 为空，payload 里有 | `fold()` | 从 payload 读到并标下线 | 单元 | 同上 · `信封 itemId 缺失从 payload 读` |

#### 3.8.4 折叠 · 笔记（5 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-EVT-030` | — | — | 同节连写三次 | `fold()` | 版本 3，正文为最后一条 | 单元 | `fold_test.dart` · `版本 = 该节事件计数` |
| `TC-EVT-031` | — | — | 写 a、b，再回滚 `targetVersion: 1` | `fold()` | 正文回到 `a`，**版本仍 3** —— 历史只增 | 单元 | 同上 · `回滚追加事件` |
| `TC-EVT-032` | `FND-014` | **显式** | 首版后回滚 `targetVersion: 5` | `fold()` | 抛 `FormatException` —— 不静默回落 | 单元 | 同上 · `回滚目标版本不存在即报错` |
| `TC-EVT-033` | `FND-014` | 语义 | 只写过 `boundary` | 查 `how` / 查别的项 | 均返回 `null`，不返回空对象 | 单元 | 同上 · `没写过的节返回 null` |
| `TC-EVT-034` | — | — | 项内笔记与空间级笔记（`itemId` 为空）各一条 | `fold()` | 两节独立计数，互不覆盖 | 单元 | 同上 · `空间级自由笔记分开计` |

#### 3.8.5 折叠 · 迁移账本（2 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-EVT-035` | `C-12` | 语义 | 一条 `state_carried` + 一条 `state_merged` | `fold()` | 账本各一条，字段与 payload 一致，顺序同事件序 | 单元 | `fold_test.dart` · `拆分与合并都进账本` |
| `TC-EVT-036` | `C-12` | 语义 | `state_carried` 不带 `ratio`，分成三份 | `fold()` | `ratio` 补为 `1/3` —— 与常量口径同源 | 单元 | 同上 · `拆分缺 ratio 字段时按 1/n 补` |

#### 3.8.6 坏事件（3 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-EVT-037` | `FND-014` | **显式** | `step_completed` 无 `stepIndex` | `fold()` | 抛 `FormatException`，不补 0 | 单元 | `fold_test.dart` · `缺 stepIndex 即抛错` |
| `TC-EVT-038` | `FND-014` | 语义 | `item_passed` 无 `itemId` | `fold()` | 抛 `FormatException` | 单元 | 同上 · `缺 itemId 即抛错` |
| `TC-EVT-039` | `FND-014` | 语义 | `score: "great"` | `fold()` | 抛 `FormatException`，文案列出允许值 | 单元 | 同上 · `未知 score 取值即抛错` |

#### 3.8.7 折算函数（9 条 · `carryStability`）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-EVT-040` | `C-12` | 语义 | 无账本 | `carryStability()` | 原样返回 | 单元 | `migration_test.dart` · `空账本原样返回` |
| `TC-EVT-041` | `C-12` | **显式** | `S(a) = 9`，`a` 拆成三份 | `carryStability()` | 三个子项各 3 | 单元 | 同上 · `子项各拿 1/n` |
| `TC-EVT-042` | `FND-012` | 语义 | 同上 | 看 `a` 自己的值 | 仍是 9 —— 源项不删 | 单元 | 同上 · `拆分不删源项` |
| `TC-EVT-043` | `C-13` | **显式** | `S(b)=4` / `S(c)=11` / `S(d)=7`，合并为一项 | `carryStability()` | 合并项 11 —— 取最大，不是求和 | 单元 | 同上 · `合并取最大` |
| `TC-EVT-044` | `C-12` | 语义 | `a → {b,c}`，`b → {d,e}` | `carryStability()` | `d` / `e` 各 2（比例连乘） | 单元 | 同上 · `二次拆分` |
| `TC-EVT-045` | `C-12` | 语义 | 同一账本正序 / 逆序各算一次 | `carryStability()` | 结果一致 —— 折算与账本顺序无关 | 单元 | 同上 · `账本顺序颠倒` |
| `TC-EVT-046` | `C-12` | **显式** | 把上一次结果当输入再算一次 | `carryStability()` | 与一次结果相同（幂等） | 单元 | 同上 · `重放同一账本` |
| `TC-EVT-047` | `FND-014` | 语义 | 源项没有任何 `S` | `carryStability()` | 不产生目标项，**不造 0 值** | 单元 | 同上 · `源项没有 S 时不造 0 值` |
| `TC-EVT-048` | `C-12` | 语义 | 目标项已有更大的实测 `S` | `carryStability()` | 保留实测值，不被折算值覆盖 | 单元 | 同上 · `目标项已有更大实测值` |

### 3.9 `VIEW` 域（续）· 构图与投影（17 条 · `B2` 第 4 笔）

> §3.5 已用 `TC-VIEW-001`（界面阈值常量），故本节从 `002` 续号。两组用例的层次不同：§3.5 测**常量取值**，本节测**由常量算出的几何**。

#### 3.9.1 构图 · `φ` 层号（9 条 · `kahnLevels`）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-002` | `VIEW-002` | **显式** | 链 `a→b→c` | `kahnLevels` | `a`/`b`/`c` 分别为 `0`/`1`/`2` | 单元 | `app/test/core/graph/levels_test.dart` · `链：a→b→c 得 0 / 1 / 2` |
| `TC-VIEW-003` | `VIEW-002` | **显式** | 菱形 `a→b` `a→c` `b→d` `c→d` | 同上 | `d == 2` —— 汇合点取两侧**较深**的一层 | 单元 | 同上 · `菱形：汇合点取两侧较深的一层` |
| `TC-VIEW-004` | `VIEW-002` | **显式** | `a→b→c` 与 `a→c` 并存 | 同上 | `c == 2` —— **最长**前置链，不能因有直达边就算 1 | 单元 | 同上 · `取最长前置链，不取最短` |
| `TC-VIEW-005` | `VIEW-002` | **显式** | `a→b` + 孤立点 `lonely` | 同上 | `lonely == 0`，与入度为 0 的节点同层 | 单元 | 同上 · `孤立节点为 0 层` |
| `TC-VIEW-006` | `VIEW-002` | **显式** | 空边集 | 同上 | 全部 `0` 层（不抛错） | 单元 | 同上 · `空边集：全部 0 层` |
| `TC-VIEW-007` | — | — | 边指向 `ghost` / 来自 `ghost`（均不在 `nodeIds`） | 同上 | 该边被忽略，`a`/`b` 均 `0`，不抛错 —— 存在性校验归构建期，客户端不再写第二份判据 | 单元 | 同上 · `端点不在册的边被忽略` |
| `TC-VIEW-008` | `VIEW-002` | **显式** | 四节点同一组边，正序与逆序各算一次 | 同上 | 两张层号表**完全相等**（取 `max` 与入队顺序无关） | 单元 | 同上 · `边顺序不影响结果` |
| `TC-VIEW-009` | `FND-005` | **显式** | `a→b` + `b→a` | 同上 | 抛 `FormatException`，**不返回半份结果** | 单元 | 同上 · `有环即抛错并列出卡住的节点` |
| `TC-VIEW-010` | `VIEW-002` | **显式** | α 真实包：150 项 / 167 边 | 同上 | 150 项**全部有层号**；`max == 63`、0 层 == `3` 项 | 单元 | 同上 · `真实 α 包：150 项全部有层号，最深 63 层` |

> `TC-VIEW-010` 的两个数是**内容侧事实**，不是调出来的参数：α 包的 `⪯` 近乎一条长链。它们决定宇宙视图把 `φ` 直接当高度时会不会把节点推出画面 —— `B3` 必须据此选归一化或截断。

#### 3.9.2 投影 · 三坐标 → 2D（8 条 · `projectFrame`）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-011`~~ | `VIEW-002` | **显式** | 三节点 `radial01` = `0` / `0.1` / `0.9`；`yaw`/`pitch` 置零、`sector=0` | `projectFrame` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：前两者 `x` **相等**（同段同半径）；`0.9` 的 `x` 更大（`r` 是 7 段径向分层） | 单元 | — |
| `TC-VIEW-012` | `VIEW-002` | **显式** | `phiLevel` = `0` 与 `3`，其余相同 | 同上 | 深者的 `y` 更大 —— 「越深越靠外」 | 单元 | 同上 · `φ 越深越靠外` |
| `TC-VIEW-013` | `VIEW-002` | **显式** | `sector` = `0` 与 `3`，其余相同 | 同上 | `x` 一正一负（落在相反两侧） | 单元 | 同上 · `θ 扇区：sector 0 与 sector 3 落在相反两侧` |
| `TC-VIEW-014` | — | — | `distance = 0.1`、`minDepth = 0.05`，节点贴到相机平面 | 同上 | `depth == 0.05`（被钳）；`x`/`y` **均有限** —— 不钳制会算出 `Infinity`，而 painter 拿到 `Infinity` 的表现是**整帧消失**，不报错 | 单元 | 同上 · `贴到相机平面的节点被钳到 minDepth` |
| `TC-VIEW-015` | — | — | 三节点不同 `radial01`；`yaw = 0.3`（保证深度有差异） | 同上 | `drawOrder` 长度 = `nodes` 长度；逐对 `depth` **单调不增**（远→近）；`nodes` 顺序**保持入参顺序** | 单元 | 同上 · `深度排序：drawOrder 远 → 近，且不重排 nodes` |
| `TC-VIEW-016` | — | — | 20 节点 + 1 条边，同输入连投两次 | 同上 | `drawOrder` 与每节点 `x`/`y`/`depth` **逐字段相等** | 单元 | 同上 · `确定性：同一输入连投两次，逐字段一致` |
| `TC-VIEW-017` | `VIEW-002` | **显式** | α 真实包 150 项 | 同上 | 投影出 150 节点、`drawOrder` 150 项；`x`/`y`/`depth` 全有限且 `depth ≥ minDepth` | 单元 | 同上 · `真实 α 包：150 节点全投影，坐标全部有限` |
| `TC-VIEW-018` | `VIEW-002` | **显式** | α 真实包 170 条边（其中 3 条 `type=unknown`，目标 id 不在册） | 同上 | 产出 **167** 条 `EdgeSpan`；每条两端下标均在 `[0, 149]` | 单元 | 同上 · `真实 α 包：170 条边里有 3 条「指向未知」，投影时被跳过` |

> `TC-VIEW-015` 的「不重排 `nodes`」不是顺手断言：边用**下标**引用两端，重排会让每条边接到别的节点上，而画面看起来仍然「有连线」—— 错得没有声音。
>
> `TC-VIEW-018` 顺带暴露一个真问题：3 条「指向未知」的边在投影层只能跳过，**视觉上没有任何表达**。`channel-table.md` 通道 6 只说「虚线 = 弱依赖 / 指向未知」，两者混为一谈。`B3` 必须裁定怎么画，本笔不擅自补。

### 3.10 `VIEW` 域（续二）· 绘制计数与帧时序（20 条 · `B2` 第 5 笔）

> 本节守的是「一帧发了多少次绘制调用、帧时序怎么算」，**不是帧率达标**。帧率只能在真机上量（`C-32` 的判据归终端 `flutter run --profile`），headless 环境产不出 `FrameTiming` —— 在测试里断言 fps 等于自制一台跑不起来的机器。

#### 3.10.1 绘制指令计数（6 条 · `paintFrame`）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-019`~~ | — | `ADR-0002` | 合成场景 ×1（150 项 / 167 边），视口 800×600 | `paintFrame` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`dots == 150`；`strokes ≥ 167`；`dashedSegments > dashedEdges`；`total == dots + strokes` | 单元 | — |
| `TC-VIEW-020` | `VIEW-002` | **显式** | 两节点 + 一条实线边 | 同上 | `strokes == 1`；`dashedEdges == 0` | 单元 | 同上 · `实线边只发一次 stroke（SPEC-VIEW-002）` |
| `TC-VIEW-021` | — | — | 两节点相距 100 px + 一条虚线边，`pixelsPerUnit = 1` | 同上 | `dashedSegments == 12`（100 ÷ 9 向上取整）；`strokes == 12` | 单元 | 同上 · `虚线边按 9 px 周期拆段：100 px ⇒ 12 段（无 SPEC：虚线段长为设计 token）` |
| `TC-VIEW-022` | — | — | 两节点投影后完全重合 + 一条虚线边 | 同上 | `skippedEdges == 1`、`strokes == 0`、`dots == 2` —— 退化输入不产生零长线段 | 单元 | 同上 · `两端重合的虚线边被跳过，不计段（无 SPEC：退化输入的保护）` |
| `TC-VIEW-023` | — | `ADR-0002` | 原点到视口外（-5000, -5000） | 同上 | `dots == 2` 且 `offscreenDots == 2` —— **照发调用**，朴素实现不逐个判屏 | 单元 | 同上 · `画到视口外的节点仍发绘制调用，并被计入 offscreenDots（ADR-0002）` |
| `TC-VIEW-024` | — | — | 两节点 + 一条实线边 | 同上 | 目标收到的首个指令是 `stroke`、末个是 `dot` —— 点压在线上 | 单元 | 同上 · `先边后点：点压在线上（无 SPEC：绘制次序属实现选择）` |

> `TC-VIEW-019` 是本节的地基：这一笔所有结论都建立在「一帧 300 多次调用」这个数上。若它只能靠读代码数，那就是意见；被断言住才是事实。已做反向验证 —— 把节点循环改成隔一个跳过，本组 3 条立即变红（150→75）。

#### 3.10.2 帧时序统计（6 条 · `FrameRateMonitor`）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-025`~~ | — | `C-32` | 0 帧 / 2 帧 | `snapshot()` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：返回 `null` —— 不足 20 个间隔不出快照，不拿两帧编一个 fps | 单元 | — |
| `TC-VIEW-026` | — | `C-32` | 25 帧，间隔 16 667 µs；build 1 ms / raster 4 ms | 同上 | `fps ≈ 60`、`frameP50Ms ≈ 16.667`、`rasterP95Ms ≈ 4`、`meetsGood == true` | 单元 | 同上 · `16.667 ms 稳定间隔 ⇒ 60 fps，UI 1 ms / 光栅 4 ms（C-32）` |
| `TC-VIEW-027` | — | `C-32` | 24 个间隔里 5 个为 50 ms | 同上 | `fps ≈ 60`（中位不受影响）**且** `frameP95Ms ≈ 50` —— 两个指标缺一不可 | 单元 | 同上 · `掉帧拉高 p95 但不改变中位 fps —— 两个指标缺一不可（C-32）` |
| `TC-VIEW-028` | — | `C-32` | 25 帧，间隔 40 000 µs | 同上 | `fps ≈ 25`、`meetsTarget == false` —— 低于 30 fps 判不过 | 单元 | 同上 · `低于 30 fps 判不过（C-32）` |
| `TC-VIEW-029` | — | `C-32` | 先加 25 帧再 `reset()` | 同上 | `reset()` 后 `snapshot()` 为 `null` —— 切档必须清窗口 | 单元 | 同上 · `reset 后回到无样本状态（C-32）` |
| `TC-VIEW-030` | — | — | `capacity = 30`，连加 200 帧 | 同上 | `samples == 30` —— 滚动窗口有上界 | 单元 | 同上 · `滚动窗口只保留最近 capacity 个间隔（无 SPEC：内存上界属实现约束）` |

> `TC-VIEW-027` 锁的是一个**判据设计**，不是算法细节：只报平均 fps 会把「一直 45 fps」和「60 fps 但每 5 帧掉一次」判成同一件事，而后者手感明显更差。所以中位承载稳态、p95 承载卡顿，两条都要有。

#### 3.10.3 场景装配（6 条 · `scene_source`）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-031`~~ | — | `ADR-0002` | — | `buildSyntheticScene()` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`itemCount == 150`、`edgeCount == 167` —— 合成口径 = α 包有效边数 | 单元 | — |
| `TC-VIEW-032` | — | `ADR-0002` | — | `buildSyntheticScene(copies: 2)` | 300 项 / 334 边；**id 去重后仍 300** —— 第二份必须改 id，否则边索引重映射后指错点 | 单元 | 同上 · `×2 = 300 项 / 334 边，且 id 不重复（ADR-0002）` |
| `TC-VIEW-033` | — | `ADR-0002` | — | 遍历合成节点 | `φ ∈ [0, 63]`；`maxPhi == 63`；0 层恰好 3 项 —— 与 `TC-VIEW-010` 的真实包口径一致 | 单元 | 同上 · `层号 0…63，0 层恰好 3 项（ADR-0002）` |
| `TC-VIEW-034` | — | `ADR-0002` | ×2 合成场景 | 遍历全部边 | 两端下标 ∈ `[0, 299]`；`fromIndex != toIndex`（自环会退化成零长线段） | 单元 | 同上 · `边索引全部落在节点范围内（ADR-0002）` |
| `TC-VIEW-035` | — | — | 连续装配两次 | 逐节点比对 | `phiLevel` / `radial01` / `brightness01` 完全相等 —— 读数可复现是测量前提 | 单元 | 同上 · `同一输入两次装配完全一致（无 SPEC：可复现读数属测量前提）` |
| `TC-VIEW-036` | `PACK-018` | **显式** | `content/python` 真实包（`dist/` 已构建） | `resolveAlphaScene()` | **不回落**；`origin == alphaPack`；**153** 节点（150 项 + 3 占位）/ **170** 条边 / `maxPhi == 63` | 单元 | 同上 · `装出 150 节点 / 167 有效边 / 最大层号 63（SPEC-PACK-018）` |

> `TC-VIEW-036` 断言「不回落」而不是「能装出来」：回落路径也会给出一份看起来正常的场景，**装失败与装成功的画面无法区分**。这个测量最坏的失败形态就是「回落后画合成数据，帧率很好看，而被测对象已经不是真包了」。

> **合成档的虚线比例与真实包差 8.6 倍**（登记在 §五 第 12 项）：`TC-VIEW-031` 只锁项数与边数，虚线比例不在断言内 —— 它由 `_noise` 决定（86/167 条），而真实包只有 10/167 条。故本节出现的 draw call 数在合成档只代表该档几何，**不代表真实包**。`STR` 轮次 `R1` 里合成 ×1 与真实 α 包的 draw call 相差 2.6 倍、光栅只差 9% —— 这一偏差恰好成了「成本与调用数无关」的反证样本。

#### 3.10.4 页面（2 条 · `UniverseSpikeScreen`）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-037`~~ | — | `ADR-0002` | — | 挂载页面 → 切到 ×2 → 卸载 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：三个档位按钮都在；切换后 `takeException()` 为 `null`；卸载时 `dispose` 不撞 ticker 断言 | Widget | — |
| `TC-VIEW-038` | — | `C-32` | 未收到任何 `FrameTiming` | 挂载页面 | HUD 显示「采样中」；**不出现**「需回写 adr/0002」—— 没有样本就不出判据 | Widget | 同上 · `HUD 在没有帧时序时显示采样中，而不是编一个数（C-32）` |

**合计 277 条** = `FND` 7 + `PACK` 41 + `QUANT` 9 + `STEP` 3 + `PLAN`/`NOTE`/`VIEW` 3 + `INF` 25 + `LOAD` 40 + `EVT` 48 + `VIEW`（续）17 + `VIEW`（续二）20 + `VIEW`（续三）5 + `VIEW`（续四）6 + `VIEW`（续五）4 + `VIEW`（续六）6 + `VIEW`（续七）11 + `VIEW`（续八）6 + `VIEW`（续九）12 + `VIEW`（续十）9 + `VIEW`（续十一）5。其中 Dart 244 条（`flutter test`），管线 fixture 40 条（`verify.py --suite`：源层 32 + 产物层 8）。`v0.7.0` → `v0.8.0` 新增 20 条（`B2` 第 5 笔：绘制计数 6 · 帧时序 6 · 场景装配 6 · 页面 2），**既有 191 条一字未改**。

### 3.11 `VIEW` 域（续三）· 坐标与通道装配（5 条 · `B3` 笔 1）

> 本节锁的是 `ADR-0003` 的五条裁定**在 α 包上落到具体数**：段数、分位、命中集、占位数。全部读真实包 —— 这些数只在 α 包上有意义，内联 JSON 测不出「10 个域各 15 项」。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-039`~~ | `VIEW-002` | **显式** | α 包 | `buildSceneNodes` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`radial01` 恰 **10** 个不同值、每值 **15** 项；每项 = `(域序号 + 0.5) / 10` | 单元 | — |
| `TC-VIEW-040` | — | `ADR-0003` | α 包 | 同上 | `φ=0` 的分位为 `0`、`φ=1` 为 `3/150`；不同层的分位**严格递增**（无零宽层） | 单元 | 同上 · `φ 按层项数取累计分位，无零宽层（ADR-0003）` |
| `TC-VIEW-041` | `VIEW-003` | `C-34` | α 包 | 同上 | 虚线恰 **3** 项，且集合与 `type = tacit` 的 **完全相同** —— 两处标注共线 | 单元 | 同上 · `虚实按 C-34：不可外化格 ≥ 3，命中集与 type=tacit 相同（C-34）` |
| `TC-VIEW-042` | — | `ADR-0003` | α 包 | 同上 + `buildEdgeSpans` | 占位节点 **3** 个且 `isPlaceholder`、`size01 == 0`；节点数 **153**；边跨度 **170**（不再是 167） | 单元 | 同上 · `端口不在册的边生成占位节点，有效边数不再减少（ADR-0003）` |
| `TC-VIEW-043` | — | `ADR-0003` | 两份手搭小包 | 同上 | 主轴缺省继承 `manifest.defaultPrimaryAxis`；项级可覆盖；两者都缺 ⇒ `sector == sectorCount`（越界哨兵，不塞进任何轴） | 单元 | 同上 · `主轴缺省继承 manifest 默认，两者都缺则落「未声明」扇区（ADR-0003）` |

> `TC-VIEW-041` 与 `TC-VIEW-043` 是本节最该看的两条：前者把一个**共线发现**固定成断言（`type` 不得再占通道），后者把「不猜」写成可执行判据 —— 越界哨兵比「随便挑一个轴」更容易在评审时被抓到。

### 3.12 `VIEW` 域（续四）· 视口封顶与 HUD 规则（6 条 · `B3` 笔 2）

> 本节锁两件事：**绘制表面按面积封顶**（`C-33`，实测成本随覆盖面积走）与**七区块的显示规则**（`VIEW-018` / `VIEW-019` / `VIEW-013`）。后者尤其重要 —— 「② 激活才出现、④ 仅 `Z4`」若第一天就摆成常显占位，这条规则以后再也测不出来。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-044`~~ | — | `C-33` | 窗口 1280×800 / 恰为基准 | `planViewport` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`scale == 1`、表面 = 窗口；**恰好等于基准不降分辨率** | 单元 | — |
| `TC-VIEW-045` | — | `C-33` | 窗口 3840×2160 | 同上 | 表面 **1920×1080**、`scale == 2`、`isDownscaled` | 单元 | 同上 · `4K 窗口缩到基准尺寸再放大：表面 1920×1080、scale 2（C-33）` |
| `TC-VIEW-046` | — | `C-33` | 2560×1080 与 1920×1440（等面积异形） | 同上 | 两者 `scale` 相同、封顶后面积等于基准 —— **按面积判而非按单边** | 单元 | 同上 · `按面积判而不是按单边：2560×1080 与 1920×1440 同分支（C-33）` |
| ~~`TC-VIEW-047`~~ | `VIEW-018` | **显式** | 默认 `Z1` | 挂载 `UniverseScreen` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：①③⑤⑥ **在**；② ④ ⑦ **不在**（② 是状态栏激活才出现 · ④ 仅 `Z4` · ⑦ `V-1a` 起作废） | Widget | — |
| ~~`TC-VIEW-048`~~ | `VIEW-013` | **显式** | — | ~~点 `Z4 单星`~~ | **已作废**（`V-1a`）：⑦ 刻度条没了，「点刻度进 `Z4`」这条路不存在。`Z4` 现在只能从「点星」或「搜索落项」进；段数判据由 `TC-VIEW-186`–`189` 接手，抽屉判据并入 `189` | Widget | — |
| ~~`TC-VIEW-049`~~ | `VIEW-001` | **显式** | — | ~~遍历五档来回切~~ | **已作废**（`V-1a`）：五档刻度条随 ⑦ 一起作废。**反向**断言在 `TC-VIEW-190`（底部不再有任何档位按钮） | Widget | — |

### 3.13 `VIEW` 域（续五）· 树行模型（4 条 · `B3` 笔 3）

> 树只表达容器层级（域 → 项），域层不画 `⪯` 边。本节的四个数全部从 α 包实测而来：10 个域、`maxφ=63`（深链）、首屏 7 项、3 个黑洞。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-050`~~ | `VIEW-006` | **显式** | α 包，不展开任何域 | `buildTree` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：域行数 = `domainIds` 长度；**顺序逐个等于** `domainIds`；未展开的域只出一行 | 单元 | — |
| `TC-VIEW-051` | `VIEW-008` | **显式** | α 包（`maxφ=63`） | `initialExpandPhi` + `buildTree` | 返回 **2**；展开后项行 **7** 条（`φ=0` 3 项 + `φ=1` 2 项 + `φ=2` 2 项），且全部 `φ ≤ 2` | 单元 | 同上 · `深链空间首屏只展开到 φ=2（SPEC-VIEW-008）` |
| `TC-VIEW-052` | — | `ADR-0003` | α 包，全展开 | 同上 | **同一域内** `φ` 单调不减；每行的 `φ` 等于 `kahnLevels` 的值（跨域会重起算，故按域分段断言） | 单元 | 同上 · `域内按 φ 升序、同层按标题（无 SPEC：域内排序属设计裁定）` |
| `TC-VIEW-053` | `VIEW-007` | **显式** | α 包（3 条边指向未知） | 同上 | 黑洞行 **3** 条、`dashed`、**`expandable == false`**、`label` 非空 | 单元 | 同上 · `指向未知的画成黑洞行：虚线、不可展开、恒在末位（SPEC-VIEW-007）` |

> **本笔的口径变更 —— `R4` 判据收窄**：`R4`（源不进视觉通道）原判据是「`lib/features/**` 一律不许出现 `SourceRef` / `SourceSegment`」，与 `SPEC-VIEW-004` 末句「源只写进详情页」**直接矛盾** —— 详情三区的来源区必须显示源名与摘录，而那就在 `features/` 下。现判据改为**视觉通道文件**（`core/frame/**` · `frame_painter.dart` · `frame_draw_target.dart`），守的仍是原意：源不进**通道**。`TC-INF-016`–`019` 随之改写，并补 `TC-INF-024`（装配层被拦）与 `TC-INF-025`（详情页不拦）两条边界。
> **不采用「换个参数名绕过」**：判据写宽了就该改判据，否则规则里留着一条名不副实的约束，下一个人只会照抄那个绕法。

### 3.14 `VIEW` 域（续六）· 树视图界面（6 条 · `B3` 笔 3）

> 行模型已在 §3.13 锁住，本节只测**渲染与交互**：四类行是否可辨、点谁有反应、收起域会不会把项一起带走。
> 树是惰性列表，本节不断言「所有域行都在」—— 那测的是 `ListView` 缓存多大，不是树对不对。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-054`~~ | `FND-014` | **显式** | `pack == null`（合成回落） | 挂载 `TreeView` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：渲染 `tree-empty`；**不渲染** `tree-view`（不画一棵空树）；文案「没有可展开的树」 | Widget | — |
| `TC-VIEW-055` | `VIEW-008` | **显式** | α 包 | 挂载 `TreeView` | 标题行含「展开到 φ=2」；首 3 行建出；**所有项行 `φ ≤ 2`** | Widget | 同上 · `首屏：域全展开，项只到 φ=2（SPEC-VIEW-008）` |
| `TC-VIEW-056` | `VIEW-006` | **显式** | α 包 | 点首个域行 | 该域第一项消失；**域行本身仍在** | Widget | 同上 · `点域行收起 ⇒ 该域的项行消失（SPEC-VIEW-006）` |
| `TC-VIEW-057` | `VIEW-012` | **显式** | α 包 | 点首个圈内项行 | `onSelect` 收到该行 `id` | Widget | 同上 · `点圈内项行回调 itemId（SPEC-VIEW-012：点行等于聚焦）` |
| `TC-VIEW-058` | `VIEW-007` | **显式** | α 包（3 个黑洞） | 点黑洞行 | `onSelect` **不被调用**；无异常 | Widget | 同上 · `黑洞行不回调 —— 没有实体就没有详情可看（SPEC-VIEW-007）` |
| `TC-VIEW-059` | `VIEW-014` | **显式** | α 包，指定 `selectedItemId` | 比选中行与未选中行的字色 | 两者**不同**（六个入口落点一致 ⇒ 选中的结果必须看得见） | Widget | 同上 · `选中项与未选中项的视觉可区分（SPEC-VIEW-014：六个入口落点一致）` |

### 3.15 `VIEW` 域（续七）· 详情三区模型与面板（11 条 · `B3` 笔 3）

> 上半节（`060`–`065`）测**渲染模型** `buildItemDetail`，下半节（`066`–`070`）测面板渲染与点击。
> 「两壳一套内容」由 `TC-VIEW-068` 单独守：宽壳与窄壳的**分区顺序逐个相等**。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-060` | `VIEW-014` | **显式** | α 包，取一条两端都在册的边 | `buildItemDetail`（两端各一次） | `to` 端的关系里有 `prerequisite` 且 `itemId == from`；`from` 端有 `successor` 且 `itemId == to` | 单元 | `app/test/core/view/detail_test.dart` · `关系区按边方向落：to 是前置、from 是后继（SPEC-VIEW-014）` |
| `TC-VIEW-061` | `VIEW-007` | **显式** | α 包（3 条边指向未知） | 同上 | 缺口行 `kind == gap`、`itemId == null`、`tappable == false`、`dashed == true`、`label` 非空 | 单元 | 同上 · `端口不在册 ⇒ 缺口行：无 itemId、虚线、点不动（SPEC-VIEW-007）` |
| `TC-VIEW-062` | `FND-004` | **显式** | α 包 | 同上 | 要件区**恒 6 行**，`key` 序列**逐个等于** `RequirementKey.values`（不跟 JSON 键序走） | 单元 | 同上 · `六要件恒定六行，顺序 = RequirementKey.values（SPEC-FND-004）` |
| `TC-VIEW-063` | `VIEW-004` | **显式** | α 包，取一个 `sourceRefs` 非空的项 | 同上 | 来源区条数 = `sourceRefs` 长度；每条的 `name` / `authorityLevel` 非空、`missing == false`；首个源有 `segments` | 单元 | 同上 · `来源区按 sourceRefs 解析出源名、等级与摘录（SPEC-VIEW-004）` |
| `TC-VIEW-064` | `VIEW-004` | 语义 | 构造 `missing == true` | 读 `levelLabel` | 返回「缺源」而非空串（「引用断了」与「没有来源」必须分得开） | 单元 | 同上 · `缺源的等级标签写「缺源」，不写成空串（SPEC-VIEW-004）` |
| `TC-VIEW-065` | — | `无 SPEC` | 任意包 | `buildItemDetail(pack, 'does-not-exist')` | 返回 `null`，**不造空壳** | 单元 | 同上 · `项不在册 ⇒ null，不造空壳详情（无 SPEC：造空壳会让人以为这项存在）` |
| `TC-VIEW-066` | `VIEW-017` | **显式** | α 包 | 挂载 `DetailPanel`，按 y 坐标排四个分区 `Key` | 顺序 = **关系 → 要件 → 来源 → 笔记** | Widget | `app/test/features/detail/detail_panel_test.dart` · `三区 + 笔记区齐，顺序为 关系 → 要件 → 来源 → 笔记（SPEC-VIEW-017）` |
| `TC-VIEW-067` | `VIEW-012` | **显式** | `detail == null` | 同上 | 面板在、写「未选中知识项」；**四个分区一个都不渲染** | Widget | 同上 · `未选中 ⇒ 空态一行字，三区一个都不渲染（SPEC-VIEW-012）` |
| `TC-VIEW-068` | `VIEW-017` | **显式** | 同一项，`compact` 各一 | 分别取分区顺序 | 两次结果**逐个相等** —— 只换布局断点，不动字段与顺序 | Widget | 同上 · `窄壳与宽壳的字段顺序完全一致（SPEC-VIEW-017）` |
| `TC-VIEW-069` | `VIEW-014` | **显式** | 一条可跳关系 + 一条缺口 | 各点一次 | 可跳行回调对方 `itemId`；缺口行**不回调** | Widget | 同上 · `关系行点击回调对方 itemId，缺口行点不动（SPEC-VIEW-014）` |
| `TC-VIEW-070` | `NOTE-007` | **显式** | α 包 | 检查笔记区 | 笔记区 `Key` 在；其内**没有 `TextField`**（能输入会让人以为写完能存） | Widget | 同上 · `笔记区是可识别的空壳，不是能写字的输入框（SPEC-NOTE-007）` |

### 3.16 `VIEW` 域（续八）· 宇宙 ⇄ 树切换（6 条 · `B3` 笔 3）

> 切换只做交叉淡入（`C-22`），不做形态过渡（`VIEW-010`）。`TC-VIEW-071` 直接读 `AnimatedSwitcher.duration`，**不靠肉眼**。
> 注意：`AnimatedSwitcher` 在过渡期间**同时持有**新旧 child，断言「树还在不在」必须先推过 `C-22` 上界，否则问的是「淡出进行到哪了」。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-071`~~ | — | `C-22` | 默认 `Z1` | 读 `AnimatedSwitcher.duration` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：毫秒数落在 **180–220** 区间内；`transitionBuilder` 非空（默认即 `FadeTransition`） | Widget | — |
| `TC-VIEW-072` | `VIEW-011` | **显式** | α 包 | 点模式图标（`hud-mode-icon`） | `tree-view` 在、面包屑变两段 `知识 › Python`（`V-1a` 前写的是「树 › 全空间」）；**罗盘 ⑥ 与焦点星 ⑤ 都不渲染** | Widget | 同上 · `切到树 ⇒ 树视图出现，罗盘 ⑥ 与焦点星 ⑤ 不渲染（SPEC-VIEW-011）` |
| `TC-VIEW-073` | `VIEW-012` | **显式** | α 包，`initialMode = tree` | 挂载 | ④ 详情抽屉**在**（不必推到 `Z4`）；内容为空态 | Widget | 同上 · `树里详情常驻右栏，不必推到 Z4（SPEC-VIEW-012）` |
| `TC-VIEW-074` | `VIEW-009` | **显式** | α 包，树模式 | 点一个**有后继**的项 → 点「宇宙」 | 详情页头是该行标题；面包屑档位 == `zoomForPhi(该行 φ, hasChildren: true)`；`tree-view` 消失 | Widget | 同上 · `树里选行 ⇒ 详情填上该行，再切回宇宙按 φ 定档（SPEC-VIEW-009）` |
| ~~`TC-VIEW-075`~~ | `VIEW-001` | **显式** | — | ~~点 `Z2 星云`~~ | **已作废**（`V-1a`）：刻度条作废 ⇒ 树里没有「点刻度回宇宙」这条路。树 → 宇宙改成「点面包屑第 1 段」，见 `TC-VIEW-191` | Widget | — |
| `TC-VIEW-076` | `FND-014` | **显式** | 无包 | 点「树」 | 渲染 `tree-empty`；④ 仍在位；无异常 | Widget | 同上 · `没有包时树照样能进去，报「没有可展开的树」而不是崩（SPEC-FND-014）` |

### 3.17 `VIEW` 域（续九）· 筛选表达式 DNF（12 条 · `B3` 笔 4a）

> `SPEC-VIEW-021` 的「同轴 OR / 跨轴 AND」不是口味而是唯一自洽的读法：一项一轴只取一值，
> 同轴取 AND 恒为空集。本节前半验语义，后半验 ② 的 chip 列表。
> α 包的形状刚好够用 —— `subject` 一个取值（150 项全覆盖）、`ability` 9 个取值 × 15 项、
> `role` / `industry` / `topic` / `stack` 全 `null`。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-077`~~ | `VIEW-021` | **显式** | α 包，取 `ability` 两个取值 | `matchedCount` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：条数 = 两个取值各自条数之和（OR） | 单元 | — |
| `TC-VIEW-078` | `VIEW-021` | **显式** | α 包，两轴各取一个值 | 同上 + 逐项复查 | 条数 = 交集；每个可见项的 `ability` 都等于所取值 | 单元 | 同上 · `跨轴取 AND：两轴各取一个值只剩交集（SPEC-VIEW-021）` |
| `TC-VIEW-079` | `VIEW-021` | **显式** | α 包（`role` 全为 `null`） | filter = `{role: ['后端']}` | 命中 **0** —— 项上没有这个轴就是不匹配，不是「忽略」 | 单元 | 同上 · `轴上有筛选但项里没这个轴 ⇒ 不匹配，不是「忽略」（SPEC-VIEW-021）` |
| `TC-VIEW-080` | — | `C-27` | α 包 | `visibleIdsOf(pack, emptyAxisFilter)` | 返回 **`null`** 而非空集 —— 空集会被绘制层读成「一项都不显示」 | 单元 | 同上 · `空筛选不算筛选：visibleIds 返回 null 而不是空集（C-27）` |
| `TC-VIEW-081` | — | `无 SPEC` | α 包 | filter = `{ability: []}` | 返回 `null`，命中数 = 全量 —— 空取值集按「该轴未参与」处理 | 单元 | 同上 · `某轴取值集为空 ⇒ 该轴不参与，不把全空间筛空（无 SPEC：留空列表会让 ② 数出一个空 chip）` |
| `TC-VIEW-082` | — | `无 SPEC` | 空筛选 | `toggleAxisValue` 同一取值两次 | 结果只有一个 —— 重复会让 chip 出现两条一样的 | 单元 | 同上 · `加已有取值是幂等的，不重复（无 SPEC：重复会让 chip 出现两条一样的）` |
| `TC-VIEW-083` | — | `无 SPEC` | 单取值筛选 | `withoutAxisValue` 删掉最后一个 | 整个轴键消失，`visibleIds` 回到 `null` —— 空列表会沉淀成幽灵轴 | 单元 | 同上 · `删掉最后一个取值会把整个轴删掉，不留空列表（无 SPEC：空列表会沉淀成幽灵轴）` |
| `TC-VIEW-084` | — | `无 SPEC` | 单取值筛选 | 删不存在的取值 / 轴 | 返回**同一个实例**（`same`），不改状态 | 单元 | 同上 · `删不存在的取值不动原值（无 SPEC：删不存在的键不该静默改状态）` |
| `TC-VIEW-085` | `VIEW-019` | **显式** | 先点 `ability` 再点 `subject` | `filterChipsOf` | 轴序 = `sixAxisKeys` ⇒ `subject` 在前（不按点选先后） | 单元 | 同上 · `chip 顺序 = 轴序（sixAxisKeys）→ 取值点选序（SPEC-VIEW-019）` |
| `TC-VIEW-086` | `VIEW-019` | **显式** | 同一轴点两个取值 | 同上 | 保持点选先后 | 单元 | 同上 · `同一轴内保持点选先后（SPEC-VIEW-019）` |
| `TC-VIEW-087` | `VIEW-019` | **显式** | filter = `{ability: ['抽象']}` | 读 `axisLabel` | `能力`（中文），不是 `ability` | 单元 | 同上 · `chip 的轴名是中文，不是 key（SPEC-VIEW-019）` |
| `TC-VIEW-088` | — | `无 SPEC` | filter 含表外轴 `futureAxis` | 同上 | 仍出 chip，`axisLabel` 退回 key —— 吞掉的表现是「筛了但 ② 不显示」 | 单元 | 同上 · `表外的轴也照出 chip，不静默吞掉（无 SPEC：吞掉的表现是筛了但 ② 不显示）` |

### 3.18 `VIEW` 域（续十）· 定位浮层（9 条 · `B3` 笔 4a）

> 浮层只验**显示与选择**：它不认识档位与筛选，选完把「哪一条」交给 `universe_screen`。
> 分成两处的理由 —— 失败时的含义完全不同（一处是列错了，一处是跳错了）。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-089` | `VIEW-024` | **显式** | α 包 | 直接挂载，不输入 | 浮层在、提示行在、结果列表**不渲染**（空着也要有话说） | Widget | `app/test/features/locate/locate_overlay_test.dart` · `打开即有一段说明，不空着（SPEC-VIEW-024）` |
| `TC-VIEW-090` | `VIEW-027` | **显式** | 输入 `装饰器`（唯一精确命中） | 看结果区 | 出现「唯一命中 · 回车直接定位」，且该行在 | Widget | 同上 · `完整标题 ⇒ 唯一命中，给一行「回车直接定位」（SPEC-VIEW-027）` |
| `TC-VIEW-091` | `VIEW-027` | **显式** | 同上 | 触发 `TextInputAction.done` | `onPick` 收到最强那条（`kind == item`、`label == 装饰器`） | Widget | 同上 · `回车把最强的那条交出去（SPEC-VIEW-027）` |
| `TC-VIEW-092` | `VIEW-029` | **显式** | 输入 `抽象`（多条命中） | 点第 2 条 | 交出的是第 2 条，不是第一条 | Widget | 同上 · `点结果行交出去的是该行，不是第一条（SPEC-VIEW-029）` |
| `TC-VIEW-093` | `VIEW-028` | **显式** | 输入 `计算机科学`（轴值） | 看该行 | 徽标「轴值」+ 尾部「筛选」—— 与落点类长得不一样 | Widget | 同上 · `轴取值命中带「轴值」徽标，跟落点类长得不一样（SPEC-VIEW-028）` |
| `TC-VIEW-094` | `VIEW-026` | **显式** | 浮层打开 | 按 Esc | `onDismiss` 被调用一次 | Widget | 同上 · `Esc 关闭浮层（SPEC-VIEW-026）` |
| `TC-VIEW-095` | `VIEW-030` | **显式** | 无域上下文，输入 `虚拟环境` | 看结果区 | 出现分诊面板、**不出现**结果列表；主按钮是「记下这个需求」，**没有**「新增这一项」、也没有表单 | Widget | 同上 · `无命中先给分诊，不直接给新增入口（SPEC-VIEW-030）`（`v0.17.0` 改写：原预期是「只说没有命中」，笔 4b 起无命中要分诊） |
| `TC-VIEW-096` | `VIEW-033` | **显式** | 两个包各有一项「装饰器」；先窄作用域 | 搜「装饰器」→ 点「在全部空间中搜索」 | 单空间时一行不带前缀、也没有 ` › ` 分隔符；放宽后两行分别是 `Python › 装饰器` 与 `Go › 装饰器` —— 前缀由命中集推，不由调用方注入 | Widget | 同上 · `同名跨空间才写前缀，单空间不重复写空间名（SPEC-VIEW-033）` |
| `TC-VIEW-097` | `FND-014` | **显式** | `pack == null` | 挂载 | 浮层照样开，提示「没有内容包」；无异常 | Widget | 同上 · `没有内容包时浮层照样打开并说明原因（SPEC-FND-014）` |

### 3.19 `VIEW` 域（续十一）· 定位路由与 ② 状态栏（5 条 · `B3` 笔 4a）

> 「选了之后世界怎么变」全在 `_applyHit` 一处 —— 本节每条都在验那一个 switch。
> `TC-VIEW-100` 顺带锁住一条本笔新增的裁定：**落点 = `Z4`，不按 `φ` 定档**（见 `VIEW-027` 修订）。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-098`~~ | `VIEW-026` | **显式** | α 包，宇宙模式 | `Ctrl+K` → 再按 Esc | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：浮层出现后消失；全程无异常 | Widget | — |
| `TC-VIEW-099` | `VIEW-028` | **显式** | 输入 `计算机科学` 并点中 | 看 ② 与面包屑 | ② 出现、`subject · 计算机科学` chip 在、面包屑仍是 `Z1 星系`（**不换根**）、浮层已关 | Widget | 同上 · `轴值命中只写筛选：② 出现、视距不动（SPEC-VIEW-028）` |
| `TC-VIEW-100` | `VIEW-027` | **显式** | 输入 `装饰器` 并回车 | 看面包屑与详情 | 面包屑四段（末段 = `装饰器`）；详情页头是该标题 —— 落点是这一项本身，不是它所在的星云 | Widget | 同上 · `落点命中 ⇒ 跳到该项，详情页头是它的标题（SPEC-VIEW-027）` |
| `TC-VIEW-101` | `VIEW-019` | **显式** | 已有一条 chip | 点 `×` | ② **整块消失**（「激活才出现」是双向的） | Widget | 同上 · `删掉唯一的 chip ⇒ ② 整块消失（SPEC-VIEW-019）` |
| `TC-VIEW-102` | `VIEW-021` | **显式** | 树模式，两次筛选 | 读树标题里的项数 | `subject` 全空间同值 ⇒ 项数不变；换一个 `ability` 取值 ⇒ 项数 = 该取值条数 | Widget | 同上 · `筛选后树里只剩匹配的项（SPEC-VIEW-021）` |

### 3.20 `VIEW` 域（续十二）· 无命中分诊与表单兜底（22 条 · `B3` 笔 4b）

> `SPEC-VIEW-030` 的四类是**按判据顺序**判的，本节前半（`TC-VIEW-103`–`115`）逐条锁那个顺序，
> 后半（`116`–`124`）锁界面与路由。另有一条不属于分诊但同批修掉的缺陷：
> 关掉浮层后主焦点落空，`⌘K` 第二次打不开（`TC-VIEW-116`）。
>
> 类 ① 与 ② 在 α 包里**构造不出来**（150 项全在圈内，也没有一对「措辞不同」的标题），
> 故这几条用 `test/support/pack_fixture.dart` 现搭小包 —— 真包验「形状不变也不崩」，夹具验「判据对」。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-103` | `VIEW-030` | **显式** | 夹具包 | `diagnose(query: '')` | 返回 `null` —— 空输入不构成「搜不到」，弹分诊会让空输入看起来像失败 | 单元 | `app/test/core/locate/diagnose_test.dart` · `空输入不分诊 —— 没有输入就没有「搜不到」（SPEC-VIEW-030）` |
| `TC-VIEW-104` | `VIEW-030` | **显式** | 夹具包（有「关键字」） | `diagnose('关键字')` | `null` —— 有能落点的命中就是正向路径，归浮层 | 单元 | 同上 · `有能落点的命中就不分诊，正向路径由浮层负责（SPEC-VIEW-030）` |
| `TC-VIEW-105` | `VIEW-028` | **显式** | 夹具包，两项 `ability = 抽象` | `diagnose('抽象')` | `null` —— 轴值命中也是「成了」（写筛选），不进分诊 | 单元 | 同上 · `命中轴取值也算「成了」，不进分诊（SPEC-VIEW-028）` |
| `TC-VIEW-106` | `VIEW-030` | **显式** | 夹具包，`元类` 在圈外 | `diagnose('元类')` | `outOfScope`，`outside` 里有「元类」 | 单元 | 同上 · `只有圈外项对得上 ⇒ 类 ① 圈外，出口是申请纳入（SPEC-VIEW-030）` |
| `TC-VIEW-107` | `VIEW-030` | **显式** | 输入 `装饰器协`：既命中圈外项「装饰器协议」，又与圈内「装饰器」共享 2 片段 | 同上 | `outOfScope` 且 `near` 为空 —— ① **先于** ② | 单元 | 同上 · `圈外项先于「措辞不同」判 —— 它是更硬的事实（SPEC-VIEW-030）` |
| `TC-VIEW-108` | `VIEW-030` | **显式** | 夹具包 | `diagnose('装饰器参数')` | `differentWording`；首条是「装饰器的参数」；**不含**圈外的「装饰器协议」 | 单元 | 同上 · `零命中但有共享片段的圈内项 ⇒ 类 ② 措辞不同（SPEC-VIEW-030）` |
| `TC-VIEW-109` | `VIEW-030` | **显式** | 同上 | 读 `near` | 按 `overlap` 降序（3 片段在前、2 片段在后） | 单元 | 同上 · `邻近候选按共享片段数降序，多者在前（SPEC-VIEW-030）` |
| `TC-VIEW-110` | `VIEW-030` | **显式** | 夹具包 + `domainId = python/func` | `diagnose('虚拟环境', domainId: …)` | `absentInDomain`，回显该域 | 单元 | 同上 · `知道该放哪个域 ⇒ 类 ③ 域内没有（SPEC-VIEW-030）` |
| `TC-VIEW-111` | `VIEW-030` | **显式** | 同上前置但不给 `domainId` | 同上 | `absentInSpace`，`domainId == null` | 单元 | 同上 · `不知道往哪放 ⇒ 类 ④ 全空间没有，只记需求（SPEC-VIEW-030）` |
| `TC-VIEW-112` | `VIEW-030` | **显式** | 夹具包 | `Locator(pack).locate('元类')` | `state == none`、`hits` 非空、`usableHits` 空、`top == null` —— 存在性与可用性分开 | 单元 | 同上 · `只命中圈外项：三态是 none，那条命中仍在集里（SPEC-VIEW-030）` |
| `TC-VIEW-113` | `VIEW-030` | **显式** | 夹具包 | `nearItemsOf(pack, 'zzz')` | 空 —— 共享片段为 0 就不是候选 | 单元 | 同上 · `共享片段为 0 就不是候选，宁可去 ③/④（SPEC-VIEW-030）` |
| `TC-VIEW-114` | — | `C-28` | 夹具包 | `nearItemsOf(pack, '装饰器参数')` | 返回非空 —— 邻近候选不读 `C-28`（判据是「共享 > 0」+ 计数排序，见 `C-43`）；即使将来命中档补上阈值，这条也得继续过 | 单元 | 同上 · `不读 C-28：邻近候选判的是共享片段，不是命中阈值（C-28）` |
| `TC-VIEW-115` | — | `无 SPEC` | 夹具包 | `nearItemsOf(pack, '装')` | 空 —— 单字构不成片段，此时任何「像不像」都是猜 | 单元 | 同上 · `一段字都构不成片段时不猜（无 SPEC：单字与任何标题的「像」都是猜）` |
| `TC-VIEW-116` | `VIEW-030` | **显式** | 同上 | 点主按钮 | 出现说明且含「没有写入任何数据」——审核队列在 `B4`，不能把没写成的说成已提交 | Widget | 同上 · `类 ④ 无域上下文：只给「记下这个需求」，按下如实说没落库（SPEC-VIEW-030）` |
| `TC-VIEW-117` | `VIEW-030` | **显式** | α 包 | 输入 `装饰器参数` | 「都不对」在、「新增这一项」**不在**、候选行 `python/fn-decorator` 在；点候选 → `onPickNear` 收到该 id | Widget | 同上 · `类 ②：先给邻近候选，点候选就走落点（SPEC-VIEW-030）` |
| `TC-VIEW-118` | `VIEW-030` | **显式** | α 包 + `domainId = python/func` | 输入 `装饰器参数` → 点「都不对」 | 表单展开，标题预填 `装饰器参数`，并写出所属域 | Widget | 同上 · `类 ②「都不对」：有域上下文才展开表单，标题预填输入（SPEC-VIEW-030）` |
| `TC-VIEW-119` | `VIEW-030` | **显式** | α 包，无 `domainId` | 同上 | 无表单（第一格就得说放哪个域），只出现说明 | Widget | 同上 · `没有域上下文时「都不对」不给表单，只记需求（SPEC-VIEW-030）` |
| `TC-VIEW-120` | `VIEW-032` | **显式** | α 包 + `domainId` | 类 ③ → 表单里改标题 → 提交 | 外层搜索词不变（表单是另一次查询）；提交后出现「没有写入任何数据」 | Widget | 同上 · `表单是死的一次性查询：填它不改外层输入、提交也不留筛选（SPEC-VIEW-032）` |
| `TC-VIEW-121` | `VIEW-030` | **显式** | 夹具包（`元类` 圈外） | 输入 `元类` | 无结果列表、无「唯一命中」；「圈外」行写出该项标题；主按钮「申请纳入」 | Widget | 同上 · `类 ①：圈外项不列成结果，只给「申请纳入」（SPEC-VIEW-030）` |
| ~~`TC-VIEW-122`~~ | `VIEW-030` | **显式** | α 包 | 输入 `装饰器参数` → 点候选「装饰器」 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：浮层关；面包屑四段（末段 = `装饰器`）；详情页头是「装饰器」—— 与命中同一条落点路径 | Widget | — |
| `TC-VIEW-123` | `VIEW-032` | **显式** | α 包，先定位并选中一项（域上下文就位） | 输入 `虚拟环境` → 新增 → 提交 → `Esc` | 全程 ② 不出现；退出搜索后 ② 仍不出现 —— 视图与进来前一致 | Widget | 同上 · `表单兜底不写筛选：提交后退出搜索，视图没有被筛过（SPEC-VIEW-032）` |
| `TC-VIEW-124` | `VIEW-026` | **显式** | α 包 | `Ctrl+K` → `Esc` → 再 `Ctrl+K` | 第二遍照样打开 —— 浮层销毁时输入框的主焦点落空，不收回屏幕根就「只灵一次」 | Widget | 同上 · `关掉浮层后 ⌘K 还能再开 —— 焦点不随浮层一起消失（SPEC-VIEW-026）` |


### 3.21 `VIEW` 域（续十三）· 点星拾取与 ⑥ 罗盘（19 条 · `B3` 笔 5）

> 这一笔把宇宙从「画得出来、点不动」补成可操作：`VIEW-014` 的第一个入口（点星进详情）
> 与 `VIEW-019`/`020` 的 ⑥ 罗盘（加筛选）。用例分三层：**纯几何**（`pick.dart`，不碰投影）·
> **装配**（`scene_pick.dart`，验绘制与拾取同源）· **界面**（`universe_screen`，验接线）。
>
> `pick_test` 直接构造 `ProjectedFrame`，不跑投影 —— 这样「重叠取近」「筛掉的不参与」
> 这类判据不受相机与取景影响，失败时能直接指向判据本身。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-125`~~ | `VIEW-014` | **显式** | 手造一帧（单节点，投影单位 ×100） | 点星心 `(50, 20)` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：返回该 id | 单元 | — |
| `TC-VIEW-126` | `VIEW-014` | **显式** | 同上 | 点半径外的 `(60, 20)` | `null` —— 不误选邻星 | 单元 | 同上 · `点在星的半径外 ⇒ null（不误选邻星）（SPEC-VIEW-014）` |
| `TC-VIEW-127` | `VIEW-014` | **显式** | 两节点同屏位置，`drawOrder` 远→近 | 点重叠处 | 返回**更近**的那颗 —— `drawOrder` 反向遍历，用户点的是看得见的那颗 | 单元 | 同上 · `两星重叠时取更近的那颗，不是列表里靠前的（SPEC-VIEW-014）` |
| `TC-VIEW-128` | `VIEW-021` | **显式** | 同上 + `visibleIds` 不含该节点 | 点它的位置 | `null` —— 屏幕上没画的星不能选中 | 单元 | 同上 · `被筛掉的星点不中 —— 屏幕上没画的不能选中（SPEC-VIEW-021）` |
| `TC-VIEW-129` | — | `C-44` | 半径 1 px 的星 | 分别在 1 / 7 / 9 px 处点 | 前两处命中、9 px 处 `null` —— 下限只补到 `C-44`，不无限放大抢邻星 | 单元 | 同上 · `比 C-44 还小的星按最小可点半径接住（C-44）` |
| ~~`TC-VIEW-130`~~ | `VIEW-014` | **显式** | 三颗分得很开的星（自制场景） | 逐个点各自投影位置 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：三次都命中自己 —— 绘制与拾取若算了两套 origin / `pixelsPerUnit`，这里整体偏 | 单元 | — |
| `TC-VIEW-131` | `VIEW-014` | **显式** | 同上 | 点视口角落 `(4, 4)` | `null` | 单元 | 同上 · `点视口角落 ⇒ null（SPEC-VIEW-014）` |
| `TC-VIEW-132` | `VIEW-014` | **显式** | 同上，取 `a` 在偏航 0 时的屏幕位置 | 用偏航 `π/2` 拾取同一点 | 不再是 `a` —— 自转参与拾取，沿用基准偏航会整体点偏 | 单元 | 同上 · `偏航变了，同一个屏幕点不再命中原来那颗（SPEC-VIEW-014）` |
| `TC-VIEW-133` | `FND-014` | **显式** | 空场景 / `Size.zero` | 拾取 | 均为 `null`，不抛 —— 首帧尺寸可能是 0 | 单元 | 同上 · `空场景 / 零尺寸视口 ⇒ null，不抛（SPEC-FND-014）` |
| ~~`TC-VIEW-134`~~ | `VIEW-020` | **显式** | α 包 | `axisValuesOf(pack, 'ability')` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：与「去重后的实际取值」相等，无重复 | 单元 | — |
| `TC-VIEW-135` | `VIEW-020` | **显式** | 同上 | 逐对比较相邻取值 | 出现次数单调不增 —— 一屏放得下时常用的在前 | 单元 | 同上 · `按出现次数降序 —— 一屏放得下时常用的必须在前面（SPEC-VIEW-020）` |
| `TC-VIEW-136` | `VIEW-020` | **显式** | 同上 | 找同频的两个取值 | 按字典序 —— 两次打开顺序不变 | 单元 | 同上 · `同次数按字典序 —— 两次打开顺序不变（SPEC-VIEW-020）` |
| `TC-VIEW-137` | `VIEW-020` | **显式** | α 包（`role` 全 `null`） | 查 `role` 与不存在的轴 | 都返回空列表，不造占位值 | 单元 | 同上 · `这一轴全空 ⇒ 空列表，不造一个占位值（SPEC-VIEW-020）` |
| `TC-VIEW-138` | `VIEW-007` | **语义** | 夹具包（一项 `ability = ''`） | 查该轴取值 | 只有非空的那个 —— 空串按未声明处理 | 单元 | 同上 · `空串按未声明处理，不进候选（SPEC-VIEW-007）` |
| ~~`TC-VIEW-139`~~ | `VIEW-014` | **显式** | α 包 + 由它构出的场景 | 点中一颗星 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：④ 出现、面包屑到 `Z4` —— 与搜索命中同一条落点路径 | Widget | — |
| `TC-VIEW-140` | `VIEW-014` | **显式** | 同上 | 点星后再点空白 | ④ 仍在 —— 点歪不构成「取消」 | Widget | 同上 · `点空白不动选中 —— 详情不会毫无预警地消失（SPEC-VIEW-014）` |
| `TC-VIEW-141` | `VIEW-019` / `020` | **显式** | α 包，宇宙 | 点「能力」轴 → 点首个取值 | 收起态没有取值行；展开后出现；点取值后 ② 出现且 chip 为 `能力 · 取值` | Widget | 同上 · `⑥ 点轴就地展开取值，点取值写进 ②（SPEC-VIEW-019 / 020）` |
| `TC-VIEW-142` | `VIEW-019` | **显式** | 同上 | 再点同一个取值 | ② 整块消失 —— 与 ② 的 `×` 等价 | Widget | 同上 · `⑥ 再点同一取值即取消，② 整块消失（SPEC-VIEW-019）` |
| `TC-VIEW-143` | `FND-014` | **显式** | 不带包 | 进宇宙看 ⑥ | 写出「没有内容包」，不给轴按钮 | Widget | 同上 · `没有内容包时罗盘说清原因，不给一排按不动的按钮（SPEC-FND-014）` |

### 3.22 `VIEW` 域（续十四）· 绘制表面封顶（3 条 · `B3` 笔 6）

> 这一笔只做**成本侧**：窗口再大，绘制表面也只到 `C-33` 的基准面积为止，再放大贴满
> —— 光栅成本跟的是绘制表面，不是窗口。判据用**物理面积**（`w·h·dpr²`），否则
> 高分屏上这条封顶等于不存在。`VIEW-023` 的降级态本身**不在本笔**（缺「链」视图与
> 帧率 / 无障碍输入源，见 `VIEW-views.md` 同条「未实现」段）。
>
> 用例分两层：**纯判据**（`viewport.dart`，不需要 widget）与**接线**（4K 下画布真的
> 缩了、真的铺满、真的还点得中）。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-144`~~ | — | `C-33` | 逻辑尺寸取基准窗口，`dpr = 2` | 求 `planViewport` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`isDownscaled` 为真、`scale ≈ 2`，且**表面物理面积** `= 基准面积` —— 只看逻辑尺寸的话这条封顶在 Retina 上失效 | 单元 | — |
| `TC-VIEW-145` | — | `C-33` | `dpr` 取 `0` / `-1` / `NaN` | 求 `planViewport(800, 600)` | 表面 `800×600`、`scale = 1` —— 按 `1` 处理，画布不会变成 0 或 `NaN` 而整块消失 | 单元 | 同上 · `dpr 非法时按 1 处理，画布不会变成 0 或 NaN（C-33）` |
| ~~`TC-VIEW-146`~~ | — | `C-33` | 4K 客户区（`3840×2160`，`dpr = 1`），α 包 | 进宇宙；量画布尺寸与画布盒矩形；再点一颗星 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：画布 `≈ 1920×1080`（4 倍面积 ⇒ 线性缩一半）；画布盒左上 `(0,0)`、`3840×2160`（铺满，不居中留底）；点星仍进 `Z4` | Widget | — |

### 3.23 `VIEW` 域（续十五）· 跨空间搜索与作用域（9 条 · `B3` 笔 7）

> 这一笔把定位的范围从「一个包」扩到「一组包 + 一个作用域」（`VIEW-031`），并让
> 同名项在结果里分得清（`VIEW-033`）。用例分三层：**引擎**（`locator`，不碰界面）·
> **浮层**（那一行与那一条说明）· **屏幕**（作用域跟着档位走）。
>
> ⚠️ **本节记的是笔 7 的覆盖面**：「`Z0` 搜全部空间 / `Z1` 只搜本空间 + 一行」有了；
> 当时「按 `returnTo` 还原」与「跳进另一个空间」都**没有** —— 缺的不是 `C-21`
> （它早定为 5），而是 `trail` 历史栈与多根。**两者已由笔 10 关闭**，用例见 §3.26
> （`TC-VIEW-174`–`180`）。本节 `TC-VIEW-154` 的预期随之改写：跨空间命中现在照常
> 交给 `onPick`，落点归屏幕层。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-147` | `VIEW-031` | **显式** | 两个包各有一项标题「装饰器」 | `Locator([python, go]).locate('装饰器')` | 精确命中 **2** 条，`spaceId` 分别为 `python` / `go`，`spaceName` 各取自己的空间名 —— 跨空间不并成一条 | 单元 | `app/test/core/locate/locator_test.dart` · `两个空间的同名项都在命中集里，各带自己的空间（SPEC-VIEW-031）` |
| `TC-VIEW-148` | `VIEW-031` | **显式** | 两个包里有**同一个项 id** | 按该 id 搜 | 精确命中 **2** 条 —— 去重键带空间；不带的话并成一条，用户会以为只有一个空间有 | 单元 | 同上 · `同 id 跨空间不被去重并成一条 —— 去重键带空间（SPEC-VIEW-031）` |
| `TC-VIEW-149` | `VIEW-031` | **显式** | 同上 | `Locator([python, go], spaceId: 'go')` | 只回 `go` 的那一条 | 单元 | 同上 · `作用域收窄 ⇒ 只回本空间（SPEC-VIEW-031）` |
| `TC-VIEW-150` | `VIEW-031` | **显式** | 同上 | 作用域给一个不在列表里的 id（`rust`） | 命中集为空、三态 `none` —— **不放宽**成全部空间：静默放宽会把「本空间没搜到」说成「全部空间没搜到」 | 单元 | 同上 · `作用域给了不存在的空间 ⇒ 空，不放宽成全部空间（SPEC-VIEW-031）` |
| `TC-VIEW-151` | `FND-008` | **语义** | 两个空间各有一处精确命中 | 搜该标题 | 三态 `partial`（不是 `located`）—— 用户确实要在两条之间选一次 | 单元 | 同上 · `两个空间各有一处精确命中 ⇒ 部分命中，等用户选一次（SPEC-FND-008）` |
| `TC-VIEW-152` | — | 无 SPEC | `Locator(const [])` | 搜任意词 | 空命中集、`none`，不抛 —— 入参形状的兜底 | 单元 | 同上 · `空包列表是合法输入，不抛（无 SPEC：入参形状的兜底）` |
| `TC-VIEW-153` | `VIEW-031` | **显式** | 两个包各有一项「装饰器」；先窄作用域 | 分别在「窄作用域 + 有别的空间」「本空间无命中」「`Z0`」「只有一个空间」四种情形下看结果区顶部 | 前两种出现那一行；后两种不出现 —— 按下去什么也不会变的按钮比没有更糟 | Widget | `app/test/features/locate/locate_overlay_test.dart` · `窄作用域才给「在全部空间中搜索」，Z0 与单空间都不给（SPEC-VIEW-031）` |
| `TC-VIEW-154` | `VIEW-031` | **显式** | 同上，另一空间的命中在列表里 | 点它 | `onPick` 收到该条，且 `spaceId` 为 `go` —— **浮层不拦跨空间命中**（笔 10 起；此前是只说明、不回调） | Widget | 同上 · `跨空间的命中照样交给 onPick，且带着它自己的空间（SPEC-VIEW-031）` |
| ~~`TC-VIEW-155`~~ | `VIEW-031` | **显式** | α 包 + 一个夹具空间，`initialZoom` 分别取 `Z1` / `Z0` | 打开定位并输入 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`Z1` 有那一行、`Z0` 没有 —— 作用域跟着档位走 | Widget | — |

### 3.24 `VIEW` 域（续十六）· 导航记忆：`returnTo` 与 `trail`（16 条 · `B3` 笔 8）

> `VIEW-015` / `016` 第一次有用例。这两条此前只有实体字段（`ViewState.returnTo` / `trail`）
> 与一个常量（`C-21`），**没有任何代码读写它们** —— 典型的「规范有、入口无」（`R-08`）。
> 用例分三层：**纯逻辑**（`core/view/navigation.dart`，不碰界面，10 条）· **界面接线**
> （屏幕，4 条）· **面板**（详情页头，2 条）。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-156`~~ | `VIEW-016` | **显式** | 无 | `pushTrail(空, 'a')` → `pushTrail(['a'], 'b')` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`['a']` → `['a','b']`，追加到尾部 | 单元 | — |
| `TC-VIEW-157` | `C-21` | 语义 | 无 | 连压 `a`–`f` 六次 | 栈长 `= 5`，内容 `['b','c','d','e','f']`；`last` 是刚离开的那一项 | 单元 | 同上 · `超出 C-21 丢最旧的那端 —— 最近 5 步永远在（C-21）` |
| `TC-VIEW-158` | `VIEW-016` | **显式** | 栈非空 | `pushTrail(trail, null)` | 原样返回（同一个实例），不留空洞 | 单元 | 同上 · `null 不压栈 —— 从「没有选中」进详情不该在历史里留一个空洞（SPEC-VIEW-016）` |
| `TC-VIEW-159` | `VIEW-016` | **显式** | 无 | 压 `a` → `b` → `a`，连退两步 | 栈为 `['a','b','a']`；第一步退到 `a`，第二步退到 `b` | 单元 | 同上 · `不去重：A → B → A 是走过两次的路，两次都得记（SPEC-VIEW-016）` |
| `TC-VIEW-160` | `VIEW-016` | **显式** | 空栈 | `popTrail([])` | `itemId` 为 `null`、剩空栈（调用方据此改用快照） | 单元 | 同上 · `空栈退步给 null，剩下的还是空栈（SPEC-VIEW-016）` |
| `TC-VIEW-161` | `VIEW-015` | **显式** | 七字段都非空 | `toJson` → `fromJson` | 结果 `==` 原快照，七个字段逐个对得上（含笔 10 新增的 `spaceId`、`V-1f` 新增的 `domainId`） | 单元 | 同上 · `七个字段往返 JSON 不丢（SPEC-VIEW-015）` |
| `TC-VIEW-162` | `VIEW-015` | **显式** | 只给 `mode` / `zoomLevel` | 同上 | JSON 里**没有** `spaceId` / `domainId` / `selectedItemId` / `selector` 四个键（不是写 `null`）；还原后四者皆 `null`、筛选为空 | 单元 | 同上 · `可缺的四项是真缺：没选中项、不是从搜索进来、合成根没有空间、没有域（SPEC-VIEW-015）` |
| `TC-VIEW-163` | `VIEW-015` | **显式** | 两份筛选：键序不同、同轴取值顺序不同 | 比 `==` 与 `hashCode` | 都相等 —— 两种写法筛出的可见集一样 | 单元 | 同上 · `筛选按集合比：键序与同轴取值顺序都不影响（SPEC-VIEW-015）` |
| `TC-VIEW-164` | — | — | 缺 `zoomLevel` / 枚举名越界 | `fromJson` | 抛 `FormatException`，不猜默认值 | 单元 | 同上 · `缺字段报错而不是猜默认值 —— 猜会把 bug 变成「返回后位置有点怪」（无 SPEC：判据取自 VIEW-015 的字段清单，无独立编号）` |
| `TC-VIEW-165` | `VIEW-015` | **显式** | 构造后改传入的 map | 读 `snapshot.axisFilter` | 快照拿到的是同一份引用（不深拷贝），改动可见 | 单元 | 同上 · `快照里的筛选是快照，不是活引用（SPEC-VIEW-015）` |
| ~~`TC-VIEW-166`~~ | `VIEW-015` | **显式** | α 包，`initialZoom` 默认 `Z1` | 点一颗星 ⇒ 点「返回」 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：进详情前无返回按钮；进后有一个；返回后详情消失、面包屑回到 `Z1`、按钮再次消失 | Widget | — |
| `TC-VIEW-167` | `VIEW-016` | **显式** | α 包，先点星进详情 | 点一条带 `itemId` 的关系行 ⇒ 点「返回」 | 选中项先换成关系对方；返回后**回到最初那一项**，没有跳回 `Z1` | Widget | 同上 · `详情里点前置项 ⇒ 返回先退这一项，不是一次跳回原档位（SPEC-VIEW-016）` |
| `TC-VIEW-168` | `VIEW-015` | **显式** | α 包，`⌘K` 搜「装饰器」 | 点一条命中进详情 ⇒ 点「返回」 | 定位浮层重开，输入框里仍是「装饰器」，结果按当下重算 | Widget | 同上 · `从搜索落点进详情，返回时词填回去、结果按当下重算（SPEC-VIEW-015）` |
| `TC-VIEW-169` | `VIEW-015` | **显式** | `initialZoom` 直接给 `Z4` | 点另一颗星 | 详情照常换项，但**没有**返回按钮（退无可退不给按不动的按钮） | Widget | 同上 · `一直在详情里、从没离开过 ⇒ 不给返回按钮（SPEC-VIEW-015）` |
| `TC-VIEW-170` | `VIEW-015` | **显式** | α 包第一项 | 分别不传 / 传 `onBack` | 不传时 `detailBackKey` 不存在；传了就有，且点击恰好回调一次（面板只交出去，不判「能不能退」） | Widget | `app/test/features/detail/detail_panel_test.dart` · `返回按钮：给了回调才渲染，点了就原样交出去（SPEC-VIEW-015）` |
| `TC-VIEW-171` | `VIEW-015` `VIEW-017` | **显式** | 同上，传 `onBack` | 比返回行与标题的 y 坐标，再取四分区顺序 | 返回在标题之上；三区 + 笔记区顺序不变（加返回不影响 `VIEW-017` 的字段顺序） | Widget | 同上 · `返回按钮在标题之上，不挤动三区的顺序（SPEC-VIEW-015 / 017）` |

### 3.25 内容侧补测（3 条 · `B3` 笔 9）

> 三处**「靠约定保证」的地方**（`R-08`）：违反它们不会有任何东西变红，表现只是
> 画面还能看、但某条语义已经没了。α 包零圈外项，所以那条分支在真包上不可达 ——
> 必须用夹具造。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-172`~~ | `VIEW-004` | 语义 | 夹具包：一项圈内、一项 `inScope: false`，域展开到 `φ=0` | `buildTree` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：圈外项 `kind = outsideNeighbor`、`dashed = true`、`depth = 1`、`expandable = false`、标题仍是原文；圈内项 `kind = item`、`dashed = false` | 单元 | — |
| ~~`TC-PACK-042`~~ | — | — | ~~α 包~~ | — | **已作废**（`B13a` 笔 5c）：α 包夹具删除；且 `pack.space` / `sixAxis` 随 `ADR-0005`（三轴容器树）与 `ADR-0007` 已不存在，被测对象本身消失 | 单元 | — |
| ~~`TC-PACK-043`~~ | — | — | ~~α 包~~ | — | **已作废**（`B13a` 笔 5c）：同上，`primaryAxis` 已随六轴渲染层删除 | 单元 | — |

### 3.26 `VIEW` / `PACK` 域（续）· 多根与跨空间换根（11 条 · `B3` 笔 10）

> `VIEW-031` 的末句「跨空间落点」与 `VIEW-015` 第 4 条「跨空间换根的还原」此前
> 都是**未实现**，因为屏幕只有一个根。本笔把根改成一组（`roots`），两条同时关闭。
> 用例分三层：**纯逻辑**（`navigation.dart` 的 `TrailStep` 与 `spaceId`，1 条 + 2 条修订）·
> **屏幕行为**（7 条：换根 / 返回 / 作用域 / 树）· **装配**（`scene_source.dart`，3 条）。
>
> ⚠️ 有一条**没有断言**：空间命中后清空选中项。残留的旧空间 id 在任何视图里都
> 取不出内容（`_detail()` 返回 `null`，与 `null` 同效），唯一可观测差异是「树 → 宇宙」
> 会按 `?? 0` 猜成 0 层，而它没有独立出口。按 `R-09`（标错比不标更糟）不硬凑断言，
> 记在代码注释里。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-173`~~ | `VIEW-016` | **显式** | 无 | 压 `python/fn-closure` → `go/fn-closure`，连退两步 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：栈长 2；第一步退到 `go`、第二步退到 `python`；两个 `TrailStep` 互不相等 | 单元 | — |
| ~~`TC-VIEW-174`~~ | `VIEW-031` | **显式** | α 包为根，另有 1 项的空间 `go`；`Z1` | `⌘K` 搜「闭包」⇒ 点放宽那一行 ⇒ 点命中 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：换根到 `go`：详情 id 为 `g1`，诊断行写 `· 1 项`（α 包是 153 项） | Widget | — |
| `TC-VIEW-175` | `VIEW-015` | **显式** | 同上，已跨空间跳进 `go` 的 `Z4` | 点「返回」⇒ `Esc` 关掉重开的浮层 | 详情消失；诊断行回到 `· 153 项` —— 回到出发空间，不是停在 `go` | Widget | 同上 · `跨空间跳过去后按返回 ⇒ 回到出发的空间与档位（SPEC-VIEW-015）` |
| `TC-VIEW-176` | `VIEW-016` | **显式** | α 包，先点星进详情（`Z4`） | 详情里搜「闭包」⇒ 放宽 ⇒ 点命中 ⇒ 返回 | 回到**出发那一项**（`origin.id`），诊断行 `· 153 项` —— `trail` 里存的是「python 空间的那一项」 | Widget | 同上 · `详情里再跨空间跳 ⇒ 返回先回原空间的那一项（SPEC-VIEW-016）` |
| `TC-VIEW-177` | `VIEW-001` `VIEW-031` | **显式** | `Z0`，两个空间 | 搜「Go 语言」⇒ 点空间命中 | 换根到 `go`（诊断行 `· 1 项`）、面包屑 `Z0`、**无**详情抽屉 | Widget | 同上 · `空间命中 ⇒ 换根到它并推到 Z0，选中项清空（SPEC-VIEW-001 / 031）` |
| `TC-VIEW-178` | `VIEW-028` | **显式** | α 包为根；`go` 包唯一的项 `ability = 语言特性` | 搜「语言特性」⇒ 放宽 ⇒ 点轴值命中 | 换根到 `go`（`· 1 项`）、② 出现、面包屑仍是 `Z1` —— 筛选不换档位 | Widget | 同上 · `跨空间的轴值命中 ⇒ 换根并写筛选，档位不动（SPEC-VIEW-028 的边界）` |
| `TC-VIEW-179` | `VIEW-031` | **显式** | 已换根到 `go`（`Z0`） | 再搜「装饰器」 | 命中行的 `spaceId` 为 `python`，且该行在结果列表里 —— 换根后「别人」跟着变 | Widget | 同上 · `换根后作用域跟着新根：放宽那一行改报「另有 1 个空间」（SPEC-VIEW-031）` |
| `TC-VIEW-180` | `VIEW-031` `VIEW-021` | **显式** | 已换根到 `go` | 切到树 | 标题写 `树 · 1 项`，树里有「闭包」—— 树读的是当前根 | Widget | 同上 · `换根后树里是新根的项（SPEC-VIEW-031 / 021）` |
| ~~`TC-PACK-044`~~ | `VIEW-031` | 语义 | 真实内容目录 | `resolveAllScenes()` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：**恒非空**；含 `python` 根且 `fellBack = false`；每个真包的 `itemCount > 0` | 单元 | — |
| `TC-PACK-045` | — | — | 同上 | `resolveAlphaScene()` 与 `resolveAllScenes()` 里同一空间的那份对比 | 项数 / 边数 / 最大层号 / 径向段数**逐项相等** —— 换根与首帧必须同源（无 SPEC：违反它只会「形状有点不一样」） | 单元 | 同上 · `多根与单根对同一个包装出**同一份形状**（无 SPEC：换根与首帧必须同源）` |
| `TC-PACK-046` | `VIEW-031` | 语义 | 同上 | 取全部根的 `space.id` | 无重号 —— `_rootOf` 按 id 线性查第一个，重号等于有一个根永远进不去 | 单元 | 同上 · `每个根的空间互不相同 —— 同名会让按 id 查根查到错的那个（SPEC-VIEW-031）` |




### 3.27 布局口径 · ⑥ 罗盘六轴一行（2 条 · 2026-10-18 提出）

> 本节**没有 `SPEC` 依据**：`VIEW-019` / `VIEW-020` 只规定「六个轴按钮」与
> 「已选数量写在按钮上」，没规定排几行。要求六轴排一行是**观感口径**，
> 2026-10-18 终端验收时提出，因此追溯列一律写「—」、类型列不再标显式 / 语义。
>
> 判据是**六个按钮的 `dy` 相同**（`Set` 长度 1）。不能用「找得到六个按钮」
> 代替 —— 折行时六个照样都找得到。
>
> 实测（11px 字号，`CJK` 一字 11）：六个按钮合计 **192.3**；带 `·N` 的单个
> 按钮从 30.2 涨到 **63.5**（后缀占 33.3），两个轴同时筛合计 **263.9**。所以
> 面板宽度改成「**下限 236 + 上限 288、中间由内容撑开**」：空状态与筛查状态
> 都不折行，而写死任一常数都会在另一个状态下难看。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-181`~~ | — | — | α 包，罗盘收起态 | 取六个轴按钮的左上角 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：六个 `dy` 全相同 —— 「技术栈」不落到第二行 | Widget | — |
| `TC-VIEW-182` | — | — | α 包；`subject` 与 `ability` 各筛一个值（α 包只这两轴有取值） | 同上 | 仍全相同 —— `·N` 不该把按钮挤下去 | Widget | 同上 · `两个轴都筛过、按钮带 ·N 后仍排在一行（无 SPEC：布局口径，2026-10-18 提出）` |

### 3.28 内容侧 · 新增 `english` / `german` 两个空间（1 条 · 2026-10-18 提出）

> 这一条钉的是**架构铁律的实证面**：接入新空间不改一行核心代码，只往
> `content/` 放一个目录（`build.py` 自动发现、`resolveAllScenes()` 自动多根）。
> 所以断言落在「装出来的形状」上，而不是「目录存在」—— 后者在 `dist/` 没构建时
> 照样为真。
>
> 两个包刻意与 α 包**不同形状**：各 80 项 · 84 条边 · **8 域**（`python` 是
> 150 / 170 / **10 域**）。域数不同，换根时星图的域带分段数就不同 —— 一眼能
> 看出根真的换了；同段数会让人怀疑是不是只重渲染了一遍。
>
> 出处（`sourceRefs`）两包均为 `[]`，`excerpts` 为空段：源摘录须逐条可核验并带
> 许可标记，不代写。这是**登记在案的缺口**，不影响上述任何断言 —— 校验器允许空段。

> ⚠️ 这一笔顺带查出一处**两边判据不一致**：`Item.sourceRefs` 在客户端
> `Item.fromJson` 是**必填**，而校验器原先只查它「若出现则类型要对」。新包第一版
> 没写这个键，校验全绿，`parsePack` 抛异常 → `bundleFromPack` 返回 `null` →
> **整个空间在界面上消失**（只是少一个根，不报错）。已让校验器同口径
> （`E-ITEM-FIELD`，允许 `[]`），反证过：删掉该键会报 80 条。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-PACK-047`~~ | `PACK-001` | **显式** | 三个空间均已构建（`dist/` 不入库，先跑 `build.py`） | `resolveAllScenes()`，按 `space.id` 取 `english` 与 `german` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：各自 `fellBack = false`；项数 80、边数 84（两包都没有指向未知的边 ⇒ 无占位节点）；径向段数 **8** = 域数；`version` 非空（独立版本）、`edges` 非空（独立 `⪯`）、`layer` 三种齐全、`domainIds` 无重号 | 单元 | — |

### 3.29 ① 里的换根入口（3 条 · **已作废**）

> **本节的被测对象已删除**（`V-1a` · `VIEW-018` 修订 3 · PR #59 回退）。`B3` 收尾
> 时加这排 chips，是因为那会儿「星系不可点」；`B12` 之后星系本身是入口
> （`VIEW-036`），chips 与它语义重复，且 chips 落 `Z0` 与「点星系 ⇒ `Z1`」直接冲突。
>
> 三条**保留行**而不删除：它们记的「为什么加过 / 后来为什么撤」是追溯材料，删掉
> 就只能靠 `git log` 才查得到。替代断言 = `TC-VIEW-192`。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-183`~~ | `VIEW-031` | 语义 | — | ~~看 ①~~ | **已作废**：chips 容器与两枚 chip 都不再存在 | Widget | — |
| ~~`TC-VIEW-184`~~ | `VIEW-031` | 语义 | — | ~~树模式看 ①~~ | **已作废**：「树里不渲染 chips」这条行为随 chips 一起消失 | Widget | — |
| ~~`TC-VIEW-185`~~ | `VIEW-031` `VIEW-001` | 语义 | — | ~~点 chip~~ | **已作废**：换根入口改为「点星系」（`V-1b`）与「点面包屑第 1 段」（`TC-VIEW-193`）。⚠️ 原预期里「面包屑回到 `Z0`」也已过时 —— 空间落点现在推 `Z1` | Widget | — |

### 3.30 `V-1a` · ① 面包屑与图标（12 条 · 2026-10-18 提出）

> `VIEW-018` 修订 2 把 ① 收成三段式：**面包屑 + 14 px 模式图标 + `Z0` 放大镜**，
> ⑦ 刻度条作废。判据从「面包屑写档名」改成「**段数 = 档位**」—— 前者只能证明
> 「页面上印着 Z1」，后者证明「用户走过的那条路是对的」。
>
> 段数靠「末段没有 key」来数：`_crumbCount()` 数有 key 的前段再 +1。这条接口本身
> 就是「末段不可点」的证据 —— 末段哪天带上 key，所有段数断言一起偏 1。
>
> ⚠️ 四段里第 3 段显示的是 **`domainId`**（如 `vocab`），不是中文域名：包里没有
> `Domain` 实体，域只有 `Item.domainId` 与 `KnowledgeSpace.domainIds` 两个字符串
> 字段。`VIEW-018` 的例子写「`词法形态`」，那是数据里不存在的名字 —— 等包格式补
> `domains` 段再换，属 PACK 域修订。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-186`~~ | `VIEW-018` | **显式** | α 包，`initialZoom = Z0` | 数面包屑段数 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：**1 段** `知识`；不出现空间名（`Z0` 是宇宙层，并列的是全部空间） | Widget | — |
| `TC-VIEW-187` | `VIEW-018` | **显式** | α 包，默认 `Z1` | 同上 | **2 段**：`知识 › Python`；空间名取 `space.id` 首字母大写（`VIEW-036` 标注口径），不取 `space.name` | Widget | 同上 · `Z1 面包屑两段：知识 › Python（SPEC-VIEW-018 修订 2）` |
| `TC-VIEW-188` | `VIEW-018` `VIEW-028` | **显式** | α 包，搜索 `domainIds.first` → 点域命中 | 同上 | **3 段**：`知识 › Python › <domainId>`。域落点是 `Z2` 当前唯一正式入口（点域点要等 `V-1b`） | Widget | 同上 · `Z2 面包屑三段：加上域名（SPEC-VIEW-018 修订 2 / VIEW-028）` |
| `TC-VIEW-189` | `VIEW-001` `VIEW-018` | **显式** | α 包，搜索 `装饰器` 并回车 | 数段数 + 看 ④ | **4 段**，末段 = `装饰器`；④ 出现。`Z3` 与 `Z4` 同形 ⇒ **区分靠抽屉，不靠段数** | Widget | 同上 · `Z4 面包屑四段、且有抽屉（SPEC-VIEW-001 / 018 修订 2）` |
| `TC-VIEW-190` | `VIEW-018` | **显式** | 默认 `Z1` | 逐档查字面 `Z0 宇宙` … `Z4 单星` | 五枚都**找不到**；⑦ 的位置空着（`hudZoomScaleKey` 不存在）。⚠️ 两条判据都要：「少一块面板」与「少一个功能」是不同结论 | Widget | 同上 · `⑦ 作废后底部没有任何档位按钮（SPEC-VIEW-018 修订 1）` |
| `TC-VIEW-191` | `VIEW-018` | **显式** | α 包，`initialMode = tree` | 点面包屑第 1 段 | 回 `Z0` 并切回宇宙（`tree-view` 消失）、段数变 1。⑦ 作废后这是**树 → 宇宙的唯一出口** | Widget | 同上 · `树里点面包屑第 1 段 ⇒ 回 Z0 并切回宇宙（SPEC-VIEW-018 修订 2）` |
| `TC-VIEW-192` | `VIEW-018` `VIEW-031` | **显式** | 两个根（α + `go` 夹具） | 看 ① | `hudSpaceSwitchKey` 不存在；小写空间 id `go` 也不在 ① 里出现 —— 换根的两个正式入口是「点星系」与「点面包屑第 1 段」 | Widget | 同上 · `换根 chips 已撤：① 右侧不再有一排空间按钮（SPEC-VIEW-018 修订 3）` |
| `TC-VIEW-193` | `VIEW-018` | **显式** | α 包，`Z1` | 点第 1 段 `知识` | 段数 1、空间名消失。走 `_toLevel(Z0)`：清选中项与域（宇宙层不属于任何域） | Widget | 同上 · `前段可点：点「知识」回 Z0（SPEC-VIEW-018 修订 2）` |
| `TC-VIEW-194` | `VIEW-018` | **显式** | α 包，`Z1` | 点末段文字 `Python` | 段数仍 2。末段没有 key、没有去处 —— 「点了什么都不变」在这里是**正确**行为，与「死按钮」不是一回事：那个是控件在而无效，这个是根本不渲染成控件 | Widget | 同上 · `末段不可点：点「Python」什么都不变（SPEC-VIEW-018 修订 2）` |
| `TC-VIEW-195` | `VIEW-018` | **显式** | α 包，`Z1` | 取图标中心，点 +25 px 与 +19 px | 前者不切换、后者切换。命中盒 44 px（半径 22）、图形 14 px —— **看得见与点得中是两回事** | Widget | 同上 · `图标命中盒 44 px：盒外不切、盒内切（SPEC-VIEW-018 修订 2）` |
| `TC-VIEW-196` | `VIEW-018` | **显式** | α 包，`Z0` | 看 ① 并点放大镜 | `hudSearchKey` 存在、点击打开定位浮层。`Z1` 及更深没有它（「默认 Z1」那条的组内断言已覆盖反面） | Widget | 同上 · `Z0 有放大镜，点它开浮层（SPEC-VIEW-018 修订 2）` |
| `TC-VIEW-197` | `VIEW-015` `VIEW-018` | **显式** | α 包，点星进 `Z4` → 点第 2 段回 `Z1` → 再点同一颗星（⚠️ `V-1b` 起退到 `Z1` 而不是 `Z0`：`Z0` 不出项，那一步点到的是星系、落点变成换根。**判据没变，变的是可走的路**） | 按返回 | 回到 **`Z1`**（抽屉消失、段数 2），不是「上一颗星的 `Z4`」。残留的 `returnTo` 会让后者发生，而它看起来完全正常 —— 抽屉还开着，只是内容换了一颗星 | Widget | 同上 · `退回上层之后 returnTo 不残留（SPEC-VIEW-015 / 018 修订 2）` |

### 3.31 `V-1b` · `Z0` 宇宙层 = N 个星系（16 条 · 2026-10-18 提出）

> `VIEW-036` 把 `Z0` 从「某个空间的远景」改成**宇宙层**：一个
> `KnowledgeSpace` 一个星系，不出项、不出边，可点对象只有星系盘。于是 `Z0`
> 与 `Z1` 起**不同源** —— 前者画空间之间，后者画空间内部。
>
> 判据分两半：几何（比值、确定性、退化、遮挡）是纯函数，直接算；形态（几个
> 星系、标注在哪、点了去哪）要起 widget。
>
> ⚠️ 三处如实说明：
>
> - **本笔不画运动**。盘自转 `C-54` 与构型公转 `C-55` 归 `V-1i`，所以这里
>   没有「整数比 ⇒ 两帧逐像素相同」那条断言 —— 它验的是运动，不是形态。
> - **`k` 的取值口径**：由「最大盘直径 = 构型分布半径（`C-52`）」定，
>   **不按包数摊薄**。试过面积守恒的 `clusterR / (2·√(Σn))`，在 `C-52 = 0.30`
>   下三个包就会让矮星系撞上 `C-53` 直接判退化 —— 那是把「常数取小了」伪装成
>   「画不出来」。包数多时的挤压由重叠 + 描边承担（`VIEW-036` 明确允许遮挡）。
> - **退化只报不换形态**。`k` 触底时 `VIEW-036` 判「该档改为列表式」，列表
>   不在本笔射程内，但**必须说出来** —— 不说的话用户看到的是「几个小得看不清
>   的盘」，而不会想到「这一档画不出星系」。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-198`~~ | `VIEW-036` | **显式** | 三个空间（150 / 80 / 80） | 跑一次布局 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：盘数 = 3（一个空间一个）；主星系（项最多）落在视口中心；其余按项数降序、并列按 `id`；三个盘心互不相同 | Unit | — |
| `TC-VIEW-199` | `VIEW-036` | **显式** | 同上 | 比 150 项与 80 项的盘半径 | `r²` 之比 = 项数之比（容差 5%）—— `r = k·√n` 承载的是**比值**，不是绝对值 | Unit | 同上 · `盘半径承载**比值**：r_i / r_j = √(n_i / n_j)（容差 5%）（SPEC-VIEW-036）` |
| `TC-VIEW-200` | `VIEW-036` | **显式** | 同上 | 同一输入连跑两次布局 | 盘序、中心坐标、半径**逐分量相等**。哈希用 FNV-1a 自己算 —— `String.hashCode` 不承诺跨版本稳定 | Unit | 同上 · `分布确定性：同一输入两次布局，坐标逐分量相等（SPEC-VIEW-036）` |
| `TC-VIEW-201` | `VIEW-036` `C-53` | **显式** | 同上，视口 800×600 | 读最小盘半径与 `degenerate` | 每个盘 ≥ 40 px；不判退化。`C-53` 约束的是**全局系数 `k` 的下限**，不是 `r_i` 的下限 | Unit | 同上 · `盘半径不低于 C-53 下限，且不判退化（SPEC-VIEW-036）` |
| `TC-VIEW-202` | `VIEW-036` `C-53` | **显式** | 同上，视口 240×240 | 读 `degenerate` 与盘半径 | 判**退化**（`k` 触底），且盘仍按 40 px 下限画 —— 退化不等于把盘画没 | Unit | 同上 · `视口小到 k 触底 ⇒ 判退化，且盘按 C-53 下限画（SPEC-VIEW-036）` |
| `TC-VIEW-203` | `VIEW-036` `FND-014` | **显式** | 只有一个**合成回落**的根（无包） | 跑布局 | 空布局。合成节点背后没有 `KnowledgeSpace`，给它编一个星系等于凭空造空间（未声明即不渲染） | Unit | 同上 · `没有包的根不出星系（不凭空造空间）（SPEC-VIEW-036）` |
| `TC-VIEW-204` | `VIEW-036` | **显式** | 三个空间 | 读标注字段 | 主行 = `space.id` 首字母大写（`Python`），副行 = 项数与域数。**不取 `space.name`** —— 「Python 语法分层」在盘下方放不下 | Unit | 同上 · `标注口径：space.id 首字母大写，副行给项数与域数（SPEC-VIEW-036）` |
| `TC-VIEW-205` | `VIEW-036` | **显式** | 三个空间 | 记录绘制指令 | 盘数条指令；**每个指令的圆心都等于某个盘心** —— 均分圆的圆心在构型中心，绕的不是任何一个星系，这一条就把它排除了 | Unit | 同上 · `一个盘一次绘制，且**不画均分圆**（SPEC-VIEW-036）` |
| `TC-VIEW-206` | `VIEW-036` | **显式** | 800×600（不遮挡）与 240×240（必然遮挡） | 记录两条路径的 `rim` | 前者的盘全不描边；后者至少有 1 个被遮、且 `rim` 与 `occluded` 逐个一致 —— 描边跟遮挡标志走，不是「画好看点」 | Unit | 同上 · `未被遮不描边；被遮才描边（SPEC-VIEW-036）` |
| `TC-VIEW-207` | `VIEW-036` | **显式** | 三个空间 | 点各盘心、点 (0,0) | 盘心各自返回自己的 `spaceId`；空白返回 `null`（点空白什么都不做） | Unit | 同上 · `点圆心命中该星系；点空白返回 null（SPEC-VIEW-036）` |
| `TC-VIEW-208` | `VIEW-036` | **显式** | 240×240（盘重叠） | 点两个盘心的中点 | 命中**绘制序在前**（最近）的那个。重叠区点中前面那个是可接受的，点不中任何一个才是不可接受的 | Unit | 同上 · `重叠区命中**最近**那个（绘制序在前）（SPEC-VIEW-036）` |
| `TC-VIEW-209` | `VIEW-036` | **显式** | 240×240（退化档） | 读每个盘直径 | ≥ 24 px。正常档由 `C-53` 顶住（≥ 80 px），这一条兜的是退化情形 —— 盘画得出、点不中是最坏的失效形态 | Unit | 同上 · `点击目标不小于 24 px（C-53 兜底后仍成立）（SPEC-VIEW-036）` |
| ~~`TC-VIEW-210`~~ | `VIEW-036` | **显式** | α 包 + `go` 空间，`initialZoom = Z0` | 看画面与 ① | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：两个空间各有一条标注（`z0-galaxy-<id>`），副行写「N 项 · M 域」；没有详情抽屉；面包屑 1 段 —— **这一档不出项** | Widget | — |
| `TC-VIEW-211` | `VIEW-036` `VIEW-027` | **显式** | 同上 | 点 `go` 那个星系的盘心（坐标由同一条 `layoutGalaxies` 算出） | 换根到 `go` 并落 **`Z1`**（段数 2、星系标注消失、诊断行改成 60 项）。与搜索命中同一条路 —— 两条路都叫「进这个空间」 | Widget | 同上 · `点星系 ⇒ 换根并落到 Z1（SPEC-VIEW-036）` |
| `TC-VIEW-212` | `VIEW-036` `FND-014` | **显式** | 无包（合成回落），`Z0` | 找星系标注与退化提示 | 两者都**不存在**；不崩。空布局不构成退化 —— 退化说的是「盘小到画不出」 | Widget | 同上 · `没有包就没有星系（不凭空造空间）（SPEC-VIEW-036）` |
| `TC-VIEW-213` | `VIEW-036` `C-53` | **显式** | α 包 + `go`，窗口 800×400 | 找 `hudZ0DegradedKey` | 存在。`k` 触底是**可计算的判据**，且必须让人看到 —— 否则用户以为「就画了这么小几个点」 | Widget | 同上 · `盘半径触底时把退化说出来（C-53）` |

### 3.32 `V-1c` · `Z1` 星系盘 = 旋涡 + 域点（18 条 · 2026-10-18 提出）

> `VIEW-037` 把 `Z1` 从「项投影的远景」改成**一张盘**：核球 + 两条旋臂 + 域点，
> 项作背景、不可点。这一笔同时把 `r` 的几何落点从**同心环**改成**沿旋臂弧长**
> （`ADR-0003` 2026-10-18 修订 §2），`r` 的语义一字未动。
>
> 判据同样分两半：几何（弧长分位、对称、转过多少度、暗斑几个、点哪算命中）
> 是纯函数，直接算；形态（几个标注、点域去哪、点项无反应）要起 widget。
>
> ⚠️ 三处如实说明：
>
> - **`C-58` 的因子是勘误过的**。原式 `b = 1/tan(15°) = 3.73` 在盘半径比 10 下
>   只转 `0.68 rad`（几乎笔直）；改为 `b = tan(15°) = 0.268` 后转 `8.59 rad`
>   （约 1.37 圈）。`TC-VIEW-218` 直接锁这一条 —— 它写着「**不是半个圆都转不到
>   的径向短刺**」，把写反的因子变红。
> - **α 包 150 项全部没有 `primaryAxis`**（继承 `ability`）⇒ 所有项落在同一个
>   扇区里，十个域只是十条同心环。这是竖列的直接成因，也是本笔换几何的实证
>   依据；`θ` 通道本身没错，是内容侧还没补值（`ADR-0003` §决策 3 的 B 级变更）。
> - **项的位置不再承载 `θ`**。这一档的项是背景、不承载语义；`θ` 仍由 `Z2` 起
>   的项位置承载（那一段没动）。这不是省事，是「背景不留第二条读法」。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-214`~~ | `VIEW-037` | **显式** | 三域夹具（每域 4 项），视口 800×600 | 跑一次盘面布局 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：域点数 = 域数；每个域 **2 个**落点；臂数 = 2（核球 + 两条旋臂） | Unit | — |
| `TC-VIEW-215` | `VIEW-037` `C-30` | **显式** | 同上 | 比第 i 个域点到核球的距离 | `= 核球半径 + (i+0.5)/n × 跨距`（容差 0.01）。弧长与半径差成正比 ⇒「弧长中点」就是「半径中点」 | Unit | 同上 · `域点落在弧段的**中点**：半径 = 核球 + (i+0.5)/n × 跨距（SPEC-VIEW-037）` |
| `TC-VIEW-216` | `VIEW-037` | **显式** | 同上 | 比两条臂上同域的两点 | 关于核球中心**对称**（逐分量容差 0.01）。两个点是一个域的两个投影 | Unit | 同上 · `两条臂的点关于核球中心对称（SPEC-VIEW-037）` |
| `TC-VIEW-217` | `VIEW-037` | **显式** | 同上 | 比相邻域点的半径差 | 恒等于 `跨距 / 域数` —— 弧长等分，不是面积等分 | Unit | 同上 · `域与域在半径上等距 —— 弧长等分而不是面积等分（SPEC-VIEW-037）` |
| `TC-VIEW-218` | `C-58` | **显式** | 同上 | 逐段累加旋臂折线转过的角 | ≈ `ln(rMax/r₀)/tan(15°) = 8.59 rad`（容差 0.05），且 **> π**。用逐段累加而不是首末差角：差角只能得到模 `2π` 的值，而要验的恰是「一共转了几圈」 | Unit | 同上 · `旋臂按 C-58 的螺距转足够多圈 —— 盘半径比 10 时约 1.37 圈（C-58）` |
| `TC-VIEW-219` | `VIEW-037` | **显式** | 同上 | 同一输入连跑两次布局 | 域点与项坐标**逐分量相等**。起始角由 `space.id` 的 FNV-1a 定，不用 `Random` | Unit | 同上 · `同一输入两次布局，坐标逐分量相等 —— 不用随机数（SPEC-VIEW-037）` |
| `TC-VIEW-220` | `VIEW-037` | **显式** | 同上（12 项 / 3 域） | 读项数与每个项的位置 | 项数 = 包内项数；每项都在盘内（`≤ 盘缘 + 1`）。甩到盘外会被读成「另一层」 | Unit | 同上 · `项在盘内作背景：数量 = 包内项数（SPEC-VIEW-037）` |
| `TC-VIEW-221` | `VIEW-037` `VIEW-021` | **显式** | 同上，传 `visibleIds` = 每域 1 项 | 比筛选前后 | 项数与 `visibleIds` 同数；**域点不减少**（筛的是项，不是把域筛掉）；留下的项位置与全量布局里的完全一致（不重新洗牌） | Unit | 同上 · `筛选只减背景项，其余项位置不动（SPEC-VIEW-037）` |
| `TC-VIEW-222` | `VIEW-037` | **显式** | `s/a` 4 项链 · `s/b` 1 边 + 2 孤立 · `s/c` 无边 | 读 `systemCount` 与暗斑数 | `1 / 3 / 4`，合计 = 暗斑数 8 —— 数量 = 域内 `⪯` 子树根数，**不为好看凑数** | Unit | 同上 · `暗斑数 = 每域 ⪯ 子树根数，不为好看凑数（SPEC-VIEW-037）` |
| `TC-VIEW-223` | `VIEW-037` | **显式** | 同上 | 在**每一个**背景项的位置调拾取 | 全部返回 `null` —— 项不参与拾取。项与域点挨得太近时这条会红，那是布局问题不是判据问题 | Unit | 同上 · `点项不命中任何域 —— 项是背景（SPEC-VIEW-037）` |
| `TC-VIEW-224` | `VIEW-037` `C-57` | **显式** | 同上 | 点域点 / 偏 11 px / 偏 13 px | 命中；命中；`null` —— 命中半径 = `domainMarkMinTapDiameter / 2 = 12 px`（域点只画 4 px，按图形判会「看得见点不中」） | Unit | 同上 · `点域点命中，命中半径 24 px（SPEC-VIEW-037）` |
| `TC-VIEW-225` | `VIEW-037` `VIEW-014` | **显式** | 同上 | 点第二条臂上的同域落点 | 返回**同一个** `domainId` —— 两点拾取等价 | Unit | 同上 · `两条臂上的两个点拾取等价 —— 同一个域（SPEC-VIEW-037）` |
| `TC-VIEW-226` | `VIEW-037` | **显式** | `python/data-model` 一类的 id | 读标注名 | 取末段（`data-model`）；无斜杠时原样返回。取末段是因为盘面上十个全串会互相压住 | Unit | 同上 · `域标注取 id 末段：s/a → a（SPEC-VIEW-037）` |
| `TC-VIEW-227` | `VIEW-037` `FND-014` | **显式** | 零视口 / 零域的自造包 | 跑布局 | 两者都返回空盘 —— 不画一个「有东西」的空核球 | Unit | 同上 · `没有域或没有视口 ⇒ 空盘，不画一个「有东西」的盘（SPEC-FND-014）` |
| ~~`TC-VIEW-228`~~ | `VIEW-037` | **显式** | α 包，`initialZoom = Z1` | 找域标注与 painter | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：每个域一条标注（`z1-domain-<id>`）；画布由 `SpiralPainter` 承担，且**没有**并存的 `FramePainter` —— 两套叠着画会让拾取与画面各说一套 | Widget | — |
| `TC-VIEW-229` | `VIEW-037` `VIEW-028` | **显式** | 同上 | 点第一个域的第一个落点（坐标由同一条 `layoutSpiral` 算出） | 面包屑 3 段、第 3 段是该域 id。域点是 `Z1` **唯一**的可点对象 | Widget | 同上 · `点域点 ⇒ 落到 Z2，选中该域最浅的一项（SPEC-VIEW-037 / 028）` |
| `TC-VIEW-230` | `VIEW-037` | **显式** | 三域夹具（α 包的十域挤在 126 px 盘上，24 px 命中圈连成一片，验不出「点项无反应」） | 点一个在所有命中圈之外的背景项 | 面包屑仍 2 段、无详情抽屉 —— **连选中都不该发生**；给软响应就等于让它可点 | Widget | 同上 · `点项什么都不发生 —— 项是背景（SPEC-VIEW-037）` |
| `TC-VIEW-231` | `VIEW-037` `FND-014` | **显式** | 无包（合成回落），`Z1` | 找盘面 | 不存在 `SpiralPainter`；只留诊断行，不崩 | Widget | 同上 · `没有包时不画盘面，只留诊断行（SPEC-FND-014）` |

### 3.33 `V-1d` · `Z2` 分子云 = 一朵云 + 亮结（20 条 · 2026-10-18 提出）

> `VIEW-038` 把 `Z2` 从「项投影的近景」改成**一朵分子云**：无边界粒子云 +
> 云里的项 + 亮结（`⪯` 子树）+ 跨域出口标记。
>
> 判据三块：**通道**（粒子数不跟项数走、亮结数 = 子树数、颜色不编码语义）、
> **可点**（亮结 ⇒ `Z3`、单项子树 ⇒ `Z4`、项 ⇒ `Z4`）、**边**（域内画线、
> 跨域画出口标记，**不画断线**）。前两块是纯函数，直接算；第三块的落点要起
> widget。
>
> ⚠️ 四处如实说明：
>
> - **`φ` 从「轴向高度」改成「云内半径」**（`ADR-0003` 修订四）。`Z2` 正对
>   云面看，留着高度通道等于把它画成一条竖线；语义（累计项数分位）没变，
>   变的是落法 —— 与 `V-1c` 把 `r` 落到旋臂弧长上是同一类改动。
> - **〈动词形态〉没有数据**。规格写 `→ 进入〈动词形态〉`，而包里没有域实体、
>   没有动词形态 ⇒ 退成末段域名（`→ 进入 vocab`）。与 `VIEW-018` 的中文域名
>   同一个缺口，一并归 `PACK` 域修订，**不假造**。
> - **`⪯` 子树划分只有一份实现**（`core/graph/subtrees.dart`）。`Z1` 的暗斑与
>   `Z2` 的亮结是同一个数的两个尺度，两处各写一遍的话「暗斑 ≠ 亮结」不会有
>   任何东西变红 —— 本笔顺带把 `spiral_map` 里那份私有实现收归公共。
> - **`C-58` 的勘误在 `ADR-0003` 里还有一处漏改**（原文仍写 `b = 1/tan`），
>   本笔一并改正：`constants.md` 是数值事实源，`ADR` 是解释，两处写反了因子
>   都会把下一次实现带偏。

| 用例 | 追溯 | 类型 | 前置 | 操作 | 预期 | 方式 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-232`~~ | `VIEW-038` | **显式** | 两域夹具（`lexical` 3 项 · `vocab` 2 项），视口 800×600 | 跑一次云的布局 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：项 = 该域的项（按包内顺序）；别域的项**不进来**。顺序不同会让「第 i 项」指到别的项 | Unit | — |
| `TC-VIEW-233` | `VIEW-038` `C-62` | **显式** | 同上（3 项域 vs 2 项域） | 比两朵云的粒子数 | 都 = `C-62`（240），**完全相等**。粒子数跟项数走就成了第三条「项数」通道 | Unit | 同上 · `云粒子数固定：不跟项数走（SPEC-VIEW-038 / C-62）` |
| `TC-VIEW-234` | `VIEW-038` | **显式** | 单链夹具 `a→b→c` | 读亮结 | **1 个**；根 = `a`；`itemCount = 3`；`isSingle = false`（进 `Z3`） | Unit | 同上 · `亮结 = ⪯ 子树数：单链一个（SPEC-VIEW-038）` |
| `TC-VIEW-235` | `VIEW-038` | **显式** | 单域单链（域内只有 1 项） | 读亮结 | `isSingle = true` —— 界面据此**跳过 `Z3`** 直接 `Z4` | Unit | 同上 · `单项子树：亮结 isSingle（VIEW-038：点它跳过 Z3）（SPEC-VIEW-038）` |
| `TC-VIEW-236` | `VIEW-037` `VIEW-038` | **显式** | `vocab` 域：`x` 只有跨域前置、`y` 无前置 | 读亮结数 | **2 个**，顺序 `x` / `y`。跨域前置**不算**同域前置 —— 算进来的话这个域永远没有根 | Unit | 同上 · `无支路时每域一个亮结，与 Z1 暗斑同源（SPEC-VIEW-037 / 038）` |
| `TC-VIEW-237` | `VIEW-038` | **显式** | 上述两域夹具 | 读 `threads` 与 `exits` | `lexical` 内 2 条线（`a→b` · `b→c`）；`c→x` 攒成 **1 个出口**，`targetDomainId = python/vocab`、文案 `→ 进入 vocab` | Unit | 同上 · `域内边画线、跨域边攒成出口标记（SPEC-VIEW-038）` |
| `TC-VIEW-238` | `VIEW-038` | **显式** | 同上，改从 `vocab` 那一侧看 | 读 `threads` / `exits` | `threads` 空；`exits` 仍 **1 个**（指向 `lexical`）—— 同一条跨域边两端各算一次，两边都要能出去 | Unit | 同上 · `跨域边不再算「域内边」：出口两侧都只认一次（SPEC-VIEW-038）` |
| `TC-VIEW-239` | `VIEW-038` `C-62` | **显式** | 同上，传 `visibleIds = {a}` | 比筛选前后 | 项 3 → 1；`a→b` 那条线消失（另一端被筛掉）；**粒子数与亮结数不变**；`domainItemCount` 仍是 3 | Unit | 同上 · `筛选只减项与域内边，粒子与亮结不跟着消失（SPEC-VIEW-038 / C-62）` |
| `TC-VIEW-240` | `VIEW-038` | **显式** | 同一输入连跑两次布局 | 逐点比粒子、颜色、亮结中心 | 全部相等。粒子方位由 `domainId` 的 FNV-1a 定，不用 `Random` | Unit | 同上 · `确定性：同一输入两次布局逐点相同（SPEC-VIEW-038）` |
| `TC-VIEW-241` | `VIEW-038` | **显式** | 单链夹具 | 量每颗粒子到云心的距离；取最近 / 最远两颗的颜色 | 全部 ≤ 云半径；最近那颗**红分量 > 蓝分量**（氢 α），最远那颗反过来（尘埃反射）。只验两极 —— 中间过渡是插值实现细节 | Unit | 同上 · `云粒子落在云内，颜色内红外蓝（SPEC-VIEW-038）` |
| `TC-VIEW-242` | `FND-014` | **显式** | 域 id 不在册 | 跑布局 | 返回空云（`isEmpty`）—— 给一个没有内容的域画云，等于说「这里有东西」 | Unit | 同上 · `空域不画云（SPEC-FND-014 未声明即不渲染）` |
| `TC-VIEW-243` | `VIEW-014` `C-44` | **显式** | 单链夹具 | 点项中心 / 偏 9 px | 命中 → `item.id`；偏 9 px（> `C-44` 的 8 px）→ `null`。星画得再小也要够得着，但圈外不该抢邻星 | Unit | 同上 · `点项命中 8 px 圈内，圈外不命中（C-44 / SPEC-VIEW-014）` |
| `TC-VIEW-244` | `VIEW-038` `VIEW-018` | **显式** | 同上 | 点亮结中心 / 偏 11 px / 偏 13 px | 命中；命中；`null` —— 命中半径 = `domainMarkMinTapDiameter / 2 = 12 px`，与 `Z1` 域点同一条 24 px 口径 | Unit | 同上 · `点亮结命中 24 px 圈内（VIEW-018 口径 / SPEC-VIEW-038）` |
| `TC-VIEW-245` | `VIEW-037` `VIEW-038` | **显式** | 单项子树（亮结落在那一项身上） | 同一点分别调两个拾取函数 | 两个都命中 —— 重叠处**界面按「先亮结」分派**（容器优先，与 `Z1` 同一条口径） | Unit | 同上 · `亮结压住项时算亮结 —— 容器优先（SPEC-VIEW-037 / 038）` |
| ~~`TC-VIEW-246`~~ | `VIEW-038` | **显式** | 两域夹具（`a→b→c`） | 进域后找 painter 与亮结标注 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：画布由 `NebulaPainter` 承担；**没有**并存的 `FramePainter`（两套叠着画，拾取与画面会各说一套）；亮结标注写根项标题 | Widget | — |
| `TC-VIEW-247` | `VIEW-038` `VIEW-001` | **显式** | 同上 | 点三项子树的亮结（坐标由同一条 `layoutNebula` 算出） | 面包屑 4 段（`Z3`）、**无详情抽屉** —— 亮结是容器，不是项 | Widget | 同上 · `亮点结 ⇒ 落到 Z3（SPEC-VIEW-038）` |
| `TC-VIEW-248` | `VIEW-038` | **显式** | 单域单项夹具 | 点那个亮结 | 直接落在 `Z4`，抽屉出现 —— 给只有一颗行星的恒星系画共面轨道是纯粹的空转 | Widget | 同上 · `单项子树的亮结 ⇒ 直接 Z4，跳过 Z3（SPEC-VIEW-038）` |
| `TC-VIEW-249` | `VIEW-014` `VIEW-001` | **显式** | 两域夹具，点链尾那一项（离亮结最远，不被容器抢走） | 点云里的星 | 抽屉出现、面包屑 4 段 —— `Z2` 两种都能点（`VIEW-001`） | Widget | 同上 · `点云里的星 ⇒ Z4 详情（SPEC-VIEW-014）` |
| `TC-VIEW-250` | `VIEW-038` | **显式** | 两域夹具（`c→x` 跨域） | 找 `z2-exit-python/vocab` | 存在：云缘一个朝外的箭头 + 一行 `→ 进入 vocab`；**没有断线** | Widget | 同上 · `跨域边画成出口标记，不画断线（SPEC-VIEW-038）` |
| `TC-VIEW-251` | `VIEW-038` `VIEW-018` | **显式** | α 包（15 项一域、全落同一扇区 ⇒ 最内一项离画面中心不到 10 px） | 点云心那一项 | 抽屉出现。⑤「焦点星」的占位槽正好在屏幕正中，它若接住手势，这里就**什么都不发生**而画面一切正常 | Widget | 同上 · `云心的那一项点得中 —— ⑤ 占位不吃点击（SPEC-VIEW-038）` |

### 3.34 `V-1d2` · 标注避让 + 绘制常量提号（18 条 · 2026-10-18 提出）

> 这一笔**不对应任何新 `SPEC`**：它落在 `VIEW-036` / `037` / `038` 已写的「标注
> 在屏幕空间、字号统一」与 `VIEW-018` 的「⑤ 是槽而非内容」之上 —— 三档此前各自
> 把标签钉在正下方，规格没规定方向，所以那是自由度没被用，不是规格外私改。
>
> 三处如实说明：
>
> 1. **`Z1` / `Z2` 两条有证据力，`Z0` 那条没有。** 把 `C-70` 归零（等效于 `V-1d`
>    的「一律正下方」）后，`Z1` 与 `Z2` 的不重叠用例立刻变红 —— 与终端截图对得上；
>    而 `Z0` 那条**照样绿**，说明夹具复现不出真机那 36 px 的盘缝。它保留为**护栏**
>    （将来挤到别的盘或别的标注上会红），**不作为本笔缺陷的证据**。
> 2. **`C-64`–`C-69` 提号不改值。** 曾据「臂是 1 px 细线」打算调宽，实读是
>    `6 px + 3 px 模糊 + α 0.30` —— 错的前提不能拿去改常数。本笔只让它们可被点名。
> 3. **`⑤` 占位的文字是这次才查清的。** 终端截图里 `Z1` 核球旁那处「叠字」，
>    上一轮判断不出是什么，因为以为域名走 `idTail()` 全是英文 —— 对，但那一处
>    根本没走域名通道：它是 `Center` 在屏幕正中的「焦点星」三个字。

| 编号 | 追源 | 判据类型 | 输入 | 操作 | 期望 | 层 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-252`~~ | `VIEW-036`–`038` | **显式** | 单锚点，位于视口中心正下方（`400,380`），盒 120×14，`gap = 10` | 跑 `placeLabels` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：左 = 340、上 = 390 —— **与 `V-1d` 的「正下方、水平居中」逐像素一致**。本函数是推广，不是改变 | Unit | — |
| `TC-VIEW-253` | `VIEW-036`–`038` | **显式** | 单锚点在正右（`520,300`） | 同上 | 左 = 530、上 = 293（垂直居中）—— 标签**从点的右侧长出去**，不压住它标的那个点 | Unit | 同上 · `锚点在正右 ⇒ 标签从点的右侧长出去，垂直居中对齐` |
| `TC-VIEW-254` | `VIEW-036`–`038` | **显式** | 单锚点在正上（`400,220`） | 同上 | 左 = 340、上 = 196、**下边界 = 210**（正好贴住锚点） | Unit | 同上 · `锚点在正上 ⇒ 标签从点的上侧长出去，不压住它标的那个点` |
| `TC-VIEW-255` | `VIEW-036`–`038` | **显式** | 锚点与中心**重合** | 同上 | 退化成「正下方」（340, 310），且坐标**全部有限** —— 不因除零飞到 `NaN` | Unit | 同上 · `锚点与中心重合 ⇒ 退化成「正下方」，而不是除零后飞到 NaN` |
| `TC-VIEW-256` | `C-70` | **显式** | 两个锚点坐标完全相同 | 同上 | 第一个 0 格、第二个 1 格；两盒不相交；两盒 `left` 相同（沿方位挤开，不是挪到旁边） | Unit | 同上 · `两个同位锚点 ⇒ 第二个沿方位挤开一格，两盒不相交` |
| `TC-VIEW-257` | `C-71` | **显式** | 四个锚点坐标完全相同 | 同上 | 各占 0 / 1 / 2 / 3 格，`overlaps` **全为 false** —— 用尽上限却没压住。这条钉的是「判据是结果不是过程」 | Unit | 同上 · `四个同位锚点各占一格：用尽上限却没压住 ⇒ overlaps 是结果不是过程` |
| `TC-VIEW-258` | `C-71` | **显式** | 五个锚点坐标完全相同 | 同上 | 最后一个 `outwardSteps = C-71` 且 `overlaps = true`；**前四个仍不相交** —— 上限是最后一处让的，不是全体的借口 | Unit | 同上 · `五个同位锚点 ⇒ 最后一个接受重叠，并且把这件事说出来` |
| `TC-VIEW-259` | `VIEW-036`–`038` | **显式** | 同上两同位锚点 | 比两盒中心 | `dx` 相同、`dy` 递增 —— 外推只沿方位方向，不换象限（换象限会让「哪个标签对哪个点」失效） | Unit | 同上 · `外推只沿方位方向，不换象限` |
| `TC-VIEW-260` | `VIEW-036` | **显式** | 锚点贴右缘（`790,300`） | 同上 | 右边界收进视口；**宽高不变** —— 只平移不缩字（缩字会让同一档出现两种字号） | Unit | 同上 · `靠右缘的锚点被平移回视口内，且不缩字（宽高不变）` |
| `TC-VIEW-261` | `VIEW-036`–`038` | **显式** | 三个分散锚点，正序与逆序各跑一次 | 按 `key` 比矩形 | 每个 `key` 的矩形相同 —— **方位角是判据、下标不是**。换成下标排序的话，换个包顺序就换布局 | Unit | 同上 · `打乱传入顺序，每个 key 落到的矩形不变（方位角是判据，不是下标）` |
| `TC-VIEW-262` | — | **显式** | 三个锚点，`key` 为 `z` / `a` / `m` | 同上 | 返回顺序是 `z, a, m` —— 与传入顺序一致，调用方才能按下标回填 | Unit | 同上 · `返回顺序与传入顺序一致（调用方这样才能按下标取）` |
| `TC-VIEW-263` | — | **显式** | 两个带 `payload` 的锚点（`'knot'` 与 `42`） | 同上 | 原样带回 —— 调用方不必按 `key` 前缀反解类型（「前缀即类型」正是 `R-08` 要消掉的约定） | Unit | 同上 · `载荷原样带回 —— 调用方不必按 key 前缀反解类型` |
| `TC-VIEW-264` | `FND-014` | **显式** | 空锚点列表 | 同上 | 返回空列表、不抛 —— 没有要标注的东西不是错误 | Unit | 同上 · `没有锚点就没有摆放，也不抛` |
| ~~`TC-VIEW-265`~~ | `VIEW-037` | **显式** | α 包（10 个域，`verb-conjugation` 与 `verb-frame` 中心距 58 px、标签宽 120） | 取每个域标注的 `Rect`，两两比 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：**任意两个都不相交**。把 `C-70` 归零后此条立刻红 —— 有证据力 | Widget | — |
| `TC-VIEW-266` | `VIEW-036` | **显式** | 1080×580；α(150) + english(80) + german(80) 三根 | 比三标注两两相交；再比每个标注到自己盘 / 别的盘心的距离 | 不相交，且到**自己那个盘**最近。⚠️ **旧实现下也绿** —— 见段首第 1 条，本条的定位是护栏 | Widget | 同上 · `Z0 三个空间的标注不压在一起，且各离自己那个盘最近（回归护栏）` |
| `TC-VIEW-267` | `VIEW-038` | **显式** | α 包进第一域 | 取亮结与出口标注的 `Rect`，两两比 | 不相交。把 `C-70` 归零后此条立刻红 —— `V-1d` 时两段各落各的（亮结正下方、出口按箭头外让），谁也不看谁 | Widget | 同上 · `Z2 的亮结与出口标注不互相压（V-1d 时它们各落各的）` |
| `TC-VIEW-268` | `VIEW-018` | **显式** | α 包 | 找 `hudFocusStarKey`；找文字「焦点星」；量尺寸 | `key` **找得到**（槽还在，可断言）；**文字找不到**；尺寸 = `Size.zero`。占位落在屏幕正中，而 `Z1` 的核球、`Z2` 的云心也在那里 | Widget | 同上 · `⑤「焦点星」占位不再显示文字，但槽还在（SPEC-VIEW-018）` |
| `TC-VIEW-269` | `VIEW-036` | **显式** | 800×480（盘半径仅 100.8，靠缘的标注会顶出去） | 量十个域标注的四边与宽 | 四边都在视口内；**宽仍是 120** —— 内收只平移、不缩字 | Widget | 同上 · `标注不出视口 —— 平移而不是缩字（VIEW-036 字号统一）` |

### 3.35 `V-1e` · `Z3` 恒星系 = 一颗恒星 + 共面轨道（23 条 · 2026-10-18 提出）

> 这一笔对应 `SPEC-VIEW-039`，也是 **`VIEW-039` 的首次覆盖**。
>
> 四处如实说明：
>
> 1. **`VIEW-039` 的三条真实约束只兑现了两条。** 同向与共面本笔做到了（相位
>    全部按同一方向排、倾角差 0），**开普勒 `T ∝ a^1.5` 没有** —— 本笔只有静态
>    相位，没有运动就没有周期可验。`C-56`（内轨 8 s）仍登记在表里，归运动那一笔。
> 2. **`φ` 在本档落成「轨道序号」，`θ` 与 `r` 同时退化。** 这是 `Z0`–`Z3` 里
>    第一次出现两个通道一起退化（前几档至少保住 `θ` 或 `φ`）。代价是这一档不能
>    靠位置读出轴与域 —— 它读的是「学这一项之前要先学哪些」这条链的形状。
> 3. **同层多颗共轨是妥协。** 链状数据（每域 10 项 9 边）每层恰好一颗，不触发；
>    有分支的域会触发。真实里同轨两颗会共振散掉，但规格明写的「共面」「同向」
>    都守住了 —— 违反其中任何一条都更显眼。
> 4. **证据力是实测的。** 把 `Z3` 的布局强制恒空（走回项投影）后，本节 5 条
>    Widget 用例**全红**；只短路拾取（几何仍在）时，形态那条**绿**、拾取 4 条**红**
>    —— 两条判据各自独立被守，不是一条用例兼着。

| 编号 | 追源 | 判据类型 | 输入 | 操作 | 期望 | 层 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-270`~~ | `VIEW-039` | **显式** | 单域链 `a→b→c` | `layoutStarSystem(rootId: 'a')` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：恒星 = `a`（标题「甲」）；行星 = `[b, c]`，**按包内出现顺序**；`memberCount = 3`（含恒星） | Unit | — |
| `TC-VIEW-271` | `VIEW-039` | **显式** | 同域两项：`a→b` 与孤立的 `x` | 同上 | 行星只有 `[b]` —— `x` 是另一个根、另一个恒星系。「`Z3` 画的是**一条** `⪯` 链」 | Unit | 同上 · `只画这一棵子树：同一域的另一个根不进这个恒星系` |
| `TC-VIEW-272` | `VIEW-039` | **显式** | `a`（域 1）→ `x`（域 2） | 同上 | 空 —— 跨域边不是这个域里的「先学」，与 `subtreesInDomain()` 口径 1 同源 | Unit | 同上 · `跨域后继不算行星` |
| `TC-VIEW-273` | `VIEW-039` / `φ` | **显式** | `a→b→c` 与 `a→{b,c}`、`b→d` | 两次布局，数 `orbits` | 两次都是 **2 条轨道**；后者 `level == 1` 的行星有 **2 颗** —— 轨道数跟层号走，不跟项数走 | Unit | 同上 · `轨道数 = 最大层号` |
| `TC-VIEW-274` | `C-73` / `C-74` | **显式** | 四层链，视口 800×600（短边一半 300） | 量三条轨道的 `semiMajor` | 最内 = `300 × 0.24 = 72`、最外 = `300 × 0.46 = 138`，且逐条递增 | Unit | 同上 · `层号 → 轨道半径单调递增，最内 / 最外对得上 C-73 / C-74` |
| `TC-VIEW-275` | `VIEW-039` 第 2 条 | **显式** | `a→b→c` | 把每颗行星反旋转到轨道坐标系，代入 `(u/a)² + (v/b)²` | 每条都 ≈ `1`（容差 1e-3）—— 行星真的在自己那条椭圆上，不是随手取的点 | Unit | 同上 · `共面：每颗行星都落在自己那条椭圆上` |
| `TC-VIEW-276` | `VIEW-039` 第 2 条 | **显式** | 同上 | 比 `e` 与 `semiMinor / semiMajor` | `e ≤ C-75`；比值 = `sqrt(1 − e²)` —— 屏幕上的长短轴是实数，不经投影。「倾角差 0」的可观测形式 | Unit | 同上 · `同心：九个同心椭圆共享一个圆心，倾角差为 0` |
| `TC-VIEW-277` | `VIEW-039` | **显式** | `a→{b,c}`、`b→d` | 取 `level == 1` 的两颗 | 都落在第 1 条轨道上（余量 1e-3）；两点距离 > `4 ×` 行星半径 —— 同层均分方位，不重合 | Unit | 同上 · `同层多颗共轨：它们落在同一条轨道上，方位不重合` |
| `TC-VIEW-278` | — | **显式** | 同一份包，跑两次 | 逐项比轨道与行星坐标 | 全部相等 —— 两次打开必须是同一个恒星系（`X-02` 的下限：禁随机） | Unit | 同上 · `确定性：同一个恒星系算两次逐项相等` |
| `TC-VIEW-279` | `VIEW-039` | **显式** | `a→b→c`，`visibleIds = {a, b}` | 比全量与筛选后 | 行星只剩 `[b]`；**轨道数不变**；`b` 的坐标与全量时**逐值相等** | Unit | 同上 · `筛选只减行星：轨道数不变，其余行星位置不动` |
| `TC-VIEW-280` | `VIEW-039` | **显式** | 同上，`visibleIds = {a}` | 判 `isEmpty` | `planets` 空但 `isEmpty == false` —— 恒星与轨道仍在。退回项场景会让用户以为「这个域没有恒星系了」 | Unit | 同上 · `行星被筛空时恒星系仍然在 —— 只是没有行星` |
| `TC-VIEW-281` | `VIEW-039` | **显式** | 单项包（`a` 无后继） | 同上 | 空 —— 一颗孤星没有轨道可画，画一圈空轨道等于说「它有两颗行星」 | Unit | 同上 · `没有后继 ⇒ 空（一颗孤星没有轨道可画）` |
| `TC-VIEW-282` | `VIEW-039` | **显式** | `rootId = 'nope'` | 同上 | 空，且不抛 | Unit | 同上 · `选中的项不在包里 ⇒ 空` |
| `TC-VIEW-283` | `C-77` | **显式** | 两项链与四项链各跑一次 | 数 `wisps`；量每颗到恒星的距离 | 两次都是 **28** 颗（不跟项数走）；半径都 `< 内轨 72`（越过内轨会盖住最里面那颗行星） | Unit | 同上 · `残余云气数固定，且不越出内轨` |
| `TC-VIEW-284` | `C-72` | **显式** | 视口 800×600 | 量 `starRadius` 与 `starCenter` | `= 300 × 0.045 = 13.5`；圆心 = `(400, 300)` | Unit | 同上 · `恒星半径 = C-72 × 短边一半` |
| `TC-VIEW-285` | `VIEW-037` | **显式** | 同上，取第一颗行星 | 在距它 0 / 10 / 14 px 处 `pickStarPlanetAt` | 10 px 命中、14 px 不命中 —— 命中半径 12 px（`domainMarkMinTapDiameter` 24 的一半），**不是绘制半径 2.6** | Unit | 同上 · `行星命中 12 px，画多大不影响点得中` |
| `TC-VIEW-286` | `VIEW-037` | **显式** | 800×600 与 400×300 两个视口 | 在距恒星 0 / `r±2` / 10 / 14 px 处 `hitsStarAt` | 大窗口（`r = 13.5 > 12`）按恒星自己的半径判；小窗口（`r = 6.75 < 12`）由 12 兜底 —— 否则「看得见、点不中」 | Unit | 同上 · `恒星按 max(半径, 12 px) 判命中：大窗口按半径、小窗口按 12` |
| `TC-VIEW-287` | `VIEW-039` | **显式** | `Size.zero` | 同上 | 空，且不除零 | Unit | 同上 · `空视口不炸` |
| ~~`TC-VIEW-288`~~ | `VIEW-039` | **显式** | 单域链 `a→b→c`，从 `Z1` 点域点进 `Z2`、再点亮结 | 找 painter 与标注 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`StarPainter` 一个、`FramePainter` **零个**（两套几何不并存）；`starLabelKey('a')` 一个；面包屑 3 段；**无详情抽屉** | Widget | — |
| `TC-VIEW-289` | `VIEW-039` / `VIEW-014` | **显式** | 同上，点第一颗行星 | 看面包屑、抽屉、抽屉里的标题 | 落 `Z4`；抽屉在；抽屉里有「乙」（= `b`）—— 点行星进的是**那颗行星** | Widget | 同上 · `点行星 ⇒ Z4 详情，选中的是那颗行星` |
| `TC-VIEW-290` | `VIEW-039` | **显式** | 同上，点恒星圆心 | 同上 | 落 `Z4`；抽屉里有「甲」（= 根项 `a`）—— 点恒星进的是它自己的特写 | Widget | 同上 · `点恒星 ⇒ Z4，选中的是根项` |
| `TC-VIEW-291` | `VIEW-039` / `VIEW-014` | **显式** | 同上，先进 `Z4` 再点一个扫出来的空白点（既不在行星 12 px 内、也不在恒星命中圈内、避开右侧抽屉） | 看抽屉与面包屑 | 抽屉**仍在**、面包屑仍 4 段 —— 点歪是常态，不该把抽屉收掉 | Widget | 同上 · `点空白不动选中 —— 详情不会毫无预警地消失` |
| `TC-VIEW-292` | `C-33` | **显式** | 3840×2160（dpr 1），画布必然降采样 | 点第一颗行星（坐标乘 `scale`） | 抽屉在 —— 不乘 `scale` 会整体偏左上、点空 | Widget | 同上 · `4K 窗口：画布照旧降采样，行星照样点得中` |

### 3.36 `V-1f` · `returnTo` 快照补 `domainId`（3 条 · 2026-10-18 提出）

> 这一笔对应 `SPEC-VIEW-015` **修订三**（七字段）。规格本身早已就位（`B12` 开工时随
> `ADR-0003` 修订一并写下），本笔只做实现 —— 因此**不新增任何判据**，§四 也不重算。
>
> 四处如实说明：
>
> 1. **只有 `Z2` 存域。** 判据是「**目标档位画不画域**」，不是「离开时在不在域里」：
>    `Z0` / `Z1` 存了不会被读（还会让两份画面上一样的快照判成不相等）；`Z3` / `Z4`
>    的域由选中项反推，存下来反而多一条可能与选中项不一致的真相。
> 2. **这个洞只在一种路径上开。** 从 `Z3` 点面包屑第 3 段退回 `Z2` 时选中项被清空、
>    域留着 —— 那一帧进详情，`selectedItemId` 是 `null`，按选中项反推只能得到
>    `null`。其余「`Z2` → `Z4`」的路径上选中项恰好带域，旧实现也侥幸对。所以
>    `TC-VIEW-294` 的输入必须绕这一圈，直接「进域 → 点星 → 返回」是测不出来的。
> 3. **`TC-VIEW-295` 只作护栏。** 它在补齐实现前后都绿：`Z3` 的快照里 `domainId`
>    为空，还原走选中项反推，而选中项（恒星）本来就带域。它的定位与 `TC-VIEW-266`
>    同类 —— 守住「`Z3` 只画该域的链」这条不因快照改动而退化。
> 4. **证据力是实测的。** 改前跑 `TC-VIEW-294`：`Expected: <3>` / `Actual: <2>`
>    （面包屑少一段、`Z2` 连云都不画）；补上 `ViewSnapshot.domainId` 与还原分支后
>    转绿。同一次运行里 `TC-VIEW-295` 绿 —— 两条判据各自独立被守。

| 编号 | 追源 | 判据类型 | 输入 | 操作 | 期望 | 层 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-293`~~ | `VIEW-015` 修订三 | **显式** | 两份快照仅 `domainId` 不同（`python/data-model` vs `python/func`） | 比 `==` 与 `hashCode` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：都不相等 —— `==` / `hashCode` 没有漏字段。漏了的话「返回时域错了」在值层看起来是「同一帧」，而画面上是两个不同的域 | 单元 | — |
| ~~`TC-VIEW-294`~~ | `VIEW-015` 修订三第 7 / 9 条 | **显式** | α 包（第 2 个域 `python/data-model`）· 路径：进域 ⇒ 点亮结进 `Z3` ⇒ 点面包屑第 3 段退回 `Z2`（选中项被清、域留着）⇒ 点一颗星进 `Z4` ⇒ 点「返回」 | 数面包屑段数，再找第 3 段文字 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：仍是 **3 段**且第 3 段是 `python/data-model` —— 域进了快照。旧实现下这里是 2 段（回推拿到的 `selectedItemId` 是 `null`） | Widget | — |
| `TC-VIEW-295` | `VIEW-015` 修订三第 9 条 | **显式** | 同上域，进 `Z3` ⇒ 点第一颗行星进 `Z4` ⇒ 点「返回」 | 数面包屑段数，再找域文字 | 回到 **4 段**（`Z3` 与 `Z4` 同形，域仍在）——「从 `Z2` 返回 `Z3` 时保留域」，而这个域是从选中项反推来的，不靠快照。⚠️ **旧实现也绿**，只作护栏 | Widget | 同上 · `Z3 点行星进详情再返回：域跟着选中项回到 Z3（SPEC-VIEW-015 修订三）` |

### 3.37 `V-1f` 后半 · `Z4` 恒星特写（17 条 · 2026-10-18 提出）

> `SPEC-VIEW-040` 的**首次覆盖**。至此 `Z0`–`Z4` 五档形态全通。
>
> 四处如实说明：
>
> 1. **这一笔把 `V-1f` 补成完整的一笔。** 笔序表（`V-1a` 的 PR 描述）里 `V-1f` 写的是
>    「`Z4`：恒星特写（不转）· 快照补 `domainId`」—— 它是**两半**。`PR #68` 只交了
>    快照那一半，当时的 PR 描述与 `STR` 轮次 `R9` / `R10` 都写成「`VIEW-040` 不在
>    `B12` 九笔里」，那是**照 `V-1e` 的 PR 描述推的、没回查首版笔序表**，判断错了。
> 2. **`Z4` 从「项投影」换成「恒星特写」，连带改了一处行为**：画布不再拾取。依据是
>    `VIEW-001` 的 `Z4` 行「可点对象 —（详情抽屉即形态）」。改前 `Z4` 走 `pickSceneNode`
>    按**项投影**的坐标判命中，而这一档根本不画项投影 —— 点哪儿都是随机命中率。
> 3. **两条轨道比例（`C-79` / `C-80`）不承载语义。** 真实里最近的行星轨道是恒星半径
>    的几十倍，把恒星填满画面时它在画面外（`VIEW-040` 原话「本档最大的一处妥协」）。
>    规格的边界正是「只露能放进画面边缘的 1–2 条」，所以这两个数是**为了让轨道出现
>    在画面里**定的。
> 4. **证据力是三次独立反证实测的**（不是「写完跑绿了所以有证据」）：
>    - `Z4` 的 painter 退回项投影 ⇒ 三条 Widget 全红；
>    - `C-81` 由 2 改成 99 ⇒ 单元「只露最内」与 Widget「不是又一档星图」两条红；
>    - `C-78` 由 `0.46` 改回 `Z3` 的 `0.045` ⇒ 单元「恒星占短边比例」与 Widget
>      「画的是恒星特写」两条红。

| 编号 | 追源 | 判据类型 | 输入 | 操作 | 期望 | 层 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-296`~~ | `VIEW-040` | **显式** | 三项链 `a → b → c`，800×600 | `layoutStarCloseup(itemId: 'a')` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：恒星中心 `(400, 300)`、半径 = `300 × C-78`（`138`）；且大于 `Z3` 恒星半径的 5 倍 —— 两档同比例的话必有一档是错的 | 单元 | — |
| `TC-VIEW-297` | `VIEW-040` 边界 | **显式** | 五项链 `a → … → e`（`Z3` 四条轨道） | 同上 | 轨道 **2 条**、层号 `[1, 2]`；行星只出现在第 1 / 2 层 —— 「不做成太阳系示意图」 | 单元 | 同上 · `只露最内 C-81 条轨道：五条链也只画两条（SPEC-VIEW-040）` |
| `TC-VIEW-298` | `VIEW-040` | 语义 | 两项链（`Z3` 一条轨道） | 同上 | 轨道 1 条，半长轴 = `恒星半径 × C-79`（**内**比例）—— 用中点会让「有几层」看不出来 | 单元 | 同上 · `三条轨道以内就照实露：两项链只有一条（SPEC-VIEW-040）` |
| `TC-VIEW-299` | `VIEW-040` | **显式** | 单项、无后继（`Z3` 在这一档是空） | 同上 | **不空**：恒星半径 > 0、`C-82` 颗米粒照出，轨道与行星为空 —— 孤星是这一档的常态，与 `Z3` 的「孤星退回项投影」刻意不同 | 单元 | 同上 · `孤星也画：这一项没有后继，特写照出（SPEC-VIEW-040）` |
| `TC-VIEW-300` | — | — | 项 id 不在包里 / 视口 `Size.zero` | 同上 | `isEmpty` —— 与四档同一条入口守卫（无 SPEC：违反它只会「画了半颗恒星」） | 单元 | 同上 · `项不在包里 ⇒ 空；视口为零 ⇒ 空（无 SPEC：与四档同一条入口守卫）` |
| `TC-VIEW-301` | `VIEW-040` | **显式** | 三项链 | 反旋转到轨道自身坐标系，验 `(u/a)² + (v/b)²` | 每颗行星残差 = 1（容差 `1e-9`）—— 行星在**这一档自己的**椭圆上 | 单元 | 同上 · `行星落在这一档自己的椭圆上 —— 推近不是「另一张图」（SPEC-VIEW-040）` |
| `TC-VIEW-302` | — | — | 同一包，先算 `Z3` 再算 `Z4` | 比同 id 行星的 `phase` | 参数角逐颗相等（容差 `1e-12`）—— 两档各算一遍「均分 + 抖动」的话，推近会变成换一张图（无 SPEC：`R-08` 的正面用法） | 单元 | 同上 · `相位沿用 Z3：推近之后行星还在同一个方向上（无 SPEC：两档同源是 R-08 的判据）` |
| `TC-VIEW-303` | `VIEW-040` 第 2 条 | **显式** | 三项链 | 逐颗验「圆心距 + 半径 ≤ 恒星半径」 | 46 颗米粒 + 3 个黑子**整体**落在恒星盘内 —— 斑点是**有半径的圆**，圆心在盘内不等于它整体在盘内（这一条抓出了米粒分布半径 `0.94` 越界 1.5%） | 单元 | 同上 · `米粒与黑子全落在恒星盘内（SPEC-VIEW-040 第 2 条）` |
| `TC-VIEW-304` | `VIEW-040` 第 2 条 | **显式** | 同一项连算两次 | 逐颗比坐标与半径 | 完全相同 —— 位置由哈希定、禁随机，否则第二次打开像换了一颗星 | 单元 | 同上 · `同一项两次布局完全相同 —— 斑点位置由哈希定，禁随机（SPEC-VIEW-040 第 2 条）` |
| `TC-VIEW-305` | `VIEW-040` 第 2 条 | 语义 | 同一包的两项 `a` / `b` | 比第一颗米粒的坐标 | 不相等 —— 若两处都取常量或都按序号算，两个项会长得一模一样 | 单元 | 同上 · `换一项就换一张脸 —— 哈希真的按 item.id 走（SPEC-VIEW-040 第 2 条）` |
| `TC-VIEW-306` | `VIEW-040` 第 1 条 | **显式** | 同一份链，`itemType` 分别 `declarative` / `tacit` | 比恒星半径、accent、全部斑点 | 逐项相同 —— `type` 是**知识属性**，按它分「红巨星 / 白矮星」会私开一条通道，且与 `C-34` 那批同集重合 | 单元 | 同上 · `外观不看 Item.type —— 同一项换 type 画出来一样（SPEC-VIEW-040 第 1 条）` |
| `TC-VIEW-307` | — | — | 三项链，`visibleIds = {a, b}` | 同上 | 轨道仍是 2 条、半长轴不变，行星只剩 `b` —— 筛选只减行星（无 SPEC：与 `Z3` / `Z2` 同口径） | 单元 | 同上 · `筛选只减行星，不减轨道（无 SPEC：与 Z3 / Z2 同口径）` |
| `TC-VIEW-308` | — | — | 三项链 | `paintStarCloseup` 打到记账目标上 | 动词序列里 `starBody` 在 `granule` 与 `planet` 之前；`orbit` / `granule` / `spot` 的条数与布局一致（无 SPEC：遮挡关系就是判据 —— 反过来米粒一颗也看不见） | 单元 | 同上 · `绘制序：轨道 → 恒星 → 米粒 → 黑子 → 行星（无 SPEC：遮挡关系是判据）` |
| `TC-VIEW-309` | — | — | `StarCloseupLayout.empty` | 同上 | 一条指令都不发（无 SPEC：空包不该画半个恒星） | 单元 | 同上 · `空布局一条指令都不发（无 SPEC：空包不该画半个恒星）` |
| ~~`TC-VIEW-310`~~ | `VIEW-040` | **显式** | 三项链，走真实入口 `Z1` 点域点 → `Z2` 点亮结 → `Z3` 点第一颗行星 | 看画布 painter 与面包屑 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：painter 是 `StarCloseupPainter`；**没有** `FramePainter`、也**没有** `StarPainter`（三套几何不能并存）；`itemId == 'b'`（点的那颗行星）；面包屑 4 段 | Widget | — |
| `TC-VIEW-311` | `VIEW-040` 边界 | **显式** | 五项链，同上走真实入口 | 读 painter 的布局，再找 `starLabelKey(itemId)` | 轨道 2 条、层号 `[1, 2]`；**没有**恒星名标注 —— 面包屑末段已是这一项，邻域只靠抽屉文字 | Widget | 同上 · `Z4 不是「又一档星图」：只露最内两条轨道（SPEC-VIEW-040）` |
| `TC-VIEW-312` | `VIEW-001` | **显式** | 三项链，进 `Z4` | 依次点恒星中心、窗口空白、原行星位置 | 三处都不产生跳转：面包屑仍 4 段、抽屉里的项仍是 `乙` —— `Z4` 的可点对象是「—」 | Widget | 同上 · `Z4 画布不响应点击：可点对象是「—」（SPEC-VIEW-001）` |

### 3.38 `V-1f2` 插笔 · 多根取值域 + 筛空明示（5 条 · 2026-10-18 提出）

> 起点是用户的一张截图：「六轴罗盘学科，新增的两个语言好像没有」。实测确认 ——
> `axisValuesOf` 原来只读**当前根**，`Z0` 画着三个星系，罗盘的「学科」里却只有
> α 那一个取值。这一笔只补「值从哪来」，**不改落点**。
>
> 三点如实说明：
>
> 1. **插笔而不是塞进 `V-1g`。** `V-1g` 管的是「搜索四类落点」，与罗盘取值域
>    没有交集；把缺陷压进另一笔的 PR 里，出问题时按 `git log` 找不到它。
> 2. **顺带补的是另一条口径，不是顺手改。** 换根后筛选跟着过去（`VIEW-028`），
>    而新根可能一项都不匹配 ⇒ 画面全空。用户的原话是「点哪儿都没反应」——
>    一半是筛空、一半是这个空画面没有任何解释。`Z0` **不显示**这行提示：那一档
>    画的是星系、本就不受筛选影响，在那儿说「无匹配」会把「这一档没有可筛内容」
>    说成「整个宇宙被筛空了」。
> 3. **证据力是两处独立反证实测的**（不是「写完跑绿了所以有证据」）：
>    - `_compass()` 的取值域退回单包 ⇒ `TC-VIEW-315` 红；
>    - `noMatch` 的条件短路成 `false` ⇒ `TC-VIEW-317` 红。

| 编号 | 追源 | 判据类型 | 输入 | 操作 | 期望 | 层 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-313`~~ | `VIEW-020` 修订 5 | **显式** | 三包：4 项「计算机科学」+ 3 项「语言」+ 3 项「语言」 | `axisValuesOfAll([a, b, c], 'subject')` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`['语言', '计算机科学']` —— 合并后按**累加计数**排（6 > 4），不是按包序；同一批数据 `axisValuesOf(b)` 仍只有 `['语言']`（单包口径不变） | 单元 | — |
| `TC-VIEW-314` | `VIEW-020` 修订 5 | — | 空的可迭代 | 同上 | 空列表，不抛 —— 合成回落那种「一个包都没有」要能走到（无 SPEC：违反只会让首帧炸掉） | 单元 | 同上 · `空列表 ⇒ 空取值域，不抛（SPEC-VIEW-020 修订 5）` |
| ~~`TC-VIEW-315`~~ | `VIEW-020` 修订 5 | **显式** | α 包 + 一个 30 项的德语包（`subject = 语言`），`Z0` | 点 ⑥ 的「学科」轴 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：两个取值**都在**：α 的学科与「语言」（缺陷本体：只读当前根时后者不出现） | Widget | — |
| `TC-VIEW-316` | `VIEW-028` / `VIEW-020` 修订 5 | 语义 | 同上；先在 `Z0` 选「语言」，再点德语星系 | 看 `Z1`，再点域点 | 无筛空提示、域标注在屏上、能进 `Z2` —— 跨根选的值在那个根里真的可用 | Widget | 同上 · `选别的根的取值 ⇒ 切过去 Z1 照常，域点还能进 Z2（SPEC-VIEW-020）` |
| `TC-VIEW-317` | `VIEW-020` 修订 5 第 6 条 | **显式** | 同上；先选 α 的学科，再点德语星系（该根无一项匹配） | 看 `Z1`，再点域点进 `Z2` | `hudNoMatchKey` 出现且 `Z2` 仍在；域点**仍能点进去** —— 提示是说明不是遮罩，筛的是项不是容器 | Widget | 同上 · `取值在本根无匹配 ⇒ 明示一行小字，且不吞域点的点击（SPEC-VIEW-020）` |

### 3.39 `V-1i` 前半 · 运动时钟 + `Z1` 盘转 + 减速停转（29 条 · 2026-10-18 提出）

> `V-1i` 在笔序表里是「自转 / 构型公转 / 减速停转双阈值」（`C-54`–`C-57`），拆两笔：
> **本笔 = 时钟 + 旋转管线 + `Z1` + `C-57`**，后一笔铺满 `Z0` / `Z2` / `Z3` / `Z4`。
>
> 四点如实说明：
>
> 1. **时钟是累计秒数，不是控制器进度。** `AnimationController..repeat()` 走完一圈
>    会把 `value` 归零；`Z3` 的 `T_i = C-56 · (a_i / a_inner)^1.5` 与 `C-55` 的
>    72 s 不成整数比，归零那一帧行星会**当场跳位** —— 而跳变只在屏幕上一闪，
>    不会有任何断言变红。改成每帧 `dt × 速率` 累加，时钟只增。
> 2. **布局拆两段：构建（贵、缓存）+ 旋转（便宜、逐帧）。** 构建里有
>    `subtreesInDomain` 与 `buildSceneNodes`，是一整遍拓扑；旋转只是对算好的点做
>    一次余弦。混在逐帧路径里就是每帧重算拓扑。
> 3. **相位只有一个来源。** 拾取与标注都读同一份 `spun` 布局，painter 一行未改 ——
>    「画在这、点在那」在结构上写不出来。
> 4. **证据力是三处独立反证实测的**（不是「跑绿了所以有证据」）：
>    - `spun` 短路成恒等 ⇒ **6 条红**（旋转角、拾取、停转判据 + 2 条 Widget）；
>    - `governorFactor` 恒返回 1（停转整体失效）⇒ `TC-VIEW-343` 红；
>    - 失焦时不清 `_pointer` ⇒ `TC-VIEW-345` 红。
>
>    ⚠️ 第一次的写法是「把 `distance <= stopRadius` 改成 `distance <= 0`」，**没红**：
>    负系数被 `advanceClock` 当成 0 挡住了，于是两条防线互相掩护。改成「恒常速」才
>    真的红 —— 反证本身也会挑错。
>
> ⚠️ **本笔未实现**：`VIEW-037` 要求的「移动端长按 ≥ 400 ms 才停转、停转后抑制 tap」
> 没做 —— 触屏没有 hover，`C-57` 那条路径在本笔里根本不会触发，画面常速旋转。
> 这是**未实现**，不是未验。

| 编号 | 追源 | 判据类型 | 输入 | 操作 | 期望 | 层 | 落点 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-318`~~ | `C-54` | **显式** | 周期 24 s | `orbitPhase(6, 24)` 等四个取样 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：`0 / 0.25 / 0.5 / 0.75` —— 相位是周期的分数，不是秒数 | 单元 | — |
| `TC-VIEW-319` | `C-54` | **显式** | 同上 | `orbitPhase(24, 24)`、`orbitPhase(48, 24)` | 都等于 `0`，不是 `1.0` —— 停在 1.0 会让「t=0 与 t=T 整帧相同」永远差一个浮点误差 | 单元 | 同上 · `走满一个周期回到原点，而不是停在 1.0（C-54）` |
| `TC-VIEW-320` | `C-56` / `C-55` | **显式** | 8 s 与 72 s 两个周期 | `orbitPhase(72, 8)`、`orbitPhase(76, 8)` | `0` 与 `0.5` —— 两个周期不必整除，这正是「时钟不能取控制器进度」的理由 | 单元 | 同上 · `周期不必是整数倍关系：8 s 与 72 s 各算各的（C-56 / C-55）` |
| `TC-VIEW-321` | `C-54` | **显式** | 23.999 s 与 24.001 s | 两次 `orbitPhase`，取**环上距离** | 差 < 1e-3 —— 边界处相位连续（直接比绝对值会恒接近 1） | 单元 | 同上 · `跨过周期边界时相位连续 —— 不跳（C-54）` |
| `TC-VIEW-322` | `C-57` | 语义 | 时钟 −0.24 s | `orbitPhase(-0.24, 24)` | `0.99` —— 负时钟折回正区间，重启那一帧即便漏进来也有定义 | 单元 | 同上 · `时钟为负也折回正区间 —— 重启 ticker 那一帧不会算出负相位（C-57）` |
| `TC-VIEW-323` | `C-54` | **显式** | 周期 0 / −24 / ∞ | `orbitPhase(1, ·)` | 抛 `ArgumentError` —— 静默取 0 会让画面从此不动而无一处报错 | 单元 | 同上 · `周期为 0 或负数直接抛 —— 静默取 0 会让画面从此不动（C-54）` |
| `TC-VIEW-324` | `C-54` | 语义 | 6 / 12 / 24 s | `spunRadians(·, 24)` | `π/2 · π · 0` —— 屏幕上的转角 = 相位 × 2π | 单元 | 同上 · `旋转角 = 相位 × 2π（C-54）` |
| `TC-VIEW-325` | `C-57` | **显式** | 距离 0 / 24 / 42 / 60 / 300 | `governorFactor(·, 24, 60)` | `0 · 0 · 0.5 · 1 · 1` —— 三档：贴住不动、中间线性、远处常速 | 单元 | 同上 · `三档：贴住不动、中间线性、远处常速（C-57）` |
| `TC-VIEW-326` | `C-57` | **显式** | 距离 0…100 逐 px | 同一函数扫一遍 | 系数**单调不减** —— 反了就是「越近越快」，点不中；单调性也是收敛性的前提 | 单元 | 同上 · `系数随距离单调不减 —— 反了就是「越近越快」，点不中（C-57）` |
| `TC-VIEW-327` | `C-57` | 语义 | `stop=60, slow=24` 与 `stop=slow=24` | 同一函数 | 抛 `ArgumentError` —— 写反或相等会让减速区间消失，而画面上只表现为「转得怪」 | 单元 | 同上 · `两个阈值写反或相等直接抛 —— 否则减速区间消失而无人报错（C-57）` |
| `TC-VIEW-328` | `C-57` | 语义 | `distance = NaN` | 同一函数 | 返回 `1` —— 「不知道离多远」不该被读成「停住」 | 单元 | 同上 · `算不出距离（NaN）时按常速 —— 「不知道」不该读成「停住」（C-57）` |
| `TC-VIEW-329` | `C-57` / `C-54` | 语义 | 常量表 | 读 `governorStopRadiusPx` / `governorSlowRadiusPx` / `spinPeriodSeconds` | `24 / 60 / 24` —— 代码与 `docs/specs/constants.md` 同值 | 单元 | 同上 · `常量与规格一致：停 24、慢 60（C-57）` |
| `TC-VIEW-330` | `C-54` | 语义 | 时钟 10 s，dt 0.5 s，常速 | `advanceClock(10, 0.5, 1)` | `10.5` —— 时钟按 dt 累加 | 单元 | 同上 · `常速时按 dt 累加（C-54）` |
| `TC-VIEW-331` | `C-57` | **显式** | 时钟 10 s，dt 0.5 s，系数 0 | `advanceClock(10, 0.5, 0)` | 仍是 `10` —— **停转不改时钟**；乘在相位上就会在这里丢一段时间，恢复时画面往前蹿 | 单元 | 同上 · `停转不改时钟 —— 恢复时相位不跳（C-57）` |
| `TC-VIEW-332` | `C-57` | 语义 | dt = −0.5 / NaN / ∞ | `advanceClock(10, ·, 1)` | 都返回 `10` —— ticker 重启后第一帧不会让画面倒转 | 单元 | 同上 · `dt 为负或非有限一律丢弃 —— ticker 重启后第一帧不会倒转（C-57）` |
| `TC-VIEW-333` | `C-57` | 语义 | 系数 4 | `advanceClock(10, 1, 4)` | `11` —— 夹在 1：算错了表现为速度不对，而不是时钟飞走 | 单元 | 同上 · `系数大于 1 被夹住 —— 算错了表现为速度不对，而不是时钟飞走（C-57）` |
| `TC-VIEW-334` | `C-55` | 语义 | 1000 帧 × 1/60 s | 循环 `advanceClock` | 时钟单调且终点 ≈ 16.67 s —— 这正是「不用 `controller.value`」的判据 | 单元 | 同上 · `时钟只增：一千帧之后也不回卷（C-55）` |
| ~~`TC-VIEW-335`~~ | `C-54` | **显式** | 三域盘，相位 0 | `layout.spun(0)` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：原样返回同一对象；逐值相等 —— 0 相位不能靠浮点误差「差不多」 | 单元 | — |
| `TC-VIEW-336` | `C-54` | **显式** | 同上，相位 2π | `spun(2π)` 后逐个域点比 | 与未转逐点差 < 1e-9 —— 转一圈回到原位 | 单元 | 同上 · `转满一圈回到原位（C-54）` |
| `TC-VIEW-337` | `C-54` | **显式** | 同上，相位 0.7 | `spun(0.7)` 后比每点到盘心距离 | 距离逐个不变；盘心 / 盘半径 / 核球半径也不变 —— 刚性旋转，不是收缩 | 单元 | 同上 · `刚性旋转：每点到盘心的距离一点不变（C-54）` |
| `TC-VIEW-338` | `C-54` | **显式** | 同上，相位 π/2 | 比域点向量 | `(dx, dy) → (−dy, dx)`（容差 1e-9）—— 转的就是 90° | 单元 | 同上 · `转过 π/2 后，向量正好转 90°（C-54）` |
| `TC-VIEW-339` | `C-54` | **显式** | 同上，相位 π/2 | 在**新位置**与**旧位置**各 `pickSpiralDomainAt` 一次 | 新位置命中该域、旧位置不命中 —— 「画在这、点在那」的护栏 | 单元 | 同上 · `拾取跟着画面转：点新位置命中，点旧位置不命中（C-54）` |
| `TC-VIEW-340` | `C-57` | **显式** | 盘内域点上；盘外 200 px；转 π/2 后的原位置 | `distanceToNearestDomainMark` | 域点上 ≈ 0；盘外 > 60（常速区）；转 π/2 后原位置 > 0.5。⚠️ 不拿「转 π 后的原位置」当探针 —— 每域两臂对称，转 π 正好落回另一个落点 | 单元 | 同上 · `停转判据量的是到域点本身的距离（C-57）` |
| `TC-VIEW-341` | `C-57` | 语义 | `SpiralLayout.empty` | 同一函数 | `double.infinity` —— 空盘不该「贴着某个不存在的东西」 | 单元 | 同上 · `没有域点时可点距离是无穷 —— 空盘不该「贴着某个不存在的东西」（C-57）` |
| ~~`TC-VIEW-342`~~ | `C-54` | **显式** | α 包，`Z1`，运动开 | 读 painter 的 layout → `pump(6 s)` → 再读 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：同一域点的向量夹角 = π/2（6 / 24 = 四分之一圈） | Widget | — |
| `TC-VIEW-343` | `C-57` | **显式** | 同上；指针停在域点**外侧 12 px** | `pump(16 ms)` 记一次 → `pump(2 s)` 再记 | 两次坐标完全相同 —— 速率降到 0 且 ticker 已停。⚠️ 探针**不能压正中心**：压中心时距离 ≈ 0，阈值整个失效也照样过（实测） | Widget | 同上 · `指针贴住域点 ⇒ 停转：之后两秒画面一动不动（C-57）` |
| `TC-VIEW-344` | `C-57` | **显式** | 同上；随后把指针移到窗口底部中央 | 再推两帧（ticker 重启第一帧 `dt` 未知）后 `pump(2 s)` | 坐标变化 —— 离开减速区即恢复；漏了这一条就是永久停转 | Widget | 同上 · `指针移开 ⇒ 恢复常速（C-57）` |
| `TC-VIEW-345` | `C-57` | **显式** | 同上；指针贴住域点 | `handleAppLifecycleStateChanged(inactive)` 后推两帧 | 坐标变化 —— 失焦与进后台合并成一个 handler（桌面 Flutter 里都是 `inactive`） | Widget | 同上 · `窗口失焦（inactive）⇒ 当作指针已离开，恢复转（C-57）` |
| `TC-VIEW-346` | `C-57` | 语义 | `disableAnimations = true` | `pump(5 s)` 后比坐标 | 完全不动 —— 系统「减弱动画」是总开关，也是测试里唯一的确定性开关 | Widget | 同上 · `系统「减弱动画」开着 ⇒ 画面完全不动（C-57）` |

### 3.40 `V-1i` 后半 · 五档铺满运动（24 条 · 2026-10-19 提出）

> `V-1i` 的后一半：把前半只接在 `Z1` 上的相位铺到 `Z0` / `Z2` / `Z3` / `Z4`。
> 时钟与速率（`advanceClock` / `governorFactor`）**一个字没改** —— 这一笔只加
> 四个档的「布局 × 相位」方法，以及各档自己的停转判据。
>
> 四点如实说明：
>
> 1. **`Z0` 的 `C-54` 在这条路上仍然不可观测。** 那一档的盘只是一枚椭圆、
>    没有内部图案，绕自身轴转的投影轮廓每个角度都一样 ⇒ 只接 `C-55` 构型公转。
>    这不是「没做」，是「做了看不见」——两件事在报告里必须分开写。
> 2. **`Z0` 的公转是刚体，所以遮挡标记不重判。** 反证过程中发现原文的注释写错了
>    （「不重判描边会停在上帧的判定上」）：相对位置逐字不变，重判只是每帧多花
>    `n²` 次比较。改法是把前提写成可执行断言（`TC-VIEW-351`），而不是留一段
>    听着对的注释。
> 3. **`Z3` / `Z4` 的周期只由层号定**，不读当前档的半长轴。反证实测：改成读本档
>    `a` 之后 `TC-VIEW-363` 会红 —— 而画面上表现为「推近那一瞬间行星突然变速」，
>    很难归因到周期。
> 4. **两条用例本身被反证挑出毛病**（详见 `STR` 的 `R13c`）：`TC-VIEW-368` 原先
>    只比「当前 vs `t=0`」，时钟停在非零值上时照样绿；`TC-VIEW-366` 原先只比
>    「前后相等」，两端都错时差值仍相等。两条判据都已改成「与绝对量比」。

| 用例 | 常量 | 类型 | 输入 | 方法 | 预期 | 层次 | 来源 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-347`~~ | `C-55` | **显式** | 三空间，800×600 | `layoutGalaxies(...).spun(π/3)` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：主星系中心逐分量不变；每个矮星系到构型中心的距离（正圆口径）不变 | 单元 | — |
| `TC-VIEW-348` | `C-55` | **显式** | 同上，相位 π/2 | 比正圆口径下的偏移向量 | `(dx, dy) → (−dy, dx)`（容差 1e-9）—— 转的是盘面上的 90°，不是屏幕上的 | 单元 | 同上 · `转 90° = 正圆口径里把偏移方向转 90°（C-55）` |
| `TC-VIEW-349` | `C-55` | 语义 | 同上，π/4 两次 vs π/2 一次；另取 2π | 逐盘比坐标 | 两次半程 = 一次全程；2π 回到原位（容差 1e-9）—— 公转是个群作用 | 单元 | 同上 · `两次半程 = 一次全程；走满一圈回到原位（C-55）` |
| `TC-VIEW-350` | `C-55` | 语义 | 相位 0 / NaN；只有一个盘 | `spun(·)` 返回对象 | `identical` 为真 —— 不重建、也不启 ticker | 单元 | 同上 · `相位为 0 / 非有限，或只有一个盘时原样返回（C-55）` |
| `TC-VIEW-351` | `C-55` | 语义 | 五个等大空间，扫 π/4 的整数倍共 8 个角度 | 逐盘比 `occluded` | 与 `t=0` 逐个相同 —— **这条红了就说明 `spun` 已不是刚体，必须回去补重判** | 单元 | 同上 · `刚体旋转：谁挡谁逐字不变 —— 这就是 spun 不重判遮挡的前提（SPEC-VIEW-036）` |
| `TC-VIEW-352` | `C-57` | **显式** | 单盘；盘心 / 长轴端点 / 3 倍半径处 | `distanceToNearestGalaxy` | 负 / ≈0 / 正 —— 过零点正是盘缘，盘内一律读作「贴住了」 | 单元 | 同上 · `停转判据：盘内为负、盘缘过零、盘外为正（C-57）` |
| ~~`TC-VIEW-353`~~ | `C-54` | **显式** | 两域包，相位 π/2 | `layoutNebula(...).spun(π/2)` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：项与云粒子逐个落在「绕云心转 90°」的期望位置（1e-9）；粒子半径不变 | 单元 | — |
| `TC-VIEW-354` | `C-54` | 语义 | 三项单链（一棵子树） | 比亮结中心与成员质心 | 两者重合（1e-9），且相对 `t=0` 确实移动过 —— 它没有自己的角速度 | 单元 | 同上 · `亮结没有自己的角速度 —— 它跟的是成员质心（SPEC-VIEW-038）` |
| `TC-VIEW-355` | `C-54` | **显式** | 两域包（含一条跨域边），相位 π/2 | 比出口的 `center` 与 `direction` | 位置绕云心转 90°；朝向 `(dx, dy) → (−dy, dx)` —— 只转位置会让箭头指回来路 | 单元 | 同上 · `出口的箭头朝向跟着转 —— 只转位置会让箭头指回来路（SPEC-VIEW-038）` |
| `TC-VIEW-356` | `C-54` | 语义 | 同上，相位 2π / 0 | 同 `TC-VIEW-349` 的口径 | 2π 回到原位；0 原样返回（`identical`） | 单元 | 同上 · `走满一圈回到原位；相位为 0 时原样返回（C-54）` |
| `TC-VIEW-357` | `C-57` | 语义 | 亮结中心 / 项中心 / 出口中心 | `distanceToNearestNebulaMark` | 前两者 ≈ 0；出口 > 24 —— 出口不算可点对象，算进去减速区间会常驻 | 单元 | 同上 · `停转判据取亮结与项里近的那个，出口不算（C-57）` |
| ~~`TC-VIEW-358`~~ | `C-56` | **显式** | 层数 1 / 2 / 3 | `starOrbitPeriodSeconds(level, n)` | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：最内层恒等于 `C-56`；`T_2 = C-56 · (C-74/C-73)^1.5`（1e-9）；外层恒大于内层 | 单元 | — |
| `TC-VIEW-359` | `C-56` | 语义 | 同一 level=2，层数 2 vs 4 | 同上 | 四层时更短 —— 层数多则第二层相对更靠内。守的是「不读本档 `semiMajor`」 | 单元 | 同上 · `周期只由层号定 —— 层数变了周期跟着变，与当前档的轨道半径无关（C-56）` |
| `TC-VIEW-360` | `C-56` | **显式** | 两层包，推进 `T_1/4` 与 `T_1` | `advanced(·)` + 反解参数角 | 前者参数角 +π/2（1e-6）；后者回到原位（1e-6）；`phase` 字段全程不变 | 单元 | 同上 · `相位推进：四分之一周期转 90° 参数角，一个周期回到原位（C-56）` |
| `TC-VIEW-361` | `C-56` | 语义 | 同上，推进 `T_2/4` | 只看第二层那颗 | 它转过 π/2，同一段时间内层已过一整圈 —— 「越外越慢」 | 单元 | 同上 · `两层各按自己的周期走：外轨走 1/4 圈时内轨已走大半圈（C-56）` |
| `TC-VIEW-362` | `C-56` | 语义 | 时钟 0 / NaN；另筛掉一颗行星 | `advanced(·)` / `layoutStarSystem(visibleIds:)` | `identical` 为真；筛掉一颗不改变另一颗的位置 | 单元 | 同上 · `时钟为 0 时原样返回；筛选不影响相位（C-56）` |
| ~~`TC-VIEW-363`~~ | `C-56` | **显式** | 五项链，同一 `clock = 3.7` | `Z3.advanced(3.7)` 与 `Z4.advanced(3.7)` 各反解参数角 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：逐层两档的**增量相等**（1e-9）。⚠️ 改成读本档 `a` 后此条必红（反证实测） | 单元 | — |
| `TC-VIEW-364` | `C-56` | 语义 | 同上，推进 2.3 s | 验本档椭圆方程 `(u/a)² + (v/b)²` | 恒为 1（1e-9）—— 落点始终在本档的 `C-79` / `C-80` 尺度上 | 单元 | 同上 · `推进后行星仍在本档的椭圆上（C-79 / C-80 的尺度没被带走）` |
| `TC-VIEW-365` | `C-56` | 语义 | 时钟 0；孤星（`c`，无后继） | `advanced(·)` | `identical` 为真 —— 没有行星可走，界面也不该为它启 ticker | 单元 | 同上 · `相位为 0 时原样返回；孤星特写不炸（C-56）` |
| ~~`TC-VIEW-366`~~ | `C-55` | **显式** | α 包 + 60 项空间，`Z0`，运动开 | 读 `GalaxyPainter.layout` → `advance(6 s)` → 再读 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：主星系中心不变；矮星系方位转过 30°；⚠️ **正圆半径恒等于 `C-52 × 短边`** —— 断言的是绝对量，不是「前后相等」 | Widget | — |
| `TC-VIEW-367` | `C-54` | **显式** | α 包，`Z1` → `Z2`，运动开 | 读 `NebulaPainter.layout` → `advance(6 s)` | 离云心最远那一项的距离不变、方位转过 90°（与 `Z1` 同一个 `ω`） | Widget | 同上 · `Z2 云整盘自转：项绕云心转，离云心的距离不变（C-54）` |
| `TC-VIEW-368` | `C-56` | **显式** | α 包，`Z1` → `Z2` → `Z3`，运动开 | 记 `t_0` → `advance(3 s)` → 记 `t_1` → 点 `t_1` 里最左那颗 | 进了 `Z4`，且 `itemId` 就是刚点的那颗。⚠️ 推 **3 s（135°）而不是 2 s（90°）**：同层 4 等分时 90° 会精确落回另一颗的位置（反证实测） | Widget | 同上 · `Z3 行星公转：按此刻的位置点得中（C-56）` |
| `TC-VIEW-369` | `C-57` | **显式** | 同上；先 `advance(1 s)` 确认在走，再 `mouseOn` 最左那颗 | `pump(16 ms)` 记一次 → `advance(2 s)` 再记 | 逐颗坐标完全相同。⚠️ 前半句「不贴时它必须在走」是必需的 —— 否则「本来就不动」也能让这条过 | Widget | 同上 · `Z3 指针贴住行星 ⇒ 停转（C-57）` |
| `TC-VIEW-370` | `C-57` | 语义 | `Z3` 点行星进 `Z4`；指针压住其中一颗 | `pump(16 ms)` 记一次 → `advance(2 s)` 再记 | 坐标**变了** —— 这一档可点对象是「—」（`VIEW-001`），`_governorAt` 走「不知道就常速」 | Widget | 同上 · `Z4 没有可点对象 ⇒ 指针压住行星也照转（VIEW-001 / C-57）` |

### 3.41 `V-1g` · 搜索四类落点（3 条 · 2026-10-19 提出）

> 笔序表把 `V-1g` 写成「搜索四类落点**重写**」。探清之后，落到实处只有一条 ——
> **四类落点早在 `B3` 笔 4a / 7 / 10 与 `V-1a` 修订里就改完了，缺的是证据**。
>
> 1. 项 ⇒ `Z4`、空间 ⇒ `Z1`（`V-1a` 已从 `Z0` 改过）、轴值 ⇒ 只写筛选，三路都有
>    用例；**域 ⇒ `Z2` 这一路一条都没有**。`TC-VIEW-371` 补的就是它 —— 这是本笔
>    唯一的判据缺口，也是笔序表那一行唯一还站得住的部分。
> 2. **「落点不看发起视图」从没验过**：树里也能 `⌘K`，而树只画行、不画单星 ⇒
>    项落点必须切回宇宙（`372`）；轴值是筛选类，反过来必须**留在树**（`373`）——
>    筛的是用户正在看的那一份，切走等于把他带离了要看的东西。
> 3. 同一张验收表里 `VIEW-031` 有一行仍写「空间命中落 `Z0`」，与 `VIEW-027` 那两行
>    的 `Z1` 互相打脸 ⇒ **规格残留，本笔一并纠正**。代码与断言一直是 `Z1`，
>    所以这不是「改坏了再改回来」，是「文档没跟上」。
> 4. `VIEW-029` 的第三键「未学优先」**仍未实现**，且不是本笔能补的：它要掌握度，
>    而掌握度归 `B6`。`locator.dart` 里写明这一点，不假装做了。

| 用例 | 常量 | 类型 | 输入 | 方法 | 预期 | 层次 | 来源 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-371`~~ | `VIEW-027` | **显式** | α 包，`Z1` | `⌘K` 搜 `python/func` → 回车 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：浮层关；面包屑**三段**且第 3 段是该域；**不弹抽屉** —— `Z2` 本就不显示抽屉，域落点顺手选中的那一项在这一档没有可观测出口 | Widget | — |
| `TC-VIEW-372` | `VIEW-031` | **显式** | α 包，`mode = tree` | 树里 `⌘K` 搜「装饰器」→ 回车 | 树收起、视图切回宇宙，档位 `Z4` —— 项只有那一档看得见，落点不因发起视图而变 | Widget | 同上 · `树里搜到项 ⇒ 落点切回宇宙的 Z4（SPEC-VIEW-027）` |
| `TC-VIEW-373` | `VIEW-028` | **显式** | α 包，`mode = tree` | 树里 `⌘K` 搜「计算机科学」→ 回车 | 树**还在**；② 出现那条「轴名：取值」chip —— 筛选类不换档位也不切视图 | Widget | 同上 · `树里搜到轴值 ⇒ 留在树，只写筛选（SPEC-VIEW-028）` |

### 3.42 `V-1h` · 树四层与树里换根（10 条 · 2026-10-19 提出）

> 笔序表把 `V-1h` 的判据写成「`VIEW-006` **修订**」，读起来要**先改规格再写代码**。
> 探清之后：**规格已经改过** —— 四层表、两个可点区、「换根留在树里」都在 `#61`
> （`docs(view): B12 规格就位`）里落地了，`VIEW-009` 的「落点层级 = 档位」也在同一笔。
> 落后的是**实现与证据**：树一直只有「域 → 项」两层，`_zoomForSelection` 仍在按 `φ`
> 定档（与 `VIEW-009` 修订第 2 条**直接冲突**），树里的抽屉无条件常驻（与 `VIEW-006`
> 修订第 4 条冲突）。所以本笔**未改任何规格**，是把已裁定的修订落地。
>
> ⚠️ **两条旧用例的判据被改（不是新增）**：`树里详情常驻右栏` → `树里没选中项就不开抽屉`；
> `再切回宇宙按 φ 定档` → `再切回宇宙落 Z4`。前者从「常驻」改成「有选中才开」，后者从
> 「按 `φ`」改成「项一律 `Z4`」。两条都是修订文本先改、实现后到，用例跟着修订走。
>
> ⚠️ **两处规格没写、由实现补的裁定**（详见 `VIEW-006` 落地状态，请评审确认）：① `知识`
> 的名字**不可点**（回 `Z0` 的入口在面包屑第 1 段）；② 当前根那一行挂「当前」标签。
>
> ⚠️ **一处口径由本笔补**：筛选（`visibleIds`）**只作用于当前根**（`TC-VIEW-375`）——
> `visibleIds` 是当前包算出来的，拿它去藏别的空间的项，等于替用户判了另一份数据。

| 用例 | 常量 | 类型 | 输入 | 方法 | 预期 | 层次 | 来源 |
|---|---|---|---|---|---|---|---|
| ~~`TC-VIEW-374`~~ | `VIEW-006` | **显式** | 两个夹具包，`spaceId = python`，只展开 `python` | 构树 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：空间行 2 行（所有空间并列）；域行只出 `python` 的（`go` 收着）⇒ `go` 只剩空间行自己 | Unit | — |
| `TC-VIEW-375` | `VIEW-021` | **显式** | 同上，两个空间都展开，`visibleIds = {python/a}` | 构树 | 当前根只剩筛中的那一项，**另一个空间的项照出** | Unit | 同上 · `筛选只作用于当前根（SPEC-VIEW-021）：别的空间的项不被当前空间的筛选藏掉` |
| ~~`TC-VIEW-376`~~ | `VIEW-006` / `C-91` | **显式** | α 包，空间与域全展开 | 取 `知识` / 空间 / 域 / `φ=0` 项四行的名字区左边界 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：四层深度 0/1/2/3；`rowIndentOf` 依次 0 / 14 / 28 / 42；相邻两层左边界差恒为 **14 px** | Widget | — |
| `TC-VIEW-377` | `VIEW-006` / `C-92` | **显式** | 三项链夹具（φ=0/1/2）+ 一个 `φ = C-92 + 10` 的合成行 | `rowIndentOf` | φ 每升一级多 14 px；超过 `C-92` 之后**不再变深** | Widget | 同上 · `项内按 φ 缩进，封顶 C-92 级（SPEC-VIEW-006 修订第 5 条）` |
| `TC-VIEW-378` | `VIEW-006` | **显式** | α 包 | 找 `知识` 行的箭头 key；点它的名字 | **没有**箭头；点名字不抛异常、不触发任何回调 —— 树里没有「比知识更外」的地方 | Widget | 同上 · `` `知识` 没有折叠箭头，点它也没有回调（SPEC-VIEW-006 修订第 3 条） `` |
| `TC-VIEW-379` | `VIEW-006` | **显式** | α 包 | 点第一个域的**名字** | 回调域名 + 它所属的空间；**不**触发选中项 —— 选中域不是选中一项 | Widget | 同上 · `点域名 ⇒ 回传域名与它所属的空间，且不选中任何项（SPEC-VIEW-006 修订）` |
| `TC-VIEW-380` | `VIEW-006` | **显式** | α 包 | 点空间行的**名字** | 回调换根；**域行照样在**（名字不等于折叠） | Widget | 同上 · `点空间名 ⇒ 换根回调，且不折叠那一行（SPEC-VIEW-006 修订第 2 条）` |
| `TC-VIEW-381` | `VIEW-006` | **显式** | α 包，`selectedDomainId = 第一个域` | 比两行域名的字色 | 选中域与未选中域**字色不同** —— 选中域不开抽屉，选上了只能在行上看见 | Widget | 同上 · `选中域与未选中域的视觉可区分（SPEC-VIEW-006 修订第 3 条）` |
| ~~`TC-VIEW-382`~~ | `VIEW-006` / `VIEW-009` | **显式** | 小夹具 + `go` 包，树模式，`go` 起先收着 | 点 `go` 空间名 → 切回宇宙 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：树**还在**；面包屑第 2 段换成 `Go`；`go` 的域行出现（新根自动展开）；切宇宙落 **`Z1`**（2 段） | Widget | — |
| `TC-VIEW-383` | `VIEW-006` / `VIEW-009` | **显式** | α 包，树模式 | 先点一项（右栏开）→ 再点域名 → 切回宇宙 | 右栏**关**（选中域不是选中一项）；面包屑 3 段且第 3 段是该域；切宇宙落 **`Z2`**（3 段） | Widget | 同上 · `树里选中域 ⇒ 落 Z2 且 domainId 是该域，抽屉不开（SPEC-VIEW-006 修订第 3 / 4 条）` |

### 3.43 `B4` 第 1 笔 · `userId` 进信封（3 条 · 2026-10-19 提出）

> `SDP` §4.2 有一条明文：「**`userId` 不是 `B10` 的内容**……落地时**随 `B4` 第一笔一起做**」——
> 因为 `B4` 一开工就写事件，而 `B10` 要等到账号体系落地。若拖到 `B10`，`B4`–`B6` 期间
> 写下的全部事件都要迁移。所以本笔是 `B4` 的**第 1 笔**，不是 `B10` 的提前。
>
> ⚠️ **规格早已就位，落后的是实现**：`event-types.md` §一 的公共信封里 `userId` 一直在
> （`ACC-013` 定的），`ACC-014` 也写明「`fold` 必须支持 `userId` 过滤」。代码里 `Event`
> 没有这个字段、`fold` 没有这个维度 —— 与 `V-1h` 同一种形态：文档先到，实现没跟上。
>
> ⚠️ **取恒定默认值而非空串**（`C-93`）：`null` 会让「这条属于谁」多出第三态，之后每处
> 读取都得特判。`B10` 登录后由真实账号取代，**既有事件不批量改写**，认领靠新增
> `identity_adopted`（`ACC-014`）。
>
> ⚠️ **信封双向未被单独断言的说明**：既有用例 `itemId 可为空` 里做过
> `Event.fromJson(e.toJson())` 往返，而 `fromJson` 的 `userId` 是**必填** ——
> `toJson` 漏写会当场抛，所以这一维有隐式覆盖。不为它单编一条用例：一条只会
> 「照着实现写一遍」的断言不提供信息。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-ACC-001` | `ACC-014` | **显式** | 同一空间两条 `item_passed`，`userId` 分别为 `u-a` / `u-b` | `fold(events, userId: 'u-a')` 与 `userId: 'u-b'` 各折一次 | `u-a` 只看到自己那项；`u-b` 同理 —— **互不污染** | Unit | `app/test/core/events/fold_test.dart` · `同一设备两个账号的进度互不污染（SPEC-ACC-014）` |
| `TC-ACC-002` | `ACC-014` | **显式** | 同上两条 | `fold(events)`，**不传** `userId` | 两项都在 —— 迁移与导出要的是「存在过」，不是「谁的进度」 | Unit | 同上 · `不传 userId 即全量折 —— 迁移与导出要的是「存在过」（SPEC-ACC-014）` |
| `TC-ACC-003` | `ACC-014` | **显式** | 三条：`(python, u-a)` · `(english, u-a)` · `(python, u-b)` | `fold(events, spaceId: 'python', userId: 'u-a')` | 只剩 `(python, u-a)` 那项 —— **两级过滤是 AND，不是覆盖** | Unit | 同上 · `userId 与 spaceId 同时给出时两级都生效（SPEC-ACC-014）` |

### 3.44 `B4` 第 2 笔 · 三段候选装载与双向收窄（17 条 · 2026-10-19 提出）

> 本笔把 `SPEC-PLAN-006` 的「三处出处」落成**合并机制**（三段同一条路径、优先级
> `user > pack > platform`），并按实证修订 `SPEC-PLAN-014` 的依赖方向。
>
> ⚠️ **为什么改依赖方向**：`PLAN-014` 原写「源决定体系候选（圈外不得进候选）」。
> α 包实测：`scheme-first-week`（45 节点）里 `pep-484` 与 `python-asyncio-docs`
> 覆盖 **0** —— 按「源先定」走，用户选 `pep-484` 之后两套体系被**全部排除**，
> 流程当场死路。改双向后是同一张覆盖矩阵两个入口：给 `schemeId` 收窄源，给
> `sourceId` 收窄体系。
>
> ⚠️ **三处出处是机制对称，不是数据齐备**：源无平台内置档（平台档无法覆盖任何
> 具体体系）；体系无平台档（`⪯` 原序的「原序」指哪个拓扑序尚未裁定）；方法的
> pack 档为**空**（`PACK` 五段无 `methods`，`SPEC-PACK-006` 明文「第三次扩 schema
> 应暂停」）。合并器只有一条，数据各有缺口 —— 缺口与触发条件记在 `PLAN-006` 注记。
>
> ⚠️ **「一套方法」需要一层组合**：`PLAN-010` 要求按 `Item.type` 派生，而
> `MethodProfile` 一个 id 只装一份步骤表。新增 `MethodBundle`（`ItemType` →
> `MethodProfile.id`），`Plan.methodProfileId` 仍存**单个字符串**（存组合 id），
> `event-types.md` 的 payload 一字未改 —— 事件已开始写盘，改字段是不可逆的迁移面。
>
> ⚠️ **`appliesTo.sixAxis` 已移除**（`B13a` 笔 5b，随 `ADR-0005`）：六轴降为「三条
> 容器轴 + 四类标签」之后，项身上不再有「每轴单值」，原先那条软约束（项未标注该轴
> 则不据此否决）在新本体里**恒真** —— 留着就是留一个永远返回 `true` 的分支。现在它
> 落在「未认的键」这条判据上：传了就抛，不静默放过。内容侧 10 条摘录的该键一并摘除。
>
> ⚠️ **笔 5c-1 把匹配器整体挪到新本体**：键集 `{spaceId, type, layer}` →
> **`{type, axes, layer}`**（`spaceId` 与 `sixAxis` 同待遇：传了就抛），入参从
> `Item` + `KnowledgeSpace` 改成 `Node`。⚠️ **`appliesTo` 有两个形状**，别混：源的
> `{axes[], node_scope[]}`（两键必填，解析层强制）与方法的 `{type, axes, layer}`
> （三键均可省，省 = 声明过的不限）。本节五条只守方法那一侧。⚠️ 用例从
> `candidates_test.dart` 拆到 `app/test/core/plan/applies_to_test.dart`，改吃节点夹具
> 而非 α 包 —— 借旧实体搭桥会把 5c 待删的东西变成依赖。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-PLAN-002` | `PLAN-006` | **显式** | 4 项（四类各一）+ 2 套体系 + 3 条源（其中 1 条 `spaceId = java`） | `loadCandidates(pack)`，不给体系与源 | 源候选 2 条（另一空间的被挡）；每条的 `total` = 4、`covered` = 1 | Unit | `app/test/core/plan/candidates_test.dart` · `不给体系与源时，源候选是空间内全部、覆盖按全空间项数算（SPEC-PLAN-006）` |
| `TC-PLAN-003` | `PLAN-014` | **显式** | 同上 | `loadCandidates(pack, schemeId: 'scheme-dec-only')`（该体系只含 1 项） | 源只剩覆盖那 1 项的那条；覆盖 0 的**不进候选** | Unit | 同上 · `给出体系即按覆盖收窄源，覆盖为 0 的不进候选（SPEC-PLAN-014）` |
| `TC-PLAN-004` | `PLAN-014` | **显式** | 同上 | `loadCandidates(pack, sourceId: 'src-b')` | 体系只剩被该源覆盖的那套，`covered` = 1 / `total` = 4 | Unit | 同上 · `给出源即按覆盖收窄体系，两张表都进来源时只剩交集（SPEC-PLAN-014）` |
| `TC-PLAN-005` | `PLAN-014` | **语义** | 同上 | 同时给 `schemeId: 'scheme-dec-only'` 与 `sourceId: 'src-b'`（两者互不覆盖） | 两侧列表都不再含已选值 —— 这就是 `P-4` 要标「与当前源无交集，需重选」的可观测形态 | Unit | 同上 · `两段同时给出且互相无覆盖时，已选值从候选里消失（SPEC-PLAN-014）` |
| `TC-PLAN-006` | `PLAN-006` | **显式** | 同 id 的源在 pack 与 user 两份里各有一条 | `loadCandidates(pack, userSources: [同 id 自建版])` | 名字、`origin`、**等级**三者都取 user 那份（覆盖的是整条记录）；同 id 只出现一次。⚠️ `v0.44.0` 起断言的**是这一点，不再是位置** —— 排序介入后位置不可观测 | Unit | 同上 · `同 id 三源并存时 user 覆盖 pack 的**整条**记录（SPEC-PLAN-006）` |
| `TC-PLAN-007` | `PLAN-006` | **语义** | 一条源声明 `spaceId = java` | `loadCandidates(pack)` | 该源不进候选 —— 客户端不显示别的空间的材料 | Unit | 同上 · `别的空间的源不进候选（SPEC-PLAN-006）` |
| `TC-PLAN-008` | — | — | 同上 | `loadCandidates(pack, schemeId: 'scheme-nope')` | 抛 `ArgumentError`，**不返回空列表** —— 「零覆盖」与「拿错 id」必须能分开 | Unit | 同上 · `不存在的体系 id 抛错，不返回空列表（无 SPEC：\`PLAN\` 未定此契约，静默空表会被读成「零覆盖」）` |
| `TC-PLAN-009` | `PLAN-006` | **显式** | 同上 | `loadCandidates(pack).methods` | 三套平台组合，`origin` 均为 `platform` | Unit | 同上 · `方法候选只有三套平台组合，出处均为 platform（SPEC-PLAN-006）` |
| `TC-PLAN-010` | `PLAN-008` | **语义** | 同上 | 遍历 `PlanSegment.values` 取 `of(segment)` | 三段都非空，且每个候选都能读到 `id` / `name` —— 卡片形态三段一致的前提 | Unit | 同上 · `三段的候选都实现同一个读法，卡片才能统一（SPEC-PLAN-008）` |
| `TC-PLAN-011` | `PLAN-010` | **显式** | 五份内置分支 + 三套组合 | 逐组合逐类型：取该类型的项，用分支的 `appliesTo` 与它比对 | 分支 id 都在册，且每个分支的 `appliesTo` 确实覆盖所映射的类型 —— 不覆盖就是「选了一套方法，某类项无路可走」 | Unit | 同上 · `每套组合的每个类型分支都在分支册内，且该分支的 appliesTo 覆盖该类型（SPEC-PLAN-010）` |
| `TC-PLAN-012` | `STEP-027` | **显式** | 五份内置分支 | 逐个读 `hasReviewStep` | 全为真 —— 否则静默绕过了遗忘曲线 | Unit | 同上 · `五份分支都至少有一个 review 步骤（SPEC-STEP-027）` |
| `TC-PLAN-013` | `PLAN-010` | **显式** | `理解优先` 组合 | `profileIdFor` 取三类 | `declarative → 费曼` · `procedural → 刻意练习` · `skill → 跟读模仿` —— 正是 `PLAN-010` 原文举的三例 | Unit | 同上 · `理解优先的分支映射就是 PLAN-010 举的那三例（SPEC-PLAN-010）` |
| `TC-PLAN-014` | `PLAN-020` | **显式** | 节点夹具：可学（角色轴 / 陈述 / 持久）与结构（学科轴 / `group`）各一 | 空 `appliesTo` · 只写 `type` · 写 `type: []` · 结构节点写 `type` / `layer` / `axes`，各比对一次 | 空恒真；`type` 相符才通过；**空数组恒不命中**（`type: []` 是「任何类型都不适用」，不是「不限」）；结构节点上声明 `type` / `layer` **不命中**（那两项只对可学节点有意义，不是缺字段）；只声明 `axes` 时结构节点照常参与 | Unit | `app/test/core/plan/applies_to_test.dart` · `未给的键不构成限制，给了的键逐项相符才通过（SPEC-PLAN-020）` |
| `TC-PLAN-015` | `PLAN-020` | **显式** | 同上 | `type` 写成数组 | 任一命中即通过；全不命中则不适用 | Unit | 同上 · `数组取任一命中，单值需相符（SPEC-PLAN-020）` |
| `TC-PLAN-016` | `PLAN-020` | **语义** | 同一套夹具，改传 `appliesTo.sixAxis` 与 `appliesTo.spaceId` | `appliesToNode(...)` 收到含这两个键的 map | 两者均抛 `FormatException`（未认的键）—— `sixAxis` 随 `ADR-0005` 移除、`spaceId` 随「一空间一包已废」失效，**抛错而非静默忽略**：静默放过会让作者以为约束还在生效 | Unit | 同上 · `六轴与空间两个键都已不再被接受：传了就抛，不静默忽略（SPEC-PLAN-020 修订，笔 5c-1）` |
| `TC-PLAN-017` | `PLAN-020` | **显式** | 节点夹具：角色轴可学节点 · 学科轴结构节点 | `appliesTo.axes` 分别写 `occupation` / `major` / `["discipline", "occupation"]` / `discipline` / `occupation` | 轴相符才适用，不符即不适用 —— `axes` 是 `spaceId` 的对家：一空间一包废掉后，「适用哪条轴」才是作者与用户都说得出口的那一句（`ADR-0005`）；四条轴不管「可学与否」，故结构节点按轴照常命中 | Unit | 同上 · `axes 与节点轴相符才适用，轴不符即不适用（ADR-0005）` |
| `TC-PLAN-018` | — | — | 节点夹具 | `appliesTo` 写 `{relevance: high}`；另一次写 `{'type': [1]}` | 均抛 `FormatException`，**不静默忽略** —— 认错键与写错形状都必须当场报，不能与「匹配不上」压成同一个 `false` | Unit | 同上 · `未认的键与写错的形状都在比较之前就报，不静默忽略（无 SPEC：entity-fields 未列可用键，本笔补在附注里）` |

### 3.45 `B4` 第 3 笔 · 排序键与逆序代价（13 条 · 2026-10-19 提出）

> 本笔把 `SPEC-PLAN-020` 的三张排序键落成代码，并把 `PLAN-012` / `PLAN-013` /
> `PLAN-021` 的「代价可见」变成可断言的东西。
>
> ⚠️ **三段各用各的键，不是实现偷懒**：方法**没有权威谱系**（`PLAN-009`），强给
> L 级就是编的；体系的好坏是「代价小」，不是「谁说的」；源的好坏恰恰是「谁说的」。
> 统一成一个键，只能靠把其中两种硬塞进第三种的口径里。
>
> ⚠️ **逆序数数的是「前提边」，不是「项对」**：`PLAN-012` 与 `entity-fields` §10
> 的措辞都是「倒置了多少条前提边」。整段倒过来时，`a ⪯ b ⪯ c` 的 `[c, b, a]`
> 是 **2** 处逆序，不是 3 对 —— 后者会把「一处倒置」数成「一处半」。**两端不在
> 序列里的边不计**：那不是倒置，是那条前置不在这份计划的范围里，与
> `kahnLevels`「端点缺失即忽略这条边」同一判据。
>
> ⚠️ **方法覆盖率的分母是「本集合里出现的类型数」，不是恒 4**：α 包 `python`
> 空间若一个 `tacit` 项都没有，用 4 作分母等于给每套方法凭空扣掉四分之一 ——
> 那个分数不反映任何事实，只反映分母写死了。
>
> ⚠️ **未知等级排最后，不抛错**：与 `appliesTo` 的「未认键抛错」不是同一情形 ——
> 那里认错键会让约束静默失效（假通过），这里只是一个值不在册。Planner 得照常
> 渲染，**排最后也不等于删掉**；排最后而不是最前，是因为不认识的等级不配被推荐
> 到第一位。
>
> ⚠️ **排序只重排**（`PLAN-013`）：逆序多的体系沉到末尾，但仍在列表里。若为
> 「列表干净」把它折叠、置灰或截断，就等于把 `PLAN-012` 的「不禁止」改成了硬禁。
>
> ⚠️ **本笔改了一条既有用例的断言**：`TC-PLAN-006` 原写「位置留在首次出现处」，
> 排序介入后列表位置不再可观测（同 id 自建版声明 `L4`，会被排到 `L1` 之后）。
> 改为断言「**整条**记录被覆盖」—— 名字、`origin`、**等级**三者都取 user 那份。
> 这比原断言更强：原先只测了 id 去重与位置，测不出「只换了名字、等级没跟着换」。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-PLAN-019` | `PLAN-020` | **显式** | `⪯` 链 `i-a ⪯ i-b ⪯ i-c` + 游离 `i-d`；五条源取 `L0` / `L1` / `L2` / `L3` / `L4` | `loadCandidates(pack).sources` | `L0 → L1 → L2 → L4 → L3`。秩表就是四项 `L0 L1 L2 L4` —— 按字母序排会「碰巧对」，用例把秩表本身也断言住 | Unit | `app/test/core/plan/ordering_test.dart` · `TC-PLAN-019 官方 → 标准 → 教材 → 手册 → 社区依次靠前，不是字母序（SPEC-PLAN-020）` |
| `TC-PLAN-020` | — | — | 同上，其中一条源声明 `L3`（不在取值域内） | 同上 | 该源**排在最后**、`authorityRank('L3') == 4`，且**仍在列表里**（5 条进、5 条出） | Unit | 同上 · `TC-PLAN-020 无等级排最后：不抛错、也不被删（无 SPEC：五档未覆盖「不标」这一情形）` |
| `TC-PLAN-021` | — | — | 包内一条 `L4` + 两条同 id 周期的自建 `L4` | `loadCandidates(pack, userSources: [两条 L4])` | 三条 `L4` 的相对顺序 = 输入顺序（`stableSorted` 用原索引做末位比较键；`List.sort` 不稳定，直接用会打乱） | Unit | 同上 · `TC-PLAN-021 同一等级并列时保持包声明顺序（无 SPEC：\`PLAN-020\` 只给键，并列的回落本笔补）` |
| `TC-PLAN-022` | `PLAN-012` | **显式** | `scheme-linear` = `[i-a, i-b, i-c, i-d]` | `schemeOrderCost(scheme, edges, itemById)` | `inversions == 0`、`isLinearExtension` 为真、`firstBlockedStep` 为 `null`、显示「本序无逆序」 | Unit | 同上 · `TC-PLAN-022 线性扩展 ⇒ 0 处逆序，显示「本序无逆序」（SPEC-PLAN-012）` |
| `TC-PLAN-023` | `PLAN-012` | **显式** | `scheme-reversed` = `[i-c, i-b, i-a]` | 同上 | `inversions == 2`（两条边各被倒置一次，**不是 3 对**）；`firstBlockedStep == 1`、`firstBlockedItemName == 'C 装饰器'`；显示「本序 2 处逆序，第 1 步会卡在 C 装饰器」 | Unit | 同上 · `TC-PLAN-023 整段倒过来 ⇒ 2 处逆序，第 1 步卡住（SPEC-PLAN-012）` |
| `TC-PLAN-024` | `PLAN-012` | **显式** | `scheme-swapped` = `[i-a, i-c, i-b]`（只换一对位置） | 同上 | `inversions == 1`；`firstBlockedStep == 2` —— 取**最早**卡住的那一步，不是最后一条倒置边 | Unit | 同上 · `TC-PLAN-024 只换一对位置 ⇒ 1 处逆序，第 2 步卡住（SPEC-PLAN-012）` |
| `TC-PLAN-025` | — | — | `scheme-dec-only` = `[i-a]`，但它的一条出边指向序列外的 `i-b` | 同上 | `inversions == 0`、显示「本序无逆序」—— 一端不在序列里的边**不算逆序** | Unit | 同上 · `TC-PLAN-025 一端不在序列里的边不算逆序（无 SPEC：只数两端都在序列里的边）` |
| `TC-PLAN-026` | `PLAN-013` | **语义** | 四套体系：0 / 0 / 1 / 2 处逆序 | `loadCandidates(pack).schemes` | 顺序 `linear, dec-only, swapped, reversed`（两套 0 处的保持声明序）；**四套全在**，最后的仍是「工程路线」 | Unit | 同上 · `TC-PLAN-026 体系按逆序数升序，且逆序多的仍在列表里（SPEC-PLAN-013）` |
| `TC-PLAN-027` | — | — | 集合只含一项 `declarative` | 全类型组合的 `methodTypeCoverage` | `total == 1`（不是 4）、显示「覆盖 1/1 类」 | Unit | 同上 · `TC-PLAN-027 分母是本集合里出现的类型数，不是恒 4（无 SPEC：分母本笔补）` |
| `TC-PLAN-028` | `PLAN-013` | **语义** | 三套平台组合（各覆盖 4/4）+ 一条只覆盖 `declarative` 的自建 | `loadCandidates(pack, userMethodBundles: [只会陈述项])` | 覆盖率高者靠前；`m-thin` 排最后但**仍在列表**（4 条进、4 条出） | Unit | 同上 · `TC-PLAN-028 覆盖率高者靠前，覆盖少的仍在列表里（SPEC-PLAN-013）` |
| `TC-PLAN-029` | `PLAN-020` | **显式** | 集合含 `declarative` + `skill` 两项 | 只覆盖 `declarative` 的 `methodTypeCoverage` | `total == 2`、`covered == {declarative}`、`ratio == 0.5` —— 未覆盖的类型不进分子但进分母 | Unit | 同上 · `TC-PLAN-029 未覆盖的类型不计入分子，但计入分母（SPEC-PLAN-020）` |
| `TC-PLAN-030` | `PLAN-021` | **显式** | 同 §3.44 的夹具 | 读三段首条的 `reason` | `出处等级 L0` / `本序无逆序` / `覆盖 4/4 类` —— 「为何推荐」就是排序键本身（`PLAN-021` 只做 A 级，不做一键生成） | Unit | 同上 · `TC-PLAN-030 三段每张卡都给出「为何推荐」，且内容即排序键（SPEC-PLAN-021）` |
| `TC-PLAN-031` | — | — | 包内 `L2` 一条 + 自建 `L1` 一条 | `loadCandidates(pack, userSources: [L1 自建])` | 自建 `L1` 排在包内 `L2` **之前**，且它的 `origin` 仍是 `user` —— 排序键不看出处；把「用户自建」当降权，排序键就变成两个了 | Unit | 同上 · `TC-PLAN-031 排序键不看出处：自建 standard 仍排在包内 textbook 之前（无 SPEC：出处不参与排序键本笔补）` |

### 3.46 `B4` 前置 · 交付物一致性检查器（25 条 · 2026-10-19 提出；`v0.44.0` 补 4 条 · `v0.52.0` 补 5 条 · `v0.55.0` 补 2 条 · `v0.63.0` 补 3 条）

> 这一节验的不是产品，是**检查器自己**。`tool/docs/check.dart` 的五条规则（`D1`–`D5`）
> 是把「四份交付物之间同一个读数必须相等」这件事变成可执行的东西；规则自己写错了会
> **静默失效** —— 工具跑绿、人以为文档自洽、实际什么都没查。所以它也要有断言锁住。
>
> ⚠️ **两处真 bug 都是先写出来、跑出「红数看着不对」才发现的**，不是用例抓的：
> `D1` 在转义反引号处截断测试名（假红 5 条）、`D4` 把合计行重复计入累加（120 而非 60）。
> 补上本节 15 条之后，同样的错会当场定位到行。
>
> ⚠️ **`TC-DOC-005` 的夹具必须是倒序**：一开始写成「`v0.2.0` 在前、`v0.3.0` 在后」，
> 那么「取最后一行」与「取语义最大」结果相同，两种实现都绿 —— 反证时才发现。
> 这与 `TC-PLAN-022`–`026` 要造三套不同逆序数的体系是同一个道理：**用例形状**比条数
> 更能决定能不能验出事。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-DOC-001` | — | — | 内存夹具：四份自洽的迷你文档 + 2 份测试 | `checkAll` 全跑 | 零违规 —— 每个用例只改其中一处，所以红线唯一 | Unit | `app/test/tool/docs_rules_test.dart` · `自洽的四件套应当零违规（无 SPEC：检查器自身的基线，设计规格里尚无对应条目）` |
| `TC-DOC-002` | — | — | 落点写成 `app/test/missing_test.dart` | `checkAll` | `D1` 报 1 处，行号指向用例表首行 | Unit | `app/test/tool/docs_rules_test.dart` · `落点写的文件不存在就报（无 SPEC：检查器规则，设计规格里尚无对应条目）` |
| `TC-DOC-003` | — | — | 落点只写 `a_test.dart`，`test/` 下两份同名 | `checkAll` | `D1` 报「2 份同名」—— 裸文件名无法定位落点 | Unit | `app/test/tool/docs_rules_test.dart` · `落点只写文件名且有两份同名时报二义（无 SPEC：检查器规则）` |
| `TC-DOC-004` | — | — | 落点写 `TC-FND-001 甲（无 SPEC：…）`，测试文件里没有这一条 | `checkAll` | `D1` 报 1 处；**摘要式名字（`甲`）对不上不报** | Unit | `app/test/tool/docs_rules_test.dart` · `带编号的测试名必须逐字存在，摘要式不校验（无 SPEC：检查器规则）` |
| `TC-DOC-005` | — | — | 修订历史**倒序**（`v0.3.0` 在前、`v0.2.0` 在后），头部 `v0.3.0` | `checkAll` | `D2` 零违规 —— 取语义最大而非最后一行；顺带证明检查不依赖行的位置 | Unit | `app/test/tool/docs_rules_test.dart` · `头部版号取修订历史的语义最大，不依赖行的位置（无 SPEC：检查器规则）` |
| `TC-DOC-006` | — | — | 头部改成 `v0.9.0`，修订历史仍 `v0.1.0` | `checkAll` | `D2` 报 2 处：头部 vs 修订历史 1 处、`SCMP` §5.1 登记 1 处 | Unit | `app/test/tool/docs_rules_test.dart` · `头部与修订历史最大版号不符就报（无 SPEC：检查器规则）` |
| `TC-DOC-007` | — | — | `SCMP` §5.1 把 `STD` 登记成 `v0.0.9` | `checkAll` | `D2` 报 1 处，指出两侧各是什么 | Unit | `app/test/tool/docs_rules_test.dart` · `SCMP §5.1 登记的版号必须等于对方头部（无 SPEC：检查器规则）` |
| `TC-DOC-008` | — | — | `STD` 头部声明 3 条，用例表实扫 2 条 | `checkAll` | `D3` 报 1 处 —— `STP` 合计仍是 2，不连带报 | Unit | `app/test/tool/docs_rules_test.dart` · `STD 头部声明的条数必须等于用例表实扫（无 SPEC：检查器规则）` |
| `TC-DOC-009` | — | — | `STP` 段落的编号列只写 `TC-FND-001`，合计仍 2 | `checkAll` | `D3` 报「分段展开 1 条、合计 2 条」，并点出缺 `TC-FND-002` | Unit | `app/test/tool/docs_rules_test.dart` · `STP 分段编号展开必须等于合计（无 SPEC：检查器规则）` |
| `TC-DOC-010` | — | — | §4.1「有用例」写 2，用例表只有一个 `SPEC` | `checkAll` | `D4` 报 3 处：总量行、按域列加总、无用例的算式 | Unit | `app/test/tool/docs_rules_test.dart` · `有用例数必须等于用例表里出现过的 SPEC 去重数（无 SPEC：检查器规则）` |
| `TC-DOC-011` | — | — | 按域表 `FND` 行写「2 / 2 / 0」，实扫 1 条 | `checkAll` | `D4` 报「按域表 `FND` 写有用例 2 条」 | Unit | `app/test/tool/docs_rules_test.dart` · `按域表每一行的有用例数也要对得上（无 SPEC：检查器规则）` |
| `TC-DOC-012` | — | — | 夹具的 `STD` §六 已有一处合法读数，另在**头部状态行**注射一处读数（`flutter test` 后紧跟加粗的 2，正是本规则要拦的形态） | `checkAll` | `D5` 报 **1 处 error**「读数出现在「当前读数」节之外」—— 判据不是「头部不许写」，而是**节外任何位置都不许写**；头部只是最容易写错的那一处 | Unit | `app/test/tool/docs_rules_test.dart` · `头部再写 flutter test 读数就报重复登记（无 SPEC：检查器规则）` |
| `TC-DOC-013` | — | — | 把 `STD` 的 `## 六、当前读数` 节名改成 `## 六、其它` —— 节还在、内容还在，**锚点没了** | `checkAll` | `D5` 报 **1 处警告**「找不到「## 当前读数」节」—— 与 `S7-1` 剥版号那次同型的故障：判据还在、落点没了，规则会静默通过；宁可报「找不到节」也不许它静默 | Unit | `app/test/tool/docs_rules_test.dart` · `找不到当前读数节就警告，并说清为什么这一节不能缺（无 SPEC：检查器规则）` |
| `TC-DOC-014` | — | — | 「当前读数」节里的读数行改成 `flutter test` / `待跑`（节在、格式在、**没有数**） | `checkAll` | `D5` 报 **1 处警告**（`isWarning`）「节里没有 `flutter test` 读数」—— **空节比没有节更坏**（它让人以为登记过），故措辞必须与 `013` 不同，否则读到警告的人不知道该补节还是补数 | Unit | `app/test/tool/docs_rules_test.dart` · `当前读数节空着也只警告，不阻断（无 SPEC：检查器规则）` |
| `TC-DOC-015` | — | — | `STD` 头部写「`flutter test` **4 → 2**」（箭头形态的变化叙述） | `checkAll` | `D5` **零报** —— 箭头不是读数声明。防误报：正则一旦放宽成「后面第一个数字」，每份修订摘要都会变红 | Unit | `app/test/tool/docs_rules_test.dart` · `箭头形态的变化叙述不判成读数（无 SPEC：检查器规则）` |
| `TC-DOC-016` | — | — | `docs/a/note.md` 里链接同目录文件、上跳到另一目录、带锚点的文件、以及本文档锚点 | `checkAll` | `D6` 零报 —— **目录**（`docs/reference`）与文件同等对待，指向目录不算坏链 | Unit | `app/test/tool/docs_rules_test.dart` · `指向存在的文件或目录都不报（无 SPEC：检查器规则）` |
| `TC-DOC-017` | — | — | 链接目标 `missing.md` 不存在 | `checkAll` | `D6` 报 1 处，消息同时给出原文与**解析后路径**（`docs/a/missing.md`）—— 只说原文无法区分「写错」与「判错」 | Unit | `app/test/tool/docs_rules_test.dart` · `指向不存在的文件就报，并把解析后的路径写进消息（无 SPEC：检查器规则）` |
| `TC-DOC-018` | — | — | 从 `docs/a/note.md` 写 `../target.md`（少一层上跳 —— 本仓真实事故的形态） | `checkAll` | `D6` 报 1 处并指出解析为 `docs/target.md` —— 若实现少退一层会得 `docs/a/target.md`、那里存在，就验不出这条 | Unit | `app/test/tool/docs_rules_test.dart` · `少一层上跳会解析到错误目录（本仓真实踩过的形态，无 SPEC：检查器规则）` |
| `TC-DOC-019` | — | — | 链接写成 `../../../outside.md`，上跳越过仓库根 | `checkAll` | `D6` 报 1 处，措辞为「越过仓库根」，不与「文件不存在」混为一谈 | Unit | `app/test/tool/docs_rules_test.dart` · `上跳越过仓库根单独报，不与「文件不存在」混为一谈（无 SPEC：检查器规则）` |
| `TC-DOC-020` | — | — | 外链、`mailto:`、页内锚点、站内绝对路径、代码围栏内、行内代码里，各放一个**坏**目标 | `checkAll` | `D6` 零报 —— 五类过滤漏掉任何一类，本条即红。行内代码那类是实跑打出来的：`STP` / `SCMP` 正文里写 `` `[参考层](reference/)` `` 描述链接语法，首版实现把它当真链接、报 2 处假红 | Unit | `app/test/tool/docs_rules_test.dart` · `外链 / 锚点 / 站内绝对路径 / 围栏内 / 行内代码里的链接一律不校验（无 SPEC：检查器规则）` |

| `TC-DOC-021` | — | — | `SDD` 历史表写成升序（`v0.1.0` 在前、`v0.3.0` 在后），`SCMP` §5.1 同步登记 `v0.3.0` | `checkAll` | `D2` 报 1 处 —— 降序被破，行号指到倒挂那一行；**版号本身对得上**，所以只有这一处 | Unit | `app/test/tool/docs_rules_test.dart` · `TC-DOC-021 历史表必须按版号降序，倒挂就报（无 SPEC：检查器规则）` |
| `TC-DOC-022` | — | — | `SDD` 历史表同一版号 `v0.1.0` 出现两次 | `checkAll` | `D2` 报 1 处 —— **相等也报**：同版号两行等于同一版本记了两次，读者无从判断哪条是准的 | Unit | `app/test/tool/docs_rules_test.dart` · `TC-DOC-022 历史表同版号出现两次也报（无 SPEC：检查器规则）` |
| `TC-DOC-023` | — | — | `STD` 头部加一行「上一版：旧读数」 | `checkAll` | `D7` 报 1 处警告，消息指明「归文末历史表」—— **版号与读数都没错，错的只是位置** | Unit | `app/test/tool/docs_rules_test.dart` · `TC-DOC-023 头部出现「上一版」就报，提示指向文末历史表（无 SPEC：检查器规则）` |
| `TC-DOC-024` | — | — | `STD` 历史表某行写「此前 597 → **608**」（在第一个 `## ` 之后） | `checkAll` | `D7` **零报** —— 只扫头部；若实现改成全文件扫，六份历史表会整片误报 | Unit | `app/test/tool/docs_rules_test.dart` · `TC-DOC-024 历史表里的「此前」是叙述，不算堆叠（无 SPEC：检查器规则）` |
| `TC-DOC-025` | — | — | `SDD` 头部状态行写成 601 字 | `checkAll` | `D7` 报 1 处警告并带**实测字数** —— 只说「超了」无法判断该删多少 | Unit | `app/test/tool/docs_rules_test.dart` · `TC-DOC-025 头部状态行超过 600 字就报，并说出实测字数（无 SPEC：检查器规则）` |

### 3.47 `B4` 第 4 笔 · Planner 面板骨架（10 条 · 2026-10-19 提出）

> 这一节验的是 `P-4`：左栏四段（源 → 体系 → 方法 → 确认）+ 右栏三项预览，以及
> `SPEC-PLAN-014` 修订后的**双向收窄**与「需重选」这个显式态。
>
> ⚠️ **夹具必须「两种源各覆盖两项、两套体系一全一窄」**。造一套体系、两条源
> 全量覆盖，则「先选源不筛空」与「选体系后源会收窄」两条都恒真 —— 用例形状不对，
> 条数再多也验不出事。`TC-PLAN-037` 就是靠「`src-b` 对窄体系覆盖 0」才咬得住。
>
> ⚠️ **`TC-PLAN-038` 走的是重入预填，不是点选**。正常点选时，不相容的一端**已经
> 被筛出列表了**，用户点不到它 —— 「需重选」只可能出现在预填的旧值上
> （`SPEC-PLAN-019` 的重入）。这一点不写清楚，后来人照点选路径造不出红。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-PLAN-032` | `PLAN-015` | **显式** | 四项两型 + 一全一窄两套体系 | `computePlannerPreview` 给 / 不给 `schemeId` | 项数随体系变（4 / 2 / 4），**分母恒 4** —— 分母是圈内项数，不随覆盖度变 | Unit | `app/test/core/plan/preview_test.dart` · `项数随体系变，分母不变（SPEC-PLAN-015）` |
| `TC-PLAN-033` | `PLAN-015` | **显式** | 同型两项 × 两种类型各造一包 | 同一套组合（理解优先）分别算陈述包与程序包 | 陈述 2 项 = 18 分钟；程序包**不等于**陈述包 —— 先乘平均再乘项数会得同一值，这条专验「按类型派生」 | Unit | `app/test/core/plan/preview_test.dart` · `时长逐项按 Item.type 派生后累加（SPEC-PLAN-015）` |
| `TC-PLAN-034` | `PLAN-015` | **显式** | 不给 `bundle` | `computePlannerPreview` | `usingDefaultMethod` 为真且时长 > 0 —— 没选 ③ 也要给得出一版估算 | Unit | `app/test/core/plan/preview_test.dart` · `未选方法时按平台默认组合估，并标出来（SPEC-PLAN-015）` |
| `TC-PLAN-035` | `PLAN-010` | **语义** | 程序类两项 + 只含 `declarative` 分支的组合 | 同上 | `uncoveredItems == 2`、时长 **0** —— 不凭空空出时长；确认段据此拦住 | Unit | `app/test/core/plan/preview_test.dart` · `方法未覆盖的类型计进 uncoveredItems（SPEC-PLAN-010 口径）` |
| `TC-PLAN-036` | `PLAN-014` | **显式** | 面板满铺 1200×2600 | 读四段标题的 `topLeft.dy` | 源 < 体系 < 方法 < 确认。**用纵坐标而不是 `find` 顺序** —— 组件树顺序与视觉顺序可以不一致 | Widget | `app/test/features/planner/planner_panel_test.dart` · `四段按「源 → 体系 → 方法 → 确认」竖排（SPEC-PLAN-014）` |
| `TC-PLAN-037` | `PLAN-014` | **显式** | 同上 | 先点 `src-a`，再点窄体系 `sch-part` | 先选源时体系**非空**（单向依赖下会剩 0 条）；再选体系后源里不含覆盖 0 的 `src-b` | Widget | `app/test/features/planner/planner_panel_test.dart` · `先选源不筛空，选体系后源按覆盖收窄（SPEC-PLAN-014 修订）` |
| `TC-PLAN-038` | `PLAN-019` | **显式** | 预填 `src-b` + `sch-part`（两者覆盖 0） | 直接 pump | 源段出现「需重选」、确认按钮禁用 —— **不静默保留**「界面上选着、实际不存在」的组合 | Widget | `app/test/features/planner/planner_panel_test.dart` · `预填两端互不相容 ⇒ 被筛掉那段标「需重选」且拦住确认（SPEC-PLAN-019）` |
| `TC-PLAN-039` | `PLAN-015` | **显式** | 同上 | 读三项读数，再选窄体系重读 | 右栏恰好三项；选体系后项数 4 → 2，**分母仍 4** | Widget | `app/test/features/planner/planner_panel_test.dart` · `右栏只有三项读数，分母不随体系变（SPEC-PLAN-015）` |
| `TC-PLAN-040` | `PLAN-014` | **显式** | 全新打开 | 读确认按钮 | `onPressed` 为 `null` 且给出「三段选齐才能建计划」 | Widget | `app/test/features/planner/planner_panel_test.dart` · `三段没选齐时确认按钮禁用并说明原因（SPEC-PLAN-014 ④段）` |
| `TC-PLAN-041` | `PLAN-014` | **显式** | 同上 | 依次点源 / 体系 / 方法 | 按钮可用、无阻断行，且确认段列出三个名字 | Widget | `app/test/features/planner/planner_panel_test.dart` · `三段选齐后可建，且确认段列出三个名字（SPEC-PLAN-014）` |

### 3.48 `B4` 第 5 笔 · 预览的项数与 `target`（5 条 · 2026-10-19 提出）

> 这一节验 `P-5`。**探清后笔序表写的「三项预览」在 `P-4` 就已经落地** ——
> `computePlannerPreview` 早就算出三个读数，`TC-PLAN-032`–`035` / `039` 也在验。
> 真正缺的是两件：① `SPEC-PLAN-015` 只定义了**分母**，**项数**的定义只活在代码
> 注释里；② `PlanTarget` 实体早在 `entities/plan.dart`，预览却一直没接。
>
> ⚠️ **两条旧用例其实一直没咬住。** `TC-PLAN-032` 的夹具四项全在圈内，把
> `preview.dart` 里 `where((i) => i.inScope)` 删掉它照样绿 —— 「分母 = 圈内项数」
> 这半句从 `P-4` 起就是**写了没验**。`TC-PLAN-043` 补上这一刀，`TC-PLAN-042` 则
> 把规格验收表里那个 **140 分钟**第一次真正算出来（平台内置五套方法没有一套是
> 「读忆练讲」四步，必须自造 profile）。
>
> ⚠️ **`target` 收窄的是这一份计划，不是空间。** 分母跟着缩看起来很自然，但会让
> 「12 / 12」被读成「这个空间学完了」—— 空间其实还有 138 项。裁定见
> `SPEC-PLAN-015` 的 `P-5` 修订段。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-PLAN-042` | `PLAN-015` | **显式** | 10 项 + 自造的「读 / 忆 / 练 / 讲」四步 profile | `computePlannerPreview` | **140 分钟** —— 逐字对上规格验收表的 `(3+1+5+5) × 10` | Unit | `app/test/core/plan/preview_test.dart` · `十项四步估出规格写的 140 分钟（SPEC-PLAN-015 验收向量）` |
| `TC-PLAN-043` | `PLAN-015` | **显式** | 两项圈内 + 一项 `inScope: false`，且体系节点含那项圈外项 | 不给 / 给 `schemeId` 各算一次 | 分母 **2**；体系分支项数仍 **2**（不拦圈外项时会是 3 > 2，项数超过分母即自相矛盾） | Unit | `app/test/core/plan/preview_test.dart` · `圈外项既不计入分母，也不进项数（SPEC-PLAN-015）` |
| `TC-PLAN-044` | `PLAN-015` | **显式** | 四项 + 全量体系，`target` 圈 `i1` / `i3` | 给 / 不给 `target` 各算一次 | 项数 **2**、分母**两次相同**、时长变小 —— 时长跟项数走，不跟分母走 | Unit | `app/test/core/plan/preview_test.dart` · `target 收窄项数，分母不动（SPEC-PLAN-015）` |
| `TC-PLAN-045` | `PLAN-015` | **语义** | 窄体系 `sch-part`（`i1` `i2`）+ `target` 圈 `i1` `i3` `i4` | 同上 | 项数 **1** —— 体系不因 `target` 变宽，`target` 也不因体系变全 | Unit | `app/test/core/plan/preview_test.dart` · `target 与体系取交集，两边都不放宽（SPEC-PLAN-015）` |
| `TC-PLAN-046` | `PLAN-015` | **显式** | 面板 + `target` 圈两项 | 读右栏三项读数 | 「项数 2」·「分母 4」—— 面板确实把 `target` 传进了预览，不是只在函数层支持 | Widget | `app/test/features/planner/planner_panel_test.dart` · `面板把 target 接进预览：项数收窄、分母不动（SPEC-PLAN-015）` |

### 3.49 `B4` 第 6 笔 · 建 Plan 落事件与 `fold` 折出 `Plan`（15 条 · 2026-10-19 提出）

> 这一节验 `P-6`。三件事：事件构造（`plan_events.dart`）、草稿组装（`plan_draft.dart`）、
> 折叠（`fold.dart` 的 `plans`）。
>
> ⚠️ **本笔开工前发现 `PLAN-003` 在事件层根本表达不出来。** 表里 `plan_created` 的 payload
> 没有 `planId`，而同空间可并存多份 —— 没有这个字段，`fold` 分不清「这条 `plan_revised`
> 改的是哪一份」，「建两份 Plan，两份独立存在」这条验收向量**无处落地**。裁定：`Plan.id`
> **就是创建事件的 `id`**，`plan_revised` 带 `planId` 指回它（`event-types.md` §二 B）。
>
> ⚠️ **`version` 从 payload 里删掉了。** 原文写 `plan_revised` 带 `version = 前值 + 1`，
> 那是第二份计数：`fold` 既数事件条数、又读 payload，重传或乱序时必然打架。改由 `fold`
> 数该 `planId` 名下的事件条数（与 `noteVersion` 同一口径）。
>
> ⚠️ **`target` 的字段名原本三处不一致**：`event-types` 写 `resolvedCount`、`toJson()` 写
> `count`、实体里 `count` 是派生值。统一为 `{selector, resolved}`，`count` 派生且不序列化。
> 原文那条测试名写「不单独存」、断言却是 `containsPair('count', 3)`，**自己跟自己打架**，
> 本笔一并改成真在验。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-PLAN-047` | — | — | 一份 `PlanDraft` + 未发过号的 `HlcClock` | `buildPlanCreated` | type / spaceId（取信封）/ userId / itemId 为空；payload 五键齐；**不含** `spaceId` · `planId` · `version` —— 三个本可以写、但写了就是第二份真相的字段 | Unit | `app/test/core/plan/plan_events_test.dart` · `载荷齐全，且刻意不写 spaceId / planId / version（无 SPEC：event-types.md §二 B）` |
| `TC-PLAN-048` | — | — | 同一个 `HlcClock`，`now` 两次相同 | 连发 created + revised | 两个 `id` 不同；`hlc` 仍严格递增；`at` 相同（同一毫秒，先后归 `hlc`） | Unit | 同上 · `同毫秒连发两条：id 不撞，hlc 仍严格递增（无 SPEC：HLC 全序）` |
| `TC-PLAN-049` | — | — | 一次 `buildPlanRevised` | 读 payload | 带 `planId`；其余与创建同形；**仍不写** `version` | Unit | 同上 · `plan_revised 的 payload 带 planId，其余与创建同形（无 SPEC：PLAN-003 需区分同空间多份）` |
| `TC-PLAN-050` | `PLAN-015` | **显式** | 圈内 2 项 + 圈外 1 项，体系三项全包 | 同一个 `target` 分别喂 `composePlanDraft` 与 `computePlannerPreview` | `resolved` 长度 **等于** `preview.itemCount`；分母仍 2 —— 两处读数同源，不会一个 12 一个 120 | Unit | `app/test/core/plan/plan_draft_test.dart` · `resolved 与预览的项数同源（无 SPEC：PLAN-015 的项数就是这次要走的量）` |
| `TC-PLAN-051` | `PLAN-015` | **显式** | 同上，体系节点含 `py-out`（圈外） | 不给 `target` | `resolved == [py-a, py-b]`，不含 `py-out` | Unit | 同上 · `圈外项不进 resolved（SPEC-PLAN-015 圈外项不进计划）` |
| `TC-PLAN-052` | — | — | 同上 | 读 `sourcePolicy` | 只有 `primary` 一键；**没有** `byType` / `exceptions` —— 写两个空容器会被读成「已确认无例外」 | Unit | 同上 · `sourcePolicy 只落 primary，不写空的 byType / exceptions（无 SPEC：P-6 口径）` |
| `TC-PLAN-053` | — | — | 同上 | 读草稿四个身份字段 | `spaceId` / `spaceVersion` 取自包；`methodProfileId` 取 bundle 的 id | Unit | 同上 · `空间与包版本取自包本身，不另传（无 SPEC：entity-fields §8）` |
| `TC-PLAN-054` | — | — | 传一个带 `selector` 的 `target`，`resolved` 里混入不存在的项 | `composePlanDraft` | `selector` 原样保留；`resolved` 按当前包重算 —— 照抄旧值会把已下线的项写进新计划 | Unit | 同上 · `传了 target 就沿用它的 selector（无 SPEC：selector 结构归 PLAN-016）` |
| `TC-PLAN-055` | — | — | 一条 `plan_created` | `fold` | 折出**一份**，键 = 事件 id；六字段齐；`version == 1` | Unit | `app/test/core/events/fold_test.dart` · `plan_created 折出一份，版本从 1 起（无 SPEC：event-types.md §二 B）` |
| `TC-PLAN-056` | `PLAN-003` | **语义** | 同空间两条 `plan_created`，体系与 `target` 各不同 | `fold` | **两份独立存在**，`plansOf('python').length == 2`，两份 `version` 各自为 1 —— 键若用 `spaceId`，第二份会把第一份覆盖掉 | Unit | 同上 · `同空间两份计划独立存在（SPEC-PLAN-003 验收向量）` |
| `TC-PLAN-057` | `PLAN-019` | **语义** | 建计划 + 一次 `plan_revised`（换体系、换 `target`） | `fold` | `version == 2`；体系与 `resolved` 被新 payload 覆盖；`plans.length == 1` —— 重规划改的是同一份，不是新开一份 | Unit | 同上 · `plan_revised 版本 +1，且新 payload 覆盖旧值（SPEC-PLAN-019）` |
| `TC-PLAN-058` | `FND-014` | **显式** | 一条 `plan_revised`，`planId` 指向从未创建的计划 | `fold` | 抛 `FormatException` —— 不静默补建，否则回放会凭空多出一份「从没建过」的计划 | Unit | 同上 · `plan_revised 指向不存在的计划即抛错，不静默补建（SPEC-FND-014）` |
| `TC-PLAN-059` | — | — | 同一条 `plan_created` 传两次 | `fold` | 仍只有一份，`version` 仍为 1 —— 版本由重放条数得出，幂等必须成立 | Unit | 同上 · `同一条创建事件重传只算一次，版本不涨（无 SPEC：event-types.md §一 幂等）` |
| `TC-PLAN-060` | `FND-010` | **显式** | Python 一份 + German 一份 | `fold(spaceId: 'python')` | 只折出 Python 那份；`plansOf('german')` 为空 | Unit | 同上 · `spaceId 过滤：别空间的计划折不进来（SPEC-FND-010）` |
| `TC-PLAN-061` | `PLAN-019` | **语义** | 面板 + 一个 `resolved` 含 `ghost` 的 `target` | 三段选齐后点「建计划」 | 交出草稿：`schemeId` / `methodProfileId` / `sourcePolicy` 对；`selector` 原样；`resolved == [i1, i3]`（`ghost` 被重算掉） | Widget | `app/test/features/planner/planner_panel_test.dart` · `点「建计划」把草稿交出去，target 透传且 resolved 按当前包重算（SPEC-PLAN-019）` |

### 3.50 `B4` 第 7 笔 · 三入口与范围的选择式（17 条 · 2026-10-19 提出）

> 这一节验 `P-7`。三件事：选择式的四种 `kind` 与解算（`plan_target.dart`）、
> Planner 的全屏承载（`planner_screen.dart`）、两个入口的接线（`Z1` ③ 区 · 定位结果底部 CTA）。
>
> ⚠️ **本笔开工前探清，笔序表写的「三个入口」只有一个做得了。** 进展视图「新建计划」的宿主
> 全仓不存在（`ViewMode.progress` 在 `app/lib` 里零引用），它的规格是 `QUANT-011`、属 `B6`。
> **不给它挂空回调** —— 那会得到一个永远点不到的按钮，而「有入口」这件事在文档上会显得已做。
>
> ⚠️ **`PlanTarget.selector` 的字段级结构此前从没定过。** `entity-fields` §8 只写「存选择式不存
> 结果列表」，`P-6` 因此只能落空对象并明写「Z3/Z4 怎么表达归 P-7」。本笔把它定成四值判别式联合，
> 与 `PLAN-002`「粒度随视距」一一对应；`query` 存**词**不存 id 表，因为只存 id 会丢掉「按什么圈出来的」。
>
> ⚠️ **`PLAN-017` 只说了「不是什么」，没说「渲染在哪」。** 三个入口都要「打开它」，于是本笔补定
> 承载形态 = **一整页路由**（抽屉会撞上 ⑤⑥，模态放不下 iOS 三步分页）。
>
> ⚠️ **`EventStore` 全仓只有接口、零实现** —— 所以「建 Plan 跑通」到「交出草稿」为止，草稿由
> `UniverseScreen` 向上抛（`onPlanCreated`），持久化归后续批次。这条不假装做了。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| ~~`TC-PLAN-062`~~ | `PLAN-022` | **显式** | ~~4 项两域，其中 1 项 `inScope: false`~~ | — | **已作废**（`B13a` 笔 5c）：`ADR-0007` 决策 2 废除 `PlanSelector` / `PlanTarget`，范围只落 `Plan.subtreeRoot`，「space 式解算」不再有入口；范围语义改由 `resolvePlanScope(subtreeRoot)` 单一路径承载 | Unit | — |
| ~~`TC-PLAN-063`~~ | `PLAN-022` | **显式** | ~~同上~~ | — | **已作废**（`B13a` 笔 5c）：同上，「domain 式」随 `PlanSelector` 一并删除；单域即取该域容器作子树根 | Unit | — |
| ~~`TC-PLAN-064`~~ | `PLAN-022` | **显式** | ~~同上~~ | — | **已作废**（`B13a` 笔 5c）：同上，「item 式」由「把该项设为 `subtreeRoot`」表达 | Unit | — |
| ~~`TC-PLAN-065`~~ | `PLAN-016` | **显式** | ~~同上~~ | — | **已作废**（`B13a` 笔 5c）：同上，「query 式」归定位入口（`core/locate`），不再进计划范围解算 | Unit | — |
| ~~`TC-PLAN-066`~~ | `PLAN-022` | **显式** | ~~四个 `PlanSelector`~~ | — | **已作废**（`B13a` 笔 5c）：类本身删除，无 JSON 往返可测 | Unit | — |
| ~~`TC-PLAN-067`~~ | `PLAN-022` | **显式** | ~~同上~~ | — | **已作废**（`B13a` 笔 5c）：同上；`Plan.toJson` 现只落 `subtreeRoot`，`count` / `resolved` 均不落（新判据见 `entities_test` 的「范围只落 subtreeRoot」一条） | Unit | — |
| `TC-PLAN-068` | `PLAN-017` | **显式** | 两段可选的包 | 打开 Planner 整页 | 左栏与预览同在；标题带空间名；**下面那一页已被盖住**（不是抽屉、不是弹层） | Widget | `app/test/features/planner/planner_screen_test.dart` · `打开的是整页，左栏与预览同在（SPEC-PLAN-017）` |
| `TC-PLAN-069` | `PLAN-016` | **显式** | 同上 | 三段选齐 → 点「建计划」 | 草稿回到调用方；页面自己关掉；`spaceId` / `schemeId` / `sourcePolicy` 对 | Widget | 同上 · `建计划后草稿回到调用方，页面自己关掉（SPEC-PLAN-016）` |
| `TC-PLAN-070` | `PLAN-016` | **显式** | 同上 | 点返回 | 交回 `null` —— 取消不能悄悄造出一份三段都没选齐的计划 | Widget | 同上 · `返回按钮是取消：草稿为 null（SPEC-PLAN-016）` |
| ~~`TC-PLAN-071`~~ | `PLAN-016` | **显式** | α 包，`Z1` | 看 ③ 区 | **已作废**（`B13a` 笔 5a）：六轴渲染层随 `ADR-0005` 整层删除，被测行为与落点一并消失；重建归 `B17a`（容器树）/ `B17b`（3D）。原预期：有「开始学习」 | Widget | — |
| `TC-PLAN-072` | `PLAN-016` | **显式** | α 包，`Z0` | 同上 | **没有** —— 那一档画的是并列的几个空间，没有「当前空间」可规划 | Widget | 同上 · `Z0 不出现「开始学习」（SPEC-PLAN-016）` |
| `TC-PLAN-073` | `PLAN-016` | **显式** | α 包，`Z2` | 同上 | **没有** —— 规划是空间级动作，局部入口会让人以为只学眼前这一团 | Widget | 同上 · `Z2 不出现「开始学习」（SPEC-PLAN-016）` |
| `TC-PLAN-074` | `PLAN-016` | **显式** | α 包，`Z1` | 点「开始学习」 | 进整页 Planner；`项数 150` 且 `分母 150` —— 范围是整个空间 | Widget | 同上 · `点「开始学习」进整页 Planner，范围是整个空间（SPEC-PLAN-016）` |
| `TC-PLAN-075` | `PLAN-016` | **显式** | 同上 + `onPlanCreated` | 点进 Planner 再点返回 | 路由栈退回去；上层**一次都没被调用** | Widget | 同上 · `点返回取消，上层收不到草稿（SPEC-PLAN-016）` |
| `TC-PLAN-076` | `PLAN-016` | **显式** | 一项的夹具包，搜其标题 | 看结果列表底部 → 点 CTA | CTA 出现；回调用**整次定位结果**（`query` 对），不是某一行 | Widget | `app/test/features/locate/locate_overlay_test.dart` · `有落点类命中 ⇒ 底部「按此范围建计划」（SPEC-PLAN-016）` |
| `TC-PLAN-077` | `PLAN-016` | **显式** | 同上，改搜其轴取值 | 同上 | 结果照列（轴是筛选入口），但**没有** CTA —— 按轴圈不出任何项 | Widget | 同上 · `只命中筛选类 ⇒ 不给「按此范围建计划」（SPEC-PLAN-016）` |
| `TC-PLAN-078` | `PLAN-016` | **显式** | 同上，不给 `onPlanHere` | 同上 | 无 CTA —— 按下没反应的按钮比没有按钮更糟 | Widget | 同上 · `没有上层接收 ⇒ 不渲染这个入口（SPEC-PLAN-016）` |

### 3.51 `B4` 第 8 笔 · 三段「+ 自建」与重入复用（20 条 · 2026-10-19 提出）

> 本笔的探清结论与笔序表不同，**三段的可达程度不一样**，用例也照实分成三块：
>
> ⚠️ **「+ 自建」此前是三段各一个灰色占位文字**（`+ 自建（P-8 开放）`），零交互。
> 而 `loadCandidates` 的 `userSources` / `userSchemes` / `userMethodBundles` 三个通道
> **`P-2` 就打通了**，面板一直没传 —— 缺的是接线，不是机制。
>
> ⚠️ **源的自建只能「登记」**：覆盖率算的是「参照集合里 `sourceRefs` 含本源 id 的项数」，
> 绑定关系住在 **`Item.sourceRefs`（内容侧）**，客户端反向写不了 ⇒ 自建源 coverage 恒 0。
> 已选体系时它会被「覆盖 > 0」筛掉并标「需重选」——**与别的候选同一口径，不做特例放行**。
> 规格修订已如实写明，不假装三段等价。
>
> ⚠️ **`v0.52.0`（`B4-R`）推翻了上面的「不做特例」**：终端走查发现「建完立刻选中、随即被
> 清空」= 建的动作没有任何回执。现改为**保留 + 不可选**（`TC-PLAN-097` 的预期已就地改写，
> 见 §3.52）。
>
> ⚠️ **自建体系与自建方法不接进解算/预览就等于没做**：`resolvePlanScope` /
> `computePlannerPreview` / `composePlanDraft` 一直只认包里的东西，`loadCandidates` 的
> 参照集合也直接问 `pack.schemeNodes`。不接会得到一个特别难查的现象 —— 自建体系在候选
> 列表里看得见、**一选中就抛「不存在的体系 id」**；自建方法建完，预览报「未覆盖 N 项」
> 把确认拦住。本笔把节点查找收成 `schemeNodesOf` 一处，三处都走它。
>
> ⚠️ **`PLAN-019` 的「`Plan.version + 1`」已被 `P-6` 推翻**：版本由 `fold` 数条数得出，
> 面板与 `PlannerScreen` 连碰都不碰。本笔只补两个接头：从整份 `Plan` 取初值、`planId`
> 与预填同源。
>
> ⚠️ **本地 overlay 存储全仓不存在**（`GOV-008` / `PACK-011` 均未开工）⇒ 自建的三份只活
> 在面板 `State` 里，关掉即丢。**跨会话持久化如实登记为未做**，不写临时 JSON 文件 ——
> 那会与将来的 overlay 变成两份判据。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-PLAN-079` | — | — | `taken` 为空的 / 含前缀的 | `uniqueContentId` | 空集时取前缀本身；撞了向后试；**同输入同输出**（随机数会让「建两次」与「改一次」分不开） | Unit | `app/test/core/plan/user_content_test.dart` · `自建 id 优先用前缀本身，撞了才追加序号（无 SPEC：id 生成属实现口径）` |
| `TC-PLAN-080` | `PLAN-007` | **显式** | `appliesTo = {type: [], sixAxis: {}, layer: null}` | `normalizeAppliesTo` 后再 `appliesToItem` | 归一成空 map，匹配器判**真** —— 留着空列表会走「数组取任一命中」⇒ 恒不命中 ⇒ 全部项被筛空 | Unit | 同上 · `空 appliesTo 读作「不限」，空列表与空 map 必须丢掉（SPEC-PLAN-007）` |
| `TC-PLAN-081` | — | — | `appliesTo = {relevance: high}` | 同上 | 抛 `FormatException` —— 与 `appliesToItem` 同一口径 | Unit | 同上 · `未认的 appliesTo 键仍抛（无 SPEC：沿用 appliesToItem 的未认键口径）` |
| `TC-PLAN-082` | `PLAN-007` | **显式** | 名字带前后空白 / 空名字 / 空版本 | `buildUserSource` | 名字去空白；`segments` **恒空**（内容绑定落地前拿不到摘录）；空名字与空版本都抛 | Unit | 同上 · `自建的源没有摘录正文，名字与版本必填（SPEC-PLAN-007）` |
| `TC-PLAN-083` | `PLAN-007` | **显式** | `nodes = [i3, i1, i3, i2]` | `buildUserScheme` | 结果 `[i3, i1, i2]` —— 顺序原样保留（那是学习次序），重复去重但保首次位置；空 `nodes` 抛 | Unit | 同上 · `节点顺序就是学习次序，重复节点去重保首次（SPEC-PLAN-007）` |
| `TC-PLAN-084` | `PLAN-011` | **显式** | 两个「读 / 例」步；一个「读」步但 `phase` 覆盖成 `review` | `validateMethodRecipe` | 前者抛（`entity-fields` §12 校验 ②）；后者通过 —— 判据是 `effectivePhase`，不是算子名 | Unit | 同上 · `全「读 / 例」的配方被拒 —— 会静默绕过遗忘曲线（SPEC-PLAN-011）` |
| `TC-PLAN-085` | `PLAN-010` | **显式** | 空配方；`type = procedural` 的一份自建 | `validateMethodRecipe` / `buildUserMethod` | 空配方抛；产出的 bundle **只覆盖一个类型**，id 由 profile id 派生（重入时凭 `Plan.methodProfileId` 反查得到） | Unit | 同上 · `空配方被拒；一份自建只覆盖一个类型，bundle id 由 profile 派生（SPEC-PLAN-010）` |
| `TC-PLAN-086` | `PLAN-011` | **显式** | 一份全无 `hint` / 一份带 `hint` | `bundleHasAnyHint` | 前者 `false`、后者 `true` —— 校验 ③ 只要求「说得出来」，不拦 | Unit | 同上 · `全步骤无 hint 时判得出来（不拦，但确认段要能说出来）（SPEC-PLAN-011）` |
| `TC-PLAN-087` | `PLAN-007` | **显式** | 自建体系 `nodes = [i3, i1]` | `resolvePlanScope` 分别不传 / 传 `userSchemes` | 不传抛 `ArgumentError`；传了得 `[i1, i3]` —— `resolved` 恒按 `pack.items`，**不按 `nodes`** | Unit | `app/test/core/plan/user_scope_test.dart` · `自建体系能被解算，不传就抛（SPEC-PLAN-007）` |
| `TC-PLAN-088` | — | — | 自建体系与包内同为 `sch-full` | 同上 | 自建优先（`nodes = [i4]` 生效）；分母仍 4 —— 与 `mergeByOrigin` 的 `user > pack` 同序 | Unit | 同上 · `自建体系与包内同 id ⇒ 自建优先（无 SPEC：与 mergeByOrigin 同序，属实现一致性）` |
| `TC-PLAN-089` | `PLAN-011` | **显式** | 一份只覆盖 `declarative` 的自建方法；4 项里 2 项 `procedural` | `computePlannerPreview` 不传 / 传 `userProfiles` | 不传 ⇒ 未覆盖 **4**（分支 id 不在平台档里）；传了 ⇒ **2** —— 不接线时「自建完反而用不了」 | Unit | 同上 · `自建分支不传进预览 ⇒ 全被判未覆盖，传了就为 0（SPEC-PLAN-011）` |
| `TC-PLAN-090` | `PLAN-015` | **语义** | 自建体系 `[i4, i2]` + 自建方法 | `composePlanDraft` 与 `computePlannerPreview` 传**同一份** | `resolved.length == itemCount`，且 `resolved == [i2, i4]` —— 两处各写一遍必然分叉 | Unit | 同上 · `草稿与预览用同一份自建体系 ⇒ resolved 与项数一致（SPEC-PLAN-015）` |
| `TC-PLAN-091` | `PLAN-008` | **显式** | 夹具包（源 `appliesTo` 为空） | 逐段读卡片 | 五元素齐：名字 · 出处（`· 空间包`）· 适用范围（源读 `appliesTo`→「不限」、体系读 `nodes` 的类型→「陈述」、方法读 `byType`→四类全覆盖）· 读数与版本 · 尾部「+ 自建」**三段都有且是真按钮** | Widget | `app/test/features/planner/planner_panel_test.dart` · `候选卡五元素齐：名字 · 出处 · 适用范围 · 读数 · 尾部「+ 自建」（SPEC-PLAN-008）` |
| `TC-PLAN-092` | `PLAN-007` | **显式** | 同上（**未选体系**） | 点源段「+ 自建」→ 填名字「内规」→ 加入 | 候选出现且 id 带 `user:` 前缀；出处标「· 自建」；确认段随即显示「内规」—— **建完立刻选中**，不用再点一次。⚠️ `v0.52.0` 起这条只覆盖「未选体系」：不收窄就不筛，覆盖 0 不影响可用性 | Widget | 同上 · `源自建：建完立刻出现在候选里并被选中（SPEC-PLAN-007）` |
| `TC-PLAN-093` | `PLAN-007` | **显式** | 同上 | 点体系段「+ 自建」→ 填名字 → 依次勾 `i2` / `i1` → 加入 | 候选出现；选中后 `preview-items` = 2、`preview-denominator` = 4 —— 不接线时这里会抛「不存在的体系 id」 | Widget | 同上 · `体系自建：勾选次序即 nodes，预览与确认都用它（SPEC-PLAN-007）` |
| `TC-PLAN-094` | `PLAN-011` | **显式** | 同上（起手一步是「读」） | 点方法段「+ 自建」→ 填名字 → 直接加入 | 表内出现错误且**说得出理由**、对话框不关、候选里没有它；把该步改成「忆」后同一张表能存 | Widget | 同上 · `方法自建：全「读」配方被拒，错误显示在表里且不入候选（SPEC-PLAN-011）` |
| `TC-PLAN-095` | `PLAN-011` | **显式** | 同上，选中 `src-a` + `sch-full` | 自建一份只覆盖陈述的方法 → 建计划 | 确认可点、无「未覆盖」拦截；草稿的 `methodProfileId` 是 **bundle 的 id**（`user:method:三遍法#bundle`），不是分支 id | Widget | 同上 · `方法自建后能走完三段并建计划，草稿存的是 bundle id（SPEC-PLAN-011）` |
| `TC-PLAN-096` | `PLAN-011` | **显式** | 同上 | 先不选 ③ → 选平台「记忆优先」→ 再自建一份带 `hint` 的 | 未选时无提示；选平台组合时出现「本方法无提示可给」（五份平台分支确实都没 `hint`）；自建带 `hint` 后提示消失 | Widget | 同上 · `全步骤无 hint 时 ③ 段说出来；自建带 hint 后提示消失（SPEC-PLAN-011）` |
| `TC-PLAN-097` | `PLAN-007` | **显式** | 同上，先选 `sch-full` | 再自建一条源 → 加入 | 卡片**留在列表里**（`v0.52.0` 起不再被「覆盖 > 0」筛掉）；灰显、读数带「不可选」、段下出「已加入候选；当前体系下覆盖 0…」；**没有**「需重选」红字（它从没被选中过）；点它无效、确认仍禁用 | Widget | 同上 · `已选体系下自建的源覆盖 0 ⇒ 留在候选里标「不可选」，不凭空消失（SPEC-PLAN-007）` |
| `TC-PLAN-098` | `PLAN-019` | **显式** | 一份 `Plan`（三段 + `target` 圈 `i1`，`version = 3`） | `open(revising: plan)` | 三段与 `target` 全部预填（`项数 1` / `分母 2`）、`planId == 'evt-created-1'` 与预填同源；交出的草稿沿用上次的 `selector`，`resolved` 按当前包重算 | Widget | `app/test/features/planner/planner_screen_test.dart` · `传 revising 就是重规划：三段与范围都预填，planId 与预填同源（SPEC-PLAN-019）` |

### 3.52 `B4-R` · 终端走查后的四条（4 条 · 2026-10-19 提出）

> `B4` 八笔在沙箱内全绿，但沙箱只证「行为」：widget 测试每条用例自己摆初始状态，
> **从未跨屏串过一次**，也证不了真实窗口下的观感。终端走查 11 条，收成本节四条
> （另有两处语义改写已就地并入 §3.51 的 `092` / `097`）。
>
> - **唯一出口在视口外**：④ 确认原先排在 `ListView` 末尾，候选 4+2+3 条就要滚一屏多
>   —— 实拍「滚到顶看不到 ④ 确认和建计划」。它是建计划的唯一出口，不该靠用户去发现。
> - **极窄窗口整页崩坏**：`Row(Expanded(3), Divider, Expanded(2))` 没有下限，两栏各分到
>   几十像素，文字**逐字竖排**、每张卡片挂 `RIGHT OVERFLOWED BY 52 PIXELS`。
> - **「＋ + 自建」**：`Icon(Icons.add)` 与 `Text('+ 自建')` 各带一个加号。
> - **「需重选」文案与事实相反**：说「已选的」，而那一项已被清空；「当前另一端」也没
>   告诉用户是哪一端。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-PLAN-099` | `PLAN-014` | **显式** | 面板夹具，视口 **800×420**（≥ 断点 720 走横排，高度放不下三段） | 滚到顶 → 滚到底 | `planner-confirm-button` 的 rect 始终落在 `0..420` 内 —— 它固定在左栏底部、不参与滚动；旧实现下滚到顶时按钮在列表末尾、坐标掉出视口 | Widget | `app/test/features/planner/planner_panel_test.dart` · `④ 确认固定在左栏底部：候选滚到顶它仍在视口内（SPEC-PLAN-014）` |
| `TC-PLAN-100` | `PLAN-017` | **显式** | 面板夹具，视口 **520×900**（< 断点 720） | 逐段渲染 | 无 `FlutterError`（溢出在测试里以异常抛出）；`planner-preview` 的 `top >= planner-left` 的 `bottom` —— 堆叠后预览在清单下方 | Widget | 同上 · `窄于断点改上下堆叠，不出溢出条（SPEC-PLAN-017）` |
| `TC-PLAN-101` | `PLAN-007` | **显式** | 面板夹具 | 逐段读「自建」按钮 | 每个按钮内只有 `Text('自建')` + `Icon(Icons.add)`，**没有** `'+ 自建'` | Widget | 同上 · `三段「自建」按钮只有一个加号（SPEC-PLAN-007）` |
| `TC-PLAN-102` | `PLAN-014` | **显式** | `source: 'src-b'` + `scheme: 'sch-part'`（互不相容的重入预填） | `_pump` 即触发 `_dropChecks` | 红字含 `src-b` / 「当前体系」/「已取消选择」，且**不含**「已选的」。⚠️ 手动选择走不到这里：双向收窄下两段永远兼容，现只剩重入预填这一条路径 | Widget | 同上 · `「已取消选择」既说名字也说另一端，不再说「已选的」（SPEC-PLAN-014）` |

### 3.53 `B13a` 笔 1 · `Node` 按槽位两分（9 条 · 2026-10-20 提出）

> `ADR-0007` 的地基笔：`Node` 变 `sealed`、`StructuralNode` / `LearnableNode` 两分、
> `(axis, level_slot)` 的 12 对合法组合进静态表、四条形态检查（`R6`–`R9`，用例在 §3.6）。
>
> 本节守的是**行为**，§3.6 守的是**形态** —— 两者不能互替：形态检查看不出
> 「12 对里少了一对」，行为测试也看不出「有人给 `StructuralNode` 加了 `type`」。
>
> ⚠️ **两处与 `ADR-0007` 字面有出入，均为实现期发现并回写 ADR**：
> ① `levelSlot` 做成抽象 getter 而非基类字段 —— 基类字段就得让 `LearnableNode`
> 接收它再校验「必须是 planet」，而 ADR 原话是「开放就等于留一个能写错的口子」；
> ② `system`（行星系）归 `StructuralNode`，且**不在** 12 对表内 —— 它是载荷容器、
> 轴继承自父恒星，列进表里反而要为新槽位回来改表。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-NODE-001` | — | — | `legalSkeletonSlots` 12 条 | 逐对构造 `StructuralNode` | 12 对**全部**构造成功；表长度恰为 12 | 单元 | `app/test/core/entities/node_test.dart` · `12 对合法组合全部可构造` |
| `TC-NODE-002` | — | — | `(discipline, galaxy)` 与 `(major, cluster)` | 构造 | 抛 `IllegalNodeSlotError` —— 学科轴没有星系级、专业轴没有星团级 | 单元 | 同上 · `非法组合构造即抛 IllegalNodeSlotError` |
| `TC-NODE-003` | — | — | `levelSlot = system`，三轴各一次 | 构造 | 三次**都成功** —— 载荷容器不限轴 | 单元 | 同上 · `system 不限轴` |
| `TC-NODE-004` | — | — | 一个 `LearnableNode` | 读 `levelSlot` | `planet` —— 且构造函数**没有**这个参数可传 | 单元 | 同上 · `levelSlot 被钉死为 planet` |
| `TC-NODE-005` | — | — | 同上，`requirements` 四齐 + 一缺 + 一不可外化 | 读 `type` / `layer` / `completeCount` / `externalizableCount` | `procedural` / `persistent` / `4` / `5` —— 不可外化**不进分母** | 单元 | 同上 · `三项非空字段有值` |
| `TC-NODE-006` | — | — | `scope = S4`、`packId` 空、无 `officialCode` | 构造 | 成功且 `officialCode == null` —— 自建与载荷节点无官方码 | 单元 | 同上 · `载荷节点可无官方码` |
| `TC-NODE-007` | — | — | `Scope.s0`–`s4` | `wire` 与 `fromWire` | 线上是 `S0`–`S4`（大写）；`fromWire('s3')` **抛错** —— 与小写混用过的正是这类 | 单元 | 同上 · `Scope 线上取值是大写 S0–S4` |
| `TC-NODE-008` | — | — | 四组未知取值 `moon` / `topic` / `skill2` / `deleted` | `fromWire` | 四者均抛 `FormatException`，报错里**列出允许值** | 单元 | 同上 · `未知取值抛 FormatException` |
| `TC-NODE-009` | — | — | 按轴聚合 `legalSkeletonSlots` | 数每轴槽位数 | 学科 **3** / 专业 **4** / 角色 **5**；学科轴**不含** `galaxy` —— 槽位是语义的，不是深度序号 | 单元 | 同上 · `槽位是语义槽位而非深度序号` |

### 3.54 `B13a` 笔 2 · 三元校验器与 `ParentIndex`（11 条 · 2026-10-20 提出，**本节补登**）

> ⚠️ **补登说明**：笔 2（`#91`）的这 11 条用例落地时**没有登记进本节**，`STD` 头部读数因此从 704 直接跳到 709（`D6` 那笔加的 5 条），中间 11 条一直是空的。`D5` 查的是「头部读数 vs `STR` 最新轮次」，两处一起过期时它不报 —— 这是同一个盲区的第二面。本节补齐，用例编号一次给足（`001`–`011`），不重排既有段。
>
> 判据来自 [`minimal-pack.md`](../minimal-pack.md) §4.3（6 个错误码 + **固定 fail-fast 顺序**）与 [`path-rules.md`](../path-rules.md) §六（七面对应表）。**与解析层口径刻意相反**：那一层一次报全部问题（服务构建期修包的人），这一层遇错即停（服务「恰好一个码」的验收判据）。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-PATH-001` | — | 显式 | `fixtures/m1/pack.json` + `expect.json` | `validatePack` | `codes` 为空，且 `paths` 与 `expect.json` 的映射**逐条相等** | 单元 | `app/test/core/pack/triple_validator_test.dart` · `3 节点 / 4 边 / 2 entry 全绿…` |
| `TC-PATH-002` | — | 显式 | 同上 | 扫 `nodes[]` 的键 | 没有任何节点带 `path` 字段 —— 派生值不入库（`P-01`）；三条 path 仍逐段正确 | 单元 | 同上 · `path 由父链重算，不来自任何缓存或字段…` |
| `TC-PATH-003` | — | 显式 | 两份不同的 `skeletonPaths` 注入表 | 各跑一次 | `path` 前缀跟着注入表变，**签名不变** —— `B13b` 换真骨架时不用改实现 | 单元 | 同上 · `骨架 path 由调用方注入…` |
| `TC-PATH-004` | — | 显式 | 父节点 id 指向不存在的节点 | `validatePack` | `E-PATH-PARENT` —— 无码可报不等于通过 | 单元 | 同上 · `父节点缺失时无码可报会静默通过…` |
| `TC-PATH-005` | — | 显式 | `neg-id-format/`（`var` 的 id 写成 `m1-demo:v1:var`） | 同上 | `E-ID-FORMAT`（`P-09`：local 段不许含分隔符） | 单元 | 同上 · 参数化遍历目录 |
| `TC-PATH-006` | — | 显式 | `neg-id-dup/`（两个节点同 id） | 同上 | `E-ID-DUP` —— 且**只报这一个**（id 唯一早于父链可达，改 id 会让引用悬空） | 单元 | 同上 |
| `TC-PATH-007` | — | 显式 | `neg-path-parent/`（父 id 不存在） | 同上 | `E-PATH-PARENT` | 单元 | 同上 |
| `TC-PATH-008` | — | 显式 | `neg-path-dup/`（两个 slug 都改成 `same`） | 同上 | `E-PATH-DUP` —— 同父唯一（`P-06`）与 path 全局唯一（`P-07`）各断言一次 | 单元 | 同上 |
| `TC-PATH-009` | — | 显式 | `neg-slug-format/`（`Func_2`） | 同上 | `E-SLUG-FORMAT`（`P-04`：大写与下划线都不在字符集） | 单元 | 同上 |
| `TC-PATH-010` | — | 显式 | `neg-parent-cross-pack/`（`var` 直接挂骨架） | 同上 | `E-PARENT-CROSS-PACK` —— **靠「骨架父只能有一个」抓到**，单看「等于 `attach_to`」它过得去 | 单元 | 同上 |
| `TC-PATH-011` | — | 显式 | `_extra` 与 `_` 前缀的 slug | `_wellFormedSlug` 路径 | 保留段前缀即拒（`P-04`）；`^[a-z0-9-]+$` 不含下划线 | 单元 | 同上 · `下划线只允许作为保留段前缀…` |

> ⚠️ **`ADR` 编号不进 `SPEC` 列**：`D4` 的编号正则是 `([A-Z]{3,6})-\d{3}`，`ADR-0005` 会被截成 `ADR-000` 当成一个独立 SPEC，凭空多出一条覆盖。本节三条款子的形态依据是 `ADR-0005` 决策 7（身份与地址分离 · `attach_to` 物化）与 `ADR-0007` 决策 2（派生三项不作字段），写在这里而不进列。

**每个反例只改一处、只期望一个码** —— 一次改两处就分不清是哪条规则抓到的，反例的证明力归零。校验顺序固定（`id 格式 → id 唯一 → slug 格式 → 父链可达 → path 构成 → path 唯一 → 跨包`）是这条成立的前提。

### 3.55 `B13a` 笔 3 · 存储三区接缝与原子写（22 条 · 2026-10-20 提出）

> 三区的判据不是「三个目录叫对了名字」，而是**可写区碰不到只读区**、**事件区拿不到写方法**、**写失败不留半截事实**。前两条在拼路径与接口形状时就判死，第三条只能打真实磁盘 —— 所以本节**没有内存实现**：要验的语义就是「写到一半挂了会怎样」，而内存实现里「写一半」不存在，拿它验原子性等于把要验的那条 mock 掉。
>
> ⚠️ **三区根全部由调用方注入**，本节不测平台目录 —— 那归 `B8`（`PACK-018` 把路径解析判给探测层）。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-STORE-001` | — | 显式 | 三个互不包含的根，含尾斜杠与 `./` | 构造 `StoreLayout` | 成立，且三个根都被归一化（`data/packs/` → `data/packs`） | 单元 | `app/test/core/storage/store_layout_test.dart` · `三根互不包含即成立…` |
| `TC-STORE-002` | — | 显式 | 两区同根 | 构造 | 抛 `InvalidStoreLayoutError` | 单元 | 同上 · `两区根相同即拒…` |
| `TC-STORE-003` | — | 显式 | `data` 与 `data/user` | 构造 | 抛，且 `other` 指向另一区 —— 可写区落在只读区里，一次原子写就能改包正文 | 单元 | 同上 · `一区包含另一区即拒…` |
| `TC-STORE-004` | — | 显式 | `/data` 与 `/database` | 构造 | **不抛** —— 字符串同前缀但段不同是两个目录。反证：判据退成 `startsWith(root)` 时本条立刻红 | 单元 | 同上 · `字符串同前缀但段不同不算重叠…` |
| `TC-STORE-005` | — | 显式 | `data` 与 `data/user/..` | 构造 | 抛 —— 归一化后是同一个目录 | 单元 | 同上 · `归一化后相等也算重叠…` |
| `TC-STORE-006` | — | 显式 | `C://app//data` 与 `C:/app/data` | 构造 | 抛 —— 反斜杠与正斜杠是同一个根 | 单元 | 同上 · `Windows 反斜杠与正斜杠是同一个根` |
| `TC-STORE-007` | — | 显式 | 只读区根为空串 | 构造 | 抛 —— 空根拼出来是 `/x`，整棵树变成一个区 | 单元 | 同上 · `空根即拒…` |
| `TC-STORE-008` | — | 显式 | 可写区 / 事件区各一个相对路径 | `pathIn` | 拼到对应区根下 | 单元 | 同上 · `区内相对路径拼到对应区的根下` |
| `TC-STORE-009` | — | 显式 | `../packs/pack.json` · `../../etc/passwd` | `pathIn` | `null` —— 相对路径是插件作者可控的输入 | 单元 | 同上 · `` `..` 逃出本区即拒 `` |
| `TC-STORE-010` | — | 显式 | `a/../claims.json` | `pathIn` | 归一化后仍在本区 | 单元 | 同上 · `区内上跳再回来不算逃逸` |
| `TC-STORE-011` | — | 显式 | 临时目录下一个不存在的目标 | `writeStringAtomic` | `true`、内容读回一致、目录里**没有 `.tmp` 残留** | 单元 | `app/test/core/storage/store_fs_test.dart` · `写新文件…` |
| `TC-STORE-012` | — | 显式 | 先写 `old` 再写 `new` | 同上 | 内容换成 `new`，目录里只有目标文件 | 单元 | 同上 · `覆盖已有文件…` |
| `TC-STORE-013` | — | 显式 | 目标路径是个**目录**（rename 必然失败） | 同上 | `false`，且**同目录的 `keep.json` 原样还在**、临时文件已清 | 单元 | 同上 · `写不下去时返回 false 且不动旧内容…` |
| `TC-STORE-014` | — | 显式 | 目标目录不存在 | 同上 | `false` —— 建目录是调用方的显式动作，不代做 | 单元 | 同上 · `目标目录不存在时不自行建目录…` |
| `TC-STORE-015` | — | 显式 | 先 `ensureDir` 建三层再写 | 同上 | 两步都成功 | 单元 | 同上 · `目录建好之后同一路径即可写…` |
| `TC-STORE-016` | — | 语义 | 同一实现类的类型关系 | `isA` 三次 | 同时满足 `StoreFs` / `WritableStoreFs` / `AppendOnlyStoreFs` —— 三区共用一份实现，越界由 `StoreLayout` 判 | 单元 | 同上 · `同一个实现类同时满足三个区的能力` |
| `TC-STORE-017` | — | 显式 | 连续 `appendLine` 两次 | 同上 | 行间**只有一个**换行（实现负责补，调用方不传） | 单元 | 同上 · `连续追加两行…` |
| `TC-STORE-018` | — | 显式 | 输入已带 `\n` | 同上 | 不重复补，不产生空行 | 单元 | 同上 · `已带行尾换行的输入不重复补` |
| `TC-STORE-019` | — | 显式 | 目录不存在 | 同上 | `false` —— 半行写入比写不进去更难查 | 单元 | 同上 · `目录不存在时返回 false` |
| `TC-STORE-020` | — | 显式 | 追加前已有内容 | 同上 | 已有内容**一个字都不变**，只增长 | 单元 | 同上 · `追加不改动已有内容…` |
| `TC-STORE-021` | — | 显式 | 非 UTF-8 字节 | `readString` | `null` —— 不猜编码 | 单元 | 同上 · `非 UTF-8 返回 null 而不是猜编码` |
| `TC-STORE-022` | — | 显式 | 不存在的路径 | `readString` / `isFile` | `null` / `false` —— 读接口一律总函数，不抛 | 单元 | 同上 · `不存在的文件读为 null、isFile 为 false` |

**六处独立反证（各红对应的一条，无连坐）**：段级判据退成 `startsWith(root)` ⇒ `TC-STORE-004` 红；撤 `pathIn` 的越界检查 ⇒ `009` 红；撤反斜杠归一化 ⇒ `006` 红；撤 `appendLine` 补换行 ⇒ `017` 红；撤失败分支的临时文件清理 ⇒ `013` 红；给 `AppendOnlyStoreFs` 注入 `clear()` ⇒ `R3` 红一处。

> ⚠️ **`TC-STORE-013` 首版写错了判据位置**：断言的是「目标目录里没有 `.tmp`」，而临时文件建在**目标路径旁**（同目录保 rename 原子），目标是目录时它落在**上一级** —— 撤掉清理逻辑该用例照样绿。反证当场抓住，改成查上一级。**判据写错了位置，等于没判。**

### 3.56 `B13a` 笔 4 · 五类实体补齐与新格式解析层（42 条 · 2026-10-21 提出）

> 本节验两件事：**五类此前没有代码的实体**（`Pack` / `NodeEntry` / `PathClaim` / `PathAlias` / `OverlayPatch`）能不能把台账的字段与不变式落住；**新格式解析层**（单文件六段）在坏数据面前报不报得出来。
>
> ⚠️ **本节不验旧链路** —— 12 个吃 α 包的用例仍跑旧解析器，接线归笔 5。本节全部读 `test/fixtures/m2/`，反例由 `mutateM2()` 在原文上改一处生成，**不另存反例文件**：改一处就存一份，六份反例就是六份会与正例漂移的副本。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-ENT-001` | `PACK-001` | 显式 | M2 清单 | `Pack.fromJson` | 九个清单字段逐项落地（`plugin_id` / `version` / `namespace` / `schema_version` / `skeleton_requires` / `license` / `review_state` / `signature` / `axes`） | 单元 | `app/test/core/entities/pack_test.dart` · `清单字段逐项落地` |
| `TC-ENT-002` | — | 显式 | `kinds: [payload, method]` | 同上 | 两个 kind 都在册，`terrain` / `overlay` 的 facts 为 `null` —— **`kinds` 可多值，不是判别符** | 单元 | 同上 · `kinds 可多值…` |
| `TC-ENT-003` | — | 显式 | `deps` 一条 | 同上 | `pluginId` + semver `range` 都读到 | 单元 | 同上 · `deps 跨包依赖带区间` |
| `TC-ENT-004` | `PACK-002` | 显式 | M2 `payload` | 同上 | `attachTo` / `subtreeRoot` / `levelRange` / 三级 `counts` / 五个装前可见布尔 / `quizTypes` / `estMinutesCoverage` 逐项 | 单元 | 同上 · `payload 摘要…` |
| `TC-ENT-005` | `STEP-027` | 语义 | M2 `method.methods[0]` | 同上 | `hasReviewStep = true`、`itemTypes` 三值、`stepCount = 4` —— 装前就能看出配方缺不缺复习 | 单元 | 同上 · `method 摘要带 has_review_step` |
| `TC-ENT-006` | — | 显式 | 删 `payload` 字段、`kinds` 仍含 `payload` | `Pack.fromJson` | 抛 `IllegalPackKindError`，`declared = true` | 单元 | 同上 · `声明了 kind 却没有特化字段 ⇒ 抛` |
| `TC-ENT-007` | — | 显式 | `kinds` 只留 `method`，`payload` 字段仍在 | 同上 | 抛，`declared = false` —— **第二种错法更隐蔽**：数据在、没人读、界面显示「零可学项」而无人报错 | 单元 | 同上 · `带了特化字段却没声明 kind ⇒ 抛` |
| `TC-ENT-008` | — | 显式 | `counts` 删 `planet` 键 | 同上 | 抛 `FormatException` 且**报出键名** —— 不给默认值 | 单元 | 同上 · `counts 缺一个键就报字段名` |
| `TC-ENT-009` | — | 语义 | 解析后的 `Pack` | `toJson` → 再 `fromJson` | 往返后清单字段与计数不变（序列化自洽） | 单元 | 同上 · `序列化往返…` |
| `TC-ENT-010` | — | 显式 | M2 `m2-demo:var` 的 entry | `NodeEntry.fromJson` | 十一个内容字段逐项落地 | 单元 | `app/test/core/entities/entry_test.dart` · `载荷内容逐项落地` |
| `TC-ENT-011` | — | 显式 | 同上 | 读 `sourceRefs` | `['m2-tutorial']`；`typing` 节点两者皆空 —— **`source_refs` 与 `resources` 是两件事**（引自哪份材料 vs 推荐去哪学） | 单元 | 同上 · `source_refs 落地…` |
| `TC-ENT-012` | — | 语义 | `m2-demo:lang-core`（`system`） | `entryOf` | `node` 在、`entry` 为 `null` —— 稀疏表，不是「每节点必有一份」 | 单元 | 同上 · `骨架节点没有 entry…` |
| `TC-ENT-013` | `STEP-012` | 显式 | 四个算子各一条无 `phase` 的步骤 | `effectivePhase` | `read` / `example` → `first`；`recall` / `do` → `both` | 单元 | 同上 · `相位派生…` |
| `TC-ENT-014` | — | 显式 | `read` + 显式 `phase: review` | 同上 | `review` —— 作者可覆盖派生值 | 单元 | 同上 · `显式 phase 覆盖派生` |
| `TC-ENT-015` | — | 显式 | `typing`（`criteria: []`）与 `var`（一条） | `isCheckin` | `true` / `false` —— 空 `criteria` 即打卡式，`S` 永不增长 | 单元 | 同上 · `空 criteria = 打卡式…` |
| `TC-ENT-016` | — | 显式 | `var` 与 `typing` | `isQuizAligned` | 两者皆 `true` —— **两边都空也是合法形态**，不是坏数据 | 单元 | 同上 · `criteria 与 quiz 1:1 对齐` |
| `TC-ENT-017` | — | 显式 | 手造 2 条 criteria + 1 道题 | 同上 | `false`，且**不抛** —— 坏数据归构建期，客户端给判据不给门 | 单元 | 同上 · `criterion 少一题 ⇒ 对齐为假，但不抛` |
| `TC-ENT-018` | — | 语义 | `var`（`auto`）与 `debug`（`self`） | `isAutoJudged` | `true` / `false` —— `progressKind` 由 `judge` 派生，不入库 | 单元 | 同上 · `judge 派生 progressKind…` |
| `TC-ENT-019` | — | 显式 | `{"operator": "do"}` | `EntryStep.fromJson` → `toJson` | 算子为 `doStep`，序列化回 **`do`** —— `do` 是 Dart 保留字，成员名与线上取值必须分开 | 单元 | 同上 · `算子线上取值是裁定值…` |
| `TC-ENT-020` | — | 显式 | `state: live` / `state: tombstone` | `PathClaim.fromJson` | 三字段落地；`isTombstone` 两态分明 | 单元 | `app/test/core/entities/path_claims_test.dart` · `占用与墓碑两态` |
| `TC-ENT-021` | — | 显式 | `state: deleted` | 同上 | 抛 `FormatException`，允许值一并列出 | 单元 | 同上 · `未知 state 不在册即报…` |
| `TC-ENT-022` | — | 显式 | `parent_change` 带/不带 `from_ver`+`to_ver` | `PathAlias.fromJson` | `hasVersionRange` 分别 `true` / `false` | 单元 | 同上 · `parent_change 必须带版本区间…` |
| `TC-ENT-023` | — | 显式 | `slug_change` 不带版本 | 同上 | `hasVersionRange = true` —— 版本区间只对改主父必填 | 单元 | 同上 · `slug_change 的版本区间允许为空` |
| `TC-ENT-024` | — | 显式 | `reason: parent_change` | `toJson` / `fromWire` | 线上取值是蛇形，与成员名 `parentChange` 不同形 | 单元 | 同上 · `线上取值是蛇形…` |
| `TC-ENT-025` | — | 显式 | 六字段补丁 | `OverlayPatch.fromJson` | `scope` / `targetId` / `field` / `value` / `baseHash` / `isStale` 逐项 | 单元 | `app/test/core/entities/overlay_patch_test.dart` · `字段级补丁逐项落地` |
| `TC-ENT-026` | — | 语义 | `value` 是字符串数组 | 同上 | 原样携带为 `List` —— **不收窄类型**，收窄等于把 §9 字段表抄一遍 | 单元 | 同上 · `value 不收窄类型…` |
| `TC-ENT-027` | — | 显式 | `state: stale` | 同上 | `isStale = true` —— 指纹失配不自动应用 | 单元 | 同上 · `指纹失配 ⇒ stale…` |
| `TC-ENT-028` | — | 显式 | `value: null` | 同上 | 合法，序列化也保留 `null` —— 补丁可以「清空一格」 | 单元 | 同上 · `value 允许为 null…` |
| `TC-PACK-048` | `PACK-005` | 显式 | M2 全文 | `readPack` | 六段全部解析：9 节点 / 15 边 / 6 entry / 2 源 / 2 体系 / 1 配方 | 单元 | `app/test/core/pack/pack_reader_test.dart` · `M2 六段齐全即可解析` |
| `TC-PACK-049` | — | 语义 | M2 `nodes` | 同上 | 1 个 `StructuralNode`（`system`）+ 8 个 `LearnableNode` —— 分派轴是 `level_slot` 不是 `scope` | 单元 | 同上 · `按 level_slot 分派…` |
| `TC-PACK-050` | `FND-005` | 显式 | M2 三类边 | 同上 | `ParentEdge` 10 · `WormholeEdge` 1 · `PrerequisiteEdge` 4，其中 `required` 2 条 | 单元 | 同上 · `三类边按判别符分派…` |
| `TC-PACK-051` | — | 语义 | `idiom` 有两条 parent | 同上 | 其中恰好一条 `main`（指向 `lang-core`）、一条 `secondary` —— 附加归属不冒充父 | 单元 | 同上 · `主父唯一…` |
| `TC-PACK-052` | `PACK-008` | 显式 | `nodes` 末尾复制第一个节点 | 同上 | 抛，报「id 重复」 | 单元 | 同上 · `段内 id 唯一：nodes 重复即拒` |
| `TC-PACK-053` | `PACK-008` | 显式 | `entries` 复制第一条 | 同上 | 抛，报出 `m2-demo:var` —— **查重键是 `node_id`，不是数组下标** | 单元 | 同上 · `entries 按 node_id 查重…` |
| `TC-PACK-054` | `PACK-005` | 显式 | 删 `methods` 段 | 同上 | 抛，报缺 `methods` 段 —— 六段缺一即格式错误 | 单元 | 同上 · `六段缺一即格式错误` |
| `TC-PACK-055` | `PACK-007` | 显式 | 顶层加 `notes` | 同上 | 抛，报 `notes` —— 清单字段与六段之外一律拒 | 单元 | 同上 · `顶层出现六段与清单字段之外的键即拒` |
| `TC-PACK-056` | — | 显式 | `counts.planet` 由 8 改 7 | 同上 | 抛，同时报声明值与实扫值 —— **摘要与正文不能各说各话** | 单元 | 同上 · `counts 与 nodes 实扫不一致即拒…` |
| `TC-PACK-057` | `FND-005` | 显式 | 加一条 `func → var` 的 `required` 先修边 | 同上 | 抛，报出现环 —— `⪯` 必须是 DAG | 单元 | 同上 · `先修边成环即拒` |
| `TC-PACK-058` | — | 显式 | 一条边 `type: unknown` | 同上 | 抛，允许值一并列出 | 单元 | 同上 · `未知边类型不在册即报…` |
| `TC-PACK-059` | — | 显式 | `system` 节点改 `axis: discipline` + `level_slot: galaxy` | 同上 | 抛「非法的节点槽位组合」—— 学科轴没有 `galaxy` 槽位 | 单元 | 同上 · `非法槽位组合当场抛…` |
| `TC-PACK-060` | — | 语义 | 加两条两端相同、`kind` 不同的 `wormhole` | 同上 | 两条都保留，总数 17 —— **`edges` 段不按 id 查重**（三类边没有 `id`，两端相同的 parent 与 wormhole 是两条边） | 单元 | 同上 · `` `edges` 段不按 id 查重… `` |
| `TC-PACK-061` | — | 显式 | M2 解析结果 | 三个索引 | `nodeById` 9 / `entryByNodeId` 6 / `sourceById` 2；`schemeNodes` 命中与未命中；`catalog` 源的 `isCatalog` | 单元 | 同上 · `类方法与源可达…` |

**六处独立反证**：撤 `Pack` 的 payload 特化字段校验 ⇒ `TC-ENT-006` / `007` 红（**同一判据的两个方向**，2 条）；`nodeFromJson` 的 `planet` 分支改判 `galaxy` ⇒ 红 **8 条** —— 分派是所有下游用例的前提，破坏它必然连坐（这不是判据不灵，恰相反）；撤 `counts` 与实扫比对 ⇒ `TC-PACK-056` 红；删 `nodes` 段的 `idOf` ⇒ `TC-PACK-052` 红（`entries` 仍查重，故只红 1 条）；`EntryStep.fromJson` 忽略显式 `phase` ⇒ `TC-ENT-014` 红；撤 `isQuizAligned` 的 `containsAll` ⇒ `TC-ENT-017` 红。

> ⚠️ **反证 6 第一版没红，抓出一条冗余判据**：原实现在 `containsAll` 之前还比了一次 `criteria.length != quiz.length`，撤掉它**没有任何用例变红** —— 因为它被后面两行的双向判据完全覆盖，是一个**没有对家的判据**（`R-08` 的镜像：撤掉也不红，那它就是多余的）。已删除长度检查，并在注释里写明「题数 == 条数」由 `covered.length == quiz.length` 与 `containsAll` 联合蕴含；重做反证后红 1 条。

### 3.57 `B14` 笔 4 · 装 / 卸载与 `PathClaim` 台账（15 条 · 2026-10-25 提出）

> 本节验的是此前**没有一行承载代码**的那条出口判据：「四类包可装可卸」。装包 = 探测 → 解析 → 三元校验 → 台账冲突 → 落盘，**任一阶段有问题就一个字节都不写**；卸载 = claim 转墓碑（`P-14`），**不删条目**。
>
> ⚠️ **两条口径在本节落地时定下，规格未回写**：
> 1. **台账形态**：`<可写内容区>/claims.json` = `{"schema":1,"claims":[…]}`。`entity-fields` §6 定义了 `PathClaim` 实体，但全文没有定义「这一堆 claim 存哪、长什么样」。
> 2. **冲突检查按算出来的 `path` 全表查，不只查 `path_reservations[]`**。`P-16` 把 `reservations` 定为「唯一依据」，而它声明的是本包将要占用的 `(父, slug)` —— 与解析后算出的 `path` 表**重合**。对着一张更全的表查比对着声明的子集查更严，且同样是 O(n)；漏查的后果正是「两个包共用一个 `path`」，即 `P-14` 存在要挡的那件事。`P-16` 禁止的是**装完再遍历全树比对**，本笔没做那件事。
>
> ⚠️ **`attach_to` 不在本节「物化」**：那条跨包 `main` 边本来就在包数据里（`entity-fields` §3 要求每个节点都有 `main` 父边，骨架父也不例外，`M1` / `M2` 两份夹具都这么写）。装载器若再补一条，同一对端点就有两条 `main` 边，「主父是谁」当场两个答案。所以这里的「物化」= 验证它存在且唯一（`validatePack` 第 ⑦ 步）。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-LOADER-001` | — | 显式 | `M2` 原文放进内存盘 `content/m2/pack.json`，骨架 `path` 注入 `skeleton:major/080901` | `PackLoader.install` | 装成功；台账 9 条、全部 `live`；`major/080901/lang-core` 归 `m2-demo:lang-core` | 单元 | `app/test/core/pack/pack_loader_test.dart` · 装一个载荷包：每个节点各占一条 path、状态 live（无 SPEC：path-rules P-14） |
| `TC-LOADER-002` | — | 显式 | 同一份包，两次装：一次注入骨架 `path`、一次不注入 | 同上 | 注入时 `pathOf('m2-demo:var')` = `major/080901/lang-core/var`；不注入则以 `E-PATH-PARENT` 拒装，且**不留台账** —— 算不出 `path` 的包装进来也定位不到 | 单元 | 同上 · 骨架 path 注入后跨包 pathOf 可达，不注入则以 E-PATH-PARENT 拒装（无 SPEC：minimal-pack §4.2） |
| `TC-LOADER-003` | — | 显式 | 预置台账：`major/080901/lang-core` 归 `other:lang-core`、状态 `live` | 同上 | 拒装，正文指名占用者；**台账原样不动**（冲突时一字不写） | 单元 | 同上 · 同一 path 已被别的节点占用即拒装，台账原样不动（无 SPEC：path-rules P-16） |
| `TC-LOADER-004` | — | 显式 | 同上，但占用者的状态是 `tombstone` | 同上 | 同样拒装，正文写「墓碑永不复用」—— 放开它就是「A 卸 → B 装 → A 装回」时 A 覆盖 B 的入口 | 单元 | 同上 · 同一 path 只有墓碑也拒装 —— 墓碑永不复用（无 SPEC：path-rules P-14） |
| `TC-LOADER-005` | — | 显式 | 内存盘 `writeStringAtomic` 恒返回 `false` | 同上 | 报「原子写失败」，`installedOf` 为 `null`，盘上没有台账 —— 写失败不能算装成功 | 单元 | 同上 · 台账原子写失败即报，且内存里也没有这个包（无 SPEC：写失败不能算装成功） |
| `TC-LOADER-006` | — | 显式 | `M3`（`kinds: ["overlay"]`、`nodes` 为空） | 同上 | 装成功，`paths` 为空、`attachTo` 为 `null`，**一个 claim 也不写**、盘上不出现台账 —— 没有 claim 可写就不碰盘 | 单元 | 同上 · 非载荷包照装，但一个 claim 也不写 —— 它没有 attach_to，没有 path 可占（无 SPEC：四类包里只有载荷带定位） |
| `TC-LOADER-007` | — | 显式 | 先装 `M2`，再 `uninstall('m2-demo')` | `PackLoader.uninstall` | 返回 `tombstoned = 9`；台账仍是 **9 条**、全部 `tombstone`、`node_id` 不变；`installedOf` 变 `null` | 单元 | 同上 · 卸载把 claim 转墓碑、不删条目（无 SPEC：path-rules P-14） |
| `TC-LOADER-008` | — | 显式 | 装 → 卸 → 再装同一个包 | 同上 | 第二次装成功，台账仍 9 条、全部回到 `live` —— 墓碑挡别人，不挡自己重装 | 单元 | 同上 · 卸载后重装同一个包：自己的墓碑回到 live（无 SPEC：墓碑挡别人，不挡自己重装） |
| `TC-LOADER-009` | — | 显式 | 台账文件不存在，卸一个没装过的包 | 同上 | 报「未安装」；**不凭空写一份空台账**（写了就分不清「没装过」与「装空了」） | 单元 | 同上 · 未安装就卸载即报，且不凭空造一份台账（无 SPEC：空台账写盘会让「没装过」与「装空了」看不出区别） |
| `TC-LOADER-010` | — | 显式 | 台账是半截 JSON（`{"schema":1,"claims":[`） | `install` | 拒装并报「不是合法台账」；**原来那份坏数据原样留着** —— 坏台账不能靠重建掩盖 | 单元 | 同上 · 台账不是合法 JSON 即拒装，且不覆盖它（无 SPEC：坏台账不能靠重建掩盖） |
| `TC-LOADER-011` | — | 显式 | 空台账 | `toJson` → `fromJson` | 读回仍是空；两次序列化**同一串字节** | 单元 | `app/test/core/storage/claim_ledger_test.dart` · 空台账序列化后读回仍是空，两次序列化同一串字节（无 SPEC：台账形态本笔定） |
| `TC-LOADER-012` | — | 显式 | 两条 claim，一份按 `a,b` 写入、一份按 `b,a` 写入 | 同上 | 两份 `toJson` **逐字节相同** —— 不定序会让每次装包都产生「内容没变、diff 全变」的提交 | 单元 | 同上 · 按 path 升序序列化 —— 结果与写入顺序无关（无 SPEC：台账形态本笔定） |
| `TC-LOADER-013` | — | 显式 | `{"schema":2,"claims":[]}` | `fromJson` | 抛 `FormatException` —— 不认识的格式不猜（猜错 `state` 的后果是该拦的复用拦不住） | 单元 | 同上 · `schema` 不认识即拒，不猜字段含义（无 SPEC：台账形态本笔定） |
| `TC-LOADER-014` | — | 显式 | 同一个 `path` 两条 claim（一条 `live`、一条 `tombstone`） | 同上 | 抛 `FormatException` —— 同一个地址两份账，「谁现役」没有答案 | 单元 | 同上 · 同一个 path 两份账即拒 —— 谁现役说不清（无 SPEC：台账形态本笔定） |
| `TC-LOADER-015` | — | 显式 | 台账里 `a` 是 `x:1` 的墓碑 | `withClaim` 写 `a` = `x:1` 的 `live` | 新台账 1 条、状态 `live`；**旧台账仍是墓碑** —— 台账不可变是「写盘失败不留中间态」的前提 | 单元 | 同上 · 同 path 再写一条即覆盖，且旧的那份不被就地改（无 SPEC：台账不可变是写盘失败不留中间态的前提） |

**两处独立反证（各红 1 条，无连坐）**：把冲突判定里的墓碑分支放过（`held.isTombstone` 也算可占）⇒ `TC-LOADER-004` 红，其余 9 条全绿；把卸载从「转墓碑」改成「删条目」⇒ `TC-LOADER-007` 红，其余 9 条全绿。两次都只红一条 —— 这说明两处断言各自钉在一条判据上，不是靠同一段代码连坐出来的绿。

> ⚠️ **本节没验的两件事，如实登记**：
> 1. **`deps` 区间不校验**。`P-16` 只把 `path_reservations[]` 定为装前判据；依赖求解要读另一个包的 `version`，需要一张已安装清单 —— 本笔没有，且「已装清单」的落盘形态规格也没定义。
> 2. **`PathAlias` 不写**。它服务「骨架升版改主父」，归骨架版本迁移，不在装 / 卸。
>
> ⚠️ **同一批里的两处账面修正**：§3.7 节头「40 条」早在 `B14` 笔 1 / 笔 3 之后就是错的（实为 46：3 + 8 + 13 + 6 + 12 + 4），本次一并改为 46；§3.7.3 的表被一条空行断成两截（`TC-LOAD-043`–`046` 四行落在表外），本次接回同一张表。两处都不改条数，只改形态。

### 3.58 首次装上真包 · 装配器与启动装载（5 条 · 2026-10-25 提出）

> 本节验的是**到这一笔之前完全不存在的那条链路**：源数据 → `assemble_pack.py` → `<空间>/pack.json` → `PackProbe` → `readPack` → 界面。
> 此前 `pack_loader` / `readPack` 有 439 条用例，但**没有一行生产代码调用它们**，`main.dart` 只有一个空态 —— 所以「包能装」这件事在界面上从来没被观测过。
>
> ⚠️ **本节测的是真实产物，不是夹具**，这是它与 `§3.7` / `§3.57` 的根本差别：夹具是人手写的、永远合规；产物是脚本拼的，拼错了没有任何别的地方会红。代价是它**依赖盘上有产物** —— 所以缺产物时 `fail` 而**不 skip**（`skip` 会让「忘了跑装配脚本」表现成绿灯）。
>
> ⚠️ **本节不验字段语义**：装配器的映射口径（`criteria[].statement` 由答案派生、`quiz[].type` 定为 `freeform`）是**搬运约定**，写在 `content/tools/assemble_pack.py` 的文件头表里，不是判据。判据仍归 `validator.py` 的字段级规则。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-BOOT-001` | `FND-014` | 显式 | 注入 `PackBoot(problems: [missingPack: …])`，不读磁盘 | 渲染外壳 | 空态仍是「尚未载入任何知识空间」，**并列出那条具体原因**与修法提示；不塌成一句「加载失败」 | Widget | `app/test/widget_test.dart` · 探不到包时报出具体原因，不塌成一句「加载失败」（`SPEC-FND-014`） |
| `TC-BOOT-002` | `PACK-005` | 显式 | `content/` 下**每个**已装配的 `pack.json`（不写死空间名） | `readPack` | 全部解析通过，且每个包都有可学节点 —— 装上也学不到东西的包不算装上 | 单元 | `app/test/core/pack/real_content_pack_test.dart` · `content/` 下每个已装配的包都能被 readPack 解析（`SPEC-PACK-005`） |
| `TC-BOOT-003` | `PACK-005` | 显式 | `content/python/pack.json` | `readPack` | `counts` 与实扫一致（`readPack` 内建对账）；行星系数 > 0 且可学节点数多于行星系数 | 单元 | 同上 · 真实产物能被 readPack 解析，且 counts 与实扫一致（`SPEC-PACK-005`） |
| `TC-BOOT-004` | — | 显式 | 同上 | 遍历 `learnableNodes` 查 `parents.mainParentOf` | 每个可学节点都有主父，且主父 id 在本包 `nodes` 里 —— 挂不住的节点在树上不出现 | 单元 | 同上 · 每个可学节点都有主父，且主父指向本包内存在的节点（无 SPEC：主父唯一是 `entity-fields` §3 的表，尚无 `SPEC` 编号） |
| `TC-BOOT-005` | `PACK-018` | 显式 | 真实产物 + 注入式启动装载 | 渲染外壳 | 出现包名、**不出现空态** —— 探测按运行期 CWD 命中 `<包根>/pack.json` | Widget | 同上 · 界面从真实产物渲染出行星系，而不是空态（`SPEC-PACK-018`） |

> ⚠️ **本节没验的两件事，如实登记**：
> 1. **`steps` / `body` 一栏没有内容**。旧源数据里根本没有这两栏，装配器写 `null`，界面显示「暂无」—— 被测的是「缺就照实说」，不是「补上」。**后续**：`§3.59` 起 `python/func` 一域已写出真内容，其余九域仍空；本节这条读的是**当时**的状态，现行口径见 `§3.59`。
> 2. **`flutter run` 的真机形态**。沙箱不跑 GUI，本节只到 widget 层。

### 3.59 内容真的写出来了 · `entries.json` 与断言覆盖（4 条 · 2026-10-25 提出）

> 本节验的是 **`content/<空间>/entries.json` → `pack.json` 的 `entries` 段**这一跳：写出来的摘要 / 正文 / 步骤 / 时长有没有真的到客户端手里。
> 上一节（`§3.58`）验「包能装上、缺内容照实说」；本节验「有内容时不丢」。两者都要有，因为**内容丢了与内容没写，界面上是同一种表现**——都显示「暂无」——靠肉眼分不出来。
>
> ⚠️ **输入仍是真实产物**（同 `§3.58`）：缺产物 `fail` 不 `skip`。
> ⚠️ **本节不验文案对不对**：正文与步骤说了什么由作者负责；本节只验四类结构判据 —— 非空、算子合法、至少一步复习、断言与题成对。

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-BOOT-006` | `PACK-005` | 显式 | `content/python/pack.json`（真实产物） | 取 `entries` 中 `steps` 非空者 | 至少一条；且每条都有 `summary` / `body` / `estMinutes`，每步 `instruction` 非空 —— 内容进了段而字段没丢 | 单元 | `app/test/core/pack/real_content_pack_test.dart` · 写出来的内容真的进了 entries 段：摘要 / 正文 / 步骤 / 时长（`SPEC-PACK-005`） |
| `TC-BOOT-007` | — | 显式 | 同上 | `entry.hasReviewStep` + 算子枚举 | 每条带步骤的条目至少一步 `review` / `both`；算子恒在六类内 —— 全是「读 / 例」的配方跑得通、进度也涨，只是学过就忘不会被发现 | 单元 | 同上 · 每条带步骤的条目至少一步复习，且算子合法（无 SPEC：这条校验在 `entity-fields` §9.1，尚无 `SPEC` 编号） |
| `TC-BOOT-008` | — | 显式 | 同上 | 断言数与题数 + 每题 `criterion_id` 的归属 | 断言或题**任一非空**的条目：断言数 == 题数，且每题 `criterion_id` 指向本条目断言；且至少一条断言不以「能说出：」开头（真写的，不是模板兜底） | 单元 | 同上 · 能力断言与题目严格 1:1，且存在真写的断言而不是模板兜底（无 SPEC：1:1 是 `entity-fields` §9.3 的注，尚无 `SPEC` 编号） |
| `TC-BOOT-009` | `PACK-005` | 显式 | 真实产物 + 直接渲染详情页 | 渲染 `PlanetScreen` | 出现首步指令原文，**不出现**「暂无（本包不含步骤）」 | Widget | 同上 · 详情页渲染真实步骤，不是「暂无」（`SPEC-PACK-005`） |

> ⚠️ **`TC-BOOT-008` 补上了 `§3.58` 登记的那个缺口**：`§3.58` 如实登记过「`criteria` 与 `quiz` 的 1:1 没有任何用例锁住」（实测拆开配对后四条仍全绿）。过滤条件特意取「**任一非空**」而不是「有题」——只剩断言、没有题的条目同样是 1:1 被破坏，按「有题」筛会把最该抓的那一条整条跳过。
> ⚠️ **`entries.json` 的输入契约在装配期拦，不在本节拦**（反证实测四条）：算子写错 · 全是首学算子 · 断言指向不存在的题 · `itemId` 错字，装配脚本都直接 `fail` 并指出文件与条目，不会一路走到客户端才炸。
> **如实登记**：`entries.json` 目前只覆盖 `python/func` 一域 **15 条**（`steps` 75 步 · 断言覆盖 6 题），其余九域**仍无步骤与正文**；**97 条**节点既无题也无内容（不建 `entry`，界面照实显示「暂无」）；`payload.est_minutes_coverage` = **0.1**。

## 四、覆盖缺口

### 4.1 总量

| 口径 | 数量 |
|---|---|
| `SPEC` 唯一编号总数（实测 `grep -ohE` 去重） | **209**（`v0.50.0` 起 +`PLAN-022`；`v0.23.0` 起：原 171 + `ACC` 15 + `SYNC` 16 + `VIEW-035` 1；`v0.30.0` 起再 + `B12` 的 `VIEW-036`–`040` 5 条） |
| 有对应用例的 `SPEC` | **74**（按 `SPEC` **首次出现**那条用例判显式 / 语义：显式 55 + 语义 18 + 1 条首现行标的是常量 `C-34`（`VIEW-003`，`TC-VIEW-041`），不属二分）<br>（`v0.56.0` 起 `PACK-002` 首次覆盖，+1 —— 首现行 `TC-ENT-004` 标**显式**；`v0.51.0` 起 `PLAN-007` `011` 两条**同时**首次覆盖，+2 —— 两条的首现行都标**显式**（`TC-PLAN-097` / `096`）；`v0.50.0` 起 `PLAN-016` `017` `022` 三条**同时**首次覆盖，+3 —— ⚠️ 本版首刷曾把增量错记为 +1（只算 `PLAN-022`），因为误以为 `016` / `017` 早有用例；实扫第 2 列证明它们在 `P-7` 之前**从未出现过**，是 `D4` 对账抓出来的。`v0.49.0` 起 `PLAN-003` 首次覆盖，+1；`PLAN-019` 早由 `TC-PLAN-038`（`P-4`）覆盖，是本行的列举一直漏了它、数字却按实扫算，故不在本笔增量里；`v0.45.0` 起按实扫校正 —— `VIEW` +6、`ACC` −1；旧值 60 与「显式 45 + 语义 15」都是手写的，**没有留下口径**，所以复算不出来；`v0.44.0` 起 `PLAN-012` `013` `021` 首次覆盖，+3；`v0.43.0` 起 `PLAN-006` `008` `010` `014` `020` 首次覆盖，+5；`v0.42.0` 起 `ACC-013` / `ACC-014` 首次覆盖，+2；`v0.4.0` 为 18；`v0.15.0` 起 `VIEW-009` `010` `011` `012` `014` `017` 与 `FND-004` · `NOTE-007` 首次覆盖；`v0.16.0` 起 `VIEW-019` `021` `024` `026` `030` `033` 首次覆盖，再 +6；`v0.17.0` 起 `VIEW-032` 首次覆盖，+1；`v0.18.0` 起 `VIEW-020` 首次覆盖，+1；`v0.20.0` 起 `VIEW-031` 首次覆盖，+1；`v0.21.0` 起 `VIEW-015` `VIEW-016` 首次覆盖，+2；`v0.30.0` 起 `VIEW-036` 首次覆盖，+1；`v0.31.0` 起 `VIEW-037` 首次覆盖，+1；`v0.32.0` 起 `VIEW-038` 首次覆盖，+1；`v0.35.0` 起 `VIEW-039` 首次覆盖，+1；本版 `VIEW-040` 首次覆盖，+1）。`B2` 第 2 笔补上 `FND-008` 定位三态 · `VIEW-025`/`027`/`028`/`029` 快速定位 · `PACK-018` 运行期取包；第 3 笔补上 `FND-010` 事件折叠；第 4 笔补上 `VIEW-002` 三坐标各承载一维） |
| 无用例 | **135** |

按域：

| 域 | `SPEC` 总数 | 有用例 | 缺口 |
|---|---|---|---|
| `FND` | 16 | 10（`002` `003` `004` `005` `008` `010` `011` `012` `013` `014`） | 6 |
| `VIEW` | 40 | 34（`001` `002` `003` `004` `006` `007` `008` `009` `011` `012` `013` `014` `015` `016` `017` `018` `019` `020` `021` `024` `025` `026` `027` `028` `029` `030` `031` `032` `033` `036` `037` `038` `039` `040`） | 6 |
| `PACK` | 18 | 7（`001` `002` `005` `007` `008` `009` `018` —— `002` 由 `B13a` 笔 4 的 `TC-ENT-004` 首次覆盖） | 11 |
| `PLAN` | 22 | 16（`003` `006` `007` `008` `010` `011` `012` `013` `014` `015` `016` `017` `019` `020` `021` `022` —— `014` / `015` 由 `P-4` 首次覆盖、`003` 由 `P-6` 首次覆盖、`016` `017` `022` 由 `P-7` 首次覆盖、`007` `011` 由 `P-8` 首次覆盖；`019` 先前就有用例，只是本行的列举漏了它） | 6 |
| `STEP` | 34 | 4（`012` `014` `022` `027`） | 30 |
| `QUANT` | 15 | 1（`006`） | 14 |
| `NOTE` | 19 | 1（`007`） | 18 |
| `GOV` | 14 | 0 | 14 |
| `ACC` | 15 | 1（`014`） | 14 |
| `SYNC` | 16 | **0** | 16 |
| **合计** | **209** | **74** | **135** |

### 4.2 缺口必须分三类看，不能混算

**135 这个数字本身说明不了任何问题。** 项目当前只完成 `B1`（三端骨架）、`B2` 全部与 `B3` 全部（十笔，`G3` 判定见 `STR` 轮次 `R2`，已出仓），209 条需求里绝大多数属于 `B4`–`B11`。把它们算成「测试缺失」等于指责一个还没开工的批次。

| 类别 | 判据 | 性质 | 数量 |
|---|---|---|---|
| **A · 未开工缺口** | 该 `SPEC` 所属批次尚未开始 | **正常**，随批次推进自然收敛 | 127（= 135 − B 类 8，为估算） |
| **B · 已实现无断言** | 代码里已有实际定义或逻辑，但**没有断言锁住该语义** | **真风险** | **8** |
| **C · 有断言但未标号** | 已测，测试里没写裁定编号 | 追溯断链，**非**测试缺失 | **0**（`R-09` 清零） |

> ⚠️ **`v0.45.0` 又修了 `VIEW` 与 `ACC` 两行**（28→34、2→1），并连带校正总量 60→65 / 148→143 与 §4.2 的 158→143、140→135。原因是同一类：只改正文、不改按域表。这次不是人眼发现的，是新增的 `tool/docs/check.dart`（`D4`）逐项比对出来的 —— 它把「§4.1 说的」与「用例表第 2 列写的」直接对账，对不上就报
>
> ⚠️ **本表按实扫修正了按域的两行**：`v0.43.0` 与 `v0.42.0` 两次升版只改了上面的总数与正文，`PLAN` 行仍写「21 / 0 / 21」、`ACC` 行仍写「15 / 0 / 15」—— 与正文「`PLAN-006` `008` … 首次覆盖」直接矛盾。**同版内部自相矛盾比数字过时更糟**：读者不知道信哪一行。合计随之从 50 / 158 校正为 **60 / 148**。
>
> **A 类为什么只能给估算**：判断「未开工」需要逐条核对 `SPEC` 所属批次，而 `specs/` 的 209 条并未逐条标注批次归属。135 是按「总数 − 已明确判定的 B、C 两类」倒推的上界，不是逐条核对的结果。把 `SRS` 按批次切片完成后，这个数才能变准。**`ACC` / `SYNC` 两域 31 条全在 A 类**（各自 0 代码 0 用例），这一部分没有估算误差。
>
> **差分口径有一处已知重叠**：`FND-003` 既在「有用例」（`TC-PACK-019` 锁的是**取值域** —— 非法 `layer` / `type` 即拒）又在 B 类（「三层是径向属性、不是层级」这一**语义**无断言）。两处判的不是同一件事，故不重复扣减；差分数因此是估算而非核对结果。

> **C 类为什么是 0，而不是「这 12 条被删了」**：它们走两条出口 —— 7 条核对后映射成立，标号已写进测试名，`R5` 规则从此强制它；5 条核对后**不成立**（借用同域相近语义），降级进 B 类。**不硬标是这次处置的核心**：把 `R1` 的依赖方向标成 `FND-015` 的「零硬编码分支」，追溯表会好看，但那是伪造证据 —— 比不标更糟。


### 4.3 B 类明细（真正的缺口 · 8 条）

| `SPEC` | 实现位置 | 现状 | 为什么算缺口 |
|---|---|---|---|
| `FND-003` | `core/enums.dart` `Layer` | 枚举已定义 | 无断言锁住「三层是径向属性、不是层级」这一语义 |
| `FND-015` | `core/**` 全局 | `R1` 保证核心层不反向依赖 | **判据错位**：`R1` 管依赖方向，`FND-015` 管「不得按具体空间 / 语言分支」。前者红不等于后者成立 |
| `GOV-001` | `core/enums.dart` | 四种裁定枚举已定义 | 零用例 |
| `STEP-018` | `core/enums.dart` | 三档刻度枚举已定义 | 零断言 |
| `QUANT-007` | `core/entities/plan.dart` `isCheckin` | 能判定「这是打卡式」 | 判定位有了，**算法位没有**：照算、封顶 `0.5`、不归零、UI 标「未验证」四条都无断言 |
| `PLAN-003` | `core/entities/plan.dart` `Plan` | `Plan` 已持有三段引用 | 无断言测「三项挂 `Plan` 不挂空间」与「同一空间可并存多份 `Plan`」—— 测的是 `target.count` 派生，是另一回事 |
| `NOTE-005` | `core/entities/state.dart` `Note` | 三层显示优先级已测 | 测的是 `authored > autoFilled > generated`，**不是**「两套笔记共用 `itemId` 锚点」 |
| `VIEW-001` | `core/constants.dart` | 界面阈值常量齐备 | 测的是 `C-20`–`C-23` 六个常量取值，与「五档视距 Z0–Z4 是唯一主导航层级」无关 |

**后四条是 `R-09` 从 C 类降级来的**：它们原先靠「同域 + 语义沾边」被当作已覆盖，核对 `SPEC` 原文后不成立。降级不是退步 —— 标错比不标更糟。

`FND-010` 本轮从 B 类**移出**（9 → 8）：`TC-EVT-014` / `027` / `026` 三条合起来锁住了「状态只能由 `fold` 从事件算出」—— 空事件流得空态、`asOf` 能截断、`spaceId` 能过滤，且 `item_skipped` 明确**不写任何状态**。原先缺口的理由是「结构已定但无断言」，现在断言的是**派生关系本身**，不是「有个 `fold` 函数」这种形状检查。

`FND-004` 上一轮从 B 类**移出**（10 → 9）：`TC-LOAD-001` 断言了「三态只认 `present` / `missing` / `not_externalizable`，驼峰写法抛错」，即**取值集合封闭**。原来那条缺口的理由是「`TC-PACK-002` 只测缺格即错」，现在有了锁住取值域的那条。

`STEP-012` 不算缺口：`TC-QUANT-005` 的「系数表与枚举等长」足以挡住「往枚举里加第七类」（加一项则等长断裂），而类型系统挡住「写个不在册的算子」。两处合起来覆盖了「只能取这 6 类之一」。

### 4.4 追溯已接通（原 C 类 7 条）

`R-09` 的处置结果：12 条里 **7 条映射核对成立**，标号已写进测试名（`R5` 从此强制），`STR` 可以机械生成追溯表。

| `SPEC` | 承接测试 | 标号落点 |
|---|---|---|
| `FND-005` | `TC-FND-007`（`neg-cycle`） | `fixtures/neg-cycle/expect.json` 的 `note` |
| `FND-011` | `TC-FND-001` · `TC-FND-002` | `events_test.dart` 两条 `test` 名 |
| `FND-014` | `TC-FND-005` · `TC-INF-010` | `events_test.dart` · `widget_test.dart` |
| `STEP-012` | `TC-QUANT-005` | `constants_test.dart`（`C-14…C-19`） |
| `STEP-014` | `TC-STEP-001` · `TC-STEP-002` | `entities_test.dart` 两条 `test` 名 |
| `STEP-022` | `TC-QUANT-006` | `constants_test.dart`（`C-26`） |
| `STEP-027` | `TC-STEP-003` | `entities_test.dart` 一条 `test` 名 |

还有 4 条测试**写不出标号**，按规则显式写「无 SPEC：<理由>」而不是硬凑：`fromJson(toJson()) 往返保真`（契约层通用要求）· `target.count 由 resolved 派生`（字段定义在 `entity-fields.md`，非 `SPEC` 条目）· `Event` 的两条 wire 名测试（约定在 `event-types.md`）。

**机制化**：`R5` 规则已进 `tool/lint`，每个 `test` / `testWidgets` 必须带 `SPEC-…` / `C-…` / `ADR-…` / `R<n>` 之一，或显式「无 SPEC：<理由>」。漏标即 CI 红 —— 断链不会再靠人自觉。


## 五、待补与待核

| # | 项 | 类型 | 归属 |
|---|---|---|---|
| 1 | ~~`FND-012` 加 lint 规则（禁 `copyWith` / 禁非 `final` 字段）~~ —— **已处置**（`R3`，`TC-INF-011`–`015`） | 补断言 | ✅ 2026-10-17 闭环 |
| 2 | ~~`VIEW-004` 加架构规则（`sourceRefs` 不得出现在视图层入参）~~ —— **已处置**（`R4`，`TC-INF-016`–`019`） | 补断言 | ✅ 2026-10-17 闭环 |
| 3 | ~~`TC-PACK-010` 的 `SPEC` 标号待核（note 写 `PACK-005`，语义更像 `PLAN-012`）~~ —— **已处置**：fixture note 与 §3.2 该行均改标 `SPEC-PLAN-012`（`PACK-005` 讲包形态，从不承载逆序语义） | 待核 | ✅ 2026-10-25 闭环 |
| 4 | ~~28 个错误码无 fixture 覆盖~~ —— **已处置**（`TC-PACK-011`–`041`，37/37 + 覆盖对账自检，见 `STP` §六） | 补用例 | ✅ 2026-10-17 闭环 |
| 5 | ~~C 类 13 处补 `SPEC` 标号~~ —— **已处置**（7 条标号进测试名 + 5 条降级进 B 类，`R5` 强制此后不漏） | 补标号 | ✅ 2026-10-17 闭环 |
| 6 | ~~B 类其余 6 条补断言~~ —— **已处置**：`FND-012` / `VIEW-004` 已补机制；余 10 条转入存量 `B2` 起逐批补 | 补断言 | ✅ 2026-10-17 已重分类 |
| 7 | `FND-010` 的 **UI 半边**：`features/` 建成后补一条「视图不持有可写状态」的断言（当前只有核心层的派生关系有断言） | 补断言 | `B3` 视图层开工时 |
| 8 | ~~**「主取值」缺承载位**~~ —— **已处置**：新增 `Item.primaryAxis`（六值枚举，声明式字段），落地在 `entity-fields` `Item` 表 + `channel-table` §一 #5；`ADR-0003` §决策 3 记录了为什么不能用轴序或稀有度代替（那正是规格排除的「按优先级猜」）。代价如实登记：第 4 次扩 schema，须走 `PACK` B 级变更补值 | 补字段 | ✅ 2026-10-17 闭环（`ADR-0003`） |
| 9 | ~~**「指向未知」无视觉表达**~~ —— **已处置**：宇宙视图沿用 `SPEC-VIEW-007` 的黑洞（缺失端画虚线占位节点、父位取源点质心），不新增第三种线型；`channel-table` §一 #6 备注补明文 | 补规格 | ✅ 2026-10-17 闭环（`ADR-0003` §决策 5） |
| 10 | ~~**`φ` 的深度归一化 / 截断**~~ —— **已处置**：径向位置取**累计项数分位**（`r_φ = 累计在前项数 / 总项数`）。原拟的「分段折叠（0–9 / ≥10）」被实算否掉 —— `φ ≥ 10` 的层装了 **126/150 项（84%）**，折叠反而制造新粘连。`SPEC-VIEW-008` 的「首屏到 `φ=2`」管的是树的展开深度，与这条不冲突 | 补规格 | ✅ 2026-10-17 闭环（`ADR-0003` §决策 4） |
| 11 | ~~**帧率判据（`C-32`）待真机实测**~~ —— **已处置**：三档 + 一次窗口对照共四组读数（`76.0` / `60.0` / `72.8` / 全屏 `76.9` fps，均达优线）记入 `STR` 轮次 `R1`（已出仓）；判据补了测量前提 `C-33`（基准窗口 `1920×1080`），因为光栅随面积上涨，不绑尺寸则同一档能读出「余量 57%」与「占预算 88%」两种结论 | 补实测 | ✅ 2026-10-17 闭环 |
| 12 | 合成场景的**虚线比例与真实包不一致**：`buildSyntheticScene` 用 `_noise > 0.62` 造出 86/167 条虚线（51.5%），真实包只有 10/167（6.0%），条数差 **8.6 倍** ⇒ 合成档的 draw call（`1908` / `3622`）比真实情形高估约 2.6 倍。不影响 fps 与光栅结论（二者与调用数无关，见 `STR` 轮次 `R1`），但**该列不可当真实值引用** | 口径偏差 | `B3` 换掉合成场景后自然消失；`B3` 前引用该列须带此注 |
| 13 | **`ACC` / `SYNC` 两域共 31 条需求，已覆盖 2 条**（`ACC-013` / `ACC-014` 由 `B4` 第 1 笔覆盖；`ACC` 12 条进 `v0.1.0`、3 条随 `v0.2.0`；`SYNC` 16 条全在 `v0.2.0`） | 待补用例 | `B10`（`ACC` 余 10 条）· `B11`（`ACC` 余 3 条 + `SYNC` 16 条）。**不得提前编用例** —— 未实现模块的用例只能是用构造出来的证据冒充验证（`X-05`）；两域各自已有验收表可作种子（见 `ACC` / `SYNC` 末节） |

> 第 4 项已闭环，数字一并更正：`validator.py` 共 **37 个错误码**（原记 36 —— 那次统计用裸正则扫全文，把注释里提到的码算成了定义），现 **37/37** 有 fixture 断言。**重点不是补完，而是把对账固化成机制**：`verify.py --suite` 里的一步比对「定义集 vs 断言集」，差一条即退出码 1（`v0.9.0` 起该步为第三步，其后新增第四层「输出可移植性」，见 [`STP`](stp.md) §七 —— 那一层不产生用例）。α 包（`B2`）落地后仍需补**真实坏法样本** —— 那是提高负例代表性，不是补漏，两件事别混。

> 第 5 项的处置值得单独说：补标号有两种做法 —— 「把 12 条都标上」和「只标对得上的」。取后者。因为标号的用途是让 `STR` 机械生成追溯表，而**标错的标号会让追溯表撒谎**，且没有任何机制能事后发现。所以 5 条借位映射降级进 B 类（见 §4.3），宁可在缺口表里显形，也不在追溯表里充数。

## 六、当前读数

> **本节是全仓唯一的执行读数登记处。** 其余任何文件都不得复制这三个数 —— 同一个数写在两个地方，就存在「一起过期」的窗口，窗口里没有任何规则看得见（`v0.44.0`–`v0.45.0` 连续两版漏登、`B13a` 笔 2 双双停在 668 而真实 679，各实证过一次）。

| 读数 | 当前值 | 采集方式 |
|---|---|---|
| `flutter test` | **448 passed** | 在 `app/` 下整跑 `flutter test` |
| 用例表条数 | **824** | 本文件 §三 的 `TC-` 行数（唯一编号同数） |
| `lint` 规则数 | **10** | `tool/lint/rules.dart` 的 `R1`–`R10` |

**采集时点**：2026-10-25（内容笔收口时复采：用例 820 → 824、测试 444 → 448。这两数只随「新增用例」变，同笔改了装配器与内容源但没有新增断言的地方不改读数）。

**为什么读数放这里而不是文件头部**：头部是「这份文档现在讲什么」的摘要，每次改动都重写；读数是「此刻实测多少」，只在真跑过之后才变。两者变化频率不同，混在一处必然出现「改了摘要顺手改了数但没跑」或「跑了却没改」—— 判据需要的是一个**只在实测后才变**的落点，而节名比行号稳定：有人调整头部格式不会让锚点失效。

## 历史（迁移前版号序列）

> 以下为**迁入 `specs/` 之前**的版号序列，用于与旧版交付物对账，**不是现行版号** —— 本文件作为活文档不设版号，更新时间以 `git log` 为准。

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.69.0` | 2026-10-25 | **内容第一次写进产物：`entries.json` 与一个域的真步骤** —— 新增 `content/python/entries.json`（15 条 = `python/func` 一域：摘要 · 正文 · 5 步执行序列（读 / 例 / 练 / 讲 / 忆）· 步骤自检 · 预计时长 · 6 条真写的断言）。`assemble_pack.py` 两处行为变更：① 「有题目才建 `entry`」→「有题**或有内容**就建」（`criteria` 空 = 打卡式，`entity-fields` §9.2 允许）；② 搬运期拦四类输入契约（算子不在六类 · 步骤全是首学算子 · 断言指向不存在的题 · `itemId` 错字），四类全部反证实测会 `fail` 并指出文件与条目。`payload.est_minutes_coverage` 由写死的 `0.0` 改为实算（分母取可学节点数，不取条目数 —— 取条目数会让覆盖随「写了多少条」一起虚高）。§三 新增 §3.59 **4 条**（`TC-BOOT-006`–`009`），其中 `TC-BOOT-008` 补上了 `v0.68.0` 如实登记的「`criteria` 与 `quiz` 的 1:1 无用例锁住」那个缺口。**用例表 820 → 824**、`flutter test` 444 → **448**。⚠️ **如实登记**：只覆盖 `python/func` 一域 15 条，其余九域仍无步骤与正文；97 条节点既无题也无内容；`est_minutes_coverage` = 0.1 |
| `v0.68.0` | 2026-10-25 | **首次装上真包：装配器 + 启动装载 + 界面** —— 新增 `assemble_pack.py`（旧五段源 → 单文件 `pack.json`，一条一条的映射口径写在该文件头的表里：`criteria[].statement` 由答案原文加固定前缀派生、`quiz[].type` 定 `freeform`，其余旧数据没有的字段一律 `null` / 空数组，**不编造**；106 条没有题目的节点连 `entry` 都不建）。`main.dart` 从空态改成三层：包列表（多于一个包时才出现）→ 行星系 → 节点详情，缺内容时显示「暂无」而不是补占位。§三 新增 §3.58 **5 条**（`TC-BOOT-001`–`005`）。**用例表 815 → 820**、`flutter test` 439 → **444**。⚠️ **如实登记**：`steps` / `body` 一栏旧数据根本没有，界面显示「暂无」；`content/tools/build.py` 与它的 37 个 fixture **未迁**，两个产出脚本并存；真机 `flutter run` 沙箱验不了 |
| `v0.67.0` | 2026-10-25 | **`B14` 笔 5：`pack` 格式的规格与引用对齐（用例与断言零改动）** —— §3.2 的 `TC-PACK-010` 改标 `SPEC-PLAN-012`：`PACK-005` 讲的是包形态、从不承载逆序语义，原标号把「逆序不禁止」挂在了错的规格上（fixture `valid-inversion` 的 `note` 一并改）。§3.2 说明句里「`PACK-005` 五段与 `meta`」改「**旧**五段形态与 `meta` 信封」——`SPEC-PACK-005` 已改为单文件六段，旧五段只是 `content/tools/` 尚未迁移的实现。§五 待核项第 3 条据此闭环。**用例仍 815 条、`flutter test` 读数不变** |
| `v0.66.0` | 2026-10-25 | **`B14` 笔 4：装 / 卸载与 `PathClaim` 台账** —— §三 新增 §3.57 十五条（`TC-LOADER-001`–`015`）：装包五段（探测 → 解析 → 三元校验 → 台账冲突 → 落盘，**任一阶段有问题就一个字节都不写**）· 卸载把 claim 转墓碑、**不删条目**（`P-14`）· 冲突按算出来的 `path` 全表查（`P-16` 的 `path_reservations[]` 是同一张表的声明子集）· 台账落 `<可写内容区>/claims.json`（`{"schema":1,"claims":[…]}`，一次原子写落全部 claim）· `attach_to` 的跨包 `main` 边**不在此处物化**（它本来就在包数据里，装载器只验证唯一）。**用例表 800 → 815**、`flutter test` 424 → **439**。同批修两处账面：§3.7 节头「40 条」→ **46 条**（笔 1 / 笔 3 之后没跟）· §3.7.3 的表被一条空行断成两截（`TC-LOAD-043`–`046` 落在表外），接回同一张表。⚠️ **如实登记：`deps` 区间与 `PathAlias` 都不在本笔** —— 前者要一张已安装清单（其落盘形态规格未定义），后者归骨架版本迁移 |
| `v0.65.0` | 2026-10-25 | **`B14` 笔 3：非载荷两类包的样本入库** —— 新增夹具 `m3`（`kinds: ["overlay"]`，六段全空）与 `m4`（`kinds: ["terrain"]`，`nodes` 空、3 条先修边指向另一包的节点），配套加载器与 4 条用例。**动机**：`Pack` 的 `kinds` 与四个 facts 是**双向**校验，但此前只有载荷样本跑过 —— 「声明了却没给」（`TC-LOAD-045`）与「给了却没声明」（`TC-LOAD-046`）两侧都没被非载荷 kind 覆盖过。§3.7.3 包解析 9 → **13 条**（`TC-LOAD-043`–`046`，四条均标「无 SPEC」：`entity-fields` §1 只定字段集，未定「六段是否可空」与双向校验）；**§三 用例表 796 → 800 条**。⚠️ **如实登记：`overlay` 类包的补丁正文在 `pack.json` 里没有落点**（六段中无 `patches`）⇒ `overlay.patchCount` 目前**无对家**，`m3` 取 0 而不声明不存在的补丁；落点定下后 `m3` 与该摘要要一起改。`flutter test` 420 → **424** |
| `v0.64.0` | 2026-10-24 | **`B14` 笔 1：探测层切单文件 + 按 `kind` 分组候选根** —— `PackLayout` 删 `manifestFileName` / `distDirName` / `manifestPath`，`packPath(包根)` 直指 `<包根>/pack.json`（旧形态「清单 + 产物」两件自 `ADR-0007` 取消 `meta` 段后已无清单独有内容 ⇒ 探测说「不是包」、解析说「是包」，两层各说一套）；`PackProblemKind` 三值降两值；`PackLocation` 加 `kind`、`spaceRoot` 改名 `packRoot`；`probeSpace` → `probePack(包根, kind)` · `scanRoot` 加 `kind` 入参 · `scanRoots` 改收 `Map<PackKind, List<String>>`。⚠️ **分组 ≠ 分子目录**：同一个根可列给多个 kind，同一个包在各类查询里各出现一次（`packRoot` 相同、`kind` 不同）—— kind 是查询维度，权威 `kinds[]` 仍由解析层读；去重只在同一 kind 内按目录名进行。§3.7.2 路径探测 6 → **8 条**（`TC-LOAD-004` / `005` / `008` 重写 · `007` / `009` 改签名 · `TC-LOAD-006` 作废保留行 · 新增 `TC-LOAD-041` / `042`）；两条新用例标「无 SPEC」—— `SPEC-PACK-018` 只钉 `pack.json` 位置，未定义多 kind 探测。`TC-LOAD-010` 的「六段 + 清单」改「六段（`pack.json` 单文件，无清单）」。**§三 用例表 794 → 796 条**（含 66 条作废保留行）；`flutter test` 419 → **420**。⚠️ **如实登记：`SPEC-PACK-018` 的路径串 `<仓根>/content/<空间>/dist/pack.json` 仍指旧形态** —— 规格重写归 `B14` 笔 5，本笔不动 |
| `v0.63.0` | 2026-10-23 | §三 新增 `TC-DOC-023`–`025` 三条（`D7` 头部状态行：堆叠词报 1 处 · 历史表「此前」零报 · 超 `600` 字报并给实测值）；**§三 用例表 791 → 794**。同批把 §3.46 标题的条数从停在 **15** 条改准到 **25** 条（`v0.44.0` / `v0.52.0` / `v0.55.0` / `v0.63.0` 四次增量相加），此前标题与实际不符 |
| `v0.62.1` | 2026-10-22 | **勘误**：`ADR-0008` 换轨后目录名过时 —— `entity-fields` / `constants` 回指 3 处 + 批次归属说明。只改路径指向，**用例仍 789 条**、断言与判据零改动。 |
| `v0.62.0` | 2026-10-21 | **用例数不变（789）**：`B13a` 笔 5c 收口同步。§3.7.3 包解析 9 条落点从已删的 `pack_parse_test` 改指 `pack_reader_test` —— `TC-LOAD-010` / `013` / `014` / `015` / `016` 五条逐字换成新用例名并同步前置与预期（`items` → `nodes`、`parsePack` → `readPack`）；`TC-LOAD-011` / `012` 作废（`ADR-0007` 取消 `meta` 段，包身份改由 `Pack.pluginId` 自带、版本并入 `PackVersions`）；`TC-LOAD-017` / `018` 落点 `—` 标**待补**（坏 JSON 与「一次报全部」两条行为仍在，重写夹具时未带上）。§3.7.5 真实 α 包 4 条（`TC-LOAD-037`–`040`）与 §3.26 `TC-PACK-042` / `043` 作废 —— α 包夹具 `support/alpha_pack.dart` 随 `pack_parse.dart` 删除，且 `pack.space` / `sixAxis` / `primaryAxis` 已随 `ADR-0005` / `ADR-0007` 消失；**欠账如实登记**：真实内容包的四数校验、150 项自定位、题库悬空引用校验当前无自动化。§3.50 `TC-PLAN-062`–`067` 作废 —— `PlanSelector` / `PlanTarget` 由 `ADR-0007` 决策 2 废除，范围只落 `Plan.subtreeRoot`，四种解算式不再有入口。§3.45 五条逐字改名对齐（`TC-PLAN-019` / `020` / `025` / `027` / `031`，`L0`–`L4` 口径改五档 `AuthorityLevel`）。作废行按 `D3` 口径保留（删除线 + 落点 `—`），行数与编号集合不变 |
| `v0.61.0` | 2026-10-21 | **`B13a` 笔 5c-1：`appliesTo` 匹配器落到新本体（契约收口）** —— 键集 `{spaceId, type, layer}` → **`{type, axes, layer}`**（`spaceId` 随「一空间一包已废」失效、`sixAxis` 随 `ADR-0005` 失效）；入参 `Item` + `KnowledgeSpace` → **`Node`**，`type` / `layer` 只对可学节点有意义（结构节点上声明它们 ⇒ 不命中，不是缺字段）。5 条契约用例从 `candidates_test.dart` **拆到 `test/core/plan/applies_to_test.dart`** 并改吃节点夹具（`test/support/node_fixture.dart`）—— 这一份在 5c-2 / 5c-3 换解析层时原样存活。§3.44 五条改判：`TC-PLAN-017` 由 `spaceId` 改 `axes` · `TC-PLAN-016` 扩到两个废键 · `TC-PLAN-014` 补结构节点与空数组两条断言 · `TC-PLAN-018` 补形状错。⚠️ **用例表 789 条、Dart 419 条均不变**（只换契约与落点，不增删用例）；§四 不变。⚠️ **如实登记：`appliesToNode` 仍无生产调用方** —— 生产里的源过滤是 `candidates.dart` 的私有 `_spaceAllows`（只查已废的 `spaceId`），接线归 5c-2 |
| `v0.60.0` | 2026-10-21 | **新增 lint `R10`（append-only 接口方法面封闭）**：§3.6 补五条 `TC-INF-038`–`042`，用例 784 → **789**、Dart 414 → **419**。`R3` 是黑名单（查禁止的方法名），本条是**白名单**（多一个就报）—— 黑名单只能拦住想到过的名字，`R-24` 记的正是「`R3` 名单拦不住有人把 `writeStringAtomic` 加进 `AppendOnlyStoreFs`」。⚠️ **白名单刻意不用 `write*` / `delete*` 前缀匹配**：反证实测，前缀黑名单漏掉 `purge()`（`TC-INF-039` 专守这一面），而封闭集连这个一起收。⚠️ **只查接口声明体、不查实现类**：`DartIoPackFs` 同时 `implements PackFs, WritableStoreFs, AppendOnlyStoreFs`，按实现类查会把合法的能力叠加判成违规（`TC-INF-041` 专守）。⚠️ **顺带修 `R5` 的标号正则**：`\bR\d\b` 匹配不到 `R10`，新规则自己的测试标了号反而被判没标号 —— 这条正则写的时候规则只有九条。**`R10` 不进 `B13a` 出口判据**，它没有闸门效力，只有 CI 常在跑的效力 |
| `v0.59.0` | 2026-10-21 | **`B13a` 笔 5b（`Requirements` 改名 + `appliesTo.sixAxis` 移除）**：① `content.dart` 的 `ItemRequirements` 改名 `Requirements` 搬入 `entities/requirement.dart`，`node.dart` 改用新名。② `appliesTo` 从四键降到**三键**（`spaceId` / `type` / `layer`）—— 六轴降为「三容器轴 + 四类标签」后旧软约束恒真；内容侧 10 条摘录（english 3 · german 3 · python 4）的该键一并摘除并重建三包。③ §3.45 的注与 `TC-PLAN-016` 改判「传该键即抛 `FormatException`」。④ `normalizeAppliesTo` 删掉永不触发的「空 Map 丢弃」分支（三个键都不是对象类型）。**用例仍 784、Dart 仍 414** —— `TC-PLAN-016` 是改写不是增删 |
| `v0.58.0` | 2026-10-21 | **读数单点化 + `D2` 扩六份（检查器补两处盲区，代码与用例数不变）**：① `D5` 原判据「`STD` 头部 == `STR` 最新轮次」有**结构性盲区** —— 两处一起过期时两边相等、规则全绿（`STR` `R15a` 实证：头部与轮次双双停在 668，真实 679，一次没报）。改为**结构消灭**：读数只登记在 `STR` 轮次一处，`STD` 头部再出现 `flutter test` **N** 即报；变化叙述「748 → 414」不算读数（`TC-DOC-015` 专守防误报 —— 一条会误报的规则活不过三次改动）。② `D2` 的版号自洽从 `docFiles` 四份扩到 `versionDocFiles` **六份**，补 `SDP` / `SDD` —— 笔 4 那次 `SDD` 头部停在 `v0.13.0`、树里缺本笔落下的八份新文件，两处自洽所以 `D2` 全程没报。③ 用例表 §3.46 的 `TC-DOC-012`–`015` 四行判据重写（编号与条数都不变）。**用例仍 784、Dart 仍 414**，§四 **不变** |
| `v0.57.0` | 2026-10-21 | **`B13a` 笔 5a（六轴渲染层整层删除）**：`ADR-0005` 换本体后 `lib/features/universe/` 仍在画 `Z0`–`Z4` 六轴五档，且 `core/frame/` 与 `core/view/` 六份**只服务它** ⇒ 一并删除，不留孤儿。**共删 54 份 / 19,681 行**（`lib/features/universe` 20 · `test/features/universe` 13 · `lib/core/frame` 3 · `test/core/frame` 3 · `lib/core/view` 六（含 `fit`）· `test/core/view` 七 · `graph/subtrees` 1 · `tool/bench` 1）：`features/universe` 20 份 / 8,238 行 · `test/features/universe` 13 份 / 7,717 行 · `core/frame` 3 份 + 测试 2 份 · `core/view/{filter,motion,navigation,tree,viewport}` 5 份 + 测试 5 份 · `core/graph/subtrees.dart` · `tool/bench/projection_bench.dart`。**59 条用例标作废并保留行**（`~~编号~~` + 落点改 `—`，与 `V-1a` 那批同形），§三 用例表仍 **784 条**。⚠️ **`core/view/tree.dart` 是被迫删的**，不是主动扩权：它 `import '../frame/scene.dart'` 取 `placeholderIdPrefix`，`frame` 一删即编译不过；而它的行模型（root / space / domain / item 四层）本就是 `ADR-0005` 之前的形态，重建归 `B17a`。⚠️ **`features/locate/locate_overlay.dart` 对 `navigation.dart` 只有一句注释提及、无真 import** —— 按 grep 计数会误判它仍是消费者（实测消费者为 0）。`flutter test` 748 → **414**；`tool/bench/` 随 `projection_bench` 一起清空，**`STR` `R1` 的帧预算读数自此不可复跑**。**§4.1 覆盖数不变** —— 作废行仍带 `SPEC` 列，`D4` 照旧计入（既有口径，非本笔新定） |
| `v0.56.0` | 2026-10-21 | **`B13a` 笔 4（五类实体补齐 + 新格式解析层）**：§三 新增 §3.56 四十二条 —— `TC-ENT-001`–`028`（`Pack` 9 · `NodeEntry` 10 · `PathClaim`/`PathAlias` 5 · `OverlayPatch` 4）与 `TC-PACK-048`–`061`（解析层 14：六段齐全 · `counts` 与实扫一致 · 环检测 · 槽位分派 · `edges` 不按 id 查重）；用例 742 → **784**，`flutter test` 706 → **748**。⚠️ **反证 6 第一版没红，抓出一条冗余判据** —— `isQuizAligned` 里单独比 `criteria.length != quiz.length` 的那一行被后面的双向判据完全覆盖，撤掉它没有任何用例变红，已删除并在注释里写明理由 |
| `v0.55.0` | 2026-10-20 | **`B13a` 笔 3（存储三区接缝 + 原子写）**：§三 新增 §3.55 二十二条（`TC-STORE-001`–`022`：布局 10 · 原子写 6 · 追加 4 · 读能力 2），用例 709 → **742**；Dart 684 → **706**（+22）。⚠️ **同笔补登 §3.54 十一条 `TC-PATH-001`–`011`** —— 笔 2 的三元校验用例落地时没进本节，704 直接跳到 709，中间 11 条是空的；`D5` 只比「头部读数」与「`STR` 最新轮次」，两处一起过期时它不报（同一个盲区的第二面）。补登不重排既有段。⚠️ 本节的新段**没有内存实现**：要验的语义就是「写到一半挂了会怎样」，内存实现里「写一半」不存在。 |
| `v0.54.0` | 2026-10-20 | **交付物检查器补 `D6` 相对链接**：§三 新增 §3.46 五条（`TC-DOC-016`–`020`），用例 704 → **709**；Dart 679 → **684**（5 条 Unit）。§四 **不变** —— 这五条验的是检查器自身，不含任何 `SPEC-*` 的行为断言。⚠️ **起因是检查器的一条盲区**：`D1`–`D5` 全在查「数对不对」，没有一条查「路对不对」；本仓在 `01-plan/` 下写 `../design/`（正确是 `../../design/`）三处全错，而 `check.dart` 照样全绿 —— 数字错读者当场能看出来，链接坏了要点击才知道。⚠️ **范围定在全仓**：不只四份交付物，实测 91 份 Markdown / 749 条相对链接；`tmp/` 排除，那是待贴到别处的草稿。⚠️ **五类一律不校验**：带 scheme 的外链（会把 CI 变成网络依赖）· 页内锚点（判据本身有版本差异）· 站内绝对路径（本仓 Markdown 不经站点渲染）· 代码围栏内（示例路径本就可能是占位符）· **行内代码**（描述链接语法本身时就会出现这种形态）。最后一类是**实跑打出来的**：首版实现只在围栏处过滤，于是 `STP` / `SCMP` 正文里那两处 `` `[参考层](reference/)` `` 被当真链接，报 2 处假红 —— 假红比漏报更糟，它教会人忽略红灯。⚠️ **目录算存在**：`[参考层](reference/)` 是合法写法，判据是「能不能落地」而非「是不是文件」。⚠️ **四处独立反证**：撤 `..` 退层 ⇒ 016 / 018 / 019 红 3 条（`017` 不红，它没有上跳）；撤围栏跳过 ⇒ 020 红 1 条；撤行内代码剥离 ⇒ 020 红 1 条；行内代码正则退回**单反引号** ⇒ 020 红 1 条（多反引号定界被剥成半截）。⚠️ **顺带修正上一笔的漏登**：头部 `flutter test` 与 `STR` 最新轮次都还写 668（`B13a` 笔 1 的数），笔 2 加 11 条后两处**一起没跟** ⇒ `D5` 两边一致、不报。真实读数是 679，本笔实测 684，两处一并写正 |
| `v0.53.0` | 2026-10-20 | **`B13a` 笔 1（`Node` 按槽位两分）**：§三 新增 §3.53 九条（`TC-NODE-001`–`009`），§3.6 补十二条（`TC-INF-026`–`037`），用例 683 → **704**；Dart 647 → **668**（9 单元 + 12 架构）。§四 **不变** —— 本笔没有新增 `SPEC` 覆盖：`ADR-0007` 定的是类型形态，不是需求条，九条用例守的是「非法组合不可表达」，不含任何 `SPEC-*` 的行为断言。⚠️ **两条与 `ADR-0007` 字面的偏差，实现期发现并回写 ADR**：① `levelSlot` 做成抽象 getter 而非基类字段 —— 做字段就得让 `LearnableNode` 接收它再校验「必须是 `planet`」，而原话是「开放就等于留一个能写错的口子」；② `system`（行星系）归 `StructuralNode` 且**不在** 12 对表内 —— 载荷容器，轴继承自父恒星，列进表里反而要为新槽位回来改表。⚠️ **`R8` 必须同时看 `MethodInvocation`**：不带 `new` / `const` 的 `Node(...)` 在 analyzer 14 的 AST 里**不是** `InstanceCreationExpression`，只查后者会漏掉最常见的写法（首跑就漏了一条，被 `TC-INF-032` 抓住）。⚠️ **台账「八个语义槽位」实测只有七个**，差额疑为「可观测宇宙（根）」而根已由 `supercluster` 承担 —— 本笔按七个建枚举，差额待台账修订 |
| `v0.52.0` | 2026-10-19 | **`B4-R` 终端走查后的一笔**：§三 新增 §3.52 四条（`TC-PLAN-099`–`102`），用例 679 → **683**；Dart 643 → **647**（4 条 Widget）。§四 **不变** —— 四条都落在已覆盖的 `PLAN-007` / `014` / `017` 上，`SPEC` 覆盖数与缺口数不动。§3.51 两处**语义改写**：`092` 只覆盖「未选体系」（建完立刻选中仍成立）、`097` 由「被筛掉 + 需重选」改为「保留 + 不可选」—— 覆盖恒 0 是客户端写不了 `Item.sourceRefs`，不是用户选错。⚠️ **本笔起因**：沙箱 643 全绿之后做了终端走查 11 条。沙箱只证「行为」—— 每条 widget 用例自己摆初始状态，**从未跨屏串过一次**，也证不了真实窗口下的观感。⚠️ **两条真缺陷**：① ④ 确认排在 `ListView` 末尾，候选 4+2+3 条就要滚一屏多（实拍「滚到顶看不到 ④ 确认和建计划」）⇒ 固定左栏底部；② `Row(Expanded(3), Divider, Expanded(2))` 无下限，极窄时两栏各分到几十像素、文字**逐字竖排**、每张卡片挂 `RIGHT OVERFLOWED BY 52 PIXELS` ⇒ 断点 **720** 改上下堆叠。⚠️ **「需重选」现在只剩一条路径**：双向收窄下手动选择永远兼容，只有重入预填可能互不相容 —— 文案因此改为「「X」在当前体系下覆盖 0，已取消选择」，另一端按段取名。**未做**：`english` / `german` 两包 `excerpts` = 0（源段空 ⇒ 建不出计划）与树容器四边留白（`TreeView` 的 64 与外层 `_hudTopHeight` 叠加），均另排，不在本笔 |
| `v0.51.0` | 2026-10-19 | **`B4` 第 8 笔 `P-8` 三段「+ 自建」与重入复用**，§三 新增 §3.51 二十条（`TC-PLAN-079`–`098`），用例 659 → **679**；Dart 623 → **643**（12 条 Unit + 8 条 Widget）。§四 **重算** —— 有用例 71 → **73**（`PLAN-007` `011` 首次覆盖，两条首现行均标**显式**）、无用例 138 → **136**、`PLAN` 域有例 14 → **16**（缺口 8 → **6**，`SPEC` 总数仍 **22**）、A 类 130 → **128**。⚠️ **本笔开工前先探清三段的真实状态**：三段尾部的「+ 自建」此前是**灰色占位文字、零交互**；而 `loadCandidates` 的三个 user 通道 `P-2` 就打通了、面板**一个都没传** ⇒ 缺的是接线，不是能力。⚠️ **源的自建只能「登记」不能「完整」**：候选装载按 `Item.sourceRefs` 命中数算覆盖，客户端反向写不了 `sourceRefs` ⇒ 自建源恒为 0 覆盖；已选体系时它会被筛掉并标「需重选」，**不做特例**（`TC-PLAN-097` 锁的就是这个处置，且要求说出名字而不是内部 id）。⚠️ **体系 / 方法可完整**：体系的 `nodes` 就是 id 列表，但要接 `schemeNodesOf` —— 否则「自建的体系一选中就抛」（本笔第一个红就是这个，`TC-PLAN-093` 找不到自建体系的卡片）；方法一份 = 一个类型分支、自动包单类型 `MethodBundle`，不接 `userProfiles` 会「自建完反而被未覆盖拦住」。⚠️ **`PLAN-019` 的 `version + 1` 已被 `P-6` 推翻**，面板不碰版本；本笔只补两个接头：`PlannerScreen.open` 加 `revising` 取整份 `Plan` 的初值、`planId` 与预填同源。⚠️ **`TC-PLAN-096` 顺带钉住一处此前写着没验的语义**：五份平台方法分支确实都没有 `hint` ⇒ ③ 段要说出「本方法无提示可给」，自建带 `hint` 后提示消失。⚠️ **四处独立反证**红 4 / 2 / 2 / 1：撤面板喂自建 ⇒ `092` `093` `094` `095` 四条红；预览不喂自建 ⇒ `093` / `095` 两条红；撤配方 review 校验 ⇒ `084` / `094` 两条红；撤「空列表 / 空 map 丢弃」⇒ `080` 一条红。**新增两份文件**（`core/plan/user_content.dart` · `features/planner/user_draft_dialogs.dart`）、`core/constants.dart` 上收 `itemTypeLabels` / `layerLabels` 两份标签表（原 `detail_panel.dart` 的私有副本）⇒ `core/` 44 → **45 份**、`features/` 25 → **26 份**；`dart run tool/lint/check.dart` 由 123 → **127 文件** |
| `v0.50.0` | 2026-10-19 | **`B4` 第 7 笔 `P-7` 三入口与范围的选择式**，§三 新增 §3.50 十七条（`TC-PLAN-062`–`078`），用例 642 → **659**；Dart 606 → **623**（6 条 Unit + 11 条 Widget）。§四 **重算** —— `SPEC` 总数 208 → **209**（新增 `PLAN-022`）、有用例 68 → **71**、无用例 140 → **138**、`PLAN` 域 21 → **22**（有例 11 → **14**，缺口 10 → **8**）。⚠️ **本笔首刷把 §4.1 的增量错记为 +1**（只算 `PLAN-022`），误以为 `PLAN-016` / `017` 早有用例 —— 实扫第 2 列证明它们在 `P-7` 之前**从未出现过**，是 `D4` 对账抓出来的，已按实扫改成 `71 / 138 / 14 / 8`（连带 §4.2 A 类 132 → **130**、§4.2 正文两处 `208` → `209`）。⚠️ **本笔先做了探清，笔序表写的三个入口只有一个做得了**：进展视图「新建计划」的宿主全仓不存在（`ViewMode.progress` 在 `app/lib` 里零引用），它的规格是 `QUANT-011`、属 `B6` —— **不挂空回调**（那会得到一个永远点不到的按钮，而文档上显得已做），已在 `SPEC-PLAN-016` 的修订表里如实登记。⚠️ **`PlanTarget.selector` 的字段级结构此前从没定过**：`entity-fields` §8 只写「存选择式不存结果列表」，`P-6` 因此只能落空对象并明写「Z3/Z4 怎么表达归 P-7」。本笔定为四值判别式联合（`space` / `domain` / `item` / `query`），与 `PLAN-002`「粒度随视距」一一对应；`query` 存**词**不存 id 表（只存 id 会丢掉「按什么圈出来的」），不认识的 `kind` **抛错不回落**（回落成 `space` 会让「按子图建的计划」静默变成「整个空间」）。⚠️ **`PLAN-017` 只说了「不是什么」、没说「渲染在哪」**，本笔补定承载 = 一整页路由：抽屉会撞上 ⑤⑥、模态放不下 `PLAN-014` 的 iOS 三步分页。⚠️ **`EventStore` 全仓只有接口、零实现** ⇒ 「建 Plan 跑通」到「交出草稿」为止，草稿由 `UniverseScreen` 向上抛（`onPlanCreated`），持久化归后续批次，不假装做了。⚠️ **四处独立反证**红 1 / 1 / 2 / 1：撤域命中折算 ⇒ `065` 红；`item` 式不筛圈外 ⇒ `064` 红；撤「仅 `Z1`」条件 ⇒ `072` / `073` 红；撤「无回调不渲染」⇒ `078` 红。**新增两份文件**（`core/plan/plan_target.dart` · `features/planner/planner_screen.dart` ⇒ `core/` 43 → **44 份**、`features/` 24 → **25 份**）；**无新增常量** |
| `v0.49.0` | 2026-10-19 | **`B4` 第 6 笔 `P-6` 建 Plan 落事件 + `fold` 折出 `Plan`**，§三 新增 §3.49 十五条（`TC-PLAN-047`–`061`），用例 627 → **642**；Dart 591 → **606**（12 条 Unit + 1 条 Widget + 2 条 Unit 落在 `fold_test` 的计划组）。§四 **重算** —— 有用例 67 → **68**（`PLAN-003` 首次覆盖）、无用例 141 → **140**、`PLAN` 域 10 → **11**（缺口 11 → 10）、A 类 133 → **132**。⚠️ **`PLAN-019` 不在增量里** —— 它早由 `TC-PLAN-038` 覆盖，是 §4.1 的 `PLAN` 列表一直漏列它、而数字按实扫算，于是「数字写 10、列举只有 9 个」这个矛盾此前没被 `D4` 抓到（`D4` 只对数字，不对列举）。本笔把 `019` 补进列表。⚠️ **本笔开工前发现 `PLAN-003` 在事件层根本表达不出来**：`plan_created` 的 payload 没有 `planId`，同空间多份就分不开「改的是哪一份」。裁定 `Plan.id` **就是创建事件的 id**，`plan_revised` 带 `planId` 指回它。⚠️ **`version` 从 payload 里删掉**（原文写「`version = 前值 + 1`」）：那是第二份计数，`fold` 既数条数又读 payload，重传或乱序必然打架；改由 `fold` 数条数，与 `noteVersion` 同口径。⚠️ **`target` 的键原本三处不一致**（`resolvedCount` / `count` / 派生 `count`），统一为 `{selector, resolved}`，`count` 不序列化。⚠️ **顺带修一条自相矛盾的旧测试**：`target.count …不单独存` 那条，名字说不存、断言却是 `containsPair('count', 3)`，本笔改成 `isNot(contains('count'))`。⚠️ **三处独立反证**红 5 / 1 / 3：planId 改用 `spaceId` ⇒ 键变了，055–060 中 5 条红；`version` 改读 payload ⇒ `057` 红；落点不筛圈外项 ⇒ `043` / `050` / `051` 红（`043` 是 `P-5` 的用例，同源算法的证明）。**新增四份核心文件**（`core/events/id.dart` · `core/plan/scope.dart` · `core/plan/plan_events.dart` · `core/plan/plan_draft.dart` —— 四份 ⇒ `core/` 39 → **43 份**、`features/` 仍 **24 份**）；**无新增常量** |
| `v0.48.0` | 2026-10-19 | **`B4` 第 5 笔 `P-5` 预览的项数与 `target`**，§三 新增 §3.48 五条（`TC-PLAN-042`–`046`），用例 622 → **627**；Dart 586 → **591**（4 条 Unit + 1 条 Widget）。⚠️ **本笔先做了探清，结论与笔序表不同**：表里写「实时预览三项」，而 `computePlannerPreview` 在 `P-4` 就算出三项、实时性也通（`build()` 每次重算），`TC-PLAN-032`–`035` / `039` 已在验 —— 真正缺的是**项数没有定义**（`PLAN-015` 只定义了分母）与**`PlanTarget` 没接**（实体早在 `entities/plan.dart`）。⚠️ **顺带发现两条旧用例一直没咬住**：`TC-PLAN-032` 的夹具全在圈内，删掉 `preview.dart` 的 `where((i) => i.inScope)` 它照样绿 ⇒「分母 = 圈内项数」自 `P-4` 起是**写了没验**，本笔由 `TC-PLAN-043` 补上；`TC-PLAN-042` 则把规格验收表里那个 **140 分钟**第一次真正算出来。⚠️ **本笔改了规格**：`SPEC-PLAN-015` 补**项数 = 圈内项 ∩ 体系节点 ∩ `target`**、补「分母不随 `target` 变」及其理由（两笔差额混成一笔就分不开）、补「圈外项不进计划」（不拦会让项数超过分母）、补验收表两行。⚠️ **一处实现收紧**：体系分支原本按节点直取、不筛圈内，项数可能超过分母；改为在圈内项里按节点集合过滤。**无新增文件**（`core/` 仍 **39 份**、`features/` 仍 **24 份**）；**无新增常量** |
| `v0.47.0` | 2026-10-19 | **`B4` 第 4 笔 `P-4` Planner 面板骨架**，§三 新增 §3.47 十条（`TC-PLAN-032`–`041`），用例 612 → **622**；Dart 576 → **586**（4 条 Unit + 6 条 Widget）。左栏四段（源 → 体系 → 方法 → 确认）+ 右栏三项预览（项数 / 分母 / 时长）落地为 `features/planner/planner_panel.dart`，预览计算落 `core/plan/preview.dart`。⚠️ **本笔改了规格**（`v0.46.0` 之后单独一版 `docs(design)` 已写入）：`PLAN-014` 由「源决定体系」改为**双向**收窄，并在规格里补了「需重选」这个显式态 —— 它是 `TC-PLAN-005` 那条语义用例的界面侧唯一正确处置。⚠️ **一处实现纠正**：`PlanSegment` 的声明顺序原为 `scheme, source, method` 且注释声称「`P-4` 定：体系 → 源 → 方法」，而 `P-4` 当时尚未开工、规格一直写源 → 体系 → 方法 —— 注释是假的，枚举改为 `source, scheme, method`。⚠️ **`R2` 抓了一处**：预览的展示串 `(minutes / 60)` 落在核心层，核心层禁裸字面量 ⇒ 展示串整段挪到面板层。**新增** `core/plan/preview.dart` 一份（`core/` 38 → **39 份**）、`features/planner/` 一份（`features/` 23 → **24 份**）；**无新增常量** |
| `v0.46.0` | 2026-10-19 | **补 `D5`（头部读数）+ 修头部两处漏跟**，§3.46 十一条 → **十五条**，用例 608 → **612**；Dart 572 → **576**。⚠️ **缺陷形态**：`D1`–`D4` 管的全是「正文之间是否一致」，**头部状态行一处都不管** —— 于是 `flutter test` 读数自 `v0.43.0` 的 548 起连续两版没跟（`v0.44.0` 的 561、`v0.45.0` 的 572 都没写进去）。这不是笔误，是规则覆盖面的一个洞。⚠️ **新增 `D5`**：头部读数必须等于 `STR` **语义最大版号**那一轮的实跑数 —— 取最大不取最后一行，与 `D2` 同理由（`STR` 历史当下乱序，依赖位置就得先修表）。读数缺失只报警告不阻断：那是信息损失，不是两个数打架。⚠️ **同版删掉头部另一处重复读数**（`SPEC` 覆盖数只在 §4.1 写一份）—— 能不复制就不需要对账，这条比再加一条规则便宜。**一处规格未改** |
| `v0.45.0` | 2026-10-19 | **`B4` 前置 · 交付物一致性检查器落地**（`D1`–`D4`）+ §3.46 十一条自测，用例 597 → **608**。⚠️ **同版按 `D4` 实扫校正 §4.1**：`VIEW` 28→34、`ACC` 2→1，连带总量 60→65 / 148→143 与 §4.2 的 158→143、140→135。这不是又发现一处笔误，是同一类漏改的第三次 —— 前两次靠人眼在升版时撞见，这次是 `D4` 把「§4.1 说的」与「用例表第 2 列写的」直接对账。另：`STP` §5.1 长期少登 §3.38 的 5 条（`TC-VIEW-313`–`317`，分段 592 与合计 597 差 5），同版补登 |
| `v0.44.0` | 2026-10-19 | **`B4` 第 3 笔 · 排序键与逆序代价**，新增 §3.45 十三条（`TC-PLAN-019`–`031`），用例 584 → **597**。三件事：① 源按 `authorityLevel` 秩（`L0 L1 L2 L4`，未知排最后不抛错）；② 体系按**逆序数**升序，并给出「第 N 步会卡在哪」；③ 方法按 **`Item.type` 覆盖率**降序，分母是集合内实际出现的类型数。⚠️ **`TC-PLAN-006` 的断言被改强**（原「位置留在首次出现处」→「整条记录被覆盖」），原因见 §3.45 起首。⚠️ **同版按实扫修正 §4.1 按域表** —— `v0.43.0` 时只改了正文总数，`PLAN` 行仍写 0、`ACC` 行仍写 0，与正文自相矛盾 |
| `v0.43.0` | 2026-10-19 | §三 新增 §3.44（17 条：`TC-PLAN-002`–`018`，`B4` 第 2 笔候选装载与双向收窄），**584 条**；Dart 531 → **548**（17 条 Unit）。§四 重算：有对应用例的 `SPEC` 52 → **57**（`PLAN-006` / `008` / `010` / `014` / `020` 首次覆盖）。⚠️ 本笔**改了规格**：`PLAN-014` 的「源决定体系候选」按实证修订为**双向**（α 包 `scheme-first-week` 45 节点里 `pep-484` 与 `python-asyncio-docs` 覆盖 0）；新增 `MethodBundle` 一层，`Plan.methodProfileId` 仍存单个字符串。⚠️ `TC-PLAN-005` 是语义用例：两段各自收窄后，已选值会从两侧列表里消失 —— 这不是缺陷，是 `P-4` 要显式标出的「需重选」态 |
| `v0.42.0` | 2026-10-19 | §三 新增 §3.43（3 条：`TC-ACC-001`–`003`，`B4` 第 1 笔 `userId` 进信封），**567 条**；Dart 528 → **531**（3 条 Unit）。§四 重算：有对应用例的 `SPEC` 50 → **52**（`ACC-013` / `ACC-014` 首次覆盖）；`ACC` 域由 0 条用例升至 3 条，余 9 条仍随 `B10`。⚠️ 本笔**未改任何规格**：`event-types.md` §一 的信封里 `userId` 一直在、`ACC-014` 也写明「`fold` 必须支持 `userId` 过滤」，落后的是代码（`Event` 无此字段、`fold` 无此维度）—— 与 `V-1h` 同一种形态。⚠️ 新增 `C-93`（本地默认 `userId` = `local`）：取恒定值而非空串，因为 `null` 会让「这条属于谁」多出第三态，之后每处读取都得特判 |
| `v0.41.0` | 2026-10-19 | §三 新增 §3.42（10 条：`TC-VIEW-374`–`383`，`V-1h` 树四层与树里换根），**564 条**；Dart 518 → **528**（2 条 Unit + 8 条 Widget）。§四 **不重算** —— `VIEW-006` 修订与 `VIEW-009` 修订早在 `#61` 就有验收行，本笔是它们的落地。⚠️ 三点如实登记：① **本笔未改任何规格**，是把已裁定的修订落地（`_zoomForSelection` 原先按 `φ` 定档，与 `VIEW-009` 修订第 2 条直接冲突）；② **两条旧用例的判据被改锐**（`树里详情常驻右栏` → `没选中就不开抽屉`；`按 φ 定档` → `项一律 Z4`），不是新增；③ **两处规格没写、由实现补的裁定**（`知识` 名字不可点 · 当前根挂「当前」标签），已在 `VIEW-006` 落地状态标「请评审确认」 |
| `v0.40.0` | 2026-10-19 | §三 新增 §3.41（3 条：`TC-VIEW-371`–`373`，`V-1g` 搜索四类落点），**554 条**；Dart 515 → **518**（3 条 Widget）。⚠️ **本笔的实际内容与笔序表写的不同**：表里写「四类落点**重写**」，探清后四类早在 `B3` 笔 4a / 7 / 10 与 `V-1a` 修订里就改完了 —— 缺的是**域那一路的证据**（此前一条用例都没有），以及「落点不看发起视图」这条从没验过的边界。本笔补这三条，不改落点代码（`git diff lib/` 为空）。⚠️ 同笔纠正 `VIEW-031` 验收表一处**规格残留**：一行仍写「空间命中落 `Z0`」，与 `VIEW-027` 两行的 `Z1` 互相打脸；代码与断言一直是 `Z1`，属文档没跟上。⚠️ `VIEW-029` 的第三键「未学优先」仍未实现（要掌握度，归 `B6`），`locator.dart` 写明，不假装做了 |
| `v0.39.0` | 2026-10-19 | §三 新增 §3.40（24 条：`TC-VIEW-347`–`370`，`V-1i` **后半**把相位铺满 `Z0` / `Z2` / `Z3` / `Z4`），**551 条**；Dart 489 → **515**（19 条 Unit + 5 条 Widget）。§四 **不重算** —— `VIEW-036`–`040` 早有用例，本笔是它们的运动条款落地。⚠️ 四点如实登记：① **`Z0` 的 `C-54` 在那一档仍不可观测**（盘只有一枚椭圆、无内部图案），该档只接 `C-55` 构型公转；② **`Z0` 是刚体旋转，遮挡不重判** —— 起草时写的「不重判描边会停在上帧」是**错的**，相对位置逐字不变，已把前提落成可执行断言（`TC-VIEW-351`）；③ **`Z3` / `Z4` 的周期只由层号定**，反证实测：改成读本档 `a` 会让 `TC-VIEW-363` 红；④ **两条用例自己也有毛病**，被反证挑出：`TC-VIEW-368` 原先比「当前 vs `t=0`」，时钟冻在非零值时照样绿（改成比「推进前后」）；`TC-VIEW-366` 原先比「前后相等」，两端都错时差值仍相等（改成比 `C-52` 的绝对半径）。⚠️ **规格有一处修订**：`VIEW-036` 原写「`Z0` 不给 `C-57`」，`C-55` 落地后盘持续以约 16 px/s 移动，那条前提已削弱 ⇒ `Z0` 改为也接停转 |
| `v0.38.0` | 2026-10-18 | §三 新增 §3.39（29 条：`TC-VIEW-318`–`346`，`V-1i` **前半**的时钟 + `Z1` 盘转 + 减速停转），**527 条**；Dart 460 → **489**（24 条 Unit + 5 条 Widget）。§四 **不重算** —— `VIEW-037` 早在 `v0.15.0` 就有用例，`C-54` / `C-57` 是它的运动条款落地。⚠️ 四点如实登记：① **时钟是累计秒数**（`C-56` 的轨道周期不整除 `C-55` 的 72 s，取控制器进度会在归零那一帧跳位）；② **布局拆两段**（构建缓存 + 逐帧只做旋转），否则逐帧重算拓扑；③ **相位只有一个来源**（拾取与标注都读同一份 `spun` 布局，painter 一行未改）；④ 证据力是**三处独立反证**实测的（`spun` 恒等 ⇒ 6 条红；`governorFactor` 恒常速 ⇒ `TC-VIEW-343` 红；失焦不清指针 ⇒ `TC-VIEW-345` 红）—— 其中第一次的反证写法（`distance <= stopRadius` 改 `<= 0`）**没红**，因为负系数被 `advanceClock` 挡住，两条防线互相掩护。⚠️ **本笔未实现**：`VIEW-037` 的「移动端长按 ≥ 400 ms 停转 + 抑制 tap」—— 触屏无 hover，该路径本笔不触发 |
| `v0.37.0` | 2026-10-18 | §三 新增 §3.38（5 条：`TC-VIEW-313`–`317`，`V-1f2` **插笔**的多根取值域 + 筛空明示），**498 条**；Dart 455 → **460**（2 条 Unit + 3 条 Widget）。§四 **不重算** —— `VIEW-020` 早在 `v0.18.0` 就有用例，本笔是它的第二处修订。⚠️ 三点如实登记：① **缺陷是用户截图报的**（「六轴罗盘学科，新增的两个语言好像没有」），实测 `axisValuesOf` 只读当前根，`Z0` 的「学科」于是只有 α 的取值；本笔只改「值从哪来」，**不改落点**（`Z0` 下选值落到哪一档仍归 `VIEW-028`，留给 `V-1g`）。② **顺带补一条筛选口径**：换根后筛选跟着过去（`VIEW-028`），而新根可能一项都不匹配 ⇒ 画面全空，与「渲染坏了」同形；新增 `VIEW-020` 修订 5 第 6 条与 `hudNoMatchKey` 一行说明，`Z0` 不出（那一档画星系、本就不受筛选影响），且包 `IgnorePointer` 让域点照旧可点。③ **证据力是两处独立反证实测的**：取值域退回单包 ⇒ `TC-VIEW-315` 红；`noMatch` 条件短路 ⇒ `TC-VIEW-317` 红 |
| `v0.36.0` | 2026-10-18 | §三 新增 §3.37（17 条：`TC-VIEW-296`–`312`，`V-1f` **后半**的 `Z4` 恒星特写），**493 条**；Dart 438 → **455**（14 条 Unit + 3 条 Widget）。§四 **重算** —— 有用例 49 → **50**（`VIEW-040` 首次覆盖）、缺口 159 → **158**、A 类 151 → **150**、B 类仍 8、C 类仍 0。⚠️ 四点如实登记：① **`V-1f` 是笔序表里的两半**（`Z4` 恒星特写 + 快照补 `domainId`），`PR #68` 只交了后半，此前「`VIEW-040` 不在 `B12` 九笔里」的判断是照 `V-1e` 的 PR 描述推的、没回查首版笔序表，**错了**；② `Z4` 从项投影换成恒星特写后**画布不再拾取**（`VIEW-001` 的 `Z4` 行「可点对象 —」），改前是按项投影坐标判命中而画面根本不画项投影；③ `C-79` / `C-80` 两条轨道比例**不承载语义**，真实里行星在画面外几十个恒星直径处；④ 证据力是**三次独立反证**实测的（painter 退回项投影 ⇒ 3 条 Widget 全红；`C-81` 2→99 ⇒ 2 条红；`C-78` 0.46→0.045 ⇒ 2 条红） |
| `v0.35.0` | 2026-10-18 | §三 新增 §3.36（3 条：`TC-VIEW-293`–`295`，`V-1f` 的 `returnTo` 快照加 `domainId`），**476 条**；Dart 435 → **438**（1 条 Unit + 2 条 Widget）。`TC-VIEW-161` / `162` 原地修订 —— `ViewSnapshot` 加 `domainId`，字段六 → **七**，「可缺」从三项变四项（与 `v0.24.0` 加 `spaceId` 同一手法）。§四 **不变** —— `VIEW-015` 早在 `v0.21.0` 就有用例（`TC-VIEW-161`），本笔补的是它的**第三处修订**（域推不出来），不是新覆盖面。⚠️ 证据力实测：改前 `TC-VIEW-294` **红在「面包屑只剩 2 段」**，补齐实现后转绿；`TC-VIEW-295` 改前改后都绿 ⇒ 只作护栏，不当缺陷证据。⚠️ 顺带说明两条**没有**做的：`Z1` / `Z0` 的快照不带域（判据是「目标档位画不画域」，不是「离开时在不在域里」）、`Z3` / `Z4` 的域仍由选中项反推（存下来会多一条可能与选中项不一致的真相） |
| `v0.34.0` | 2026-10-18 | §三 新增 §3.35（23 条：`TC-VIEW-270`–`292`，`V-1e` 的 `Z3` 恒星系），**473 条**；Dart 412 → **435**（18 条 Unit + 5 条 Widget）。§四 **重算** —— 有用例 48 → **49**（`VIEW-039` 首次覆盖）、缺口 160 → **159**、A 类 152 → **151**、B 类仍 8、C 类仍 0。⚠️ 四处如实登记：**`VIEW-039` 三条真实约束只兑现两条**（开普勒 `T ∝ a^1.5` 要运动，本笔只有静态相位，`C-56` 归运动那一笔）、**`θ` 与 `r` 同时退化**（`Z0`–`Z3` 里第一次）、**同层多颗共轨是妥协**、**证据力是实测的**（布局恒空 ⇒ 5 条 Widget 全红；只短路拾取 ⇒ 形态那条绿、拾取 4 条红）。⚠️ 顺带修两处误引：`C-67` / `C-76` 的「命中半径 24 px」把 `domainMarkMinTapDiameter`（**直径**）当成了半径 |
| `v0.33.0` | 2026-10-18 | §三 新增 §3.34（18 条：`TC-VIEW-252`–`269`，`V-1d2` 的标注避让 + 绘制常量提号），**450 条**；Dart 394 → **412**（13 条 Unit + 5 条 Widget）。⚠️ **§四 不重算** —— 这一笔不覆盖任何新 `SPEC`，有用例仍 48、缺口仍 160、A 类 152、B 类 8、C 类 0。⚠️ 如实登记两处：**`Z0` 那条在旧实现下也绿**（夹具复现不出真机那 36 px 盘缝，只作护栏）、**`C-64`–`C-69` 提号不改值**（曾据「臂 1 px」的错误前提打算调宽，实读是 6 px + 模糊） |
| `v0.32.0` | 2026-10-18 | §三 新增 §3.33（20 条：`TC-VIEW-232`–`251`，`V-1d` 的 `Z2` 分子云），**432 条**；Dart 374 → **394**（`flutter test` 实跑 **394**：新增 14 条 Unit + 6 条 Widget）。§四 **重算** —— 有用例 47 → **48**（`VIEW-038` 首次覆盖）、缺口 161 → **160**、A 类 153 → **152**、B 类仍 8、C 类仍 0。⚠️ **连带改 6 条既有用例**：「点星进详情」那几条原先在 `Z2` 用 `pickSceneNode` 找落点，`Z2` 自本笔起是云（`layoutNebula` 那一套几何）⇒ 落点改按云的布局算；判据（选中 / 返回 / 跨空白）没变，变的是位置怎么算。⚠️ **本笔抓到一处静默缺陷**：⑤「焦点星」占位是普通 `Container`、正落在屏幕正中，`Z2` 云心那一项就在它下面 ⇒ 点上去什么都不发生（`TC-VIEW-251`）。同类隐患在 `Z0` / `Z1` 的标注层也存在（文字压在画布上会吃掉手势），三处一并包了 `IgnorePointer` |
| `v0.30.0` | 2026-10-18 | §三 新增 §3.31（16 条：`TC-VIEW-198`–`213`，`V-1b` 的 `Z0` 宇宙层），**394 条**；Dart 340 → **356**（`flutter test` 实跑 **356**）。§四 **不变** —— `VIEW-036` 此前只有「面包屑不写空间名」这类间接覆盖，本笔才有直接断言。⚠️ 连带改一条既有用例：`TC-VIEW-197` 原本「点第 1 段回 `Z0` → **再点同一颗星**」——`Z0` 自本笔起不出项，那一步点到的是星系、落点变成换根，故改成退到 `Z1` 再点星。**判据（`returnTo` 不残留）没变，变的是可走的路** |
| `v0.29.0` | 2026-10-18 | §三 新增 §3.30（12 条：`TC-VIEW-186`–`197`，`V-1a` 的 ① 面包屑与图标），**378 条**；Dart 334 → **340**（`flutter test` 实跑 **340**）。作废 6 条并**保留行**（`048` `049` `075` `183`–`185`）：⑦ 视距刻度条作废 ⇒ 「点刻度进 Z4」「五档刻度全在」「树里点刻度」三条失去入口；换根 chips 撤掉 ⇒ 三条失去被测对象。判据从「面包屑写档名」改为「段数 = 档位」：`Z0` 1 段 · `Z1` 2 段 · `Z2` 3 段 · `Z4` 4 段（`Z3` 与 `Z4` 同形，靠抽屉区分）。§四 **不变** —— `VIEW-018` 早已在有用例内（`TC-VIEW-047`），本笔改的是它的判据而不是覆盖面。⚠️ 顺带修一条 `_navigate` 的静默缺陷：离开详情时 `returnTo` 不清理，`Z4` 退层后再进详情，返回按钮会跳回**上一颗星** —— `TC-VIEW-197` 锁住这半边 |
| `v0.28.0` | 2026-10-18 | §三 新增 §3.29（3 条：换根 chips 存在性 1 · 树里不给 1 · 点击换根 1），**366 条**；Dart 331 → **334**（`flutter test` 实跑 **334**）。起因是**用户在屏幕上数不出三个空间** —— 包都装了、`Z0` 也一次装了三个根，但 `VIEW-031` 的两条路都在定位浮层里，不给屏幕入口就看不出多根。① 面包屑右侧加一排 chips，点击复用 `_jumpToSpace`。两处刻意不给：单根时整排消失、树里不渲染。§四 **不变**（`VIEW-031` 早已有用例） |
| `v0.27.0` | 2026-10-18 | §三 新增 §3.28（1 条：`TC-PACK-047`，`english` / `german` 两个新空间各自独立成包），**363 条**；Dart 330 → **331**（`flutter test` 实跑 **331**）。两个空间（各 80 项 · 84 边 · 8 域）与 α 包**刻意不同域数**，换根时星图分段数一眼可辨。§四 **不变**（`PACK-001` 已在有用例内）。⚠️ 本笔连带修掉一处两边判据不一致：`sourceRefs` 客户端必填、校验器原先不查 ⇒ 省略时「校验绿、整个空间装不出来」；校验器已同口径，反证 80 条会红 |
| `v0.26.0` | 2026-10-18 | §三 新增 §3.27（2 条：`TC-VIEW-181` `182`，⑥ 罗盘六轴一行），**362 条**；Dart 327 → **329**（`flutter test` 实跑 **330**）。这两条**没有 `SPEC` 依据** —— `VIEW-019` / `020` 只规定「六个轴按钮」与「已选数量写在按钮上」，没规定排几行；要求一行属观感口径，故追溯列写「—」。§四 **不变** |
| `v0.25.0` | 2026-10-18 | **用例数不变（360）**，两件事：① `C-28` 裁定为「v0.1 不适用」（模糊档 = 子串包含），`TC-QUANT-007` **改靶** —— 原锁「读 `fuzzyMatchThreshold` 即抛 `TbdConstantError`」，该常量已删、哨兵无使用者，现锁裁定内容本身（连续包含才命中、跨字不命中）；编号与域不动（§一 编号稳定），落点从 `constants_test.dart` 挪到 `locator_test.dart`。② §3.23 段首与 `TC-VIEW-154` 的滞后表述回填：原写「`C-21` 上限未定」是**错的**（`C-21` 早定为 5，缺的是 `trail` 与多根），两者已由笔 10 关闭。`TC-VIEW-114` 的预期也随之去掉「仍是 `TbdConstantError`」 |
| `v0.24.0` | 2026-10-18 | §三 新增 §3.26（11 条：`TrailStep` 带空间 1 · 屏幕换根与返回 7 · 多根装配 3），**360 条**；Dart 316 → **327**（`flutter test` 实跑 328，差额是同一条不入表的冒烟用例）。`TC-VIEW-161` / `162` 原地修订 —— `ViewSnapshot` 加 `spaceId`，「可缺」从两项变三项。§四 **不变**：新增用例没有一条首次覆盖新 `SPEC`。`TC-VIEW-174`–`180` 依赖两个根（α 包 + 1 项的夹具包），单根下那段代码不可达 |
| `v0.23.0` | 2026-10-18 | **§三 不增（349 条不变）**，§四 重算 —— `SPEC` 总数 171 → **203**（`ACC` 15 · `SYNC` 16 · `VIEW-035` 1），有用例仍 **45**，缺口 126 → **158**。新增两域的依据见 [`ADR-0004`](../../decisions/0004-accounts-as-usage-prerequisite.md)。**本版刻意不写用例**：两域一行代码都没有，为未实现模块编用例等于用构造出来的证据冒充验证（`X-05`）。用例随 `B10` / `B11` 落地补，已登记进 §五 第 13 项 |
| `v0.22.0` | 2026-10-18 | §三 新增 §3.25（3 条：树圈外邻项 1 · α 包空间级声明 2），**349 条**；Dart 313 → **316**（`flutter test` 实跑 317）。§四 **不变** —— 三条都没首次覆盖新 `SPEC`（`VIEW-004` 早有 `TC-VIEW-051`，`PACK-005` 早有 `TC-PACK-019`）；它们补的是**分支与链路**，不是覆盖面。`TC-VIEW-172` 必须用夹具：α 包零圈外项，那条分支在真包上不可达。 |
| `v0.21.0` | 2026-10-18 | §三 新增 §3.24（16 条：纯逻辑 10 · 屏幕 4 · 面板 2），**346 条**；Dart 297 → **313**（`flutter test` 实跑 314）。§四 重算 —— `VIEW-015` `VIEW-016` **首次有用例**，覆盖 43 → **45**、缺口 128 → **126**；顺手修正域表合计行（上一版仍写 42 / 129，与头部 43 / 128 不一致）。另记五处实施裁定：`returnTo` 只在「详情从不可见变为可见」时记；`trail` 压**离开的那一项**、超 `C-21` 丢最旧、不去重；返回先 `trail` 后 `returnTo`；退无可退时按钮**不渲染**；`ViewSnapshot.hashCode` 必须**先排序再算**（照 `entries` 顺序算会与按集合比的 `==` 冲突 —— 这条是 `TC-VIEW-163` 抓出来的真 bug） |
| `v0.20.0` | 2026-10-17 | §三 新增 §3.23（9 条：引擎 6 · 浮层 2 · 屏幕 1），**330 条**；Dart 288 → **297**（`flutter test` 实跑 298）。§四 重算 —— `VIEW-031` **首次有用例**，覆盖 42 → **43**、缺口 129 → **128**。`TC-VIEW-096` 的预期随「前缀由命中集推」改写（原文按 `spacePrefix` 入参取有 / 无）。另记三处实施裁定：`Locator` 收「一组包 + 可选作用域」，作用域不匹配**不放宽**；跨空间命中照常列出但点下去只说明、不换根；去重键带空间 |
| `v0.19.0` | 2026-10-17 | §三 新增 §3.22（3 条：封顶判据 2 · 4K 接线 1），**321 条**；Dart 285 → **288**（`flutter test` 实跑 289）。§四 **不变** —— 三条守的是 `C-33` 的面积口径与接线，没有一条首次覆盖某条 `SPEC`。另记三处实施裁定：封顶判**物理面积**（`w·h·dpr²`，基准面积不乘 dpr）；`CustomPaint.size` 只是 preferred、尺寸须由 `SizedBox` 强制给；`FittedBox` 在 loose 约束下只缩不放，外层必须给 tight 窗口尺寸 |
| `v0.18.0` | 2026-10-17 | §三 新增 §3.21（19 条：拾取几何 5 · 装配 4 · 罗盘取值域 5 · 界面接线 5），**318 条**；Dart 266 → **285**（`flutter test` 实跑 286）。§四 重算 —— `VIEW-020` **首次有用例**，覆盖 41 → **42**、缺口 130 → **129**。另记三处实施裁定：拾取圆 = 绘制圆（不再算第二份半径，只补 `C-44` 下限）；`drawOrder` 要**反向**遍历（画家序是远→近，用户点的是近的那颗）；点空白不改选中 |
| `v0.17.0` | 2026-10-17 | §三 新增 §3.20（22 条：分诊判据 13 · 分诊面板与表单 6 · 路由与快捷键 3），**299 条**；Dart 244 → **266**（`flutter test` 实跑 267）。`TC-VIEW-095` 的预期随分诊改写（原文「只说没有命中」）。§四 重算 —— `VIEW-032` **首次有用例**，覆盖 40 → **41**、缺口 131 → **130**。另记两处实施裁定：圈外项留在命中集但不算可落点（存在性 ≠ 可用性）；关浮层后必须收回焦点，否则 `⌘K` 只灵一次 |
| `v0.16.0` | 2026-10-17 | §三 新增 §3.17–3.19（26 条：筛选 DNF 12 · 定位浮层 9 · 路由与 ② 5），**277 条**；Dart 218 → **244**。§四 重算 —— `VIEW-019` `021` `024` `026` `030` `033` **首次有用例**（`027` `028` `029` 本已有），覆盖 34 → 40、缺口 137 → 131。另记 `VIEW-027` 修订：落点 = `Z4`，不按 `φ` 定档 |
| `v0.15.0` | 2026-10-17 | §三 新增 §3.14–3.16（23 条：树视图 6 · 详情三区 11 · 视图切换 6）并补 `TC-INF-024` `025`（`R4` 收窄的边界），**251 条**；Dart 193 → **218**。§四 重算 —— `VIEW-009` `010` `011` `012` `014` `017` 与 `FND-004` · `NOTE-007` **首次有用例**（26 → 34，缺口 145 → 137）。另记 `R4` 判据收窄：原「`features/**` 一律不许出现源」与 `SPEC-VIEW-004`「源只写进详情页」直接矛盾，现限定为视觉通道文件 |
| `v0.14.0` | 2026-10-17 | §三 新增 §3.13 `VIEW` 域（续五）`TC-VIEW-050`–`053`（4 条：域序 · 首屏展开 · 域内排序 · 黑洞行），**226 条**；Dart 185 → **193** |
| `v0.13.0` | 2026-10-17 | §三 新增 §3.12 `VIEW` 域（续四）`TC-VIEW-044`–`049`（6 条：视口封顶 3 · HUD 规则 3），**222 条**；Dart 176 → **185** |
| `v0.12.0` | 2026-10-17 | §三 新增 §3.11 `VIEW` 域（续三）`TC-VIEW-039`–`043`（5 条：域带段数 · `φ` 分位 · `C-34` 命中集 · 占位节点 · 主轴继承），**216 条**；`TC-VIEW-036` 预期由「150 节点 / 167 边」改为「153 节点（含 3 占位）/ 170 条边」——`ADR-0003` §决策 5 让指向未知不再丢边。Dart 用例 171 → **176** |
| `v0.11.0` | 2026-10-17 | **用例数不变（211）**：§五 第 8–10 项（「主取值」缺承载位 / 「指向未知」无视觉 / `φ` 归一无口径）**三项同时闭环**，裁定见 `ADR-0003`（新增 `Item.primaryAxis` · 沿用 `VIEW-007` 黑洞 · `φ` 改累计分位映射 · `r` 改域带）。原拟的 `φ` 分段折叠被实算否掉（`φ ≥ 10` 占 84% 项）。本版不新增 `TC-` 编号：新裁定属 `B3` 未开工范围，断言随视图层落地 |
| `v0.10.0` | 2026-10-17 | **用例数不变（211）**：§五 第 11 项（`C-32` 待真机实测）标为**已闭环** —— 四组读数（三档 + 一次窗口对照）记入 `STR` 轮次 `R1`（已出仓），判据补测量前提 `C-33`；§五 新增第 12 项登记合成场景的虚线比例偏差。本版不新增 `TC-` 编号：帧率由判据直接裁定，不是用例行为 |
| `v0.9.0` | 2026-10-17 | **只修口径，用例数不变（211）**：§五 待补第 4 项括注「`--suite` 最后一步」改为「其中一步」—— 该轮之后 `--suite` 增至四层（第四层「输出可移植性」见 `STP` §七），错误码覆盖不再位于末位。本版不新增 `TC-` 编号：可移植性自检是工具链健康约束，不是某条 `SPEC` 的行为 |
| `v0.8.0` | 2026-10-17 | §三 新增 §3.10 `VIEW` 域（续二）`TC-VIEW-019`–`038`（20 条：绘制计数 6 · 帧时序 6 · 场景装配 6 · 页面 2）；§四 **不变** —— 新增用例守的是「调用数」与「时序算法」，没有一条首次覆盖某条 `SPEC`（`VIEW-002` / `PACK-018` 此前已有用例）。本节**不测帧率**：`FrameTiming` 只在真设备上产生 |
| `v0.7.0` | 2026-10-17 | §三 新增 §3.9 `VIEW` 域（续）`TC-VIEW-002`–`018`（17 条：`φ` 层号 9 · 投影 8）；§四 重算 —— `VIEW-002` 首次有用例（25 → 26、缺口 146 → 145、A 类 138 → 137），B 类仍 8 条；§五 登记 `B3` 开工前的三项待核。**本版为补记**：第 4 笔的代码与用例已随 PR #33 合并，当时只改了 `constants.md`，`STD` 滞后一版 |
| `v0.6.0` | 2026-10-17 | §三 新增 §3.8 `EVT` 域 `TC-EVT-001`–`048`（48 条：发号 13 · 游标与判定 10 · 幂等/空间/快照/孤儿 6 · 笔记 5 · 迁移账本 2 · 坏事件 3 · 折算函数 9）；§四 重算 —— `FND-010` 移出 B 类（9 → 8），B 类列修正为与 §4.3 行数一致，补记 `FND-003` 的差分重叠 |
| `v0.5.0` | 2026-10-17 | §三 新增 §3.7 `LOAD` 域 `TC-LOAD-001`–`040`（40 条：枚举同源 3 · 路径探测 6 · 包解析 9 · 环检测 6 · 定位引擎 12 · 真实 α 包 4）；§四 重算 —— `FND-008` / `VIEW-025` `027` `028` `029` / `PACK-018` 由 A 转「有用例」，`FND-004` 移出 B 类（10 → 9），A 类 143 → 138 |
| `v0.4.0` | 2026-10-17 | §三 补 `TC-INF-011`–`023`（13 条：`R3` 5 · `R4` 4 · `R5` 4）；§四 重算 —— `FND-012` / `VIEW-004` 由 B 转「有用例」，5 条借位映射降级进 B 类，**C 类清零**；§五 待补第 1 · 2 · 5 · 6 项关闭 |
| `v0.3.0` | 2026-10-17 | §三 补 `TC-PACK-011`–`041`（31 条管线用例，覆盖 `validator.py` 余下 29 个错误码 + 1 条产物层正例）；§五 待补第 4 项关闭 |
| `v0.2.0` | 2026-10-17 | **追溯补录** §三 用例表（42 条：Dart 33 + 管线 9）、§四 覆盖缺口、§五 待补清单 |
| `v0.1.0` | 2026-10-17 | 首建。确立用例编号与格式；用例表待补 |

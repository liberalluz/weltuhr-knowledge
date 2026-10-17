# 软件测试说明（STD）

> **版号**：`v0.2.0` · **状态**：§三 用例表已按既有测试反推填齐（42 条），§四 覆盖缺口已算
> 本文件是**用例正文**。测什么与通过判据见 [`STP`](STP-软件测试计划.md)，实际执行结果见 [`STR`](STR-软件测试报告.md)。
> **追溯补录**：2026-10-17 · §三 依据 `app/test/` 与 `content/tools/fixtures/` 的既有测试逐条反推，非当时所写。

## 修订历史

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建。确立用例编号与格式；用例表待补 |
| `v0.2.0` | 2026-10-17 | **追溯补录** §三 用例表（42 条：Dart 33 + 管线 9）、§四 覆盖缺口、§五 待补清单 |

---

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
| `TC-PACK-001` | — | — | 一份合法 `Item` JSON | `fromJson(toJson())` | `id`/`sixAxis`/`layer`/`type`/`requirements` 全部往返保真 | 单元 | `app/test/core/entities_test.dart` · `fromJson(toJson()) 往返保真` |
| `TC-PACK-002` | `PACK-009` | 语义 | 同上，但 `requirements` 删掉 `tacit` 一格 | `fromJson` | 抛 `FormatException`，**不补默认值** | 单元 | 同上 · `六要件缺一格即格式错误（不补默认值）` |
| `TC-PACK-003` | `PACK-005` | 语义 | `valid-min`（五段齐全、六要件三态齐全、含一条 `type=unknown` 边） | `verify.py` 跑该 fixture | 退出码 0；`scheme-official-tutorial` 的 `inversions` = 0 | 管线 | `fixtures/valid-min/expect.json` |
| `TC-PACK-004` | `PACK-008` | 语义 | `neg-dupid`：两项共用同一 `Item.id` | 同上 | 退出码 1，含 `E-ID-DUP` | 管线 | `fixtures/neg-dupid/expect.json` |
| `TC-PACK-005` | `PACK-001` | **显式** | `neg-no-order`：文件在、段齐，但 `edges` 为空 | 同上 | 退出码 1，含 `E-SPACE-NO-ORDER`（无独立 `⪯` ⇒ 应降为域而非成包） | 管线 | `fixtures/neg-no-order/expect.json` |
| `TC-PACK-006` | `PACK-009` | 语义 | `neg-req-value`：三态出现 `partial` | 同上 | 退出码 1，含 `E-REQ-VALUE`（三态只允许 present/missing/not_externalizable） | 管线 | `fixtures/neg-req-value/expect.json` |
| `TC-PACK-007` | `PACK-009` | **显式** | `neg-requirements`：`function` 缺 `tacit`；`class` 的 `relation` 为 `null` | 同上 | 退出码 1，含 `E-REQ-KEY` **与** `E-REQ-STATE`（两者都要报，不是只报第一个） | 管线 | `fixtures/neg-requirements/expect.json` |
| `TC-PACK-008` | `PACK-005` | 语义 | `neg-version-space`：`manifest.version` 带前导空格 | 同上 | 退出码 1，含 `E-VERSION-FORMAT`；**不得静默 strip** | 管线 | `fixtures/neg-version-space/expect.json` |
| `TC-PACK-009` | `PACK-008` · `FND-013` | **显式** | `neg-versioned-id`：`Item.id` 写成 `python/decorator@2.1.0` | 同上 | 退出码 1，含 `E-ID-VERSIONED` | 管线 | `fixtures/neg-versioned-id/expect.json` |
| `TC-PACK-010` | `PACK-005` | **显式** | `valid-inversion`：`nodes` 把 `class` 排在 `function` 之前 | 同上 | 退出码 0（逆序**不禁止**），但 `inversions` 必须算出 = 1 | 管线 | `fixtures/valid-inversion/expect.json` |

> ⚠️ **`TC-PACK-010` 的标号待核**：fixture 的 note 写「`SPEC-PACK-005`：逆序不禁止，但必须算出 inversions」，而 `PACK-005` 标题是「pack 五段 + `meta` 信封」；逆序语义更贴近 `SPEC-PLAN-012`「逆序不禁止，但必须算清并显示」。此处按 **note 原文**登记（不擅自改源码），并列入 §五 待核项。

### 3.3 `QUANT` 域（9 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-QUANT-001` | — | — | 常量表 | 读 `sZeroDays` / `graduationSDays` | `30` / `180`（= `C-01` / `C-02`） | 单元 | `app/test/core/constants_test.dart` · `C-01 / C-02` |
| `TC-QUANT-002` | — | — | 同上 | 读 `fsrsTargetRetention` / `checkinCap` | `0.90` / `0.5`（= `C-03` / `C-25`，2026-10-17 裁定值） | 单元 | 同上 · `C-03 / C-25` |
| `TC-QUANT-003` | — | — | 同上 | 读会话、配额、失败阈值 | `sessionBudgetMinutes=25` · `reviewPoolCap=20` · `newPoolCap=5` · `failStreakToGap=2` · `skipStreakHint=3` · `skipEventsWritten=0`（`C-05`–`C-11`） | 单元 | 同上 · `C-05…C-11` |
| `TC-QUANT-004` | — | — | `carryRatio` | 传 2 / 4 / 0 | `0.5` / `0.25` / 抛 `ArgumentError`（`C-12` 拒绝非法拆分数） | 单元 | 同上 · `C-12 carryRatio` |
| `TC-QUANT-005` | `STEP-012` | 语义 | 六类算子枚举 | 比 `operatorMinutes.length` 与枚举长度；逐项读系数 | 等长；`read=3` `example=2` `recall=1` `practice=5` `teach=5` `build=30`（`C-14`–`C-19`） | 单元 | 同上 · `C-14…C-19` |
| `TC-QUANT-006` | `STEP-022` | 语义 | 常量表 | 读 `scaffoldCap` | `Grade.pass`（`C-26`：脚手架封顶到「合格」，熟练档关闭） | 单元 | 同上 · `C-26 脚手架封顶` |
| `TC-QUANT-007` | — | — | `C-28` 尚未裁定 | 读 `fuzzyMatchThreshold` | 抛 `TbdConstantError` 且 `constantId == 'C-28'`，**不得返回默认值** | 单元 | 同上 · `C-28 未裁定` |
| `TC-QUANT-008` | `QUANT-006` | **显式** | `Item` 六要件：2 格 `complete`、1 格 `notExternalizable`、3 格 `missing` | 读 `requirements.completeCount` / `externalizableCount` | `2` / `5` —— 不可外化格**不进深度分母** | 单元 | `app/test/core/entities_test.dart` · `不可外化格不进深度分母` |
| `TC-QUANT-009` | `QUANT-007` | 语义 | 方法全部步骤无判据；另一步骤带 `hint` | 读 `isCheckin` / `hasAnyHint` | `isCheckin=true`、`hasAnyHint=false` | 单元 | 同上 · `全部步骤无判据 ⇒ 打卡式` |

### 3.4 `STEP` 域（3 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-STEP-001` | `STEP-014` | 语义 | 两个 `MethodStep`：`operator=read` / `operator=practice`，均不写 `phase` | 读 `effectivePhase` | `read → first`、`practice → both` | 单元 | `app/test/core/entities_test.dart` · `读 → first；练 → both` |
| `TC-STEP-002` | `STEP-014` | 语义 | `operator=read` 且显式写 `phase=review` | 读 `effectivePhase` | `review` —— 作者写的值覆盖派生值 | 单元 | 同上 · `作者可覆盖派生的 phase` |
| `TC-STEP-003` | `STEP-027` | 语义 | 方法 A：`read` + `recall`；方法 B：`read` + `example` | 读 `hasReviewStep` | A `true`、B `false`（全为读/例 ⇒ 无 review 步骤） | 单元 | 同上 · `至少一个 review 步骤` |

### 3.5 `PLAN` / `NOTE` / `VIEW` 域（3 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-PLAN-001` | `PLAN-003` | 语义 | `Plan` 的 `target` 含 `selector` 与 `resolved`（3 项），**不写 `count`** | 读 `target.count`；再 `toJson()` | `count == 3`；序列化后 `target` 含 `count: 3` —— 由 `resolved` 派生，不单独存 | 单元 | `app/test/core/entities_test.dart` · `target.count 由 resolved 派生` |
| `TC-NOTE-001` | `NOTE-005` | 语义 | `Note` 三层同时有值：`generated` / `autoFilled` / `authored` | 读 `displayText` / `noteVersion` | `手写层`（`authored` 优先）、`noteVersion == 3` | 单元 | 同上 · `authored > autoFilled > generated` |
| `TC-VIEW-001` | `VIEW-001` | 语义 | 常量表 | 读 `deepChainPhi` / `trailCap` / `viewTransitionMinMs` / `viewTransitionMaxMs` / `lodBrightnessFar` / `lodBrightnessNear` | `5` / `5` / `180` / `220` / `3` / `7`（`C-20`–`C-23`） | 单元 | `app/test/core/constants_test.dart` · `C-20…C-23 界面阈值` |

### 3.6 `INF` 域（10 条 · 架构约束与外壳）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-INF-001` | `FND-015` | 语义 | 一段 `core/` 代码 import `package:flutter/...` | 跑 `R1` | 报违规 | 架构 | `app/test/lint/rules_test.dart` · `core 引用 Flutter 被拦` |
| `TC-INF-002` | `FND-015` | 语义 | 同上，import `dart:ui` | 跑 `R1` | 报违规 | 架构 | 同上 · `core 引用 dart:ui 被拦` |
| `TC-INF-003` | `FND-015` | 语义 | 同上，import `features/` 下文件 | 跑 `R1` | 报违规 | 架构 | 同上 · `core 引用 features/ 被拦` |
| `TC-INF-004` | `FND-015` | 语义 | `features/` 代码 import Flutter | 跑 `R1` | **不报**（UI 层本就该用） | 架构 | 同上 · `features 引用 Flutter 不拦` |
| `TC-INF-005` | — | — | `core/` 非常量表文件出现数字字面量 | 跑 `R2` | 报违规，且**行号正确** | 架构 | 同上 · `普通数字被拦，并报出行号` |
| `TC-INF-006` | — | — | 同上，文件为 `constants.dart` | 跑 `R2` | **不报**（唯一豁免点） | 架构 | 同上 · `constants.dart 豁免` |
| `TC-INF-007` | — | — | `core/` 出现 `0` 与 `1` | 跑 `R2` | **不报**（坐标原点与计数基元） | 架构 | 同上 · `0 与 1 放行` |
| `TC-INF-008` | — | — | 数字出现在注释与字符串里 | 跑 `R2` | **不误报** | 架构 | 同上 · `注释与字符串里的数字不误报` |
| `TC-INF-009` | — | — | `features/` 出现数字字面量 | 跑 `R2` | **不查**（间距属设计 token） | 架构 | 同上 · `features 层不查数字` |
| `TC-INF-010` | `FND-014` | 语义 | 无内容包 | 挂载应用外壳 | 渲染空态，标题为 `Weltuhr`；**不补默认星系、不填假数据** | Widget | `app/test/widget_test.dart` · `空态外壳可渲染` |

**合计 42 条** = `FND` 7 + `PACK` 10 + `QUANT` 9 + `STEP` 3 + `PLAN`/`NOTE`/`VIEW` 3 + `INF` 10。与既有测试 1:1 对应（Dart 33 条 + 管线 fixture 9 条），无新增、无删减。

## 四、覆盖缺口

### 4.1 总量

| 口径 | 数量 |
|---|---|
| `SPEC` 唯一编号总数（实测 `grep -ohE` 去重） | **171** |
| 有对应用例的 `SPEC` | **18**（显式 6 + 语义 12） |
| 无用例 | **153** |

按域：

| 域 | `SPEC` 总数 | 有用例 | 缺口 |
|---|---|---|---|
| `FND` | 16 | 5（`005` `011` `013` `014` `015`） | 11 |
| `VIEW` | 34 | 1（`001`） | 33 |
| `PACK` | 18 | 4（`001` `005` `008` `009`） | 14 |
| `PLAN` | 21 | 1（`003`） | 20 |
| `STEP` | 34 | 4（`012` `014` `022` `027`） | 30 |
| `QUANT` | 15 | 2（`006` `007`） | 13 |
| `NOTE` | 19 | 1（`005`） | 18 |
| `GOV` | 14 | 0 | 14 |
| **合计** | **171** | **18** | **153** |

### 4.2 缺口必须分两类看，不能混算

**153 这个数字本身说明不了任何问题。** 项目当前只完成 `B1`（三端骨架），171 条需求里绝大多数属于 `B2`–`B9`。把它们算成「测试缺失」等于指责一个还没开工的批次。

| 类别 | 判据 | 性质 | 数量 |
|---|---|---|---|
| **A · 未开工缺口** | 该 `SPEC` 所属批次尚未开始 | **正常**，随批次推进自然收敛 | 146（= 153 − B 类 7，为估算） |
| **B · 已实现无断言** | 代码里已有实际定义或逻辑，但**没有断言锁住该语义** | **真风险** | **7** |
| **C · 有断言但未标号** | 已测，测试里没写 `SPEC` 编号 | 追溯断链，**非**测试缺失 | **12** |

> **A 类为什么只能给估算**：判断「未开工」需要逐条核对 `SPEC` 所属批次，而 `design/` 的 171 条并未逐条标注批次归属。146 是按「总数 − 已明确判定的 B、C 两类」倒推的上界，不是逐条核对的结果。把 `SRS` 按批次切片完成后（第 3 笔），这个数才能变准。

### 4.3 B 类明细（真正的缺口 · 7 条）

| `SPEC` | 实现位置 | 现状 | 为什么算缺口 |
|---|---|---|---|
| `FND-003` | `core/enums.dart` `Layer` | 枚举已定义 | 无断言锁住「三层是径向属性、不是层级」这一语义 |
| `FND-004` | `core/enums.dart` `SixRequirementState` | 枚举已定义 | `TC-PACK-002` 只测「缺格即错」，未测「三态取值集合封闭」 |
| `FND-010` | `core/events/event.dart` · `event_store.dart` | 结构已定 | 无断言测「事件是唯一可写事实源」（不存在其他可变状态） |
| `FND-012` | `core/events/event.dart` | 无 `copyWith`、字段全 `final` | **既无断言也无 lint 规则**锁住 append-only —— 有人加个 `copyWith` 不会有任何东西报错 |
| `GOV-001` | `core/enums.dart` | 四种裁定枚举已定义 | 零用例 |
| `STEP-018` | `core/enums.dart` | 三档刻度枚举已定义 | 零断言 |
| `VIEW-004` | `core/entities/content.dart:223` | 仅有注释声明「源不进任何视觉通道」 | 注释不是约束；无任何机制阻止把源接进渲染 |

**其中 `FND-012` 与 `VIEW-004` 最值得先补**：这两条的共同点是**约束只存在于注释里**。注释拦不住任何人，而它们各自保护的是「事件不可变」与「换源不改观感」—— 都是改起来容易、发现难的那类。

`STEP-012` 属**部分覆盖**，不计入本表：`TC-QUANT-005` 测了「系数表与枚举等长」，但没测「不得自创第七类」。

### 4.4 C 类明细（追溯断链 · 12 条）

`FND-005` · `FND-011` · `FND-014` · `FND-015` · `QUANT-007` · `STEP-012` · `STEP-014` · `STEP-022` · `STEP-027` · `PLAN-003` · `NOTE-005` · `VIEW-001`

**修法不是补文档，是补标号**：在这些测试的 `group`/`test` 名或首行注释里写上 `SPEC` 编号，`STR` 就能机械生成追溯表。本文件这 12 条现在只能靠人工判定，正是这一断链的直接后果。

## 五、待补与待核

| # | 项 | 类型 | 归属 |
|---|---|---|---|
| 1 | `FND-012` 加 lint 规则（禁 `copyWith` / 禁非 `final` 字段） | 补断言 | `B2` |
| 2 | `VIEW-004` 加架构规则（`sourceRefs` 不得出现在视图层入参） | 补断言 | `B3` |
| 3 | `TC-PACK-010` 的 `SPEC` 标号待核（note 写 `PACK-005`，语义更像 `PLAN-012`） | 待核 | 本轮登记，`B2` 前定 |
| 4 | **28 个错误码无 fixture 覆盖**（见 `STP` §六） | 补用例 | `B2` |
| 5 | C 类 13 处补 `SPEC` 标号 | 补标号 | 随 `B2` 顺手改 |
| 6 | B 类其余 6 条补断言 | 补断言 | 随所属批次 |

> 第 4 项的数字要说清：`validator.py` 共 **36 个错误码**，9 个 fixture 覆盖了其中 **8 个**（`E-CYCLE` `E-ID-DUP` `E-SPACE-NO-ORDER` `E-REQ-VALUE` `E-REQ-KEY` `E-REQ-STATE` `E-VERSION-FORMAT` `E-ID-VERSIONED`）。**28 个错误码的拒绝路径从未被执行过** —— 它们是否有 bug，目前无人知道。

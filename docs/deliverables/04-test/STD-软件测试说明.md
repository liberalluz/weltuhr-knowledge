# 软件测试说明（STD）

> **版号**：`v0.16.0` · **状态**：§三 用例表 **277 条**（§3.17–3.19 的 26 条锁 `B3` 笔 4a 的筛选 DNF、定位浮层与 ② 状态栏）；`TC-VIEW-036` 预期随占位节点改为 **153 节点 / 170 条边**
> 本文件是**用例正文**。测什么与通过判据见 [`STP`](STP-软件测试计划.md)，实际执行结果见 [`STR`](STR-软件测试报告.md)。
> **追溯补录**：2026-10-17 · §三 依据 `app/test/` 与 `content/tools/fixtures/` 的既有测试逐条反推，非当时所写。

## 修订历史

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建。确立用例编号与格式；用例表待补 |
| `v0.2.0` | 2026-10-17 | **追溯补录** §三 用例表（42 条：Dart 33 + 管线 9）、§四 覆盖缺口、§五 待补清单 |
| `v0.3.0` | 2026-10-17 | §三 补 `TC-PACK-011`–`041`（31 条管线用例，覆盖 `validator.py` 余下 29 个错误码 + 1 条产物层正例）；§五 待补第 4 项关闭 |
| `v0.4.0` | 2026-10-17 | §三 补 `TC-INF-011`–`023`（13 条：`R3` 5 · `R4` 4 · `R5` 4）；§四 重算 —— `FND-012` / `VIEW-004` 由 B 转「有用例」，5 条借位映射降级进 B 类，**C 类清零**；§五 待补第 1 · 2 · 5 · 6 项关闭 |
| `v0.5.0` | 2026-10-17 | §三 新增 §3.7 `LOAD` 域 `TC-LOAD-001`–`040`（40 条：枚举同源 3 · 路径探测 6 · 包解析 9 · 环检测 6 · 定位引擎 12 · 真实 α 包 4）；§四 重算 —— `FND-008` / `VIEW-025` `027` `028` `029` / `PACK-018` 由 A 转「有用例」，`FND-004` 移出 B 类（10 → 9），A 类 143 → 138 |
| `v0.6.0` | 2026-10-17 | §三 新增 §3.8 `EVT` 域 `TC-EVT-001`–`048`（48 条：发号 13 · 游标与判定 10 · 幂等/空间/快照/孤儿 6 · 笔记 5 · 迁移账本 2 · 坏事件 3 · 折算函数 9）；§四 重算 —— `FND-010` 移出 B 类（9 → 8），B 类列修正为与 §4.3 行数一致，补记 `FND-003` 的差分重叠 |
| `v0.7.0` | 2026-10-17 | §三 新增 §3.9 `VIEW` 域（续）`TC-VIEW-002`–`018`（17 条：`φ` 层号 9 · 投影 8）；§四 重算 —— `VIEW-002` 首次有用例（25 → 26、缺口 146 → 145、A 类 138 → 137），B 类仍 8 条；§五 登记 `B3` 开工前的三项待核。**本版为补记**：第 4 笔的代码与用例已随 PR #33 合并，当时只改了 `constants.md`，`STD` 滞后一版 |
| `v0.8.0` | 2026-10-17 | §三 新增 §3.10 `VIEW` 域（续二）`TC-VIEW-019`–`038`（20 条：绘制计数 6 · 帧时序 6 · 场景装配 6 · 页面 2）；§四 **不变** —— 新增用例守的是「调用数」与「时序算法」，没有一条首次覆盖某条 `SPEC`（`VIEW-002` / `PACK-018` 此前已有用例）。本节**不测帧率**：`FrameTiming` 只在真设备上产生 |
| `v0.9.0` | 2026-10-17 | **只修口径，用例数不变（211）**：§五 待补第 4 项括注「`--suite` 最后一步」改为「其中一步」—— 该轮之后 `--suite` 增至四层（第四层「输出可移植性」见 `STP` §七），错误码覆盖不再位于末位。本版不新增 `TC-` 编号：可移植性自检是工具链健康约束，不是某条 `SPEC` 的行为 |
| `v0.10.0` | 2026-10-17 | **用例数不变（211）**：§五 第 11 项（`C-32` 待真机实测）标为**已闭环** —— 四组读数（三档 + 一次窗口对照）记入 [`STR`](STR-软件测试报告.md) 轮次 `R1`，判据补测量前提 `C-33`；§五 新增第 12 项登记合成场景的虚线比例偏差。本版不新增 `TC-` 编号：帧率由判据直接裁定，不是用例行为 |
| `v0.16.0` | 2026-10-17 | §三 新增 §3.17–3.19（26 条：筛选 DNF 12 · 定位浮层 9 · 路由与 ② 5），**277 条**；Dart 218 → **244**。§四 重算 —— `VIEW-019` `021` `024` `026` `030` `033` **首次有用例**（`027` `028` `029` 本已有），覆盖 34 → 40、缺口 137 → 131。另记 `VIEW-027` 修订：落点 = `Z4`，不按 `φ` 定档 |
| `v0.15.0` | 2026-10-17 | §三 新增 §3.14–3.16（23 条：树视图 6 · 详情三区 11 · 视图切换 6）并补 `TC-INF-024` `025`（`R4` 收窄的边界），**251 条**；Dart 193 → **218**。§四 重算 —— `VIEW-009` `010` `011` `012` `014` `017` 与 `FND-004` · `NOTE-007` **首次有用例**（26 → 34，缺口 145 → 137）。另记 `R4` 判据收窄：原「`features/**` 一律不许出现源」与 `SPEC-VIEW-004`「源只写进详情页」直接矛盾，现限定为视觉通道文件 |
| `v0.14.0` | 2026-10-17 | §三 新增 §3.13 `VIEW` 域（续五）`TC-VIEW-050`–`053`（4 条：域序 · 首屏展开 · 域内排序 · 黑洞行），**226 条**；Dart 185 → **193** |
| `v0.13.0` | 2026-10-17 | §三 新增 §3.12 `VIEW` 域（续四）`TC-VIEW-044`–`049`（6 条：视口封顶 3 · HUD 规则 3），**222 条**；Dart 176 → **185** |
| `v0.12.0` | 2026-10-17 | §三 新增 §3.11 `VIEW` 域（续三）`TC-VIEW-039`–`043`（5 条：域带段数 · `φ` 分位 · `C-34` 命中集 · 占位节点 · 主轴继承），**216 条**；`TC-VIEW-036` 预期由「150 节点 / 167 边」改为「153 节点（含 3 占位）/ 170 条边」——`ADR-0003` §决策 5 让指向未知不再丢边。Dart 用例 171 → **176** |
| `v0.11.0` | 2026-10-17 | **用例数不变（211）**：§五 第 8–10 项（「主取值」缺承载位 / 「指向未知」无视觉 / `φ` 归一无口径）**三项同时闭环**，裁定见 `ADR-0003`（新增 `Item.primaryAxis` · 沿用 `VIEW-007` 黑洞 · `φ` 改累计分位映射 · `r` 改域带）。原拟的 `φ` 分段折叠被实算否掉（`φ ≥ 10` 占 84% 项）。本版不新增 `TC-` 编号：新裁定属 `B3` 未开工范围，断言随视图层落地 |

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

> **`TC-PACK-011`–`041` 的「对应 `SPEC`」多为 `—`，这是有意的**：这 31 条测的是**字段级判据**，其权威处是 [`docs/reference/entity-fields.md`](../../reference/entity-fields.md) 的各节，不是 `SPEC-*`。硬凑一个编号会让追溯表看起来完整、实际指错地方 —— 那正是 `R-09` 要防的形态。能确定对应的（`PACK-005` 五段与 `meta`、`PACK-007` 段集合、`FND-002` 六轴、`FND-003` 三层、`FND-013` 稳定 id）已如实填。

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

### 3.6 `INF` 域（23 条 · 架构约束与外壳）

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
| `TC-INF-018` | `VIEW-004` | 语义 | `core/entities/content.dart` 的 `Item` 构造参数收 `SourceRef` | 跑 `R4` | **不报**（源本来就该在核心层流转） | 架构 | 同上 · `core 实体层收源不拦（R4 只管视觉通道）` |
| `TC-INF-019` | `VIEW-004` | 语义 | 视图层参数名 `resourceId` | 跑 `R4` | **不误报** —— 判据是 `source` 不是 `resource` | 架构 | 同上 · `resourceId 不误报（R4：判据是 source 不是 resource）` |
| `TC-INF-024` | `VIEW-004` | 语义 | `core/frame/scene.dart` 构造参数收 `SourceSegment` | 跑 `R4` | 报违规 —— **场景装配也算视觉通道**（`v0.15.0` 收窄后补的边界） | 架构 | 同上 · `场景装配层收源被拦（R4：core/frame 也算视觉通道）` |
| `TC-INF-025` | `VIEW-004` | 语义 | `features/detail/detail_panel.dart` 构造参数收 `SourceRef` | 跑 `R4` | **不报** —— `SPEC-VIEW-004` 要求源写进详情页；收窄前这条会误判为违规 | 架构 | 同上 · `详情页显示源名不拦（R4 收窄后只管通道，SPEC-VIEW-004 要求写进详情）` |
| `TC-INF-020` | — | — | 测试名无任何标号 | 跑 `R5` | 报违规，并指名该测试 | 架构 | 同上 · `无标号的 test 被拦` |
| `TC-INF-021` | — | — | 测试名分别带 `SPEC-…` / `C-…` / `ADR-…` / `R<n>` | 跑 `R5` | 四种标号**全部放行** | 架构 | 同上 · `SPEC 编号、常量编号、ADR、规则号都算合规标号` |
| `TC-INF-022` | — | — | 测试名写「无 SPEC：<理由>」 | 跑 `R5` | **放行** —— 写不出标号时允许显式豁免，不允许静默留空 | 架构 | 同上 · `显式豁免放行` |
| `TC-INF-023` | — | — | `lib/` 下出现 `test('…')` 调用 | 跑 `R5` | **不查**（`R5` 只管 `test/`） | 架构 | 同上 · `lib 下的 test 调用不查` |

### 3.7 `LOAD` 域（40 条 · 包加载与定位，`B2` 第 2 笔）

> 本节全部落在 `app/lib/core/pack/` 与 `app/lib/core/locate/`。三类里最值得看的是 **①枚举取值与包数据同源**：此前 `ItemType` / `Layer` / `RequirementState` / `EdgeType` 四个枚举与真包取值差一个词（`statement` vs `declarative`、`quick` vs `ephemeral`、`complete` vs `present`、`unknownTarget` vs `unknown`），而既有测试全用内联 JSON、与真包同错 —— **所以一直是绿的**。α 包一进来当场抛错。

#### 3.7.1 枚举取值与包数据同源（3 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-LOAD-001` | `PACK-009` | **显式** | `RequirementState` 四个候选：`present` / `missing` / `not_externalizable` / `notExternalizable` | 逐个 `fromWire` | 前三个正常解析；驼峰那个抛 `FormatException` —— 包只认蛇形 | 单元 | `app/test/core/entities_test.dart` · `三态用蛇形 not_externalizable` |
| `TC-LOAD-002` | — | — | `ItemType` / `Layer` 的取值 | `fromWire('declarative')` / `('procedural')` / `('ephemeral')`；再试 `'statement'` / `'quick'` | 前三个通过；后两个抛错 —— 旧枚举名不得再被接受 | 单元 | 同上 · `项的 type 与 layer 取数据里的值` |
| `TC-LOAD-003` | — | — | 一条 `type: "unknown"` 的边 | `Edge.fromJson` 再 `toJson` | 解析为 `EdgeType.unknown`，回写仍是 `unknown` | 单元 | 同上 · `边类型 unknown 能解析` |

#### 3.7.2 路径探测（6 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-LOAD-004` | `PACK-018` | 语义 | 两个空间目录，各有 `manifest.json` + `dist/pack.json` | `PackProbe.scanRoot('content')` | 两个位置，按目录名排序，无问题 | 单元 | `app/test/core/pack/pack_probe_test.dart` · `清单与产物都在才算一个包` |
| `TC-LOAD-005` | `PACK-018` | 语义 | 只有 `dist/pack.json`，缺清单 | 同上 | 不产出位置，报 `missingManifest` 并指名清单路径 | 单元 | 同上 · `缺清单报 missingManifest` |
| `TC-LOAD-006` | `PACK-018` | 语义 | 只有清单，缺产物（= 忘了跑 `build.py`） | 同上 | 报 `missingPack` 并指名 `dist/pack.json` | 单元 | 同上 · `清单在、产物不在报 missingPack` |
| `TC-LOAD-007` | `PACK-018` | 语义 | 文件在但读不出（模拟权限 / 非 UTF-8） | 同上 | 报 `unreadable`，**不与「缺文件」混为一谈** | 单元 | 同上 · `文件在但读不出来报 unreadable` |
| `TC-LOAD-008` | `PACK-018` | 语义 | 三个候选根：第一个不存在，后两个各有同名空间 | `scanRoots([...])` | 同名空间只取**先出现**的那个；各自独有的空间都保留 | 单元 | 同上 · `候选根依次探测` |
| `TC-LOAD-009` | — | — | 根目录不存在 | 同上 | 空结果、**零问题** —— 空根不是错误，缺文件才是 | 单元 | 同上 · `根目录不存在` |

#### 3.7.3 包解析（9 条）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-LOAD-010` | `PACK-005` | 语义 | 最小包：五段 + `meta` | `parsePack` | 解析成功，`itemById` / `schemeNodes` 可用 | 单元 | `app/test/core/pack/pack_parse_test.dart` · `五段 + meta 齐备即可解析` |
| `TC-LOAD-011` | `PACK-005` | **显式** | `meta.space` 与清单 `id` 不同 | 同上 | 抛错，文案点明「包与清单不是同一空间」 | 单元 | 同上 · `meta.space 与清单 id 不一致即拒` |
| `TC-LOAD-012` | `PACK-005` | **显式** | `meta.version` 与清单 `version` 不同 | 同上 | 抛错，文案点明「不是同一批产物」 | 单元 | 同上 · `meta.version 与清单 version 不一致即拒` |
| `TC-LOAD-013` | `PACK-007` | **显式** | pack 多出 `notes` 段 | 同上 | 抛错 —— 笔记模板不进包 | 单元 | 同上 · `多出 notes 段即拒` |
| `TC-LOAD-014` | `PACK-005` | 语义 | 删掉 `items` 段 | 同上 | 抛错，**不补空数组**（补默认值会把坏包读成空包） | 单元 | 同上 · `缺 items 段即拒` |
| `TC-LOAD-015` | `PACK-008` | 语义 | 两个 `items` 用同一 `id` | 同上 | 抛错并指名重复的 id | 单元 | 同上 · `段内 id 重复即拒` |
| `TC-LOAD-016` | `FND-005` | 语义 | `a→b`、`b→a` 两条边 | 同上 | 抛错，报错正文里带出环路径 | 单元 | 同上 · `有环的 ⪯ 即拒` |
| `TC-LOAD-017` | — | — | 同时存在三处错（版本不符 / 缺段 / 多段） | 同上 | 一次抛出的 `problems` 至少 3 条 —— 不遇到第一个就停 | 单元 | 同上 · `一次报全部问题` |
| `TC-LOAD-018` | — | — | 清单是 `{`（坏 JSON） | 同上 | 抛 `PackFormatException`，文案指名哪个文件 | 单元 | 同上 · `坏 JSON 即拒并指名文件` |

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

> 这四条读 `../content/python/dist/pack.json`，`dist/` 不入库 ⇒ 缺失时**明确失败而非跳过**（`dist/` 由 `build.py` 生成，CI 在跑测试前先构建）。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-LOAD-037` | `PACK-005` | 语义 | α 包产物 | 探测 → 解析 | 150 项 / 170 边 / 10 域 / 150 条 id 索引 | 单元 | `app/test/core/pack/alpha_pack_test.dart` · `可解析且图密度四个数与登记口径一致` |
| `TC-LOAD-038` | `FND-005` | 语义 | 同上 | `findCycles(edges)` | 空 —— 构建期校验过，运行时这份也要过 | 单元 | 同上 · `⪯ 无环` |
| `TC-LOAD-039` | `FND-008` | **显式** | 150 项，逐项用自己的标题查询 | `locate(item.title)` | 每项都 `located` 且落点是自己；**0 例外** | 单元 | 同上 · `全部 150 项用自己的标题自定位` |
| `TC-LOAD-040` | — | — | 44 道声明式题 | 逐个查 `itemId` 是否在册 | 无悬空引用 | 单元 | 同上 · `题库全部指向在册项` |

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
| `TC-VIEW-011` | `VIEW-002` | **显式** | 三节点 `radial01` = `0` / `0.1` / `0.9`；`yaw`/`pitch` 置零、`sector=0` | `projectFrame` | 前两者 `x` **相等**（同段同半径）；`0.9` 的 `x` 更大（`r` 是 7 段径向分层） | 单元 | `app/test/core/frame/projection_test.dart` · `r 是 7 段径向分层` |
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
| `TC-VIEW-019` | — | `ADR-0002` | 合成场景 ×1（150 项 / 167 边），视口 800×600 | `paintFrame` | `dots == 150`；`strokes ≥ 167`；`dashedSegments > dashedEdges`；`total == dots + strokes` | 单元 | `app/test/features/universe/frame_painter_test.dart` · `150 项 / 167 边 ⇒ 150 次 dot + 实线 1 段 + 虚线段若干（ADR-0002）` |
| `TC-VIEW-020` | `VIEW-002` | **显式** | 两节点 + 一条实线边 | 同上 | `strokes == 1`；`dashedEdges == 0` | 单元 | 同上 · `实线边只发一次 stroke（SPEC-VIEW-002）` |
| `TC-VIEW-021` | — | — | 两节点相距 100 px + 一条虚线边，`pixelsPerUnit = 1` | 同上 | `dashedSegments == 12`（100 ÷ 9 向上取整）；`strokes == 12` | 单元 | 同上 · `虚线边按 9 px 周期拆段：100 px ⇒ 12 段（无 SPEC：虚线段长为设计 token）` |
| `TC-VIEW-022` | — | — | 两节点投影后完全重合 + 一条虚线边 | 同上 | `skippedEdges == 1`、`strokes == 0`、`dots == 2` —— 退化输入不产生零长线段 | 单元 | 同上 · `两端重合的虚线边被跳过，不计段（无 SPEC：退化输入的保护）` |
| `TC-VIEW-023` | — | `ADR-0002` | 原点到视口外（-5000, -5000） | 同上 | `dots == 2` 且 `offscreenDots == 2` —— **照发调用**，朴素实现不逐个判屏 | 单元 | 同上 · `画到视口外的节点仍发绘制调用，并被计入 offscreenDots（ADR-0002）` |
| `TC-VIEW-024` | — | — | 两节点 + 一条实线边 | 同上 | 目标收到的首个指令是 `stroke`、末个是 `dot` —— 点压在线上 | 单元 | 同上 · `先边后点：点压在线上（无 SPEC：绘制次序属实现选择）` |

> `TC-VIEW-019` 是本节的地基：这一笔所有结论都建立在「一帧 300 多次调用」这个数上。若它只能靠读代码数，那就是意见；被断言住才是事实。已做反向验证 —— 把节点循环改成隔一个跳过，本组 3 条立即变红（150→75）。

#### 3.10.2 帧时序统计（6 条 · `FrameRateMonitor`）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-025` | — | `C-32` | 0 帧 / 2 帧 | `snapshot()` | 返回 `null` —— 不足 20 个间隔不出快照，不拿两帧编一个 fps | 单元 | `app/test/features/universe/frame_stats_test.dart` · `样本不足时不出快照（C-32）` |
| `TC-VIEW-026` | — | `C-32` | 25 帧，间隔 16 667 µs；build 1 ms / raster 4 ms | 同上 | `fps ≈ 60`、`frameP50Ms ≈ 16.667`、`rasterP95Ms ≈ 4`、`meetsGood == true` | 单元 | 同上 · `16.667 ms 稳定间隔 ⇒ 60 fps，UI 1 ms / 光栅 4 ms（C-32）` |
| `TC-VIEW-027` | — | `C-32` | 24 个间隔里 5 个为 50 ms | 同上 | `fps ≈ 60`（中位不受影响）**且** `frameP95Ms ≈ 50` —— 两个指标缺一不可 | 单元 | 同上 · `掉帧拉高 p95 但不改变中位 fps —— 两个指标缺一不可（C-32）` |
| `TC-VIEW-028` | — | `C-32` | 25 帧，间隔 40 000 µs | 同上 | `fps ≈ 25`、`meetsTarget == false` —— 低于 30 fps 判不过 | 单元 | 同上 · `低于 30 fps 判不过（C-32）` |
| `TC-VIEW-029` | — | `C-32` | 先加 25 帧再 `reset()` | 同上 | `reset()` 后 `snapshot()` 为 `null` —— 切档必须清窗口 | 单元 | 同上 · `reset 后回到无样本状态（C-32）` |
| `TC-VIEW-030` | — | — | `capacity = 30`，连加 200 帧 | 同上 | `samples == 30` —— 滚动窗口有上界 | 单元 | 同上 · `滚动窗口只保留最近 capacity 个间隔（无 SPEC：内存上界属实现约束）` |

> `TC-VIEW-027` 锁的是一个**判据设计**，不是算法细节：只报平均 fps 会把「一直 45 fps」和「60 fps 但每 5 帧掉一次」判成同一件事，而后者手感明显更差。所以中位承载稳态、p95 承载卡顿，两条都要有。

#### 3.10.3 场景装配（6 条 · `scene_source`）

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-031` | — | `ADR-0002` | — | `buildSyntheticScene()` | `itemCount == 150`、`edgeCount == 167` —— 合成口径 = α 包有效边数 | 单元 | `app/test/features/universe/scene_source_test.dart` · `×1 = 150 项 / 167 边（ADR-0002）` |
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
| `TC-VIEW-037` | — | `ADR-0002` | — | 挂载页面 → 切到 ×2 → 卸载 | 三个档位按钮都在；切换后 `takeException()` 为 `null`；卸载时 `dispose` 不撞 ticker 断言 | Widget | `app/test/features/universe/universe_spike_screen_test.dart` · `spike 页渲染不崩，三档切换可用（ADR-0002）` |
| `TC-VIEW-038` | — | `C-32` | 未收到任何 `FrameTiming` | 挂载页面 | HUD 显示「采样中」；**不出现**「需回写 adr/0002」—— 没有样本就不出判据 | Widget | 同上 · `HUD 在没有帧时序时显示采样中，而不是编一个数（C-32）` |

**合计 277 条** = `FND` 7 + `PACK` 41 + `QUANT` 9 + `STEP` 3 + `PLAN`/`NOTE`/`VIEW` 3 + `INF` 25 + `LOAD` 40 + `EVT` 48 + `VIEW`（续）17 + `VIEW`（续二）20 + `VIEW`（续三）5 + `VIEW`（续四）6 + `VIEW`（续五）4 + `VIEW`（续六）6 + `VIEW`（续七）11 + `VIEW`（续八）6 + `VIEW`（续九）12 + `VIEW`（续十）9 + `VIEW`（续十一）5。其中 Dart 244 条（`flutter test`），管线 fixture 40 条（`verify.py --suite`：源层 32 + 产物层 8）。`v0.7.0` → `v0.8.0` 新增 20 条（`B2` 第 5 笔：绘制计数 6 · 帧时序 6 · 场景装配 6 · 页面 2），**既有 191 条一字未改**。

### 3.11 `VIEW` 域（续三）· 坐标与通道装配（5 条 · `B3` 笔 1）

> 本节锁的是 `ADR-0003` 的五条裁定**在 α 包上落到具体数**：段数、分位、命中集、占位数。全部读真实包 —— 这些数只在 α 包上有意义，内联 JSON 测不出「10 个域各 15 项」。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-039` | `VIEW-002` | **显式** | α 包 | `buildSceneNodes` | `radial01` 恰 **10** 个不同值、每值 **15** 项；每项 = `(域序号 + 0.5) / 10` | 单元 | `app/test/core/frame/scene_test.dart` · `r = 域带：段数 = 域数、每段等量、取环中线（ADR-0003）` |
| `TC-VIEW-040` | — | `ADR-0003` | α 包 | 同上 | `φ=0` 的分位为 `0`、`φ=1` 为 `3/150`；不同层的分位**严格递增**（无零宽层） | 单元 | 同上 · `φ 按层项数取累计分位，无零宽层（ADR-0003）` |
| `TC-VIEW-041` | `VIEW-003` | `C-34` | α 包 | 同上 | 虚线恰 **3** 项，且集合与 `type = tacit` 的 **完全相同** —— 两处标注共线 | 单元 | 同上 · `虚实按 C-34：不可外化格 ≥ 3，命中集与 type=tacit 相同（C-34）` |
| `TC-VIEW-042` | — | `ADR-0003` | α 包 | 同上 + `buildEdgeSpans` | 占位节点 **3** 个且 `isPlaceholder`、`size01 == 0`；节点数 **153**；边跨度 **170**（不再是 167） | 单元 | 同上 · `端口不在册的边生成占位节点，有效边数不再减少（ADR-0003）` |
| `TC-VIEW-043` | — | `ADR-0003` | 两份手搭小包 | 同上 | 主轴缺省继承 `manifest.defaultPrimaryAxis`；项级可覆盖；两者都缺 ⇒ `sector == sectorCount`（越界哨兵，不塞进任何轴） | 单元 | 同上 · `主轴缺省继承 manifest 默认，两者都缺则落「未声明」扇区（ADR-0003）` |

> `TC-VIEW-041` 与 `TC-VIEW-043` 是本节最该看的两条：前者把一个**共线发现**固定成断言（`type` 不得再占通道），后者把「不猜」写成可执行判据 —— 越界哨兵比「随便挑一个轴」更容易在评审时被抓到。

### 3.12 `VIEW` 域（续四）· 视口封顶与 HUD 规则（6 条 · `B3` 笔 2）

> 本节锁两件事：**绘制表面按面积封顶**（`C-33`，实测成本随覆盖面积走）与**七区块的显示规则**（`VIEW-018` / `VIEW-019` / `VIEW-013`）。后者尤其重要 —— 「② 激活才出现、④ 仅 `Z4`」若第一天就摆成常显占位，这条规则以后再也测不出来。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-044` | — | `C-33` | 窗口 1280×800 / 恰为基准 | `planViewport` | `scale == 1`、表面 = 窗口；**恰好等于基准不降分辨率** | 单元 | `app/test/core/view/viewport_test.dart` · `不超过基准窗口时按原尺寸画，scale = 1（C-33）` |
| `TC-VIEW-045` | — | `C-33` | 窗口 3840×2160 | 同上 | 表面 **1920×1080**、`scale == 2`、`isDownscaled` | 单元 | 同上 · `4K 窗口缩到基准尺寸再放大：表面 1920×1080、scale 2（C-33）` |
| `TC-VIEW-046` | — | `C-33` | 2560×1080 与 1920×1440（等面积异形） | 同上 | 两者 `scale` 相同、封顶后面积等于基准 —— **按面积判而非按单边** | 单元 | 同上 · `按面积判而不是按单边：2560×1080 与 1920×1440 同分支（C-33）` |
| `TC-VIEW-047` | `VIEW-018` | **显式** | 默认 `Z1` | 挂载 `UniverseScreen` | ①③⑤⑥⑦ **在**；② 与 ④ **不在**（② 是状态栏激活才出现 · ④ 仅 `Z4`） | Widget | `app/test/features/universe/universe_screen_test.dart` · `默认 Z1：①③⑤⑥⑦ 在，② 与 ④ 不在（SPEC-VIEW-018）` |
| `TC-VIEW-048` | `VIEW-013` | **显式** | 默认 `Z1` | 点 `Z4 单星` | ④ 出现；面包屑变为 `宇宙 › Z4 单星` | Widget | 同上 · `切到 Z4 ⇒ ④ 出现、面包屑含 Z4（SPEC-VIEW-018）` |
| `TC-VIEW-049` | `VIEW-001` | **显式** | 默认 `Z1` | 遍历五档来回切 | 五档刻度全在；反复切换 `takeException()` 为 `null` | Widget | 同上 · `五档刻度全在，且当前档可反复切换不崩（SPEC-VIEW-001）` |

### 3.13 `VIEW` 域（续五）· 树行模型（4 条 · `B3` 笔 3）

> 树只表达容器层级（域 → 项），域层不画 `⪯` 边。本节的四个数全部从 α 包实测而来：10 个域、`maxφ=63`（深链）、首屏 7 项、3 个黑洞。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-050` | `VIEW-006` | **显式** | α 包，不展开任何域 | `buildTree` | 域行数 = `domainIds` 长度；**顺序逐个等于** `domainIds`；未展开的域只出一行 | 单元 | `app/test/core/view/tree_test.dart` · `第一层是域，顺序与 manifest.domainIds 一致（SPEC-VIEW-006）` |
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
| `TC-VIEW-054` | `FND-014` | **显式** | `pack == null`（合成回落） | 挂载 `TreeView` | 渲染 `tree-empty`；**不渲染** `tree-view`（不画一棵空树）；文案「没有可展开的树」 | Widget | `app/test/features/universe/tree_view_test.dart` · `没有包 ⇒ 空态，不画一棵空树（SPEC-FND-014）` |
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
| `TC-VIEW-071` | — | `C-22` | 默认 `Z1` | 读 `AnimatedSwitcher.duration` | 毫秒数落在 **180–220** 区间内；`transitionBuilder` 非空（默认即 `FadeTransition`） | Widget | `app/test/features/universe/universe_screen_test.dart` · `交叉淡入时长落在 C-22 区间内，而非随手取一个数（C-22）` |
| `TC-VIEW-072` | `VIEW-011` | **显式** | α 包 | 点「树」 | `tree-view` 在、面包屑变「树 › 全空间」；**罗盘 ⑥ 与焦点星 ⑤ 都不渲染** | Widget | 同上 · `切到树 ⇒ 树视图出现，罗盘 ⑥ 与焦点星 ⑤ 不渲染（SPEC-VIEW-011）` |
| `TC-VIEW-073` | `VIEW-012` | **显式** | α 包，`initialMode = tree` | 挂载 | ④ 详情抽屉**在**（不必推到 `Z4`）；内容为空态 | Widget | 同上 · `树里详情常驻右栏，不必推到 Z4（SPEC-VIEW-012）` |
| `TC-VIEW-074` | `VIEW-009` | **显式** | α 包，树模式 | 点一个**有后继**的项 → 点「宇宙」 | 详情页头是该行标题；面包屑档位 == `zoomForPhi(该行 φ, hasChildren: true)`；`tree-view` 消失 | Widget | 同上 · `树里选行 ⇒ 详情填上该行，再切回宇宙按 φ 定档（SPEC-VIEW-009）` |
| `TC-VIEW-075` | `VIEW-001` | **显式** | α 包，树模式 | 点 `Z2 星云` | 面包屑 `宇宙 › Z2 星云`；`tree-view` 消失（视距是宇宙的导航层级） | Widget | 同上 · `树里点刻度 ⇒ 回宇宙并定到该档（SPEC-VIEW-001）` |
| `TC-VIEW-076` | `FND-014` | **显式** | 无包 | 点「树」 | 渲染 `tree-empty`；④ 仍在位；无异常 | Widget | 同上 · `没有包时树照样能进去，报「没有可展开的树」而不是崩（SPEC-FND-014）` |

### 3.17 `VIEW` 域（续九）· 筛选表达式 DNF（12 条 · `B3` 笔 4a）

> `SPEC-VIEW-021` 的「同轴 OR / 跨轴 AND」不是口味而是唯一自洽的读法：一项一轴只取一值，
> 同轴取 AND 恒为空集。本节前半验语义，后半验 ② 的 chip 列表。
> α 包的形状刚好够用 —— `subject` 一个取值（150 项全覆盖）、`ability` 9 个取值 × 15 项、
> `role` / `industry` / `topic` / `stack` 全 `null`。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-077` | `VIEW-021` | **显式** | α 包，取 `ability` 两个取值 | `matchedCount` | 条数 = 两个取值各自条数之和（OR） | 单元 | `app/test/core/view/filter_test.dart` · `同轴多选取 OR：两个取值并起来是两者之和（SPEC-VIEW-021）` |
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
| `TC-VIEW-095` | `VIEW-030` | **显式** | 输入一句必然搜不到的 | 看结果区 | 只说「没有命中」；提示文案里**不含「新增」** | Widget | 同上 · `无命中只说没有，不出现新增入口（SPEC-VIEW-030）` |
| `TC-VIEW-096` | `VIEW-033` | **显式** | 同一句输入，`spacePrefix` 各取有 / 无 | 看结果行 | 有前缀时写 `Python › 装饰器`；无前缀时只有 `装饰器`，且**没有** ` › ` 分隔符 | Widget | 同上 · `多空间才带前缀，单空间不重复写空间名（SPEC-VIEW-033）` |
| `TC-VIEW-097` | `FND-014` | **显式** | `pack == null` | 挂载 | 浮层照样开，提示「没有内容包」；无异常 | Widget | 同上 · `没有内容包时浮层照样打开并说明原因（SPEC-FND-014）` |

### 3.19 `VIEW` 域（续十一）· 定位路由与 ② 状态栏（5 条 · `B3` 笔 4a）

> 「选了之后世界怎么变」全在 `_applyHit` 一处 —— 本节每条都在验那一个 switch。
> `TC-VIEW-100` 顺带锁住一条本笔新增的裁定：**落点 = `Z4`，不按 `φ` 定档**（见 `VIEW-027` 修订）。

| 编号 | 对应 `SPEC` | 依据 | 前置 | 步骤 | 预期 | 类型 | 自动化位置 |
|---|---|---|---|---|---|---|---|
| `TC-VIEW-098` | `VIEW-026` | **显式** | α 包，宇宙模式 | `Ctrl+K` → 再按 Esc | 浮层出现后消失；全程无异常 | Widget | `app/test/features/universe/universe_screen_test.dart` · `Ctrl+K 打开定位浮层，Esc 关掉（SPEC-VIEW-026）` |
| `TC-VIEW-099` | `VIEW-028` | **显式** | 输入 `计算机科学` 并点中 | 看 ② 与面包屑 | ② 出现、`subject · 计算机科学` chip 在、面包屑仍是 `Z1 星系`（**不换根**）、浮层已关 | Widget | 同上 · `轴值命中只写筛选：② 出现、视距不动（SPEC-VIEW-028）` |
| `TC-VIEW-100` | `VIEW-027` | **显式** | 输入 `装饰器` 并回车 | 看面包屑与详情 | 面包屑 `宇宙 › Z4 单星`；详情页头是该标题 —— 落点是这一项本身，不是它所在的星云 | Widget | 同上 · `落点命中 ⇒ 跳到该项，详情页头是它的标题（SPEC-VIEW-027）` |
| `TC-VIEW-101` | `VIEW-019` | **显式** | 已有一条 chip | 点 `×` | ② **整块消失**（「激活才出现」是双向的） | Widget | 同上 · `删掉唯一的 chip ⇒ ② 整块消失（SPEC-VIEW-019）` |
| `TC-VIEW-102` | `VIEW-021` | **显式** | 树模式，两次筛选 | 读树标题里的项数 | `subject` 全空间同值 ⇒ 项数不变；换一个 `ability` 取值 ⇒ 项数 = 该取值条数 | Widget | 同上 · `筛选后树里只剩匹配的项（SPEC-VIEW-021）` |

## 四、覆盖缺口

### 4.1 总量

| 口径 | 数量 |
|---|---|
| `SPEC` 唯一编号总数（实测 `grep -ohE` 去重） | **171** |
| 有对应用例的 `SPEC` | **40**（显式 26 + 语义 14）<br>（`v0.4.0` 为 18；`v0.15.0` 起 `VIEW-009` `010` `011` `012` `014` `017` 与 `FND-004` · `NOTE-007` 首次覆盖；`v0.16.0` 起 `VIEW-019` `021` `024` `026` `030` `033` 首次覆盖，再 +6）。`B2` 第 2 笔补上 `FND-008` 定位三态 · `VIEW-025`/`027`/`028`/`029` 快速定位 · `PACK-018` 运行期取包；第 3 笔补上 `FND-010` 事件折叠；第 4 笔补上 `VIEW-002` 三坐标各承载一维） |
| 无用例 | **131** |

按域：

| 域 | `SPEC` 总数 | 有用例 | 缺口 |
|---|---|---|---|
| `FND` | 16 | 10（`002` `003` `004` `005` `008` `010` `011` `012` `013` `014`） | 6 |
| `VIEW` | 34 | 18（`002` `004` `009` `010` `011` `012` `014` `017` `019` `021` `024` `025` `026` `027` `028` `029` `030` `033`） | 16 |
| `PACK` | 18 | 6（`001` `005` `007` `008` `009` `018`） | 12 |
| `PLAN` | 21 | 0 | 21 |
| `STEP` | 34 | 4（`012` `014` `022` `027`） | 30 |
| `QUANT` | 15 | 1（`006`） | 14 |
| `NOTE` | 19 | 1（`007`） | 18 |
| `GOV` | 14 | 0 | 14 |
| **合计** | **171** | **40** | **131** |

### 4.2 缺口必须分三类看，不能混算

**145 这个数字本身说明不了任何问题。** 项目当前只完成 `B1`（三端骨架）与 `B2` 前四笔，171 条需求里绝大多数属于 `B2`–`B9`。把它们算成「测试缺失」等于指责一个还没开工的批次。

| 类别 | 判据 | 性质 | 数量 |
|---|---|---|---|
| **A · 未开工缺口** | 该 `SPEC` 所属批次尚未开始 | **正常**，随批次推进自然收敛 | 137（= 145 − B 类 8，为估算） |
| **B · 已实现无断言** | 代码里已有实际定义或逻辑，但**没有断言锁住该语义** | **真风险** | **8** |
| **C · 有断言但未标号** | 已测，测试里没写裁定编号 | 追溯断链，**非**测试缺失 | **0**（`R-09` 清零） |

> **A 类为什么只能给估算**：判断「未开工」需要逐条核对 `SPEC` 所属批次，而 `design/` 的 171 条并未逐条标注批次归属。137 是按「总数 − 已明确判定的 B、C 两类」倒推的上界，不是逐条核对的结果。把 `SRS` 按批次切片完成后，这个数才能变准。
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

还有 4 条测试**写不出标号**，按规则显式写「无 SPEC：<理由>」而不是硬凑：`fromJson(toJson()) 往返保真`（契约层通用要求）· `target.count 由 resolved 派生`（字段定义在 `reference/entity-fields.md`，非 `SPEC` 条目）· `Event` 的两条 wire 名测试（约定在 `reference/event-types.md`）。

**机制化**：`R5` 规则已进 `tool/lint`，每个 `test` / `testWidgets` 必须带 `SPEC-…` / `C-…` / `ADR-…` / `R<n>` 之一，或显式「无 SPEC：<理由>」。漏标即 CI 红 —— 断链不会再靠人自觉。


## 五、待补与待核

| # | 项 | 类型 | 归属 |
|---|---|---|---|
| 1 | ~~`FND-012` 加 lint 规则（禁 `copyWith` / 禁非 `final` 字段）~~ —— **已处置**（`R3`，`TC-INF-011`–`015`） | 补断言 | ✅ 2026-10-17 闭环 |
| 2 | ~~`VIEW-004` 加架构规则（`sourceRefs` 不得出现在视图层入参）~~ —— **已处置**（`R4`，`TC-INF-016`–`019`） | 补断言 | ✅ 2026-10-17 闭环 |
| 3 | `TC-PACK-010` 的 `SPEC` 标号待核（note 写 `PACK-005`，语义更像 `PLAN-012`） | 待核 | 本轮登记，`B2` 前定 |
| 4 | ~~28 个错误码无 fixture 覆盖~~ —— **已处置**（`TC-PACK-011`–`041`，37/37 + 覆盖对账自检，见 `STP` §六） | 补用例 | ✅ 2026-10-17 闭环 |
| 5 | ~~C 类 13 处补 `SPEC` 标号~~ —— **已处置**（7 条标号进测试名 + 5 条降级进 B 类，`R5` 强制此后不漏） | 补标号 | ✅ 2026-10-17 闭环 |
| 6 | ~~B 类其余 6 条补断言~~ —— **已处置**：`FND-012` / `VIEW-004` 已补机制；余 10 条转入存量 `B2` 起逐批补 | 补断言 | ✅ 2026-10-17 已重分类 |
| 7 | `FND-010` 的 **UI 半边**：`features/` 建成后补一条「视图不持有可写状态」的断言（当前只有核心层的派生关系有断言） | 补断言 | `B3` 视图层开工时 |
| 8 | ~~**「主取值」缺承载位**~~ —— **已处置**：新增 `Item.primaryAxis`（六值枚举，声明式字段），落地在 `entity-fields` `Item` 表 + `channel-table` §一 #5；`ADR-0003` §决策 3 记录了为什么不能用轴序或稀有度代替（那正是规格排除的「按优先级猜」）。代价如实登记：第 4 次扩 schema，须走 `PACK` B 级变更补值 | 补字段 | ✅ 2026-10-17 闭环（`ADR-0003`） |
| 9 | ~~**「指向未知」无视觉表达**~~ —— **已处置**：宇宙视图沿用 `SPEC-VIEW-007` 的黑洞（缺失端画虚线占位节点、父位取源点质心），不新增第三种线型；`channel-table` §一 #6 备注补明文 | 补规格 | ✅ 2026-10-17 闭环（`ADR-0003` §决策 5） |
| 10 | ~~**`φ` 的深度归一化 / 截断**~~ —— **已处置**：径向位置取**累计项数分位**（`r_φ = 累计在前项数 / 总项数`）。原拟的「分段折叠（0–9 / ≥10）」被实算否掉 —— `φ ≥ 10` 的层装了 **126/150 项（84%）**，折叠反而制造新粘连。`SPEC-VIEW-008` 的「首屏到 `φ=2`」管的是树的展开深度，与这条不冲突 | 补规格 | ✅ 2026-10-17 闭环（`ADR-0003` §决策 4） |
| 11 | ~~**帧率判据（`C-32`）待真机实测**~~ —— **已处置**：三档 + 一次窗口对照共四组读数（`76.0` / `60.0` / `72.8` / 全屏 `76.9` fps，均达优线）记入 [`STR`](STR-软件测试报告.md) 轮次 `R1`；判据补了测量前提 `C-33`（基准窗口 `1920×1080`），因为光栅随面积上涨，不绑尺寸则同一档能读出「余量 57%」与「占预算 88%」两种结论 | 补实测 | ✅ 2026-10-17 闭环 |
| 12 | 合成场景的**虚线比例与真实包不一致**：`buildSyntheticScene` 用 `_noise > 0.62` 造出 86/167 条虚线（51.5%），真实包只有 10/167（6.0%），条数差 **8.6 倍** ⇒ 合成档的 draw call（`1908` / `3622`）比真实情形高估约 2.6 倍。不影响 fps 与光栅结论（二者与调用数无关，见 `STR` 轮次 `R1`），但**该列不可当真实值引用** | 口径偏差 | `B3` 换掉合成场景后自然消失；`B3` 前引用该列须带此注 |

> 第 4 项已闭环，数字一并更正：`validator.py` 共 **37 个错误码**（原记 36 —— 那次统计用裸正则扫全文，把注释里提到的码算成了定义），现 **37/37** 有 fixture 断言。**重点不是补完，而是把对账固化成机制**：`verify.py --suite` 里的一步比对「定义集 vs 断言集」，差一条即退出码 1（`v0.9.0` 起该步为第三步，其后新增第四层「输出可移植性」，见 [`STP`](STP-软件测试计划.md) §七 —— 那一层不产生用例）。α 包（`B2`）落地后仍需补**真实坏法样本** —— 那是提高负例代表性，不是补漏，两件事别混。

> 第 5 项的处置值得单独说：补标号有两种做法 —— 「把 12 条都标上」和「只标对得上的」。取后者。因为标号的用途是让 `STR` 机械生成追溯表，而**标错的标号会让追溯表撒谎**，且没有任何机制能事后发现。所以 5 条借位映射降级进 B 类（见 §4.3），宁可在缺口表里显形，也不在追溯表里充数。

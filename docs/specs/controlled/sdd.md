# 软件结构设计说明（SDD）

> **状态**：§二 §三 已写实，§四–§六 待填。§2.1 视图层 **6 份**（实扫）、`core/` 文件树 **五十份**（树内 39 条，`plan/` 11 份待补登）。
> 本文件是**软件结构**的设计视图。分章与 `specs/` 主题文档对齐，实现细节**回指不复制**。当前已映射**八份**（`FND` / `VIEW` / `PACK` / `PLAN` / `STEP` / `QUANT` / `NOTE` / `GOV`）；`ACC` / `SYNC` 两域属 `v0.1.0` 服务端新增，**结构与机制待补**（见 `ACC` / `SYNC` 本身，本文件暂不映射）。
> **追溯补录**：2026-10-17 · §二 §三 依据 `app/lib/` · `app/tool/lint/` · `content/tools/` 的既有代码反推，非当时所写。

## 一、分章与设计文档的映射

| 本章 | 对应设计文档 | 本文件写什么 | 不写什么 |
|---|---|---|---|
| §二 分层与模块边界 | [FND](../FND-foundation.md) · SSDD | 分层、模块划分、依赖方向 | 领域模型定义（回指 FND） |
| §三 内容管线 | [PACK](../PACK-content-pack.md) | 源数据 → 构建 → 加载三段的结构 | pack schema 字段（回指 PACK 与 `entity-fields.md`） |
| §四 事件内核 | [FND](../FND-foundation.md) | 事件表、折叠、持久化的结构 | 事件类型全集（回指 `event-types.md`） |
| §五 视图投影 | [VIEW](../VIEW-views.md) | 投影管线与渲染入口 | 通道映射（回指 `channel-table.md`） |
| §六 关键机制 | [QUANT](../QUANT-quantification.md) · [GOV](../GOV-governance.md) | 掌握度计算、同步与合并的落点 | 参数数值（回指 `constants.md`） |

**为什么这样分**：`specs/` 是活文档（不设版号、随讨论演进），本文件按版号冻结。若复制设计正文，必然出现「设计改了交付物没改」。

## 二、分层与模块边界

### 2.1 现状（`B1` 三端骨架已落地部分）

| 层 | 路径 | 允许依赖 | 禁止依赖 | 现状 |
|---|---|---|---|---|
| **核心层** | `app/lib/core/` | 纯 Dart SDK + `core/` 内部 | Flutter · `dart:ui` · `features/` · 一切 I/O | ✅ 已落地 |
| **外壳层** | `app/lib/main.dart` | Flutter + `core/` | 不得被 `core/` 反向引用 | ✅ 已落地（空态） |
| **视图层** | `app/lib/features/` | Flutter + `core/` | — | ⚠️ 视图层 **6 份**（实扫）：`planner/` 3（面板 · 整页 · 自建对话）· `locate/` 1（定位浮层）· `detail/` 1 · `palette.dart` 1。**23 → 6 是 `B13a` 笔 5a 的结果** —— `universe/` 20 份（六轴五档渲染 + 树视图 + 绘制 spike）整层删除，容器树界面归 `B17a`、3D 归 `B17b` |
| **静态检查** | `app/tool/lint/` | Dart SDK | 不参与构建产物 | ✅ 已落地（`R1` `R2`） |
| **内容工具** | `content/tools/` | Python 标准库 | 第三方包 | ✅ 已落地（三脚本） |
| **服务端** | `server/` | — | — | ⬜ 仅 `README` + `AGENTS`（`P4`） |
| **基础设施** | `infra/` | — | — | ⬜ 仅 `README` + `AGENTS`（`P3`/`P4`） |

`core/` 实际文件：

```
app/lib/core/                    共 49 份（树内 38 条；`plan/` 11 份尚未补登，见下）
├── constants.dart          常量表（docs/specs/constants.md 的代码投影）
├── enums.dart              枚举全集（含 wire 名映射）
├── errors.dart             错误类型（含 TbdConstantError）
├── ids.dart                id 末段显示（域 / 缺口 id 共用一处）
├── json.dart               JSON 严格解析 helper
├── entities/
│   ├── content.dart        **旧实体件**：`Item` · `Edge` · `Scheme` · `SourceRef` · `MethodProfile` 等，逐份由 `entities/` 新件替换，删归笔 5c
│   ├── edge.dart           三类边 `sealed` 三分 + 按 `type` 判别符分派（唯一入口）
│   ├── entry.dart          NodeEntry · Resource · EntryStep · Criterion · QuizItem（补裁 `source_refs[]`）
│   ├── method.dart         新格式 MethodProfile · MethodBundle（旧件在 `content.dart`，笔 5 收口）
│   ├── node.dart           `Node` 按槽位 `sealed` 两分（结构 / 可学）+ `R6`–`R9` 守形态
│   ├── overlay_patch.dart  OverlayPatch（`value` 为 `Object?`，**不收窄**）
│   ├── pack.dart           Pack + 四类特化事实（`kinds[]` 与字段一一对应，违反抛 `IllegalPackKindError`）
│   ├── path_claims.dart    PathClaim（`live` / `tombstone`）+ PathAlias（蛇形 wire）
│   ├── plan.dart           Plan · Target
│   ├── requirement.dart    Requirements（六要件 × 三态；笔 5b 从 `content.dart` 的 `ItemRequirements` 改名搬出 —— 旧名把「属于 `Item`」写进了类型名，而 `ADR-0007` 之后要件只挂可学节点）
│   ├── scheme.dart         新格式 Scheme（带 `AuthorityLevel`；旧件在 `content.dart`，笔 5 收口）
│   ├── source.dart         新格式 SourceRef · SourceSegment · SourceAppliesTo（同上，笔 5 收口）
│   └── state.dart          SrsState · ViewState 等状态实体
├── events/
│   ├── event.dart          Event · Hlc · EventType ↔ wire 名
│   ├── event_store.dart    事件存储接口（只 append）
│   ├── fold.dart           事件 → 状态（纯函数）
│   ├── hlc_clock.dart      混合逻辑时钟
│   ├── id.dart             事件 id 由 HLC 派生，不引 uuid
│   └── migration.dart      包迁移账本
├── graph/
│   ├── levels.dart         `⪯` 上的 Kahn 层号（= `φ`）
│   └── parent_index.dart   child → 主父索引 + `pathOf` 每次从父链重算，不缓存
├── locate/
│   ├── diagnose.dart       无命中的四类分诊 + 邻近候选（不过滤、不渲染）
│   └── locator.dart        快速定位匹配 + 三态（判在可用命中上）
├── pack/
│   ├── cycle_check.dart    环检测（`findCyclesFrom` 供新解析层复用，旧签名转调）
│   ├── dart_io_pack_fs.dart 唯一 `dart:io` 处（读 + 原子写 + 追加）
│   ├── pack_fs.dart        内容包的只读接缝（`StoreFs` 的包语义名）
│   ├── pack_parse.dart     清单 + 产物 → LoadedPack（旧格式，笔 5 删）
│   ├── pack_probe.dart     候选根探测
│   ├── pack_reader.dart    单文件六段解析（无 `meta` 信封；`counts` 与 `nodes[]` 实扫一致）
│   └── triple_validator.dart 三元校验器（6 码 fail-fast，`path-rules` §六）
├── storage/
│   ├── store_fs.dart       三区接缝：只读 / 可写（原子写）/ 只追加
│   └── store_layout.dart   三区物理根 + 互不重叠校验 + 区内路径解析
└── view/
    ├── detail.dart         详情三区渲染模型（关系 / 要件 / 来源）
    └── zoom.dart           五档视距 + `φ` → 档位
```

⚠️ **`plan/` 11 份（`applies_to` · `candidates` · `method_bundle` · `ordering` · `plan_draft` · `plan_events` · `plan_target` · `platform_candidates` · `preview` · `scope` · `user_content`）尚未进树** —— 它们随 `B4` 的 `P-6`–`P-8` 落地，而那一批只改了别处的份数、没回头改本树。上面那句「共 49 份」是按 `find` 实扫的，不是树内条数相加（38 + 11）；树内 38 条已对账 —— 无「树里有、磁盘无」，亦无反向漏登。补登归 `B13a` 笔 6 收口：笔 3 补了自己新增的 `storage/` 两份与笔 1 / 笔 2 落下的 5 份，笔 4 补了新增的 8 份（`entities/` 七 + `pack_reader`），笔 5a 反向摘掉了整层删除的 10 条（`frame/` 三 · `graph/subtrees` · `view/` 六）。

### 2.2 约束如何被强制执行

core 层的两条边界**不是写在文档里的约定**，而是可执行规则：

| 规则 | 内容 | 实现 | 用例 |
|---|---|---|---|
| `R1` | `lib/core/**` 不得 import Flutter / `dart:ui` / `features/` | `app/tool/lint/rules.dart` | `TC-INF-001`–`TC-INF-004` |
| `R2` | `lib/core/**`（除 `constants.dart`）禁止数字字面量 | 同上 | `TC-INF-005`–`TC-INF-009` |

- **为什么用独立 lint 而非测试**：这两条要看**语法结构**（import 目标、字面量位置），不是看行为输出。测试只能验「跑起来对不对」，验不了「代码长什么样」。
- **`R2` 为什么豁免 `constants.dart`**：常量表就是这个规则要收口的那个地方本身；豁免它，其余文件才无处可躲。
- **`0` 与 `1` 放行**：坐标原点与计数基元，强行具名会让代码更难读。
- **`features/` 不做数字检查**：间距、尺寸属设计 token，不属知识语义常量。

> 与 [`constants.md`](../constants.md) 的关系：`R2` 保证「数字只能出现在常量表」，`TC-QUANT-001`–`TC-QUANT-007` 保证「常量表里的值与文档一致」。两条合起来才能防住「有人绕过常量表直接写数」。

## 三、内容管线

### 3.1 三段与边界

| 段 | 输入 | 处理 | 输出 | 现状 |
|---|---|---|---|---|
| **① 源数据** | `content/<space>/` 六段 JSON | 人工撰写 | 受版本控制的源 | ✅ `content/tools/fixtures/` 有 9 份样例 |
| **② 构建** | 源数据 | `validator.py` 校验 → `build.py` 序列化 | `<space>/dist/pack.json` | ✅ 已落地 |
| **③ 运行期加载** | `pack.json` | 解析 → 建内存模型 | 可渲染的空间 | ⬜ **未实现**（`B2`） |

**第二段的两条硬约束**：

1. **确定性**：`build.py` 硬编码序列化参数（`sort_keys` + 固定缩进 + `ensure_ascii=False` + 末尾单换行）。换任何一项，同一 commit 的两次构建就不是同一串字节，`dist/` 与 tag 对不上。
2. **`meta.version` 原样透传**，绝不改写；`meta` 是信封不是内容段，**不含构建时间戳** —— 加了时间戳，确定性当场失效。

### 3.2 第三段为什么必须单独设计（不是「读个文件」）

开发期的路径假设是 `content/<space>/dist/pack.json`，它成立的前提是**从仓库根目录运行**。装成 exe / ipa 之后：

| 环境 | 该路径是否存在 |
|---|---|
| `flutter test` / `flutter run`（CWD = `app/`） | 存在（回溯到仓根） |
| Windows exe | **不存在** —— 用户的安装目录里没有源码树 |
| macOS `.app` | **不存在** —— 沙盒内只有容器路径 |
| iOS `.ipa` | **不存在** —— 只读 bundle |

后果不是「体验差」，是**安装包能启动但一条内容都没有**。`project-language` 实际踩过这个坑（上架包里没有任何语言包）。

**本项目选择 exe 同级解析**（内容包与可执行文件并列放置），与 `project-language` 的「内置资产 + 首启复制沙盒」不同：

| 方案 | 做法 | 选它的理由 |
|---|---|---|
| **exe 同级解析**（本项目） | 运行时按可执行文件所在目录找 `content/` | 内容包可由用户替换 / 增补，不必重新打包 |
| 内置资产 + 首启复制（language） | 包打进 Flutter assets，首启复制到可写目录 | 上架商店时无法保证同级目录可写 |

**⚠️ 这一选择有一个前置后果必须在 `B2` 就确认**：App Store 上架时，iOS/macOS 的 bundle 目录是**只读且签名校验**的，同级解析在上架形态下不成立。因此 `P3`（上架与分发）开工前必须补一条回落路径 —— 这不是 `B8` 才需要想的事，`B2` 写加载器时就要把「路径探测」与「解析」拆开，否则到时候要重写。

**`PackLoader` 的改动边界**：只改「路径从哪来」，不改「拿到 bytes 之后怎么解析」。这样第三段的解析逻辑可以被单元测试覆盖，无需真实安装包。

### 3.3 生成物不入库

`dist/` 由 `.gitignore` 覆盖，CI 有独立判据（`content-checks.yml` 第四步）。**内容包 tag 是产物的唯一指针** —— `dist/` 不入库，所以「某次发布用的是哪份产物」只能靠 tag 回溯。

这也是校验器**不得静默修正源数据**的原因：静默 `strip` 一个前导空格，tag 名与产出就对不上了。`TC-PACK-009` 锁定的正是这一条。

## 四、事件内核

<!-- 待填。→ 填充时点：`B2` 收尾时。 -->

## 五、视图投影

<!-- 待填。→ 填充时点：`B3` 收尾时。 -->

## 六、关键机制

<!-- 待填。→ 填充时点：`B6` / `B9` 收尾时。 -->

## 历史（迁移前版号序列）

> 以下为**迁入 `specs/` 之前**的版号序列，用于与旧版交付物对账，**不是现行版号** —— 本文件作为活文档不设版号，更新时间以 `git log` 为准。

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.16.1` | 2026-10-22 | **勘误**：`ADR-0008` 换轨后目录名过时 —— 分章映射表述 + §三–§六 四处回指 + 文件树里的常量表出处。只改路径指向，**分层、映射与文件计数零改动**。 |
| `v0.16.0` | 2026-10-21 | §2.1 树补 **1 份**：`entities/requirement.dart` —— 笔 5b 把 `Requirements` 从 `content.dart` 的 `ItemRequirements` 改名搬出，`node.dart` 改用新名（旧名把「属于 `Item`」写进类型名，而 `ADR-0007` 之后要件只挂可学节点）；`content.dart` 那一行改为「旧实体件，删归笔 5c」。计数 `find` 实扫 49 → **50 份**、树内 38 → **39 条** |
| `v0.15.0` | 2026-10-21 | §2.1 摘掉整层删除的 **10 条**：`frame/` 三份（`pick` · `projection` · `scene`）· `graph/subtrees.dart` · `view/` 六份（`filter` · `fit` · `motion` · `navigation` · `tree` · `viewport`）。计数按 `find` 实扫 59 → **49 份**、树内 48 → **38 条**；视图层 23 → **6 份**（`planner/` 3 · `locate/` 1 · `detail/` 1 · `palette.dart` 1）。**这不是登记遗漏，是 `ADR-0005` 的后果落地** —— 六轴五档渲染整层作废，`core/frame` 与 `core/view` 五份只服务它，`main.dart` 退回单一空态 |
| `v0.14.0` | 2026-10-21 | §2.1 `core/` 树补登 **8 份**（笔 4 落下却未进树）：`entities/` 七份 —— `pack.dart` · `entry.dart` · `path_claims.dart` · `overlay_patch.dart` · `source.dart` · `scheme.dart` · `method.dart`，`pack/` 一份 —— `pack_reader.dart`。计数按 `find` 实扫 51 → **59 份**、树内 40 → **48 条**；`plan/` 11 份仍待笔 6 补登。⚠️ `source` / `scheme` / `method` 三份与 `entities/content.dart` 里的旧同名类型**并存** —— 旧件是 α 包链路（12 个用例仍在跑），删除归笔 5，树里已就地标注 |
| `v0.13.0` | 2026-10-20 | §2.1 `core/` 树补登 **7 份**并新增 **`storage/` 一层**：`entities/node.dart` · `entities/edge.dart` · `events/id.dart` · `graph/parent_index.dart` · `pack/triple_validator.dart`（前五份是笔 1 / 笔 2 落下却没进树的）+ `storage/store_fs.dart` · `storage/store_layout.dart`（笔 3 新建）。计数按 `find` 实扫改为 **51 份**。⚠️ **树内只有 40 条** —— `plan/` 11 份（`P-6`–`P-8` 落地）从来没进过树，树下一段已显式列出，补登归 `B13a` 笔 6。这不是本笔新增的滞后，是攒了三批的；写明而非静默改。同时把 `pack_fs.dart` 的描述从「文件系统抽象」改为「内容包的只读接缝」—— 它现在零方法、三方法收口到 `StoreFs` |
| `v0.12.0` | 2026-10-18 | §2.1 `core/view/` 由 7 份 → **8 份**（增 `motion.dart`，`V-1i` 前半）：三个纯函数（`orbitPhase` 相位 · `spunRadians` 相位→弧度 · `governorFactor` 减速系数）+ 一个换算（`advanceClock` 累计时钟）。放 `core/view/` 而不是屏幕里的理由与 `navigation.dart` 同一套 —— 「时钟只增不回卷」「跨周期边界相位连续」「系数随距离单调」全是**可判定**的判据，留在 `_State` 里只能靠 widget test 隔着 24 s 的 `pump` 间接验。同版按**实扫**修两处：`core/` 总数 31 → **33**（`graph/subtrees.dart` 是 `V-1d` 新增却一直没进树 —— 那一笔只改了 §5 的份数没改本树），树内计数行「共 28 份」也早已与树自身条目数（31）不一致，一并校正。**注意这里刻意不放 `Ticker` / `AnimationController`** —— 那两个是 Flutter 类型，核心层禁 `dart:ui`（`R1` 规则），时钟只以「秒数」进出 |
| `v0.11.0` | 2026-10-18 | §2.1 `features/` 增两个文件：`universe/star_closeup.dart`（`Z4` 恒星特写的几何）与 `universe/star_closeup_painter.dart`（绘制）。与 `Z3` 同为「几何 / 绘制」一对，理由也相同 —— 前者是纯函数（可断言轨道数、确定性、斑点分布），后者只负责把布局变成画布指令。⚠️ **顺带修一处长期滞后**：§2.1 视图层一行自 `v0.7.0` 起一直写「12 份」，而 `B12` 前四笔各增一对几何 / 绘制文件后再没人改它；本版按**实扫**改为 **23 份**（`universe/` 20 + `locate/` 1 + `detail/` 1 + `palette.dart` 1）。这不是本笔新增导致的，是四笔累计未同步 —— 写明而非静默改 |
| `v0.10.0` | 2026-10-18 | §2.1 `navigation.dart` 再扩一格：`ViewSnapshot` 加 `domainId`（七字段，`SPEC-VIEW-015` 修订三）。**文件数不变** —— 「域」和「空间」同属这条判据的**参数**，不是新的一层。为什么这个字段非在 `core/view/` 不可：`Z2` 的画面只画一个域，而域**推不出来**（档位 + 空间只说了「在这个空间的某个域里」，选中项在从 `Z3` 退到 `Z2` 时被清空）—— 判据落到屏幕里就只能靠 widget test 间接验，而漏掉的表现是「返回后空屏配两段面包屑」，没有任何东西会变红 |
| `v0.9.0` | 2026-10-18 | §2.1 `core/view/navigation.dart` 的职责扩一格：`ViewSnapshot` 加 `spaceId`（六字段），`trail` 的元素由 `itemId` 改为 `TrailStep{spaceId, itemId}`。**文件数不变** —— 多根是这条判据的参数，不是新的一层。放这里的理由与 `v0.8.0` 同： 「返回该回到哪个空间的哪一项」是可判定判据，留在 `State` 里只能靠 widget test 间接验 |
| `v0.8.0` | 2026-10-18 | §2.1 `core/view/` 由 6 份 → **7 份**（增 `navigation.dart`）：`ViewSnapshot` 五字段快照 + `pushTrail` / `popTrail`。放 `core/view/` 而不是屏幕里，因为「`trail` 超 `C-21` 丢哪端」「同一项要不要去重」都是**可判定**的判据，与「谁来调」无关 —— 留在 `State` 里就只能靠 widget test 间接验。`core/` 30 → **31 份** |
| `v0.7.0` | 2026-10-17 | §2.1 `core/frame/` 由 2 份 → **3 份**（增 `pick.dart`）：拾取只做「已投影的一帧 → 点中了谁」，**投影与取景都不归它** —— 重算一遍就有两套几何，改任一处的口径都会变成「看得见点不中」的偶发缺陷。`features/` 11 → **12 份**（增 `universe/scene_pick.dart`：装配入口，复用 `buildSceneFrame` 与 `paint` 同源）。`core/` 29 → **30 份** |
| `v0.6.0` | 2026-10-17 | §2.1 `core/locate/` 由 1 份 → **2 份**：`locator.dart`（命中与三态）+ `diagnose.dart`（无命中四类分诊与邻近候选，`SPEC-VIEW-030` / `032`）。拆分的判据：**存在性归引擎、可用性与分诊归另一层** —— 圈外项仍在命中集里，但不可落点；把分诊塞进 `Locator` 会让「三态」同时回答两个问题。`core/` 28 → **29 份**；视图层仍十一份（`locate_overlay.dart` 内扩，未新增文件） |
| `v0.5.0` | 2026-10-17 | §2.1 视图层九份 → **十一份**（增 `locate/locate_overlay.dart` 与 `universe/filter_chips.dart`）；`core/` 文件树 27 → **28 份**（增 `view/filter.dart`）。§2.2 规则表与 §3.1 的滞后**仍未动**（同 `v0.4.0` 的注） |
| `v0.4.0` | 2026-10-17 | §2.1 视图层由「spike 占位」改为**正式视图层九份**（宇宙 7 · 详情 1 · 调色板 1；spike 保留作 `STR` 复跑装置）；`core/` 文件树由 5 份补全至**实扫 27 份**（原树停在 `B1` 收尾状）。**未改** §2.2 规则表（仍只列 `R1` / `R2`，`R3`–`R5` 的登记滞后）与 §3.1「9 份样例 / 第三段未实现」—— 两处是更早的滞后，不在本笔范围 |
| `v0.3.0` | 2026-10-17 | §2.1 视图层由「⬜ 未建（`B3`）」改为「⚠️ spike 占位（`B2` 第 5 笔 · 5 份，`B3` 重写）」—— `features/` 首次有代码，但它是一次帧率实测的**测量装置**，不是视图层设计；§五 视图投影仍待填，填充时点不变 |
| `v0.2.0` | 2026-10-17 | **追溯补录** §二 分层与模块边界、§三 内容管线。据代码现状写实，并标明第三段（运行期加载）尚未实现 |
| `v0.1.0` | 2026-10-17 | 首建。确立与 `design/` 的分章映射；结构与机制待补 |

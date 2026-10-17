# 软件结构设计说明（SDD）

> **版号**：`v0.7.0` · **状态**：§二 §三 已写实，§四–§六 待填（§2.1 视图层为**正式视图层十二份**，`core/` 文件树按实扫补全至 **30 份** —— 定位层拆引擎与分诊，构图层拆绘制与拾取）
> 本文件是**软件结构**的设计视图。分章与 `design/` 八份主题文档对齐，实现细节**回指不复制**。
> **追溯补录**：2026-10-17 · §二 §三 依据 `app/lib/` · `app/tool/lint/` · `content/tools/` 的既有代码反推，非当时所写。

## 修订历史

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建。确立与 `design/` 的分章映射；结构与机制待补 |
| `v0.2.0` | 2026-10-17 | **追溯补录** §二 分层与模块边界、§三 内容管线。据代码现状写实，并标明第三段（运行期加载）尚未实现 |
| `v0.7.0` | 2026-10-17 | §2.1 `core/frame/` 由 2 份 → **3 份**（增 `pick.dart`）：拾取只做「已投影的一帧 → 点中了谁」，**投影与取景都不归它** —— 重算一遍就有两套几何，改任一处的口径都会变成「看得见点不中」的偶发缺陷。`features/` 11 → **12 份**（增 `universe/scene_pick.dart`：装配入口，复用 `buildSceneFrame` 与 `paint` 同源）。`core/` 29 → **30 份** |
| `v0.6.0` | 2026-10-17 | §2.1 `core/locate/` 由 1 份 → **2 份**：`locator.dart`（命中与三态）+ `diagnose.dart`（无命中四类分诊与邻近候选，`SPEC-VIEW-030` / `032`）。拆分的判据：**存在性归引擎、可用性与分诊归另一层** —— 圈外项仍在命中集里，但不可落点；把分诊塞进 `Locator` 会让「三态」同时回答两个问题。`core/` 28 → **29 份**；视图层仍十一份（`locate_overlay.dart` 内扩，未新增文件） |
| `v0.5.0` | 2026-10-17 | §2.1 视图层九份 → **十一份**（增 `locate/locate_overlay.dart` 与 `universe/filter_chips.dart`）；`core/` 文件树 27 → **28 份**（增 `view/filter.dart`）。§2.2 规则表与 §3.1 的滞后**仍未动**（同 `v0.4.0` 的注） |
| `v0.4.0` | 2026-10-17 | §2.1 视图层由「spike 占位」改为**正式视图层九份**（宇宙 7 · 详情 1 · 调色板 1；spike 保留作 `STR` 复跑装置）；`core/` 文件树由 5 份补全至**实扫 27 份**（原树停在 `B1` 收尾状）。**未改** §2.2 规则表（仍只列 `R1` / `R2`，`R3`–`R5` 的登记滞后）与 §3.1「9 份样例 / 第三段未实现」—— 两处是更早的滞后，不在本笔范围 |
| `v0.3.0` | 2026-10-17 | §2.1 视图层由「⬜ 未建（`B3`）」改为「⚠️ spike 占位（`B2` 第 5 笔 · 5 份，`B3` 重写）」—— `features/` 首次有代码，但它是一次帧率实测的**测量装置**，不是视图层设计；§五 视图投影仍待填，填充时点不变 |

---

## 一、分章与设计文档的映射

| 本章 | 对应设计文档 | 本文件写什么 | 不写什么 |
|---|---|---|---|
| §二 分层与模块边界 | [FND](../../design/FND-foundation.md) · [SSDD](SSDD-系统结构设计说明.md) | 分层、模块划分、依赖方向 | 领域模型定义（回指 FND） |
| §三 内容管线 | [PACK](../../design/PACK-content-pack.md) | 源数据 → 构建 → 加载三段的结构 | pack schema 字段（回指 PACK 与 `reference/entity-fields.md`） |
| §四 事件内核 | [FND](../../design/FND-foundation.md) | 事件表、折叠、持久化的结构 | 事件类型全集（回指 `reference/event-types.md`） |
| §五 视图投影 | [VIEW](../../design/VIEW-views.md) | 投影管线与渲染入口 | 通道映射（回指 `reference/channel-table.md`） |
| §六 关键机制 | [QUANT](../../design/QUANT-quantification.md) · [GOV](../../design/GOV-governance.md) | 掌握度计算、同步与合并的落点 | 参数数值（回指 `reference/constants.md`） |

**为什么这样分**：`design/` 是活文档（不设版号、随讨论演进），本文件按版号冻结。若复制设计正文，必然出现「设计改了交付物没改」。

## 二、分层与模块边界

### 2.1 现状（`B1` 三端骨架已落地部分）

| 层 | 路径 | 允许依赖 | 禁止依赖 | 现状 |
|---|---|---|---|---|
| **核心层** | `app/lib/core/` | 纯 Dart SDK + `core/` 内部 | Flutter · `dart:ui` · `features/` · 一切 I/O | ✅ 已落地 |
| **外壳层** | `app/lib/main.dart` | Flutter + `core/` | 不得被 `core/` 反向引用 | ✅ 已落地（空态） |
| **视图层** | `app/lib/features/` | Flutter + `core/` | — | ✅ 正式视图层 **12 份**：`universe/` 9（正式界面 · 树视图 · 筛选 chips · 绘制 · 绘制目标 · 帧统计 · 场景源 · **拾取** · 绘制 spike）· `locate/` 1（定位浮层）· `detail/` 1 · `palette.dart` 1。spike 是 `STR` 复跑装置，**不是产品路径** |
| **静态检查** | `app/tool/lint/` | Dart SDK | 不参与构建产物 | ✅ 已落地（`R1` `R2`） |
| **内容工具** | `content/tools/` | Python 标准库 | 第三方包 | ✅ 已落地（三脚本） |
| **服务端** | `server/` | — | — | ⬜ 仅 `README` + `AGENTS`（`P4`） |
| **基础设施** | `infra/` | — | — | ⬜ 仅 `README` + `AGENTS`（`P3`/`P4`） |

`core/` 实际文件：

```
app/lib/core/                    共 28 份
├── constants.dart          常量表（docs/reference/constants.md 的代码投影）
├── enums.dart              枚举全集（含 wire 名映射）
├── errors.dart             错误类型（含 TbdConstantError）
├── ids.dart                id 末段显示（域 / 缺口 id 共用一处）
├── json.dart               JSON 严格解析 helper
├── entities/
│   ├── content.dart        Item · ItemRequirements · Edge · Scheme · SourceRef · MethodProfile
│   ├── plan.dart           Plan · Target
│   └── state.dart          SrsState · ViewState 等状态实体
├── events/
│   ├── event.dart          Event · Hlc · EventType ↔ wire 名
│   ├── event_store.dart    事件存储接口（只 append）
│   ├── fold.dart           事件 → 状态（纯函数）
│   ├── hlc_clock.dart      混合逻辑时钟
│   └── migration.dart      包迁移账本
├── frame/
│   ├── pick.dart           屏幕点 → 节点 id（只吃已投影的一帧，不算几何）
│   ├── projection.dart     三维几何（`r/θ/φ` → 屏幕）
│   └── scene.dart          图模型 → SceneNode（只取值，不做几何）
├── graph/
│   └── levels.dart         `⪯` 上的 Kahn 层号（= `φ`）
├── locate/
│   ├── diagnose.dart       无命中的四类分诊 + 邻近候选（不过滤、不渲染）
│   └── locator.dart        快速定位匹配 + 三态（判在可用命中上）
├── pack/
│   ├── cycle_check.dart    环检测
│   ├── dart_io_pack_fs.dart 唯一 `dart:io` 处
│   ├── pack_fs.dart        文件系统抽象
│   ├── pack_parse.dart     清单 + 产物 → LoadedPack
│   └── pack_probe.dart     候选根探测
└── view/
    ├── detail.dart         详情三区渲染模型（关系 / 要件 / 来源）
    ├── filter.dart         筛选表达式 DNF（同轴 OR / 跨轴 AND）
    ├── fit.dart            自适应取景
    ├── tree.dart           树行模型（四类可见集合）
    ├── viewport.dart       绘制表面按面积封顶（`C-33`）
    └── zoom.dart           五档视距 + `φ` → 档位
```

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

> 与 [`../../reference/constants.md`](../../reference/constants.md) 的关系：`R2` 保证「数字只能出现在常量表」，`TC-QUANT-001`–`TC-QUANT-007` 保证「常量表里的值与文档一致」。两条合起来才能防住「有人绕过常量表直接写数」。

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

# ADR-0001 · 项目基线：架构形态与开源协议

- **状态**：已接受
- **日期**：2026-10-17
- **决策人**：liberal

## 背景

本项目（Weltuhr）需要把一份已完成的知识体系学习方法论落地为软件：桌面（Windows / macOS）+ iOS 的客户端，加服务端同步与治理。方法论本身见 [`../intent/knowledge-system-learning-methodology.md`](../intent/knowledge-system-learning-methodology.md)，产品与系统的设计规范已完成（140 条裁定），需要一份可实施的基线。

## 决策

### 1. 形态：Flutter 客户端 + Serverpod 服务端 + 内容包管线的 monorepo

顶层五目录与 commit scope 一一对应：`app/` `server/` `content/` `docs/` `infra/`。

**理由**：

- 客户端一套代码覆盖三端，且三维渲染需要 `Canvas` 级控制（不复用三方 3D 引擎）；
- 服务端必须支持**离线优先**的事件合并，Serverpod 提供 PostgreSQL + 迁移 + 鉴权骨架；
- 内容包是**数据而非代码**，独立目录 + 独立构建脚本，才能保证「零核心代码改动接入新空间」。

### 2. 内容分发：一空间一包 + overlay 双平面

**理由**：空间是最小可独立升级的单元（三条边界判据）；overlay 让用户自建内容不必等发版。

### 3. 状态模型：事件溯源 + 混合逻辑时钟

**理由**：离线闭环是硬约束（M2a），服务端递增序号在离线时拿不到；而 FSRS 的 `D`/`S` 不可交换，只有偏序不足以确定重放顺序。HLC 是唯一能**离线生成且保证全序**的方案。

**代价**：事件 schema 一旦上线就难改；物理时钟会被设备偏差污染，须由服务端 clamp。

### 4. 开源协议：Apache-2.0

**理由**：

1. 含**显式专利授权** —— 本项目涉及算法（掌握度合成、FSRS 调度），比 MIT 更稳；
2. **宽松可商用** —— 允许闭源集成与私有化交付，不反向限制商业模式；
3. **条款完备** —— 商标、变更声明（`NOTICE`）、贡献者许可均有明文，审计好交代。

**被否方案**：

| 方案 | 为什么否 |
|---|---|
| MIT | 无专利授权条款；且与同源的 `project-language` 许可不一致，跨仓复用代码时口径会分叉 |
| AGPL-3.0 | 强传染覆盖 SaaS，要求衍生开源 —— 与「允许闭源集成」的定位冲突 |
| 专有 / 闭源 | 与「公开方法论、接受社区贡献」的意图冲突 |

### 5. 仓库标识不随品牌名改

仓名 / 目录名 `project-knowledge`、Dart 包 `project_knowledge`、产品名 `Weltuhr`。

**理由**：品牌名可换，仓库标识一换就牵动仓名、包名、CI 配置与全部既有 commit 引用。**品牌名 ≠ 仓标识**，两者解耦。

**应用标识（bundle id）是反向的例外**：`com.weltuhr.projectKnowledge` —— **前缀跟品牌、后缀跟包名**。理由：bundle id 是**对外产品身份**（牵动证书与 App Store 记录，首版发布后不可改），而仓名是内部标识，两者的寿命与受众都不同。iOS / macOS 均取此值（`RunnerTests` 在同一值后追加 `.RunnerTests`）；Windows 无 bundle id，由 `Runner.rc` 的 `CompanyName` 承接同一命名空间。

**版权主体取自然人**：Windows `LegalCopyright` 与 macOS `PRODUCT_COPYRIGHT` 写 `liberal`，与 `LICENSE` 一致。**不用反向域名**——反向域名是标识符，不是法律主体。

> **更新（2026-10-18）**：**仓名已改为 `weltuhr-knowledge`**（GitHub 侧；本地目录仍 `project-knowledge`，与仓名解耦）。本条对**标识名**的判断不变 —— Dart 包 `project_knowledge`、bundle `com.weltuhr.projectKnowledge`、Windows `InternalName`、CMake `project()` 一律不动。
>
> 失效的只是把**仓名**并进「标识」这一步归类。仓名不进编译、不进签名，只出现在 remote URL 与外部链接里，属**协作层**，跟品牌走。原判据说「一换就牵动既有 commit 引用」，实测不成立 —— 改名不动任何 commit hash，PR / issue 编号原样保留，旧地址由 GitHub 301 兜住。
>
> 真正的截止期不是「现在还是以后」，而是**第一个把仓名写进产物的东西**（更新器下载地址、镜像、公网分发）。它一出现，改名就从「一条命令 + 六处 clone 命令行」变成「永久依赖重定向，或断掉老客户端的更新检查」。
>
> 顺带修正一处判断：`project-knowledge` 里 **`project-` 才是占位**（「还没起名，先叫项目」），`-knowledge` 是**域**、有信息量。所以换品牌时该换的是占位那一半，`weltuhr-knowledge` 正是「换占位、留域」。

## 影响

- `LICENSE` = Apache-2.0 全文 + `NOTICE` 随首提入库。
- `.github/SECURITY.md` 随首提落盘（承诺：仅最新 minor · 7 个工作日内首次回复 · GitHub 私密报告）。
- 依赖许可须逐项核查，**强传染（GPL / AGPL）依赖禁止引入**（见 `../specs/dependency-licenses.md`）。
- 事件 schema 的新增字段一律可空，`fold` 必须有默认语义 —— 这是事件溯源上线后的兼容性约束。

## 后续

- 待补：`app/` `server/` `content/` 的脚手架生成（须单独变更）。
- 待补：搜索模糊匹配阈值（`C-28`）—— 三个 TBD 常量中余此一项，须实测标定。FSRS 目标保留率（`C-03` = 0.90）与打卡封顶系数（`C-25` = 0.5）已于 2026-10-17 裁定（见 `../specs/constants.md`）。

> **更新（2026-10-18）**：本条已失效。`C-28` 已裁定 —— **v0.1 不适用**（模糊档 = 子串包含，不做相似度阈值）。至此三个 `TBD` 常量全部有结论，**常量表当前无 `TBD` 项**。理由与边界见 `../specs/constants.md` §八注。

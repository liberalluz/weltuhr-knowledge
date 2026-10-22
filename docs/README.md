# 文档体系索引

> 本文件是**文档导航**，不写项目介绍（项目介绍见仓根 [README.md](../README.md)）。
> 单一事实源：参数只在 `specs/` 的横切表里维护一处，其余文档**引用不复制**。

## 一、目录分工

| 目录 | 一句话定义 | 内容 | 版号 |
|---|---|---|---|
| [specs/](specs/00-index.md) | **应当如何** | 设计规格：10 份主题规格 + 8 份横切表/规格 + 2 份工程规范 | 活文档，不设版号 |
| [decisions/](decisions/) | **定没定** | 8 份 ADR（为什么这么选，含被否方案与代价）+ 2 份台账（`not-list` 已裁不做 · `open-decisions` 未裁待定） | 活文档，不设版号 |
| [intent/](intent/) | **为什么** | 两份方法论长文 —— 全案的上游依据，`specs/` 全部引用它而它不引用 `specs/` | 活文档，不设版号 |
| [ideas/](ideas/README.md) | **还没认定的想做什么** | 候选，尚未被接受成决策或规格。**当前为空，空本身是信息** | 活文档，不设版号 |
| [runbooks/](runbooks/environment.md) | **怎么把东西跑起来** | 操作手册：环境搭建与跑法、已知的坑 | 活文档，不设版号 |
| [deliverables/](deliverables/README.md) | **要签字、有版号** | 按 GB/T 8567 组织的**六段 25 种**（计划 / 需求 / 设计 / 测试 / 交付 / 总结） | `vX.Y.Z` 独立递增 |

**判据**（放进来之前问自己）：讲「应当如何」→ `specs/`；讲「定没定」→ `decisions/`；讲「为什么」→ `intent/`；**还没认定**的候选 → `ideas/`；讲「怎么操作」→ `runbooks/`；要对外交付、需签字 → `deliverables/`。

> **`deliverables/` 是另一根轴**：上面五个按**内容**分（活文档、不设版号），它按**版本**分（`vX.Y.Z` 独立递增）。两者不并进同一套判据 —— 一份交付物可以既讲「应当如何」又讲「定了什么」，它靠版号冻结而不是靠目录分类。

> **仓根的 `README.*.md` 不参与上述判据**：它不是一类文档，而是仓根 README 的语言副本 —— 中文原文 `README.zh-CN.md`，另有 `de` / `it` / `ja` / `fr` 四份译本。译本规则（文件命名、切换条顺序、溯源行、不译清单）的唯一权威处是 [`AGENTS.md`](AGENTS.md) §译本规范。

三个**唯一权威处**（别处只引用不复制）：

| 内容 | 唯一权威处 |
|---|---|
| 交付物清单与命名（六段 25 种） | [`deliverables/README.md`](deliverables/README.md) §一 |
| 排期、批次、阶段与目标版本 | [`deliverables/01-plan/SDP-软件开发计划.md`](deliverables/01-plan/SDP-软件开发计划.md) §四 |
| 基线与配置项 | [`deliverables/01-plan/SCMP-软件配置管理计划.md`](deliverables/01-plan/SCMP-软件配置管理计划.md) §三 |

目录级约定与红线见 [`AGENTS.md`](AGENTS.md)。

## 二、设计规格（`specs/`）

入口：[specs/00-index.md](specs/00-index.md)。十份主题文档，按**变更耦合度**拆分（不是按讨论顺序）：

| 文档 | 主体 | 明确不管 |
|---|---|---|
| [FND](specs/FND-foundation.md) | KST 三元组 · 六轴三层 · 六要件三态 · `⪯` · 坐标与容器之辨 | 视距与通道（VIEW）· 包格式（PACK） |
| [VIEW](specs/VIEW-views.md) | Z0–Z4 · 六通道两叠加 · 三视图投影 · HUD 七区块 · 树四类行 · 快速定位 | 掌握度公式（QUANT） |
| [PACK](specs/PACK-content-pack.md) | 边界三判据 · 一空间一包 · pack schema · 稳定 id · 版本迁移 | 事件字段定义（[entity-fields](specs/entity-fields.md)） |
| [PLAN](specs/PLAN-planning.md) | 源 / 体系 / 方法三段 · 三处出处 · 逆序数 · `Plan` 实体 · 实时预览 | 方法与判据的执行（STEP） |
| [STEP](specs/STEP-learning-steps.md) | 七步行为 · Runner 三入队源 · 会话边界 · 步骤游标 · 六类执行算子 | SRS 参数与公式（QUANT） |
| [QUANT](specs/QUANT-quantification.md) | 掌握度两维 · 进度离散 · 三层单调状态 · FSRS 参数 | 视觉表达（VIEW） |
| [NOTE](specs/NOTE-notes.md) | `Note` 实体 · 三层内容 · 两套切换 · 单向导出 · 按节版本 | 笔记模板的具体排版（平台声明） |
| [GOV](specs/GOV-governance.md) | 提交四裁定 · overlay 双平面 · 跨设备 HLC 合并 · 孤儿项 | 包格式（PACK） |
| [ACC](specs/ACC-accounts.md) | 账号为使用前提 · 账号/登录方式分层 · 三渠道三批 · 会话双令牌 · `userId` 接缝 | 事件搬运（SYNC）· 治理裁定权（GOV） |
| [SYNC](specs/SYNC-sync.md) | 只搬不判 · 双向游标 · 三端点三表 · 包版本三态 · 触发时机 | 事件类型（[event-types](specs/event-types.md)）· 合并语义（GOV） |

同目录另有 **8 份横切表/规格**（见 §三）与 **2 份工程规范** —— 它们不是产品规格，但同属「应当如何」：

| 文件 | 管什么 |
|---|---|
| [git-conventions.md](specs/git-conventions.md) | **Git 流程与格式的权威处**：仓库结构 · 分支 · 提交 · 评审与合并 · 版本与 tag · 交付物版号 |
| [dependency-licenses.md](specs/dependency-licenses.md) | 依赖许可核查判据：强传染（GPL / AGPL）禁止引入，许可清单与取证方式 |

## 三、横切表与规格（`specs/`）

被多份文档引用，**只在一处维护**。六张**横切表**（数值 · 事实 · 规则）+ 两份**规格**：

| 文件 | 内容 | 类型 |
|---|---|---|
| [channel-table.md](specs/channel-table.md) | 视觉通道 ↔ 语义维度映射（含唯一豁免） | 表 |
| [constants.md](specs/constants.md) | 全部数值常量（`S₀`、配额、系数、`carry`…） | 表 |
| [event-types.md](specs/event-types.md) | 事件类型全集与字段 | 表 |
| [entity-fields.md](specs/entity-fields.md) | 实体字段表 | 表 |
| [glossary.md](specs/glossary.md) | 术语表（含八对易混辨析） | 表 |
| [path-rules.md](specs/path-rules.md) | `path` 的 **16 条规则** + 与三元校验器的对应 | 规则表 |
| [minimal-pack.md](specs/minimal-pack.md) | **M1 最小示例包** —— `B13a` 笔 2–6 的验收样本 + 6 个错误码 | 规格 |
| [skeleton-catalog.md](specs/skeleton-catalog.md) | **骨架数据规格** —— 三轴取哪份目录、槽位映射、编号定位、体积预算（`B13b` 的输入） | 规格 |

另外四份**不在本目录**，按内容轴各归其位：

| 文件 | 位置 | 为什么在那里 |
|---|---|---|
| [not-list.md](decisions/not-list.md) | `decisions/` | 记「已裁不做」，是**裁定结果**，不是规格 |
| [open-decisions.md](decisions/open-decisions.md) | `decisions/` | 记「未裁待定」，是**决策轴的另一端** |
| [knowledge-system-learning-methodology.md](intent/knowledge-system-learning-methodology.md) | `intent/` | 上游理论依据，见 §四 |
| [knowledge-space-navigation-methodology.md](intent/knowledge-space-navigation-methodology.md) | `intent/` | 同上 |

**`not-list` 与 `open-decisions` 是同一根轴的两端**：一个记「已裁不做」，一个记「未裁待定」。**裁定后条目从台账迁出**（进 ADR / 规格 / `not-list`），台账删行不留尸。两者都不得互相抄写内容。

## 四、上游论证（`intent/`）

| 文件 | 是什么 |
|---|---|
| [knowledge-system-learning-methodology.md](intent/knowledge-system-learning-methodology.md) | **知识体系学习方法论** —— KST 三元组、定位算子全景（五族 17 个）、习得七步的理论推导。本项目的设计规格是其软件化落地；**方法论讲「人怎么学」，规格讲「软件怎么设计」**，两者不同层，冲突时以方法论的理论结论为准、以规格的实现取舍为落地 |
| [knowledge-space-navigation-methodology.md](intent/knowledge-space-navigation-methodology.md) | **知识空间导航方法论** —— 为什么三轴、为什么七级、锚点质量（`ADR-0005` 的论证依据） |

**为什么单独一层而不并入 `specs/`**：它是 `specs/` 的**上游** —— `specs/` 全部引用它，而它不引用 `specs/`；且改动频率远低于 `specs/`。并入会让「设计基线」的变更纪律与「理论论证」的演进节奏混在一起。

**结论以 ADR 为准**：方法论可继续演进，落地的取舍以 [`ADR-0005`](decisions/0005-three-axis-tree-replaces-six-axis.md) / [`0006`](decisions/0006-3d-rendering-stack-and-visual-style.md) / [`0007`](decisions/0007-node-type-shape.md) 为准。

## 五、写作纪律

- **结论先行**，表格优先于长段落。
- **引用不复制**：同一规则只在「唯一权威处」展开，其余位置写「见 XX」。
- **每条裁定可回溯**：规格条目带 `src:` 字段指向讨论来源与依据。
- **验收必须可观测**：每份规格末附验收表（裁定号 / 可观测断言 / 测试向量 / 预期）。写不出可观测断言的条目，说明该条本就没想清楚 —— 按「验证不得自证」处理，不得以「实现里写了」充当验收。
- **时态要清**：讲「已经这么定了」进 `decisions/`，讲「应当如何」进 `specs/`，讲「还没认定的候选」进 `ideas/`。混在一处会让读者分不清哪条能作为开工依据。

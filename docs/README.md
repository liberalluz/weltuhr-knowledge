# 文档体系索引

> 本文件是**文档导航**，不写项目介绍（项目介绍见仓根 [README.md](../README.md)）。
> 单一事实源：参数只在 `reference/` 维护一处，其余文档**引用不复制**。

## 一、目录分工

| 目录 | 内容 | 版号 |
|---|---|---|
| [design/](design/00-index.md) | **设计规格** —— 产品与系统的「是什么」 | 活文档，不设版号 |
| [reference/](reference/channel-table.md) | **参考层** —— 横切六表（通道 / 常量 / 事件类型 / 实体字段 / 术语 / NOT 清单）+ 上游方法论长文 | 活文档，不设版号 |
| [deliverables/](deliverables/README.md) | **交付物** —— 按 GB/T 8567 组织的**六段 25 种**（计划 / 需求 / 设计 / 测试 / 交付 / 总结） | `vX.Y.Z` 独立递增 |
| [guides/](guides/) | **操作指南** —— 怎么做（环境、Git、依赖许可…） | 活文档，不设版号 |
| [adr/](adr/) | **架构决策记录** —— 为什么这么选，含被否方案与代价 | 活文档，不设版号 |
| [readme/](readme/README.zh.md) | **README 译本** —— 仓根 [README.md](../README.md)（英文）的中 / 德 / 意 / 日 / 法五份译本，中文为**唯一权威原文** | 活文档，不设版号 |

**判据**：讲「是什么 / 为什么」→ `design/` 或 `adr/`；讲「多少次 / 哪些值」→ `reference/`；讲「怎么操作」→ `guides/`；要对外交付、需签字 → `deliverables/`。

> `readme/` **不参与上述判据**：它不是一类文档，而是仓根 README 的语言副本 —— 只放译本，不承载新内容。译本规则（文件命名、切换条顺序、溯源行、不译清单）的唯一权威处是 [`AGENTS.md`](AGENTS.md) §译本规范。

三个**唯一权威处**（别处只引用不复制）：

| 内容 | 唯一权威处 |
|---|---|
| 交付物清单与命名（六段 25 种） | [`deliverables/README.md`](deliverables/README.md) §一 |
| 排期、批次、阶段与目标版本 | [`deliverables/01-plan/SDP-软件开发计划.md`](deliverables/01-plan/SDP-软件开发计划.md) §四 |
| 基线与配置项 | [`deliverables/01-plan/SCMP-软件配置管理计划.md`](deliverables/01-plan/SCMP-软件配置管理计划.md) §三 |

目录级约定与红线见 [`AGENTS.md`](AGENTS.md)。

## 二、设计规格（`design/`）

入口：[design/00-index.md](design/00-index.md)。八份主题文档，按**变更耦合度**拆分（不是按讨论顺序）：

| 文档 | 主体 | 明确不管 |
|---|---|---|
| [FND](design/FND-foundation.md) | KST 三元组 · 六轴三层 · 六要件三态 · `⪯` · 坐标与容器之辨 | 视距与通道（VIEW）· 包格式（PACK） |
| [VIEW](design/VIEW-views.md) | Z0–Z4 · 六通道两叠加 · 三视图投影 · HUD 七区块 · 树四类行 · 快速定位 | 掌握度公式（QUANT） |
| [PACK](design/PACK-content-pack.md) | 边界三判据 · 一空间一包 · pack schema · 稳定 id · 版本迁移 | 事件字段定义（reference） |
| [PLAN](design/PLAN-planning.md) | 源 / 体系 / 方法三段 · 三处出处 · 逆序数 · `Plan` 实体 · 实时预览 | 方法与判据的执行（STEP） |
| [STEP](design/STEP-learning-steps.md) | 七步行为 · Runner 三入队源 · 会话边界 · 步骤游标 · 六类执行算子 | SRS 参数与公式（QUANT） |
| [QUANT](design/QUANT-quantification.md) | 掌握度两维 · 进度离散 · 三层单调状态 · FSRS 参数 | 视觉表达（VIEW） |
| [NOTE](design/NOTE-notes.md) | `Note` 实体 · 三层内容 · 两套切换 · 单向导出 · 按节版本 | 笔记模板的具体排版（平台声明） |
| [GOV](design/GOV-governance.md) | 提交四裁定 · overlay 双平面 · 跨设备 HLC 合并 · 孤儿项 | 包格式（PACK） |

## 三、参考层（`reference/`）

被多份文档引用，**只在一处维护**。前六份是**横切表**（数值与事实），第七份是**上游理论长文**：

| 文件 | 内容 | 类型 |
|---|---|---|
| [channel-table.md](reference/channel-table.md) | 视觉通道 ↔ 语义维度映射（含唯一豁免） | 表 |
| [constants.md](reference/constants.md) | 全部数值常量（`S₀`、配额、系数、`carry`…） | 表 |
| [event-types.md](reference/event-types.md) | 事件类型全集与字段 | 表 |
| [entity-fields.md](reference/entity-fields.md) | 实体字段表 | 表 |
| [glossary.md](reference/glossary.md) | 术语表（含八对易混辨析） | 表 |
| [not-list.md](reference/not-list.md) | **明确不做**的事 + 理由 | 表 |
| [knowledge-system-learning-methodology.md](reference/knowledge-system-learning-methodology.md) | **知识体系学习方法论** —— 全案的上游理论依据 | 长文 |

**为什么方法论放这里而不放 `design/`**：它是 `design/` 的**上游**（design 全部引用它，而它不引用 design），且改动频率远低于 design。放 `reference/` 意味着「被引用的权威源」；放 `design/` 会与「设计基线」的变更纪律混在一起。**仓根只留 `README.md` / `LICENSE` / `NOTICE`**，不放孤岛文档。

## 四、方法论依据

[reference/knowledge-system-learning-methodology.md](reference/knowledge-system-learning-methodology.md) —— KST 三元组、定位算子全景（五族 17 个）、习得七步的理论推导。本项目的设计规格是其软件化落地；**方法论讲「人怎么学」，规格讲「软件怎么设计」**，两者不同层，冲突时以方法论的理论结论为准、以规格的实现取舍为落地。

## 五、写作纪律

- **结论先行**，表格优先于长段落。
- **引用不复制**：同一规则只在「唯一权威处」展开，其余位置写「见 XX」。
- **每条裁定可回溯**：规格条目带 `src:` 字段指向讨论来源与依据。
- **验收必须可观测**：每份规格末附验收表（裁定号 / 可观测断言 / 测试向量 / 预期）。写不出可观测断言的条目，说明该条本就没想清楚 —— 按「验证不得自证」处理，不得以「实现里写了」充当验收。

# 文档体系索引

> 本文件是**文档导航**，不写项目介绍（项目介绍见仓根 [README.md](../README.md)）。
> 单一事实源：参数只在 `reference/` 维护一处，其余文档**引用不复制**。

## 一、目录分工

| 目录 | 内容 | 版号 |
|---|---|---|
| [design/](design/00-index.md) | **设计规格** —— 产品与系统的「是什么」 | 活文档，不设版号 |
| [reference/](reference/channel-table.md) | **横切表** —— 通道 / 常量 / 事件类型 / 实体字段 / 术语 / NOT 清单 | 活文档，不设版号 |
| [deliverables/](deliverables/) | **交付物** —— 按 GB/T 8567 组织的计划、需求、设计、测试、验收文档 | `vX.Y.Z` 独立递增 |
| [guides/](guides/) | **操作指南** —— 怎么做（环境、Git、依赖许可…） | 活文档，不设版号 |
| [adr/](adr/) | **架构决策记录** —— 为什么这么选，含被否方案与代价 | 活文档，不设版号 |

**判据**：讲「是什么 / 为什么」→ `design/` 或 `adr/`；讲「多少次 / 哪些值」→ `reference/`；讲「怎么操作」→ `guides/`；要对外交付、需签字 → `deliverables/`。

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

## 三、横切表（`reference/`）

被多份文档引用，**只在一处维护数值**：

| 表 | 内容 |
|---|---|
| [channel-table.md](reference/channel-table.md) | 视觉通道 ↔ 语义维度映射（含唯一豁免） |
| [constants.md](reference/constants.md) | 全部数值常量（`S₀`、配额、系数、`carry`…） |
| [event-types.md](reference/event-types.md) | 事件类型全集与字段 |
| [entity-fields.md](reference/entity-fields.md) | 实体字段表 |
| [glossary.md](reference/glossary.md) | 术语表（含七个易混辨析） |
| [not-list.md](reference/not-list.md) | **明确不做**的事 + 理由 |

## 四、方法论依据

仓根 [knowledge-system-learning-methodology.md](../knowledge-system-learning-methodology.md) —— 知识体系学习方法论：KST 三元组、定位算子全景（五族 17 个）、习得七步的理论推导。本项目的设计规格是其软件化落地；**方法论讲「人怎么学」，规格讲「软件怎么设计」**，两者不同层，冲突时以方法论的理论结论为准、以规格的实现取舍为落地。

## 五、写作纪律

- **结论先行**，表格优先于长段落。
- **引用不复制**：同一规则只在「唯一权威处」展开，其余位置写「见 XX」。
- **每条裁定可回溯**：规格条目带 `src:` 字段指向讨论来源与依据。
- **验收必须可观测**：每份规格末附验收表（裁定号 / 可观测断言 / 测试向量 / 预期）。写不出可观测断言的条目，说明该条本就没想清楚 —— 按「验证不得自证」处理，不得以「实现里写了」充当验收。

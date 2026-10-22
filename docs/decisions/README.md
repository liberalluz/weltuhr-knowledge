# ADR 索引

> 架构决策记录：记「为什么这么选」，含被否方案与代价。**不记「是什么」**（那是 `../specs/` 的活）。
> 活文档，不设版号。新增 ADR 编号连续，不复用、不删号（废弃用「已取代」状态标注）。

| 编号 | 标题 | 状态 | 关联 |
|---|---|---|---|
| [0001](0001-project-baseline.md) | 项目基线：架构形态与开源协议 | 已接受 | 全部 |
| [0002](0002-dev-order-vertical-slice.md) | 开发顺序：纵切优先与风险前置 | 已接受 | 全部 |
| [0003](0003-view-radial-axis-and-channel-thresholds.md) | 宇宙视图的径向语义与三处通道判据 | 已接受 | `VIEW-002` / `VIEW-003` / `VIEW-007` · `channel-table` · `entity-fields` · `C-34` |
| [0004](0004-accounts-as-usage-prerequisite.md) | 账号作为使用前提 | 已接受（**覆盖 `0002` 的「服务端不在关键路径」**） | `ACC` · `SYNC` · `SDP` §4 · `X-09` · `C-45`–`C-51` |
| [0005](0005-three-axis-tree-replaces-six-axis.md) | 三轴容器树取代六轴坐标 | 已接受（**覆盖 `FND-002` / `FND-006` / `FND-007`**，并收窄 `0004`） | `entity-fields` · `FND` · `PACK` · `PLAN` · `STEP` · `VIEW` · `ACC` · `SDP` |
| [0006](0006-3d-rendering-stack-and-visual-style.md) | 3D 渲染栈与视觉风格 | 已接受（`0005` 未决项之一；**附 spike 闸门**） | `VIEW` · `entity-fields` · `skeleton-catalog` · `SDP` §4.2 `B17b` / §4.5 · `app/pubspec.yaml` · `infra/` |
| [0007](0007-node-type-shape.md) | `Node` 的类型形态：按槽位分型 | 已接受 | `entity-fields` §1.2 · `SDP` §4.2 `B13a` · `core/entities/` · 647 用例的构造点 |

## 何时需要 ADR

满足任一条即需：

- 改**地基判据**（六轴 / `⪯` / 六要件 / 事件模型 / 视觉通道表）
- 引入**新的架构层**（新实体、新存储、新同步机制）
- **推翻既有决策**（尤其推翻 `not-list.md` 中的条目）
- 选择**有长期代价**的方案（如引入 codegen 全家桶、引入第二套时钟）

## 不必写 ADR 的情形

- 只改常量数值（B 级变更，PR 说明即可）
- 只改措辞、补例子（C 级）
- 界面排布细节（TBD 级）

## 模板

```markdown
# ADR-NNNN · 标题

- 状态：提议 / 已接受 / 已取代 / 已废弃
- 日期：
- 决策人：

## 背景
## 决策
## 被否方案（各附理由）
## 影响
## 后续
```

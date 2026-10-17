# Weltuhr 设计规格 · 索引

> **本目录是什么**：产品与系统的**设计基线**，回答「是什么」。理论依据在 [`../reference/knowledge-system-learning-methodology.md`](../reference/knowledge-system-learning-methodology.md)（回答「人怎么学」）。
> **本文件是导航与裁决规则，不承载具体设计内容。**

## 一、怎么读

- **第 0 步永远是 [FND](FND-foundation.md)** —— 其余九份都引用其中的术语与判据。
- 每份开头都有「前置阅读」与「明确不管」两行。**「明确不管」是防重复的手段，不是可选项** —— 它指定了该内容归谁管。
- 数值一律不写在正文里，只写表项 id（如「见 `C-01`」），去 [`../reference/constants.md`](../reference/constants.md) 查。

## 二、十份主题文档

| 文档 | 主体 | 条数 | 前置阅读 | 明确不管（归谁） |
|---|---|---|---|---|
| [FND](FND-foundation.md) | KST 三元组 · 六轴 + 三层 · 六要件三态 · `⪯` · 坐标与容器之辨 · 事件折叠底座 | 16 | — | 视距与通道（VIEW）· 包格式（PACK） |
| [VIEW](VIEW-views.md) | Z0–Z4 · 六通道两叠加 · 三视图投影 · HUD 七区块（不含事件计数）· 树四类行 · 详情六入口两壳 · 快速定位 | 35 | FND | 掌握度公式（QUANT）· 笔记内容（NOTE） |
| [PACK](PACK-content-pack.md) | 边界三判据 · 一空间一包 · pack schema · 稳定 `Item.id` · overlay 双平面 · 版本迁移 | 18 | FND | 事件字段（reference/event-types）· 审核裁定（GOV） |
| [PLAN](PLAN-planning.md) | 源=材料 · 体系=顺序 · 方法=动作+判据 · 三段自建 · 逆序数 · `Plan` 实体 · 实时预览 · 候选排序 | 21 | FND · PACK | 方法与判据的执行（STEP） |
| [STEP](STEP-learning-steps.md) | 七步行为 · Runner 三入队源 · 会话边界 · 步骤游标 · 六类执行算子 · 检验两出口 · 保持 · 毕业 | 34 | FND · PLAN | SRS 参数与公式（QUANT） |
| [QUANT](QUANT-quantification.md) | 掌握度两维 · 进度离散 · 三层单调状态 · `verified/checked` · FSRS 参数落位 | 15 | FND · STEP | 视觉表达（VIEW）· 常量数值（reference/constants） |
| [NOTE](NOTE-notes.md) | `Note` 实体 · 三层内容 · 两套切换 · 单向导出三戳 · 按节版本 · 与判定的隔离 | 19 | FND · PACK · STEP | 模板排版（平台声明）· 笔记内容正确性（内容作者） |
| [GOV](GOV-governance.md) | 提交四裁定 · 最小三字段 · 即入 overlay · 跨设备 HLC 合并 · 孤儿项 · 降级五档 | 14 | FND · PACK | 包格式（PACK） |
| [ACC](ACC-accounts.md) | 账号为使用前提 · 账号/登录方式分层 · 三渠道 · 注册五步 · 会话双令牌 · `userId` 接缝 | 15 | FND · event-types | 事件搬运（SYNC）· 包格式（PACK）· 治理裁定权（GOV） |
| [SYNC](SYNC-sync.md) | 只搬不判 · 双向游标 · 三端点 · 三张表 · 包版本三态 · 触发时机 · 可中断增量 | 16 | FND · GOV · ACC · event-types | 事件类型（event-types）· 合并语义（GOV）· 账号与会话（ACC） |

合计 **203 条编号条目**（十份文档各自 `1..N` 连续编号，无跨文档重号）。

## 三、参考层（`../reference/`）

被多份文档引用，**只在 `../reference/` 维护**。六张横切表：

| 表 | 内容 | 主要引用方 |
|---|---|---|
| [channel-table](../reference/channel-table.md) | 视觉通道 ↔ 语义维度（含唯一豁免） | VIEW · QUANT |
| [constants](../reference/constants.md) | 全部数值常量 | 全部 |
| [event-types](../reference/event-types.md) | 事件类型全集 | PACK · STEP · NOTE · GOV |
| [entity-fields](../reference/entity-fields.md) | 实体字段表 | 全部 |
| [glossary](../reference/glossary.md) | 术语与八对辨析 | 全部 |
| [not-list](../reference/not-list.md) | 明确不做 + 理由 | 全部（实施者必读） |

> 另有**上游理论长文** [`../reference/knowledge-system-learning-methodology.md`](../reference/knowledge-system-learning-methodology.md) —— 全案的理论依据。它是 `design/` 的**上游**（design 全部引用它，它不引用 design），改动频率远低于 design，故归入参考层而非设计基线。

## 四、跨文档约束清单

以下判据**同时约束多份文档**，拆开后单看任何一份都看不见它的全貌。此为索引存在的第二个理由。

| 约束 | 内容 | 管着哪几份 |
|---|---|---|
| **X-01 未声明即不渲染** | 模型未声明的通道 / 字段 / 分区，界面不得画出来；缺失表现为空位或不画，不补默认值 | FND · VIEW · NOTE |
| **X-02 一通道一维度** | 每个视觉通道只承载一个语义维度；唯一豁免是轨道环（掌握填充 + 毕业线型） | VIEW · QUANT |
| **X-03 不同构就不映射** | 宇宙坐标与树缩进不同构 ⇒ 只做交叉淡入；`φ` 不得当难度代理；难度不得进 Planner 预览 | VIEW · QUANT |
| **X-04 事件是唯一事实源** | 所有可写状态由 `fold(events, asOf)` 得出；不得有并行的可写状态表 | PACK · STEP · NOTE · GOV |
| **X-05 验证不得自证** | 验收须给可观测断言与测试向量；不以「代码里写了」充当验收 | 全部（每份末验收表） |
| **X-06 声明驱动零分支** | 空间 / 语言 / 方法差异由内容包与平台声明承载，代码不得按具体空间分支 | PACK · PLAN · STEP |
| **X-07 已学不可撤销** | `item_passed` 是 append-only 事件；只有包版本迁移可改变其指向 | QUANT · PACK · GOV |
| **X-08 顺序与范围分离** | 体系（顺序）定义在空间级；`target`（范围）随视距。不得给域单独配体系 | FND · PLAN · NOTE |
| **X-09 同步只搬不判** | 同步层只搬运事件与校验包版本，**不去重、不做冲突解决、不计算状态**；合并一律由客户端 `fold` 完成。违反它不会有任何测试变红 —— 故须显式成条 | SYNC · GOV · PACK |

## 五、编号规则

格式 **`SPEC-<域>-<NNN>`**，每份从 001 起。每条附 `src:` 字段记来源（讨论轮次或依据文档），用于回溯。

**为什么重编**：讨论期的临时编号有真实撞车 —— `Z1–Z4` 同时指「视距档位」与「跨设备合并批次」，`S1–S4` 与 FSRS 的 `S` 撞，`M1–M4` 与里程碑撞。规格里写「Z3 触发」时无法判断指哪个。**这不是洁癖，是可读性的必要条件。**

## 六、开放问题（TBD）

不影响结构，可在实现期定：

| # | 问题 | 归属 |
|---|---|---|
| TBD-1 | `sectionKey` 的命名规则 | NOTE |
| TBD-2 | 窄壳抽屉里四个分区（事实 / 缺口 / 信息 / 笔记）的折叠策略 | VIEW · NOTE |
| TBD-3 | 导出目标笔记软件清单（Obsidian / Notion / 语雀 / 飞书…） | NOTE |
| TBD-4 | 导出的打包形态（目录树 / 单文件 / zip） | NOTE |
| TBD-5 | 空间级自由笔记的排序与归档位置 | NOTE |
| TBD-6 | 能力清单的排序键（按空间 / 掌握度 / 毕业时间）与「适用场景」来源 | QUANT |
| TBD-9 | 搜索模糊匹配阈值（`C-28`），须实测标定 | VIEW |
| TBD-10 | 候选卡的元素排布细节（三段一致的三段卡片） | PLAN |
| TBD-11 | 总览链的具体形态（分段来自 `methodProfile`，但视觉待定） | QUANT |
| TBD-12 | 事件累计量（复习次数 / 累计时长 / 学习天数）是否进首屏，以及多设备重合时的呈现口径 | VIEW |
| TBD-13 | 多设备同步完成的提示文案（须报重合项数，不只说「已合并 N 条」） | VIEW |
| TBD-14 | 邮件服务商选型（自建 SMTP / Resend / Postmark / SES）；私有化交付常要求走客户自己的 SMTP，会影响端点抽象 | ACC |
| TBD-15 | 短信服务商与模板报备；国际号码的区号选择器形态 | ACC |
| TBD-16 | Windows 上的 Apple 登录回调方式（loopback 监听 / 自定义 URL scheme） | ACC |
| TBD-17 | 条款与隐私政策勾选的时点（注册时 / 首次启动） | ACC |
| TBD-18 | 账号删除的具体形态与冷却期（`v1.0.0` 上架硬性要求） | ACC |

> **已裁定（2026-10-17）**：TBD-7 → `C-25` = **0.5**（[QUANT-008](QUANT-quantification.md)）· TBD-8 → `C-03` = **0.90**。编号保留不复用、不重排，以免既有引用失效。

> **TBD-12 / TBD-13 为什么现在挂而不现在定**：跨设备同步尚未开工（`GOV-011` 只裁了「不去重、都重放」，没裁呈现）。而当前 [VIEW-018](VIEW-views.md) 的 HUD 七区块与 [QUANT-011](QUANT-quantification.md) 的两个分区**本来就不含任何事件计数**，所以这两条在 `v0.1.0` 无实现压力。挂 TBD 的目的是：将来真要加统计卡片时，**先定口径再加**，而不是先加一个会随设备数翻倍的裸数字。详见 [VIEW](VIEW-views.md) 的 `VIEW-035`（`VIEW-018` 末尾有指针）。

> **TBD-14–TBD-18 为什么不阻塞**：前四条是外部服务商与平台回调方式，[`ACC-006`](ACC-accounts.md) 已按批次把它们各自隔离在一个版本里，选型晚定只影响该批开工，不影响条目结构；`TBD-18` 属 `v1.0.0` 上架要求，届时随审核材料一并定。**五条都不阻塞 `v0.1.0`。**

> TBD 与「未提出的需求」不同：TBD 是**已知要定、暂不必定**；未提出的需求（如推荐引擎一键生成、跨空间统一队列）已在 [NOT 清单](../reference/not-list.md) 中明确排除或挂待办。

## 七、变更纪律

| 变更级别 | 判据 | 动作 |
|---|---|---|
| **C 级** | 只改措辞、补例子 | 直接改，PR 里说明 |
| **B 级** | 改常量数值、改字段可空性、新增事件类型 | PR + 变更说明 + 回填横切表 |
| **A 级** | 改地基判据（六轴、`⪯`、事件模型、通道表） | 先出 ADR，评审通过后改规格 |
| **D 级** | 与 NOT 清单冲突 | **不做**；除非推翻 NOT 条目并留痕 |

规格是活文档，**不设版号**；交付物（`../deliverables/`）才独立递增 `vX.Y.Z`。

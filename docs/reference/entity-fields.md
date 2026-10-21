# 实体字段表

> **唯一权威处**：实体与字段只在本文件定义。字段的**值域**若在别处（事件 payload、常量），以对应表为准。
> 标记「派生」的实体/字段**不入库**，由 `fold(events, asOf)` 或纯函数算出。
>
> **2026-10-20 按 [`ADR-0005`](../adr/0005-three-axis-tree-replaces-six-axis.md) 重写**：三轴容器树取代六轴坐标。
> 旧字段 `sixAxis` / `primaryAxis` / `domainId` / `inScope` / `depth` / `spaceId` / `selector` 已移除；原委与 supersede 清单见该 ADR，回溯靠 git 历史。字段名对照见文末附录。
>
> ⚠️ **节号已重排（13 → 18 节）**：全仓仍按旧节号引用 `§5` / `§7.1` / `§8` 等处的 12 个位置清单见该 ADR 的「影响 · 三」，**尚未同步**（其中 4 处内容已失效，非仅编号错位）。

## 〇、存储三区

| 区 | 内容 | 可写 | 走事件 |
|---|---|---|---|
| **只读分发区** | 骨架 / 载荷 / 地形 / 方法 / 覆盖包正文 | 否 | 否 |
| **可写内容区** | S4 自建节点 · 个人 `OverlayPatch` · `PathClaim` 墓碑 | 是 | 否 |
| **事件日志区** | 学 / 评 / 复习 / 访问 | 仅 append | — |

判据是**「事实的累积还是事实的投影」**，不是「谁产生的」：用户自建节点属内容（要进地址空间、被虫洞指向），只有时间序列才走事件。`X-04`「事件是唯一事实源」据此收窄为「**学习状态**以事件为唯一事实源」。

---

## 一、内容侧（来自包）

### 1. `Pack` —— 插件包（取代 `KnowledgeSpace`）

一个插件可含多个包（分发单元 ≠ 逻辑单元）。`skeleton` 全量内置、不走插件、不进审核 ⇒ 本表只覆盖四类。

| 字段 | 类型 | 说明 |
|---|---|---|
| `plugin_id` | string | **永久唯一、不可复用**。`^[a-z][a-z0-9-]*$` |
| `name` | string | 展示名 |
| `version` | semver | semver，参与 `deps` 区间匹配 |
| `kinds[]` | enum[] | `payload` / `overlay` / `terrain` / `method` |
| `namespace` | string | 节点 id 前缀，实际 id = `{plugin_id}:{local_id}` |
| `schema_version` | int | 插件格式版本（**不是**包版本，两者独立演进） |
| `skeleton_requires` | string | 骨架版本区间。载荷节点挂骨架父节点，骨架升版会让 `attach_to` 失配 |
| `deps[]` | object[] | `{plugin_id, range}`。跨包父子（A 出 L5、B 补 L6）必须在此声明 |
| `license` | string | SPDX 标识 |
| `author` / `origin` | string | — |
| `review_state` | enum | `pending` / `approved` / `rejected`（可重提）/ `revoked`（仅恶意违法强制停分发，**不远程删除**） |
| `signature` | string? | 侧载与私有包可空 |
| `axes[]` | enum[] | 涉及哪几条轴（全类必填） |

**按 `kinds[]` 追加的特化字段**：

| kind | 字段 | 说明 |
|---|---|---|
| `payload` | `attach_to` | **节点 id**（非 path）。骨架已有该恒星时填其 id；编外节点填 `@extra/root` |
| | `subtree_root` | `star` / `system` —— 本包提供的最上层槽位 |
| | `level_range` | 实际覆盖的槽位区间 |
| | `counts` | `{star, system, planet}` —— **必须分级**：`Item` = 行星层，七步能否跑取决于 planet 数 |
| | `official_code_coverage` | 有无官方码，用于「自设方向·无国标码」标注 |
| | `path_reservations[]` | `(parent_id, slug)` 清单。**装前判冲突的唯一依据**（侧载无审核） |
| | `sources[]` · `schemes[]` | 摘要，见 §11 / §12 注 |
| | `has_steps` / `has_criteria` / `has_quiz` | 能否跑 ④ ⑤ |
| | `quiz_types[]` | 供装前显示「支持哪些题型」 |
| | `est_minutes_coverage` | 有时长的项占比 |
| `terrain` | `edge_counts` | `{required, recommended}` |
| | `axes_covered[]` | 地形边跨了哪几条轴 |
| `overlay` | `target_scope` | `S1`–`S4` |
| | `patch_count` | 补丁条数 |
| `method` | `methods[]` | `{id, name, item_types[], step_count, has_review_step, phase_distribution}`。`has_review_step` 是 `STEP-027` 的**装前可见项** |

**禁止字段**（schema 层机器校验）：`price` · `currency` · `purchase` · `subscription`。市场是**开放注册中心**，不是商店。

### 2. `Node` —— 树节点（取代 `Item`）

节点身份与地址分离：`id` 稳定，`path` 是当前位置。

> **类型形态不在此定义** —— `sealed` 按槽位两分（结构节点 / 可学节点）、派生字段不入类型、`(axis, level_slot)` 的 12 个合法对，见 [`ADR-0007`](../adr/0007-node-type-shape.md)。本表只定字段集。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | `{plugin_id}:{local_id}`；骨架节点 `skeleton:{local_id}`。**不带版本号**，否则升级后所有已学事件指向旧 id。`local_id` 永久、不可复用（软删 + 墓碑） |
| `axis` | enum | `discipline` 学科 / `major` 专业 / `occupation` 角色 |
| `level_slot` | enum | **语义槽位，不是深度序号**。取值见下表 |
| `official_code` | string? | **可空**。学科轴 676 个二级/方向属「自设方向·无国标码」 |
| `name` | string | 展示名 |
| `slug` | string | path 段。`^[a-z0-9-]+$`；`_` 开头为保留段（如 `_extra`） |
| `scope` | enum | `S0` 官方 / `S1` 平台 / `S2` 机构 / `S3` 团队 / `S4` 个人 |
| `pack_id` | string | 来源包；骨架为 `skeleton` |
| `status` | enum | `live` / `tombstone` / `revoked` |
| `tags[]` | string[] | **骨架事实标签**（如 `digital` 数字职业 97 个 / `green` 绿色职业 133 个）。与内容侧 `keywords` 不是一回事 |
| `catalog_refs[]` | string[] | 引用 `SourceRef.id`（`kind = catalog`）。**多值**：同一节点可同时受两份目录覆盖 |
| `type` | enum? | **仅可学项**：`declarative` / `procedural` / `skill` / `tacit` |
| `layer` | enum? | **仅可学项**：`persistent` / `view` / `ephemeral` |
| `requirements` | object? | **仅可学项**：六要件 × 三态，取值见下 |
| `path` | string | **派生** = 父链 `slug` 串联。同子树内段数 = 该子树层数；官方与编外可不同。**16 条规则见 [`path-rules.md`](path-rules.md)**，本表不复述 |
| `inScope` | bool | **派生** = 是否在 `Plan.subtree_root` 子树下 |
| `depth` | int | **派生** = `level_slot` 在轴内的序号，**仅供展示**，不得用于判据 |

**`level_slot` 八个语义槽位**（三轴实际占用的槽位不同 —— 这就是禁止用绝对层号的原因）：

| 槽位 | 学科轴 | 专业轴 | 角色轴 |
|---|---|---|---|
| `supercluster` 超星系团 | 根 | 根 | 根 |
| `group` 星系群 | 门类 14 | 门类 12 | 大类 8 |
| `galaxy` 星系 | — | 类 93 | 中类 79 |
| `cluster` 星团 | — | — | 小类 449 |
| `star` **恒星** | 一级 117 + 学位类别 67 = 184 | 专业 845 | 细类 1,636 |
| `system` 行星系 | 载荷 | 载荷 | 载荷 |
| `planet` 行星 | 载荷 | 载荷 | 载荷 |

- **恒星槽位 = 官方目录最细的正式条目**，是骨架与载荷的分界线（**3,323** 节点内置；各轴取哪份目录、为何学科轴跳过 `galaxy`，见 [`skeleton-catalog.md`](skeleton-catalog.md)，本表只登记映射）
- **行星层 = `Item`（可学项）**。旧的 `Item` 概念不另设实体，就是行星层 `Node`
- 行星系与行星**均无官方码**，`slug` 是它们唯一的 path 段来源

**`requirements` 取值域**（JSON 用英文键，中文只是本表表述）：

| 字段 | 键 / 值 |
|---|---|
| `requirements` | `boundary` 边界 · `justification` 证成 · `proposition` 命题 · `relation` 关联 · `how` How · `tacit` Tacit |
| `requirements.*` | `present` 齐 · `missing` 缺 · `not_externalizable` 不可外化 |

三态含「缺」，`null` 不是合法取值。**`requirements` 是量化层 `d`（知识深度）的唯一来源**，`mastery = d × s` 依赖它 —— 不得因本次重写而废弃。

### 3. `ParentEdge` —— 父子边（主父唯一 + 附加归属）

| 字段 | 类型 | 说明 |
|---|---|---|
| `child_id` / `parent_id` | string | `Node.id` |
| `kind` | enum | `main` 主父（**每节点恰好一条**）· `secondary` 附加归属（0..N） |

> **主父不可覆盖**（`S0`–`S4` 任何一层都不得改）。树内必须无环，与地形 DAG 是两套独立校验。
> 载荷内 `parent_id` 只允许指向**同包节点**或 `attach_to`，**禁止跨包** —— 否则卸载 A 会拆掉 B 的树。跨包只用 `deps` 表达。

### 4. `WormholeEdge` —— 虫洞边（跨轴 / 跨枝跳转）

| 字段 | 类型 | 说明 |
|---|---|---|
| `from_id` / `to_id` | string | `Node.id`。**双向**：跳转后 A 仍是 B 的出口，反之亦然 |
| `kind` | enum | 单值，判定顺序 `same_name` > `many_to_many` > `granularity` |
| `note` | string? | 呈现用说明 |

| `kind` | 含义 | 例 |
|---|---|---|
| `same_name` | 同名异编 | `0812` 计算机科学与技术（学科一级）↔ `080901` 计算机科学与技术（本科专业） |
| `granularity` | 粒度错位 | 一个学科方向覆盖多个专业 |
| `many_to_many` | M:N 共享 | `050201` 英语被多专业共享 |

> **单值而非数组**：三形态本身会重叠（`0812 ↔ 080901` 既像同名异编又像粒度错位）。多值等于把「这条边画成什么样」的矛盾推给渲染层。
> **只影响呈现**（边样式与详情提示），所有虫洞共用同一套跳转机制 —— 跳转永远改地址，不改筛选。

### 5. `PrerequisiteEdge` —— 先修边（地形）

| 字段 | 类型 | 说明 |
|---|---|---|
| `from_id` / `to_id` | string | 前置 → 后继。**允许跨轴**（`Python → 框架调参` 同时涉及学科轴与角色轴） |
| `strength` | enum | `required` 必须补 / `recommended` 可以跳 |

> **`⪯` = `strength = required` 边的传递闭包**，全项目唯一偏序源。`recommended` 只影响排序建议与 UI 提示，**不构成可达性约束**。
> **两类边都必须过 DAG 校验** —— 地形图整体是学习顺序图，任何环都是数据错误。
> `V1` 不物化闭包，运行时 BFS；载荷到十万级再引索引。
> **重组边不在此表**：「数学 × 工程 → 深度学习」描述的是领域来源，不是学习顺序，降级为节点上的说明文本，不进图。

### 6. `PathClaim` —— path 占用

| 字段 | 类型 | 说明 |
|---|---|---|
| `path` | string | 完整 path |
| `node_id` | string | 占用者 |
| `state` | enum | `live` / `tombstone` |

> **只管插件节点**：骨架 path 由构建过程一次性保证唯一，运行时无需再维护一份账。
> **墓碑必须留在可写内容区**：卸载插件只删节点，不删 claim；否则「A 卸载 → B 装上 → A 再装回」时 A 会以为自己是首次占用。

### 7. `PathAlias` —— 路径重定向

| 字段 | 类型 | 说明 |
|---|---|---|
| `old_path` | string | — |
| `node_id` | string | 现役节点 |
| `reason` | enum | `parent_change`（骨架升版改主父）/ `slug_change`（改名） |
| `from_ver` / `to_ver` | string? | **仅 `parent_change` 必填**；`slug_change` 发生在骨架版本轴之外，允许为空 |

> 解析顺序：**`live` → `tombstone`（命中即报「此地址已停用」）→ `alias` 重定向**。反过来先查 alias，已复用的旧地址会盖掉现役节点。
> **禁止成链**：`A→B` 且 `B→C` 时，写入时把 `A` 直接改指 `C`。解析只需一跳，不可能成环。

### 8. `OverlayPatch` —— 覆盖补丁

| 字段 | 类型 | 说明 |
|---|---|---|
| `scope` | enum | `S0`–`S4`。优先级「最具体者胜出」（`S4 > S3 > S2 > S1 > S0`） |
| `target_id` | string | 被补丁节点 |
| `field` | string | 字段路径，须在 `NodeEntry` 的可 patch 集内（§9） |
| `value` | any | — |
| `base_hash` | string | 打补丁时目标值的指纹 |
| `state` | enum | `applied` / `stale`（指纹失配，**不自动应用**） |

**四条铁律**：
① `id` / `official_code` / 主父 / `level_slot` **绝对不可覆盖**（低层只能改表述、加内容、加边）
② 删除只在**视图层**（`visible = false`），不得物理删除
③ `M3` 派生字段默认禁改，需显式 `frozen` 声明
④ `profile` ≠ `scope`：`profile` 是**被激活的 scope 链**，不是一层

### 9. `NodeEntry` —— 载荷内容（键 = `node_id`）

与 `Node` 分离：`nodes[]` 进地址空间（改动要校验父子与 DAG），`entries[]` 只是文本（改动不影响结构）。混在一起无法单独升级。

> **`source_refs` 是 `B13a` 笔 4 补登的**（2026-10-21）：旧 `Item.sourceRefs` 迁移时在本体系里没有落点 —— `Node` 表没有它（源引用不影响结构，进 `nodes[]` 会让「改一条引用」也要过父子与 DAG 校验），本表也没有。落内容侧而非 `Node`：`resources` 回答「推荐去哪学」，`source_refs` 回答「我这句话引自哪份材料的哪一段」，前者是给学习者的建议，后者是可追溯的引用（能追到 `segments[].locator`）——受众与校验方式都不同，合成一个字段会让两者互相污染。

| 字段 | 形态 | 可字段级 patch |
|---|---|---|
| `summary` | 一句话 | ✅ |
| `outcomes[]` | 能做什么 | ✅ 按元素 |
| `resources[]` | `{kind, title, url, license, lang}`，kind ∈ 课程/书/视频/工具/规范 | ✅ 按元素 |
| `source_refs[]` | 引用 `SourceRef.id`（`kind = material`）。**本节点内容引自哪几份材料** | ✅ 按元素 |
| `aliases[]` | 别名（检索与虫洞对齐用） | ✅ |
| `keywords[]` | 自由文本，**与骨架 `tags` 不是一回事** | ✅ |
| `body` | Markdown 整块 | ❌ 整块替换（等价 fork） |
| `steps[]` | 见下 | ✅ 按元素 |
| `selfCheck[]` | 步内自检提示 | ✅ |
| `criteria` | 项末验收；**空 = 打卡式** | ✅ |
| `quiz[]` | 见下 | ✅ 按元素 |
| `estMinutes` | 项级预计时长 | ✅ |
| `methodId` | 指定配方，空 = 用默认 | ✅ |

#### 9.1 `steps[]` —— 执行步骤

| 字段 | 类型 | 说明 |
|---|---|---|
| `operator` | enum | **六类之一，不得自创**：`read` 读 · `example` 例 · `recall` 忆 · `practice` 练 · `explain` 讲 · `do` 做。与界面组件 **1:1**。⑤⑥ 标识符**已裁定保持** `explain` / `do`（`2026-10-20`，原 `OD-03`）—— `teach` / `build` 案被否：`build` 与 `content/tools/build.py`、`build/` 目录、CI 的 `build` 步骤**同词异义** |
| `phase` | enum | `first` / `review` / `both`。**默认由算子派生**：`read`·`example` → `first`；其余 → `both`。作者可覆盖 |
| `instruction` | string | 本步指令 |

> **不含 `estMinutes`**：时长由「步数 × 算子系数」派生（系数 `C-14`–`C-19`），项级覆盖已足够；步级再留一个字段会与系数表打架。
> **校验**：至少一个 `review`（含 `both`）步骤 —— 等价于「至少有一个 both 类算子」，防静默绕过遗忘曲线。
> **`selfCheck` 是步内自检（形成性），不写判定**；项末验收是唯一写入点，否则掌握度会被「每步记一次」污染。

#### 9.2 `criteria` —— 项末验收（终结性）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 段内唯一 |
| `statement` | string | 能力断言（「能解释 Transformer 的注意力机制」） |

> **不设 `judge_type`**（`2026-10-20` 裁定，原 `OD-02`）：`criteria` 与 `quiz` 是 1:1（`criterion_id`，见 §9.3），故「系统判还是自评」由 `quiz[].judge` **派生**即可。与 `progressKind` 不入库（同由 `judge` 派生）同构 —— 1:1 关系下留两个同义字段，等于给不一致留一条合法路径（错的状态可表达，就一定会有人表达出来）。
> 由此 `criteria` 只有 `id` 与 `statement` 两个字段，**它不承载任何判定信息**：判定全在 `quiz`。

> **空 `criteria` = 打卡式**：跳过 ⑤、直接记 `checked`、`S` 永不增长、**永不毕业**。它是学习痕迹，不通往出口。

#### 9.3 `quiz[]` —— 题库（`SPEC-PACK-006` 的第三次扩 schema）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 段内唯一 |
| `criterion_id` | string | 指向 `criteria.id`，**1:1**：每条 criteria 恰有一题 |
| `type` | enum | `choice` 选择 / `fill` 填空 / `code` 代码跑通 / `audio` 发音比对 / `freeform` 自由作答 |
| `prompt` | string | 题干 |
| `answer` | string | 参考答案 |
| `judge` | enum | `auto`（前四类题型）/ `self`（自评 + 可选留证） |

> **不设 `covers[]` 数组**：criteria 与 quiz 定为 1:1 后，单值 `criterion_id` 即可表达；需要多题就拆多条 criteria。
> **三档判定**：`达成`（全部 criteria 通过 / 部分 / 全未）× `独立性`（无脚手架 / 用过提示）。**无脚手架 + 全达成 = 熟练；有脚手架 + 达成 = 合格；未达成 = 未过**。
> **不设 `passLine` 阈值** —— 跨包可比的前提是不让作者改分数线。
> `progressKind`（`verified` / `checked`）**不入库**，由 `judge` 自动派生；`criteria` 也**不再设** `judge_type`，同由此处派生（§9.2 注）。
> 模型生成的题不入包：不可复现、不参与 SRS 判定（`SPEC-PACK-006`）。

### 10. `Scheme` —— 体系（路径模板，可跨轴）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | — |
| `name` | string | 如「官方 Tutorial 序」「学徒 → 中级 → 高级 → 技师」 |
| `nodes` | string[] | `Node.id` 的有序序列，**可跨轴** |
| `authority_level` | enum | 五档语义值（见 §11） |
| `inversions` | int | **派生**：违反 `required` 先修边的处数 |

**三条校验**（全部可机器判）：

1. `nodes[]` 相邻两项之间**必须存在** `ParentEdge` 或 `WormholeEdge` —— 否则那不是路线，只是一张清单
2. 不得违反 `required` 先修边：`A --required--> B` 时 B 不得排在 A 之前（`recommended` 不构成约束）
3. **不校验同轴**

> 旧定义「`nodes` 必须是 `⪯` 的线性扩展」随 `⪯` 并入地形 DAG 而失效，由上述三条替代。
> 跨轴体系不需要新机制：它本质就是**按顺序排好的一串虫洞跳转**。

### 11. `SourceRef` —— 源（材料）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | — |
| `name` | string | 展示名 |
| `kind` | enum | `catalog` 编目依据 / `material` 学习材料 |
| `authority_level` | enum | **仅 `material` 需要**；`catalog` 本身就是权威 |
| `version` | string | 源自身的版本 |
| `segments` | object[] | **仅 `material`**：`{text, locator(页码/锚), license}`，离线可读 |
| `appliesTo` | object | `{axes[], node_scope[]}` |

| `authority_level` | 含义 | 旧编号 |
|---|---|---|
| `official` | 官方规范本身（Python Tutorial、PEP） | `L0` |
| `standard` | 权威机构标准（CEFR、Cambridge、Duden） | `L1` |
| `textbook` | 教材 | `L2` |
| `reference` | 手册 / 百科 | `L3`（旧实现中从未定义、数据中零出现） |
| `community` | 社区、博客、个人 | `L4` |

> **废除 `L` 编号**：`L` 前缀在项目内已三处撞名（节点层级 / 源等级 / 出处等级）。语义值本身即排序键，`authorityRank` 只需换列表，未知档排最后的逻辑不变。
> **不设 `user` 档**：`scope = S4` 已表达「这是你自己定义的」，再给 `authority_level` 加一档会让「权威度」与「谁的定义」两个正交维度重叠。
> **`appliesTo` 两个键都不能省**：`axes` 让「整条轴适用」不必枚举根节点 id；`node_scope` 才是实际过滤依据（`node_scope ∩ 子树`）。旧的 `spaceId`（一空间一包已废）与 `sixAxis.stack`（六轴已废）**全部失效**。
> **`catalog` 不参与 ①② 候选**：它绑定 `Node.catalog_refs[]`，回答「这个 `0812` 依据哪份文件」。混进候选卡会让「教育部目录」与「Python Tutorial」并列，用户无从选择。

### 12. `MethodProfile` / `MethodBundle` —— 方法（配方）

**第五类包**（`Pack.kind = method`）。独立成包的理由：一份配方可服务多个载荷包（N:M），语言类配方不必跟着每个语言包各发一份。

| `MethodProfile` 字段 | 类型 | 说明 |
|---|---|---|
| `id` / `name` | string | — |
| `steps` | object[] | 与 §9.1 同一算子集（`operator` / `phase` / `instruction`） |
| `appliesTo` | object | **必填**：`{type, axes, layer}` —— 三键**均可省**，省 = 不限 |
| `origin` | enum | `platform` / `pack` / `user`，合并优先级 `user > pack > platform` |

| `MethodBundle` 字段 | 类型 | 说明 |
|---|---|---|
| `id` / `name` | string | — |
| `origin` | enum | 同上 |
| `byType` | `ItemType → MethodProfile.id` | 四个类型各指一份分支；**允许不齐**（缺分支 = 不覆盖该类型，确认段须拦住并说明） |

> `Plan.method_profile_id` 存 **bundle 的 id**，字段名与类型不变。
> **校验三条**：算子必须在册 · 至少一个 `review` 步骤 · 全步骤无 `hint` 时 Planner ③ 须提示「本方法无提示可给，熟练档不受约束」（不禁止，显式标代价）。
> **`V1` 只内置三套，不对外开放提交** —— 教学法设计门槛高，配方审核判据不在 `V1` 范围。
> **`appliesTo` 三个键的含义**（`B13a` 笔 5c-1 定；此前只写「`Item.type` / 轴 / 层」，键名一直没定）：`type` 对 `LearnableNode.type`、`layer` 对 `LearnableNode.layer`、`axes` 对 `Node.axis`，三个都是「单值或数组，数组取任一命中」。**空数组恒不命中**（`type: []` 读作「任何类型都不适用」），与「未给该键 = 不限」不是一回事 —— 写入口负责先丢空容器，读侧不再兜。`type` / `layer` 只对可学节点有意义：结构节点上声明了它们 ⇒ 不命中，那**不是**缺字段（`ADR-0007` 决策 1）。旧的 `spaceId`（一空间一包已废）与 `sixAxis`（六轴已废）**落进「未认的键 ⇒ 抛」**，不静默忽略。
> ⚠️ **与 §11 的 `appliesTo` 不是同一个形状**：源那侧是 `{axes[], node_scope[]}`、两键**必填**、过滤依据是「`node_scope` ∩ 子树」；方法这侧三键均可省、过滤依据是「节点自己的三个取值」。同名不同结构 —— 按一处写完直接拿到另一处用，会得到一份永远为真的过滤。

---

## 二、用户态（派生或本地）

### 13. `Plan` —— 计划（意图）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | = 该计划 `plan_created` 事件的 `id`，**不在 payload 另写一份** |
| `subtree_root` | string | **节点 id**（不用 path：`id` 稳定、`path` 会变）。取代旧的 `spaceId` |
| `primary_axis` | enum | 主序轴。**默认由模式给出**（学生 = 专业轴 / 职业规划 = 角色轴 / 个人学习 = 学科轴），**可被体系显式覆盖** |
| `pack_versions` | object | `{skeleton, payloads{}}` —— 旧的单值 `spaceVersion` 装不下多包 |
| `source_policy` | object | 主源 + 按类型 + 例外，引用 `SourceRef.id` |
| `scheme_id` / `method_profile_id` | string | — |
| `version` | int | 重规划时 +1，**由 `fold` 数该计划名下事件条数得出**，payload 不写 |
| `progress` | object | **派生**：`{learned / total, segments[]}` |
| `resolved` | string[] | **派生**：子树下全部可学项 id。**载荷安装变化时必须重算**，否则参照集合指向已卸载的项 |
| `sessions` | object[] | 以项边界（⑤ 检验完成）收尾的执行段 |

> **删除 `selector`**（旧六轴 DNF 筛选式）：子树根 id 已足够表达，且「点击即下钻」与筛选语义冲突。
> **合法粒度**：子树内可学项 ≥ 2。只有 1 项时 ② 选体系无顺序可排，候选卡会出现「覆盖 1/1」的伪选择。
> **模式锁的是 `primary_axis` 的默认值，不是访问权** —— 单轴体系下用户无感；跨轴体系覆盖它时，模式锁定没有被违反。

### 14. `SrsState` —— 每项的记忆状态（**派生，由事件折叠**）

| 字段 | 类型 | 说明 |
|---|---|---|
| `itemId` | string | 键。**= `Node.id`（行星层）**。字段名保留 `itemId`，避免历史事件迁移 |
| `D` | float | 难度。**首次评分时才初始化** —— 建计划时不存在 |
| `S` | float | 稳定度（天） |
| `lastReviewAt` | timestamp | — |
| `due` | timestamp | — |
| `failCount` | int | 连续未过计数，合格即清零（跨会话） |
| `reps` | int | 复习次数 |
| `skipStreak` | int | 连续跳过计数。**与 `failCount` 不可互相折算** |

> `R(t)` 与 `mastery` 均不入库。
> **本实体不建表**：`ADR-0005` 决策 5 之后它明确是 `node_id → SrsState` 的内存投影。卸载载荷不会「删掉」学习状态 —— 节点没了但事件还在，重装后 fold 恢复。

### 15. 三层学习状态（由事件 fold）

| 状态 | 判据 | 可逆性 |
|---|---|---|
| 未学 | 无 `item_passed` | — |
| **已学** | 存在 `item_passed`（⑤ 首次验收合格；判据为空时 = 步骤跑完） | **不可撤销** |
| **毕业** | `S ≥ 180` 天 | **不可逆**（毕业后降频长间隔，不退出队列） |

> **「记得住」与「学得深」是两件事**：`S` 回答前者，`requirements` 完整度 `d` 回答后者。`mastery = d × s`；`score` 不进（`score` 是 `R` 的观测值，已通过 FSRS 更新 `D`/`S`，再计入即重复计分）。
> **打卡项永不毕业**：`S` 永不增长 ⇒ 永不到 180。这是 `M3` 与 `X2` 相乘的必然结论，**必须显式保留** —— 不写清就会有人当 bug 修掉，一修就击穿 `M3` 的封顶逻辑。

### 16. `Note` —— 笔记

| 字段 | 类型 | 说明 |
|---|---|---|
| `itemId` | string | **锚点**（= `Node.id`）。两套笔记共用同一锚点，「随时切换」才成立 |
| `sectionKey` | string | 节标识（命名 TBD） |
| `layers` | object | `{generated, autoFilled, authored}` —— **三层都保留**，显示优先级 `authored > autoFilled > generated` |
| `noteVersion` | int | **按节独立计数**，不是整本一个号 |
| `origin` | enum | `standard` 标准体系笔记 / `self` 自建笔记 |

> 空间级自由笔记：`itemId` 为空，不参与两套切换。笔记**不进量化**（`d` 只看 `requirements`）。

### 17. `Submission` —— 提交（治理）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | — |
| `targetType` | enum | `node / source / scheme / method / note`（首期只开 `node`） |
| `target` | object | `{nodeId?}`。最小三字段提交：标题（可用搜索词预填）· 所属父节点 · 一句描述 |
| `status` | enum | `draft` 草稿 / `pending` 待审 / `local` 本地 overlay 可用 / `public` 公共 overlay / `rejected` 驳回 |
| `verdict` | enum | `通过` / `驳回` / `合并到已有节点（收作别名）` / `降为圈外成员` |

> **与 `Pack.review_state` 的映射**：`draft` → （无对应，包无草稿态）· `pending` → `pending` · `rejected` → `rejected` · `public` → `approved`。`revoked` **不适用于 Submission** —— 内容不强制撤回，只在视图层隐藏（`ADR-0005` 决策 5 + 铁律 ②）。
> **提交后立即进本地 overlay，立刻可学**；过审才进公共 overlay。「审核通过」的必要条件不是「提交」的门槛。

### 18. `ViewState` —— 界面状态（本地，不入事件流）

| 字段 | 类型 | 说明 |
|---|---|---|
| `mode` | enum | 导航 / 树 / 详情 / 定位结果 / 进展 / 修习 |
| `focus_slot` | enum | 当前聚焦的 `level_slot`。取代旧的 `Z0`–`Z4`（同心球壳无五档径向） |
| `selectedNodeId` | string \| null | — |
| `dualView` | bool | 是否切到导航树浮层。**恒星级起才可用**；切换后保持形态（下钻不退回 3D） |
| `focusChain` | string[] | 焦点链 |
| `expandedNodes` | string[] | 树展开集 |
| `cameraState` | object | 相机（位置 / 朝向 / 距离），切换视图时保留 |
| `returnTo` | object | 进入详情时快照：`{mode, focus_slot, selectedNodeId, subtree_root}` |
| `trail` | string[] | 详情页**内部**历史，上限 5 |

> **删除 `axisFilter`**（旧六轴 DNF：轴内 OR、轴间 AND）：三轴树里「点击是下钻、不是筛选」。树的展开集由 `expandedNodes` 表达，过滤需求由 `Plan.subtree_root` 表达。
> **`returnTo` 存 `subtree_root` 而非结果列表** —— 与 `Plan.resolved` 是派生值的处理一致。
> **最近访问与后退/前进不在此表**：它们是 `navigate` 事件的 fold 投影（留最近 100 条、按 id 去重、双栈），属会话状态，见 `event-types.md`。

---

## 附录：字段名对照（迁移用）

| 旧 | 新 | 处置 |
|---|---|---|
| `KnowledgeSpace` | `Pack` | 实体替换；`sixAxis` / `defaultPrimaryAxis` / `domainIds` 删 |
| `Item` | `Node`（行星层） | `title` → `name`；`sixAxis` / `primaryAxis` / `domainId` / `inScope` / `depth` 删（`inScope` / `depth` 改派生） |
| `Item.requirements` | `Node.requirements` | **保留**，仅可学项持有 |
| `Item.aliases` | `NodeEntry.aliases` | 移入内容侧 |
| `Edge`（`strong`/`weak`/`unknown`） | `PrerequisiteEdge`（`required`/`recommended`） | 三值改两值：`unknown` 由 `recommended` + 「后继不在本包」表达 |
| `Question`（独立段） | `NodeEntry.quiz[]` | 内嵌，加 `criterion_id` / `type` / `judge` |
| `Scheme.nodes` 的 `⪯` 线性扩展 | 三条校验 | 见 §10 |
| `SourceRef.authorityLevel` `L0`–`L4` | `authority_level` 五档语义值 | 见 §11 映射表；数据 10 条待迁移 |
| `SourceRef.appliesTo{spaceId, sixAxis}` | `appliesTo{axes[], node_scope[]}` | 键全换 |
| `Plan.spaceId` | `Plan.subtree_root` | 值类型改为节点 id |
| `Plan.spaceVersion` | `Plan.pack_versions` | 单值 → 多包 |
| `Plan.target.selector` | （删除） | 子树根已足够 |
| `Plan.target.resolved` | `Plan.resolved` | 提升为顶层派生字段 |
| `ViewState.zoomLevel` `Z0`–`Z4` | `ViewState.focus_slot` | 五档径向 → 语义槽位 |
| `ViewState.axisFilter` | （删除） | 下钻取代筛选 |
| `SrsState` / 三层学习状态 / `Note` / `Submission` | 原样 | 仅 `itemId` 语义明确为 `Node.id` |

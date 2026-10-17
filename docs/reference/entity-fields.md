# 实体字段表

> **唯一权威处**：实体与字段只在本文件定义。字段的**值域**若在别处（事件 payload、常量），以对应表为准。
> 标记「派生」的实体/字段**不入库**，由 `fold(events, asOf)` 或纯函数算出。

## 一、内容侧（来自 pack）

### 1. `KnowledgeSpace` —— 知识空间（容器）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 稳定标识，如 `python`。格式 `^[a-z][a-z0-9-]*$`；它同时是 tag 名 `pack/<space>/vX.Y.Z` 里的 `<space>` |
| `name` | string | 展示名 |
| `version` | semver | 包版本；参与合成版本 `pack@vX + overlay@N`。**来源**：源数据 `manifest.json` 的 `version`，`build.py` 原样透传至 `pack.json` 的 `meta.version`（`SPEC-PACK-005`），tag `pack/<space>/vX.Y.Z` 与之逐字一致 |
| `sixAxis` | object | 本空间在六轴上的取值（用于 Z0 分组与筛选）。键名见 §2 取值域 |
| `accent` | string | 主题强调色，随包下发。格式 `#RRGGBB` |
| `order` | int | Z0 星系列表排序 |
| `domainIds` | string[] | 空间内的「域」（Z2 星云），可选层 |

**边界三判据**（三条全齐才是独立空间，缺一条降为上位空间内的「域」）：
① 独立前提偏序 `⪯` ② 独立版本 ③ 三层结构齐全（持久 / 视图 / 快消）

> **`pack.json` 的 `meta` 信封只承载本实体的两个字段**：`space`（= `id`）与 `version`（`SPEC-PACK-005`）。信封不含时间戳，也不承载任何内容字段。

### 2. `Item` —— 知识项（Q，KST 三元组的 Q）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | **必须与版本无关的稳定 id**。格式 `<manifest.id>/<slug>`（如 `python/variable`，两侧小写字母起、可含数字与连字符）。带版本号会导致升级后所有已学事件指向旧 id |
| `title` | string | 标题；六轴之外的**唯一自由文本匹配面** |
| `sixAxis` | object | 六轴取值，每轴**单值**（这是「同轴多选取 OR」的前提）。键名见下表 |
| `layer` | enum | `persistent` 持久 / `view` 视图 / `ephemeral` 快消，驱动形态通道 |
| `type` | enum | 决定方法派发：`declarative` 陈述 / `procedural` 程序 / `skill` 技能 / `tacit` 默会 |
| `requirements` | object | 六要件 × 三态，键与取值见下表 |
| `sourceRefs` | string[] | 引用 `SourceRef.id` |
| `domainId` | string | 所属域（Z2），须在 `manifest.domainIds` 内 |
| `inScope` | bool | 圈内 / 圈外 |
| `depth` | int | **派生** = `φ`（`⪯` 上的 Kahn 层号），不入库 |
| `aliases` | string[] | ⚠️ **首期不实现**（不扩 schema）；重复检测降级为标题近似 + 人工裁定 |

**取值域** —— JSON 里用的是英文键与英文值，中文只是本表的表述，**不进数据**：

| 字段 | 键 / 值 | 出处 |
|---|---|---|
| `sixAxis` | `subject` 学科 · `role` 岗位 · `industry` 行业 · `ability` 能力 · `topic` 主题 · `stack` 技术栈 | `SPEC-FND-002` |
| `requirements` | `boundary` 边界 · `justification` 证成 · `proposition` 命题 · `relation` 关联 · `how` How · `tacit` Tacit | `SPEC-FND-004` |
| `requirements.*` | `present` 齐 · `missing` 缺 · `not_externalizable` 不可外化 | `SPEC-PACK-009` |

三态含「缺」，因此 **`null` 不是合法取值**：还没写用 `missing`，本来就没有外部形态用 `not_externalizable`。

### 3. `Edge` —— 前提边

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 段内唯一，小写字母 / 数字 / 连字符 |
| `from` / `to` | string | 前置 → 后继，均指 `Item.id` |
| `type` | enum | `strong` 强依赖（实线）· `weak` 弱依赖（虚线）· `unknown` 指向未知（虚线） |

> `⪯` 必须是 **DAG**。任意环须在内容校验阶段拒绝。
>
> **`unknown` 的边界**：它是唯一允许 `to` 指向**不在本包内**的项 —— 用来显式声明「后继已知存在，但尚未收进本包」。另两个取值指向不存在的项一律拒绝。`unknown` 不是「先占位、以后再补」的通用出口。

### 4. `Question` —— 声明式题（`questions` 段）

为 ⑤ 检验提供**可离线、可复现**的题；模型生成的题不入包（不可复现、不参与 SRS —— `SPEC-PACK-006` 第一次扩 schema 的原因）。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 段内唯一 |
| `itemId` | string | 指向 `Item.id`，必须存在 |
| `prompt` | string | 题干 |
| `answer` | string | 参考答案 |

> 四项是**首期最小集**。加字段前先改本表 —— `questions` 已计入 `SPEC-PACK-006` 的两次扩大，再扩要过「第三次扩 schema 应暂停」的判据。

### 5. `Scheme` —— 体系（顺序）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | — |
| `name` | string | 如「官方 Tutorial 序」「语法分层」「工程路线」 |
| `nodes` | string[] | `Item.id` 的**线性序列** |
| `authorityLevel` | enum | `L0` / `L1` / `L2` / `L4`，驱动候选卡的等级徽标 |
| `inversions` | int | **派生**：本序列倒置了多少条前提边（`⪯` 逆序数） |

**硬约束：`nodes` 必须是 `⪯` 的一个线性扩展。** 逆序不禁止，但必须算出 `inversions` 并在 Planner 显式展示代价（如「本序 4 处逆序，第 3 步会卡在装饰器」）。

### 6. `SourceRef` —— 源（材料）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | — |
| `name` | string | 展示名 |
| `authorityLevel` | enum | `L0` / `L1` / `L2` / `L4`（源排序键） |
| `version` | string | 源自身的版本 |
| `segments` | object[] | **内嵌最小结构化摘录**：`{ text, locator(页码/锚), license }` —— 离线可读 |
| `appliesTo` | object | 适用范围 |

> **换源不改观感**：亮度只由六要件 `k` 决定，源只写进详情页的 `sources`，**不进任何视觉通道**。

### 7. `MethodProfile` —— 方法（动作 + 判据）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | — |
| `name` | string | 如「费曼学习法」「间隔重复」「刻意练习」「跟读模仿」「项目驱动」 |
| `steps` | object[] | 见下 |
| `appliesTo` | object | **必填**：适用哪类项（`Item.type` / 六轴 / 三层） |
| `origin` | enum | `platform / pack / user`（出处标签，合并优先级 `user > pack > platform`） |

`steps[]` 每项字段：

| 字段 | 说明 |
|---|---|
| `operator` | **6 类执行算子之一**：`读 / 例 / 忆 / 练 / 讲 / 做`。**不得自创** |
| `params` | 算子参数（如时长、重复次数） |
| `phase` | `first / review / both`；默认由算子派生（读/例 → `first`；忆/练/讲/做 → `both`），作者可覆盖 |
| `hint` | 可选。**脚手架能被观测的前提**；未声明则该项无提示可给 |
| `criteria` | 可选。为空 = 打卡式（`checked`）；非空 = 验证式（`verified`） |

**校验规则**（三条）：
① 算子必须在册（6 类之内）—— 防自创；
② **至少有一个 `review` 步骤**（等价于「至少有一个 both 类算子」）—— 防静默绕过遗忘曲线；
③ 全步骤无 `hint` 时，Planner ③ 须提示「本方法无提示可给，熟练档不受约束」—— 不禁止，但显式标代价。

## 二、用户态（派生或本地）

### 8. `Plan` —— 计划（意图）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | — |
| `spaceId` | string | **键**。一空间可并存多份 Plan |
| `spaceVersion` | string | 建计划时的包版本 |
| `target` | object | `{ selector, resolved[], count }`。**粒度随视距**：Z1 ≈150 项 / Z3 ≈12 项 / Z4 = 1 项 |
| `sourcePolicy` | object | 主源 + 按类型 + 例外，引用 `SourceRef.id` |
| `schemeId` | string | — |
| `methodProfileId` | string | — |
| `version` | int | 重规划时 +1 |
| `progress` | object | **派生**：`{ learned / total, segments[] }`。分母 = 圈内项数（含未纳入路径的游离项） |
| `sessions` | object[] | 一组连续的、以项边界（= ⑤ 检验完成）收尾的执行段 |

### 9. `SrsState` —— 每项的记忆状态（派生，由事件折叠）

| 字段 | 类型 | 说明 |
|---|---|---|
| `itemId` | string | 键 |
| `D` | float | 难度。**首次评分时才初始化** —— 建计划时不存在 |
| `S` | float | 稳定度（天） |
| `lastReviewAt` | timestamp | — |
| `due` | timestamp | — |
| `failCount` | int | 连续未过计数，合格即清零（跨会话） |
| `reps` | int | 复习次数 |
| `skipStreak` | int | 连续跳过计数。**与 `failCount` 不可互相折算** |

> `R(t)` 不入库。掌握度 `mastery` 不入库。二者皆派生。

### 10. 三层学习状态（由事件 fold）

| 状态 | 判据 | 可逆性 |
|---|---|---|
| 未学 | 无 `item_passed` | — |
| **已学** | 存在 `item_passed`（⑤ 首次验收合格；判据为空时 = 步骤跑完） | **不可撤销** |
| **毕业** | `S ≥ 180` 天 | **不可逆**（毕业后降频长间隔，不退出队列） |

> **「记得住」与「学得深」是两件事**：`S` 回答前者，六要件完整度 `d` 回答后者。掌握度 `mastery = d × s`，两者都进但 `score` 不进（`score` 是 `R` 的观测值，已通过 FSRS 更新 `D`/`S`，再计入即重复计分）。

### 11. `Note` —— 笔记

| 字段 | 类型 | 说明 |
|---|---|---|
| `itemId` | string | **锚点**。两套笔记共用同一锚点，这是「随时切换」成立的前提 |
| `sectionKey` | string | 节标识（命名 TBD） |
| `layers` | object | `{ generated, autoFilled, authored }` —— **三层都保留**，显示优先级 `authored > autoFilled > generated` |
| `noteVersion` | int | **按节独立计数**（不是整本一个号） |
| `origin` | enum | `standard / self`（标准体系笔记 / 自建笔记） |

> 空间级自由笔记：`itemId` 为空，不参与两套切换。笔记**不进量化**（`d` 只看六要件）。

### 12. `Submission` —— 提交（治理）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | — |
| `targetType` | enum | `item / domain / source / scheme / method / note`（首期只开 `item`） |
| `target` | object | `{ itemId? }`。**最小三字段提交**：标题（可用搜索词预填）· 所属域 · 一句描述 |
| `status` | enum | 草稿 / 待审 / **本地 overlay 可用** / 公共 overlay / 驳回 |
| `verdict` | enum | `通过 / 驳回 / 合并到已有项（收作别名） / 降为圈外成员` |

> **四件套（归位 / 前提边 / 六要件 / L 层来源）是「审核通过」的必要条件，不是「提交」的门槛。**
> 提交后**立即进本地 overlay，立刻可学**；过审才进公共 overlay。

### 13. `ViewState` —— 界面状态（本地，不入事件流）

| 字段 | 类型 | 说明 |
|---|---|---|
| `mode` | enum | `宇宙 / 树 / 详情 / 定位结果 / 进展 / 修习` |
| `zoomLevel` | enum | `Z0–Z4` |
| `selectedItemId` | string \| null | — |
| `focusChain` | string[] | 焦点链 |
| `expandedNodes` | string[] | 树展开集 |
| `cameraState` | object | 相机（位置 / 朝向 / 距离），切换视图时保留 |
| `axisFilter` | object | **DNF**：轴内 OR、轴间 AND |
| `returnTo` | object | 进入详情时快照：`{ mode, zoomLevel, selectedItemId, axisFilter, selector }`。**存 selector 而非结果列表** |
| `trail` | string[] | 详情页**内部**历史，上限 5 |

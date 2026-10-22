# M1 · 最小示例包规格

> **定位**：`B13a` 笔 2–6 的**验收样本**。不是产品示例、不是教程、不是内容基线 —— 它的唯一用途是让「实体层做完了」这件事**可观测**。
> **消费方**：`B13a` 笔 2 的校验器单测（读 `app/test/fixtures/m1/` 下的数据与 `expect.json`）。**本笔不出测试代码** —— 笔 2 才写。此处只出**数据 + 期望结果**，避免「先写断言再补实现」把判据写成实现的样子。
> **为什么需要它**：`B13a` 的闸门是四条静态检查 + 三元校验单测，而**单测需要输入**。没有这份样本，笔 2 只能自己编数据再自己判过 —— 就是 `X-05`。

## 一、边界

| 含 | 不含 |
|---|---|
| 一个**可装载**的 `payload` 包：1 行星系 + 2 行星 + 边 + 内容 | 骨架数据（`B13b`，需三份官方目录） |
| 三元校验的**每个面**各一组正例 / 反例 | `overlay` / `terrain` / `method` 三类包（`B14` / `B15` / `B16`） |
| 一条**能跑到底**的学习链所需的最小内容（steps + criteria + quiz） | 真实学科内容、真实材料、真实题目 |
| 与 `path` 16 条规则的逐条对应 | 性能样本（那是 `B17b` 的星图） |

**规模上限**：3 个节点、4 条边、2 份 `NodeEntry`。**超了就不是「最小」**，而「最小」是本规格唯一不可让的约束。

## 二、文件布局

```text
app/test/fixtures/m1/
├── expect.json                 # 正例的期望结果（exit 0 / 无错误码）
├── pack.json                   # 正例：最小载荷包全文
├── neg-id-format/expect.json + pack.json
├── neg-id-dup/expect.json + pack.json
├── neg-path-parent/expect.json + pack.json
├── neg-path-dup/expect.json + pack.json
├── neg-slug-format/expect.json + pack.json
└── neg-parent-cross-pack/expect.json + pack.json
```

`expect.json` **沿用** [`content/tools/fixtures/`](../../content/tools/fixtures/) 的既有字段（`base` / `exit` / `codes` / `note`）—— 那套已经在用、已被 37 个用例消费，不另立一套。

**为什么不放 `content/tools/fixtures/`**：那批夹具喂的是**旧模型**（`sixAxis` / `spaceId` / `Item`）的 `verify.py`，`safe_load` 会按旧 schema 解析。新模型的样本混进去，要么被旧规则误判，要么逼着旧工具兼容两套 schema —— 两条都是把作废概念留在活代码里。

## 三、最小包内容

### 3.1 manifest

字段集以 [`entity-fields.md`](entity-fields.md) §1 为准，本规格只规定**取值**：

| 字段 | 取值 | 说明 |
|---|---|---|
| `plugin_id` | `m1-demo` | 符合 `^[a-z][a-z0-9-]*$` |
| `version` | `1.0.0` | — |
| `kinds` | `["payload"]` | 单类，最小 |
| `namespace` | `m1-demo` | 实际 id = `m1-demo:{local_id}` |
| `schema_version` | `1` | — |
| `skeleton_requires` | `>=1.0.0 <2.0.0` | — |
| `deps` | `[]` | 单包，无跨包依赖 |
| `axes` | `["major"]` | 只挂专业轴 |
| `payload.attach_to` | `skeleton:major/080901` | 挂到骨架恒星（本科专业 `080901` 计算机科学与技术） |
| `payload.subtree_root` | `system` | 本包提供的最上层槽位 |
| `payload.level_range` | `["system","planet"]` | — |
| `payload.counts` | `{star:0, system:1, planet:2}` | — |
| `payload.path_reservations` | `[{parent_id:"skeleton:major/080901", slug:"cs-core"}]` | 装前判冲突的唯一依据（`P-16`） |

### 3.2 节点

| id | `level_slot` | `slug` | 父 | 期望 `path` |
|---|---|---|---|---|
| `m1-demo:cs-core` | `system` | `cs-core` | `skeleton:major/080901`（经 `attach_to`） | `major/08/0809/080901/cs-core` |
| `m1-demo:var` | `planet` | `var` | `m1-demo:cs-core` | `major/08/0809/080901/cs-core/var` |
| `m1-demo:func` | `planet` | `func` | `m1-demo:cs-core` | `major/08/0809/080901/cs-core/func` |

两个 `planet` 必带 `type` / `layer` / `requirements`（`LearnableNode` 三项非可空，`ADR-0007`）；`system` **必不带**这三项。

`scope` 一律 `S1`（平台），`pack_id` 一律 `m1-demo`，`status` 一律 `live`。

### 3.3 边

| 类型 | 条数 | 内容 |
|---|---|---|
| `ParentEdge` `main` | 3 | `cs-core → skeleton:major/080901`（由 `attach_to` 物化）· `var → cs-core` · `func → cs-core` |
| `ParentEdge` `secondary` | 0 | 最小包不演示附加归属 |
| `WormholeEdge` | 0 | 单包单轴，无虫洞可跳 |
| `PrerequisiteEdge` | 1 | `var --required--> func`（`var` 是 `func` 的前置） |

**`secondary` / `WormholeEdge` 取 0 是刻意的**：它们各自有独立校验（主父唯一 / DAG 无环），但**不是三元校验的面**；塞进来会让「最小」失效，把笔 2 的范围放大。

> **JSON 形态（本规格定，笔 3 若改须同步此处）**：三类边同放 `edges[]`，每条带显式判别符 `"type": "parent" | "wormhole" | "prerequisite"`，**不靠字段名推断类型**（`wormhole` 与 `prerequisite` 都有 `from_id` / `to_id`，靠猜必然分不清）。这条与 `ADR-0007`「反序列化按判别符分派为唯一入口、不允许旁路构造」同构。

### 3.4 载荷内容

两个 `NodeEntry`，各含 `steps[]`（2 步）、`criteria[]`（1 条）、`quiz[]`（1 题）。字段以 `entity-fields.md` §9 为准。

**必须能验证的两件事**：
1. `criteria` 只有 `id` / `statement` —— **没有 `judge_type`**（`OD-02` 裁定后删的字段）。反例不需要：字段根本不在 schema 里，写了就是未知字段。
2. `steps[].operator` 取值只能来自 `read` / `example` / `recall` / `practice` / `explain` / `do`（`OD-03` 维持）。正例至少各出现一次 `first` 与 `both` 派生，以覆盖「至少一个 `review` 步骤」的校验。

## 四、本笔新定的三条（此前无文）

### 4.1 `attach_to` 装载后**物化为跨包 `main` `ParentEdge`**

`attach_to` 不是第三种边，它是**跨包主父的申报形式**。装包时物化为一条 `ParentEdge{kind: main}`，之后一切（`pathOf` / `ParentIndex` / 主父唯一性）都按普通主父处理。

**理由**：若不物化，`pathOf` 就要同时处理两种父来源，`ParentIndex`（child → main parent 的 `Map`）也得存两种 —— 而 path 计算、面包屑、圈定范围全部读这一个 `Map`。物化一次，下游零分支。

**方向固定**：只允许 `载荷 → 骨架`。骨架挂到载荷下没有合法场景（骨架是 `S0`、全量内置、不依赖任何插件）。

**这条是 `P-15` 的唯一例外**，`path-rules.md` `P-15` 已按此表述（`payload.attach_to` 显式列出）。

### 4.2 骨架 `path` 由**外部索引注入**，不内置

笔 2 时骨架数据（`B13b`）尚未存在，因此校验器签名必须是：

```dart
// 骨架父节点的 path 由调用方给出；笔 2 用 3 条 fixture 常量，B13b 起换成真骨架
PathValidation validatePack(PackJson pack, Map<String, String> skeletonPaths);
```

**不许**为了让校验器能跑而内置一份假骨架 —— 那会变成第二份骨架数据，且它在 `B13b` 落地那天不会自动消失。

### 4.3 错误码表（6 个，笔 2 必须实现）

| 码 | 触发 | 对应规则 |
|---|---|---|
| `E-ID-FORMAT` | `id` 不符合 `{plugin_id}:{local_id}`，或含版本号段 | `P-01` · `P-09` |
| `E-ID-DUP` | 全库 `id` 重复 | `P-07` 的 id 侧 |
| `E-PATH-PARENT` | 计算出的 `path` 与父链 `slug` 串不符 | `P-02` · `P-03` |
| `E-PATH-DUP` | 同一 `(parent_id, slug)` 出现两次，或两条不同父链拼出同一 `path` | `P-06` · `P-07` |
| `E-SLUG-FORMAT` | `slug` 不匹配 `^[a-z0-9-]+$`，或作者使用 `_` 开头的保留段 | `P-04` |
| `E-PARENT-CROSS-PACK` | `parent_id` 指向非同包节点，且不是 `attach_to` 申报的那一个 | `P-15` |

**码名沿用既有风格**（`E-<域>-<形态>`，与内容侧 `E-ID-FORMAT` 同名同义，不另造）。

**校验顺序固定，遇错即停（fail-fast）**：

```text
id 格式 → id 唯一 → slug 格式 → 父链可达 → path 构成 → path 唯一 / 同父唯一 → 跨包
```

**顺序不可换**：反例的价值靠「期望恰好一个码」成立，而这条只有在顺序固定时才可预测。若两条错误同时存在（反例是完整包，改动一处往往连带其他），**先触发的那个码才是 `expect.json` 该写的**。`neg-id-dup` 就依赖这点 —— 改 `func` 的 id 会让 `edges` 里对 `m1-demo:func` 的引用变悬空，但 `id 唯一` 早于 `父链可达`，故只报 `E-ID-DUP`。

## 五、fixtures 清单

| 目录 | 类型 | 验什么 | 期望 |
|---|---|---|---|
| （根） | 正例 | 全绿：3 节点 / 4 边 / 2 entry 全部合法 | `exit 0`，无错误码 |
| `neg-id-format/` | 反例 | `var` 的 id 写成 `m1-demo:v1:var`（含版本号段） | `E-ID-FORMAT` |
| `neg-id-dup/` | 反例 | 两个节点 id 都是 `m1-demo:var` | `E-ID-DUP` |
| `neg-path-parent/` | 反例 | `func` 的 `slug` 改成 `fn`，但期望 path 仍按 `func` 给 | `E-PATH-PARENT` |
| `neg-path-dup/` | 反例 | `var` 与 `func` 的 `slug` 都改成 `same` | `E-PATH-DUP` |
| `neg-slug-format/` | 反例 | `func` 的 `slug` 改成 `Func_2`（含大写与下划线） | `E-SLUG-FORMAT` |
| `neg-parent-cross-pack/` | 反例 | `var` 的 `parent_id` 写成 `skeleton:major/080901`（绕过 `attach_to` 直接挂骨架） | `E-PARENT-CROSS-PACK` |

**每个反例只改一处、只期望一个码** —— 一次改两处就分不清是哪条规则抓到的，反例的证明力归零（`STR` 里多次踩过：多处改动导致无法归因）。

**反例包是精简的**：只含三元校验读得到的字段（manifest 必填项 + `nodes` + `edges`），**不含** `entries` / `sources` / `schemes` —— 那三组不参与三元校验，放进去只会让反例看不出改在哪。

### 5.1 正例 `expect.json` 要带的两组额外字段

`path` 是**派生值**（`P-01`），包里不存它 —— 因此「path 对不对」只能靠**期望映射**断言，不能靠读数据比对：

```json
{
  "base": null,
  "exit": 0,
  "codes": [],
  "note": "…",
  "skeletonPaths": { "skeleton:major/080901": "major/08/0809/080901" },
  "paths": {
    "m1-demo:cs-core": "major/08/0809/080901/cs-core",
    "m1-demo:var":     "major/08/0809/080901/cs-core/var",
    "m1-demo:func":    "major/08/0809/080901/cs-core/func"
  }
}
```

- `skeletonPaths` = 喂给 §4.2 那个 `Map<String, String>` 的注入值。**笔 2 用它，`B13b` 起换成真骨架**，接口不变。
- `paths` = `pathOf` 的**期望输出**。这是三元里 `path` 一元的唯一断言形式 —— 没有它，「path 校验器」只能验格式、验不了内容。
- 反例的 `expect.json` **不带** `paths`：它已被 `codes` 判定，再给一份期望 path 只会让「到底哪个先失败」变模糊。

## 六、与 `path-rules` 的对应

| 规则 | 正例覆盖 | 反例覆盖 |
|---|---|---|
| `P-01` 派生 / 引用用 id | ✅ 包内无 `path` 字段 | `neg-id-format` |
| `P-02` 父链 slug 串联 | ✅ 三级 path 逐段可验 | `neg-path-parent` |
| `P-03` URI = path | ✅ 逐字相等 | 同上 |
| `P-04` slug 字符集 | ✅ 全小写连字符 | `neg-slug-format` |
| `P-05` 无码节点 slug 是唯一来源 | ✅ 两 planet 无 `official_code` | — |
| `P-06` 同父唯一 | ✅ 同父两个不同 slug | `neg-path-dup` |
| `P-07` path 全局唯一 | ✅ — | `neg-path-dup` |
| `P-09` id 稳定 / 不带版本号 | ✅ | `neg-id-format` |
| `P-15` 禁跨包父子 | ✅ 经 `attach_to` 申报 | `neg-parent-cross-pack` |
| `P-16` `path_reservations` | ✅ manifest 已列 | — |
| `P-08` · `P-10`–`P-14` | **不覆盖** —— 属运行期状态（`PathClaim` / `PathAlias` / 墓碑），静态包样本表达不出来，归笔 2 的**状态迁移单测**而非 fixture | — |

## 七、维护

- **正例先行**：反例一律以正例为基线，只改一处。改正例必须同步跑一遍全部反例（`expect.json` 的 `base` 字段就是为此）。
- **规模上限不可破**：要演示新能力（如 overlay）就另立 `M2`，不往这份里加。
- 本规格**不定义**字段值域 —— 值域在 `entity-fields.md`，冲突时以它为准并回来改本文件。

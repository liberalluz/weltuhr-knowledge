# content/tools

源数据（`content/<空间>/`）→ 构建产物（`dist/pack.json`）的管线。**纯标准库，无第三方依赖**。

> ⚠️ **本文件描述的是管线当前实现**（旧五段 + `meta` 信封），不是包格式的目标形态。目标形态见 `SPEC-PACK-005`「单文件 = 清单 + 六段」，差距与迁移时机写在那条的「迁移状态」段，此处不复述 —— 同一件事记两处，改一处就会留一句假话。

```bash
python content/tools/build.py                      # 构建全部空间
python content/tools/build.py python               # 只构建 content/python/
python content/tools/build.py --root <目录> --out <文件>   # 构建任意目录（fixtures / 临时）
python content/tools/build.py --root <目录> --check       # 确定性检查，不落盘
python content/tools/verify.py --root <目录>        # 只校验源数据
python content/tools/verify.py --pack <pack.json>   # 校验已构建的产出
python content/tools/verify.py --suite              # 全部 fixtures（源层 + 产物层）+ 错误码覆盖自检
```

## 三个文件

| 文件 | 职责 |
|---|---|
| `validator.py` | 所有判据。只读、不改写数据，一次报全部问题 |
| `build.py` | 拼 `meta` 信封、固定序列化、原子落盘、确定性检查 |
| `verify.py` | 独立校验 + fixtures 回归 |

`build.py` 与 `verify.py` 共用 `validator.py`：构建前先校验，校验不过不落盘 —— 避免 `dist/` 里躺着半合规的包。

## 取值域

**唯一权威处是 [`docs/specs/entity-fields.md`](../../docs/specs/entity-fields.md)**。本表只做索引，不重述取值 —— 同一批字面量若在这里再写一遍，就成了第二份事实源。要改取值，先改那份，再改代码。

表按 `pack.json` 的**目标形态**索引（`SPEC-PACK-005`：单文件 = 清单 + 六段）：

| 用到的地方 | 权威处 |
|---|---|
| 清单字段（`plugin_id` · `kinds[]` · `version` · `deps[]` · 四个可空 facts …） | `entity-fields.md` §1 `Pack` |
| `nodes` 段（`level_slot` · `slug` · `type` · `layer` · `requirements`） | `entity-fields.md` §2 `Node` |
| `edges` 段的 `parent` 类（主父唯一 · 附加归属） | `entity-fields.md` §3 |
| `edges` 段的 `wormhole` 类 | `entity-fields.md` §4 |
| `edges` 段的 `prerequisite` 类（`strength` 两档） | `entity-fields.md` §5 |
| `entries` 段（`steps[]` · `criteria[]` · `quiz[]`） | `entity-fields.md` §9 `NodeEntry` |
| `schemes` 段 | `entity-fields.md` §10 `Scheme` |
| `sources` 段 | `entity-fields.md` §11 `SourceRef` |
| `methods` 段 | `entity-fields.md` §12 `MethodProfile` |
| 三态语义：`null` 不是合法取值 | `SPEC-PACK-009` |

⚠️ **本表是新形态的索引，而本目录的 Python 管线还没迁过去** —— 迁移状态写在 `SPEC-PACK-005` 的说明里，别在两处各记一份。当前的对应关系：

| 管线现在产出 | 迁移后落在 |
|---|---|
| `manifest.json` | `pack.json` 顶层清单字段 |
| `items.json` | `nodes` + `entries` |
| `edges.json` | `edges` |
| `schemes.json` | `schemes` |
| `questions.json` | `entries[].quiz[]` |
| `excerpts.json` | `sources` |
| `meta{space, version}`（信封） | 清单字段的 `plugin_id` / `version` |
| — | `methods`（旧五段无处安放，这也是旧形态「方法档为空」的根因） |

**别把左列当现状读、也别把右列当已实现读** —— 那是一张迁移清单，不是完成报告。

## 序列化约定

`sort_keys=True` · `indent=2` · `ensure_ascii=False` · 分隔符 `(",", ": ")` · 末尾单换行。

这五项是 `SPEC-PACK-005`「`version` 不含构建时间戳」的**唯一实现**。换任何一项，同一 commit 的两次构建就会 byte 不等，而 `pack.json` 不入库、tag 是产物唯一指针 —— 事后无从比对。

`--check` 用四项实证这一点：

1. 同进程两次构建 byte 相同
2. 产出再序列化后与原文相同（幂等）
3. **反转每个 object 的键顺序后**再序列化，仍与原文相同（`sort_keys` 真在生效）
4. 另一个进程 + 不同 `PYTHONHASHSEED` + 不同 cwd 构建，byte 相同

## 校验规则（issue code）

| code | 判据 |
|---|---|
| `E-MANIFEST-MISSING` / `E-MANIFEST-FIELD` | manifest 缺失 / 必填字段缺失或类型错 |
| `E-VERSION-FORMAT` | `version` 不是纯 semver（**含前导空格也不放行**，不做 trim） |
| `E-CYCLE` | `⪯` 有环，报出完整环路径（`SPEC-FND-005`） |
| `E-SPACE-NO-ORDER` | 边集为空 —— 缺独立 `⪯`，按 `SPEC-PACK-001` 应降为域而非独立成包（文件在、段齐也拒） |
| `E-ID-VERSIONED` | `Item.id` 含版本号（`SPEC-FND-013` / `SPEC-PACK-008`） |
| `E-ID-DUP` / `E-ID-FORMAT` | id 重复 / 形如 `<space>/<slug>` |
| `E-REQ-KEY` | 六要件缺格或多出键 |
| `E-REQ-STATE` | 某格为 `null` —— 「还没写」用 `missing`，「本来就没有外部形态」用 `not_externalizable` |
| `E-REQ-VALUE` | 某格取值不在三态内 |
| `E-EDGE-REF` | `to` 指向不存在的项且 `type != unknown` |
| `E-SCHEME-NODE-REF` / `E-SCHEME-DUP` | `nodes` 引用不存在的项 / 有重复 |
| `E-SOURCEREF` / `E-QUESTION-REF` | `sourceRefs` / `itemId` 指向不存在的实体 |
| `E-PACK-EXTRA-KEY` | `pack.json` 出现五段与 `meta` 之外的键（`SPEC-PACK-007` 的 notes 即此） |
| `E-META-EXTRA-KEY` / `E-META-VERSION` | `meta` 多出字段（如时间戳）/ 与源 `version` 不逐字相同 |

`inversions` 是**派生值**，不校验、只计算（`validator.compute_inversions`）：逆序不禁止，但必须算得出来，Planner 才能展示代价。

## fixtures

分两层，`--suite` 一次跑完：

| 层 | 目录 | 被测对象 |
|---|---|---|
| **源数据层** | `fixtures/<name>/` | `load_source` → `validate` → `check_pack_object` 全链路（走 `build.build_text`） |
| **产物层** | `fixtures/pack/<name>/` | 直接递一个坏 `pack.json` 给 `check_pack_object` |

**为什么必须分两层**：`assemble()` 拼出的 pack 结构恒定（五段 + 两键 `meta`），所以 `E-PACK-*` / `E-META-*` 在源数据路径上**永远触发不了**。它们防的是「有人手改产物」与「构建逻辑退化」，只能直接喂坏对象才测得到。**不测就等于不存在** —— 这正是 `R-07` 的形态。

### `expect.json`

```json
{
  "base": "valid-min",
  "drop": ["manifest.json"],
  "exit": 1,
  "codes": ["E-MANIFEST-MISSING"],
  "scheme": "scheme-official-tutorial",
  "inversions": 1,
  "note": "为什么需要这个 fixture"
}
```

- `base` —— 从哪个 fixture 继承完整源数据；本目录只写「被测规则相关的那个文件」。**必须显式写，不按目录名猜**
- `drop` —— 展开后删除哪些文件。「缺文件」类判据（`E-MANIFEST-MISSING` / `E-SEGMENT-MISSING`）只靠复制造不出来，必须显式声明删哪个；删在最后一步，所以 base 提供的文件也能删
- `exit` —— 期望构建退出码（`0` 通过 / `1` 拒绝）
- `codes` —— 期望出现的 issue code（**不要求穷尽**，允许连带错误）
- `scheme` + `inversions` —— 断言派生值算得对
- `expectedVersion` —— 仅产物层用：模拟「源 manifest 的版本」，用来触发 `E-META-VERSION`

### 源数据层

原有 9 份：

| fixture | 锁定什么 |
|---|---|
| `valid-min` | 五段齐全、三态齐全、含一条 `unknown` 边；也是「怎么写一个空间」的示例 |
| `valid-inversion` | 体系逆序 **不禁止**，但 `inversions` 必须算出 1 |
| `neg-cycle` | 环被拒，且环路径可读 |
| `neg-no-order` | 空边集被拒 —— 「文件在」不等于「有 `⪯`」 |
| `neg-dupid` | 同 id 重复被拒 |
| `neg-requirements` | 缺格（`E-REQ-KEY`）与 `null`（`E-REQ-STATE`）是两类错 |
| `neg-req-value` | `partial` 这类「像是对的」取值不在三态内（`E-REQ-VALUE`） |
| `neg-version-space` | `version` 带前导空格被拒，不静默 trim |
| `neg-versioned-id` | `python/decorator@2.1.0` 被拒（`PACK-008` 验收向量） |

`R-07` 补齐后新增 23 份（按段分组，每条的具体理由写在各自 `expect.json` 的 `note` 里）：

| 组 | fixture | 锁定的码 |
|---|---|---|
| manifest | `neg-manifest-missing` · `neg-manifest-required` · `neg-manifest-field` | `E-MANIFEST-MISSING` · `E-MANIFEST-FIELD` |
| 段与 JSON | `neg-segment-missing` · `neg-segment-type` · `neg-json` | `E-SEGMENT-MISSING` · `E-SEGMENT-TYPE` · `E-JSON` |
| 六轴 | `neg-sixaxis` | `E-SIXAXIS` |
| item | `neg-item-field` · `neg-layer-type` · `neg-id-format` · `neg-domain` | `E-ITEM-FIELD` · `E-LAYER` · `E-TYPE` · `E-ID-FORMAT` · `E-DOMAIN` |
| edge | `neg-edge-field` · `neg-edge-type` · `neg-edge-ref` · `neg-edge-dup` | `E-EDGE-FIELD` · `E-EDGE-TYPE` · `E-EDGE-REF` · `E-EDGE-DUP` |
| scheme | `neg-scheme-field` · `neg-scheme-auth` · `neg-scheme-dup` · `neg-scheme-node-ref` | `E-SCHEME-FIELD` · `E-SCHEME-AUTH` · `E-SCHEME-DUP` · `E-SCHEME-NODE-REF` |
| question | `neg-question-field` · `neg-question-ref` | `E-QUESTION-FIELD` · `E-QUESTION-REF` |
| 摘录与交叉引用 | `neg-excerpt-field` · `neg-sourceref` | `E-EXCERPT-FIELD` · `E-SOURCEREF` |

### 产物层

| fixture | 锁定什么 |
|---|---|
| `pack-ok` | **正例**。没有它，负例变红也说明不了问题 —— 可能整条链都在报错 |
| `pack-not-object` | 顶层不是 object（`E-PACK-TYPE`） |
| `pack-extra-key` / `pack-missing-key` | 多段 / 少段（`E-PACK-EXTRA-KEY` / `E-PACK-MISSING-KEY`） |
| `pack-meta-field` / `pack-meta-extra-key` | `meta` 不是对象 / 混进时间戳（`E-META-FIELD` / `E-META-EXTRA-KEY`） |
| `pack-meta-version-mismatch` / `pack-meta-version-format` | 版本与源不一致 / 非三段 semver（`E-META-VERSION`） |

### 错误码覆盖自检

`--suite` 最后一步把 `validator.py` 里**定义的全部错误码**与 fixtures 断言过的码对账，缺任何一条即失败：

```
— 错误码覆盖 —
错误码覆盖：37/37
```

两个方向都查：**定义了没断言** = 那条规则从没被执行过；**断言了没定义** = `expect.json` 里写了 typo，永远不可能满足。

> 这条自检才是 `R-07` 的根治。补 23 个 fixture 只解决了当下；自检保证「以后新增规则忘配负例」会立刻红。

### 负例的用法

负例的价值在于**它们会红**。改宽任何一条判据时，先跑 `--suite`，红的那格就是被你改宽的规则；若不想让它红，得先说明为什么那条裁定不再成立。

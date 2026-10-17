# content/tools

源数据（`content/<空间>/`）→ 构建产物（`dist/pack.json`）的管线。**纯标准库，无第三方依赖**。

```bash
python content/tools/build.py                      # 构建全部空间
python content/tools/build.py python               # 只构建 content/python/
python content/tools/build.py --root <目录> --out <文件>   # 构建任意目录（fixtures / 临时）
python content/tools/build.py --root <目录> --check       # 确定性检查，不落盘
python content/tools/verify.py --root <目录>        # 只校验源数据
python content/tools/verify.py --pack <pack.json>   # 校验已构建的产出
python content/tools/verify.py --suite              # 跑 fixtures 回归
```

## 三个文件

| 文件 | 职责 |
|---|---|
| `validator.py` | 所有判据。只读、不改写数据，一次报全部问题 |
| `build.py` | 拼 `meta` 信封、固定序列化、原子落盘、确定性检查 |
| `verify.py` | 独立校验 + fixtures 回归 |

`build.py` 与 `verify.py` 共用 `validator.py`：构建前先校验，校验不过不落盘 —— 避免 `dist/` 里躺着半合规的包。

## 取值域

⚠️ 下表分两类，**不要混**：

- **[SPEC]** —— `docs/` 里已明文枚举的取值
- **[impl]** —— SPEC 只说「有限类型集合」或根本没列字段，此处是**首期实现层补齐**，尚未经维护者确认。要改，先改 `docs/`，再改这里

| 字段 | 取值 | 来源 |
|---|---|---|
| `sixAxis` 键 | `subject` 学科 · `role` 岗位 · `industry` 行业 · `ability` 能力 · `topic` 主题 · `stack` 技术栈 | 轴名 [SPEC]（`SPEC-FND-002`），英文键名 [impl] |
| `requirements` 键 | `boundary` 边界 · `justification` 证成 · `proposition` 命题 · `relation` 关联 · `how` How · `tacit` Tacit | 要件名 [SPEC]（`SPEC-FND-004`），英文键名 [impl] |
| `requirements` 值 | `present` / `missing` / `not_externalizable` | [SPEC]（`SPEC-PACK-009`） |
| `layer` | `persistent` 持久 · `view` 视图 · `ephemeral` 快消 | 中文值 [SPEC]（`SPEC-FND-003`），英文键名 [impl] |
| `type` | `declarative` 陈述 · `procedural` 程序 · `skill` 技能 · `tacit` 默会 | [impl] |
| `Edge.type` | `strong` 强依赖（实线）· `weak` 弱依赖（虚线）· `unknown` 指向未知 | 语义 [SPEC]（`channel-table` 第 6 通道），三个字面量 [impl] |
| `authorityLevel` | `L0` / `L1` / `L2` / `L4`（无 `L3`） | [SPEC]（`entity-fields` §4 §5） |
| `questions[]` 字段 | `id` · `itemId` · `prompt` · `answer` | [impl] —— `entity-fields.md` 不含题实体，`SPEC-PACK-005` 只给了语义 |
| `excerpts[]` 形态 | `SourceRef[]`（`id` / `name` / `authorityLevel` / `version` / `segments[]` / `appliesTo`） | [SPEC]（`entity-fields` §5） |

`unknown` 边是唯一允许 `to` 指向不存在项的形态 —— 这是「指向未知」的显式声明；其余边指向不存在的项一律 `E-EDGE-REF`。

## 序列化约定

`sort_keys=True` · `indent=2` · `ensure_ascii=False` · 分隔符 `(",", ": ")` · 末尾单换行。

这五项是 `SPEC-PACK-005`「`meta` 不含构建时间戳」的**唯一实现**。换任何一项，同一 commit 的两次构建就会 byte 不等，而 `dist/` 不入库、tag 是产物唯一指针 —— 事后无从比对。

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

`fixtures/` 下每个目录是一份可回归的源数据。`expect.json` 声明期望：

```json
{
  "base": "valid-min",
  "exit": 1,
  "codes": ["E-CYCLE"],
  "scheme": "scheme-official-tutorial",
  "inversions": 1,
  "note": "为什么需要这个 fixture"
}
```

- `base` —— 从哪个 fixture 继承完整源数据；本目录只写「被测规则相关的那个文件」。**必须显式写，不按目录名猜**
- `exit` —— 期望构建退出码（`0` 通过 / `1` 拒绝）
- `codes` —— 期望出现的 issue code（**不要求穷尽**，允许连带错误）
- `scheme` + `inversions` —— 断言派生值算得对

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

负例的价值在于**它们会红**。改宽任何一条判据时，先跑 `--suite`，红的那格就是被你改宽的规则；若不想让它红，得先说明为什么那条裁定不再成立。

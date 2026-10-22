# content

> 内容包源数据与构建管线：一个知识空间一个包，构建产物供客户端按空间加载。

## 本模块命令

在**仓库根**执行（脚本按自身位置定位 `content/`，与 cwd 无关；`--root` 是相对 cwd 的路径除外）：

```bash
python content/tools/build.py                   # 构建全部空间：content/<空间>/dist/pack.json
python content/tools/build.py <空间>             # 只构建单个空间
python content/tools/build.py <空间> --check     # 确定性检查：两遍构建 + 换环境复跑，比 sha256
python content/tools/verify.py --root <目录>     # 只校验源数据，不落盘
python content/tools/verify.py --suite          # 跑 fixtures 回归
```

管线细节、取值域与 issue code 见 [tools/README.md](tools/README.md)。

## 目录形态

```
content/
├── tools/                构建与校验（纯标准库，无第三方依赖）
└── <空间>/                一个知识空间一个目录（如 python/、english/、german/）
    ├── manifest.json      空间声明：id / 名称 / version / 六轴取值 / accent / order
    ├── items.json         知识项：稳定 id、标题、六要件三态、六轴取值、layer
    ├── edges.json         前提边（有限类型）
    ├── schemes.json       体系（⪯ 的线性扩展）
    ├── questions.json     声明式题库
    ├── excerpts.json      源摘录（SourceRef[]，离线可读，带出处与许可标记）
    └── dist/pack.json     构建产物（不入库）
```

> `manifest.json` 的 `version` 是包版本的**唯一事实源**（semver）。`build.py` **原样透传**到 `dist/pack.json` 的 `meta.version`，不得改写 —— 否则同一 commit 两次构建产出不同版本，而 `dist/` 不入库、tag 是唯一指针，无从比对。tag `pack/<space>/vX.Y.Z` 须与它**逐字一致**。口径见 [git-conventions §五](../docs/guides/git-conventions.md)。

> `content/python/` 是**第一个真实空间**（α 参考包：150 项 · 170 条边 · 10 域），`B2` 起作为定位引擎与投影帧预算的输入。`tools/fixtures/` 下的示例源数据仍在，用 `python content/tools/build.py --root content/tools/fixtures/valid-min` 可单独验证管线本身。
>
> `content/english/` 与 `content/german/` 是 `B3` 收尾后新增的两个空间（各 80 项 · 84 条边 · 8 域 · 24 题），**除内容外未改一行核心代码** —— 它们是「零核心代码接入新空间」这条铁律的实证面，也让多根视图与跨空间换根第一次能在终端上验到（此前只有 python 一个根，凑不出第二个）。两包的 `excerpts` 一度为**空数组**（源摘录须逐条可核验并带许可标记，不代写），`B4-R` 已**逐条回填**：每包 3 条源、`sourceRefs` 按域回填，覆盖见下。
>
> **两包的源与覆盖（`B4-R` 回填，2026-10-19）**：`excerpts` 每条 `segments` 都是**逐字短引**，`locator` 给章节名 + 可定位 URL，`license` 按源标（`proprietary-excerpt` / `CC-BY-SA-4.0`）——「可核验」指**回到该 URL 能读到原句**，不是转述。
>
> | 空间 | 源 | 等级 | 覆盖（全量体系 / 首周体系） |
> |---|---|---|---|
> | english | `english-cambridge-grammar`（Cambridge Dictionary · British Grammar） | `L1`（官方语法参考） | 50 / 15 |
> | english | `english-elt-grammar`（Grammar for English Language Teachers） | `L2`（学术出版） | 10 / 3 |
> | english | `english-wikipedia-grammar`（Wikipedia · English grammar） | `L2` | 30 / 9 |
> | german | `german-duden-grammatik`（Duden – Die Grammatik） | `L1`（权威辞书） | 40 / 12 |
> | german | `german-dw-grammatik`（Deutsche Welle · Deutsch lernen） | `L2`（开放课程） | 30 / 9 |
> | german | `german-wikipedia-grammar`（Wikipedia · German grammar） | `L2` | 20 / 6 |
>
> ⚠️ **三个判据记在这里，避免下次回填重犯**：
> ① **每条源都必须有覆盖**。覆盖 = `Item.sourceRefs` ∩ 体系节点 —— 覆盖 0 的源在已选体系时会被 `_sources()` 筛掉（`PLAN-014` 的双向收窄），写进包也选不到。
> ② **`sourceRefs` 是必填键**，客户端 `Item.fromJson` 省略即抛、`bundleFromPack` 再静默丢掉整个空间 —— 空数组 ≠ 免写。
> ③ **百科源标 `L2` 属实现补的裁定**：`knowledge-system-learning-methodology.md` §4 的 L4 是「社区聚合与索引」，把协作百科归进去会造成「源本身不可作结论来源」的自相矛盾，故按「开放课程/参考资料」记 `L2`。此条**待评审**。

## 相关文档

- 包格式与边界判据：[../docs/specs/PACK-content-pack.md](../docs/specs/PACK-content-pack.md)
- 实体字段与事件类型：[../docs/specs/entity-fields.md](../docs/specs/entity-fields.md) · [../docs/specs/event-types.md](../docs/specs/event-types.md)
- 实现约定与边界：见 [AGENTS.md](AGENTS.md)；规则细则以 `docs/` 为准（**不复制**）

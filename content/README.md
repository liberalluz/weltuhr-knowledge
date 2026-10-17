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
└── <空间>/                一个知识空间一个目录（如 python/、english/）
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

## 相关文档

- 包格式与边界判据：[../docs/design/PACK-content-pack.md](../docs/design/PACK-content-pack.md)
- 实体字段与事件类型：[../docs/reference/entity-fields.md](../docs/reference/entity-fields.md) · [../docs/reference/event-types.md](../docs/reference/event-types.md)
- 实现约定与边界：见 [AGENTS.md](AGENTS.md)；规则细则以 `docs/` 为准（**不复制**）

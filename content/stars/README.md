# stars —— 星空源数据

> **规格权威**：[`docs/decisions/0006-3d-rendering-stack-and-visual-style.md`](../../docs/decisions/0006-3d-rendering-stack-and-visual-style.md)（决策 4「天球贴图是构建产物」、决策表「背景」那一行，以及修订七）。本文件只记**来源、条数与字段口径**，不复述判据。

## 目录

```
stars/
└── source/
    └── heasarc_hipparcos.tdat.gz    Hipparcos Main Catalog（HEASARC 转制版，raw，原样入库）
```

**只有 `source/`，没有抽取结果** —— 与 `skeleton/` 不同：骨架的官方原件是 PDF，必须先抽成 JSON 才能用；星表本身是文本表，解析放在客户端启动时（`app/lib/spike/star_catalog.dart`），所以这里不需要中间产物。

## 来源

| 目录 | 版本 | 发布 | 载体与直链 | 压缩 / 解压 | sha256（前 16 位） |
|---|---|---|---|---|---|
| `I/239` Hipparcos Main Catalog | 1997（ESA 发布），本文件为 HEASARC 2022-02-05 转制 | ESA · 1997 · 转制 NASA/GSFC | gzip：[heasarc.gsfc.nasa.gov](https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_hipparcos.tdat.gz) · 取于 2026-10-31 | 14,808,803 B / 41,793,294 B | `e0e1e94344ada001` |

⚠️ **这份不是 CDS 的原始 ASCII**。Hipparcos 的原始发布方是 CDS（`I/239/hip_main.dat`，定宽文本），HEASARC 把它转成了自己的 `.tdat` 形态（`<HEADER>` + `|` 分隔的行）。取数当时：

- `cdsarc.cds.unistra.fr` 与 `cdsarc.u-strasbg.fr` 的 **http 与 https 全部连接超时**（2026-10-31 实测）
- VizieR 的哈佛镜像 `vizier.cfa.harvard.edu` 只做 **302 跳回 CDS**，等于不通
- 哈佛 `tdc-www.harvard.edu/catalogs/` 有 `bsc5.dat.gz`，但**没有** Hipparcos（`hip_main.dat.gz` 返回 404）

所以入库的是 HEASARC 原样分发的整表，一个字节没改。「原文入库」这条纪律仍然成立 —— 入库的是**分发源的原样文件**，不是我们加工出来的子集；变的只是「谁转制的」这一层。

**许可**：Hipparcos 数据由 ESA 发布，使用时须注明来源（ESA 1997, The Hipparcos and Tycho Catalogues, ESA SP-1200）。本文库经 NASA/GSFC HEASARC 分发，属美国政府数据服务；转制版的字段定义见 [heasarc_hipparcos 表文档](https://heasarc.gsfc.nasa.gov/W3Browse/star-catalog/hipparcos.html)。**与上一版 `V/50` 的「公有领域」不同**，这份要署名。

## 条数

| 项 | 数 | 说明 |
|---|---|---|
| 表头声明 | **118,218** | `<HEADER>` 的 `TOTAL ROWS` |
| 数据行 | **118,218** | 实测，与声明一致（`<END>` 标记不计）；两条不等时解析器**抛错**，不静默照收 |
| 有 `vmag` 的记录 | **118,217** | 客户端可渲染的部分 |
| 缺 `vmag` 的记录 | **1** | 没有星等就画不出亮度，整条跳过 |

`118,218 − 1 = 118,217` 这个差额是**数据本身的性质**，不是解析缺陷。解析器把它单独计数（`StarCatalog.skipped`），用例 `TC-SPIKE-007` 钉的就是这两个数。

## 字段口径（客户端实际用到的六项）

表头里共 **80 个字段**，每行 `|` 分隔、顺序即表头 `field[...]` 的声明顺序。客户端按**字段名反查列号**，不硬编码位置 —— HEASARC 改版加列时，硬编码会静默错位，而错位的症状是「解析成功、所有星整体偏移」。

| 字段 | 列（1 起） | 格式 | 用途 |
|---|---|---|---|
| `hip_number` | 6 | 整数 | 恒星身份，用例靠它锚定 |
| `ra` | 2 | `float8`，**度**，J2000 | 贴图横向位置 |
| `dec` | 3 | `float8`，度，J2000 | 贴图纵向位置 |
| `vmag` | 8 | `float8`，`F5.2` | 光斑大小与亮度 |
| `bv_color` | 39 | `float8`，`F6.3` | 颜色（billboard 用） |
| `spect_type` | 78 | 文本 | 色指数缺失时兜底判色 |

⚠️ **表里有两组坐标**：`ra_deg` / `dec_deg`（第 11–12 列）是 **J1991.25 历元**，`ra` / `dec`（第 2–3 列）才是 **J2000**。只用后者。取错那组不会报错，只会让所有星整体偏掉一个世纪的分点 —— 画面上完全看不出来。

⚠️ **赤经单位是度不是小时**：上一版 `V/50` 给的是 `HHMMSS.s`，这一版直接给 0–360 的度数。换算逻辑跟着改了（`StarRecord.raDeg`），别按旧习惯乘 15。

⚠️ **数据按赤纬排序**，不是按 HIP 号 —— 第一行在南天极附近（`HIP 48752`，dec −89.78），最后一行在北极附近。翻文件时别以为顺序乱了。

## 为什么原文入库

与 `content/skeleton/source/` 存教育部 PDF 原件同一口径：**源数据入库、烘焙产物不入库**。天球贴图与星点光斑都在运行期画（`app/lib/spike/sky_image.dart`、`star_sprite.dart`），仓里没有可入库的图片。

这样做的直接好处是**构建可重复**：不需要每次构建都联网取数，CI 也不会因为外网抖动而红。

## 与上一版（`V/50`）的关系

段 2 用的是 Yale 亮星星表 `V/50`（9,096 颗，上限 7.96 等）。它是一份**亮星表**、6.5 等以下就不全，画面上是疏星点点；决策表「背景」那一行本来写的是「9,110 颗 + **程序化补到 2 万**」，补的那一半要编造位置。

段 3 换成 Hipparcos 全量后，**一颗都不用编**：可取到 9.5 等、118,217 颗，全部落在真实位置上。旧的 `bsc5.dat.gz` 已随同一笔删除 —— 星源只留一份，下一个读仓的人不必猜两份数据是什么关系。

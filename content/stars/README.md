# stars —— 星空源数据

> **规格权威**：[`docs/decisions/0006-3d-rendering-stack-and-visual-style.md`](../../docs/decisions/0006-3d-rendering-stack-and-visual-style.md)（决策 4「天球贴图是构建产物」、决策表「背景」那一行）。本文件只记**来源、条数与字段口径**，不复述判据。

## 目录

```
stars/
└── source/
    └── bsc5.dat.gz                  Bright Star Catalogue, 5th Revised Ed.（raw，原样入库）
```

**只有 `source/`，没有抽取结果** —— 与 `skeleton/` 不同：骨架的官方原件是 PDF，必须先抽成 JSON 才能用；星表本身就是定宽文本，解析放在客户端启动时（`app/lib/spike/star_catalog.dart`），所以这里不需要中间产物。

## 来源

| 目录 | 版本 | 发布 | 载体与直链 | 压缩 / 解压 | sha256（前 16 位） |
|---|---|---|---|---|---|
| `V/50` Bright Star Catalogue | 5th Revised Ed.（Preliminary Version）· Hoffleit & Warren Jr., 1991 | ADC / NSSDC · 1991-06-28 | gzip：[tdc-www.harvard.edu](http://tdc-www.harvard.edu/catalogs/bsc5.dat.gz) · 取于 2026-10-31 | 590,228 B / 1,704,879 B | `0471ced07fc241e6` |

- **公有领域**：`V/50` 是天文数据中心（ADC）发布的机器可读版本，无版权限制。格式说明与字段表在同站的 [`bsc5.readme`](http://tdc-www.harvard.edu/catalogs/bsc5.readme)。
- 另一常见镜像 `cdsarc.cds.unistra.fr/ftp/V/50/catalog.gz` 在取数时**连接超时**（2026-10-31 实测），故采哈佛镜像。
- 变体关系：`cdsarc` 的 `catalog.gz` 是同一份 `V/50` 的另一种打包，字段一致。

## 条数

| 项 | 数 | 说明 |
|---|---|---|
| 对象总数 | **9,110** | HR 号 1–9,110，编号连续 |
| 有坐标的恒星 | **9,096** | 客户端可渲染的部分 |
| 无坐标对象 | **14** | 1908 年初版即保留编号的客星与河外星系，正文数据基本为空 |

`9,110 − 14 = 9,096` 这个差额是**数据本身的性质**，不是解析缺陷。解析器把它单独计数（`StarCatalog.skipped`）而不是静默丢弃，用例 `TC-SPIKE-007` 钉的就是这两个数。

## 字段口径（客户端实际用到的四项）

列区间 1 起、闭区间，照 `bsc5.readme` 的字节表：

| 字段 | 列 | 格式 | 用途 |
|---|---|---|---|
| `HR` | 1–4 | 整数 | 恒星身份，用例靠它锚定 |
| 赤经 J2000 | 76–83 | `HHMMSS.s` | 贴图横向位置 |
| 赤纬 J2000 | 84–90 | `±DDMMSS` | 贴图纵向位置 |
| 视星等 | 103–107 | `F5.2` | 光斑大小与亮度 |
| `B−V` | 110–114 | `F5.2` | 颜色 |

⚠️ **表里有两组坐标**：`B1900`（61–75 列）与 `J2000`（76–90 列），**只用 J2000**。取错那组不会报错，只会让所有星整体偏移约一个世纪的分点 —— 画面上完全看不出来。

⚠️ **赤经不在前列**：第 61 列之前依次是 `HR` / `Name` / `DM` / `HD` / `SAO` / `FK5` / `IRflag` / `Multiple` / `ADS` / `VarID` 十段，按「常识位置」切列必然切错。

## 为什么原文入库

与 `content/skeleton/source/` 存教育部 PDF 原件同一口径：**源数据入库、烘焙产物不入库**。天球贴图与星点光斑都在运行期画（`app/lib/spike/sky_image.dart`、`star_sprite.dart`），仓里没有可入库的图片。

这样做的直接好处是**构建可重复**：不需要每次构建都联网取数，CI 也不会因为外网抖动而红。

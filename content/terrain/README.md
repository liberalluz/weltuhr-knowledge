# content/terrain —— 地形包

跨轴先修边的**唯一**落点。`ADR-0005` 决策 4：先修边（A 是 B 的前置）不在任何
官方编目里，且**跨轴**（学一门语言 ↔ 某个职业能力），因此独立成第四类包，
与载荷包同级、各自版本。

## 两种文件，一种入库

| 文件 | 入库 | 说明 |
|---|---|---|
| `terrain.json` | **是** | 源数据：清单字段 + `edges[]`。人写这里 |
| `pack.json` | 否（`.gitignore:33`） | 产物。`assemble_terrain.py` 生成，客户端 `readPack` 读它 |

源文件**不叫** `manifest.json` 是有意的：`build.py` 与 `assemble_pack.py` 都按
「目录内含 `manifest.json`」发现空间，用那个名字会被它们当成载荷空间去装配，
然后在「缺 `items.json`」上失败。名字不同，三个装配器各装自己那一类包，
互不误伤。

## 装配

```bash
python content/tools/assemble_terrain.py          # 产出 content/terrain/pack.json
python content/tools/assemble_terrain.py --check  # 只校验，不落盘
```

**顺序有依赖**：它要读 `content/python/pack.json` 与 `content/skeleton/pack.json`
反查端点节点的轴。这两个没装配就报错，让人先跑 —— 猜一个轴只会把错误藏起来。
CI 里因此排在 `assemble_pack.py`、`assemble_skeleton.py` 之后。

## 源数据形态

```jsonc
{
  "id": "terrain",
  "name": "地形：跨轴先修边",
  "version": "0.1.0",
  "skeleton_requires": ">=1.0.0",
  "axes": ["major", "occupation"],          // 本包涉及哪几条轴（清单字段，必填）
  "deps": [{ "plugin_id": "python", "range": ">=0.1.0" }],
  "edges": [
    {
      "from_id": "python:cc-choose-model",   // 前置 → 后继，两端可以是不同包
      "to_id": "skeleton:occupation/2-02-10-03",
      "strength": "recommended",             // required / recommended
      "rationale": "……"                      // 只进源，不进产物
    }
  ]
}
```

`rationale` 是**给下一读者的**：为什么这一对端点构成先修、为什么是这个强度。
它不进 `pack.json`（`PrerequisiteEdge` 只有三个字段），所以改了它不会动产物。

## 两处不手填

`pack.json` 里的 `terrain.edge_counts` 与 `terrain.axes_covered` 都由装配器现算：

- `edge_counts` 实扫 `edges[]` 两类强度。手填的后果是「摘要说 3 条、图里 2 条」，
  而 `⪯` 走的是 `edges[]`，用户看到的建议顺序和摘要对不上，查起来还得先怀疑渲染。
- `axes_covered` 按端点 id 的包前缀去已装配的 `pack.json` 查节点 `axis`，去重。
  手填 `["major"]` 也能过 `_checkTerrainAxes`（它只查子集关系），但摘要会说这个包
  只跨一条轴，而它的边明明跨了两条。

## 加一条边要同时做什么

1. 两端节点必须**已经存在**于各自包的 `nodes[]`（装配器会查，不存在直接拒）。
2. 若跨到了新轴 ⇒ `axes[]` 一起加。装配器会拦「边跨了声明里没有的轴」。
3. `deps[]` 加上端点所属包 —— 没有它，terrain 可能先于那个包装上，边就悬空。

## 首条边的选择理由

`python:cc-choose-model`（线程 / 进程 / 协程选型）→ `skeleton:occupation/2-02-10-03`
（计算机软件工程技术人员），`recommended`。

- **跨轴是真的**：前者在学科轴（`major`），后者在角色轴（`occupation`）。
- **强度取 `recommended` 是诚实的**：不会并发选型也能做软件工程 —— 大量岗位在既有
  框架内做事。标 `required` 等于断言「不会它就当不了」，不成立。代价是这条边不进
  `⪯`（`requiredEdgesOf` 只收 `required`），所以真实数据上暂时没有跨包必学链的样品；
  那个由 `TC-FND-021` 的合成夹具覆盖。
- **两端都不取包根**：指向 `python:python` 也能成立，但那是「整个包指向一个岗」，
  读不出一条边自己的意思。

## 已知边界

- **跨包环由装载层判，不由本装配器判**。装配器只装一个包，看不见别的包之间的环；
  装载层在装 `terrain` 包之前把本包与已装包的先修边合成一张图再判（`B15` 笔 3）。
- **`axes_covered` 不校验「实际跨了哪几条轴」**（那要有全套已装包才能算），
  只校验「现算结果 ⊆ 声明」。声明漏了由装配器拦，声明多了不拦。

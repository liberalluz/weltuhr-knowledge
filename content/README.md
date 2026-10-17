# content

> 内容包源数据与构建管线：一个知识空间一个包，构建产物供客户端按空间加载。

## 本模块命令

```bash
python tools/build.py            # 构建全部空间：content/<空间>/dist/pack.json
python tools/build.py <空间>      # 只构建单个空间
```

## 目录形态

```
content/
├── tools/build.py        构建脚本（源数据 → dist/pack.json）
└── <空间>/                一个知识空间一个目录（如 python/、english/）
    ├── manifest.json      空间声明：id / 名称 / 六轴取值 / accent / order
    ├── items.json         知识项：稳定 id、标题、六要件三态、六轴取值、layer
    ├── edges.json         前提边（有限类型）
    ├── schemes.json       体系（⪯ 的线性扩展）
    ├── questions.json     声明式题库
    ├── excerpts/          源摘录（离线可读，带出处与许可标记）
    └── dist/pack.json     构建产物（不入库）
```

## 相关文档

- 包格式与边界判据：[../docs/design/PACK-content-pack.md](../docs/design/PACK-content-pack.md)
- 实体字段与事件类型：[../docs/reference/entity-fields.md](../docs/reference/entity-fields.md) · [../docs/reference/event-types.md](../docs/reference/event-types.md)
- 实现约定与边界：见 [AGENTS.md](AGENTS.md)；规则细则以 `docs/` 为准（**不复制**）

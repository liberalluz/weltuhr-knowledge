# Weltuhr

> 一句话定位：把一个学习领域展开成**可定位、可规划、可量化**的知识空间，让「我要学 X」变成「我知道该按什么顺序学什么、学到什么程度算能用」。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

## 特性要点

- **知识空间**：以内容包（pack）为边界组织知识，一空间一包；空间边界由三条判据裁定，而非人为分层
- **坐标而非目录**：六轴（学科 / 岗位 / 行业 / 能力 / 主题 / 技术栈）× 三层（持久 / 视图 / 快消）是**索引坐标**，可叠加筛选，不是嵌套文件夹
- **三维宇宙 + 二维树 + 详情**：同一份图模型的三种投影；位置本身承载语义（`r` / `θ` / `φ`），不使用 3D 力导向布局
- **规划三段**：源（材料）→ 体系（顺序）→ 方法（动作 + 判据），三段均可自建，候选按各自依据排序并显示取舍代价
- **习得七步闭环**：定位 → 规划 → 修习 → 检验 → 保持 → 出口，复习走 FSRS，进度离散（永不倒退）与掌握连续（可回落）分离
- **两套笔记**：标准体系笔记（由体系派生）与自建笔记共用 `itemId` 锚点，可就地切换；单向导出到外部笔记软件

## 快速开始

> 前置：Flutter 3.x + Dart 3.x · Serverpod 4.x（版本以 `app/pubspec.yaml` / `server/pubspec.yaml` 钉定值为准）· PostgreSQL 16

```bash
git clone git@github.com:liberalluz/project-knowledge.git && cd project-knowledge

# 客户端依赖
cd app && flutter pub get

# 服务端依赖 + 起库
cd ../server && dart pub get

# 生成内容包产物（须先于运行客户端：客户端按运行期 CWD 查找 content/<空间>/dist/pack.json）
cd ../content && python tools/build.py

# 运行
cd ../app && flutter run -d windows
```

> ⚠️ **骨架阶段**：以上为约定命令，`app/` `server/` `content/` 的脚手架尚未生成，命令在代码落地后逐条验证。**不以「应该能跑」当「已跑通」。**

## 目录导航

| 目录 | 职责 |
|---|---|
| [app/](app/README.md) | Flutter 客户端（Windows / macOS / iOS 一套代码） |
| [server/](server/README.md) | Serverpod 服务端：同步、事件合并、治理与审核 |
| [content/](content/README.md) | 内容包源数据与构建管线 |
| [docs/](docs/README.md) | 交付文档、活文档、ADR 与设计规格 |
| [infra/](infra/README.md) | 构建 / 签名 / 更新器 / 镜像 / CI |

另：`knowledge-system-learning-methodology.md` —— 本项目的**方法论依据**（知识体系学习方法论），软件设计规格见 [docs/design/](docs/design/00-index.md)。

## 文档

- [docs/README.md](docs/README.md) —— 文档体系索引（交付物 / 活文档 / ADR）
- [docs/design/00-index.md](docs/design/00-index.md) —— **设计规格索引**（FND / VIEW / PACK / PLAN / STEP / QUANT / NOTE / GOV + 横切表）

## 许可与署名

Copyright (c) 2026 liberal。本项目以 [Apache-2.0](LICENSE) 许可发布，另见 [NOTICE](NOTICE)。

## 贡献与求助

- **安全漏洞**：请勿用公开 issue，按 [.github/SECURITY.md](.github/SECURITY.md) 的私密渠道报告（承诺 7 个工作日内首次回复）
- 问题与建议：经仓库 Issues 提交；内容勘误请注明空间标识与 `itemId`
- 贡献流程：`CONTRIBUTING.md` 暂缓落盘（分支 / 提交 / PR 规范先落 [docs/guides/git-conventions.md](docs/guides/git-conventions.md)），出现第二位贡献者时再补指针版

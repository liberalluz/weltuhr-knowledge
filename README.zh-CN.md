[English](README.md) · **简体中文** · [Deutsch](README.de.md) · [Italiano](README.it.md) · [日本語](README.ja.md) · [Français](README.fr.md)

> 以根 [README.md](README.md) @ d888a44 为准，本译文对应该版本。

# Weltuhr

> 把一个学习领域展开成**可定位、可规划、可量化**的知识空间，让「我要学 X」变成「我知道该按什么顺序学什么、学到什么程度算能用」。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

- **知识空间**：知识以内容包（pack）为边界组织，一空间一包；空间边界由三条判据裁定，而非人为划成层级
- **一张图，三种投影**：六轴（学科 / 岗位 / 行业 / 能力 / 主题 / 技术栈）× 三层（持久 / 视图 / 快消）构成**索引坐标**，可叠加筛选，不是嵌套文件夹；三维宇宙、二维树与详情面板是同一张图的三种投影 —— 位置本身承载语义（`r` / `θ` / `φ`），不使用 3D 力导向布局
- **规划三段**：源（材料）→ 体系（顺序）→ 方法（动作 + 判据）；三段均可自建，候选按各自依据排序，并显示取舍代价
- **习得七步闭环**：选源 → 选体系 → 选方法 → 修习 → 检验 → 保持 → 出口；复习走 FSRS。进度离散（永不倒退），与连续的掌握度（可回落）分离
- **两套笔记**：体系笔记（由体系派生）与自建笔记共用 `itemId` 锚点，可就地切换；导出到外部笔记软件为单向

## 快速开始

> 前置：Flutter 3.x + Dart 3.x · Serverpod 4.x（版本以 `app/pubspec.yaml` / `server/pubspec.yaml` 钉定值为准）· PostgreSQL 16

```bash
git clone git@github.com:liberalluz/weltuhr-knowledge.git && cd weltuhr-knowledge

# 启用仓库托管的钩子（提交信息格式校验）。
# 每个克隆做一次；不做的话同一条规则仍会在 CI 里跑，只是要推上去才知道。
git config core.hooksPath .githooks

# 客户端依赖
cd app && flutter pub get

# 服务端依赖 + 起库
cd ../server && dart pub get

# 生成内容包（产物不入库；客户端运行期按 CWD 探测 <候选根>/<包目录>/pack.json）
cd ../content && python tools/build.py

# 运行
cd ../app && flutter run -d windows
```

## 命令

| 命令 | 作用 |
|---|---|
| `cd app && flutter run -d windows` | 启动客户端 |
| `cd app && flutter test --reporter compact` | 跑客户端测试套件 |
| `python content/tools/assemble_pack.py` | 装配 `<空间>/pack.json` —— **客户端读的是这个** |
| `python content/tools/build.py` | 旧五段产物到 `<空间>/dist/`（迁移期保留，供 `verify.py` 的 fixture） |
| `python content/tools/verify.py --suite` | 按 schema 校验内容包 |
| `cd app && flutter analyze && dart run tool/lint/check.dart && dart run tool/docs/check.dart` | 静态检查：分析器、仓库 lint 规则、文档链接与一致性 |

> 本表必须与 CI 实际 gate 一致；工作流变更时，本表在同一 PR 内同步修改。

## 项目结构

| 目录 | 职责 |
|---|---|
| [app/](app/README.md) | Flutter 客户端（Windows / macOS / iOS 一套代码） |
| [server/](server/README.md) | Serverpod 服务端：同步、事件合并、治理与审核 |
| [content/](content/README.md) | 内容包源数据与构建管线 |
| [docs/](docs/README.md) | 工程文档 —— 放置规则见 [docs/README.md](docs/README.md) |
| [infra/](infra/README.md) | 构建 / 签名 / 更新器 / 镜像 / CI |

## 架构

三层：Flutter 客户端渲染同一图模型的三种投影（三维宇宙 / 二维树 / 详情）；Serverpod 服务端负责同步、事件合并、治理与审核；内容包是纯数据，由 `content/tools/` 编译成 `pack.json`。图模型、它的坐标与路径规则见[设计规格索引](docs/specs/00-index.md)。

每个设计决策与被否掉的替代方案：[docs/decisions/](docs/decisions/)。

## 文档

- 放置规则与知识域覆盖：[docs/README.md](docs/README.md)
- 规格与接口契约：[docs/specs/](docs/specs/00-index.md)
- 运维、环境准备与怎么跑起来：[docs/runbooks/](docs/runbooks/)
- 本项目的方法论依据：[docs/intent/knowledge-system-learning-methodology.md](docs/intent/knowledge-system-learning-methodology.md)

## 获取帮助

- 先看文档索引：[docs/README.md](docs/README.md)
- 东西坏了或起不来：[docs/runbooks/](docs/runbooks/)
- 问题与建议：仓库 Issues。内容勘误请注明空间标识与 `itemId`

## 贡献

分支命名、提交格式、Pull Request 与评审门槛见 [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md)。

维护者：liberal

## 安全

安全漏洞请按 [.github/SECURITY.md](.github/SECURITY.md) 描述的私密渠道报告，请勿为安全问题开公开 issue。

## 许可

Apache-2.0 —— 见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。

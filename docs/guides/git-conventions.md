# Git 规范

> 活文档，不设版号。分支 / 提交 / PR / 合并的唯一权威处。

## 一、分支

| 分支 | 用途 |
|---|---|
| `main` | 主干，**只经 PR 合入**。唯一例外：S0 首提 |
| `<type>/<topic>` | 特性分支，如 `feat/quick-locate` · `docs/design-spec` · `fix/hlc-clamp` |

命名：`<type>` 取提交类型（`feat` / `fix` / `docs` / `refactor` / `test` / `chore`），`<topic>` 小写连字符。

## 二、提交格式

```
<type>(<scope>): <subject>
```

**scope 取值集合固定为六个**，与顶层目录一一对应：

| scope | 管什么 |
|---|---|
| `app` | Flutter 客户端 |
| `server` | Serverpod 服务端 |
| `pack` | 内容源数据与构建管线（目录名 `content/`） |
| `docs` | 软件工程文档（含设计规格） |
| `infra` | 构建 / 签名 / 更新器 / CI |
| `repo` | 仓库级配置（`.gitignore` / 模板 / hook） |

**纪律**：

- **代码与文档分开提交**，不混提。
- subject 用祈使句、不加句号、≤ 72 字符。
- 一次提交只做一件事；重构与行为变更不混在一个提交里。
- 落痕：合入后在 PR 标题保留 `(#PR号)`。

## 三、PR

| 项 | 规则 |
|---|---|
| 粒度 | **1 里程碑 = 1 PR**；小改动可独立成 PR |
| 正文必含 | 变更摘要 · 影响面 · **自验证证据**（跑过的命令与结果） |
| 合并方式 | **默认 squash**；需保留提交级历史时用 merge commit；**不用 rebase** |
| 合后 | 删除源分支 + `git fetch --prune origin` |

**自验证证据不得自证**：不写「应该能跑」，写实际执行的命令与输出。「代码里实现了」不构成证据。

## 四、变更分级

| 级 | 判据 | 动作 |
|---|---|---|
| **A** | 改地基判据（六轴 / `⪯` / 事件模型 / 通道表 / 协议） | 先出 ADR，评审后改 |
| **B** | 改常量数值、事件类型、字段可空性 | PR + 变更说明 + 回填横切表 |
| **C** | 措辞、注释、例子 | 直接改 |
| **D** | 与 NOT 清单冲突 | **不做**，除非推翻 NOT 条目并留痕 |

## 五、提交前的自检

```bash
dart format .        # 或 flutter format
dart analyze         # 零 issue
dart test            # 或 flutter test
git add -A --dry-run # 确认无意外文件（不用 check-ignore 查目录，它对目录误报）
```

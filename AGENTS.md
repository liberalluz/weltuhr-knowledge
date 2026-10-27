# weltuhr-knowledge — agent 入口

本文件是**入口与地图**；规则细则在 `.github/` 与 `docs/`，这里不复制正文。

## 开始前，按顺序读

1. [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md)：治理、评审、合并入口
2. [`docs/specs/git-conventions.md`](docs/specs/git-conventions.md) §3–§4：提交、PR、合并判据
3. 当前模块的 `AGENTS.md`（`app/` · `server/` · `content/` · `infra/` · `docs/`）
4. 批次流程加载 [`.agents/skills/batch/SKILL.md`](.agents/skills/batch/SKILL.md)

## 不可协商

- **一个批次一个 PR**；不把两个目标塞进同一张卡。
- **非平凡改动先走批次**：`plan → approve → start`，再实现。
- **没有 `.batch/active` 不得推非 main 分支**；`pre-push` 会拒绝，不是提示。
- **不直推 `main`**，不直接 `gh pr merge`；合并只走 `batch merge`。
- **作者不能自批**；C10 ruleset 要求 1 名非作者批准 + code-owner review。
- **evidence 必须来自真实命令**；没跑的写“未验”，不能写“应该通过”。
- 不确定就停下问；不要为了过门禁改 card/scope/evidence。

## 开始一个批次

```bash
python3 infra/tool/batch/batch.py status
python3 infra/tool/batch/batch.py plan <id> --type <process|feat> --goal "..." --allowed "<glob>"
python3 infra/tool/batch/batch.py approve <id> --yes
python3 infra/tool/batch/batch.py start <id>
python3 infra/tool/batch/batch.py check --batch <id> --base main
python3 infra/tool/batch/batch.py pr --batch <id> --base main
```

合并必须由另一名维护者批准，再由人类明确说“合”，执行：

```bash
python3 infra/tool/batch/batch.py merge --pr <n> --yes
```

## 目录地图

- `app/`：Flutter 客户端
- `server/`：Serverpod 服务端
- `content/`：内容包与内容管线
- `infra/`：CI、构建、batch / metrics / verify 工具
- `docs/`：规格、决策、运行手册
- `.agents/rules/`：always-on 编辑与平台约束
- `.agents/skills/`：按需加载的流程技能

## 冲突时

- 领域事实以 `docs/specs/` 为准；
- 流程以 `CONTRIBUTING` + batch 工具为准；
- 模块 `AGENTS.md` 比根文件更具体，但不能违反上面的“不可协商”；
- 机器门禁（pre-push / ruleset / CI）优先于任何提示文本。

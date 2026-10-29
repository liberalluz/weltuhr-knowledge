# infra —— agent 入口

本目录的**约定、边界与常用命令**。规则细则以项目 `docs/` 为准，**本文件不复制**。

## 路径基准

本文件内所有相对路径**以本目录（`infra/`）为准**。

## 职责边界

- **负责**：三端构建与签名 · 制品打包与分发 · 更新器 · 镜像变量 · CI 流水线定义 · 部署编排（容器化交付）
- **不负责**：业务代码（→ `app/` / `server/`）· 内容数据本身（→ `content/`）· 交付文档正文（→ `docs/`）

## 关键命令

| 用途 | 命令 |
|---|---|
| 环境自检 | `./scripts/check-env.sh`（待实现） |
| 三端构建 | `./scripts/build-all.sh`（待实现） |
| 合并闸门（只检查） | `python3 tool/batch/merge.py --pr <n> --dry-run` |
| 合并（人工确认后） | `python3 tool/batch/batch.py merge --pr <n> --yes` |
| 范围守门 | `python3 tool/batch/check.py --scope .batch/<id>/scope.json` |
| batch 状态 | `python3 tool/batch/batch.py status` |
| 批次卡 | `plan --auto-id`（多 agent）或 `plan <id>`，然后 `approve <id> --chat --confirm <hash8>` |
| 启动 | `start <id>`；仅 active PR 已合并且无 `merge.json` 时用 `start <id> --clear-stale` |
| 批次检查 | `python3 tool/batch/batch.py check --batch <id>` |
| 批次 PR | `pr --prepare` → 手写 `.batch/<id>/pr-body.md` → `pr --create --body-file ... --confirm <body-hash8>` |
| 批次合并 | `python3 tool/batch/batch.py merge --pr <n> --yes` |
| docs 审计 | `python3 tool/docs/audit.py all --root ..` |
| 技能 lint | `python3 -B tool/batch/skill_lint.py` |
| PR 周报 | `python3 tool/metrics/pr_metrics.py --since <YYYY-MM-DD>` |
| 只读验收 | `python3 tool/verify/verify.py --batch <id>` |

## batch 边界

- 同一时刻只有一个 `.batch/active`；不要手工覆盖别的 agent 的 active。
- PR 正文的 `- 批次号：` 必须与 card、分支后缀一致；本地 create 与 CI 都会校验。
- 正常合并只走 `batch merge`；直接 `gh pr merge` 不会写 `merge.json`，会留下 stale active。

## batch 新规则

- `plan` 必带：`--docs-impact none|living|controlled`、`--profile code|living|controlled|release`、逐文件 `--note`；可选 `--milestone` / `--issue` / `--related-pr`。
- `size_budget` 默认 400 行，`check` / `pr` 超预算直接失败；先拆批次。
- `feat` / `fix` 必须有 `changelog.d/<批次号>.md`；`process` 不需要。
- PR 八类关联由 `infra/tool/batch/relations.py` 生成并在 create 前预检；细则见根 `AGENTS.md` 与 `docs/specs/git-conventions.md` §4.1。

## 红线

- **制品层归用户终端执行**：`flutter build` 三端、签名打包、真机验收不在自动化沙箱内完成；沙箱只跑 analyze / format / test / 内容构建。
- **版本钉死**：Serverpod 与关键工具链版本写死，不用 `^` 区间；版本变更须走变更控制并留痕。
- **密钥不入库**：签名材料、密码、令牌一律环境变量注入；`config/passwords.yaml` 已在 `.gitignore` 中。
- **交付容器化**：服务端交付形态为容器（见 ADR），迁移脚本含 `CREATE EXTENSION` 时须先验基础镜像能力。
- **不得自证**：「构建通过」须有制品与校验和，不以本地编译成功替代三端制品验证。

---
name: batch
description: 批次生命周期导航：plan、approve、start、check、pr、merge 的顺序与边界。
whenToUse: 开始一个新批次、恢复中断的批次、或不知道该跑 batch 的哪一步时。
metadata:
  owner: liberal
---

# batch

## Owner

- Owner: `liberal`
- 适用批次：任何 `type`；流程文件改动使用 `process` 批次。

## 何时用

- 新批次开始，先建卡与 scope；
- 会话中断后恢复 `.batch/<id>`；
- 到 check / pr / merge 节点；
- 不确定下一步该跑哪条命令。

## 顺序

| 阶段 | 命令 | 产物 |
|---|---|---|
| 起草 | `batch.py plan <id> --type ...` | `card.yaml` 草稿 |
| 人审 | `batch.py approve <id> --chat --confirm <hash8>` | `approval.hash` + `via=chat` |
| 启动 | `batch.py start <id>` | branch / `state.json` / `scope.json` / `active` |
| 检查 | `batch.py check --batch <id>` | `evidence.log` |
| 开 PR | `batch.py pr --batch <id>` | `pr-body.md` + `gh pr create` |
| 合并 | `batch.py merge --pr <n> --yes` | `merge.json` |

## 边界

- 一个批次一个 PR；不把两个目标塞进同一张卡。
- `approve` 必须由用户确认：agent 先用 `ask_user_question` 展示 card 与 hash 前 8 位，用户选择 Approve 后才执行 `--chat --confirm <hash8>`；不得自批。
- `approve` 后改 `card.yaml` 会让 hash 失效，必须重新批准。
- 没有 `RESULT: PASS` 的 evidence 不进 `pr`，没有人工“合”不执行 `merge`。
- 不直接 `gh pr merge`；合并只走 `batch merge` / `merge.py`。
- `.batch/` 是本地状态，不进仓库。
- 多 agent 用 `plan --auto-id` 生成 `YYYYMMDD-<6位十六进制>`；同一时刻只允许一个 `.batch/active`。
- `start` 发现 active 属于别的批次会拒绝；不要手工覆盖，先结束当前批次。
- `start` 还会拒绝已存在的远端同名分支；跨 clone 用分支首推作为占用锁。
- `status` 看 `Active` / `Owner`；`list` 的 `*` 是当前 active，按 `createdAt` 最新优先。

## 示例

```bash
python3 infra/tool/batch/batch.py status
python3 infra/tool/batch/batch.py plan B15-2 --type feat --goal "..." --allowed "app/lib/features/terrain/**"
python3 infra/tool/batch/batch.py approve B15-2 --chat --confirm <hash8>
python3 infra/tool/batch/batch.py start B15-2
python3 infra/tool/batch/batch.py check --batch B15-2 --base main
python3 infra/tool/batch/batch.py pr --batch B15-2 --base main
```

细节见 `infra/tool/batch/README.md`。

## 自检

```bash
python3 -B infra/tool/batch/skill_lint.py .agents/skills/batch/SKILL.md
```

---
name: merge
description: 用 M1 闸门合并 PR，校验 card、scope、evidence、head 与 required checks。
whenToUse: 用户明确说“合”之后，或需要 dry-run 判断 PR 是否可合时。
metadata:
  owner: liberal
---

# merge

## Owner

- Owner: `liberal`
- 适用：所有合并；没有人工“合”不执行。

## 命令

```bash
# 只检查
python3 infra/tool/batch/batch.py merge --pr <n> --dry-run

# 人工确认后合并
python3 infra/tool/batch/batch.py merge --pr <n> --yes
```

## 合并前强制项

- card 已批准，scope 有效；
- `evidence.log` 里有 `RESULT: PASS`；
- PR head 等于 card/state 的 branch；
- 所有 required checks 通过，`mergeable=MERGEABLE`、`mergeStateStatus=CLEAN`；
- 没有 draft / conflict / changes-requested。

实际检查委托 `merge.py`，不在这里重复实现。

## 合并后

- 写 `.batch/<id>/merge.json`（PR、title、merge commit）；
- 清 `.batch/active`；
- `batch status` 进入 `Stage: merged`；
- 更新本地 `main`：`git fetch` + `git switch main` + `git merge --ff-only origin/main`。

## 边界

- 不直接 `gh pr merge`；那会跳过 evidence、scope、head 与审计。
- `merge.py` 的失败检查/未知检查一律 fail-closed。
- 合并后不 amend / 强推 `main`。

## 示例

```bash
python3 infra/tool/batch/batch.py merge --pr 205 --dry-run
python3 infra/tool/batch/batch.py merge --pr 205 --yes
```

## 自检

```bash
python3 -B infra/tool/batch/skill_lint.py .agents/skills/merge/SKILL.md
```

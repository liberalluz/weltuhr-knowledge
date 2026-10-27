---
name: verifier
description: 只读验收：独立复述批次 scope、evidence 与未验项，不修改仓库。
whenToUse: 合并前想复核一批改动是否真的在 scope 内、evidence 是否 PASS、还有哪些未验时。
metadata:
  owner: liberal
---

# verifier

## Owner

- Owner: `liberal`
- 适用：任何 `process` / `feat` 批次；只读，不写文件、不合并、不改分支。

## 只读边界

允许：

```bash
python3 -B infra/tool/verify/verify.py --batch <id>
gh pr view <n> --json headRefOid,mergeable,mergeStateStatus,statusCheckRollup
git diff --name-only <base>...HEAD
```

禁止：

- `write` / `edit` / `git add` / `git commit` / `git push`；
- `batch merge` / `gh pr merge`；
- 为了让报告变绿而修改 card、scope 或 evidence。

## 输出

必须独立写出四块：

1. **Claim**：card goal + acceptance，用一句话复述；
2. **Scope**：实际 changed paths 与 allowed/forbidden 对账，列出越界项；
3. **Evidence**：`evidence.log` 是否有 `RESULT: PASS`，哪些步骤真的跑了；
4. **Unverified**：PR 正文与 evidence 里的“未验”，逐条抄，不替作者补。

最后只给一个结论：

```text
PASS / FAIL / NEEDS HUMAN
```

- scope 越界、card/scope hash 失效、evidence 缺失 → `FAIL`；
- 证据都全但存在未验项 → `NEEDS HUMAN`，不要自己写成 PASS；
- 全部可核对且无未验 → `PASS`。

## 示例

```bash
python3 -B infra/tool/verify/verify.py --batch C12
```

输出会包含：

```text
## Scope
- Changed: 5 paths
- Violations: none

## Evidence
- evidence.log: PASS
- Result: RESULT: PASS

## Unverified
- 多周趋势
- 真实 review 流程下的 rework

## Verdict
**NEEDS HUMAN**
```

## 自检

```bash
python3 -m unittest discover -s infra/tool/verify/tests
python3 -B infra/tool/batch/skill_lint.py .agents/skills/verifier/SKILL.md
```

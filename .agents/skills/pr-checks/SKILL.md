---
name: pr-checks
description: 读懂 PR 的 required checks、平台 build 跳过与重复 check，不靠猜。
whenToUse: PR 检查红/绿、required checks 卡住、平台 build skip、或怀疑旧 check 残留时。
metadata:
  owner: liberal
---

# pr-checks

## Owner

- Owner: `liberal`
- 适用：所有 PR；合并前必须看最新 head 的检查。

## 先看什么

```bash
gh pr checks <n>
gh pr view <n> --json headRefOid,mergeable,mergeStateStatus,statusCheckRollup
```

- `headRefOid` 必须是你要合的那一笔；
- `mergeable=MERGEABLE`、`mergeStateStatus=CLEAN` 是必要条件，不是检查通过的替代品；
- `statusCheckRollup` 里同一名字有多次运行时，只信最新时间戳的运行。

## required checks

`main` 保护当前要求：

```text
app-checks
content-checks
repo-hygiene
platform-gate
```

三端 `windows-build` / `macos-build` / `ios-build` 仍是 advisory；只在 `app/` 改动时运行。`platform-gate` 永远报告，避免 skipped job 变成 “Expected”。

## 常见误判

- 只看 `gh pr checks` 的摘要，不看 head sha；
- 把旧 cancelled run 当成当前失败；
- 把 `platform-gate` 的 skipped build 当成平台验证通过；
- 把 `repo-hygiene` 的正文错误当成代码错误。

## 示例

```bash
gh pr checks 205
gh pr view 205 --json headRefOid,mergeable,mergeStateStatus
```

检查红先修代码或正文；不要用 `--no-verify` / 直接 `gh pr merge` 绕过。

## 自检

```bash
python3 -B infra/tool/batch/skill_lint.py .agents/skills/pr-checks/SKILL.md
```

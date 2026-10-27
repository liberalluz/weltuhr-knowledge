---
name: pre-push
description: 本地提交/推送三道钩子：commit-msg、pre-commit、pre-push scope。
whenToUse: 提交前、推送前、或钩子没有生效时。
metadata:
  owner: liberal
---

# pre-push

## Owner

- Owner: `liberal`
- 适用：每台开发机；钩子不生效时先查 `core.hooksPath`。

## 一次启用

```bash
git config core.hooksPath .githooks
git config --get core.hooksPath   # 应回显 .githooks
```

## 三道门

| 钩子 | 作用 |
|---|---|
| `commit-msg` | conventional commit + DCO `Signed-off-by` |
| `pre-commit` | staged diff 空白、暂存 Dart format、app/server analyze |
| `pre-push` | 只允许 PR 分支；有 `.batch/active` 时跑 scope guard；拦直推 `main` / 非法 tag |

## 边界

- `--no-verify` 只用于明确的紧急绕过，不是日常通道；绕过后 CI 仍会判。
- 直推 `main` 在平台保护启用后也会被拒；本地钩子只是第一道。
- `.batch/active` 指向批次目录；`check.py` 会解析目录下的 `scope.json`。

## 示例

```bash
git add app/lib/foo.dart
git commit -s -m "feat(app): ..."
git push -u origin HEAD
```

## 自检

```bash
python3 -B infra/tool/batch/skill_lint.py .agents/skills/pre-push/SKILL.md
```

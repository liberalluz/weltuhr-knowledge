# .agents

本目录放 agent 可读的规则与技能。

- `rules/`：always-on 编辑/平台规则（M5）。
- `skills/`：按需加载的项目技能（C5）。

## 技能

| 技能 | 用途 |
|---|---|
| `batch` | 批次生命周期导航 |
| `pr-checks` | PR 检查与 required checks |
| `pr-description` | v2 PR 正文 |
| `pre-push` | 本地钩子与scope |
| `platform-build` | 三端构建边界 |
| `merge` | M1 合并闸门 |
| `verifier` | 只读验收与未验复述 |

checklist：`.agents/checklists/acceptance.md`。

每个技能必须有 `## Owner`、`## 示例`、`## 自检`；`skill_lint.py` 检查这三项与 frontmatter。

```bash
python3 -B infra/tool/batch/skill_lint.py
```

技能只做导航，不复制 `docs/specs/` 或 `infra/tool/batch/README.md` 的正文。

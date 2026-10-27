# PR metrics

C12 的周报工具。只统计**已合并**的 PR，不做目标值，不做排名。

```bash
python3 infra/tool/metrics/pr_metrics.py --since 2026-09-01
python3 infra/tool/metrics/pr_metrics.py --since 2026-09-01 --json
python3 infra/tool/metrics/pr_metrics.py --since 2026-09-01 --output .batch/metrics-report.md
```

## 口径

| 指标 | 定义 |
|---|---|
| Lead time | `mergedAt - createdAt`，按周取中位数与 p90 |
| Rework | 首次 review 之后仍有 commit 的 PR |
| Docs share | 改动路径中 `docs/` 前缀的占比（按路径数，不按行数） |
| Scope known | 能用本地 `.batch/<id>/scope.json` 按 PR 号或 branch 匹配上的 PR |
| Scope fail | 实际 changed paths 不在该 scope 的 PR |
| Process-file PRs | 改了 `.githooks/**` / `.github/workflows/**` / `docs/specs/git-conventions.md` / `infra/tool/batch/**` 的 PR 数 |

`scope unknown` 不等于通过：历史 `.batch` 已被清理，或 PR 不是 batch 流程产生的，就明确记 unknown。

## 数据来源

- `gh pr list --state merged --search "merged:>=<since>"`；
- 每个 PR 的 `gh pr view --json files,commits,reviews`；
- 本地 `.batch/*/scope.json` 与 `merge.json` 做 scope 对账。

没有外部指标服务，没有手填数字。输出可以落 `.batch/`（gitignored），也可以只打印。

## 测试

```bash
python3 -m unittest discover -s infra/tool/metrics/tests
```

测试只覆盖纯计算，不访问网络；真实周报需要 `gh` 登录。

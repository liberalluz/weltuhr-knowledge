# batch merge gate

`merge.py` is the repository's conservative merge gate. It refuses to merge
unless the pull request is open, not a draft, conflict-free, every check is
successful/neutral/skipped, and no review is requesting changes.

## Usage

From the repository root:

```bash
# Check without merging
python3 infra/tool/batch/merge.py --pr 190 --dry-run

# Actually merge (squash + delete branch); only after human confirmation
python3 infra/tool/batch/merge.py --pr 190 --yes
```

Options:

| Option | Meaning |
|---|---|
| `--pr <n>` | Pull request number (required) |
| `--repo <owner/repo>` | Override the current `gh` repository |
| `--dry-run` | Check only; never merge |
| `--yes` | Required for an actual merge |
| `--json` | Print a machine-readable verdict |
| `--log <path>` | Audit log path (default: `.batch/merge-log.jsonl`) |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | eligible / merged / dry-run says eligible |
| `1` | blocked by a gate |
| `2` | eligible, but `--yes` was not passed |
| `3` | `gh` or repository error |

The gate treats `mergeStateStatus: CLEAN` as necessary but not sufficient:
`gh pr checks`/`statusCheckRollup` must also be all green. `MERGEABLE` alone is
not evidence that checks passed.

## Tests

```bash
python3 -m unittest discover -s infra/tool/batch/tests
```

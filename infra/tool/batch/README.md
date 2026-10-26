# batch tools

`merge.py` is the repository's conservative merge gate. It refuses to merge
unless the pull request is open, not a draft, conflict-free, every check is
successful/neutral/skipped, and no review is requesting changes. `check.py` is
the per-batch scope guard described below. `batch.py` is the state CLI skeleton.

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

## Batch state CLI

`batch.py` discovers a `.batch/<id>` directory and reports its current stage. C1
is read-only: it does not create branches, cards or pull requests.

```bash
python3 infra/tool/batch/batch.py status
python3 infra/tool/batch/batch.py status --batch M2 --json
python3 infra/tool/batch/batch.py list
```

State layout (gitignored):

```text
.batch/active              # optional: path to the current batch dir
.batch/<id>/state.json     # batch, type, branch, base
.batch/<id>/card.yaml      # C2
.batch/<id>/scope.json     # C2 + approval hash
.batch/<id>/evidence.log   # C3/C4
```

`status` falls back from `--batch` to `.batch/active`, then to the most recently
modified batch directory. Exit code `1` means no batch was found.

## Tests

```bash
python3 -m unittest discover -s infra/tool/batch/tests
```

## Scope guard

`check.py` verifies that the current diff stays inside a batch's approved
`scope.json`. `pre-push` runs it automatically when `.batch/active` exists.

```bash
python3 infra/tool/batch/check.py --scope .batch/M2/scope.json
python3 infra/tool/batch/check.py --scope .batch/M2/scope.json --warn-only

# Widen scope only with a reason and explicit human approval
python3 infra/tool/batch/check.py --scope .batch/M2/scope.json \
  --add app/lib/foo.dart --reason "needed by this batch" --yes
```

A scope file records `batch`, `type`, `allowed`, `forbidden`, and an
`approval.hash`. Editing the allowed set without re-signing is detected. Feature
batches may not touch process files (`.githooks/**`, `.github/workflows/**`,
`docs/specs/git-conventions.md`, `infra/tool/batch/**`); those require a
`type: process` batch.

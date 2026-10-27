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

## Batch card and state CLI

C2 adds the human-owned card and the start step; `status` remains read-only.

```bash
# Draft card.yaml; edit goal/allowed/acceptance, then approve
python3 infra/tool/batch/batch.py plan B15-2 --type feat --goal "..." \
  --allowed "app/lib/features/terrain/**" --acceptance "TC-FND-016..020 pass"

# Human approval: chat-confirmed, hash-locked
python3 infra/tool/batch/batch.py approve B15-2 --chat --confirm <hash8>

# Create branch (unless --no-branch), state.json, scope.json and .batch/active
python3 infra/tool/batch/batch.py start B15-2

python3 infra/tool/batch/batch.py status
python3 infra/tool/batch/batch.py status --batch M2 --json
python3 infra/tool/batch/batch.py list
```

`card.yaml` is a flat generated YAML subset (scalars + block lists + `approval`);
values are JSON-quoted, so no PyYAML dependency is needed. Editing it after
`approve` invalidates `approval.hash` and `start` refuses. `.batch/active` points
to the batch **directory**; `check.py` resolves the directory to `scope.json`.

State layout (gitignored):

```text
.batch/active              # path to the current batch dir
.batch/<id>/state.json     # batch, type, branch, base, created_at
.batch/<id>/card.yaml      # draft or approved card
.batch/<id>/scope.json     # signed scope (from the card)
.batch/<id>/evidence.log   # C3/C4
```

`status` falls back from `--batch` to `.batch/active`, then to the most recently
modified batch directory. Exit code `1` means no batch was found.

## Batch check

`batch check` is the local gate:

```bash
python3 infra/tool/batch/batch.py check --batch B15-2 --base main
python3 infra/tool/batch/batch.py check --batch B15-2 --quick      # scope only
python3 infra/tool/batch/batch.py check --batch B15-2 --dry-run    # plan only
```

It runs, when applicable:

| Step | When |
|---|---|
| `dart format --output=none --set-exit-if-changed` | changed `.dart` files |
| `flutter analyze` | any `app/` change |
| `dart run tool/lint/check.dart` | any `app/` change |
| `dart run tool/docs/check.dart` | any `docs/` change |
| `flutter test --reporter compact` | any `app/` change, unless `--no-tests` |
| `pr-body` | `--pr-body <file>` is passed |

The result is written to `.batch/<id>/evidence.log`; `batch status` only advances
to `Stage: pr` when that file contains `RESULT: PASS`. `--quick` is scope-only
and does not write evidence. `--no-format` / `--no-tests` are explicit escape
hatches, not defaults.

## Batch PR

`batch pr` builds the v2 PR body from `card.yaml` and `evidence.log`, writes it
to `.batch/<id>/pr-body.md`, and runs the same `pr-body` check as CI:

```bash
python3 infra/tool/batch/batch.py pr --batch B15-2 --base main
# review .batch/B15-2/pr-body.md, then:
python3 infra/tool/batch/batch.py pr --batch B15-2 --base main --create --yes
```

Without `--create` it only writes and validates; `--create` additionally requires
`--yes` and calls `gh pr create`. Generated `N` counts the actual changed paths;
edit the card/evidence and rerun rather than hand-editing the body when the count
changes.

## Batch merge

`batch merge` wraps the M1 gate and refuses to merge unless the local batch has
an approved card, a valid scope, `evidence.log` with `RESULT: PASS`, and a PR
head that matches the card branch:

```bash
python3 infra/tool/batch/batch.py merge --pr 200 --dry-run
python3 infra/tool/batch/batch.py merge --pr 200 --yes
```

It delegates the actual checks to `merge.py`; on success it writes
`.batch/<id>/merge.json` (PR, title, merge commit) and clears `.batch/active`.
`batch status` then reports `Stage: merged`. The direct `merge.py` command
remains the low-level gate.

## Skill lint

`.agents/skills/` 的六个技能由 `skill_lint.py` 校验 frontmatter 与 `## Owner` / `## 示例` / `## 自检`：

```bash
python3 -B infra/tool/batch/skill_lint.py
```

`batch check` 在 `.agents/skills/` 有改动时会自动跑这一步。

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

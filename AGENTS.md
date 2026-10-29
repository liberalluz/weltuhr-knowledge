# Weltuhr — agent entry point

This file is the **entry point and map**; detailed rules live in `.github/` and `docs/`, and are not copied here.

## Read these first, in order

1. [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md): governance, review, merge entry points
2. [`docs/specs/git-conventions.md`](docs/specs/git-conventions.md) §3–§4: criteria for commits, PRs, merges
3. The `AGENTS.md` of the module you touch (`app/` · `server/` · `content/` · `infra/` · `docs/`)
4. For the batch workflow load [`.agents/skills/batch/SKILL.md`](.agents/skills/batch/SKILL.md)

## Non-negotiable

- **One batch, one PR**; never cram two goals into one card.
- **Only one active batch at a time**; with multiple agents use `plan --auto-id` instead of hand-writing C-numbers and colliding.
- **Non-trivial changes go through a batch first**: `plan → approve → start`, then implement.
- **No push to a non-main branch without `.batch/active`**; `pre-push` rejects it, it is not a hint.
- **No direct push to `main`**, no direct `gh pr merge`; merges go through `batch merge` only.
- **Authors cannot self-approve**; the C10 ruleset requires one non-author approval plus code-owner review.
- **Controlled docs version at baselines, not per PR**; daily PRs do not bump `SCMP`/`STD`/`STP` or add history rows.
- **Each batch declares `docs-impact`** (`none|living|controlled`) and per-file `--note`; PR bodies must not contain placeholders.
- **SDP is an external process plan**; it holds plan only — progress belongs in `records/live` or generated reports.
- **Evidence must come from real commands**; what was not run is written as "未验", never as "should pass".
- Stop and ask when unsure; never edit card/scope/evidence just to get past a gate.

## Starting a batch

```bash
python3 infra/tool/batch/batch.py status
# multiple agents: let the CLI generate YYYYMMDD-<6 hex chars> to avoid collisions
python3 infra/tool/batch/batch.py plan --auto-id --type <process|feat> --goal "..." --allowed "<glob>"
# single agent / known id: pass <id> explicitly
python3 infra/tool/batch/batch.py plan <id> --type <process|feat> --goal "..." --allowed "<glob>"
# human review: show the card plus the first 8 hash chars first; after the user confirms
python3 infra/tool/batch/batch.py approve <id> --chat --confirm <hash8>
python3 infra/tool/batch/batch.py start <id>
# stale active (its PR is merged, no merge.json): clear only with proof
python3 infra/tool/batch/batch.py start <id> --clear-stale
python3 infra/tool/batch/batch.py check --batch <id> --base main
# PR body: --prepare writes the scaffold; edit the file to the final body
python3 infra/tool/batch/batch.py pr --batch <id> --base main --prepare
# create only from the finalized handwritten body + its hash
python3 infra/tool/batch/batch.py pr --batch <id> --base main --create \
  --body-file .batch/<id>/pr-body.md --confirm <body-hash8>
```

A merge requires approval from another maintainer and an explicit "merge" from the human, then:

```bash
python3 infra/tool/batch/batch.py merge --pr <n> --yes
```

## Directory map

- `app/`: Flutter client
- `server/`: Serverpod backend
- `content/`: content packs and the content pipeline
- `infra/`: CI, build, batch / metrics / verify tooling
- `docs/`: specs, decisions, runbooks
- `.agents/rules/`: always-on editing and platform constraints
- `.agents/skills/`: process skills loaded on demand

## When sources conflict

- Domain facts follow `docs/specs/`;
- Process follows `CONTRIBUTING` plus the batch tooling;
- A module `AGENTS.md` is more specific than this file but must not violate the non-negotiables above;
- Machine gates (pre-push / ruleset / CI) outrank any prose.

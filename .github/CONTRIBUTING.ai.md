# Contributing with AI assistants

> **What this file covers**: how AI-assisted contributions are admitted, and who carries the responsibility for them.
> **What it does not cover**: review eligibility and collaboration tiers → [`CONTRIBUTING.md`](CONTRIBUTING.md) §4–§5 · commit format, DCO check, PR body fields, merge strategy → [`git-conventions.md`](../docs/specs/git-conventions.md) · content licensing → [`dependency-licenses.md`](../docs/specs/dependency-licenses.md).

## Why this file exists

This repository is developed with AI assistants in the loop, which is expected rather than tolerated. The rules below are not a disclaimer about the tools — they are the three failure modes that actually happened here, each caught by a human reading a diff rather than by a passing build:

1. **"It passes" with no run.** A model reported success from reading the code or from a mock, while the real command was never executed.
2. **A statement the same commit refuted.** A specification line claimed that signatures survive a squash only for single-commit pull requests. The pull request that merged it was two commits and left three `Signed-off-by` lines in the squashed message — the claim was false the moment it landed.
3. **A gap filled with an invented rule.** After a set of translations was deleted, the resulting empty slot was filled with a new policy sentence that nobody had decided. It survived one review round before being removed as a second source of truth.

None of these is model-specific. They are what happens when a plausible sentence is accepted without an observable check.

## Non-negotiable

| # | Rule | Basis |
|---|---|---|
| 1 | **The submitter owns the change.** Whoever opens the pull request answers for it, whatever drafted it. | "the model said so" is not evidence |
| 2 | **Verification output is pasted from a real terminal.** No paraphrase, no reconstruction, no screenshot of a summary. | `X-05` observable assertion — [specs/00-index §4](../docs/specs/00-index.md) |
| 3 | **Decisions stay human.** A-, B- and D-level items and every `TBD` value are changed by people only, never by an assistant on its own initiative. | [`CONTRIBUTING.md`](CONTRIBUTING.md) §1 |
| 4 | **Cite, do not restate.** If a rule already exists somewhere, link it; a second copy will drift from the first. | [`docs/README.md`](../docs/README.md) §5 |
| 5 | **Declare the scope of the participation.** The `AI participation` line of the pull request body states what was drafted, what was edited, and what a human actually checked. | PR body fields — [git-conventions §4.1](../docs/specs/git-conventions.md) |

## What a model's output is not

- **Not a test result.** CI output and local command output are; a description of them is not.
- **Not a review.** Review is a human act and, once there is more than one maintainer, it must come from someone other than the author.
- **Not a licence opinion.** Provenance of generated text and media follows [`dependency-licenses.md`](../docs/specs/dependency-licenses.md) §2. If the source is unclear, the content does not go in.
- **Not an authority on platform behaviour.** Module loading, execution order, lifecycle and environment injection are settled by official documentation and real-hardware results. A local build, a mock, or a green self-check carries no evidence in that dimension.

## Before you open a pull request

1. Run the self-check in [git-conventions §7](../docs/specs/git-conventions.md) yourself, and paste the output rather than a summary of it.
2. Fill every field of the pull request body with a value, including the `AI participation` line. Checkboxes are not used on purpose — a ticked box does not mean a filled field, and anyone can tick it.
3. If the change touches A- or B-level criteria, open an issue first: a finished implementation drafted by an assistant is the least reviewable form of a proposal.
4. If you delete something, do not refill the empty space with a new statement. A deletion leaves a hole, and a hole is honest; a sentence invented to fill it becomes policy nobody decided.

## Where the rules live

| Question | Authority |
|---|---|
| May this be changed at all, and who signs off | [`CONTRIBUTING.md`](CONTRIBUTING.md) §1 |
| How the collaboration rules tighten as people join | [`CONTRIBUTING.md`](CONTRIBUTING.md) §5 |
| Branch, commit message, PR body, merge, DCO check | [`git-conventions.md`](../docs/specs/git-conventions.md) |
| What the docs may claim and how they link | [`docs/AGENTS.md`](../docs/AGENTS.md) |

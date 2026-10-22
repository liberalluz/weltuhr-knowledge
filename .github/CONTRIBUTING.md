# Contributing

> **What this file covers**: **governance** — who may change which level of decision · who is eligible to review · what a review looks at · roles · behavioural expectations · response times · licensing and DCO.
> **What it does not cover**: **process and format** — repository layout · branching · commit format · PR granularity · **approval count** · merge strategy · versions and tags · deliverable version numbers. All of that is authoritative in [`docs/guides/git-conventions.md`](../docs/guides/git-conventions.md) and is not duplicated here. Design content → [`docs/design/00-index.md`](../docs/design/00-index.md); security vulnerabilities → [`SECURITY.md`](SECURITY.md).

## 1. Authority boundaries

The design baseline of this repository is a set of **adjudicated, numbered specifications** (item count in [`docs/design/00-index.md`](../docs/design/00-index.md); this file does not repeat it). In multi-person collaboration the first discipline is not "how to write code" but **who may change a decision**: a wrong change to code can be reverted, a wrong change to a decision makes every downstream implementation drift the same way, and no test will catch it.

| Object of change | Example | Who decides | What is required |
|---|---|---|---|
| **Implementation** | bug fix, refactor, added tests, layout tweaks | any contributor | PR + review (count follows maintainer headcount, see §4) |
| **C-level docs** | wording, examples, dead links | any contributor | one sentence in the PR |
| **B-level** | constant values, field nullability, new event types | maintainer sign-off | PR + change note + backfill the cross-cutting table |
| **A-level** | six axes, `⪯`, event model, channel table, protocol | **maintainers only** | issue first → ADR → then change the specification |
| **D-level** | conflict with the [NOT list](../docs/reference/not-list.md) | **only a maintainer may overrule a NOT item** | don't; if you must, leave a record |
| **TBD values** | `C-28` search fuzziness threshold, etc. | **maintainers only** | do not fill in, do not supply a default |
| **External commitments** | licence, supported version window, response times, brand name | **maintainers only** | change requires an explicit announcement and a written record |

The grading criteria themselves are not repeated here; see [git-conventions §4.4 change grading](../docs/guides/git-conventions.md) and [design/00-index §7](../docs/design/00-index.md). This table answers only "who signs off".

**Why the last three rows are listed separately** — they all look like "just fill in a value" or "just change one sentence", yet the cost lands on other people:

- hand `C-28` a casual 0.6 and the search behaviour "a single hit jumps straight through" shifts silently — **no test goes red**;
- changing "7 business days" breaches an external promise while the PR diff is one line long;
- changing the supported version window invalidates the upgrade path of every user on an older version.

⚠️ **The most common mis-contribution**: in code, `C-28` is the sentinel `throw TbdConstantError`; reading it crashes. That is **deliberate**, not a bug. "Let me fix this crash and put in a sensible default" is the archetypal out-of-bounds change — when you hit the sentinel, open an issue; do not add a default.

## 2. Four ways in

| What you want to do | How to start | Open an issue first? |
|---|---|---|
| Report a defect | issue with **version + platform + reproduction steps** | — |
| Content erratum | issue naming the **space identifier + `itemId`** | — |
| Small change (docs, comments, single-point fix) | open a PR directly | No |
| New feature / design change / touching A- or B-level criteria | open an issue and discuss to agreement first | **Yes** |

The test for "small change": it can be stated in one commit message, and it does not touch any item in `docs/design/`.

A large PR that was never discussed will be closed rather than reviewed — not out of unfriendliness, but because **reviewing an A-level change that is already finished** amounts to rubber-stamping it after the fact, which costs more than discussing it from the start.

> **Do this once before you start**: `git config core.hooksPath .githooks` — without it the local hook never fires, and a direct push to `main` is caught by CI only **after it has landed**. Command and failure mode: [git-conventions §2.1](../docs/guides/git-conventions.md).

## 3. Five things before you open a PR

| # | Item | Criterion |
|---|---|---|
| 1 | Local self-verification | run everything in [git-conventions §7 pre-commit self-check](../docs/guides/git-conventions.md); paste the **commands actually executed and their output** into the PR body |
| 2 | Observable assertion | new behaviour needs a test vector; "it's implemented in the code" is not acceptance (`X-05`, see [00-index §4](../docs/design/00-index.md)) |
| 3 | DCO sign-off | `git commit -s`, every commit carries `Signed-off-by` (see §8) |
| 4 | One thing per PR | refactors and behaviour changes are not mixed; code and docs are not mixed in one commit |
| 5 | No stowaways | change only what you described; an unrelated problem you spot gets **its own issue**, not a drive-by reorder / rename / beautification |

Why rule 5 exists: the docs and code in this repository follow fixed conventions (tables first, cite rather than duplicate, nothing is rendered that the model does not declare). The cost of "tidying up along the way" is that the reviewer must work out line by line which parts are the real change, and reverting such a PR costs far more than it was worth.

**Using an AI assistant to write code is subject to all of these rules**, plus one more: a model saying "it passes" is not evidence — paste the output from your own terminal. Platform and runtime semantics are settled by official documentation and results on real hardware, not by a local build.

## 4. Review

**The count is not set here**: approval follows maintainer headcount (single maintainer **0** · ≥2 maintainers **1**, and it must not be the author). The rule is in [git-conventions §4.1](../docs/guides/git-conventions.md). This section answers only **who is eligible** and **what is looked at**.

- **While there is a single maintainer**: the **self-review conclusion** in the PR body stands in for approval (what changed / how it was verified / why it was cut this way). This is not an exemption, it is review exchanged for a written record; it lapses the moment a second maintainer appears.
- **A- and B-level changes**: regardless of headcount, a maintainer takes part in the review.
- Review looks at four things, not at stylistic preference:

| # | What is looked at | Basis |
|---|---|---|
| 1 | is the observable assertion there | `X-05` |
| 2 | are rules **cited** or copied into a second source | [docs/README §5](../docs/README.md) |
| 3 | does the interface quietly draw a field the model never declared | `X-01` |
| 4 | is the NOT list touched | [not-list](../docs/reference/not-list.md) |

⚠️ **Current state**: branch protection is not enabled on `main` (private repositories on free GitHub accounts cannot use it), so the constraints above **rest on discipline** rather than on system enforcement — see [git-conventions §4.3 remote state](../docs/guides/git-conventions.md). "Technically nothing stops it" does not make it allowed.

## 5. Roles

| Role | Permissions | How you get it |
|---|---|---|
| **Contributor** | open issues, open PRs | no application needed |
| **Reviewer** | approve / request changes | invited by a maintainer (threshold: see the pending item below) |
| **Maintainer** | merge, adjudicate A/B level, cut releases, change repository settings | unanimous agreement of the existing maintainers |

Current maintainer: [@liberalluz](https://github.com/liberalluz)

## 6. Expected behaviour

This repository does not yet have a separate `CODE_OF_CONDUCT.md`; these four rules apply in the meantime:

1. **Argue the point, not the person** — technical disagreements are settled with evidence and observable assertions, not with seniority.
2. **No pestering** — see §7 for the times; you may ask once a deadline has passed, but do not bump the same thread repeatedly.
3. **No filling in for others** — values owned by someone else (the last three rows of §1) are not yours to decide, even when the answer seems obvious.
4. **No self-certification** — "it runs on my machine" is not evidence.

Handling of violations: a maintainer may lock a discussion, close a PR, or refuse further contributions. A formal code of conduct (Contributor Covenant 2.1) will be added once the contributor base grows, at which point this section becomes a pointer (trigger threshold **TBD**).

## 7. Response times

| Item | Time |
|---|---|
| First response to an issue | within 7 business days (same rule as [`SECURITY.md`](SECURITY.md)) |
| First review comment on a PR | **TBD** — undecided, currently treated as the 7 business days that apply to issues |
| Closing a PR with no updates for a long time | **TBD** — undecided, current practice is to ask once before deciding |

⚠️ None of the above **constitutes an SLA**; these are the maintainers' best effort. Changing either row falls under "external commitments" in §1 and requires an explicit announcement.

## 8. Licence and attribution

- By submitting, you agree that your contribution is distributed under **Apache-2.0** (see [`../LICENSE`](../LICENSE), [`../NOTICE`](../NOTICE)).
- **DCO**: commits must use `git commit -s` and carry `Signed-off-by: Your Name <email>`, certifying that you have the right to submit the content (text at [developercertificate.org](https://developercertificate.org/)). This is not a copyright assignment; you keep the copyright.
- Knowledge content in a **content pack** (`content/`) must be original, or come from sources whose licence is compatible with this project; **do not introduce** text or media from CC-BY-NC, GPL or AGPL sources (criteria in [dependency-licenses §2](../docs/guides/dependency-licenses.md)). A content erratum does not change the original author's attribution.
- Third-party code or media must be registered **in the same PR** in [`../NOTICE`](../NOTICE) and the [dependency licence list](../docs/guides/dependency-licenses.md).

## Appendix: local environment

Flutter / Dart / Serverpod versions are pinned in `app/pubspec.yaml` and `server/pubspec.yaml` and **do not track the latest**. Environment setup and the known pitfalls of a first Windows build (symlinks, developer mode) are in [`docs/guides/environment.md`](../docs/guides/environment.md).

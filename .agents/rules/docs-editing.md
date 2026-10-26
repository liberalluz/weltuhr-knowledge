---
trigger: always_on
---

# Docs editing

- **Authority lives in `docs/AGENTS.md` and `docs/specs/`**. This file is a pointer, not a second copy; when they disagree, the docs win.
- **Controlled documents** (`STD` / `STP` / `SCMP` and other versioned deliverables) have version headers and cross-cutting counts. Update the single source, then run `dart run tool/docs/check.dart`; do not hand-edit the same number in several places.
- **Link, do not restate**: if a rule already exists, link it. A second copy drifts from the first.
- **A deletion leaves a hole; do not fill it with an invented policy sentence.** Record the gap or open an ADR instead.
- Relative links must resolve; do not use absolute local paths or paths that are not in `git ls-files`.
- **Docs sync is its own batch**: code PRs add at most a changelog line; controlled-doc reconciliation goes into a `docs` batch (or a release gate), not into every feature PR.
- The PR body's `影响面` and `验证` must say whether docs changed and which check was run.

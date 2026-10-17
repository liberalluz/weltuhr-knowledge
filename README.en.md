# Weltuhr

[简体中文](README.md) · **English** · [Deutsch](README.de.md) · [Italiano](README.it.md) · [日本語](README.ja.md) · [Français](README.fr.md)

> Translation of [README.md](README.md) · 2026-10-17 · the Chinese version is authoritative.

> Unfold a field of study into a knowledge space that is **locatable, plannable and measurable**, so that "I want to learn X" becomes "I know what to learn, in what order, and how far along I am when it counts as usable".

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

## Highlights

- **Knowledge spaces**: knowledge is organised around content packs — one space, one pack. A space boundary is settled by three criteria rather than drawn by hand into layers
- **Coordinates, not folders**: six axes (discipline / role / industry / competency / topic / tech stack) × three layers (persistent / view / fast-cycling) form **index coordinates** that can be stacked as filters, not nested folders
- **3D universe + 2D tree + detail**: three projections of one and the same graph model; position itself carries meaning (`r` / `θ` / `φ`), and no 3D force-directed layout is used
- **Planning in three stages**: source (materials) → system (sequence) → method (actions + criteria); all three are user-authorable, candidates are ranked by their own criteria, and the trade-offs are shown
- **Seven-step acquisition loop**: locate → plan → practise → test → retain → exit; review follows FSRS. Progress is discrete (never regresses) and kept separate from mastery, which is continuous (can decay)
- **Two kinds of notes**: system notes (derived from the system) and self-authored notes share the same `itemId` anchor and can be switched in place; export to external note apps is one-way

## Quick start

> Prerequisites: Flutter 3.x + Dart 3.x · Serverpod 4.x (versions are pinned in `app/pubspec.yaml` / `server/pubspec.yaml`) · PostgreSQL 16

```bash
git clone git@github.com:liberalluz/project-knowledge.git && cd project-knowledge

# client dependencies
cd app && flutter pub get

# server dependencies + database
cd ../server && dart pub get

# build content-pack output (must precede running the client: the client looks up content/<space>/dist/pack.json relative to the runtime CWD)
cd ../content && python tools/build.py

# run
cd ../app && flutter run -d windows
```

> ⚠️ **Skeleton stage**: the commands above are the agreed ones. The `app/` `server/` `content/` scaffolds have not been generated yet, so each command will be verified once the code lands. **"Ought to run" is not "has run".**

## Directory map

| Directory | Responsibility |
|---|---|
| [app/](app/README.md) | Flutter client (one codebase for Windows / macOS / iOS) |
| [server/](server/README.md) | Serverpod server: sync, event merging, governance and review |
| [content/](content/README.md) | Content-pack source data and build pipeline |
| [docs/](docs/README.md) | Deliverable documents, living docs, ADRs and design specs |
| [infra/](infra/README.md) | Build / signing / updater / mirror / CI |

Also: [docs/reference/knowledge-system-learning-methodology.md](docs/reference/knowledge-system-learning-methodology.md) — the **methodological basis** of this project (knowledge-system learning methodology); for the software design specification see [docs/design/](docs/design/00-index.md).

## Documentation

- [docs/README.md](docs/README.md) — documentation index (deliverables / living docs / ADRs)
- [docs/design/00-index.md](docs/design/00-index.md) — **design specification index** (FND / VIEW / PACK / PLAN / STEP / QUANT / NOTE / GOV + cross-cutting tables)

## Licence and attribution

Copyright (c) 2026 liberal. This project is released under the [Apache-2.0](LICENSE) licence; see also [NOTICE](NOTICE).

## Contributing and getting help

- **Security vulnerabilities**: please do not open a public issue — report through the private channel described in [.github/SECURITY.md](.github/SECURITY.md) (we commit to a first response within 7 business days)
- Questions and suggestions: via repository Issues; for content errata, quote the space identifier and the `itemId`
- Contribution workflow: [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md)

**English** · [简体中文](README.zh-CN.md) · [Deutsch](README.de.md) · [Italiano](README.it.md) · [日本語](README.ja.md) · [Français](README.fr.md)

# Weltuhr

> Unfold a field of study into a knowledge space that is **locatable, plannable and measurable**, so that "I want to learn X" becomes "I know what to learn, in what order, and how far along I am when it counts as usable".

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

- **Knowledge spaces**: knowledge is organised around content packs — one space, one pack. A space boundary is settled by three criteria rather than drawn by hand into layers
- **One graph, three projections**: six axes (discipline / role / industry / competency / topic / tech stack) × three layers (persistent / view / fast-cycling) form **index coordinates** that can be stacked as filters, not nested folders; the 3D universe, the 2D tree and the detail pane are three projections of that same graph, so position itself carries meaning (`r` / `θ` / `φ`) and no 3D force-directed layout is used
- **Planning in three stages**: source (materials) → system (sequence) → method (actions + criteria); all three are user-authorable, candidates are ranked by their own criteria, and the trade-offs are shown
- **Seven-step acquisition loop**: source → system → method → practise → test → retain → exit; review follows FSRS. Progress is discrete (never regresses) and kept separate from mastery, which is continuous (can decay)
- **Two kinds of notes**: system notes (derived from the system) and self-authored notes share the same `itemId` anchor and can be switched in place; export to external note apps is one-way

## Quick Start

> Prerequisites: Flutter 3.x + Dart 3.x · Serverpod 4.x (versions are pinned in `app/pubspec.yaml` / `server/pubspec.yaml`) · PostgreSQL 16

```bash
git clone git@github.com:liberalluz/weltuhr-knowledge.git && cd weltuhr-knowledge

# enable repository-managed hooks (commit-message format guard).
# One-time per clone; without it the same rule still runs in CI, but you only
# find out after pushing.
git config core.hooksPath .githooks

# client dependencies
cd app && flutter pub get

# server dependencies + database
cd ../server && dart pub get

# build content packs (output is not committed; the client probes <candidate root>/<pack dir>/pack.json relative to the runtime CWD)
cd ../content && python tools/build.py

# run
cd ../app && flutter run -d windows
```

## Commands

| Command | What it does |
|---|---|
| `cd app && flutter run -d windows` | Start the client |
| `cd app && flutter test --reporter compact` | Run the client test suite |
| `python content/tools/build.py` | Build content-pack output |
| `python content/tools/verify.py --suite` | Verify content packs against their schema |
| `cd app && flutter analyze && dart run tool/lint/check.dart && dart run tool/docs/check.dart` | Static checks: analyzer, repository lint rules, docs links and consistency |

> The table must match what CI actually gates; when a workflow changes, this table changes in the same pull request.

## Project structure

| Directory | Responsibility |
|---|---|
| [app/](app/README.md) | Flutter client (one codebase for Windows / macOS / iOS) |
| [server/](server/README.md) | Serverpod server: sync, event merging, governance and review |
| [content/](content/README.md) | Content-pack source data and build pipeline |
| [docs/](docs/README.md) | Engineering documentation — placement rules in [docs/README.md](docs/README.md) |
| [infra/](infra/README.md) | Build / signing / updater / mirror / CI |

## Architecture

Three tiers: the Flutter client renders three projections of one graph model (3D universe / 2D tree / detail); the Serverpod server owns sync, event merging, governance and review; content packs are plain data compiled by `content/tools/` into `pack.json`. The graph model, its coordinates and the path rules are specified in the [design specification index](docs/specs/00-index.md).

Design decisions and the rejected alternatives behind them: [docs/decisions/](docs/decisions/).

## Documentation

- Placement rules and knowledge-area coverage: [docs/README.md](docs/README.md)
- Specifications and interface contracts: [docs/specs/](docs/specs/00-index.md)
- Operations, environment setup and how to run things: [docs/runbooks/](docs/runbooks/)
- Methodological basis of the project: [docs/intent/knowledge-system-learning-methodology.md](docs/intent/knowledge-system-learning-methodology.md)

## Getting help

- Start with the documentation index: [docs/README.md](docs/README.md)
- Something is broken or won't start: [docs/runbooks/](docs/runbooks/)
- Questions and suggestions: repository Issues. For content errata, quote the space identifier and the `itemId`

## Contributing

Branch naming, commit format, pull requests and the review threshold are in [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md).

Maintainer: liberal

## Security

Report vulnerabilities through the private channel described in [.github/SECURITY.md](.github/SECURITY.md). Please do not open a public issue for a security problem.

## License

Apache-2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

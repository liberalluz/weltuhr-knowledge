---
trigger: always_on
---

# Flutter editing

Commands run from `app/` unless stated otherwise.

Before declaring a task done:

1. `dart format` the changed Dart files (not the whole tree).
2. `flutter analyze`.
3. `dart run tool/lint/check.dart` — analyzer cannot see the core invariants.
4. `flutter test` for the affected tests; full suite before a PR.
5. If `docs/` or a controlled document changed: `dart run tool/docs/check.dart`.

Rules:

- **Toolchain is pinned**: Flutter 3.47.7 / Dart 3.13.5 (`app/pubspec.yaml`, `.github/workflows/app-checks.yml`). A bump updates pubspec, CI and the environment runbook in the same change.
- **Layer boundaries are enforced by `app/tool/lint/check.dart`**: `app/lib/core` must not import Flutter. Do not restate the rule here; fix the code or the lint.
- **Codegen whitelist**: only `drift_dev` + `build_runner`. `freezed` / `json_serializable` / `riverpod_generator` require an ADR before use.
- **Do not hand-edit generated files**; regenerate with the documented command.
- **`pack.json` is generated and not committed** (SPEC-PACK-018). Run `flutter run` from `app/`, where the loader probes the candidate roots.
- Do not reformat unrelated files; a PR diff must stay inside its batch scope.

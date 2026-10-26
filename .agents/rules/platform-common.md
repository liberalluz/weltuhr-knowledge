---
trigger: always_on
---

# Platform-common

These rules apply to every Windows / macOS / iOS change.

- **No unguarded `dart:io` in shared UI**: use conditional imports or `defaultTargetPlatform`; platform-specific implementation belongs behind a seam, not an `if` scattered through widgets.
- **Check plugin support before using it**: a plugin that lacks Windows, macOS or iOS support needs a documented degradation, not a runtime crash.
- **Paths are not strings**: use `package:path`; never hardcode `/` or `\`; do not assume case-insensitive file names.
- **Line endings and file modes** are governed by `.gitattributes`; do not normalize unrelated files.
- **Window/layout facts differ**: verify window sizing, DPI/scaling, safe areas, keyboard/mouse/touch and menu shortcuts on the target platform, not just the host.
- **Tests may fake the platform** (`debugDefaultTargetPlatformOverride`) but a fake does not replace a build or a real-device check.
- When a platform behavior is uncertain, consult the official docs and record what was actually run; a local build on another OS is not evidence for that platform.

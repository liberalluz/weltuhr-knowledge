---
trigger: always_on
---

# Apple platforms (macOS / iOS)

- **macOS and iOS builds require macOS + Xcode**; a Windows host cannot verify either. If you cannot run them, say so and let CI/the platform owner verify.
- Commands:
  - macOS: `flutter run -d macos` · `flutter build macos --debug`
  - iOS: `flutter run -d ios` on a Mac; PR CI uses `flutter build ios --debug --no-codesign`
- **PR CI never signs**: no certificates, provisioning profiles or notarization secrets in pull-request jobs. Signing/notarization belongs to release jobs in `infra/`.
- Do not change the deployment target, entitlements, bundle identifiers or capabilities without an ADR; a missing entitlement can pass a simulator build and fail on device.
- CocoaPods / Swift Package Manager resolution is part of the build; commit lockfiles only when the repo already tracks them.
- **Platform behavior is settled by official documentation and a real device/simulator**, not by model memory or a green build on another OS.

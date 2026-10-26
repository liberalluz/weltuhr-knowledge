---
trigger: always_on
---

# Windows

Commands run from `app/`:

```powershell
flutter pub get
flutter run -d windows
flutter build windows --debug
```

- The supported toolchain is Visual Studio 2022 with **Desktop development with C++** and CMake; a missing workload is an environment error, not a code error.
- Long paths and symlinks are real failure modes; enable Windows Developer Mode for symlinks and keep generated paths short.
- Use **PowerShell** syntax for terminal steps (`$env:NAME`, `Start-Process`, `Start-Job`); do not paste bash-only commands.
- Check case-insensitive name collisions before adding files that differ only by case.
- File locks and antivirus can make build/cleanup hang; a post-build hang is not a build failure — record the step and move on.
- **Signing/MSIX belongs to `infra/`**: do not put certificates, passwords or signing steps in `app/`, and never commit signing material.

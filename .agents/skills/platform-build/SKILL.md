---
name: platform-build
description: Windows / macOS / iOS 平台构建的触发面、advisory 边界与签名边界。
whenToUse: 改 app/、看三端构建、或 platform-gate 结果异常时。
metadata:
  owner: liberal
---

# platform-build

## Owner

- Owner: `liberal`
- 适用：`app/` 代码、平台目录、pubspec 变更；纯文档不触发。

## 触发面

`platform-checks.yml` 只在 `app/` 的代码/平台目录变化时跑三端：

```text
app/lib app/test app/tool app/windows app/macos app/ios app/pubspec* app/analysis_options*
```

`app/AGENTS.md` 等纯文档不触发。手动 `workflow_dispatch` 强制全矩阵。

## 命令

```bash
cd app
flutter build windows --debug
flutter build macos --debug
flutter build ios --debug --no-codesign   # 在 macOS 上
```

## 边界

- build job 仍是 **advisory**；`platform-gate` 才是 required check。
- PR CI 不签名、不装证书；签名/notarization 属 release，归 `infra/`。
- Windows 的 `subosito/flutter-action` 已关闭 cache，避免 post-step 挂住；不要随意改回。
- 本地 build 成功不等于三端制品验收；平台行为以 CI / 真机为准。

## 示例

C8 的 `app/` 改动触发了三端：Windows 2m51s、macOS 2m22s、iOS 2m45s，全部通过；`platform-gate` pass。

## 自检

```bash
python3 -B infra/tool/batch/skill_lint.py .agents/skills/platform-build/SKILL.md
```

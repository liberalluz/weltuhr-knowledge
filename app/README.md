# app

> Flutter 客户端：三维宇宙、树视图、详情、定位结果、进展五个投影，共用同一份内存图模型。

## 本模块命令

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
dart run tool/lint/check.dart   # 架构规则 R1/R2（见下）
flutter run -d windows        # 必须在 app/ 目录内运行（内容包按运行期 CWD 查找）
```

## 分层

| 目录 | 内容 | 约束 |
|---|---|---|
| `lib/core/` | 常量 · 实体 · 事件 · 定位引擎 · 量化（W0 已建常量与实体） | **纯 Dart，禁 import Flutter**（R1）；**禁数字字面量**，除 `constants.dart`（R2） |
| `lib/features/` | 界面：宇宙 / 树 / 详情 / 定位结果 / 进展 / 修习（**W2 起建**） | 可用 Flutter，不持有可写状态 |
| `tool/lint/` | R1 跨层依赖 · R2 字面量常量 | 纯函数 `(path, source) → issues`，由 `test/lint/` 覆盖 |

> R1/R2 的检查是 `dart run tool/lint/check.dart`，**不在 `flutter analyze` 里**。另两条约束（事件只 append、UI 不写状态）靠接口形状保证，不设 lint —— 见 [ADR-0002](../docs/adr/0002-dev-order-vertical-slice.md)。

## 相关文档

- 交付文档与活文档：[../docs/README.md](../docs/README.md)
- 设计规格（视图与通道细节）：[../docs/design/VIEW-views.md](../docs/design/VIEW-views.md) · [../docs/reference/channel-table.md](../docs/reference/channel-table.md)
- 实现约定与边界：见 [AGENTS.md](AGENTS.md)；规则细则以 `docs/` 为准（**不复制**）

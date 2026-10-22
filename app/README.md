# app

> Flutter 客户端：三维宇宙、树视图、详情、定位结果、进展五个投影，共用同一份内存图模型。

## 本模块命令

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
dart run tool/lint/check.dart   # 架构规则 R1–R5（见下）
flutter run -d windows        # 必须在 app/ 目录内运行（内容包按运行期 CWD 查找）
```

> ⚠️ `flutter test` 里的 α 包用例读**真实产物** `../content/python/dist/pack.json`，
> 而 `dist/` 不入库（`SPEC-PACK-018`）⇒ 首次或内容改动后先跑
> `python content/tools/build.py python`，否则这几条会**明确失败**（不 skip）。

## 分层

| 目录 | 内容 | 约束 |
|---|---|---|
| `lib/core/` | 常量 · 实体 · 事件 · 包加载（探测 / 解析 / 环校验） · 定位引擎 · 量化（W0 常量与实体，B2 加载与定位） | **纯 Dart，禁 import Flutter**（R1）；**禁数字字面量**，除 `constants.dart`（R2） |
| `lib/features/` | 界面：宇宙 / 树 / 详情 / 定位结果 / 进展 / 修习（**W2 起建**） | 可用 Flutter，不持有可写状态 |
| `tool/lint/` | R1 跨层依赖 · R2 字面量常量 · R3 事件只 append · R4 源不进视觉通道 · R5 测试须标裁定来源 | 纯函数 `(path, source) → issues`，由 `test/lint/` 覆盖 |

> R1–R5 的检查是 `dart run tool/lint/check.dart`（默认扫 `lib/` 与 `test/`），**不在 `flutter analyze` 里**。R3/R4 原先被列为「靠接口形状保证」，实测形状只挡得住**改**、挡不住**加** —— 给 `Event` 加个 `copyWith` 编译不报错、测试不红，所以补成规则。仍靠形状的只剩「UI 不写状态」（判据是结构性质，写不成静态模式），它留在 `STD` §4.3 的 B 类缺口里 —— 见 [ADR-0002](../docs/decisions/0002-dev-order-vertical-slice.md)。

## 相关文档

- 交付文档与活文档：[../docs/README.md](../docs/README.md)
- 设计规格（视图与通道细节）：[../docs/specs/VIEW-views.md](../docs/specs/VIEW-views.md) · [../docs/reference/channel-table.md](../docs/reference/channel-table.md)
- 实现约定与边界：见 [AGENTS.md](AGENTS.md)；规则细则以 `docs/` 为准（**不复制**）

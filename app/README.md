# app

> Flutter 客户端：三维宇宙、树视图、详情、定位结果、进展五个投影，共用同一份内存图模型。

## 本模块命令

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d windows        # 必须在 app/ 目录内运行（内容包按运行期 CWD 查找）
```

## 相关文档

- 交付文档与活文档：[../docs/README.md](../docs/README.md)
- 设计规格（视图与通道细节）：[../docs/design/VIEW-views.md](../docs/design/VIEW-views.md) · [../docs/reference/channel-table.md](../docs/reference/channel-table.md)
- 实现约定与边界：见 [AGENTS.md](AGENTS.md)；规则细则以 `docs/` 为准（**不复制**）

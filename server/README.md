# server

> Serverpod 服务端：事件接收与合并、权威排序、内容包与 overlay 的治理与审核。

## 本模块命令

```bash
dart pub get
dart format lib test
dart analyze
dart test                     # 必须在 server/ 包目录内执行
serverpod start --no-docker   # 内嵌 PostgreSQL；测试库用 serverpod database start -m test
```

## 相关文档

- 交付文档与活文档：[../docs/README.md](../docs/README.md)
- 跨设备合并与治理：[../docs/design/GOV-governance.md](../docs/design/GOV-governance.md) · [../docs/reference/event-types.md](../docs/reference/event-types.md)
- 实现约定与边界：见 [AGENTS.md](AGENTS.md)；规则细则以 `docs/` 为准（**不复制**）

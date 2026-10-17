# server

> Serverpod 服务端：事件接收与合并、权威排序、内容包与 overlay 的治理与审核。

## 版本

与客户端**共用产品版本** `vX.Y.Z`：本包 `pubspec.yaml` 的 `version` 须与 `app/pubspec.yaml` **逐字相同**（含 `+N` 构建号），**一个 tag 覆盖双端**，服务端不另打 tag。协议（事件 schema）变更时**服务端先发并向后兼容至少一个版本**，客户端随后放量。判据与理由见 [git-conventions §五](../docs/guides/git-conventions.md)。

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

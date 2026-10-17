# server —— agent 入口

本目录的**约定、边界与常用命令**。规则细则以项目 `docs/` 为准，**本文件不复制**。

## 路径基准

本文件内所有相对路径**以本目录（`server/`）为基准**。

## 职责边界

- **负责**：事件接收（HLC 定序 + 幂等）· 跨设备合并 · 提交审核（四裁定）· overlay 双平面（本地 / 公共）· 内容包分发 · 鉴权与令牌
- **不负责**：客户端渲染与本地匹配（→ `app/`）· 内容生产与 pack 构建（→ `content/`）· 部署与容器编排（→ `infra/`）

## 关键命令

| 用途 | 命令 |
|---|---|
| 获取依赖 | `dart pub get` |
| 格式化 / 检查 | `dart format .` · `dart analyze` |
| 测试（须串行 DB 操作） | `dart test` |
| 起开发库 + 服务 | `serverpod start --no-docker` |
| 测试库 | `serverpod database start -m test` |

## 红线

- **鉴权处理器必须装配**：`lib/server.dart` 传入 `authenticationHandler`；未装配时带 `Authorization` 头的请求会直接 **HTTP 500**。本项目自研鉴权，**不启用 `serverpod_auth*`**。
- **错误映射决定续期行为**：`SerializableException` → HTTP 400，只有 `NotAuthorizedException` → HTTP 401。本项目 401 全由端点内显式抛出，内置重试不会触发 ⇒ **令牌续期必须手写**，不得指望框架重试。
- **幂等靠唯一索引，不靠先查后插**：`turnId` / 事件 `id` 一律建 UNIQUE 索引；先查后插存在竞态。
- **事件只 append，不改不删**：合并、迁移、下线都以**新增事件**表达（`state_carried` / `state_merged` / `item_retired` / `note_revised`），不得就地修改历史事件。
- **HLC 物理部分须 clamp**：设备时钟偏差会污染排序，物理时间由服务端校正、逻辑计数保证不倒退。
- **测试期数据库操作必须串行**：并排未 await 会抛 `ConcurrentTransactionsException` 并盖住真实断言。
- **`.s.PGSQL.5432` 零字节残留**会让下次起库失败（`FATAL: could not create any Unix-domain sockets`）⇒ 处置是改名挪开，不是重试。

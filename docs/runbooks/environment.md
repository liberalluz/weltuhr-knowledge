# 环境与工具链

> 活文档，不设版号。**版本以仓库钉定值为准**（`app/pubspec.yaml` / `server/pubspec.yaml`），本文只记约束与边界。

## 一、工具链

| 组件 | 约束 |
|---|---|
| Flutter / Dart | 版本钉死在 `app/pubspec.yaml`，**不用 `^` 区间** |
| Serverpod | 版本钉死，**不用 `^` 区间**；升级须走变更控制 |
| PostgreSQL | 交付侧 **16**；开发侧可用内嵌 PG |
| Python | 内容管线 `content/tools/build.py` 仅依赖标准库 |

## 二、镜像变量（网络受限环境）

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 三、沙箱能力边界（自动化助手）

| 可执行 | 不可执行（归用户终端） |
|---|---|
| `dart format` · `dart analyze` · `dart test` | `flutter build` 三端 |
| `flutter test` · `flutter pub get` | `flutter run` |
| 内容包构建 `python tools/build.py` | 签名打包 |
| `serverpod` CLI | 真机验收 |
| `git` / `gh` | CI 首跑（常驻进程） |

**跑 `flutter test` / `analyze` 前须先清空代理变量**，否则会抛 `WebSocketException`。

## 四、Windows 桌面构建的两道门

1. 开启 Windows **开发者模式**（否则符号链接失败）
2. 删除 `app/windows/flutter/ephemeral` 后重试

## 五、代理与 `gh`

`gh` 只认 `HTTPS_PROXY` / `HTTP_PROXY`。若沙箱注入了无效代理，先 `unset` 再重试。推送用 SSH 时加非交互参数：

```bash
GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new" git push
```

## 六、内容包与运行目录

`PackLoader` 按**运行期 CWD** 在**候选根下的包目录**里探测 `pack.json`（`<候选根>/<包目录>/pack.json`，`SPEC-PACK-018`）。因此 `flutter run` **必须在 `app/` 目录内执行**；`pack.json` 由内容管线生成且**不入库**。

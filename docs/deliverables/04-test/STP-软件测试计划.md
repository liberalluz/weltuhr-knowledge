# 软件测试计划（STP）

> **版号**：`v0.2.0` · **状态**：§五 用例已回填，§六 错误码覆盖缺口已量化
> 本文件规定**测什么、怎么判通过**。用例正文在 [`STD`](STD-软件测试说明.md)，实际执行结果在 [`STR`](STR-软件测试报告.md)。
> **追溯补录**：2026-10-17 · §五 §六 依据 `app/test/` 与 `content/tools/` 的既有测试反推，非当时所写。

## 修订历史

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建。确立测试分层与通过判据；用例待补 |
| `v0.2.0` | 2026-10-17 | **追溯补录** §五 用例汇总（42 条）、§六 错误码覆盖缺口（8/36） |

---

## 一、测试分层

| 层 | 范围 | 命令 | 跑在哪 |
|---|---|---|---|
| 单元测试 | 纯函数与算法（`fold` · 定位 · 量化 · `⪯` 校验） | `flutter test` | 本机 + CI |
| 组件/Widget 测试 | 视图投影、状态变化、交互 | `flutter test` | 本机 + CI |
| 内容管线回归 | `content/tools/` 的校验器与构建器 | `python content/tools/verify.py --suite` | 本机 + CI |
| 架构约束 | 跨层依赖、字面量常量等**机械化**约束 | `dart run tool/lint/check.dart` | 本机（CI 待接入） |
| 端到端 | 五动作闭环（加载 → 圈定 → 建 Plan → 学一项 → 判合格写事件） | 手工 / 集成 | 本机 |
| 真机与制品 | 三端安装包可装、可启动、能加载内容 | 手工 | **用户终端** |

**分层判据**：一层能测的，不靠下一层兜底。凡可写成断言的，不得写进「手工验收清单」—— 手工清单只留**断言写不出来**的项（观感、真机行为、商店审核）。

## 二、环境

| 环境 | 能跑什么 | 不能跑什么 |
|---|---|---|
| 本机（开发机） | analyze · test · 内容管线 · git | — |
| CI（`content-checks`） | 内容管线四步 | 客户端测试（尚未接入） |
| 沙箱 / 代理环境 | 只读操作 | `flutter build` 三端 · `flutter run` · 签名打包 |
| 用户终端 | 三端构建 · 真机 · 制品验收 | — |

**未验项处理**：跑不了的项在 `STR` 里标「未验 + 原因 + 归谁验」，**不得留空、不得写「应该能过」**。

## 三、通过判据

| 项 | 判据 |
|---|---|
| 静态检查 | `flutter analyze` 零 issue；架构约束规则零违规 |
| 测试 | 全部用例通过；不允许「已知失败但先合」 |
| 内容管线 | `content-checks` 四步全绿（fixtures 回归 · 确定性 · 构建 · 产物不入库） |
| 覆盖 | 每个 `SPEC-*` 至少一条可观测断言（`X-05`：验证不得自证） |

## 四、用例来源

| 来源 | 用法 |
|---|---|
| 各设计文档末的**验收表**（裁定号 / 可观测断言 / 测试向量 / 预期） | 直接作为用例种子 |
| `content/tools/fixtures/` | 正例与负例，负例必须红 |
| PR 正文记录的手工验证 | 转成用例，否则下次无法复跑 |

## 五、具体用例

用例正文（编号 · 前置 · 步骤 · 预期 · 自动化位置）在 [`STD`](STD-软件测试说明.md) §三，本文件不复制。此处只登记**总量与分布**，供判断测试投入是否失衡。

### 5.1 总量

| 层 | 用例数 | 编号 | 跑法 |
|---|---|---|---|
| 单元 | 23 | `TC-FND-001`–`006` · `TC-PACK-001`–`002` · `TC-QUANT-001`–`009` · `TC-STEP-001`–`003` · `TC-PLAN-001` · `TC-NOTE-001` · `TC-VIEW-001` | `flutter test`（在 `app/` 下） |
| 管线 | 9 | `TC-FND-007` · `TC-PACK-003`–`010` | `python content/tools/verify.py --suite` |
| 架构 | 9 | `TC-INF-001`–`009` | `dart run tool/lint/check.dart`（在 `app/` 下） |
| Widget | 1 | `TC-INF-010` | `flutter test` |
| **合计** | **42** | — | — |

> 42 = **Dart 33**（`constants` 8 · `entities` 9 · `events` 6 · `lint` 9 · `widget` 1）+ **管线 fixture 9**，与既有测试 1:1 对应，**未新增、未删减**。

### 5.2 一个必须写明的边界

`app/README.md` §注记写「事件只 append、UI 不写状态这两条**靠接口形状保证，不设 lint**」。本文件接受这一取舍，但它的实际保护力要说清：

| 约束 | 「形状保证」阻止了什么 | **没有**阻止什么 |
|---|---|---|
| 事件只 append | 阻止**修改**已有事件（无 `copyWith`、字段 `final`） | 阻止**新增** `copyWith` —— 加了不会有任何东西报错 |
| UI 不写状态 | 阻止视图层直接改状态对象 | 阻止视图层持有可变引用并就地修改 |

所以这两条目前在 `STD` §4.3 里被列为 **B 类缺口**，不是 C 类。差别在于：C 类是「测了但没标号」，补个编号就行；B 类是「根本没有东西会响」，得补机制。

## 六、错误码覆盖缺口

`content/tools/validator.py` 共定义 **36 个错误码**。9 个 fixture 覆盖了其中 **8 个**：

| 已覆盖 | 由哪条用例锁住 |
|---|---|
| `E-CYCLE` | `TC-FND-007` |
| `E-ID-DUP` | `TC-PACK-004` |
| `E-SPACE-NO-ORDER` | `TC-PACK-005` |
| `E-REQ-VALUE` | `TC-PACK-006` |
| `E-REQ-KEY` · `E-REQ-STATE` | `TC-PACK-007` |
| `E-VERSION-FORMAT` | `TC-PACK-008` |
| `E-ID-VERSIONED` | `TC-PACK-009` |

**未覆盖的 28 个**：

```
E-DOMAIN            E-EDGE-DUP         E-EDGE-FIELD       E-EDGE-REF
E-EDGE-TYPE         E-EXCERPT-FIELD    E-ID-FORMAT        E-ITEM-FIELD
E-JSON              E-LAYER            E-MANIFEST-FIELD   E-MANIFEST-MISSING
E-META-EXTRA-KEY    E-META-FIELD       E-META-VERSION     E-PACK-EXTRA-KEY
E-PACK-MISSING-KEY  E-QUESTION-FIELD   E-QUESTION-REF     E-SCHEME-AUTH
E-SCHEME-DUP        E-SCHEME-FIELD     E-SCHEME-NODE-REF  E-SEGMENT-MISSING
E-SEGMENT-TYPE      E-SIXAXIS          E-SOURCEREF        E-TYPE
```

**这意味着什么，要说准确**：这 28 条拒绝路径**从未被执行过**。它们可能是对的，可能有 bug，也可能已经因为数据结构演进而永远走不到 —— **目前无人知道**。而校验器是内容包质量的第一道门，它静默放过一个坏包，代价要到用户导入时才发现。

**为什么不是现在补**：补 28 个 fixture 是纯机械工作，但没有 α 真实内容包（`B2`）之前，fixture 只能基于 `valid-min` 变异得出 —— 而 `valid-min` 本身就是最小样例，从它变异出来的负例未必代表真实数据的坏法。等 α 包落地后同批补，覆盖率才能真正对应现实。

> 记入 `STD` §五 待补第 4 项，归属 `B2`。

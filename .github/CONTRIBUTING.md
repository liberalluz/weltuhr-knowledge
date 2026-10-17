# 贡献指南

> **本文件管什么**：**治理** —— 谁能改哪一级裁定 · 谁有资格评审 · 评审看什么 · 角色 · 行为期望 · 响应时限 · 许可与 DCO。
> **不管什么**：**流程与格式** —— 仓库结构 · 分支 · 提交格式 · PR 粒度 · **approval 数量** · 合并策略 · 版本与 tag · 交付物版号，一律以 [`docs/guides/git-conventions.md`](../docs/guides/git-conventions.md) 为准，此处不复制。设计内容 → [`docs/design/00-index.md`](../docs/design/00-index.md)；安全漏洞 → [`SECURITY.md`](SECURITY.md)。

## 一、权限边界

本仓的设计基线是**已裁定的编号规格**（条目数见 [`docs/design/00-index.md`](../docs/design/00-index.md)，本文不重复计数）。多人协作的第一条纪律不是「怎么写代码」，而是**谁能改裁定**：改错代码能回滚，改错裁定会让所有下游实现同时偏，且没有任何测试会发现。

| 改动对象 | 例子 | 谁能拍板 | 必须做什么 |
|---|---|---|---|
| **实现** | bug 修复、重构、补测试、布局微调 | 任何贡献者 | PR + 评审（数量随维护者人数，见 §四） |
| **C 级文档** | 措辞、例子、修死链 | 任何贡献者 | PR 里说明一句 |
| **B 级** | 常量数值、字段可空性、新增事件类型 | maintainer 确认 | PR + 变更说明 + 回填横切表 |
| **A 级** | 六轴、`⪯`、事件模型、通道表、协议 | **只能由 maintainer 定** | 先 issue → ADR → 再改规格 |
| **D 级** | 与 [NOT 清单](../docs/reference/not-list.md) 冲突 | **只能由 maintainer 推翻 NOT 条目** | 不做；要做须留痕 |
| **TBD 取值** | `C-28` 搜索模糊阈值等 | **只能由 maintainer 裁定** | 不得代填、不得给默认值 |
| **对外承诺** | 许可、支持版本窗口、响应时限、品牌名 | **只能由 maintainer** | 变更须显式公告并留痕 |

分级判据本身不在此重复，见 [git-conventions §4.4 变更分级](../docs/guides/git-conventions.md) 与 [design/00-index §七](../docs/design/00-index.md)；本表只回答「谁批」。

**为什么后三行必须单列** —— 它们看起来都只是「填个值」「改一句话」，代价却落在别人身上：

- `C-28` 随手给个 0.6，搜索的「单一命中直接跳」会静默偏移，**没有任何测试会红**；
- 改一句「7 个工作日」就是对外违约，而 PR diff 只有一行；
- 改支持版本窗口会让所有旧版本用户的升级路径失效。

⚠️ **最容易发生的误贡献**：`C-28` 在代码里是 `throw TbdConstantError` 哨兵，读到就崩。这是**故意的**，不是 bug。「顺手修好这个崩溃、给个合理默认值」是最典型的越界改动 —— 遇到哨兵请开 issue，不要补默认值。

## 二、四条进入路径

| 你想做 | 怎么开始 | 要先开 issue 吗 |
|---|---|---|
| 报缺陷 | issue 附**版本 + 平台 + 复现步骤** | — |
| 内容勘误 | issue 注明**空间标识 + `itemId`** | — |
| 小改动（文档、注释、单点修复） | 直接开 PR | 否 |
| 新功能 / 改设计 / 动 A、B 级判据 | 先开 issue 讨论到达成一致 | **是** |

「小改动」的判据：能在一条 commit message 里说清，且不牵动 `docs/design/` 的任何条目。

未讨论的大 PR 会被关闭而不是评审 —— 不是不欢迎，是**评审一份已经写完的 A 级改动**等于事后追认，成本比从头讨论高。

## 三、提 PR 前的五件事

| # | 项 | 判据 |
|---|---|---|
| 1 | 本地自验证 | 按 [git-conventions §七 提交前的自检](../docs/guides/git-conventions.md) 跑全；PR 正文贴**实际执行的命令与输出** |
| 2 | 可观测断言 | 新行为须配测试向量；「代码里实现了」不构成验收（`X-05`，见 [00-index §四](../docs/design/00-index.md)） |
| 3 | DCO 签署 | `git commit -s`，每个提交带 `Signed-off-by`（见 §八） |
| 4 | 一件一事 | 重构与行为变更不混；代码与文档不混提 |
| 5 | 不夹带 | 只改你说明的；发现的无关问题**另开 issue**，不顺手重排 / 重命名 / 美化 |

第 5 条的由来：本仓文档与代码都有固定版式（表格优先、引用不复制、未声明即不渲染）。「顺手整理」的代价是评审要逐行分辨哪些是真改动，而这类 PR 的回退成本远高于收益。

**用 AI 助手写代码同样适用全部规则**，且多一条：模型说「已跑通」不算证据，须贴你自己终端里的输出。平台 / 运行时的语义以官方文档与真机结果为准。

## 四、评审

**数量不在此定**：approval 按维护者人数取值（单人 **0** · ≥2 人 **1** 且须非作者），口径见 [git-conventions §4.1](../docs/guides/git-conventions.md)。本节只回答**谁有资格**与**看什么**。

- **单人维护期**：以 PR 正文的**自审结论**替代 approval（改了什么 / 怎么验的 / 为什么这样切）。这不是豁免，是把评审换成留痕；第二位维护者出现即失效。
- **A / B 级改动**：不论人数，须 maintainer 参与评审。
- 评审看四件事，不看风格偏好：

| # | 看什么 | 依据 |
|---|---|---|
| 1 | 可观测断言在不在 | `X-05` |
| 2 | 规则是**引用**还是复制了第二份 | [docs/README §五](../docs/README.md) |
| 3 | 模型没声明的字段，界面有没有偷偷画出来 | `X-01` |
| 4 | 有没有碰 NOT 清单 | [not-list](../docs/reference/not-list.md) |

⚠️ **现状**：`main` 未启用分支保护（GitHub 免费账号的私有仓不支持），上述约束**靠自觉**而非系统拦截，见 [git-conventions §4.3 远端现状](../docs/guides/git-conventions.md)。不因技术上没拦住就当作允许。

## 五、角色

| 角色 | 权限 | 获得方式 |
|---|---|---|
| **Contributor** | 提 issue、提 PR | 无需申请 |
| **Reviewer** | approve / 请求修改 | 由 maintainer 邀请（门槛见下方待定项） |
| **Maintainer** | 合并、裁定 A/B 级、发版、改仓库设置 | 现有 maintainer 一致同意 |

现役 maintainer：[@liberalluz](https://github.com/liberalluz)

## 六、行为期望

本仓暂不单设 `CODE_OF_CONDUCT.md`，先按下列四条执行：

1. **对事不对人** —— 技术分歧用依据与可观测断言解决，不用资历。
2. **不催单** —— 时限见 §七；超时可以直接问，但同一议题不重复顶帖。
3. **不代填** —— 别人负责的取值（§一 后三行）不代填，哪怕你觉得答案显然。
4. **不自证** —— 不把「我这边能跑」当证据。

违反的处理：maintainer 可锁定讨论、关闭 PR、拒绝后续贡献。正式行为准则（Contributor Covenant 2.1）在贡献者规模扩大后补，届时本节改为指针（触发阈值**待定**）。

## 七、响应时限

| 事项 | 时限 |
|---|---|
| issue 首次回应 | 7 个工作日内（口径同 [`SECURITY.md`](SECURITY.md)） |
| PR 首次评审意见 | **TBD** —— 未定，暂按 issue 的 7 个工作日执行 |
| 长期无更新的 PR 关闭 | **TBD** —— 未定，现行做法是先问一次再判断 |

⚠️ 以上**不构成 SLA**，是维护者的尽力值。改动这两条属 §一 的「对外承诺」，须经显式公告。

## 八、许可与署名

- 提交即表示你同意以 **Apache-2.0** 分发该贡献（见 [`../LICENSE`](../LICENSE)、[`../NOTICE`](../NOTICE)）。
- **DCO**：提交须用 `git commit -s` 附 `Signed-off-by: 你的名字 <邮箱>`，声明你有权提交该内容（文本见 [developercertificate.org](https://developercertificate.org/)）。这不是版权转让，著作权仍归你。
- **内容包**（`content/`）的知识内容须为原创，或来源许可与本项目兼容；**不得引入** CC-BY-NC、GPL / AGPL 来源的文本与素材（判据见 [dependency-licenses §二](../docs/guides/dependency-licenses.md)）。内容勘误不改变原作者署名。
- 引入第三方代码 / 素材须**同批**登记到 [`../NOTICE`](../NOTICE) 与 [依赖许可清单](../docs/guides/dependency-licenses.md)。

## 附：本地环境

Flutter / Dart / Serverpod 版本以 `app/pubspec.yaml` 与 `server/pubspec.yaml` 的钉定值为准，**不跟最新**。环境搭建与 Windows 首构的已知坑（符号链接、开发者模式）见 [`docs/guides/environment.md`](../docs/guides/environment.md)。

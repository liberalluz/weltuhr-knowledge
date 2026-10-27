# Git 规范

> 活文档，不设版号。**流程与格式权威处**：仓库结构 · 分支 · 提交 · 评审与合并 · 版本与 tag · 交付物版号。
> **本文件管不到的**：协作治理（谁能改哪一级裁定 · 角色 · 许可与 DCO · 行为期望 · 响应时限 · **评审关注点**）见 [`.github/CONTRIBUTING.md`](../../.github/CONTRIBUTING.md)，此处不重复。



---

## 一、仓库结构

### 1.1 顶层五目录

单一仓库（monorepo），五个顶层目录与 commit scope **一一对应**：

| 目录         | 内容                                                              | 版本节奏                       |
| ---------- | --------------------------------------------------------------- | -------------------------- |
| `app/`     | Flutter 客户端（Windows / macOS / iOS 一套代码）                         | 产品版本 `vX.Y.Z`（§五）          |
| `server/`  | Serverpod 服务端（事件同步 · HLC 合并 · 鉴权）                               | 与客户端**同一产品版本** `vX.Y.Z`（§五） |
| `content/` | 内容包源数据与构建管线（每空间一目录 + `tools/build.py`）                          | 独立内容包版本（§五）                |
| `docs/`    | 软件工程文档（`specs/` `intent/` `runbooks/` `decisions/`）              | 活文档不设版号（§六）               |
| `infra/`   | 构建 / 打包 / 签名 / 更新器 / CI                                         | 随产品版本                      |

**入库判据**：源数据（json / md / 脚本）入库；**构建产物不入库**。

| 产物                                                               | 处置            |
| ---------------------------------------------------------------- | ------------- |
| 内容包 `dist/`（由 `content/tools/build.py` 生成）                       | 排除，须本地构建      |
| `.dart_tool/` · `build/` · `*.iml`                               | 排除            |
| 平台 ephemeral（`app/*/flutter/ephemeral/`）· `Pods/` · `.symlinks/` | 排除            |
| 安装包 / 签名产物 / 导出件                                                 | **不入库**：走制品分发 |
| 服务端密钥（`config/passwords.yaml` 等）                                 | 排除；生产经环境变量注入  |

### 1.2 仓库级文件与三级 README

| 文件                        | 作用                       |
| ------------------------- | ------------------------ |
| `README.md`               | **项目落地页** —— 八节，节名与节序固定  |
| `LICENSE` + `NOTICE`      | Apache-2.0 全文 + 版权与变更声明  |
| `.gitignore`              | 构建产物排除；判据见 §1.4          |
| `.github/SECURITY.md`     | 漏洞报告渠道与响应承诺              |
| `.github/CONTRIBUTING.md` | 协作治理（**格式类规则引用本文件，不复制**） |

**三级 README 分工（引用不复制）**：

| 层级   | 文件                                                 | 角色                                             |
| ---- | -------------------------------------------------- | ---------------------------------------------- |
| 仓库根  | `README.md`                                        | **落地页** —— 定位 · 特性 · 快速开始 · 目录导航 · 许可署名 · 贡献入口 |
| 顶层模块 | `app/` `server/` `content/` `infra/` 的 `README.md` | **模块入口** —— 职责 · 本模块命令                         |
| 文档   | `docs/README.md`                                   | **文档索引** —— 目录分工与版号口径（**不写项目介绍**）              |

- **根 README 必需**：平台取 README 的顺序是 `.github/` → 仓库根 → `docs/`，取第一个找到的。缺根 README 时仓首页展示的是文档索引，不是项目介绍。
- **一律相对链接**：绝对链接在克隆 / 换域名后失效。

### 1.3 社区健康文件（`.github/`）

统一落点 `.github/`，使仓根只留 `README.md` / `LICENSE` / `NOTICE`。

| 文件                         | 状态            | 说明                                                     |
| -------------------------- | ------------- | ------------------------------------------------------ |
| `.github/SECURITY.md`      | ✅ 已落          | 支持版本 · 私密报告渠道 · 勿用公开 issue 报漏洞 · 响应时限                  |
| `.github/CONTRIBUTING.md`  | ✅ 已落（**完整版**） | 本文件只管**流程与格式**，**没有**角色 / 权限边界 / **评审关注点** / DCO / 行为期望 ⇒ 治理类无对家，故落完整版；其流程与格式部分**引用本文件、不复制** |
| `CODE_OF_CONDUCT.md`       | ⏸ 暂缓          | 无可执行的社区即空义务；公开接受外部贡献时再补                                |
| `CITATION.cff`             | ⏸ 暂缓          | 仅学术引用场景需要；且只能放仓根，会打破本节统一落点                             |
| `PULL_REQUEST_TEMPLATE.md` | ✅ 已落          | 「1 批次 = 1 PR + 自审留痕五行 + 交付物 + AI 参与 + 批次号」已固化；正文形态只此一处，判据见 §4.1 |

**文件名是英文，内容也只一份英文**：`SECURITY` 与 `CONTRIBUTING` 各一份、**不出译文** —— GitHub 按精确文件名读取（Security 页与新 issue / PR 界面），而治理与安全承诺若有两种措辞会引发歧义。语言规则见 [`../AGENTS.md`](../AGENTS.md) §译本规范，此处不复制。

### 1.4 `.gitignore` 判据

- **带斜杠的模式锚定在 `.gitignore` 所在目录**：仓根写 `dir/*` 管不到子目录同名路径 ⇒ 子目录需自己的 `.gitignore`，或改用**只有尾斜杠**的 `dir/` 形式（逐层匹配）。
- **判据不用 `git check-ignore` 查目录** —— 对目录会误报。权威判据 = **`git add -A --dry-run`**。

### 1.5 换行与二进制（`.gitattributes`）

仓根 `.gitattributes` 是**换行治理的唯一落点**。三条规则：

| 规则 | 内容 | 理由 |
|---|---|---|
| 默认 LF | `* text=auto eol=lf` | 消除 `core.autocrlf=true` 的「LF will be replaced by CRLF」噪音；三端克隆出的工作区一致，不产生「只有换行不同」的伪 diff |
| Windows 脚本例外 | `*.bat` `*.cmd` `*.ps1` → `eol=crlf` | 这些脚本在 CRLF 下才稳定运行 |
| 二进制显式声明 | 图像 / 字体 / 音视频 / 归档 / 可执行 / 数据库 → `binary` | 禁换行转换与文本 diff；不声明时 Git 可能按文本处理而损坏文件 |

**判据**：`.gitattributes` 必须存在且含 `eol=lf`（`check_s0.py` 检查）。

> ⚠️ **加入时机**：`.gitattributes` 只影响**入库时**的规范化。若索引中已有 CRLF 文件，加入后须跑一次 `git add --renormalize .` 并**单独成一笔提交** —— 否则会在后续每次修改这些文件时产生「全文件重写」的伪 diff。
> 本仓索引已是 LF（`core.autocrlf=true` 在入库时已转换），故首建时**无需** renormalize。

---

## 二、分支

**trunk-based**。

| 分支               | 角色                     | 生命周期     |
| ---------------- | ---------------------- | -------- |
| `main`           | 主干，常驻可发布；**只接受 PR 合入** | 长期       |
| `<type>/<topic>` | 特性 / 修复 / 文档           | 短期，合入后删除 |

- `<type>` 取提交类型（`feat` / `fix` / `docs` / `refactor` / `test` / `chore`），`<topic>` 小写连字符。示例：`feat/quick-locate` · `docs/design-spec` · `fix/hlc-clamp`。
- **不建**长期 `develop`，**不建**常驻 release 分支。
- **唯一例外**：**仓库初始化首提**（骨架 + `.gitignore` + `LICENSE` + 根 `README.md` + `.github/SECURITY.md` + 本文件 + 模块入口 README）可在 `main` 直接完成 —— **全局仅此一次**，其余一律走 PR。
- ✅ **远端分支保护已启用**（仓库转 public + `main` branch protection）：`main` 必须走 PR，required checks 为 `app-checks` / `content-checks` / `repo-hygiene` / `platform-gate`，管理员同样受约束，禁强推、禁删除。近端 `.githooks/pre-push`（本地，`git push` 当场失败）与 `repo-hygiene` 的「main 只接受 PR」仍保留，作为纵深防御。`pre-push` **同时管引用类型**：只放行 `refs/heads/*` 与 §五 命名的 tag。
- 装置只拦「忘了」，不拦「故意」——`--no-verify` 与手写伪编号都绕得过去。**不因技术上没拦住就当作允许**。开关清单见 §4.3。

### 2.1 clone 后第一件事：让钩子真正生效

```bash
git config core.hooksPath .githooks   # 每台机器设一次
git config --get core.hooksPath       # 自查：应回显 .githooks
```

`core.hooksPath` 是**本地配置，不进仓库** —— `.githooks/pre-push` 在库里，钩子却不会自动启用。这是本装置**唯一的失效方式**：文件看着都在，`git push` 时一行也没跑。新克隆、换机、重装后必跑上面第一句。

不设的后果不是「没有保护」，而是**保护降级为事后**：本地不再当场失败，直推 `main` 改由 `repo-hygiene` 判红 —— 但那时远端已经脏了。故这条是**必跑**，不是建议。

> Git 没有「仓库自带钩子自动启用」的机制（`core.hooksPath` 只能靠本地或全局配置），这是 Git 的限制，不是本仓的疏漏。要彻底免设只能靠平台侧分支保护，而当前账号类型不提供（见上）。入口处的一句话指向见 [`.github/CONTRIBUTING.md`](../../.github/CONTRIBUTING.md) §二。

### 2.2 一批的固定动作

每批（1 批 = 1 PR）固定走这七步，**顺序不可换**。第 1–3 步与第 6–7 步由 `batch.py` 完成，第 4–5 步是人的活。本节只记**序列与命令**，每步的判据在各自章节，不在此复述。

前置：`core.hooksPath` 指向 `.githooks`（§2.1）。没设，下面每一步的钩子判定一行都不跑。

| # | 动作 | 命令 | 判据 |
| -- | -- | -- | -- |
| 1 | 建卡，批次号由 CLI 分配 | `batch.py plan --auto-id --type <process\|feat> --goal … --allowed …` | 一张卡只装一个目标；`allowed` 列显式路径或 glob |
| 2 | 人审 | `batch.py approve <id> --chat --confirm <hash8>` | 由用户确认；agent 不得自批，改卡后 hash 失效须重批；确认形态见下 |
| 3 | 启动 | `batch.py start <id>` | 建分支 + `state.json` + `scope.json` + `.batch/active` |
| 4 | 改文件 → 显式暂存 → 提交 | `git add <path> …` → `git commit -s` | §三 · `.githooks/commit-msg` |
| 5 | 推分支（本批一次） | `git push -u origin <branch>` | `.githooks/pre-push`：`active` · scope · 引用类型 · 非快进 |
| 6 | 检查 → 开 PR | `batch.py check --batch <id>` → `batch.py pr --batch <id> --create --yes` | 正文形态见 §4.1（九节 + 十四条判据） |
| 7 | squash 合入 → 合后收口 | `batch.py merge --pr <n> --dry-run` → `--yes` → §4.2 四步 | §4.2 |

**批次 ID 由 CLI 分配，不手写**：形态 `YYYYMMDD-<6 位小写十六进制>`。`plan` 不给 `<id>` 即自动生成（与 `--auto-id` 等价，两者同时给会报错）。手写序号（`C1`、`C2` …）只存在于旧批次，不再新增。

**批次独占与 scope guard**（`batch.py start` 的 active 校验 + `pre-push` 第四条）：

- 同一时刻只允许一个 `.batch/active`；`start` 发现它属于别的批次会拒绝，**不要手工覆盖**，先结束当前批次。
- 非 `main` 分支没有 `.batch/active` 时**直接拒推**（fail-closed，不是提示）。删除分支、推 tag、`--range` 回放不在此列。
- 推送路径必须落在该批 `scope.json` 的 `allowed` 内。扩范围只能 `check.py --scope <scope> --add <path> --reason <…> --yes`，并由人确认后落盘 —— 不直接改卡片。

以下四处最容易漏，单独强调：

- **第 2 步的确认形态**：`--chat --confirm` 这条路只比对 hash，**不打印卡片、不读 stdin**（不带 `--chat` 的 TTY 路才会打印卡片全文并等输入）。所以「让人看见并点选」完全落在对话层：**先出问答卡片，拿到「批准」后才允许传 `--confirm`；未出卡片就 `approve` 一律算自批**。`approval.by` 优先记 GitHub 登录名（`gh api user --jq .login`），取不到回退 `git config user.name`、再回退 OS 用户 —— 它只是留痕，真正放行仍是平台上那道非作者 approve。

- **第 4 步**：`git add -A --dry-run`（§七）只用来**检查**有无意外文件，**不是提交方式**。暂存一律列显式路径 —— `-A` 会把 `tmp/`、本地配置、半成品一起带进去，且事后从 diff 里看不出是「顺手带上的」还是「本来就该改」。
- **第 5 步一批只执行一次。** 本批全部 commit 落盘后推一次，不得「改一笔 → push → 等 job 全绿 → 再改下一笔」。四支 workflow 都设了 `concurrency.cancel-in-progress: true`，注释写的是「同一分支连续推送时只保留最新一次」—— 它要的是**连着推**；逐笔等绿等于每笔都跑到自然结束，取消机制零触发，一批的等待从 1 轮变成 N 轮。**判据**：本批 `git push` 调用次数 = 1；`gh run list --branch <分支> --limit 10` 里不存在「上一条 `completed` 之后才出现下一条」的串行链。第 5 步之前须有一次本批全量自验证（`flutter analyze` · `dart run tool/lint/check.dart` · 触及 `dart:ffi` 时单文件 `dart analyze` · `flutter test` · `dart run tool/docs/check.dart`），按笔只跑改动面相关的，全量只在这里跑一次。⚠️ **这五项与 §七 是同一个集合，少跑其中任何一项即算未跑** —— `lint` 是本地唯一能拦住 `R5`（用例名未声明守哪条裁定）的门，它只在 CI 里报就意味着一轮往返。
- **第 6 步**：正文由 `batch.py pr` 从卡片与 `evidence.log` 生成，落 `.batch/<id>/pr-body.md`，**生成即校验**，不过就不建 PR；`gh pr create` 本身**不读** `.github/PULL_REQUEST_TEMPLATE.md`（缺省无自动读取行为，`--template <file>` 可显式指定骨架），Web UI 那一趟才由服务端渲染模板。要手写正文时，骨架以模板为准（**九节**标题与顺序 · 自审留痕五行名称），形态由 `.githooks/pr-body` 判 —— 本地与 `repo-hygiene` 共用同一份，十四条判据只此一处。装置**只判形态、不判内容是否成立**：反证有没有被写成自证，仍只能人看。

### 2.3 失败处置

下列情形在 2026-10-22 的 15 笔 PR 上**全部实际发生过**，且已验明是**通道间歇故障**，不是配置错误 —— **不要改 `remote`、不要清代理、不要提权**。同期 `gh` 走同一代理往往正常，可作为「是通道、不是配置」的对照判据。

| 步 | 现象 | 处置 | 判据 |
|---|---|---|---|
| 5 | `git push` 报 `CONNECT tunnel failed, response 502` · `schannel: server closed abruptly (missing close_notify)` · `Failed to connect to github.com:443 after N ms` | 先**重试**（实测第 3 次成功）；连续全败改走 SSH 一次性 refspec，**不改 `remote`**：`GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10" git push git@github.com:<owner>/<repo>.git <branch>` | 远端 ref sha == 本地 `HEAD`：`gh api repos/<owner>/<repo>/git/ref/heads/<branch>` |
| 6 | 正文写错（项数 / 漏栏 / 措辞） | `gh pr edit <n> --body-file <file>` 改正，**不重开 PR** | `gh pr view <n> --json body` 回读 |
| 6 | 正文「动了 N 条路径」与 diff 对不上 | 以 `gh pr diff --name-only` 的**行数**为准；**同一文件被两笔改过按文件去重**，不能把两次的条目数相加 | `gh pr diff --name-only \| wc -l` == N |
| 7 | `gh pr merge --squash --delete-branch` 打 `CONNECT tunnel failed` / `missing close_notify` / `warning: not possible to fast-forward to main` | **不是合并失败**：它合完会自己 fetch 一次，失败的是那一步 | `gh pr view <n> --json state,mergeCommit` → `state` 为 `MERGED` |
| 7 | 合并后 `git branch -D <branch>` 报 `not found` | 正常：`--delete-branch` 已连本地段一起删 | `git branch` 里确无该分支 |
| 8 | `git fetch --prune` 报 502 | ① 走 SSH 并**带显式 refspec**：`git fetch --prune git@github.com:<owner>/<repo>.git '+refs/heads/*:refs/remotes/origin/*'`；② 仍不通则 `gh api` 取远端事实 + `git branch -dr origin/<branch>` 手工清 tracking ref（纯本地操作，不碰远端） | `git rev-parse main` == `git rev-parse origin/main` |
| 8 | `git fetch <url>` 之后 `origin/*` 没更新 | 只写 URL 不带 refspec ⇒ 内容只进 `FETCH_HEAD`，不进 `origin/*`，已删分支也不会剪 | 同上 |
| 8 | 合并后发现 `main` 末条提交**没有 `(#NNN)`**，或 `git log -1 --format=%cn` 不是 `GitHub` | **说明 `main` 被本地重写过**（`--squash` 合出来的提交，committer 恒为 `GitHub`）。**不要再 amend + 强推去修** —— 那会第二次改写历史：sha 全变、`(#NNN)` 照样可以再丢一次（`pre-push` 旧版的标题判据挡不住带号的强推） | 不改历史：开一个 PR 把「为什么会丢」补成判据，正文追认哪几笔受影响；`git log -1 --format='%cn %s'` 回显 `GitHub … (#NNN)` |

> **`fetch` 报错不等于收口失败**：`gh pr merge` 自己会 fetch，本地 `main` 常已被快进。收口判据永远是 `main` 与 `origin/main` 两个 sha 相等，不是「`fetch` 有没有报错」。

---

## 三、提交信息

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 3.1 type（必填，11 种）

> **值域出处**：集合与 [`@commitlint/config-conventional`](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional) 的 `type-enum` **完全相同**，故按字母序排列，便于与出处逐行核对。该配置被 Conventional Commits 1.0.0 正文（§4）列为推荐示例（该规范自身只 MUST 规定 `feat` / `fix` 两个）；比 Angular 现行 8 值多 `chore` / `revert` / `style`。
> **排序不承载语义** —— 判定只看值是否在集合内，顺序不影响 `.githooks/commit-msg` 的正则匹配（11 值两两无前缀关系）。

| type       | 说明             |
| ---------- | -------------- |
| `build`    | 构建系统或外部依赖变更    |
| `chore`    | 其他杂项           |
| `ci`       | CI 配置 / 脚本变更   |
| `docs`     | 仅文档变更          |
| `feat`     | 新功能            |
| `fix`      | 修复 bug         |
| `perf`     | 性能优化           |
| `refactor` | 重构，非新功能也非修 bug |
| `revert`   | 回滚             |
| `style`    | 不影响语义的格式调整     |
| `test`     | 新增或修改测试        |

### 3.2 scope（必填，6 值，与顶层目录一一对应）

| scope    | 覆盖                              |
| -------- | ------------------------------- |
| `app`    | Flutter 客户端                     |
| `server` | 服务端                             |
| `pack`   | 内容源数据与构建管线（目录名 `content/`）      |
| `docs`   | 软件工程文档（`docs/`）                 |
| `infra`  | 构建 / 打包 / 签名 / 更新器 / CI         |
| `repo`   | 仓库级配置（`.gitignore` · 模板 · hook） |

> **子维度不进 scope**：写成 `feat(pack/python)` 会破坏 Conventional Commits 解析；空间 / 语种等子维度放 subject 或 body。
> **一笔只落一个 scope**：确实同时动两个顶层单元时（如改规范 + 同步钩子），取**主改动方**作 scope，另一处写进 body —— 不写 `docs(repo,docs):`，Conventional Commits 不支持多 scope。
> **必填的理由**：漏了 scope 的标题（`docs: …`）与规范形态（`docs(docs): …`）在 `git log` 里只差五个字符，扫一眼看不出、`grep` 也分不出哪条是漏的 ⇒ 判据不拦，就等于全凭手写时记不记得。`scope` 与 `type` 同级，同样必填。

### 3.3 subject / body / footer

- **subject**：祈使句、句尾不加句号、**≤ 72 字符**。
- **body**：与 header 空一行，解释「**为什么**」与「**做了什么**」，不复述代码。
- **footer** 每个占一行，格式 `Token: Value` 或 `Token #value`：

| 用法            | 写法                                                |
| ------------- | ------------------------------------------------- |
| 破坏性变更         | `BREAKING CHANGE: <说明>`（**大写**，后接 `: `）           |
| 关联 Issue / PR | `Closes #123` · `Fixes #123` · `Refs #123`        |
| 联合署名          | `Co-authored-by: 姓名 <邮箱>`                         |
| 审查（按需）        | `Reviewed-by: 姓名 <邮箱>`                            |
| **签署（每笔必带）**    | `Signed-off-by: 姓名 <邮箱>` —— 用 `git commit -s` 自动追加 |

> `Signed-off-by` 是 **DCO 签署**，不是「有时加一下」的装饰：缺它的提交会被 `.githooks/commit-msg` 直接拒（本地与 CI 同一个文件，见 §3.5）。它只约束**分支上的原始提交** —— `main` 上的 squash 提交不受此判据约束，签名能否随 squash 落到 `main`，取决于平台如何拼接消息；本仓实测单笔与多笔都会保留，但不作保证。规则生效前未带签名的历史提交**不追改**。

### 3.4 切分纪律

- **代码与文档分开提交**，不混提。
- 一次提交只做一件事；重构与行为变更不混在一个提交里。
- 落痕：合入后在 PR 标题保留 `(#PR号)`。

### 3.5 判据

| 判据 | 层 | 落点 | 何时生效 |
| --- | --- | --- | --- |
| 提交信息格式（§3） | 本地 | [`.githooks/commit-msg`](../../.githooks/commit-msg) | 每次 `git commit`；**一次性启用**：`git config core.hooksPath .githooks` |
| 同上 | CI | `repo-hygiene` 的「提交信息」步骤 | 每个 PR 与每次 push，只校验本次新增的提交 |
| DCO 签署（§3.3） | 本地 | 同 `.githooks/commit-msg` | 每次 `git commit`；无行首 `Signed-off-by:` 直接拒 |
| 同上 | CI | 同上 `repo-hygiene` 步骤 | 同一次 `--range` 调用，逐条校验 PR 新增提交 |
| 提交前格式/空白（C6） | 本地 | [`.githooks/pre-commit`](../../.githooks/pre-commit) | 每次 `git commit`；暂存 Dart `dart format` / app `flutter analyze` / `git diff --cached --check`；同一句 `core.hooksPath` |
| 推 `main` 必走 PR（§二 / §4.1） | 本地 | [`.githooks/pre-push`](../../.githooks/pre-push) | 每次 `git push`；同一句 `core.hooksPath` |
| 非 main 分支必须有 active batch（C16） | 本地 | 同 `.githooks/pre-push` | 每次 `git push`；无 `.batch/active` 直接拒；删除 / tag / `--range` 除外 |
| 同上 | CI | `repo-hygiene` 的「main 只接受 PR」步骤 | 只在 push 到 `main` 时；PR 事件不跑 |
| tag 命名（§五） | 本地 | 同 `.githooks/pre-push` | 每次 `git push`；只放行 `vX.Y.Z` · `pack/<space>/vX.Y.Z`，其余拒；删除放行 |
| 同上 | CI | — | **无**：`on.push` 只挂 `branches: [main]`，推 tag 不触发 workflow |
| PR 标题形态（§4.1） | — | **无装置** | 平台字段，`git` 改不到、钩子也拦不住 ⇒ 只能在开 PR 时写对（`gh pr create --title` 与提交 header 同一句），并定期 `gh pr list --state all` 与 `git log` 对账 |

每条判据的本地与 CI **共用同一个脚本**，不各写一份。两份判据等于没有判据：本地放行、CI 红，人会去改 CI 而不是改提交；反过来 CI 放行、本地红，人会 `--no-verify`。

**直推判据的取法**：不判「目标是不是 `main`」，判「这次推上去的**每个提交标题是否带 `(#NNN)`**」。`(#NNN)` 不是提交字段，而是 squash 合并时由平台写进标题的纯文本 —— 有它 ⇔ 走过 PR。这样一条正则同时放行了两种合法情形：本地 `main` 与远端已同步（区间为空）、仓库初始化首提（远端 `sha` 全 0）。另有一条：删除 `main` 直接拒（§4.3 `Allow deletions` ❌）。

**tag 判据的取法**：不判「是不是 tag」就拒 —— §五 要求发布时打 tag，一律拒会把正事挡掉。取**命名白名单**：只有 §五 那两种形态放行，其余拒；删除远端 tag 放行（误推要能回收，拒删除只会逼人 `--no-verify`）。⚠️ **原写法有个静默漏洞**：`case "$remote_ref" in refs/heads/main) ;; *) continue ;;` 把 tag 一起丢进了「不是 main 就跳过」的分支 —— 于是备份 tag 一路无阻。现在先分引用类型，再谈 `main`。

校验项：`type` 11 值 · `scope` **必填**、6 值之一 · `subject` 非空、≤ 72 字符、句尾不加句号 · header 与 body 之间空一行。

> **按字符数计，不按显示宽度**。72 个汉字的 subject 合规，而它在等宽字体下占 144 列 —— 这是刻意的：显示宽度随字体变化，进不了判据。

跳过形态：`Merge …` · `Revert "…"` · `fixup!` / `squash!` / `amend!` —— 前两者由 git 与平台生成，后三者是 rebase 中间态，最终都会被合掉。

> ⚠️ **判据只拦「新写的」提交**。规范 2026-10-17 进仓到判据上线之间产生的越界提交（`view` / `plan` / `core` / `tool` / `test` / `content` / `b13a` / `deliverables` 共 37 条）已于 2026-10-21 统一改为六值；**历史不再因格式问题重写**——改错往前走，靠提交前拦。同样地，`scope` 改为必填**之前**已合并的无 scope 提交**不追改**：改一条标题要重写 `main`，并让区间内所有提交的 committer 从平台变成本地，代价远大于收益。判据只校验 PR 新增提交，这些历史提交不会让 CI 变红。
>
> **PR 标题侧同一笔账**：上一次只改了提交标题，平台上的 PR 标题没跟着改，于是列表里残留 38 条旧 scope。已于 2026-10-25 按「旧 scope 值 → **它所属的顶层目录**」全部改齐 —— `view` / `plan` / `core` / `tool` / `test` / `events` → `app`（全在 `app/lib` 或 `app/tool`）· `content` → `pack` · 笔号 `b13a` / `deliverables` → `docs`；并顺手把 8 条与 `git log` 文案不一致的（`#140` `#115` `#82` `#81` `#69` `#67` `#23` `#22`）对齐到提交标题。现状：163 条 PR 标题 0 条越界。这类改动**只动平台字段、不重写历史**，代价低，所以与「历史不追改」不冲突。

---

## 四、评审与合并

### 4.1 评审

| 项           | 规则                                                                          |
| ----------- | --------------------------------------------------------------------------- |
| 入口          | 一律走 **PR**；`main` 禁止直推（首提例外见 §二）                                            |
| 标题          | 与提交 header **同形态**：`type(scope): subject`，`scope` 必填、取 §3.2 六值之一；与合并后写进 `main` 的提交标题**逐字一致**（`(#NNN)` 后缀除外）。PR 标题是**平台字段**，`git` 改不到 |
| 粒度          | **1 批次 = 1 PR**；批次是最小的排期单位。一个 PR 只承载一个可描述的交付；一批拆多个 PR 时正文必标批次号 |
| approval 数量 | **按维护者人数**：单人维护期 **0**（以「PR 正文自审留痕」替代评审；平台**不允许自批**）· **≥2 位维护者起 1**（且须非作者） |
| 无人数豁免的情形    | **契约 / 事件 schema / 内容包格式**变更 —— 无论人数变动，须他人评审                                |

> **approval 与「评审」是两件事**：前者是平台开关的配置值，后者是流程要求。单人期 approval = 0 **不等于**免评审 —— 评审由 PR 正文的**自审留痕**承担。
> **「反证」不得写成自证**：写「跑了测试、全绿」不算证据；要写「为推翻它做过什么尝试 · 结果如何 · 哪些没验」。

#### 正文结构

九节固定、标题逐字，顺序不判。各节无内容时写什么：

| # | 节 | 无内容时写什么 |
|---|---|---|
| 1 | 变更摘要 | 不适用（必有一句为什么） |
| 2 | 影响面 | `平台：无`，且不挂子项 |
| 3 | 自审留痕 | 不适用（五行必填） |
| 4 | 验证 | `未验：无` |
| 5 | UI 证据 | `无` |
| 6 | 交付物 | `无`，不补理由 |
| 7 | AI 参与 | 不适用（三字段必填） |
| 8 | 关联 | `无`（整节一行） |
| 9 | 评审提示 | `无`（单人维护） |

形态以 [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) 为准；`gh pr create` 不读模板，正文须照它手填。

#### 判据（十四条）

| # | 判据 | 判什么 |
|---|---|---|
| 1 | 九节齐全、标题逐字 | 形态 |
| 2 | 自审留痕五行齐全；分支基线 sha 可解析 | 形态 + 真假 |
| 3 | 禁 `- [ ]`（剥行内代码后判） | 形态 |
| 4 | 如实登记 0 / 1 / N，压段判红，不设总述 | 形态 |
| 5 | 改动面首行 N/M/K 且 N 与 diff 行数对账；条目含全角冒号且冒号前非路径；K=0 禁「未动」条目 | 形态 + 真假 |
| 6 | 技术栈字段与表只在跨 ≥2 栈时出现；出现即字段与表成套、四栈全集；标「是」的在 diff 里找得到 | 形态 + 真假 |
| 7 | 反证须含「未验」 | 形态 |
| 8 | 多行条目无编号前缀 | 形态 |
| 9 | 反证 ≥2 件不压同一行 | 形态 |
| 10 | 字段行只写字段名（例外：改动面首行 N/M/K、反证一句总述） | 形态 |
| 11 | 正文路径须在本仓 | 真假 |
| 12 | PR / issue 号写成显示链接；裸号与反引号包号判红 | 形态 |
| 13 | 各节字段齐全：影响面三字段、验证三字段、AI 三字段且级别在五级内 | 形态 |
| 14 | 关联八类封闭集、逐条一行、缺类不写 | 形态 |

**影响面三字段 + 一个条件组**：`平台`（组）· `类型` · `兼容与回滚` 三字段常驻；`技术栈`（组）只在 diff 跨 ≥2 栈时出现，跨 <2 栈**整组不写** —— 字段行与表都不写，也不写「无」。`平台` 按平台一行，形如 `<平台>：已测 —— <证据>` 或 `<平台>：未测 —— <原因与谁验>`，平台名限 `Windows` / `macOS` / `iOS`，同一平台重复判红；无平台影响写 `平台：无`，且不挂子项。`技术栈` 出现时字段行不写值，表挂本节末尾、不缩进，表头逐字 `| 模块 | 是否改动 | 说明 |`，四栈 `app` / `server` / `content` / `infra` 各一行；字段与表**成套**，只写一半判红。

**AI 参与级别**五值：`hint`（只给提示或片段）· `assist`（人主导，AI 补局部）· `pair`（交替落盘，人逐段核）· `copilot`（AI 主写，人逐行核）· `auto`（AI 全自动，人只终审）。

**关联八类封闭集**：批次号 · 里程碑 · issue · PR · ADR · 规格条 · 用例 · 待确认事项。只列有锚点的类，缺的类整行不出现；0 锚点整节一行 `无`；按上述次序排。

`未测` 管平台、`未验` 管手段，同一件事只出现在一处。

#### 形态细节

装置判上述十四条，下列是评审看的部分：

| 项 | 规则 |
|---|---|
| 字段行 | `- **名称**：<内容>`，全角冒号，名称粗体 |
| 条目 | 两格缩进 + `- `，一条一行 |
| 改动面条目 | `<做了什么>：<范围与依据>`，路径在后 |
| 并列 | 同一件内部可用 `；`；跨件必须分行 |
| 未动 | 一行写完，不逐项展开理由 |
| 组名行 | `平台` / `技术栈` 不写值，值在下层（`技术栈` 仅跨 ≥2 栈时出现） |
| approval 数量 | 不写进正文（人数会变） |
| 列表内围栏 | 代码围栏缩进 2 格（`` `  ```text` ``），不缩进则代码块跑出列表 |

#### 执行

本地开 PR 前跑一次 `bash .githooks/pr-body --file <正文> --diff-base origin/main`；CI 在 `repo-hygiene` 的 `pull_request`（含 `edited`）时跑**同一文件、同一入口**。判据只此一份，本节不复述正则；`--self-test` 覆盖正例与二十二个负例。唯一判真假的是 `改动面` 的 N、判据 6 的栈数与标「是」的栈。

#### 判不了的三件

写进「如实登记」，不要假装判过：

- 反证是否被写成自证；
- 「一件事还是多件事」只有形式代理（`反证` 里的「为推翻」×2 与编号压段），换成「先试 / 再跑」这类接续写法抓不到；
- 「算不算受控配置项」本仓无定义。


### 4.2 合并策略

**默认 squash merge**。三种策略互斥，选定后**长期一致**。

| 维度                    | A · squash（默认） | B · merge commit       | C · rebase |
| --------------------- | -------------- | ---------------------- | ---------- |
| `main` 每条 PR          | 1 提交           | N 提交 + 合并点             | N 提交       |
| `main` 形态             | 线性             | 分叉（需 `--first-parent`） | 线性         |
| 评审迭代的 WIP 提交          | **吸收**         | 留在 `main`              | 留在 `main`  |
| 是否改写已评审分支             | 否              | 否                      | **是**      |
| `bisect` / `blame` 粒度 | 里程碑级           | 提交级                    | 提交级        |
| 整块回滚里程碑               | 一步 `revert`    | 需 `revert -m`          | 逐个         |

**选 A 的理由**：`main` 的 log 直接充当变更日志；评审中的「按意见改」被压缩，不污染主干；一个里程碑可一步回滚；且**不改写**已评审的提交集（approval 绑定在提交集上，改写即失效）。

**切换条件** —— 出现任一改用 **B**，**不用 C**：

- 里程碑体量大到必须 `bisect` 到提交级；
- 需同时保留完整提交史与 `--first-parent` 里程碑视图；
- 多人共写同一分支，需保留各人贡献轨迹。

> 「要留历史」的正解是 **B** 不是 C：A 与 B 都**不改写**历史（护住 approval 与已拉取分支的人），**C 会**。

**合后**（四步，缺一不算收口）：

1. **删源分支** —— 远端与本地**都要删**。远端由仓库开关自动删除（开关现状见 §4.3）；**本地不自动**。用 `gh pr merge --delete-branch` 时它会连**本地段**一起删，故随后的 `git branch -D` 报 `not found` 属正常，不是没删。
2. **`git fetch --prune origin`** —— 只清 `origin/*` 跟踪引用、给本地分支打上 `[gone]` 标记，**不删本地分支**，故须另跑 `git branch -D <branch>`。
3. **本地 `main` 前进** —— `git switch main` → `git merge --ff-only origin/main`。**`fetch` 只更新 `origin/main` 引用，本地 `main` 不会自己走**；漏这步，下一次从 `main` 切分支就切到合并前的旧点，PR 里的「分支基线」sha 随之失真。
4. **收尾判据** —— **五项全核**：① `git branch` 与 `git branch -r` 都只剩 `main`（远端 `origin/HEAD` 是符号引用，不计；**`[gone]` 不等于已删除**）② `git rev-parse main` == `git rev-parse origin/main`（只比分支列表**看不出**本地 `main` 是否真的前进了）③ `git log --oneline -1` 的标题带 `(#NNN)` ④ `git log -1 --format=%cn` 回显 **`GitHub`** ⑤ **本批手工造的 ref 一个不剩**。第 ④ 项不是重复：标题是**纯文本**，本地提交完全可以写得一模一样；`--squash` 合出来的提交 committer 恒为 `GitHub`，被本地改写过的提交 committer 是操作者 ⇒ **这一项才是「这笔是不是平台合的」的直接证据，也是历史被重写过的唯一痕迹**。
   - ⚠️ **只查本地分支是这套判据的固有盲区**：`--delete-branch` 只删**该 PR 的头分支**；为强推兜底、归档、对照而手工造的 ref（`refs/heads/backup/…`、`refs/heads/archive/…`）**从来没有对应的 PR**，上面四步里没有任何一步会碰它们，而「只剩 `main`」这句又隐含「所有分支都由 PR 产生」的假设 ⇒ 这类 ref 既不会被自动删、也不会被判据拦住。故判据第 ① 项要求两侧都查，第 ⑤ 项单独立一条。
   - **手工 ref 只允许在当批内存在，且同批清理**：造它的那一刻就定好删除时点，与造它的命令写在同一个会话里。不接受「先留着，以后再说」—— **无主的例外等于永久遗留**：没人负责、没有到期时间，下一个会话只会把它当成既有状态。

评审意见落 PR 正文 / 评论，`main` 只留里程碑结论。

### 4.3 `main` 保护开关与远端现状

| 开关                                    | 目标取值                                                                                                     |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Require a pull request before merging | ✅ 开（禁直推）                                                                                                 |
| Required approvals                    | **按维护者人数**：单人 **0** · ≥2 人 **1**（且非作者）。当前两名维护者，取 **1** |
| Require code owner review             | ✅ 开（当前两名 CODEOWNERS）                                                                                   |
| Require conversation resolution       | ✅ 开                                                                                                      |
| Allow force pushes                    | ❌ 关                                                                                                      |
| Allow deletions                       | ❌ 关                                                                                                      |
| Dismiss stale approvals               | ✅ 开                                                                                                      |

**远端开关现状（2026-10-27）**：

| 项           | 状态                                            | 说明                                                                                 |
| ----------- | --------------------------------------------- | ---------------------------------------------------------------------------------- |
| 合并方式        | ✅ squash 允许 · merge commit 允许 · **rebase 禁用** | 仓库级设置                                                                              |
| 合后自动删源分支    | ✅ 开                                           | 仓库级设置                                                                              |
| `main` 保护 | ✅ **ruleset 已启用**                             | public 仓库；管理员同样受约束                                                              |
| Required checks | ✅ `app-checks` · `content-checks` · `repo-hygiene` · `platform-gate` | 四者均为 always-on；三端 build job 仍为 advisory、不设为 required（避免 skipped「Expected」） |
| Approvals / code owners | ✅ 1 名非作者批准 · code-owner review            | 两名维护者均在 `CODEOWNERS`；作者不能自批                                                |
| Conversation resolution | ✅ 开                                           | 未解决讨论阻塞合并                                                                        |
| Merge queue | ⏸ deferred | 当前低并发；触发条件与开启/回滚步骤见 [merge-queue.md](../runbooks/merge-queue.md) |
| Force push / deletion | ❌ 拒绝                                      | ruleset 的 `non_fast_forward` / `deletion` 规则                                          |

**已验证（2026-10-27）**：`main` 使用 C10 ruleset，required checks 为上述四项，`pull_request` 规则要求
1 名非作者批准、code-owner review 与 conversation resolution；`non_fast_forward` / `deletion` 均禁止。
仓库可见性为 `PUBLIC`。

> 保护已启用；`.githooks/pre-push` 与 `repo-hygiene` 仍保留，作为近端与 CI 的纵深防御。

> 本节只定**语义**；开关名以平台现行界面 / API 为准，落地时逐项核对，**不凭记忆填字段名**。

### 4.4 变更分级（A/B/C/D）

> **定义权威处 = 技能 `references/dev-workflow.md` §S3**。本表落在项目内，因为 A/B/C/D 是 **PR 判据**，判据必须在项目内可查；两者冲突时**以技能 §S3 为准**。各级由谁批准，见 [`.github/CONTRIBUTING.md`](../../.github/CONTRIBUTING.md) §1。

| 级     | 判据                                     | 动作                                   |
| ----- | -------------------------------------- | ------------------------------------ |
| **A** | 改地基判据（KST 三元组 · `⪯` · 事件模型 · 通道表 · 协议） | 先出 ADR，评审后改                          |
| **B** | 改常量数值、事件类型、字段可空性                       | PR + 变更说明 + 回填 `docs/specs/` 横切表 |
| **C** | 措辞、注释、例子                               | 直接改                                  |
| **D** | 与 `docs/decisions/not-list.md` 冲突      | **不做**，除非推翻 NOT 条目并留痕                |

---

## 五、版本与 tag

**版本号的事实源是仓库内的声明文件**，本文件不重抄具体值。

| 对象  | 版本号                                           | 事实源                                                                                                      | tag         |
| --- | --------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ----------- |
| 客户端 | `vX.Y.Z`（SemVer 2.0.0，`+N` 为构建号）              | `app/pubspec.yaml` 的 `version`（当前 `0.1.0+1`，**开发期基线，未发布**）                                               | `vX.Y.Z`    |
| 服务端 | 与客户端**同一产品版本** `vX.Y.Z`                     | `server/pubspec.yaml` 的 `version`，须与 `app/pubspec.yaml` **逐字相同**（含 `+N` 构建号；字段名在脚手架生成后核对）                   | 与客户端**共用** `vX.Y.Z` |
| 内容包 | 单包 semver；合成版本 `pack@vX + overlay@N`（两个版本号独立） | `pack.json` 的 `meta.version`，见 `docs/specs/PACK-content-pack.md` §二 · `docs/specs/entity-fields.md` | `pack/<space>/vX.Y.Z` |

- **两端同版本**（`app/` 与 `server/`）：共用一个产品版本 `vX.Y.Z`，**一个 tag 覆盖双端**，不设 `server/` 或 `app/` 前缀。两端 `pubspec.yaml` 的 `version` 须**逐字相同**（含 `+N` 构建号）；不一致**视为构建错误**，由 CI 比对拦截（`server/` 脚手架落地时接入）。**理由**：两端靠事件 schema 通信，版本错配本身就是兼容问题；共用版本让「这个客户端能不能连这个服务端」一眼可判，不必再维护兼容矩阵。
- **协议变更的发布顺序**：**服务端先发，且向后兼容至少一个版本** —— 新服务端先上线并接受旧客户端写入（新字段缺省、未知字段不报错），客户端随后放量；摘除兼容层须在确认旧版本客户端无活跃设备后进行，并记 ADR。**禁止客户端先发**：新客户端会调用尚未存在的端点，属必然故障而非灰度风险。**依据**：iOS 审核周期不可控，若要求两端同批，服务端会被审核窗口阻塞数天到数周。事件 schema 变更属 **B 级**（§4.4），PR 须写明兼容策略，不写的不予合入。
- **内容包 tag：`pack/<space>/vX.Y.Z`** —— 例 `pack/python/v1.2.0`。`space` 取 `KnowledgeSpace.id`（稳定标识，与版本无关），版本取 `meta.version` 的 semver ⇒ tag 名不引入任何新标识。用 `/` 而非 `-`：`git tag -l 'pack/*/v1.*'` 可跨空间筛（`-l` 通配按 `/` 分段），且空间 id 含连字符时无解析歧义。**取某空间当前版本**：`git tag -l 'pack/python/*' --sort=-v:refname | head -1` —— **`--sort` 不能省**：默认是**字典序升序**，`head -1` 取到的不是最高版（实测：只有 `v1.2.0` 与 `v1.9.0` 时默认取到 `v1.2.0`）。**被否方案**：全局号 `pack-vX.Y.Z`（违反 `PACK-001`「空间可单独升级而不牵动别的空间」）· 连字符形态（解析歧义）· 不打 tag（无法从 git 侧回答「`python v1.2.0` 对应哪次提交」，且已定「打 tag 即对外承诺」）。
- **overlay 不打 tag** —— `overlay@N` 来自用户提交与审核、存在服务端 DB（`PACK-009`/`PACK-011` 两平面），**不在仓库里**。tag 只标记仓库内容，不在仓库里的状态层不设 tag。
- **只能打在全绿的 commit 上** —— `python content/tools/build.py` 全空间通过 + 校验器通过（DAG / 稳定 id / 六要件三态）。`dist/` 不入库（`PACK-018`），tag 是唯一指针，打在构建不过的 commit 上等于发了个拿不到的包。
- **打 tag 前 `CHANGELOG.md` 必须有对应版本条目** —— 每条含 `## vX.Y.Z — YYYY-MM-DD`、递增依据（major / minor / patch —— **产品条目套本节「递增判据 · 产品」表、内容包条目套「递增判据 · 内容包」表**，两张表标准不同，别混用）、**用户可感的变化逐条一行**（按 Added / Changed / Fixed / Removed 分组写分组标题）。**理由**：tag 是唯一指针、`dist/` 不入库，缺条目等于对外发了版，却没人能说出这一版变了什么。⚠️ **与 [`ADR-0009`](../decisions/0009-deliverables-dissolve.md) 不冲突**：该 ADR 把 `SVD` 版本说明的落点由根 `CHANGELOG.md` 改判到**出仓 `product/release-notes/`**（应用商店强制填 What's New，仓内 changelog 替代不了）。分工是：**仓内 CHANGELOG = 工程侧、绑 tag、判据可机检**；**出仓 release-notes = 对外文案**。本条要的是前者，不是把版本说明搬回仓内。**首次发版前建该文件**（当前未建）；**内容包**按需记在 `pack/<space>` 分组下，不强制每包一条。**版本号本身仍以声明文件为唯一事实源**，CHANGELOG 只记人读的变化，不重抄版本表。**判据**：最新产品 tag 名与该文件顶部条目的版本号**逐字一致** —— 只推了 tag、没写条目，即本步未完成。取最新产品 tag 用 `git tag -l 'v*' --sort=-v:refname | head -1` —— **`--sort` 不能省**：默认是**字典序升序**，只有 `v1.2.0` 与 `v1.9.0` 时会取到 `v1.2.0`（与内容包取法的坑同源）；**别用裸 `git tag -l`**，本仓 `backup/pre-*` 备份 tag 会混进来（它们按本节只留本地、不上远端）。
- **命名由 `pre-push` 判** —— 上表两种形态之外的 tag 一律拒推（备份 / 临时标记只留本地，永不进远端）；删除远端 tag 放行。⚠️ 「打在全绿的 commit 上」是**人工判据**，hook 只看得到 tag 名，判不了它指向哪条构建。
- **版本写在 `manifest.json`，不靠 `build.py` 生成** —— `manifest.json` 的 `version` 是包版本的**唯一事实源**（semver），`build.py` **原样透传**到 `pack.json` 的 `meta.version`，**不得改写**（否则同一 commit 两次构建产出不同版本，与「tag 是唯一指针」冲突）。tag 名中的版本须与之**逐字一致**（与「两端 `pubspec.yaml` 逐字相同」同族，可加机器校验）。
- **tag 用附注 tag**（`git tag -a`），消息 = 版本号 + 交付范围一行，**推送至远程**。
- **打 tag 即对外承诺**：首个 tag 的时机与版本号由维护者决策，本文**不预置**。

**递增判据 · 产品**（取本版变更性质中**最高**者）：

| 判据                            | 递增        |
| ----------------------------- | --------- |
| 有不兼容变更（提交标 `BREAKING CHANGE`） | **major** |
| 有新增功能（`feat`）                 | **minor** |
| 仅修复 / 文档 / 重构 / 性能            | **patch** |

**递增判据 · 内容包**（内容变更**不带 commit type 语义**，上表不适用；按「**是否让使用者既有进度失效**」判）：

| 判据 | 递增 |
| --- | --- |
| 删项 · 改条目 `Item.id` · 改 `⪯` 边 | **major** |
| 新增项 · 新增边 · 新增体系 | **minor** |
| 措辞 · 例子 · typo | **patch** |

只有会让用户既有进度失效的才配 major —— 与 `PACK-013`~`PACK-017` 的迁移事件化对齐：拆分记 `state_carried`、合并记 `state_merged`、删除记 `item_retired`，均由 `fold` 应用。**所以改条目 id 必须走迁移事件，不能原地改**（原地改 = 既有进度整体对不上，只能靠 major 明示）。

```bash
git tag -a v1.0.0 -m "v1.0.0 交付范围：（一句话）"
git tag -a pack/python/v1.2.0 -m "pack/python v1.2.0：新增 12 项 · 修订 3 项措辞"
git push origin v1.0.0
git push origin pack/python/v1.2.0
```

---

## 六、交付物版号

**版号口径的权威处 = [`docs/README.md`](../README.md) §一**：`specs/` `intent/` `runbooks/` `decisions/` 属活文档，**不设版号**，更新时间以 `git log` 为准（**不要求手写「最后更新」头** —— 手写头会变成第二份会过期的记录）。本仓自 `ADR-0009` `S7-3` 起不再存交付物，本节保留的是**该体系停用前的 git 侧约束**，供追溯当时为何这样定，不复述那套规则。

| 约束       | 内容                                                                                |
| -------- | --------------------------------------------------------------------------------- |
| 与代码版号的关系 | **同制式、独立递增** —— 交付物版号变化**不牵动**产品版本，也不触发打 tag                                      |
| PR 要求    | 触及带版号产物（§五 的产品 / 内容包版本）的 PR，正文须写明「版号 `vX.Y.Z → vA.B.C`」与递增理由（章节重构 / 新增章节 / 勘误） |
| 修订历史     | 文末「修订历史」表**逐版追加，旧行不删不改**；**纯格式规范化不追加行**                                           |
| 两段式历史    | 早期若用过 `v1.0` 这类两段式，等价映射为三段式（`v1.0` → `v1.0.0`）；**同一版本的不同写法不算版本变更**，不追加行           |

**与 `SCMP` 的分工**：本节只管**版号的 git 侧约束**（何时递增、如何留痕、与 tag 的关系）。**配置项识别的唯一权威处是 [`scmp.md`](controlled/scmp.md) §二 §三；基线登记的唯一定点是 [`../baselines.md`](../baselines.md)**，本节不复制基线表 —— 复制就有两份可改。

**本节为历史口径**（2026-10-17 至 2026-10-23）：当时 `docs/deliverables/` 建了六段 25 份，其中 `SDP` §4、`SCMP` §三、`SRS` §三、`DPMR` 前史与 `B1` 节、`STR` 不追溯声明写实，其余为骨架（各文件头注明填充时点），交付物版号规则自 2026-10-17 生效。2026-10-23 按 `ADR-0009` `S7-3` 删除该目录、交付物改由仓外托管，**本节约束随之停用**。`BL-1` 于 2026-10-17 登记（三笔 `#14` `#15` `#16`），见 `SCMP` §3.1；`BL-2`（`app/` 代码）同日登记并附已知缺口，见 §3.2。

---

## 七、提交前的自检

```bash
cd app
flutter analyze                      # 零 issue
dart run tool/lint/check.dart        # 架构规则（R1–R10）零违规
flutter test                         # 全绿
dart run tool/docs/check.dart        # 文档相对链接 + 受控文档门禁零违规
cd ..
git add -A --dry-run                 # 只看不暂存：确认无意外文件（不用 check-ignore 查目录，它对目录误报）
```

- **五项与 §2.2 第 5 步同一个集合**：两处列举不得分叉 —— 分叉的结果是照其中一处跑、漏掉只写在另一处的那项，而漏的那项往往正是当笔唯一会红的那道门。
- **`--dry-run` 是检查，不是提交方式**：实际暂存只 `git add <显式路径>`，禁 `git add -A` / `git add .`（见 §2.2 第 3 步）。两者命令长得像，容易混用 —— `-A` 在 `--dry-run` 下无害，去掉 `--dry-run` 就是把 `tmp/` 与本地配置一起推上去的那一步。

- 涉及内容包时另跑 `python content/tools/build.py`，确认包能构建。
- **PR 标题与提交标题是两个字段，两侧都要核**：squash 时平台拿 **PR 标题**生成提交标题，且**只生成一次** —— 之后改写历史不会改 PR 标题，改 PR 标题也不会改已在 `main` 上的提交标题。核法 = `gh pr list --state all` 与 `git log` **逐条比**（后者剥掉 `(#NNN)`）；发现一处不合规即**全量扫全集**再动手。**文案以提交标题为准**（不可变的一侧当基准），平台侧用 `gh pr edit <n> --title <同形态标题>` 对齐；笔号 / 批次号不进标题。
- ⚠️ **`success` ≠ 跑了**：只改文档的 PR，`app-checks` 常在 **7s** 内通过 —— 那是 `affected.py` 判定后**空跑**，不是执行证据。判据 = 耗时（约 `1m50s` 才算真跑）＋「有没有碰 `app/` 下任何文件」；只改 `app/README.md` 一行，同样判全套。
- **跑不通或沙箱跑不了的项**（如 `flutter build` / `flutter run` / 真机验收）在 PR 正文**如实标注「未验 + 原因 + 归谁验」**，不得留空或写「应该能过」。

# ADR-0013：根级 `changelog.d/` 作为发布说明片段目录

> **状态**：accepted（DOC-2C）
> **日期**：2026-10-29
> **范围**：根目录结构、发布说明、`feat` / `fix` 批次
> **关联**：ADR-0012（文档治理）

## 背景

项目需要按版本汇总用户可感变化，但当前没有变更日志落点：

- `docs/` 的五目录分别管规格、决策、意图、候选、操作手册，**没有“发布说明片段”这一类**；
- 直接维护一个 `CHANGELOG.md` 会让每个 PR 改同一文件，冲突频繁；
- 不记录变化，发布时只能从 PR 标题反推，容易漏。

因此需要一个新的根级目录。它是不是 `docs/` 的第六个分类，必须先裁定。

## 决策

### 1. `changelog.d/` 放在仓库根，不放进 `docs/`

```text
<project>/
  changelog.d/
    README.md
    <batch-id>.md
```

理由：

- 它服务**发布流程**，不是知识分类；
- 它按批次追加，不参与 `docs/` 的 D1–D7 文档检查；
- 放在根级，和 `.github/`、`.agents/` 一样，是**工程装置目录**，不是文档分类。

**它不是 `docs/` 的第六个目录。**

### 2. 一个 `feat` / `fix` 批次一个片段

文件名 = 批次号：

```text
changelog.d/<YYYYMMDD-xxxxxx>.md
```

`process` 批次不要求片段；纯内部重构、无用户可感变化时，仍应在 PR 说明「无 changelog」，但不建空文件。

### 3. 片段只写用户可感变化

```markdown
# <一句话标题>

- 类型：added | changed | fixed | removed | security
- 范围：app | server | content | infra | docs
- 说明：用户能看到/感知到的变化
```

不写实现细节、不写 PR 号、不写测试读数。

### 4. 门禁与发布

- `batch check` 对 `feat` / `fix` 检查 `changelog.d/<batch>.md` 是否存在；
- 缺片段直接失败，不靠人记得；
- 发布时按版本汇总所有片段，生成 `CHANGELOG`；
- `changelog.d/README.md` 说明格式，不参与汇总。

### 5. 项目可选择关闭

不是所有项目都需要发布说明。模板提供 `changelog: on|off`：

- `on`：建目录与 README，启用门禁；
- `off`：不建目录，不要求片段。

`off` 只适用于没有对外发布节奏的项目，不能用来绕过已有门禁。

## 后果

- 根目录多一个 `changelog.d/`，但分类明确：**发布装置，不是文档分类**；
- PR 不再争抢同一个 `CHANGELOG.md`；
- 发布说明可按批次追溯；
- skill 模板必须同步这个目录与开关，不能只在某个项目里存在。

## 不做什么

- 不把 `changelog.d/` 塞进 `docs/`；
- 不要求 `process` 批次写片段；
- 不自动生成空片段；
- 不把片段当验收记录或测试报告。

# changelog.d

按 [`ADR-0013`](../docs/decisions/0013-changelog-fragments.md)：这是**根级发布装置**，不是 `docs/` 的第六个分类。

每个 **feat / fix** 批次一个片段，文件名 = 批次号：

```text
changelog.d/<YYYYMMDD-xxxxxx>.md
```

内容只写用户可感变化，不写内部实现细节：

```markdown
# <一句话标题>

- 类型：added | changed | fixed | removed | security
- 范围：app | server | content | infra | docs
- 说明：用户能看到/感知到的变化
```

规则：

- `process` 批次不需要片段；
- `feat` / `fix` 缺片段时 `batch check` 直接失败；
- 片段随 PR 合并；发布时按版本汇总；
- 不把 PR 号写进正文（片段按批次号命名，PR 由 git 关联）。

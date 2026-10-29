# ADR-0014：主仓与外仓引用边界

> **状态**：accepted（DOC-6）
> **日期**：2026-10-29
> **范围**：主仓 `docs/`、外仓 `<project>-docs/`、SDP、records、legal/product/process
> **关联**：ADR-0009（交付物出仓）、ADR-0012（文档治理）

## 背景

交付记录、计划、法务与商品材料已按 `ADR-0009` 出仓。出仓后出现两种相反的错误：

1. 主仓继续用 Markdown 链接指向 `<project>-docs/...` —— 单独检出主仓时全部断链；
2. 外仓开始复制 `SRS` / `SDD` / `STP` / `STD` / `SCMP` —— 出现第二套工程文档。

两者都不是“多写一份”，而是把**单一事实源**拆成两份。

## 决策

### 1. 主仓是工程文档的唯一源

```text
主仓 docs/        specs · decisions · intent · ideas · runbooks
主仓 specs/controlled/  SRS · SDD · STP · STD · SCMP
```

外仓不复制上述五份受控文档，也不建 `docs/specs/` 镜像。

### 2. 外仓是记录与仓外资产的唯一源

```text
<project>-docs/
  records/     F1 交付与验收（live + frozen）
  legal/       F2 法务
  product/     F2 商品/上架材料
  design/      F3a 设计源
  process/     F5 计划（sdp.md plan-only）
  business/    F4 商务
```

主仓不复制这些目录的内容。

### 3. 主仓引用外仓只写纯文本

**禁止**：

```markdown
[开发计划](../<project>-docs/process/sdp.md)
[验收记录](../<project>-docs/records/)
```

**允许**：

```text
开发计划：`<project>-docs/process/sdp.md`（仓外，需另行检出）
验收记录：`<project>-docs/records/`（仓外，需另行检出）
```

理由：主仓单独检出时没有兄弟目录，Markdown 链接必然断；纯文本是指认，不是链接承诺。

### 4. 外仓引用主仓可以用相对链接

外仓与主仓按兄弟目录检出时，外仓正文可以写：

```markdown
[SRS](../<project>/docs/specs/controlled/srs.md)
```

但冻结记录里的旧相对链接**不改**；在批次 README 的「原始链接说明」里登记实际去向。

### 5. 变更顺序

```text
主仓先改规则 / 文档
→ 外仓再补引用或记录
```

外仓不能先定义一个主仓还不存在的规则。

### 6. 机械检查

`infra/tool/docs/check_boundary.py`：

- 扫主仓 Markdown，禁止指向 `<project>-docs/` 的链接；
- 扫外仓，禁止出现受控五份同名文件；
- 外仓存在时检查其 `AGENTS.md`；
- 只读，不修文件。

## 后果

- 主仓单独检出时，外仓引用仍可读，但不可点击；
- 外仓不能成为第二套工程文档；
- 记录、计划、法务仍只有一处；
- 链接检查不再把“跨仓链接”当成本仓链接。

## 不做什么

- 不把 `records` / `legal` / `product` / `process` 并回主仓；
- 不把 `SRS` / `SDD` / `STP` / `STD` / `SCMP` 复制到外仓；
- 不把外仓路径写成主仓 Markdown 链接；
- 不修冻结记录里的旧链接。

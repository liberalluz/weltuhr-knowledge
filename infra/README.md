# infra

> 构建、签名、打包、更新器、镜像变量与 CI —— 制品层的全部脚本与配置。

## 本模块命令

```bash
./scripts/check-env.sh          # 校验工具链版本与镜像变量（骨架阶段：待实现）
./scripts/build-all.sh          # 三端构建（骨架阶段：待实现）
python3 tool/batch/merge.py --pr <n> --dry-run   # 合并前检查
python3 tool/batch/merge.py --pr <n> --yes      # 人工确认后合并
python3 tool/batch/check.py --scope .batch/<id>/scope.json   # 范围守门
python3 tool/batch/batch.py status                         # 批次状态
python3 tool/batch/batch.py plan --auto-id                 # 自动批次 ID
python3 tool/batch/batch.py approve <id> --chat --confirm <hash8>
python3 tool/batch/batch.py start <id>                     # 批次卡与启动
python3 tool/batch/batch.py check --batch <id>             # 批次检查
python3 tool/batch/batch.py pr --prepare --batch <id>      # PR 正文草稿
python3 tool/batch/batch.py pr --create --body-file ... --confirm <hash8>  # 定稿后创建
python3 tool/batch/batch.py merge --pr <n>                 # 批次合并
python3 tool/metrics/pr_metrics.py --since <YYYY-MM-DD>    # PR 周报
python3 tool/verify/verify.py --batch <id>                 # 只读验收
```

## 相关文档

- 交付文档与活文档：[../docs/README.md](../docs/README.md)
- 环境与工具链约束：[`../docs/runbooks/environment.md`](../docs/runbooks/environment.md)
- 实现约定与边界：见 [AGENTS.md](AGENTS.md)；规则细则以 `docs/` 为准（**不复制**）

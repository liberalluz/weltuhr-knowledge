# infra

> 构建、签名、打包、更新器、镜像变量与 CI —— 制品层的全部脚本与配置。

## 本模块命令

```bash
./scripts/check-env.sh          # 校验工具链版本与镜像变量（骨架阶段：待实现）
./scripts/build-all.sh          # 三端构建（骨架阶段：待实现）
python3 tool/batch/merge.py --pr <n> --dry-run   # 合并前检查
python3 tool/batch/merge.py --pr <n> --yes      # 人工确认后合并
python3 tool/batch/check.py --scope .batch/<id>/scope.json   # 范围守门
```

## 相关文档

- 交付文档与活文档：[../docs/README.md](../docs/README.md)
- 环境与工具链约束：[`../docs/runbooks/environment.md`](../docs/runbooks/environment.md)
- 实现约定与边界：见 [AGENTS.md](AGENTS.md)；规则细则以 `docs/` 为准（**不复制**）

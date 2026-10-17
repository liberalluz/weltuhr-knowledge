/// 核心层的错误类型。
library;

/// 常量未裁定的哨兵错误。
///
/// `docs/reference/constants.md` 的纪律：**任何 `TBD` 项在落地前必须先在
/// `docs/design/` 补齐裁定并回填常量表，不得由实现者自选一个值。**
/// 所以读到未裁定常量时的正确行为是**抛错**，不是给默认值 ——
/// 一个猜出来的数会静默污染所有下游计算，而一个异常会立刻暴露它。
class TbdConstantError extends UnsupportedError {
  TbdConstantError(this.constantId)
    : super(
        '常量 $constantId 尚未裁定。先补 docs/design/ 对应裁定并回填 '
        'docs/reference/constants.md，再实现依赖它的逻辑。',
      );

  /// 常量编号，如 `C-28`。
  final String constantId;
}

/// 核心层的错误类型。
library;

import 'enums.dart';

/// 常量未裁定的哨兵错误。
///
/// `docs/reference/constants.md` 的纪律：**任何 `TBD` 项在落地前必须先在
/// `docs/design/` 补齐裁定并回填常量表，不得由实现者自选一个值。**
/// 所以读到未裁定常量时的正确行为是**抛错**，不是给默认值 ——
/// 一个猜出来的数会静默污染所有下游计算，而一个异常会立刻暴露它。
///
/// ⚠️ **当前常量表没有 `TBD` 项，本类暂时没有使用者**（最后一处 `C-28` 已于
/// 2026-10-18 裁定为「v0.1 不适用」）。这不是死代码：它是「未定值只能抛、
/// 不能猜」这条纪律的落点，删掉它等于下次出现 `TBD` 时只能靠自觉。
class TbdConstantError extends UnsupportedError {
  TbdConstantError(this.constantId)
    : super(
        '常量 $constantId 尚未裁定。先补 docs/design/ 对应裁定并回填 '
        'docs/reference/constants.md，再实现依赖它的逻辑。',
      );

  /// 常量编号（`constants.md` 里的 `C-xx` 标识）。
  final String constantId;
}

/// 非法的 `(axis, level_slot)` 组合（`ADR-0007` 决策 4）。
///
/// **这是全项目唯一允许在运行期抛错的类型约束。** 理由：轴是运行期读取的数据
/// （包里的节点写 `axis: major`），不是类型参数，编译器看不见；而合不合法是一张
/// 静态表。`StructuralNode` 构造时与反序列化时走同一处校验，不留第二条路径。
///
/// 抛错而不是断言（`assert`）：断言在 release 里被剥掉，非法组合会静默存活到
/// 生产环境 —— 那正是 `ADR-0007` 要挡的「错的状态可表达，就一定会有人表达出来」。
class IllegalNodeSlotError extends ArgumentError {
  IllegalNodeSlotError(this.axis, this.levelSlot)
    : super(
        '非法的节点槽位组合：axis=${axis.name} × level_slot=${levelSlot.name}。'
        '骨架结构节点的合法对只有 12 对（见 constants.dart），'
        '`system` 是载荷容器、轴继承自父恒星，不在此表内。',
      );

  final Axis axis;
  final LevelSlot levelSlot;
}

/// 存储三区的布局不成立（`entity-fields.md` §〇）。
///
/// 两种不成立：**根为空**（空根会把整棵树当成一个区，`'{root}/x'` 拼出来是 `/x`）
/// 与**两区互相包含**。后者不是洁癖：可写区若落在只读区里面，一次原子写就能改写
/// 分发内容 —— 而「只读分发区」的全部意义是包正文不会被本机的写操作碰到。
///
/// 抛错而不是断言：`assert` 在 release 里被剥掉，而三区重叠恰恰是**用户机器上**
/// 才会出现的形态（自定义数据目录、把数据盘挂在 `/content` 下），开发机上永远
/// 测不出来。
class InvalidStoreLayoutError extends ArgumentError {
  /// 某一区的根为空。
  InvalidStoreLayoutError.empty(this.zone, this.root)
    : other = null,
      super('存储三区的「${zone.name}」根目录为空（归一化后为 `$root`）。');

  /// 两区互相包含。
  InvalidStoreLayoutError.overlapping(this.zone, this.root, this.other)
    : super(
        '存储三区的根目录重叠：`$root`（${zone.name}）与 `$other` 互相包含。'
        '三区必须物理分离 —— 否则可写区的原子写能落到只读区里。',
      );

  final StoreZone zone;
  final String root;

  /// 与 [root] 重叠的另一区根（`empty` 时为 `null`）。
  final String? other;
}

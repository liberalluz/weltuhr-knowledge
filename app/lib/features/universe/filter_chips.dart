/// ② 筛选状态栏（`SPEC-VIEW-019` / `021`）。
///
/// 只做「看和删」：每个 chip 带 `×`，删除与「⑥ 上再点一次取消」等价。
/// **不在这里选值** —— 选值归 ⑥ 罗盘与定位结果（`VIEW-019` / `028`），
/// 让它也能选值就等于有了两个输入源，chip 从状态栏变成编辑器。
///
/// 「激活才出现」是 `VIEW-018` 写死的：没有筛选时**整块不渲染**。留一个
/// 空状态的 ② 会让这条规则从第一天起就变成「常显占位」。
library;

import 'package:flutter/material.dart';

import '../../core/view/filter.dart';
import '../palette.dart';

/// 某一个 chip 的 `Key`。
Key filterChipKey(AxisFilterChip chip) =>
    Key('filter-chip-${chip.axisKey}-${chip.value}');

/// 尾部「清空」按钮。
const Key filterClearKey = Key('filter-clear');

/// ② 筛选 chips。
class FilterChips extends StatelessWidget {
  const FilterChips({
    required this.filter,
    required this.onRemove,
    required this.onClear,
    this.matched,
    this.total,
    super.key,
  });

  final AxisFilter filter;

  /// 点 `×`。参数是那条 chip —— 轴键与取值一起给，删的是「这一轴的这个值」。
  final ValueChanged<AxisFilterChip> onRemove;

  final VoidCallback onClear;

  /// 命中数 / 总数。给了就在 chip 行末尾写一句「N / M 项」。
  ///
  /// 筛选之后画面上的星变少，用户需要一个「少了多少」的读数 —— 只靠肉眼数
  /// 星星的话，缩小视野与渲染失败长得一模一样。
  final int? matched;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final List<AxisFilterChip> chips = filterChipsOf(filter);
    if (chips.isEmpty) {
      // 调用方本该在外层判空，这里再判一次：这个 widget 的契约就是
      // 「给了空筛选就什么都不画」，让契约成立比让调用方记住更可靠。
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: palettePanel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            '筛选',
            style: TextStyle(color: paletteTextSecondary, fontSize: 10),
          ),
          for (final AxisFilterChip chip in chips) _chip(chip),
          if (matched != null && total != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '$matched / $total 项',
                style: const TextStyle(
                  color: paletteTextSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          TextButton(
            key: filterClearKey,
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: paletteTextSecondary,
              minimumSize: const Size(40, 24),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('清空', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _chip(AxisFilterChip chip) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Container(
      key: filterChipKey(chip),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: paletteSelected,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            // 轴名 + 取值：只写取值的话，「计算机」既可能是学科也可能是行业，
            // 用户看不出这条 chip 在筛什么。
            '${chip.axisLabel} · ${chip.value}',
            style: const TextStyle(color: paletteTextPrimary, fontSize: 11),
          ),
          InkWell(
            onTap: () => onRemove(chip),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(4, 2, 6, 2),
              child: Text(
                '×',
                style: TextStyle(color: paletteTextSecondary, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

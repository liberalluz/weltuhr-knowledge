import 'package:flutter/material.dart';

import '../../../core/tree/tree_index.dart';
import '../../../core/universe/placement.dart';
import 'spike_scene.dart';

/// 宇宙视图的产品入口（`B17b` 笔 2 挂上、笔 3 接上节点）。
///
/// **地址来自树，不自己算一套**：树屏把它的 [TreeIndex] 与当前那一行原样传进来
/// （`SPEC-TREE-007`），这里只调 `layoutOfNode` 把它翻成坐标。两处各存一个 id
/// 早晚会分叉 —— 在树里看到哪、切过来就该是哪一片天。
///
/// **主题在这一层覆成深色**，不动全局 `ThemeData`：星空必须黑底，而主 app 是
/// 浅色主题。覆在页面这一层，返回时主题自然还原，不必给入口加分支。
///
/// **采样面板不显示**：[SpikeSceneView] 的 `showReadout` 默认关，这里不传，
/// 用户看不到 `P50` / `P95`。帧率仍在 `lib/spike_main.dart` 那个调试入口采
/// （`flutter run -t lib/spike_main.dart`），验收口径不变。
///
/// ⚠️ 类名仍带 `Spike`：改名会牵动测试与调用点，属于后续笔的整理范围，
/// 本笔不做未点名的重命名。
class UniverseScreen extends StatelessWidget {
  const UniverseScreen({super.key, this.tree, this.currentNodeId});

  /// 树的索引。`null` = 骨架未装载 —— 此时只画星空，不画节点，也不报错。
  final TreeIndex? tree;

  /// 树里当前那一行。`null` 同上。
  final String? currentNodeId;

  /// 这一片天。算不出来时是 `null`，由 `SpikeSceneView` 按「只画星空」处置。
  ///
  /// 在 `build` 里算而不是缓存：`layoutOfNode` 是纯函数，输入只有树与地址，
  /// 而这两个都是本组件的字段 —— 缓存反而要处理「树换了但 id 没变」这种失效。
  UniverseView? get _universe {
    final TreeIndex? tree = this.tree;
    final String? id = currentNodeId;
    if (tree == null || id == null) {
      return null;
    }
    return layoutOfNode(tree, id);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('宇宙'),
        ),
        body: SpikeSceneView(universe: _universe),
      ),
    );
  }
}

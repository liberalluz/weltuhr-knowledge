import 'package:flutter/material.dart';

import 'spike_scene.dart';

/// 宇宙视图的产品入口（`B17b` 笔 2）。
///
/// 这一笔只做「挂载 + 相机」：屏幕上还是那片星空，没有知识节点、没有轴色、
/// 没有标注 —— 那些是笔 3 之后的事。挂载单独成笔的理由是**定位**：帧率一旦
/// 塌了，要能说清是渲染本身，还是新加的那层。
///
/// **主题在这一层覆成深色**，不动全局 `ThemeData`：星空必须黑底，而主 app 是
/// 浅色主题。覆在页面这一层，返回时主题自然还原，不必给入口加分支。
///
/// **采样面板不显示**：[SpikeSceneView] 的 `showReadout` 默认关，这里不传，
/// 用户看不到 `P50` / `P95`。帧率仍在 `lib/spike_main.dart` 那个调试入口采
/// （`flutter run -t lib/spike_main.dart`），验收口径不变。
///
/// ⚠️ 类名仍带 `Spike`：改名会牵动测试与调用点，属于笔 3 的整理范围，本笔
/// 不做未点名的重命名。
class UniverseScreen extends StatelessWidget {
  const UniverseScreen({super.key});

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
        body: const SpikeSceneView(),
      ),
    );
  }
}

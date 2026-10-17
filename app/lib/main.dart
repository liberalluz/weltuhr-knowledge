import 'package:flutter/material.dart';

import 'features/universe/scene_source.dart';
import 'features/universe/universe_screen.dart';
import 'features/universe/universe_spike_screen.dart';

void main() {
  runApp(const WeltuhrApp());
}

/// 应用外壳。
///
/// W0 阶段只有空态：还没有内容包，因此没有星系图可画 —— 这是
/// `SPEC-FND-014`「未声明即不渲染」的最朴素形态：**没有数据就不补默认值**。
class WeltuhrApp extends StatelessWidget {
  const WeltuhrApp({super.key});

  static const Color _accent = Color(0xFF534AB7);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weltuhr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: _accent,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const EmptySpaceScreen(),
    );
  }
}

/// 空态页（占位，W2 由宇宙视图的 Z0 取代）。
class EmptySpaceScreen extends StatelessWidget {
  const EmptySpaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Weltuhr', style: text.headlineMedium),
            const SizedBox(height: 12),
            Text('尚未载入任何知识空间', style: text.bodyLarge),
            const SizedBox(height: 8),
            Text(
              '内容包就位后，这里会出现星系图',
              style: text.bodySmall,
            ),
            const SizedBox(height: 32),
            // 「宇宙视图」入口 —— `B3` 笔 2 的正式界面（五档刻度 + HUD 七区块）。
            // 真实入口（从空间列表进）归笔 2 收尾，这里先让它可达。
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      UniverseScreen(scene: resolveAlphaScene().bundle),
                ),
              ),
              child: const Text('宇宙视图'),
            ),
            const SizedBox(height: 12),
            // 「绘制 spike」入口 —— `B2` 第 5 笔的测量装置，**保留**：`STR` 轮次
            // `R1` 的帧率读数靠它复跑。产品功能不挂这里，测量装置挂这里。
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const UniverseSpikeScreen(),
                ),
              ),
              child: const Text('绘制 spike（帧率实测）'),
            ),
          ],
        ),
      ),
    );
  }
}

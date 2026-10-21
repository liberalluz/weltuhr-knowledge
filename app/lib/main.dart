import 'package:flutter/material.dart';

void main() {
  runApp(const WeltuhrApp());
}

/// 应用外壳。
///
/// 只有空态：`features/universe/` 的六轴五档渲染随 `ADR-0005` 在 `B13a`
/// 笔 5a 整层删除，容器树界面归 `B17a`。这里保留「没有数据就不补默认值」
/// 的最朴素形态（`SPEC-FND-014`）。
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

/// 空态页（`B17a` 容器树就位前，本页是唯一界面）。
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
          ],
        ),
      ),
    );
  }
}

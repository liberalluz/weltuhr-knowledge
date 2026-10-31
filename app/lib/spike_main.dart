/// `B17b` 笔 1 的 spike 独立入口。
///
/// **不经过主 app 的任何路由与界面**：`flutter run -t lib/spike_main.dart`
/// 打开就是那片星空。单独一个入口的理由是侵入面 —— 主界面刚通过 `B4` 验收，
/// 往它里面加调试分支，等于让下次验收多验一块。
///
/// 三端跑法（`ADR-0006` §3 要求三端各一次）：
///
/// ```text
/// flutter run -t lib/spike_main.dart -d windows
/// flutter run -t lib/spike_main.dart -d macos
/// flutter run -t lib/spike_main.dart -d <ios device id>
/// ```
///
/// Flutter GPU 已在三端平台文件里写死（见 `windows/runner/main.cpp` 与两个
/// `Info.plist`），所以命令行不必再带 `--enable-flutter-gpu`。
library;

import 'package:flutter/material.dart';

import 'features/universe/presentation/spike_scene.dart';

void main() {
  runApp(const SpikeApp());
}

/// spike 的最小外壳：一个深色 `MaterialApp` 装场景，不带任何业务导航。
class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weltuhr spike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SpikeSceneView(showReadout: true),
    );
  }
}

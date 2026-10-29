import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/main.dart';

void main() {
  testWidgets('空态外壳可渲染，标题为 Weltuhr（SPEC-FND-014：不补默认星系）', (
    WidgetTester tester,
  ) async {
    // **注入空结果，不读磁盘**：`flutter test` 的 CWD 下有没有内容包取决于本机
    // 是否跑过装配脚本，拿它当断言，红的永远是环境。
    await tester.pumpWidget(WeltuhrApp(boot: () => const PackBoot()));

    expect(find.text('Weltuhr'), findsOneWidget);
    expect(find.text('尚未载入任何知识空间'), findsOneWidget);
  });

  testWidgets('探不到包时报出具体原因，不塌成一句「加载失败」（SPEC-FND-014）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      WeltuhrApp(
        boot: () => const PackBoot(
          problems: <String>[
            'missingPack: C:/nowhere/content/python/pack.json',
          ],
        ),
      ),
    );

    expect(find.text('尚未载入任何知识空间'), findsOneWidget);
    expect(find.text('候选根下没有可用的包：'), findsOneWidget);
    expect(
      find.text('missingPack: C:/nowhere/content/python/pack.json'),
      findsOneWidget,
    );
    expect(
      find.text('先跑 python content/tools/assemble_pack.py'),
      findsOneWidget,
    );
  });

  testWidgets('深浅两套主题都在、跟随系统，不把 brightness 写死 light（无 SPEC：主题属实现层，未立规格）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(WeltuhrApp(boot: () => const PackBoot()));

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    // 写死 light 时系统切深色屏幕仍是白的 —— 两个断言各锁一半：
    // `themeMode` 决定跟不跟系统，`darkTheme` 决定跟过去有没有可用的那套。
    expect(app.themeMode, ThemeMode.system);
    expect(app.darkTheme, isNotNull);
    expect(app.darkTheme!.brightness, Brightness.dark);
    expect(app.theme!.brightness, Brightness.light);
  });
}

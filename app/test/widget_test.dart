import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/main.dart';

void main() {
  testWidgets('空态外壳可渲染，标题为 Weltuhr（SPEC-FND-014：不补默认星系）', (WidgetTester tester) async {
    await tester.pumpWidget(const WeltuhrApp());

    expect(find.text('Weltuhr'), findsOneWidget);
    expect(find.text('尚未载入任何知识空间'), findsOneWidget);
  });
}

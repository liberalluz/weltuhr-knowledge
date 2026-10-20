import 'package:flutter_test/flutter_test.dart';

import '../../tool/lint/rules.dart';

void main() {
  group('R1 核心层不得反向依赖', () {
    test('core 引用 Flutter 被拦（R1）', () {
      final issues = checkSource(
        path: 'lib/core/entities/x.dart',
        source: "import 'package:flutter/material.dart';\n\nclass X {}\n",
      );
      expect(issues.map((LintIssue i) => i.ruleId), contains(ruleCrossLayer));
    });

    test('core 引用 dart:ui 被拦（R1）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: "import 'dart:ui';\n",
      );
      expect(issues.map((LintIssue i) => i.ruleId), contains(ruleCrossLayer));
    });

    test('core 引用 features/ 被拦（R1）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source:
            "import 'package:project_knowledge/features/universe/view.dart';\n",
      );
      expect(issues.map((LintIssue i) => i.ruleId), contains(ruleCrossLayer));
    });

    test('features 引用 Flutter 不拦（R1：UI 层本就该用）', () {
      final issues = checkSource(
        path: 'lib/features/universe/view.dart',
        source: "import 'package:flutter/material.dart';\n",
      );
      expect(issues, isEmpty);
    });
  });

  group('R2 核心层禁止数字字面量', () {
    test('普通数字被拦，并报出行号（R2）', () {
      final issues = checkSource(
        path: 'lib/core/queue.dart',
        source: 'void f() {\n  final int cap = 25;\n}\n',
      );
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, ruleMagicNumber);
      expect(issues.single.line, 2);
    });

    test('constants.dart 豁免（R2）', () {
      final issues = checkSource(
        path: 'lib/core/constants.dart',
        source: 'const int sessionBudgetMinutes = 25;\n',
      );
      expect(issues, isEmpty);
    });

    test('0 与 1 放行（R2：坐标与计数基元）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: 'int f(int n) => n == 0 ? 1 : n - 1;\n',
      );
      expect(issues, isEmpty);
    });

    test('注释与字符串里的数字不误报（R2）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: "// 会话预算 25 分钟\nconst String label = 'v2 版本';\n",
      );
      expect(issues, isEmpty);
    });

    test('features 层不查数字（R2：间距属设计 token）', () {
      final issues = checkSource(
        path: 'lib/features/x.dart',
        source: 'final double gap = 12;\n',
      );
      expect(issues, isEmpty);
    });
  });

  group('R3 事件只 append', () {
    test('Event 加 copyWith 被拦（R3）', () {
      final issues = checkSource(
        path: 'lib/core/events/event.dart',
        source: '''
class Event {
  const Event({required this.id});
  final String id;
  Event copyWith({String? id}) => Event(id: id ?? this.id);
}
''',
      );
      expect(
        issues.map((LintIssue i) => i.ruleId),
        contains(ruleEventAppendOnly),
      );
    });

    test('Event 出现可变字段被拦（R3）', () {
      final issues = checkSource(
        path: 'lib/core/events/event.dart',
        source: 'class Event {\n  String id = "";\n}\n',
      );
      expect(
        issues.map((LintIssue i) => i.ruleId),
        contains(ruleEventAppendOnly),
      );
    });

    test('Event 的子类同样受限（R3：按名不按路径）', () {
      final issues = checkSource(
        path: 'lib/features/x.dart',
        source: 'class StepEvent extends Event {\n  bool done = false;\n}\n',
      );
      expect(
        issues.map((LintIssue i) => i.ruleId),
        contains(ruleEventAppendOnly),
      );
    });

    test('EventStore 出现 delete 被拦（R3）', () {
      final issues = checkSource(
        path: 'lib/core/events/event_store.dart',
        source: 'class EventStore {\n  void delete(String id) {}\n}\n',
      );
      expect(
        issues.map((LintIssue i) => i.ruleId),
        contains(ruleEventAppendOnly),
      );
    });

    test('全 final 且只 append / readAll 不误报（R3）', () {
      final issues = checkSource(
        path: 'lib/core/events/event.dart',
        source: '''
class Event {
  const Event({required this.id});
  final String id;
}

class EventStore {
  void append(Event e) {}
  List<Event> readAll() => <Event>[];
}
''',
      );
      expect(issues, isEmpty);
    });
  });

  group('R4 源不进视觉通道', () {
    test('绘制层按类型收源被拦（R4）', () {
      final issues = checkSource(
        path: 'lib/features/universe/frame_painter.dart',
        source: 'class FramePainter {\n  FramePainter(SourceRef s) {}\n}\n',
      );
      expect(
        issues.map((LintIssue i) => i.ruleId),
        contains(ruleSourceNotVisual),
      );
    });

    test('绘制层按参数名收源被拦（R4：类型写成 Object 也躲不掉）', () {
      final issues = checkSource(
        path: 'lib/features/universe/frame_painter.dart',
        source:
            'class FramePainter {\n  void render(Object? sourceRefs) {}\n}\n',
      );
      expect(
        issues.map((LintIssue i) => i.ruleId),
        contains(ruleSourceNotVisual),
      );
    });

    test('场景装配层收源被拦（R4：core/frame 也算视觉通道）', () {
      final issues = checkSource(
        path: 'lib/core/frame/scene.dart',
        source: 'class Scene {\n  Scene(SourceSegment segment) {}\n}\n',
      );
      expect(
        issues.map((LintIssue i) => i.ruleId),
        contains(ruleSourceNotVisual),
      );
    });

    test('详情页显示源名不拦（R4 收窄后只管通道，SPEC-VIEW-004 要求写进详情）', () {
      final issues = checkSource(
        path: 'lib/features/detail/detail_panel.dart',
        source: 'class DetailPanel {\n  DetailPanel(SourceRef ref) {}\n}\n',
      );
      expect(issues, isEmpty);
    });

    test('core 实体层收源不拦（R4 只管视觉通道）', () {
      final issues = checkSource(
        path: 'lib/core/entities/content.dart',
        source: 'class Item {\n  Item(SourceRef s) {}\n}\n',
      );
      expect(issues, isEmpty);
    });

    test('resourceId 不误报（R4：判据是 source 不是 resource）', () {
      final issues = checkSource(
        path: 'lib/features/x.dart',
        source: 'class X {\n  X(String resourceId) {}\n}\n',
      );
      expect(issues, isEmpty);
    });
  });

  group('R5 测试须标裁定来源', () {
    test('无标号的 test 被拦（R5）', () {
      final issues = checkSource(
        path: 'test/core/x_test.dart',
        source: "void main() {\n  test('某个行为', () {});\n}\n",
      );
      expect(issues.map((LintIssue i) => i.ruleId), contains(ruleTestSpecTag));
    });

    test('SPEC 编号、常量编号、ADR、规则号都算合规标号（R5）', () {
      final issues = checkSource(
        path: 'test/core/x_test.dart',
        source: '''
void main() {
  test('a（SPEC-QUANT-006）', () {});
  test('b（C-25）', () {});
  test('c（ADR-0002）', () {});
  test('d（R1）', () {});
}
''',
      );
      expect(issues, isEmpty);
    });

    test('显式豁免「无 SPEC：<理由>」放行（R5）', () {
      final issues = checkSource(
        path: 'test/core/x_test.dart',
        source: "void main() {\n  test('某行为（无 SPEC：纯契约层要求）', () {});\n}\n",
      );
      expect(issues, isEmpty);
    });

    test('lib 下的 test 调用不查（R5 只管 test/）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: "void main() {\n  test('某个行为', () {});\n}\n",
      );
      expect(issues, isEmpty);
    });
  });

  group('R6 结构节点不得声明可学字段', () {
    test('StructuralNode 声明 layer 被拦（R6）', () {
      final issues = checkSource(
        path: 'lib/core/entities/node.dart',
        source:
            'class StructuralNode extends Node {\n  final String? layer;\n}\n',
      );
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, ruleStructuralNodeFieldSet);
    });

    test('StructuralNode 不带三项放行（R6）', () {
      final issues = checkSource(
        path: 'lib/core/entities/node.dart',
        source:
            'class StructuralNode extends Node {\n  final String slug;\n}\n',
      );
      expect(issues, isEmpty);
    });

    test('同名类不在册时不管 —— 名字是 LearnableNode 才查（R6）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: 'class Structural {\n  final String? layer;\n}\n',
      );
      expect(issues, isEmpty);
    });
  });

  group('R7 可学节点三项非可空', () {
    test('三项齐全且非空放行（R7）', () {
      final issues = checkSource(
        path: 'lib/core/entities/node.dart',
        source:
            'class LearnableNode extends Node {\n'
            '  final LearnableType type;\n'
            '  final Layer layer;\n'
            '  final ItemRequirements requirements;\n'
            '}\n',
      );
      expect(issues, isEmpty);
    });

    test('一项写成可空被拦（R7）', () {
      final issues = checkSource(
        path: 'lib/core/entities/node.dart',
        source:
            'class LearnableNode extends Node {\n'
            '  final LearnableType type;\n'
            '  final Layer? layer;\n'
            '  final ItemRequirements requirements;\n'
            '}\n',
      );
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, ruleLearnableNodeFieldSet);
      expect(issues.single.message, contains('layer'));
    });

    test('缺一项被拦（R7）', () {
      final issues = checkSource(
        path: 'lib/core/entities/node.dart',
        source:
            'class LearnableNode extends Node {\n'
            '  final LearnableType type;\n'
            '  final Layer layer;\n'
            '}\n',
      );
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, ruleLearnableNodeFieldSet);
      expect(issues.single.message, contains('requirements'));
    });
  });

  group('R8 Node 不得直接构造', () {
    test('直接构造 Node 被拦（R8）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: "Node f() => Node(id: 'a');\n",
      );
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, ruleNodeNoDirectConstruction);
    });

    test('Node 类体内有 factory 被拦（R8）', () {
      final issues = checkSource(
        path: 'lib/core/entities/node.dart',
        source: 'sealed class Node {\n  factory Node.make() => throw 0;\n}\n',
      );
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, ruleNodeNoDirectConstruction);
    });

    test('建子类不算直接构造（R8）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: "StructuralNode f() => StructuralNode(id: 'a');\n",
      );
      expect(issues, isEmpty);
    });
  });

  group('R9 派生三项不作字段', () {
    test('Node 声明 path 被拦（R9）', () {
      final issues = checkSource(
        path: 'lib/core/entities/node.dart',
        source: 'sealed class Node {\n  final String path;\n}\n',
      );
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, ruleNodeNoDerivedFields);
    });

    test('子类声明 depth 同样被拦（R9）', () {
      final issues = checkSource(
        path: 'lib/core/entities/node.dart',
        source:
            'class StructuralNode extends Node {\n  final int depth = 0;\n}\n',
      );
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, ruleNodeNoDerivedFields);
    });

    test('无关类声明 path 不查（R9）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: 'class Route {\n  final String path;\n}\n',
      );
      expect(issues, isEmpty);
    });
  });
}

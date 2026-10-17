import 'package:flutter_test/flutter_test.dart';

import '../../tool/lint/rules.dart';

void main() {
  group('R1 核心层不得反向依赖', () {
    test('core 引用 Flutter 被拦', () {
      final issues = checkSource(
        path: 'lib/core/entities/x.dart',
        source: "import 'package:flutter/material.dart';\n\nclass X {}\n",
      );
      expect(issues.map((LintIssue i) => i.ruleId), contains(ruleCrossLayer));
    });

    test('core 引用 dart:ui 被拦', () {
      final issues = checkSource(path: 'lib/core/x.dart', source: "import 'dart:ui';\n");
      expect(issues.map((LintIssue i) => i.ruleId), contains(ruleCrossLayer));
    });

    test('core 引用 features/ 被拦', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: "import 'package:project_knowledge/features/universe/view.dart';\n",
      );
      expect(issues.map((LintIssue i) => i.ruleId), contains(ruleCrossLayer));
    });

    test('features 引用 Flutter 不拦（UI 层本就该用）', () {
      final issues = checkSource(
        path: 'lib/features/universe/view.dart',
        source: "import 'package:flutter/material.dart';\n",
      );
      expect(issues, isEmpty);
    });
  });

  group('R2 核心层禁止数字字面量', () {
    test('普通数字被拦，并报出行号', () {
      final issues = checkSource(
        path: 'lib/core/queue.dart',
        source: 'void f() {\n  final int cap = 25;\n}\n',
      );
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, ruleMagicNumber);
      expect(issues.single.line, 2);
    });

    test('constants.dart 豁免', () {
      final issues = checkSource(
        path: 'lib/core/constants.dart',
        source: 'const int sessionBudgetMinutes = 25;\n',
      );
      expect(issues, isEmpty);
    });

    test('0 与 1 放行（坐标与计数基元）', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: 'int f(int n) => n == 0 ? 1 : n - 1;\n',
      );
      expect(issues, isEmpty);
    });

    test('注释与字符串里的数字不误报', () {
      final issues = checkSource(
        path: 'lib/core/x.dart',
        source: "// 会话预算 25 分钟\nconst String label = 'v2 版本';\n",
      );
      expect(issues, isEmpty);
    });

    test('features 层不查数字（间距属设计 token）', () {
      final issues = checkSource(
        path: 'lib/features/x.dart',
        source: 'final double gap = 12;\n',
      );
      expect(issues, isEmpty);
    });
  });
}

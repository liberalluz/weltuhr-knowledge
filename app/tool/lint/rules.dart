/// 两条架构规则的实现。
///
/// 为什么只有两条：另两条约束（事件只 append、UI 不写状态）**靠接口形状就够**——
/// `EventStore` 只暴露 `append` / `readAll` / `byId`，状态只经 `fold` 派生。
/// 给已经不可能发生的写法写 lint，是给不会发生的错误装报警器。
///
/// 规则是纯函数：`(path, source) -> issues`。这样可以拿字符串直接测，不依赖磁盘。
library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// 一条违规。
class LintIssue {
  const LintIssue({
    required this.ruleId,
    required this.path,
    required this.line,
    required this.message,
  });

  final String ruleId;
  final String path;
  final int line;
  final String message;

  @override
  String toString() => '$path:$line [$ruleId] $message';
}

/// R1：核心层禁止反向依赖 —— `lib/core/**` 不得 import Flutter、`dart:ui` 或 `features/`。
///
/// 理由：核心层要能脱离 UI 单测（`ADR-0002` 把它列为纵切可行的前提）。
const String ruleCrossLayer = 'R1';

/// R2：核心层（除 `constants.dart`）禁止数字字面量 —— 常量必须来自常量表。
///
/// 只在核心层生效：UI 的间距 / 尺寸属设计 token，不归常量表管。
const String ruleMagicNumber = 'R2';

/// `lib/core/**` 不得出现的外部依赖前缀。
const List<String> _forbiddenUriPrefixes = <String>[
  'package:flutter',
  'dart:ui',
];

/// 是否为 `lib/core/**` 下的文件（兼容绝对路径与相对路径）。
bool _isCore(String path) => path.contains('lib/core/');

/// 是否为常量表本身（R2 的唯一豁免点）。
bool _isConstantsFile(String path) => path.endsWith('lib/core/constants.dart');

String _normalize(String path) => path.replaceAll(r'\', '/');

/// 对一段源码执行全部规则。
List<LintIssue> checkSource({required String path, required String source}) {
  final String normalized = _normalize(path);
  if (!normalized.endsWith('.dart')) {
    return const <LintIssue>[];
  }

  final ParseStringResult parsed = parseString(
    content: source,
    path: normalized,
    throwIfDiagnostics: false,
  );
  final CompilationUnit unit = parsed.unit;
  final issues = <LintIssue>[];

  if (_isCore(normalized)) {
    for (final ImportDirective directive in unit.directives.whereType<ImportDirective>()) {
      final String? uri = directive.uri.stringValue;
      if (uri == null) {
        continue;
      }
      final bool forbidden = _forbiddenUriPrefixes.any(uri.startsWith) || uri.contains('/features/');
      if (forbidden) {
        issues.add(
          LintIssue(
            ruleId: ruleCrossLayer,
            path: normalized,
            line: _lineOf(parsed, directive.offset),
            message: '核心层不得依赖 `$uri`（只允许纯 Dart 与 core 内部依赖）',
          ),
        );
      }
    }

    if (!_isConstantsFile(normalized)) {
      unit.accept(_MagicNumberVisitor(parsed, normalized, issues));
    }
  }

  return issues;
}

int _lineOf(ParseStringResult parsed, int offset) =>
    parsed.lineInfo.getLocation(offset).lineNumber;

/// 收集非 `0` / `1` 的数字字面量。
///
/// 走 AST 而不是正则：正则分不清字符串里的 `"v1"`、注释里的 `// 25 分钟`、
/// 以及 `1e3` 这种指数写法。
class _MagicNumberVisitor extends RecursiveAstVisitor<void> {
  _MagicNumberVisitor(this._parsed, this._path, this._issues);

  final ParseStringResult _parsed;
  final String _path;
  final List<LintIssue> _issues;

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    final int? value = node.value;
    if (value != null && value != 0 && value != 1) {
      _report(node.offset, '$value');
    }
    super.visitIntegerLiteral(node);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    final double value = node.value;
    if (value != 0 && value != 1) {
      _report(node.offset, '$value');
    }
    super.visitDoubleLiteral(node);
  }

  void _report(int offset, String literal) {
    _issues.add(
      LintIssue(
        ruleId: ruleMagicNumber,
        path: _path,
        line: _lineOf(_parsed, offset),
        message: '字面量 `$literal` 应改为 `constants.dart` 中的具名常量',
      ),
    );
  }
}

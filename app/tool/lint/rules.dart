/// 五条架构与测试规范规则的实现。
///
/// - `R1` / `R2` —— 分层与常量来源（首建即在此）。
/// - `R3` / `R4` —— 把两条「只活在注释里」的裁定变成可执行检查：
///   事件只 append（`SPEC-FND-012`）· 源不进视觉通道（`SPEC-VIEW-004`）。
/// - `R5` —— 测试与裁定的追溯链：每个测试必须声明它守的是哪一条。
///
/// 为什么原先只写了两条：另两条约束**靠接口形状就够** —— `EventStore` 只暴露
/// `append` / `readAll` / `byId`，状态只经 `fold` 派生。但形状挡得住**改**，
/// 挡不住**加**：有人给 `Event` 加个 `copyWith`，编译不报错、测试不红、
/// 代码评审也未必看见，而「事件不可变」当场破功。`R3` 补的就是这处。
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

/// R3：事件只 append —— `Event` 及其子类不得有 `copyWith`、字段必须 `final`；
/// `EventStore` 不得出现删除 / 覆盖类方法。
///
/// 判据落在「**能否构造出改写历史事件的写法**」上，而不是「当前有没有人这么写」。
const String ruleEventAppendOnly = 'R3';

/// R4：源不进**任何视觉通道** —— 场景装配（`lib/core/frame/`）与绘制
/// （`frame_painter.dart` / `frame_draw_target.dart`）不得出现 `SourceRef` /
/// `SourceSegment`（`SPEC-VIEW-004`「换源不改观感」）。
///
/// ⚠️ **判据收窄过一次**（`B3` 笔 3）。原判据是「`lib/features/**` 一律不许出现
/// 源」，与 `SPEC-VIEW-004`「源只写进详情页」**直接矛盾** —— 详情三区里的来源区
/// 必须显示源名与摘录，而那就在 `features/` 下。收窄后守的仍是原意：源不进
/// **通道**（`scene.dart` 造 `SceneNode`、`frame_painter.dart` 把它们画出来）；
/// 那两处一旦读到源，换本教材星星就会变亮，而这正是要被挡住的事。
///
/// 不靠「详情页换个参数名」绕过：判据写宽了就该改判据，否则规则里留着一条
/// 名不副实的约束，下一个人只会照抄那个绕法。
const String ruleSourceNotVisual = 'R4';

/// R5：每个测试必须声明它守的是哪一条裁定（`SPEC-…` / `C-…` / `ADR-…` / `R<n>`），
/// 或显式写「无 SPEC：<理由>」。
///
/// 这条是 `R-09` 的落点：33 个测试只有 1 处写 `SPEC` 编号时，`STR` 的追溯表
/// **只能靠人工判定**，而人工判定出来的映射有一种特别的坏法 —— 看起来对、
/// 实际是借位（`R1` 的依赖方向被当成 `FND-015` 的硬编码分支）。
/// 让测试自己说清守什么，比事后补一张映射表可靠。
const String ruleTestSpecTag = 'R5';

/// `lib/core/**` 不得出现的外部依赖前缀。
const List<String> _forbiddenUriPrefixes = <String>[
  'package:flutter',
  'dart:ui',
];

/// 是否为 `lib/core/**` 下的文件（兼容绝对路径与相对路径）。
bool _isCore(String path) => path.contains('lib/core/');

/// 是否为常量表本身（R2 的唯一豁免点）。
bool _isConstantsFile(String path) => path.endsWith('lib/core/constants.dart');

/// 是否为**视觉通道**文件（R4 的作用域）。
///
/// 两处：造视觉编码的地方（`lib/core/frame/` —— `scene.dart` 装配 `SceneNode`、
/// `projection.dart` 算几何）与画出来的地方（`frame_painter.dart` /
/// `frame_draw_target.dart`）。详情页不在这里：它显示源名与摘录是
/// `SPEC-VIEW-004` 要求的。
bool _isVisualChannel(String path) =>
    path.contains('lib/core/frame/') ||
    path.endsWith('lib/features/universe/frame_painter.dart') ||
    path.endsWith('lib/features/universe/frame_draw_target.dart');

/// 是否为测试文件（R5 的作用域）。
bool _isTestFile(String path) => path.startsWith('test/') || path.contains('/test/');

String _normalize(String path) => path.replaceAll(r'\', '/');

/// 事件类与事件存储类的名字（`SPEC-FND-012`）。
const String _eventClassName = 'Event';
const String _eventStoreClassName = 'EventStore';
const String _copyWithName = 'copyWith';

/// `EventStore` 上被禁止的方法名 —— 任一出现都意味着「历史可被改写」。
const Set<String> _forbiddenStoreMethods = <String>{
  'delete',
  'remove',
  'update',
  'replace',
  'upsert',
  'clear',
  'overwrite',
  'edit',
};

/// 不得出现在视图层入参里的源类型（`SPEC-VIEW-004`）。
const Set<String> _sourceTypeNames = <String>{'SourceRef', 'SourceSegment'};

/// 视图层入参里暗示「这是源」的参数名（小写比较，去掉前导下划线后）。
final RegExp _sourceParamName = RegExp(r'^_?source(s|ref|refs|segments?)?$');

/// 测试名里合法的裁定标号。
///
/// - `SPEC-XXX-NNN` —— 设计规格编号（`docs/design/`）。域前缀长度不一
///   （`GOV` 三位、`QUANT` 五位），所以这里不能写死 `{3}`
/// - `C-NN` —— 常量编号（`docs/reference/constants.md`）
/// - `ADR-NNNN` —— 架构决策（`docs/adr/`）
/// - `R<n>` —— 本文件里的规则自身
final RegExp _specTagPattern = RegExp(
  r'SPEC-[A-Z]+-\d{3}|\bC-\d{2}\b|ADR-\d{4}|\bR\d\b',
);

/// 写不出标号时的显式豁免（后面必须跟理由）。
const String _noSpecMarker = '无 SPEC';

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

  // R3 不限路径：`Event` 的子类可能出现在任何一层，按路径过滤会漏。
  unit.accept(_EventAppendOnlyVisitor(parsed, normalized, issues));

  if (_isVisualChannel(normalized)) {
    unit.accept(_SourceNotVisualVisitor(parsed, normalized, issues));
  }

  if (_isTestFile(normalized)) {
    unit.accept(_TestSpecTagVisitor(parsed, normalized, issues));
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

/// 收集「能构造出改写历史事件」的写法：可变字段、`copyWith`、`EventStore` 上的删除 / 覆盖方法。
class _EventAppendOnlyVisitor extends RecursiveAstVisitor<void> {
  _EventAppendOnlyVisitor(this._parsed, this._path, this._issues);

  final ParseStringResult _parsed;
  final String _path;
  final List<LintIssue> _issues;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final String name = node.namePart.typeName.lexeme;

    if (name == _eventStoreClassName) {
      for (final ClassMember member in node.body.members) {
        if (member is MethodDeclaration && _forbiddenStoreMethods.contains(member.name.lexeme)) {
          _report(
            member.offset,
            '`EventStore` 不得有 `${member.name.lexeme}()` —— 历史事件不可修改或删除（`SPEC-FND-012`）',
          );
        }
      }
    } else if (name == _eventClassName || _inheritsEvent(node)) {
      for (final ClassMember member in node.body.members) {
        if (member is FieldDeclaration && !member.fields.isFinal && !member.fields.isConst) {
          _report(member.offset, '`$name` 的字段必须 `final` —— 事件不可变（`SPEC-FND-012`）');
        } else if (member is MethodDeclaration && member.name.lexeme == _copyWithName) {
          _report(
            member.offset,
            '`$name` 不得有 `copyWith()` —— 改动须新增事件，不得复制改写（`SPEC-FND-012`）',
          );
        }
      }
    }

    super.visitClassDeclaration(node);
  }

  bool _inheritsEvent(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause != null && extendsClause.superclass.name.lexeme == _eventClassName) {
      return true;
    }
    final ImplementsClause? implementsClause = node.implementsClause;
    if (implementsClause != null &&
        implementsClause.interfaces.any((NamedType t) => t.name.lexeme == _eventClassName)) {
      return true;
    }
    final WithClause? withClause = node.withClause;
    if (withClause != null &&
        withClause.mixinTypes.any((NamedType t) => t.name.lexeme == _eventClassName)) {
      return true;
    }
    return false;
  }

  void _report(int offset, String message) {
    _issues.add(
      LintIssue(
        ruleId: ruleEventAppendOnly,
        path: _path,
        line: _lineOf(_parsed, offset),
        message: message,
      ),
    );
  }
}

/// 查视图层入参里有没有源。
///
/// 两道判据并用：**类型**（`SourceRef` / `SourceSegment`）与**参数名**
/// （`source` / `sources` / `sourceRef(s)` / `sourceSegment(s)`）。只看类型会漏掉
/// 那些先收 `Object?` 再往下转的写法；只看名字会误报 `resourceId` 这类无关参数。
class _SourceNotVisualVisitor extends RecursiveAstVisitor<void> {
  _SourceNotVisualVisitor(this._parsed, this._path, this._issues);

  final ParseStringResult _parsed;
  final String _path;
  final List<LintIssue> _issues;

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _check(node.parameters);
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final FormalParameterList? params = node.parameters;
    if (params != null) {
      _check(params);
    }
    super.visitMethodDeclaration(node);
  }

  void _check(FormalParameterList params) {
    for (final FormalParameter param in params.parameters) {
      final String typeName = param.type is NamedType
          ? (param.type! as NamedType).name.lexeme
          : '';
      final String paramName = (param.name?.lexeme ?? '').toLowerCase();
      if (_sourceTypeNames.contains(typeName) || _sourceParamName.hasMatch(paramName)) {
        _issues.add(
          LintIssue(
            ruleId: ruleSourceNotVisual,
            path: _path,
            line: _lineOf(_parsed, param.offset),
            message: '视图层入参不得接收源（`${typeName.isEmpty ? paramName : typeName}`）'
                ' —— 源不进任何视觉通道（`SPEC-VIEW-004`）',
          ),
        );
      }
    }
  }
}

/// 查每个测试有没有标出「守的是哪一条」。
class _TestSpecTagVisitor extends RecursiveAstVisitor<void> {
  _TestSpecTagVisitor(this._parsed, this._path, this._issues);

  final ParseStringResult _parsed;
  final String _path;
  final List<LintIssue> _issues;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // 只看裸 `test(...)` / `testWidgets(...)`：`foo.test()` 是别的东西。
    if (node.target == null) {
      final String name = node.methodName.name;
      if (name == 'test' || name == 'testWidgets') {
        final NodeList<Argument> args = node.argumentList.arguments;
        if (args.isNotEmpty) {
          // 用模式匹配取字面量：`argumentExpression` 已 deprecated、
          // `argumentExpression2` 标了 experimental，两个都不该在钉死版本的仓里用。
          if (args.first case final StringLiteral literal) {
            final String? label = literal.stringValue;
            if (label != null && !label.contains(_noSpecMarker) && !_specTagPattern.hasMatch(label)) {
              _issues.add(
                LintIssue(
                  ruleId: ruleTestSpecTag,
                  path: _path,
                  line: _lineOf(_parsed, node.offset),
                  message: '测试未标裁定来源：`$label`'
                      ' —— 名后补 `（SPEC-XXX-NNN）`，或写 `（无 SPEC：<理由>）`',
                ),
              );
            }
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

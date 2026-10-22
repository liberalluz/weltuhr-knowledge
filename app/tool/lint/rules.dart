/// 九条架构与测试规范规则的实现。
///
/// - `R1` / `R2` —— 分层与常量来源（首建即在此）。
/// - `R3` / `R4` —— 把两条「只活在注释里」的裁定变成可执行检查：
///   事件只 append（`SPEC-FND-012`）· 源不进视觉通道（`SPEC-VIEW-004`）。
/// - `R5` —— 测试与裁定的追溯链：每个测试必须声明它守的是哪一条。
/// - `R6`–`R9` —— 节点类型形态（`ADR-0007`）：字段集按槽位两分、可学三项非空、
///   `Node` 不可直接构造、派生三项不作字段。四条都不依赖运行期，只读 AST。
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

/// R6：`StructuralNode` 类体内**不得**声明 `type` / `layer` / `requirements`。
///
/// `ADR-0007` 决策 1 的落点。这三项只对可学节点有意义，出现在结构节点上
/// 就打开了「在恒星上跑七步流程」的入口 —— 而且一路绿灯。
const String ruleStructuralNodeFieldSet = 'R6';

/// R7：`LearnableNode` 的三项**必须声明且非可空**。
///
/// 可空 = 留一个「这项有没有类型」的第三态，而 `mastery = d × s` 的分母
/// 依赖 `requirements` 恒定有值。台账写明「`null` 不是合法取值」。
const String ruleLearnableNodeFieldSet = 'R7';

/// R8：`Node` 不得被直接构造 —— 类体内无 `factory`，全仓无 `Node(...)`。
///
/// `sealed` 已在编译期挡住外部实例化，这条是**补一刀**：`factory` 能把封闭打开
/// （返回子类实例的同时绕过子类构造的槽位校验），而「有人加了个 factory」
/// 编译不报错、测试也不红。
const String ruleNodeNoDirectConstruction = 'R8';

/// R9：`path` / `inScope` / `depth` 不得作为 `Node` 及其子类的字段。
///
/// 三项都是派生值（`ADR-0007` 决策 2）。存成字段的后果不是多一份数据，
/// 而是**两份会不一致的数据**：父节点改名后 `path` 不跟着变，而所有按
/// `path` 比对的地方都还在用旧值 —— 没有断言会红。
const String ruleNodeNoDerivedFields = 'R9';

/// R10：append-only 存储**接口的方法面是封闭集**。
///
/// `R3` 列的是「禁止的方法名」—— 黑名单只能拦住**想到过**的名字。有人往
/// `AppendOnlyStoreFs` 里加一个 `writeStringAtomic`，它不在名单里，于是整条判据
/// 静默失效。这正是 `R-08` 的原话：「凡靠约定保证的，先问『违反它会不会有任何
/// 东西变红』」—— 对「**加**一个方法」这个方向，原来的答案是不会。
///
/// 本条把方向翻过来：接口体里**只允许**白名单上的方法，多一个就报，不管它叫什么。
/// 「事件区多了一个方法」这件事本身需要一次决定，而不是靠命名撞车才发现。
///
/// ⚠️ **只查接口声明体，不查实现类**：`DartIoPackFs` 同时 `implements PackFs,
/// WritableStoreFs, AppendOnlyStoreFs` —— 它**应当**有 `writeStringAtomic`。
/// 按实现类查会把这种合法的能力叠加判成违规，那种规则活不过一次重构。
/// 洞在接口上：接口一开，所有实现者都被要求提供它。
///
/// ⚠️ **白名单里没有 `write*` 前缀匹配**：前缀是启发式（`writeThroughCache()`
/// 这种读方法也会中招），而封闭集不需要启发式 —— 不在集合里就是新增。
const String ruleAppendOnlySurface = 'R10';

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
bool _isTestFile(String path) =>
    path.startsWith('test/') || path.contains('/test/');

String _normalize(String path) => path.replaceAll(r'\', '/');

/// 事件类名（`SPEC-FND-012`）。
const String _eventClassName = 'Event';
const String _copyWithName = 'copyWith';

/// `EventStore` 与存储三区里的事件区接口（`SPEC-FND-012` · `entity-fields` §〇）。
///
/// 名单从单名改成集合，是因为笔 3 立了 `AppendOnlyStoreFs` —— 名字里不带
/// `Event`，但**同样不许出现改写方法**。只按 `EventStore` 精确匹配的话，新接口
/// 上长出一个 `clear()` 不会被任何东西拦住，而它恰恰就是「清空历史」的写法。
/// 不做「名字以 `Store` 结尾」这类启发式：`StoreLayout` 不是 append-only 存储，
/// 会被误报。
const Set<String> _appendOnlyClassNames = <String>{
  'EventStore',
  'AppendOnlyStoreFs',
};

/// append-only 存储**接口**与它允许的方法集（`R10`）。
///
/// 与 `_forbiddenStoreMethods` 的分工：那张表是**黑名单**（`R3`，查 `EventStore`
/// 与 `AppendOnlyStoreFs` 的类体里有没有这些名字），本表是**白名单**（多一个就报）。
/// 两张表都留着不是冗余 —— 黑名单管「改」，白名单管「加」。
///
/// 实现类不在本表范围内（见 `R10` 的说明）。
const Map<String, Set<String>> _appendOnlySurfaces = <String, Set<String>>{
  'EventStore': <String>{'append', 'readAll', 'byId'},
  'AppendOnlyStoreFs': <String>{'appendLine'},
};

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

/// 节点类型名（`ADR-0007`）。
const String _nodeBaseName = 'Node';
const String _structuralNodeName = 'StructuralNode';
const String _learnableNodeName = 'LearnableNode';

/// 只对可学节点有意义的字段（`R6` 禁出现在 `StructuralNode`，`R7` 要求在
/// `LearnableNode` 上非可空）。
const Set<String> _learnableOnlyFieldNames = <String>{
  'type',
  'layer',
  'requirements',
};

/// 派生字段（`R9` 禁出现在 `Node` 及其子类）。
const Set<String> _derivedFieldNames = <String>{'path', 'inScope', 'depth'};

/// 测试名里合法的裁定标号。
///
/// - `SPEC-XXX-NNN` —— 设计规格编号（`docs/specs/`）。域前缀长度不一
///   （`GOV` 三位、`QUANT` 五位），所以这里不能写死 `{3}`
/// - `C-NN` —— 常量编号（`docs/specs/constants.md`）
/// - `ADR-NNNN` —— 架构决策（`docs/decisions/`）
/// - `R<n>` —— 本文件里的规则自身。⚠️ 写成 `\d+` 不是 `\d`：`R10` 出现时
///   `\bR\d\b` **匹配不到**（`1` 与 `0` 都是词字符，中间没有词边界），
///   于是「新规则自己的测试标了号反而被判没标号」—— 这条正则在写的时候
///   规则只有九条，第十条一来就露馅
final RegExp _specTagPattern = RegExp(
  r'SPEC-[A-Z]+-\d{3}|\bC-\d{2}\b|ADR-\d{4}|\bR\d+\b',
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
    for (final ImportDirective directive
        in unit.directives.whereType<ImportDirective>()) {
      final String? uri = directive.uri.stringValue;
      if (uri == null) {
        continue;
      }
      final bool forbidden =
          _forbiddenUriPrefixes.any(uri.startsWith) ||
          uri.contains('/features/');
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

  // R6 / R7 / R9 与 R3 同理按**类型名**而非路径生效：`Node` 的子类可能落在任何层。
  unit.accept(_NodeShapeVisitor(parsed, normalized, issues));

  // R8 也按类型名：直接构造 `Node(...)` 与 `Node` 类体内的 `factory` 都算。
  unit.accept(_NodeConstructionVisitor(parsed, normalized, issues));

  // R10 同理按接口名：`EventStore` / `AppendOnlyStoreFs` 的声明可能落在任何层。
  unit.accept(_AppendOnlySurfaceVisitor(parsed, normalized, issues));

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

    if (_appendOnlyClassNames.contains(name)) {
      for (final ClassMember member in node.body.members) {
        if (member is MethodDeclaration &&
            _forbiddenStoreMethods.contains(member.name.lexeme)) {
          _report(
            member.offset,
            '`$name` 不得有 `${member.name.lexeme}()` —— 历史事件不可修改或删除（`SPEC-FND-012`）',
          );
        }
      }
    } else if (name == _eventClassName || _inheritsEvent(node)) {
      for (final ClassMember member in node.body.members) {
        if (member is FieldDeclaration &&
            !member.fields.isFinal &&
            !member.fields.isConst) {
          _report(
            member.offset,
            '`$name` 的字段必须 `final` —— 事件不可变（`SPEC-FND-012`）',
          );
        } else if (member is MethodDeclaration &&
            member.name.lexeme == _copyWithName) {
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
    if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == _eventClassName) {
      return true;
    }
    final ImplementsClause? implementsClause = node.implementsClause;
    if (implementsClause != null &&
        implementsClause.interfaces.any(
          (NamedType t) => t.name.lexeme == _eventClassName,
        )) {
      return true;
    }
    final WithClause? withClause = node.withClause;
    if (withClause != null &&
        withClause.mixinTypes.any(
          (NamedType t) => t.name.lexeme == _eventClassName,
        )) {
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

/// 查 append-only 存储**接口的方法面**（`R10`）。
///
/// 只认声明体本身，不认实现类 —— 理由见 `ruleAppendOnlySurface` 的说明。
class _AppendOnlySurfaceVisitor extends RecursiveAstVisitor<void> {
  _AppendOnlySurfaceVisitor(this._parsed, this._path, this._issues);

  final ParseStringResult _parsed;
  final String _path;
  final List<LintIssue> _issues;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final String name = node.namePart.typeName.lexeme;
    final Set<String>? allowed = _appendOnlySurfaces[name];

    if (allowed != null) {
      for (final ClassMember member in node.body.members) {
        if (member is! MethodDeclaration) {
          continue;
        }
        final String method = member.name.lexeme;
        // 私有成员是实现者的内部辅助，不进调用面。
        if (method.startsWith('_') || allowed.contains(method)) {
          continue;
        }
        _report(
          member.offset,
          '`$name` 只允许 `${allowed.join("` / `")}`，'
          '出现 `$method()` 即接口面被扩大 —— 事件区就不再是「只能追加」'
          '（`SPEC-FND-012`）',
        );
      }
    }

    super.visitClassDeclaration(node);
  }

  void _report(int offset, String message) {
    _issues.add(
      LintIssue(
        ruleId: ruleAppendOnlySurface,
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
      if (_sourceTypeNames.contains(typeName) ||
          _sourceParamName.hasMatch(paramName)) {
        _issues.add(
          LintIssue(
            ruleId: ruleSourceNotVisual,
            path: _path,
            line: _lineOf(_parsed, param.offset),
            message:
                '视图层入参不得接收源（`${typeName.isEmpty ? paramName : typeName}`）'
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
            if (label != null &&
                !label.contains(_noSpecMarker) &&
                !_specTagPattern.hasMatch(label)) {
              _issues.add(
                LintIssue(
                  ruleId: ruleTestSpecTag,
                  path: _path,
                  line: _lineOf(_parsed, node.offset),
                  message:
                      '测试未标裁定来源：`$label`'
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

/// 取类里声明的字段：`字段名 -> 类型标注`（标注可为 `null`，即类型推断）。
///
/// 走 `FieldDeclaration.fields.variables` 而不是按行正则：一行可声明多个
/// （`final String a, b;`），正则只能拿到第一个。
Map<String, TypeAnnotation?> _fieldsOf(ClassDeclaration node) {
  final result = <String, TypeAnnotation?>{};
  for (final ClassMember member in node.body.members) {
    if (member is! FieldDeclaration) {
      continue;
    }
    for (final VariableDeclaration variable in member.fields.variables) {
      result[variable.name.lexeme] = member.fields.type;
    }
  }
  return result;
}

/// 类型标注是否可空（`String?` 之类）。
///
/// 只认 `NamedType.question`：`dynamic` / 无标注都不算「声称可空」——
/// 无标注是推断，不是把 `null` 写进契约。
bool _isNullableType(TypeAnnotation? type) =>
    type is NamedType && type.question != null;

/// 查节点三类的字段集：`R6` 结构节点无可学字段 · `R7` 可学三项非空 · `R9` 无派生字段。
class _NodeShapeVisitor extends RecursiveAstVisitor<void> {
  _NodeShapeVisitor(this._parsed, this._path, this._issues);

  final ParseStringResult _parsed;
  final String _path;
  final List<LintIssue> _issues;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final String name = node.namePart.typeName.lexeme;
    final Map<String, TypeAnnotation?> fields = _fieldsOf(node);

    if (name == _structuralNodeName) {
      for (final String field in _learnableOnlyFieldNames) {
        if (fields.containsKey(field)) {
          _report(
            ruleStructuralNodeFieldSet,
            node.offset,
            '`$name` 不得声明 `$field` —— 那三项只属于可学节点（`ADR-0007` 决策 1）',
          );
        }
      }
    }

    if (name == _learnableNodeName) {
      for (final String field in _learnableOnlyFieldNames) {
        final TypeAnnotation? type = fields[field];
        if (!fields.containsKey(field)) {
          _report(
            ruleLearnableNodeFieldSet,
            node.offset,
            '`$name` 必须声明 `$field` —— 三项一个都不能少（`ADR-0007` 决策 1）',
          );
        } else if (_isNullableType(type)) {
          _report(
            ruleLearnableNodeFieldSet,
            node.offset,
            '`$name.$field` 不得可空 —— `null` 不是合法取值（`ADR-0007` 决策 1）',
          );
        }
      }
    }

    if (name == _nodeBaseName || _inheritsNode(node)) {
      for (final String field in _derivedFieldNames) {
        if (fields.containsKey(field)) {
          _report(
            ruleNodeNoDerivedFields,
            node.offset,
            '`$name` 不得声明 `$field` —— 派生项不入字段（`ADR-0007` 决策 2）',
          );
        }
      }
    }

    super.visitClassDeclaration(node);
  }

  /// 是否直接继承 / 实现 `Node`。只看一层：`sealed` 已限定子类同库，
  /// 而孙类必须经子类，够用。多套一层会让「谁算节点」变成图遍历，
  /// 收益不抵复杂度。
  bool _inheritsNode(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == _nodeBaseName) {
      return true;
    }
    final ImplementsClause? implementsClause = node.implementsClause;
    if (implementsClause != null &&
        implementsClause.interfaces.any(
          (NamedType t) => t.name.lexeme == _nodeBaseName,
        )) {
      return true;
    }
    return false;
  }

  void _report(String ruleId, int offset, String message) {
    _issues.add(
      LintIssue(
        ruleId: ruleId,
        path: _path,
        line: _lineOf(_parsed, offset),
        message: message,
      ),
    );
  }
}

/// 查 `Node` 有没有被直接构造：`R8`。
class _NodeConstructionVisitor extends RecursiveAstVisitor<void> {
  _NodeConstructionVisitor(this._parsed, this._path, this._issues);

  final ParseStringResult _parsed;
  final String _path;
  final List<LintIssue> _issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final NamedType type = node.constructorName.type;
    if (type.name.lexeme == _nodeBaseName) {
      _report(
        node.offset,
        '不得直接构造 `Node` —— `sealed` 已封闭，只能建 `StructuralNode` / `LearnableNode`',
      );
    }
    super.visitInstanceCreationExpression(node);
  }

  /// ⚠️ **必须同时看 `MethodInvocation`**：不带 `new` / `const` 的构造调用
  /// （`Node(...)`）在 AST 里是 `MethodInvocation` 而不是
  /// `InstanceCreationExpression` —— 解析期分不清「构造函数」与「同名函数」，
  /// 只有解析器补上元素模型之后才定型。只查后者会漏掉最常见的写法，
  /// 而这条规则恰恰要在**没有解析器**的场景下也能报。
  ///
  /// `Node.create()` 这类带目标的调用不算：`target` 非空即已排除。
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == _nodeBaseName) {
      _report(
        node.offset,
        '不得直接构造 `Node` —— `sealed` 已封闭，只能建 `StructuralNode` / `LearnableNode`',
      );
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.namePart.typeName.lexeme == _nodeBaseName) {
      for (final ClassMember member in node.body.members) {
        if (member is ConstructorDeclaration && member.factoryKeyword != null) {
          _report(member.offset, '`Node` 不得有 factory 构造 —— 它会在子类的槽位校验之外造出实例');
        }
      }
    }
    super.visitClassDeclaration(node);
  }

  void _report(int offset, String message) {
    _issues.add(
      LintIssue(
        ruleId: ruleNodeNoDirectConstruction,
        path: _path,
        line: _lineOf(_parsed, offset),
        message: message,
      ),
    );
  }
}

/// 源（材料）—— `entity-fields` §11。
///
/// 笔 5c 之前它与 `content.dart` 里的旧 `SourceRef`（`excerpts` 段，六轴时代
/// 的「选段」）同名并存。旧类已随 `Item` 一并删除，同名问题随之消失。
library;

import '../enums.dart';
import '../json.dart';

/// 源的一段最小结构化摘录 —— 保证离线可读（`entity-fields` §11）。
class SourceSegment {
  const SourceSegment({
    required this.text,
    required this.locator,
    required this.license,
  });

  factory SourceSegment.fromJson(JsonMap json) => SourceSegment(
    text: requireString(json, 'text'),
    locator: requireString(json, 'locator'),
    license: requireString(json, 'license'),
  );

  final String text;

  /// 页码 / 锚点。
  final String locator;
  final String license;

  JsonMap toJson() => <String, Object?>{
    'text': text,
    'locator': locator,
    'license': license,
  };
}

/// 适用范围（`entity-fields` §11 `appliesTo`）。
///
/// **两个键都不能省**：`axes` 让「整条轴适用」不必枚举根节点 id；
/// `nodeScope` 才是实际过滤依据（`nodeScope ∩ 子树`）。旧的 `spaceId`
/// （一空间一包已废）与 `sixAxis.stack`（六轴已废）**全部失效**。
class SourceAppliesTo {
  const SourceAppliesTo({required this.axes, required this.nodeScope});

  factory SourceAppliesTo.fromJson(JsonMap json) => SourceAppliesTo(
    axes: requireStringList(json, 'axes').map(Axis.fromWire).toList(growable: false),
    nodeScope: requireStringList(json, 'node_scope'),
  );

  final List<Axis> axes;
  final List<String> nodeScope;

  JsonMap toJson() => <String, Object?>{
    'axes': axes.map((Axis a) => a.name).toList(),
    'node_scope': nodeScope,
  };
}

/// 源。**换源不改观感**：源不进任何视觉通道（`SPEC-VIEW-004`）。
class SourceRef {
  const SourceRef({
    required this.id,
    required this.name,
    required this.kind,
    required this.version,
    required this.appliesTo,
    this.authorityLevel,
    this.segments = const <SourceSegment>[],
  });

  factory SourceRef.fromJson(JsonMap json) {
    final Object? authority = json['authority_level'];
    final Object? segments = json['segments'];
    return SourceRef(
      id: requireString(json, 'id'),
      name: requireString(json, 'name'),
      kind: SourceKind.fromWire(requireString(json, 'kind')),
      version: requireString(json, 'version'),
      appliesTo: SourceAppliesTo.fromJson(requireMap(json, 'appliesTo')),
      authorityLevel: authority == null
          ? null
          : AuthorityLevel.fromWire('$authority'),
      segments: segments == null
          ? const <SourceSegment>[]
          : requireMapList(
              json,
              'segments',
            ).map(SourceSegment.fromJson).toList(growable: false),
    );
  }

  final String id;
  final String name;
  final SourceKind kind;

  /// **仅 `material` 需要**；`catalog` 本身就是权威。
  final AuthorityLevel? authorityLevel;

  /// 源自身的版本。
  final String version;

  /// **仅 `material`**；`catalog` 为空列表。
  final List<SourceSegment> segments;

  final SourceAppliesTo appliesTo;

  /// `catalog` 不参与 ①② 候选 —— 它绑 `Node.catalog_refs[]`，
  /// 回答「这个 `0812` 依据哪份文件」，混进候选卡会让用户无从选择。
  bool get isCatalog => kind == SourceKind.catalog;

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'kind': kind.name,
    if (authorityLevel != null) 'authority_level': authorityLevel!.name,
    'version': version,
    if (segments.isNotEmpty)
      'segments': segments.map((SourceSegment s) => s.toJson()).toList(),
    'appliesTo': appliesTo.toJson(),
  };
}

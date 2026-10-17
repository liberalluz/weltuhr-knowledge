/// 小包夹具：需要**控制形状**的测试自己搭一个包。
///
/// 为什么不复用 α 包：α 包 150 项全在圈内、没有一个圈外项，也没有一对「措辞
/// 不同」的标题。分诊的四类里有两类在真实包里**根本构造不出来** —— 拿真包去
/// 测它们，只能测到「没有走到那条分支」。
///
/// 与 `alpha_pack.dart` 的分工：那个读真产物、验「真实形状下不崩」；这个只造
/// 最小可判形状、验判据。两个都要 —— 只有真包会暴露「字段其实叫别的名字」，
/// 只有夹具能造出四类分诊。
library;

import 'dart:convert';

import 'package:project_knowledge/core/pack/pack_parse.dart';

/// 夹具里的一项。
class FixtureItem {
  const FixtureItem(
    this.id,
    this.title, {
    this.domainId = 'python/lexical',
    this.inScope = true,
    this.ability = '基础语法',
  });

  final String id;
  final String title;
  final String domainId;

  /// `false` = 圈外邻项（树里画虚线、宇宙里不画）。
  final bool inScope;

  /// 六轴里唯一给了值的那个 —— 让「命中轴取值」这类用例有东西可中。
  final String ability;
}

/// 搭一个包。[domainIds] 缺省取各项用到的域（去重、保序）。
LoadedPack fixturePack(
  List<FixtureItem> items, {
  String spaceId = 'python',
  String spaceName = 'Python 语法分层',
  List<String>? domainIds,
}) {
  final Map<String, Object?> manifest = <String, Object?>{
    'id': spaceId,
    'name': spaceName,
    'version': '0.1.0',
    'sixAxis': <String, String>{'subject': '计算机科学'},
    'accent': '#3776ab',
    'order': 10,
    'domainIds':
        domainIds ??
        <String>{for (final FixtureItem item in items) item.domainId}
            .toList(growable: false),
  };
  final Map<String, Object?> pack = <String, Object?>{
    'meta': <String, Object?>{'space': spaceId, 'version': '0.1.0'},
    'items': <Map<String, Object?>>[
      for (final FixtureItem item in items)
        <String, Object?>{
          'id': item.id,
          'title': item.title,
          'sixAxis': <String, String>{
            'subject': '计算机科学',
            'ability': item.ability,
          },
          'layer': 'persistent',
          'type': 'declarative',
          'requirements': <String, Object?>{
            'boundary': 'present',
            'justification': 'present',
            'proposition': 'present',
            'relation': 'present',
            'how': 'present',
            'tacit': 'not_externalizable',
          },
          'sourceRefs': <String>[],
          'domainId': item.domainId,
          'inScope': item.inScope,
        },
    ],
    'edges': <Map<String, Object?>>[],
    'schemes': <Map<String, Object?>>[],
    'questions': <Map<String, Object?>>[],
    'excerpts': <Map<String, Object?>>[],
  };
  return parsePack(
    manifestJson: jsonEncode(manifest),
    packJson: jsonEncode(pack),
  );
}

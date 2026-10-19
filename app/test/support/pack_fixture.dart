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
    this.sourceRefs = const <String>[],
  });

  final String id;
  final String title;
  final String domainId;

  /// `false` = 圈外邻项（树里画虚线、宇宙里不画）。
  final bool inScope;

  /// 六轴里唯一给了值的那个 —— 让「命中轴取值」这类用例有东西可中。
  final String ability;

  /// 指向 `excerpts[].id`。Planner 的覆盖矩阵（`Item.sourceRefs` ∩
  /// `Scheme.nodes`）靠它，其余用例留空。
  final List<String> sourceRefs;
}

/// 搭一个包。[domainIds] 缺省取各项用到的域（去重、保序）。
///
/// [edges] 是 `[from, to]` 对（`from` = 前置、`to` = 后继），全部按 `strong`
/// 建边。缺省无边 ⇒ **每一项都是 `⪯` 树的根**，而「恒星系数量」这类判据要的
/// 正是「有几棵树」，所以需要造边时由调用方给。
///
/// [itemType] 只给需要验「某个视觉通道**不看** `type`」的用（`VIEW-040` 第 1 条：
/// `Z4` 的恒星外观不能按 `type` 分）。缺省 `declarative`，与其它用例无关。
/// [subject] 同时写进清单与各项的 `subject` 轴 —— 跨根合并取值域的用例
/// （`V-1f2`）需要两个**学科不同**的包，而这个轴在夹具里原本是写死的。
LoadedPack fixturePack(
  List<FixtureItem> items, {
  String spaceId = 'python',
  String spaceName = 'Python 语法分层',
  List<String>? domainIds,
  List<List<String>> edges = const <List<String>>[],
  String itemType = 'declarative',
  String subject = '计算机科学',
  Map<String, List<String>> schemes = const <String, List<String>>{},
  List<Map<String, Object?>> excerpts = const <Map<String, Object?>>[],
}) {
  final Map<String, Object?> manifest = <String, Object?>{
    'id': spaceId,
    'name': spaceName,
    'version': '0.1.0',
    'sixAxis': <String, String>{'subject': subject},
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
            'subject': subject,
            'ability': item.ability,
          },
          'layer': 'persistent',
          'type': itemType,
          'requirements': <String, Object?>{
            'boundary': 'present',
            'justification': 'present',
            'proposition': 'present',
            'relation': 'present',
            'how': 'present',
            'tacit': 'not_externalizable',
          },
          'sourceRefs': item.sourceRefs,
          'domainId': item.domainId,
          'inScope': item.inScope,
        },
    ],
    'edges': <Map<String, Object?>>[
      for (int i = 0; i < edges.length; i++)
        <String, Object?>{
          'id': 'edge-$i',
          'from': edges[i][0],
          'to': edges[i][1],
          'type': 'strong',
        },
    ],
    'schemes': <Map<String, Object?>>[
      for (final MapEntry<String, List<String>> e in schemes.entries)
        <String, Object?>{
          'id': e.key,
          'name': e.key,
          'nodes': e.value,
          'authorityLevel': 'L2',
        },
    ],
    'questions': <Map<String, Object?>>[],
    'excerpts': excerpts,
  };
  return parsePack(
    manifestJson: jsonEncode(manifest),
    packJson: jsonEncode(pack),
  );
}

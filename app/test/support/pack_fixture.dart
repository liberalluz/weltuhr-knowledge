/// 小包夹具：需要**控制形状**的测试自己搭一个包。
///
/// 为什么不复用真实内容包：`content/python` 仍是六轴旧格式（`ADR-0005` §五
/// 「310 条 `items` 迁移」尚未开始），新解析器读不了它；而分诊的四类里有两类在
/// 真实内容里**根本构造不出来** —— 拿真数据去测它们，只能测到「没有走到那条
/// 分支」。
///
/// 夹具**走真解析器**（[readPack]）而不是直接 `new PackContent(...)`：绕过解析
/// 就等于自己编一份实体、自己判过（`X-05`），JSON 键名写错也照样绿。所以这里
/// 只负责拼 JSON，实体由生产代码给。
///
/// ## 与旧夹具的三处差别（笔 5c）
///
/// | 旧 | 新 |
/// |---|---|
/// | `FixtureItem.domainId` | `FixtureNode.parentId`（父=树上真节点，不是字符串标签） |
/// | `FixtureItem.inScope`（**字段**） | 没有了 —— `inScope` 由 `subtreeRoot` 派生（`ADR-0007` 决策 2），要造圈外项就把它的父挂到子树外 |
/// | `FixtureItem.title` / `ability`（六轴） | `FixtureNode.name` / `axis`（三轴，只有三个取值） |
library;

import 'dart:convert';

import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';

/// 夹具里的一个节点。
///
/// 槽位决定它带哪些字段（`nodeFromJson` 按 `level_slot` 分派）：`planet` 必带
/// `type` / `layer` / `requirements`，其余**必不带**。这里的 `toJson` 照此写，
/// 所以「结构节点上写了个 `type`」这类错在夹具层就造不出来。
class FixtureNode {
  const FixtureNode(
    this.id,
    this.name, {
    this.slot = LevelSlot.planet,
    this.axis = Axis.major,
    this.parentId,
    this.officialCode,
    this.type = LearnableType.declarative,
    this.layer = Layer.persistent,
    this.sourceRefs = const <String>[],
    this.steps = const <EntryStep>[],
    this.criteria = const <Criterion>[],
    this.quiz = const <QuizItem>[],
    this.body,
  });

  final String id;
  final String name;
  final LevelSlot slot;
  final Axis axis;

  /// 主父（`ParentEdge.main`）。`null` = 树根 —— 夹具通常只有一个。
  final String? parentId;

  /// 官方码。树里兄弟排序的第一键（`TREE-011`），也为空时为 `null`。
  final String? officialCode;

  /// 仅 `planet`。
  final LearnableType type;
  final Layer layer;

  /// 仅 `planet`：写进 `NodeEntry.sourceRefs`（Planner 覆盖矩阵靠它）。
  final List<String> sourceRefs;

  /// 仅 `planet`：写进 `NodeEntry.steps[]`。
  final List<EntryStep> steps;

  final List<Criterion> criteria;
  final List<QuizItem> quiz;
  final String? body;

  bool get isPlanet => slot == LevelSlot.planet;

  /// `slug`：`id` 的末段。夹具不关心 slug 规则（那是 `triple_validator` 的事），
  /// 只保证同父不同 slug 即可 —— 但同一父下两个节点取同一个末段时，后面那个会
  /// 覆盖前面那个的 `path`，夹具不修，交由用例自己取不重复的 id。
  String get slug {
    final int cut = id.lastIndexOf(':');
    final String tail = cut < 0 ? id : id.substring(cut + 1);
    return tail.toLowerCase().replaceAll('_', '-');
  }

  Map<String, Object?> toJson(String packId) => <String, Object?>{
    'id': id,
    'axis': axis.name,
    'level_slot': slot.name,
    'official_code': officialCode,
    'name': name,
    'slug': slug,
    'scope': slot == LevelSlot.planet ? 'S4' : 'S0',
    'pack_id': packId,
    'status': 'live',
    'tags': <String>[],
    'catalog_refs': <String>[],
    if (isPlanet) ...<String, Object?>{
      'type': type.name,
      'layer': layer.name,
      'requirements': <String, Object?>{
        'boundary': 'present',
        'justification': 'present',
        'proposition': 'present',
        'relation': 'present',
        'how': 'present',
        'tacit': 'not_externalizable',
      },
    },
  };

  Map<String, Object?>? entryJson() {
    if (!isPlanet) {
      return null;
    }
    return <String, Object?>{
      'node_id': id,
      'summary': '$name 的一句话。',
      'outcomes': <String>['能说明$name'],
      'resources': <Map<String, Object?>>[],
      'aliases': <String>[],
      'keywords': <String>[],
      'body': body,
      'steps': steps.map((EntryStep s) => s.toJson()).toList(growable: false),
      'selfCheck': <String>[],
      'criteria': criteria.map((Criterion c) => c.toJson()).toList(growable: false),
      'quiz': quiz.map((QuizItem q) => q.toJson()).toList(growable: false),
      'source_refs': sourceRefs,
    };
  }
}

/// 搭一个包。
///
/// [nodes] 的父子关系由 [FixtureNode.parentId] 给出；`edges` 里其余三类按需给：
/// - [schemes]：体系 id → 节点 id 序列（`authority_level` 一律 `official`）
/// - [prerequisites]：`(前置, 后继)`，一律 `required` —— `⪯` 只认这一档
/// - [recommended]：`(前置, 后继)`，`recommended` 档（不参与 `⪯`，只影响排序）
/// - [sources]：源 id → 源名（`kind = material`，五档取 `official`）
///
/// `counts` 由节点现算，**不手填**：手填的计数与实扫不一致时 `readPack` 会拒，
/// 而夹具里那份不一致只会让每个用例都红在同一个地方。
PackContent fixturePack(
  List<FixtureNode> nodes, {
  String pluginId = 'python',
  String packName = 'Python 语法分层',
  List<String> kinds = const <String>['payload'],
  String attachTo = 'skeleton:major/080901',
  Map<String, List<String>> schemes = const <String, List<String>>{},
  List<(String, String)> prerequisites = const <(String, String)>[],
  List<(String, String)> recommended = const <(String, String)>[],
  Map<String, String> sources = const <String, String>{},
  Map<String, AuthorityLevel> sourceLevels = const <String, AuthorityLevel>{},
  Set<String> catalogSources = const <String>{},
  List<Map<String, Object?>> methods = const <Map<String, Object?>>[],
}) {
  int star = 0;
  int system = 0;
  int planet = 0;
  for (final FixtureNode node in nodes) {
    switch (node.slot) {
      case LevelSlot.star:
        star++;
      case LevelSlot.system:
        system++;
      case LevelSlot.planet:
        planet++;
      case LevelSlot.supercluster ||
          LevelSlot.group ||
          LevelSlot.galaxy ||
          LevelSlot.cluster:
        break;
    }
  }

  final Map<String, Object?> pack = <String, Object?>{
    'plugin_id': pluginId,
    'name': packName,
    'version': '0.1.0',
    'kinds': kinds,
    'namespace': pluginId,
    'schema_version': 1,
    'skeleton_requires': '>=1.0.0 <2.0.0',
    'deps': <Map<String, Object?>>[],
    'license': 'MIT',
    'author': 'fixture',
    'origin': 'fixture',
    'review_state': 'approved',
    'signature': null,
    'axes': <String>{
      for (final FixtureNode node in nodes) node.axis.name,
    }.toList(growable: false),
    // 骨架包 `kinds` 为空、无 `payload` facts（`ADR-0005` 决策 2：骨架全量内置、
    // 不走插件标准），因此这一段只能按 `kinds` 出现 —— 无条件写会让骨架包
    // 撞上 `Pack._verifyFacts` 的「没声明 kind 却有 facts」。
    if (kinds.contains('payload'))
      'payload': <String, Object?>{
        'attach_to': attachTo,
        'subtree_root': 'system',
        'level_range': <String>['system', 'planet'],
        'counts': <String, Object?>{'star': star, 'system': system, 'planet': planet},
        'official_code_coverage': false,
        'path_reservations': <Map<String, Object?>>[],
        'sources': sources.keys.toList(growable: false),
        'schemes': schemes.keys.toList(growable: false),
        'has_steps': nodes.any((FixtureNode n) => n.steps.isNotEmpty),
        'has_criteria': nodes.any((FixtureNode n) => n.criteria.isNotEmpty),
        'has_quiz': nodes.any((FixtureNode n) => n.quiz.isNotEmpty),
        'quiz_types': <String>['choice'],
        'est_minutes_coverage': 1.0,
      },
    'nodes': nodes.map((FixtureNode n) => n.toJson(pluginId)).toList(growable: false),
    'edges': <Map<String, Object?>>[
      for (final FixtureNode node in nodes)
        if (node.parentId != null)
          <String, Object?>{
            'type': 'parent',
            'child_id': node.id,
            'parent_id': node.parentId,
            'kind': 'main',
          },
      for (final (String, String) edge in prerequisites)
        <String, Object?>{
          'type': 'prerequisite',
          'from_id': edge.$1,
          'to_id': edge.$2,
          'strength': 'required',
        },
      for (final (String, String) edge in recommended)
        <String, Object?>{
          'type': 'prerequisite',
          'from_id': edge.$1,
          'to_id': edge.$2,
          'strength': 'recommended',
        },
    ],
    'entries': <Map<String, Object?>>[
      for (final FixtureNode node in nodes)
        if (node.entryJson() case final Map<String, Object?> entry) entry,
    ],
    'sources': <Map<String, Object?>>[
      for (final MapEntry<String, String> source in sources.entries)
        <String, Object?>{
          'id': source.key,
          'name': source.value,
          // `catalog` 不标 `authority_level` —— 它本身就是权威（`entity-fields` §11）。
          'kind': catalogSources.contains(source.key) ? 'catalog' : 'material',
          if (!catalogSources.contains(source.key))
            'authority_level':
                (sourceLevels[source.key] ?? AuthorityLevel.official).name,
          'version': '1',
          'segments': <Map<String, Object?>>[
            <String, Object?>{
              'text': '${source.value} 的原文摘录。',
              'locator': '§1',
              'license': 'MIT',
            },
          ],
          'appliesTo': <String, Object?>{
            'axes': <String>['major'],
            'node_scope': <String>[
              for (final FixtureNode node in nodes)
                if (node.isPlanet) node.id,
            ],
          },
        },
    ],
    'schemes': <Map<String, Object?>>[
      for (final MapEntry<String, List<String>> scheme in schemes.entries)
        <String, Object?>{
          'id': scheme.key,
          'name': scheme.key,
          'nodes': scheme.value,
          'authority_level': 'official',
        },
    ],
    'methods': methods,
  };
  return readPack(jsonEncode(pack));
}

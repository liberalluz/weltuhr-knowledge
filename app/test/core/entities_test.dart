/// 实体层的契约测试（`entity-fields` §2 / §3–§5 / §9 / §13）。
///
/// ## 笔 5c 把这份文件整份换掉了
///
/// 旧版全建在 `content.dart` 的 `Item` / `Edge` / `MethodStep` 上，那些类已随
/// 新本体删除。换过来时**判据没丢，只换了载体**，但有三处判据本身变了：
///
/// | 旧判据 | 新判据 |
/// |---|---|
/// | `EdgeType.unknown` 能解析 | **未知判别符直接抛** —— 三个判别符各自分派到 `ParentEdge` / `WormholeEdge` / `PrerequisiteEdge` |
/// | `MethodProfile.isCheckin` | `NodeEntry.isCheckin` —— 打卡式是「没有 `criteria`」，属内容侧，与方法无关 |
/// | `Plan.target.count` 由 `resolved` 派生 | `Plan` 不再持有 `resolved` / `target`：范围只落 `subtreeRoot` |
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/edge.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/core/entities/method.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/entities/requirement.dart';
import 'package:project_knowledge/core/entities/state.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/errors.dart';

Map<String, Object?> _nodeJson({
  String slot = 'planet',
  String axis = 'major',
  Map<String, Object?>? extra,
}) => <String, Object?>{
  'id': 'python:lambda',
  'axis': axis,
  'level_slot': slot,
  'name': 'Lambda 表达式',
  'slug': 'lambda',
  'scope': slot == 'planet' ? 'S4' : 'S0',
  'pack_id': 'python',
  'status': 'live',
  'tags': <String>[],
  'catalog_refs': <String>[],
  'official_code': null,
  ...?extra,
};

/// 六要件：3 present / 2 missing / 1 not_externalizable。
Map<String, Object?> _requirementsJson() => <String, Object?>{
  'boundary': 'present',
  'justification': 'missing',
  'proposition': 'present',
  'relation': 'missing',
  'how': 'not_externalizable',
  'tacit': 'present',
};

Map<String, Object?> _planetJson() => _nodeJson(
  extra: <String, Object?>{
    'type': 'declarative',
    'layer': 'persistent',
    'requirements': _requirementsJson(),
  },
);

Map<String, Object?> _entryJson() => <String, Object?>{
  'node_id': 'python:lambda',
  'summary': '一句话',
  'outcomes': <String>['能写'],
  'resources': <Map<String, Object?>>[],
  'aliases': <String>[],
  'keywords': <String>[],
  'steps': <Object?>[],
  'selfCheck': <String>[],
  'criteria': <Object?>[],
  'quiz': <Object?>[],
  'source_refs': <String>['src-official'],
};

void main() {
  group('节点两分与六要件', () {
    test('不可外化格不进深度分母（SPEC-QUANT-006）', () {
      final Requirements requirements = Requirements.fromJson(_requirementsJson());
      expect(requirements.completeCount, 3);
      expect(requirements.externalizableCount, 5);
    });

    test('六要件缺一格即格式错误，不补默认值（SPEC-PACK-009）', () {
      final Map<String, Object?> broken = _requirementsJson()..remove('tacit');
      expect(() => Requirements.fromJson(broken), throwsFormatException);
    });

    test('按 level_slot 分派：planet 是 LearnableNode，其余是 StructuralNode（ADR-0007 决策 1）', () {
      expect(nodeFromJson(_planetJson()), isA<LearnableNode>());
      expect(nodeFromJson(_nodeJson(slot: 'group', axis: 'discipline')), isA<StructuralNode>());
      // 槽位是类型的一部分：可学节点根本收不到 `level_slot` 参数，也就写不错。
      expect(nodeFromJson(_planetJson()).levelSlot, LevelSlot.planet);
    });

    test('行星缺 type / layer / requirements 不是「用默认值」而是坏数据（ADR-0007 决策 1）', () {
      // 三项只对可学节点有意义，结构节点上没有 —— 所以行星缺了它们不能补默认。
      for (final String key in <String>['type', 'layer', 'requirements']) {
        final Map<String, Object?> broken = _planetJson()..remove(key);
        expect(
          () => nodeFromJson(broken),
          throwsFormatException,
          reason: '缺 `$key` 时应报字段缺名',
        );
      }
    });

    test('骨架结构节点的 (axis, slot) 只认 12 对，`system` 是例外（ADR-0007 决策 4）', () {
      // `discipline` 轴只占 supercluster / group / star 三个槽位。
      expect(
        () => nodeFromJson(_nodeJson(slot: 'cluster', axis: 'discipline')),
        throwsA(isA<IllegalNodeSlotError>()),
      );
      // `system` 是载荷容器，轴继承自父恒星 ⇒ 三轴都合法，不查表。
      expect(
        nodeFromJson(_nodeJson(slot: 'system', axis: 'discipline')),
        isA<StructuralNode>(),
      );
    });
  });

  group('枚举取值与包数据同源', () {
    test('三态用蛇形 not_externalizable，不是 Dart 驼峰（SPEC-PACK-009）', () {
      expect(RequirementState.fromWire('present'), RequirementState.present);
      expect(
        RequirementState.fromWire('not_externalizable'),
        RequirementState.notExternalizable,
      );
      expect(RequirementState.notExternalizable.wire, 'not_externalizable');
      expect(
        () => RequirementState.fromWire('notExternalizable'),
        throwsFormatException,
      );
    });

    test('type 与 layer 取数据里的值，不是改写过的名字（无 SPEC：entity-fields §2 取值域）', () {
      expect(LearnableType.fromWire('declarative'), LearnableType.declarative);
      expect(LearnableType.fromWire('procedural'), LearnableType.procedural);
      expect(Layer.fromWire('ephemeral'), Layer.ephemeral);
      expect(() => LearnableType.fromWire('statement'), throwsFormatException);
      expect(() => Layer.fromWire('quick'), throwsFormatException);
    });
  });

  group('三类边按判别符分派', () {
    test('同一个 from_id / to_id，靠 type 一个字分开虫洞与先修（entity-fields §3–§5）', () {
      // 两条边字段名完全一样 —— 靠字段名猜必然分不清，所以判别符必须显式读。
      final NodeEdge wormhole = nodeEdgeFromJson(<String, Object?>{
        'type': 'wormhole',
        'from_id': 'python:a',
        'to_id': 'python:b',
        'kind': 'granularity',
      });
      final NodeEdge prerequisite = nodeEdgeFromJson(<String, Object?>{
        'type': 'prerequisite',
        'from_id': 'python:a',
        'to_id': 'python:b',
        'strength': 'required',
      });

      expect(wormhole, isA<WormholeEdge>());
      expect(prerequisite, isA<PrerequisiteEdge>());
      expect((prerequisite as PrerequisiteEdge).isRequired, isTrue);
      expect(
        (prerequisite).strength == EdgeStrength.recommended,
        isFalse,
        reason: '`recommended` 不参与 `⪯` 闭包，只影响排序',
      );
    });

    test('父子边区分主父与附加归属（entity-fields §3）', () {
      final ParentEdge main = nodeEdgeFromJson(<String, Object?>{
        'type': 'parent',
        'child_id': 'python:lambda',
        'parent_id': 'python:fn',
        'kind': 'main',
      }) as ParentEdge;

      expect(main.isMain, isTrue);
      expect(main.type, edgeTypeParent);
    });

    test('未知判别符直接抛 —— 打错字的边不该凭空消失（entity-fields §3–§5）', () {
      // 旧版这里有 `EdgeType.unknown` 这个合法取值，于是「写错类型名」与
      // 「作者明确声明一条未知边」压成同一个结果。新模型没有 unknown 档：
      // 图里少一条边的表象与「数据本来就没有」完全相同，没有断言会红。
      expect(
        () => nodeEdgeFromJson(<String, Object?>{
          'type': 'dependsOn',
          'from_id': 'python:a',
          'to_id': 'python:b',
        }),
        throwsFormatException,
      );
    });
  });

  group('EntryStep / 相位派生', () {
    test('读 → first；练 → both（SPEC-STEP-014）', () {
      final EntryStep read = EntryStep.fromJson(<String, Object?>{
        'operator': 'read',
        'instruction': '读一遍',
      });
      final EntryStep practice = EntryStep.fromJson(<String, Object?>{
        'operator': 'practice',
        'instruction': '练三遍',
      });
      expect(read.effectivePhase, StepPhase.first);
      expect(practice.effectivePhase, StepPhase.both);
    });

    test('作者可覆盖派生的 phase（SPEC-STEP-014）', () {
      final EntryStep step = EntryStep.fromJson(<String, Object?>{
        'operator': 'read',
        'instruction': '重读',
        'phase': 'review',
      });
      expect(step.effectivePhase, StepPhase.review);
    });

    test('步骤上没有 criteria —— 判据归 NodeEntry.criteria[]（entity-fields §9.1 / §9.2）', () {
      // 两处各写一个「判据」字段，就会出现「步骤说做到了、项末验收说没做到」。
      final EntryStep step = EntryStep.fromJson(<String, Object?>{
        'operator': 'practice',
        'instruction': '练三遍',
        'criteria': '连做三次不出错',
      });
      expect(step.toJson().containsKey('criteria'), isFalse);
    });
  });

  group('MethodProfile 两条校验', () {
    test('至少一个 review 步骤；全为读/例则判否（SPEC-STEP-027）', () {
      final MethodProfile ok = MethodProfile.fromJson(<String, Object?>{
        'id': 'm1',
        'name': '间隔重复',
        'origin': 'pack',
        'appliesTo': <String, Object?>{'type': 'procedural'},
        'steps': <Object?>[
          <String, Object?>{'operator': 'read', 'instruction': '读'},
          <String, Object?>{'operator': 'recall', 'instruction': '忆'},
        ],
      });
      final MethodProfile bad = MethodProfile.fromJson(<String, Object?>{
        'id': 'm2',
        'name': '只看不练',
        'origin': 'user',
        'appliesTo': <String, Object?>{},
        'steps': <Object?>[
          <String, Object?>{'operator': 'read', 'instruction': '读'},
          <String, Object?>{'operator': 'example', 'instruction': '看例'},
        ],
      });
      expect(ok.hasReviewStep, isTrue);
      expect(bad.hasReviewStep, isFalse);
    });

    test('任一步有 hint ⇒ 可给提示（SPEC-STEP-015 / SPEC-STEP-022）', () {
      final MethodProfile noHint = MethodProfile.fromJson(<String, Object?>{
        'id': 'm3',
        'name': '读一遍',
        'origin': 'user',
        'appliesTo': <String, Object?>{},
        'steps': <Object?>[
          <String, Object?>{'operator': 'read', 'instruction': '读'},
        ],
      });
      final MethodProfile withHint = MethodProfile.fromJson(<String, Object?>{
        'id': 'm4',
        'name': '带着问题读',
        'origin': 'user',
        'appliesTo': <String, Object?>{},
        'steps': <Object?>[
          <String, Object?>{
            'operator': 'read',
            'instruction': '读',
            'hint': '先想标题',
          },
        ],
      });
      expect(noHint.hasAnyHint, isFalse);
      expect(withHint.hasAnyHint, isTrue);
    });

    test('一份组合允许缺分支 —— 缺 = 不覆盖该类型（entity-fields §12）', () {
      const MethodBundle bundle = MethodBundle(
        id: 'b1',
        name: '只覆盖陈述',
        origin: CandidateOrigin.platform,
        byType: <LearnableType, String>{
          LearnableType.declarative: 'm1',
        },
      );
      expect(bundle.profileOf(LearnableType.declarative), 'm1');
      expect(bundle.profileOf(LearnableType.procedural), isNull);
    });
  });

  group('NodeEntry', () {
    test('没有 criteria 即打卡式 —— 它是学习痕迹，不通往出口（entity-fields §9.2）', () {
      final NodeEntry entry = NodeEntry.fromJson(_entryJson());
      expect(entry.isCheckin, isTrue);
      expect(entry.sourceRefs, <String>['src-official']);
    });
  });

  group('Note 三层显示优先级', () {
    test('authored > autoFilled > generated（SPEC-NOTE-008）', () {
      final Note note = Note.fromJson(<String, Object?>{
        'itemId': 'python:lambda',
        'sectionKey': 'lambda.basics',
        'layers': <String, String>{
          'generated': '生成层',
          'autoFilled': '自动补',
          'authored': '手写层',
        },
        'noteVersion': 3,
        'origin': 'standard',
      });
      expect(note.displayText, '手写层');
      expect(note.noteVersion, 3);
    });
  });

  group('Plan', () {
    Map<String, Object?> planJson() => <String, Object?>{
      'id': 'p1',
      'subtreeRoot': 'python:fn',
      'primaryAxis': 'major',
      'packVersions': <String, Object?>{
        'skeleton': '1.0.0',
        'payloads': <String, Object?>{'python': '1.2.0'},
      },
      'sourcePolicy': <String, Object?>{'primary': 'src-official'},
      'schemeId': 's1',
      'methodProfileId': 'm1',
      'version': 1,
    };

    test('范围只落 subtreeRoot —— 不存 resolved / target / count（entity-fields §13）', () {
      // 旧版存的 `target{selector, resolved}` 里，`resolved` 是派生值：载荷变化
      // 时必须重算，存下来就会出现「参照集合指向已卸载的节点」而没有任何一处
      // 会报错。键换成 `subtreeRoot` 之后，这件事从「不该做」变成「做不到」。
      final Plan plan = Plan.fromJson(planJson());
      expect(plan.subtreeRoot, 'python:fn');

      for (final String gone in <String>['target', 'resolved', 'count', 'spaceId']) {
        expect(
          plan.toJson().containsKey(gone),
          isFalse,
          reason: '`$gone` 不该出现在 payload 里',
        );
      }
    });

    test('packVersions 是复合值：骨架单列、载荷按 plugin_id 记（entity-fields §13）', () {
      final Plan plan = Plan.fromJson(planJson());
      expect(plan.packVersions.skeleton, '1.0.0');
      expect(plan.packVersions.payloads, <String, String>{'python': '1.2.0'});
      expect(
        plan.packVersions.payloads.containsKey('skeleton'),
        isFalse,
        reason: '骨架混进 payloads 会与 `skeleton` 两处记账',
      );
      // 往返保真：换包之后旧计划要能按旧版解释。
      final Plan roundTrip = Plan.fromJson(plan.toJson());
      expect(roundTrip.packVersions.toJson(), plan.packVersions.toJson());
    });
  });
}

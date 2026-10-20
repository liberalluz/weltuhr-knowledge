import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/entities/content.dart';
import 'package:project_knowledge/core/entities/node.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/errors.dart';

ItemRequirements _requirements() =>
    const ItemRequirements(<RequirementKey, RequirementState>{
      RequirementKey.boundary: RequirementState.present,
      RequirementKey.justification: RequirementState.present,
      RequirementKey.proposition: RequirementState.present,
      RequirementKey.relation: RequirementState.present,
      RequirementKey.how: RequirementState.missing,
      RequirementKey.tacit: RequirementState.notExternalizable,
    });

StructuralNode _structural({
  Axis axis = Axis.discipline,
  LevelSlot slot = LevelSlot.group,
}) => StructuralNode(
  id: 'skeleton:n1',
  axis: axis,
  levelSlot: slot,
  name: '门类',
  slug: 'menlei',
  scope: Scope.s0,
  packId: 'skeleton',
  status: NodeStatus.live,
  tags: const <String>[],
  catalogRefs: const <String>[],
);

LearnableNode _learnable() => LearnableNode(
  id: 'pkg:x',
  axis: Axis.occupation,
  name: '技能项',
  slug: 'jineng',
  scope: Scope.s1,
  packId: 'pkg',
  status: NodeStatus.live,
  tags: const <String>['digital'],
  catalogRefs: const <String>['src-1'],
  officialCode: '4-04-01',
  type: LearnableType.procedural,
  layer: Layer.persistent,
  requirements: _requirements(),
);

void main() {
  group('StructuralNode 槽位校验', () {
    test('12 对合法组合全部可构造（ADR-0007）', () {
      expect(legalSkeletonSlots, hasLength(12));
      for (final (Axis axis, LevelSlot slot) in legalSkeletonSlots) {
        expect(
          () => _structural(axis: axis, slot: slot),
          returnsNormally,
          reason: '${axis.name} × ${slot.name} 应合法',
        );
      }
    });

    test('非法组合构造即抛 IllegalNodeSlotError（ADR-0007）', () {
      // 学科轴只到 star，没有星系这一级。
      expect(
        () => _structural(axis: Axis.discipline, slot: LevelSlot.galaxy),
        throwsA(isA<IllegalNodeSlotError>()),
      );
      expect(
        () => _structural(axis: Axis.major, slot: LevelSlot.cluster),
        throwsA(isA<IllegalNodeSlotError>()),
      );
    });

    test('system 不限轴 —— 载荷容器继承父恒星的轴（ADR-0007）', () {
      for (final Axis axis in Axis.values) {
        expect(
          () => _structural(axis: axis, slot: LevelSlot.system),
          returnsNormally,
          reason: '${axis.name} × system 应放行',
        );
      }
    });
  });

  group('LearnableNode 形态', () {
    test('levelSlot 被钉死为 planet，不由调用方传入（ADR-0007）', () {
      expect(_learnable().levelSlot, LevelSlot.planet);
    });

    test('三项非空字段有值，且 requirements 参与深度计算（ADR-0007）', () {
      final LearnableNode node = _learnable();
      expect(node.type, LearnableType.procedural);
      expect(node.layer, Layer.persistent);
      expect(node.requirements.completeCount, 4);
      expect(node.requirements.externalizableCount, 5);
    });

    test('载荷节点可无官方码（ADR-0007）', () {
      final LearnableNode node = LearnableNode(
        id: 'pkg:y',
        axis: Axis.discipline,
        name: '知识点',
        slug: 'zhishidian',
        scope: Scope.s4,
        packId: '',
        status: NodeStatus.live,
        tags: const <String>[],
        catalogRefs: const <String>[],
        type: LearnableType.declarative,
        layer: Layer.ephemeral,
        requirements: _requirements(),
      );
      expect(node.officialCode, isNull);
      expect(node.scope, Scope.s4);
    });
  });

  group('取值域', () {
    test('Scope 线上取值是大写 S0–S4（ADR-0007）', () {
      expect(Scope.s0.wire, 'S0');
      expect(Scope.s4.wire, 'S4');
      expect(Scope.fromWire('S3'), Scope.s3);
      expect(() => Scope.fromWire('s3'), throwsA(isA<FormatException>()));
    });

    test('未知取值抛 FormatException，且报错列出允许值（ADR-0007）', () {
      expect(() => LevelSlot.fromWire('moon'), throwsA(isA<FormatException>()));
      expect(() => Axis.fromWire('topic'), throwsA(isA<FormatException>()));
      expect(
        () => LearnableType.fromWire('skill2'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => NodeStatus.fromWire('deleted'),
        throwsA(isA<FormatException>()),
      );
    });

    test('槽位是语义槽位而非深度序号 —— 三轴占用的槽位数不同（ADR-0007）', () {
      final Map<Axis, Set<LevelSlot>> byAxis = <Axis, Set<LevelSlot>>{};
      for (final (Axis axis, LevelSlot slot) in legalSkeletonSlots) {
        byAxis.putIfAbsent(axis, () => <LevelSlot>{}).add(slot);
      }
      expect(byAxis[Axis.discipline], hasLength(3));
      expect(byAxis[Axis.major], hasLength(4));
      expect(byAxis[Axis.occupation], hasLength(5));
      expect(byAxis[Axis.discipline]!.contains(LevelSlot.galaxy), isFalse);
    });
  });
}

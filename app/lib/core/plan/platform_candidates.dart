/// 平台内置候选 —— `SPEC-PLAN-006` 表里「平台内置」那一栏，**保底通用档**。
///
/// 为什么硬编码而不进 `assets`：`app` 的 `pubspec.yaml` 至今没有 `assets` 段，
/// 引入它等于同时要管 iOS bundle 与 exe 同级解析（那是 `B8` 的事）。内置档是
/// 「与内容无关的通用档」，改版频率极低，常量文件足够；真要挪进 `assets` 时
/// 只是把下面三张表搬走，读取入口不变。
///
/// **三段里只有方法有平台档**：
/// - 源：没有。源候选的定义是「覆盖当前体系的项」，平台档不可能覆盖任何具体
///   体系（`B4` `P-2` 定，见 `PLAN-006` 注记）
/// - 体系：没有。`⪯` 原序是保底档的候选，但拓扑序**不唯一**，「原序」指哪一个
///   拓扑序需要先裁定，属设计问题，不在本笔凭空造
/// - 方法：有五份分支 + 三套组合，见下
library;

import '../entities/content.dart';
import '../enums.dart';
import 'method_bundle.dart';

/// 平台内置的方法分支（`entity-fields` §一.7）。
///
/// 五份都满足 §一.7 的三条校验：算子在本册内（①）· 至少一个 `review` 步骤（②）·
/// 有 `hint` 或已显式接受「本方法无提示可给」（③）。
const List<MethodProfile> platformMethodProfiles = <MethodProfile>[
  MethodProfile(
    id: 'method-feynman',
    name: '费曼',
    origin: CandidateOrigin.platform,
    appliesTo: <String, Object?>{'type': 'declarative'},
    steps: <MethodStep>[
      MethodStep(operator: ExecutionOperator.read),
      MethodStep(operator: ExecutionOperator.recall),
      MethodStep(
        operator: ExecutionOperator.explain,
        criteria: '不看材料讲清该项',
      ),
    ],
  ),
  MethodProfile(
    id: 'method-spaced',
    name: '间隔重复',
    origin: CandidateOrigin.platform,
    appliesTo: <String, Object?>{
      'type': <String>['declarative', 'procedural', 'skill', 'tacit'],
    },
    steps: <MethodStep>[
      MethodStep(operator: ExecutionOperator.read),
      MethodStep(operator: ExecutionOperator.recall),
      MethodStep(
        operator: ExecutionOperator.practice,
        criteria: '到期仍能回忆并通过检验',
      ),
    ],
  ),
  MethodProfile(
    id: 'method-deliberate',
    name: '刻意练习',
    origin: CandidateOrigin.platform,
    appliesTo: <String, Object?>{'type': 'procedural'},
    steps: <MethodStep>[
      MethodStep(operator: ExecutionOperator.example),
      MethodStep(
        operator: ExecutionOperator.practice,
        criteria: '弱项达到设定阈值',
      ),
      MethodStep(operator: ExecutionOperator.practice),
    ],
  ),
  MethodProfile(
    id: 'method-shadowing',
    name: '跟读模仿',
    origin: CandidateOrigin.platform,
    appliesTo: <String, Object?>{'type': 'skill'},
    steps: <MethodStep>[
      MethodStep(operator: ExecutionOperator.example),
      MethodStep(operator: ExecutionOperator.practice, criteria: '与原音对齐'),
      MethodStep(operator: ExecutionOperator.practice),
    ],
  ),
  MethodProfile(
    id: 'method-project',
    name: '项目驱动',
    origin: CandidateOrigin.platform,
    // `procedural` 也在内：`动手优先` 把程序性知识指到本项目驱动 —— 两条路
    // （先学再做 / 边做边学）都真实存在，各有各的人。
    appliesTo: <String, Object?>{
      'type': <String>['procedural', 'tacit'],
    },
    steps: <MethodStep>[
      MethodStep(operator: ExecutionOperator.read),
      MethodStep(operator: ExecutionOperator.doStep, criteria: '产出可运行交付物'),
      MethodStep(operator: ExecutionOperator.explain),
    ],
  ),
];

/// 平台内置的方法组合（`B4` `P-2` 新增的一层，见 `method_bundle.dart`）。
///
/// 三套的形状对齐 `SPEC-PLAN-010` 的举例：「陈述题走费曼、程序题走刻意练习、
/// 语音题跟读」正是 `理解优先` 的 `byType`。
const List<MethodBundle> platformMethodBundles = <MethodBundle>[
  MethodBundle(
    id: 'method-bundle-understand',
    name: '理解优先',
    origin: CandidateOrigin.platform,
    byType: <ItemType, String>{
      ItemType.declarative: 'method-feynman',
      ItemType.procedural: 'method-deliberate',
      ItemType.skill: 'method-shadowing',
      ItemType.tacit: 'method-project',
    },
  ),
  MethodBundle(
    id: 'method-bundle-memory',
    name: '记忆优先',
    origin: CandidateOrigin.platform,
    byType: <ItemType, String>{
      ItemType.declarative: 'method-spaced',
      ItemType.procedural: 'method-spaced',
      ItemType.skill: 'method-spaced',
      ItemType.tacit: 'method-spaced',
    },
  ),
  MethodBundle(
    id: 'method-bundle-build',
    name: '动手优先',
    origin: CandidateOrigin.platform,
    byType: <ItemType, String>{
      ItemType.declarative: 'method-feynman',
      ItemType.procedural: 'method-project',
      ItemType.skill: 'method-shadowing',
      ItemType.tacit: 'method-project',
    },
  ),
];

/// 分支索引：`MethodProfile.id` → 分支。
Map<String, MethodProfile> platformMethodProfileIndex() => <String, MethodProfile>{
  for (final MethodProfile profile in platformMethodProfiles) profile.id: profile,
};

/// 平台内置候选 —— `SPEC-PLAN-006` 表里「平台内置」那一栏，**保底通用档**。
///
/// 为什么硬编码而不进 `assets`：`app` 的 `pubspec.yaml` 至今没有 `assets` 段，
/// 引入它等于同时要管 iOS bundle 与 exe 同级解析（那是 `B8` 的事）。内置档是
/// 「与内容无关的通用档」，改版频率极低，常量文件足够；真要挪进 `assets` 时
/// 只是把下面三张表搬走，读取入口不变。
///
/// **三段里只有方法有平台档**：
/// - 源：没有。源候选的定义是「覆盖当前体系的节点」，平台档不可能覆盖任何具体
///   体系（`B4` `P-2` 定，见 `PLAN-006` 注记）
/// - 体系：没有。`⪯` 原序是保底档的候选，但拓扑序**不唯一**，「原序」指哪一个
///   拓扑序需要先裁定，属设计问题，不在本笔凭空造
/// - 方法：有五份分支 + 三套组合，见下
///
/// ## 为什么步骤里没有 `criteria`（`B13a` 笔 5c）
///
/// `entity-fields` §9.2 之后，验收判据归 `NodeEntry.criteria[]`（项末、与
/// `quiz` 1:1），**不在方法步骤上**。旧 `MethodStep.criteria` 的五条文案
/// （「不看材料讲清该项」等）是六轴时代的示例，新本体的方法只描述「怎么做」，
/// 不描述「怎么算做到」—— 判据随内容走，因为同一份配方服务多个包，
/// 而「算不算过关」是包的事。
///
/// [EntryStep] 的 `instruction` 是新必填字段（`entity-fields` §9.1）。平台档
/// 按算子给一句最小可用描述：它不替代内容侧的正文，只为「这条步骤要做什么」
/// 留一个不至于空着的落点。
library;

import '../entities/entry.dart';
import '../entities/method.dart';
import '../enums.dart';

/// 平台内置的方法分支（`entity-fields` §12）。
///
/// 五份都满足 §9 的三条校验：算子在本册内（①）· 至少一个 `review` 步骤（②）·
/// 有 `hint` 或已显式接受「本方法无提示可给」（③）。
const List<MethodProfile> platformMethodProfiles = <MethodProfile>[
  MethodProfile(
    id: 'method-feynman',
    name: '费曼',
    origin: CandidateOrigin.platform,
    appliesTo: <String, Object?>{'type': 'declarative'},
    steps: <EntryStep>[
      EntryStep(
        operator: ExecutionOperator.read,
        instruction: '通读该项，标出讲不清的地方',
      ),
      EntryStep(
        operator: ExecutionOperator.recall,
        instruction: '合上材料，凭记忆复述一遍',
      ),
      EntryStep(
        operator: ExecutionOperator.explain,
        instruction: '不看材料，用自己的话讲到别人能听懂',
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
    steps: <EntryStep>[
      EntryStep(
        operator: ExecutionOperator.read,
        instruction: '首次通读，建立初步印象',
      ),
      EntryStep(
        operator: ExecutionOperator.recall,
        instruction: '到点凭记忆回忆一次，不翻材料',
      ),
      EntryStep(
        operator: ExecutionOperator.practice,
        instruction: '按排程间隔重复，直到到期仍能回忆',
      ),
    ],
  ),
  MethodProfile(
    id: 'method-deliberate',
    name: '刻意练习',
    origin: CandidateOrigin.platform,
    appliesTo: <String, Object?>{'type': 'procedural'},
    steps: <EntryStep>[
      EntryStep(
        operator: ExecutionOperator.example,
        instruction: '先看一个范例，注意每一步的依据',
      ),
      EntryStep(
        operator: ExecutionOperator.practice,
        instruction: '只练最弱的那一步，反复到稳定',
      ),
      EntryStep(
        operator: ExecutionOperator.practice,
        instruction: '把弱项接回整体动作，完整走一遍',
      ),
    ],
  ),
  MethodProfile(
    id: 'method-shadowing',
    name: '跟读模仿',
    origin: CandidateOrigin.platform,
    appliesTo: <String, Object?>{'type': 'skill'},
    steps: <EntryStep>[
      EntryStep(
        operator: ExecutionOperator.example,
        instruction: '先听一遍原音，留意节奏与重音',
      ),
      EntryStep(
        operator: ExecutionOperator.practice,
        instruction: '跟着原音同步开口，尽量对齐',
      ),
      EntryStep(
        operator: ExecutionOperator.practice,
        instruction: '脱离原音自己说一遍，再比对差异',
      ),
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
    steps: <EntryStep>[
      EntryStep(
        operator: ExecutionOperator.read,
        instruction: '先弄清这项在小项目里承担什么',
      ),
      EntryStep(
        operator: ExecutionOperator.doStep,
        instruction: '动手做出可运行的产出，不求完整',
      ),
      EntryStep(
        operator: ExecutionOperator.explain,
        instruction: '讲清产出里每一处为什么这样做',
      ),
    ],
  ),
];

/// 平台内置的方法组合（`B4` `P-2` 新增的一层，见 `entities/method.dart`）。
///
/// 三套的形状对齐 `SPEC-PLAN-010` 的举例：「陈述题走费曼、程序题走刻意练习、
/// 语音题跟读」正是 `理解优先` 的 `byType`。
const List<MethodBundle> platformMethodBundles = <MethodBundle>[
  MethodBundle(
    id: 'method-bundle-understand',
    name: '理解优先',
    origin: CandidateOrigin.platform,
    byType: <LearnableType, String>{
      LearnableType.declarative: 'method-feynman',
      LearnableType.procedural: 'method-deliberate',
      LearnableType.skill: 'method-shadowing',
      LearnableType.tacit: 'method-project',
    },
  ),
  MethodBundle(
    id: 'method-bundle-memory',
    name: '记忆优先',
    origin: CandidateOrigin.platform,
    byType: <LearnableType, String>{
      LearnableType.declarative: 'method-spaced',
      LearnableType.procedural: 'method-spaced',
      LearnableType.skill: 'method-spaced',
      LearnableType.tacit: 'method-spaced',
    },
  ),
  MethodBundle(
    id: 'method-bundle-build',
    name: '动手优先',
    origin: CandidateOrigin.platform,
    byType: <LearnableType, String>{
      LearnableType.declarative: 'method-feynman',
      LearnableType.procedural: 'method-project',
      LearnableType.skill: 'method-shadowing',
      LearnableType.tacit: 'method-project',
    },
  ),
];

/// 分支索引：`MethodProfile.id` → 分支。
Map<String, MethodProfile> platformMethodProfileIndex() => <String, MethodProfile>{
  for (final MethodProfile profile in platformMethodProfiles) profile.id: profile,
};

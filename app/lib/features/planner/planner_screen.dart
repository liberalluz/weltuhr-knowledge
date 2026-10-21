/// Planner 的全屏承载（`SPEC-PLAN-017` 修订）。
///
/// ## 为什么是一整页路由，而不是抽屉 / 弹层
///
/// `SPEC-PLAN-017` 只说了「不是第六个视图、不常驻、不占 HUD 位置、不出现在
/// ⑤⑥ 附近」，没说渲染在哪。三个入口（`SPEC-PLAN-016`）都要「打开它」，
/// 于是这一层必须定下来：
///
/// - **右栏抽屉**会让三段竖排 + 实时预览挤进 `_drawerWidth`，且抽屉的位置正是
///   ⑤⑥ 旁边 —— 与 `PLAN-017` 那句「不出现在 ⑤⑥ 附近」直接冲突。
/// - **居中模态**在桌面上可用，但 `PLAN-014` 要求 iOS 改三步分页，模态尺寸放
///   不下。
/// - **全屏路由**两头都对：进去等于「暂时离开宇宙」，返回即恢复原视图与原档位
///   —— 正是「对某个空间跑一次规划，做完就回来」的形状。
///
/// ## 入口只交 `PlanDraft`，不写事件
///
/// 与 [PlannerPanel.onCreate] 同一条理由：面板与这一层都不知道 `EventStore` /
/// `HlcClock` / `userId`。它们只回答「用户选了什么」，写事件归更上面。
///
/// ## 重入复用（`SPEC-PLAN-019`）
///
/// 传 [revising] 就是「重规划」：三段按 [Plan] 里存的值预填，交出的仍是草稿，
/// 而**调用方据 `revising.id` 决定落 `plan_revised`**。
///
/// 为什么不只收一个 `planId`：预填要的是**值**（上次选了哪条源、哪套序、哪套
/// 方法），只有 id 取不到。而值从哪来必须唯一 —— 传整份 [Plan]，`planId` 就是
/// 它的 `id`，不会出现「id 传 A、预填值来自 B」的分裂。
///
/// `Plan.version` **不在这里 +1**：`SPEC-PLAN-019` 原文写「`Plan.version + 1`」，
/// 而 `P-6` 已把版本改成由 `fold` 数该 `planId` 名下的事件条数得出 —— 多写一处
/// 就是第二份计数。面板这一层连版本号都不碰。
library;

import 'package:flutter/material.dart' hide Axis;

import '../../core/entities/plan.dart';
import '../../core/enums.dart';
import '../../core/pack/pack_reader.dart';
import '../../core/plan/plan_events.dart';
import 'planner_panel.dart';

const Key plannerScreenKey = Key('planner-screen');
const Key plannerScreenBackKey = Key('planner-screen-back');

/// Planner 的一整页。
///
/// 用 `StatelessWidget` 而不是给面板套 `showDialog`：面板自己带 `State`，
/// 这一层只负责「进出的边界」—— 加状态会让「关掉再打开是否残留」变成一个新
/// 问题，而那本该由路由生命周期回答。
class PlannerScreen extends StatelessWidget {
  const PlannerScreen({
    required this.pack,
    required this.spaceId,
    required this.subtreeRoot,
    required this.primaryAxis,
    required this.packVersions,
    this.revising,
    this.initialSourceId,
    this.initialSchemeId,
    this.initialMethodId,
    super.key,
  });

  final PackContent pack;

  /// 事件信封上的空间 id。**不进 payload**，只用来填 `PlanDraft` 的信封。
  final String spaceId;

  /// 这份计划的范围根（`PLAN-016` 三个入口各带各的）。
  ///
  /// **必填**：`inScope` 已改成派生（`entity-fields` §2），没有根节点就没有
  /// 「圈内」。旧的 `PlanTarget.selector` 四形态（`space` / `domain` / `item` /
  /// `query`）随 `ADR-0005` 一并取消 —— 子树根已足够表达范围。
  final String subtreeRoot;

  /// 主序轴的默认值（由模式给出，可被体系覆盖）。
  final Axis primaryAxis;

  /// 建计划那一刻的包版本组合。
  final PackVersions packVersions;

  /// 要重规划的那一份（`SPEC-PLAN-019`）。给了就按它预填三段与范围。
  final Plan? revising;

  /// 重规划写 `plan_revised` 时指回的那份计划。**与预填同源**，见文件头。
  String? get planId => revising?.id;

  /// 重入时的预填（`SPEC-PLAN-019`）。显式给的优先于 [revising] 里的值。
  final String? initialSourceId;
  final String? initialSchemeId;
  final String? initialMethodId;

  /// 打开 Planner，等它交出一份草稿（用户取消则得 `null`）。
  ///
  /// 三个入口都走这一个方法 —— `PLAN-016` 的「指向同一面板」在代码上就是
  /// 「只有一处 `push`」。多写一处就会多出一套参数传递，两处迟早对不齐。
  static Future<PlanDraft?> open(
    BuildContext context, {
    required PackContent pack,
    required String spaceId,
    required String subtreeRoot,
    required Axis primaryAxis,
    required PackVersions packVersions,
    Plan? revising,
    String? initialSourceId,
    String? initialSchemeId,
    String? initialMethodId,
  }) {
    return Navigator.of(context).push<PlanDraft>(
      MaterialPageRoute<PlanDraft>(
        builder: (BuildContext context) => PlannerScreen(
          pack: pack,
          spaceId: spaceId,
          subtreeRoot: subtreeRoot,
          primaryAxis: primaryAxis,
          packVersions: packVersions,
          revising: revising,
          initialSourceId: initialSourceId,
          initialSchemeId: initialSchemeId,
          initialMethodId: initialMethodId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 重规划时范围回落到 `revising` —— 只回填三段而把范围丢掉，等于「重规划
    // 把范围悄悄放大成整个空间」，那正是 `PLAN-015` 反复强调不许的。
    final String effectiveRoot = revising?.subtreeRoot ?? subtreeRoot;
    final Object? primarySource = revising?.sourcePolicy['primary'];

    return Scaffold(
      key: plannerScreenKey,
      appBar: AppBar(
        // 标题写空间名：全屏之后「我在给哪个空间做计划」在页面上没有别的出处
        // 了（宇宙那边的诊断行已被盖住）。空名回落成「规划」而不是留一个空串。
        title: Text(pack.pack.name.isEmpty ? '规划' : '规划 · ${pack.pack.name}'),
        leading: IconButton(
          key: plannerScreenBackKey,
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PlannerPanel(
        pack: pack,
        spaceId: spaceId,
        subtreeRoot: effectiveRoot,
        primaryAxis: revising?.primaryAxis ?? primaryAxis,
        packVersions: revising?.packVersions ?? packVersions,
        initialSourceId:
            initialSourceId ?? (primarySource is String ? primarySource : null),
        initialSchemeId: initialSchemeId ?? revising?.schemeId,
        initialMethodId: initialMethodId ?? revising?.methodProfileId,
        // 建完即走：`PLAN-017` 的「做完就进 Runner」由上层接（Runner 属 `B5`，
        // 未开工）。这一层只把草稿交出去，不假装跳进一个还不存在的页面。
        onCreate: (PlanDraft draft) => Navigator.of(context).pop(draft),
      ),
    );
  }
}

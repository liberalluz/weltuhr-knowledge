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
library;

import 'package:flutter/material.dart';

import '../../core/entities/plan.dart';
import '../../core/pack/pack_parse.dart';
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
    this.target,
    this.initialSourceId,
    this.initialSchemeId,
    this.initialMethodId,
    super.key,
  });

  final LoadedPack pack;

  /// 这份计划的范围（`PLAN-016` 三个入口各带各的）。
  ///
  /// 缺省 = 圈内全量。Z1「开始学习」也会显式传一份 `{kind: 'space'}` 的
  /// —— 不传与传空 `selector` 在预览上等价，但落进事件的选择式不同：
  /// 后者回看时说不清「当初是不是故意全选」。
  final PlanTarget? target;

  /// 重入时的预填（`SPEC-PLAN-019`）。
  final String? initialSourceId;
  final String? initialSchemeId;
  final String? initialMethodId;

  /// 打开 Planner，等它交出一份草稿（用户取消则得 `null`）。
  ///
  /// 三个入口都走这一个方法 —— `PLAN-016` 的「指向同一面板」在代码上就是
  /// 「只有一处 `push`」。多写一处就会多出一套参数传递，两处迟早对不齐。
  static Future<PlanDraft?> open(
    BuildContext context, {
    required LoadedPack pack,
    PlanTarget? target,
    String? initialSourceId,
    String? initialSchemeId,
    String? initialMethodId,
  }) {
    return Navigator.of(context).push<PlanDraft>(
      MaterialPageRoute<PlanDraft>(
        builder: (BuildContext context) => PlannerScreen(
          pack: pack,
          target: target,
          initialSourceId: initialSourceId,
          initialSchemeId: initialSchemeId,
          initialMethodId: initialMethodId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: plannerScreenKey,
      appBar: AppBar(
        // 标题写空间名：全屏之后「我在给哪个空间做计划」在页面上没有别的出处
        // 了（宇宙那边的诊断行已被盖住）。空名回落成「规划」而不是留一个空串。
        title: Text(pack.space.name.isEmpty ? '规划' : '规划 · ${pack.space.name}'),
        leading: IconButton(
          key: plannerScreenBackKey,
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PlannerPanel(
        pack: pack,
        target: target,
        initialSourceId: initialSourceId,
        initialSchemeId: initialSchemeId,
        initialMethodId: initialMethodId,
        // 建完即走：`PLAN-017` 的「做完就进 Runner」由上层接（Runner 属 `B5`，
        // 未开工）。这一层只把草稿交出去，不假装跳进一个还不存在的页面。
        onCreate: (PlanDraft draft) => Navigator.of(context).pop(draft),
      ),
    );
  }
}

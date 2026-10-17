/// 全部数值常量。**唯一权威处** = `docs/reference/constants.md`。
///
/// 两条纪律（违反即为缺陷）：
/// 1. 代码中**禁止字面量散落** —— 由 `tool/lint` 的 R2 规则检查
///    （本文件是 R2 的唯一豁免点）。
/// 2. **`TBD` 项不得给默认值** —— 读到时抛 [TbdConstantError]。
library;

import 'enums.dart';
import 'errors.dart';

// ─────────────────────────── 一、记忆与调度（FSRS） ───────────────────────────

/// `C-01` 记忆强度的饱和归一常数（天）：`s = S / (S + sZeroDays)`。
const int sZeroDays = 30;

/// `C-02` 毕业阈值（天）：`S >= graduationSDays` 判「可用能力」。
const int graduationSDays = 180;

/// `C-03` FSRS 目标保留率。
const double fsrsTargetRetention = 0.90;

// `C-04` 评分映射（熟练 → 升档 · 合格 → 保持 · 未过 → 降档或重置并 fail+1）
// 属行为规则而非数值，落位 `SPEC-STEP-025`，实现在 W4（Runner）。

// ───────────────────────────── 二、会话与队列 ─────────────────────────────

/// `C-05` 默认会话预算（分钟）。**不切断进行中的项**，在项边界收尾。
const int sessionBudgetMinutes = 25;

/// `C-06` 每日复习池软上限。
const int reviewPoolCap = 20;

/// `C-07` 每日新学池软上限。
const int newPoolCap = 5;

// `C-08` 队列排序（逾期天数降序 → 复习池 → 新学池；两池独立计数）属行为规则，
// 落位 `SPEC-STEP-004`，实现在 W4。

// ──────────────────────────── 三、失败与跳过 ────────────────────────────

/// `C-09` **连续**未过达此次数 ⇒ 判「前置缺」、生成缺口、回 Runner 队列。
/// 「连续」定义在事件序列上：中间出现一次「合格」即清零。
const int failStreakToGap = 2;

/// `C-10` 同项**连续**跳过达此次数 ⇒ 会话结束时提示回 Planner 重定位。
const int skipStreakHint = 3;

/// `C-11` 跳过时写入的判定事件数 —— **恒为 0**：跳过不写事件、不计 fail。
const int skipEventsWritten = 0;

// ───────────────────────────── 四、内容迁移 ─────────────────────────────

/// `C-12` 项被拆分为 `n` 个子项时，`S` 与掌握状态的折算系数 = `1 / n`。
///
/// ⚠️ **只作用于记忆状态，不作用于文本** —— 笔记 / 摘录 / 题型在拆分时
/// **全额复制**到各子项（`SPEC-PACK-014`）。文本不能打半份。
double carryRatio(int n) {
  if (n < 1) {
    throw ArgumentError.value(n, 'n', '拆分数必须 >= 1');
  }
  return 1 / n;
}

// `C-13` 合并折算（取较大 `S`）属行为规则，落位 `SPEC-PACK-015`，实现在 W1。

// ────────────────────── 五、时长预估（Planner 实时预览） ──────────────────────

/// `C-14`…`C-19` 六类执行算子的分钟系数。
///
/// 预估时长 = Σ(该项某步骤的算子系数) × 项数。可离线算、可复现、可解释。
const Map<ExecutionOperator, int> operatorMinutes = <ExecutionOperator, int>{
  ExecutionOperator.read: 3, // C-14
  ExecutionOperator.example: 2, // C-15
  ExecutionOperator.recall: 1, // C-16
  ExecutionOperator.practice: 5, // C-17
  ExecutionOperator.teach: 5, // C-18
  ExecutionOperator.build: 30, // C-19
};

// ────────────────────────────── 六、界面阈值 ──────────────────────────────

/// `C-20` `maxPhi >= 5` 时 Z1 首屏默认展开到 `phi = 2`，否则只展开一层。
const int deepChainPhi = 5;

/// `C-21` 详情页内部历史 `trail` 上限。
const int trailCap = 5;

/// `C-22` 视图切换动画下界（毫秒）。宇宙 ↔ 树**只做交叉淡入，不做形态过渡**。
const int viewTransitionMinMs = 180;

/// `C-22` 视图切换动画上界（毫秒）。
const int viewTransitionMaxMs = 220;

/// `C-23` 亮度通道远档灰阶层数。
const int lodBrightnessFar = 3;

/// `C-23` 亮度通道近档灰阶层数。
const int lodBrightnessNear = 7;

// `C-24` 备注：该行不是常量，见 `docs/reference/channel-table.md` §一。

// ──────────────────────────── 七、可信度封顶 ────────────────────────────

/// `C-25` 打卡式（判据为空）项的掌握度上限系数：`mastery = checkinCap × d × s`。
///
/// 与 `N-05`（打卡项永不毕业）同源：无观测证据的项最多给「半可信」。
const double checkinCap = 0.5;

/// `C-26` 使用了脚手架（提示 / 答案）的成绩**最高判合格**，`熟练` 档关闭。
const Grade scaffoldCap = Grade.pass;

// ──────────────────────────── 八、内容与匹配 ────────────────────────────

/// `C-27` 快速定位的首期匹配字段集合。**不扩 schema**：别名与拼音延后。
const List<String> searchMatchFields = <String>[
  'item.title',
  'item.domainId',
  'space.name',
  'item.sixAxis',
  'scheme.nodes',
];

/// `C-28` 搜索模糊匹配阈值 —— **尚未裁定**，须实测标定。
///
/// 读到即抛 [TbdConstantError]：这是有意的设计，不是遗漏。
double get fuzzyMatchThreshold => throw TbdConstantError('C-28');

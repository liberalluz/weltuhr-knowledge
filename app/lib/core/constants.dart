/// 全部数值常量。**唯一权威处** = `docs/reference/constants.md`。
///
/// 两条纪律（违反即为缺陷）：
/// 1. 代码中**禁止字面量散落** —— 由 `tool/lint` 的 R2 规则检查
///    （本文件是 R2 的唯一豁免点）。
/// 2. **`TBD` 项不得给默认值** —— 读到时抛 [TbdConstantError]。
library;

import 'dart:math' as math;

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

// ─────────────────────── 十、投影与帧预算（`B2` 第 4 笔） ───────────────────────

/// `C-29` 一整圈弧度。扇区宽 = `FULL_TURN / 扇区数`。
///
/// 进常量表不是因为它是「设计参数」，而是 R2 禁止核心层散落字面量。
const double fullTurnRadians = math.pi * 2;

/// `C-30` 径向环中线偏移：`r = (段序号 + 0.5) / 段数`。
///
/// 没有这半步，同一段的所有项会落在环的内缘，「7 段径向分层」退化成一圈
/// 连续半径 —— 段与段之间看不出层次。
const double radialBandCenterOffset = 0.5;

/// `C-31` 单帧 CPU 投影预算（毫秒，p95）。口径 = 150 项 / Z0 全量。
///
/// **这是上限而不是目标**：`B2` 第 4 笔实测 p95 约 `0.02 ms`，比它低两个
/// 数量级（见 `SDP` §7 `R-06`）。留着的用途是给 `B3` 一个「超了就是回归」的闸。
const double frameCpuBudgetMs = 8;

/// `C-32` 帧率达标线。低于它触发 `ADR-0002` 回写（换实现路径，而非调参）。
const int frameTargetFps = 30;

/// `C-32` 帧率优线。
const int frameGoodFps = 50;

/// `C-28` 搜索模糊匹配阈值 —— **尚未裁定**，须实测标定。
///
/// 读到即抛 [TbdConstantError]：这是有意的设计，不是遗漏。
double get fuzzyMatchThreshold => throw TbdConstantError('C-28');

/// **六轴键序**（`entity-fields` §2）。`θ` 扇区序号与颜色通道的颜色序号都按
/// 这个顺序取，顺序本身是规格的一部分 —— 改序等于给所有项换扇区。
///
/// 进常量表是因为 `R2` 禁止核心层散落字面量：`primaryAxis` 的值是这六个键之一，
/// 而「值 → 扇区序号」的映射必须有唯一出处。
const List<String> sixAxisKeys = <String>[
  'subject',
  'role',
  'industry',
  'ability',
  'topic',
  'stack',
];

/// `C-34` 虚实通道判据：六要件里「不可外化」格 **≥ 3** 即判「虚」（默会类）。
///
/// 阈值由 α 包分布决定，不是调手感（`ADR-0003` §决策 2）：不可外化只有
/// 三档 —— 0 格 37 项 / 仅 `tacit` 110 项 / 3 格 3 项。取 1 会让 75% 变虚，
/// 取 2 与取 3 等价（2 格的项不存在）。
const int tacitMinGrids = 3;

/// 端口不在册的边，其**占位节点**相对源点的径向外移量（`ADR-0003` §决策 5）。
///
/// 不偏移会与源点完全重合 —— 点压在点上，看不出「这里缺一个东西」。这个值只
/// 保证「能看出是两个点」，最终表现（虚线圈 / 引出线）归 `B3` 笔 2 定。
const double placeholderRadialOffset = 0.02;

/// `C-37` 树 → 宇宙的定档阈值（`SPEC-VIEW-009`）：`φ = 0` → `Z1`、
/// `φ ≤ 本值` → `Z2`、再深 → `Z3`；无子树另行判 `Z4`。
///
/// 它不是「调到顺手」的数：`φ` 是 `⪯` 上的 Kahn 层号，前两层属于「刚起步」，
/// 三层以上已经要看局部子图了。
const int zoomPhiMaxForNebula = 2;

/// `C-33` 基准窗口：`1920×1080` 客户区。帧率判据只在这个尺寸下解释
/// （`ADR-0002` 修订二），绘制表面也按它封顶。
const double frameBenchWidth = 1920;

/// `C-33` 基准窗口的高。
const double frameBenchHeight = 1080;

/// 自适应取景：内容**半径**最多占视口短边的 46%（两侧合计 92%）。
///
/// 留 8% 是因为点本身有半径、边有端点圆头 —— 贴着边画会看起来像被切掉。
/// 用半径而不是直径表达，是为了让判据里不出现常量 `2`。
const double fitViewportRadiusRatio = 0.46;

/// 焦距变化小于这个量就不重算 —— 避免每帧在「重算」与「沿用」间来回。
const double fitFocalEpsilon = 0.001;

/// `C-40` 深链空间在树里**首屏展开到 `φ` 几层**（`SPEC-VIEW-008`）。
///
/// 不展开会让人误判「就这么点东西」；全展开则 63 层一次铺满，反而看不出骨架。
const int treeInitialExpandPhi = 2;

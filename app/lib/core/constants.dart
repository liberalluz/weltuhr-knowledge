/// 全部数值常量。**唯一权威处** = `docs/specs/constants.md`。
///
/// 两条纪律（违反即为缺陷）：
/// 1. 代码中**禁止字面量散落** —— 由 `tool/lint` 的 R2 规则检查
///    （本文件是 R2 的唯一豁免点）。
/// 2. **`TBD` 项不得给默认值** —— 读到时抛 `TbdConstantError`。当前表里
///    **没有** `TBD` 项（`C-28` 已裁定为 v0.1 不适用），机制留作后续未定值
///    的落位，不因暂时无人使用而删。
library;

import 'dart:math' as math;

import 'enums.dart';

// ─────────────────────────── 一、记忆与调度（FSRS） ───────────────────────────

/// `C-01` 记忆强度的饱和归一常数（天）：`s = S / (S + sZeroDays)`。
const int sZeroDays = 30;

/// `C-02` 毕业阈值（天）：`S >= graduationSDays` 判「可用能力」。
const int graduationSDays = 180;

/// `C-03` FSRS 目标保留率。
const double fsrsTargetRetention = 0.90;

// `C-04` 评分映射（熟练 → 升档 · 合格 → 保持 · 未过 → 降档或重置并 fail+1）
// 属行为规则而非数值，落位 `SPEC-STEP-025`，实现在 W4（Runner）。

// ─────────────── `C-98`…`C-118` FSRS-5 默认权重与曲线常数 ───────────────
//
// 编号在本文件里**不按顺序出现**：id 按裁定时间递增（`C-93`–`C-97` 是帧预算读数），
// 而它们按主题归入本节 —— 读者找 FSRS 参数是来这一节，不是去翻文件末尾。
// 值一律为上游默认，**实施者不得改动**：改它们等于换算法，历史 `S` 随之不可比。

/// `C-98` 初始稳定度 `S₀`（天），首次评分 = 未过。
const double fsrsW0 = 0.40255;

/// `C-99` 初始稳定度 `S₀`，首次评分 = `Hard`。
///
/// **当前无映射入口**（三档只有未过 / 合格 / 熟练），保留是为了让权重向量与上游对得上号。
const double fsrsW1 = 1.18385;

/// `C-100` 初始稳定度 `S₀`，首次评分 = 合格。
const double fsrsW2 = 3.173;

/// `C-101` 初始稳定度 `S₀`，首次评分 = 熟练。
const double fsrsW3 = 15.69105;

/// `C-102` 初始难度 `D₀` 的基准项：`D₀ = w4 − e^(w5·(g−1)) + 1`（`g` = 档位下标 1…4）。
const double fsrsW4 = 7.1949;

/// `C-103` `D₀` 的档位灵敏度。
const double fsrsW5 = 0.5345;

/// `C-104` 难度增量的缩放：`ΔD = −w6 × (g − 3)`。
const double fsrsW6 = 1.4604;

/// `C-105` 难度的均值回归系数。
const double fsrsW7 = 0.0046;

/// `C-106` 记得住时稳定度增幅的基准项 `e^w8`。
const double fsrsW8 = 1.54575;

/// `C-107` 增幅随 `S` 衰减的幂次：`S^(−w9)`。
const double fsrsW9 = 0.1192;

/// `C-108` 增幅里的可提取率偏离项：`e^(w10·(1−R)) − 1`。
const double fsrsW10 = 1.01925;

/// `C-109` 遗忘后稳定度的基准项。
const double fsrsW11 = 1.9395;

/// `C-110` 遗忘后稳定度里的 `D^(−w12)`。
const double fsrsW12 = 0.11;

/// `C-111` 遗忘后稳定度里的 `((S + 1)^w13 − 1)`。
const double fsrsW13 = 0.29605;

/// `C-112` 遗忘后稳定度里的 `e^(w14·(1−R))`。
const double fsrsW14 = 2.2698;

/// `C-113` `Hard` 档惩罚系数（当前映射用不到，保留以对齐上游权重向量）。
const double fsrsW15 = 0.2315;

/// `C-114` `Easy`（熟练）档奖励系数。
const double fsrsW16 = 2.9898;

/// `C-115` 同日复习的稳定度增幅基准：`S′ = S · e^(w17·(g − 3 + w18))`。
///
/// ⚠️ `FSRS-4.5` **没有这一项** —— 同日重复评分时 `S` 几乎不涨，
/// 「刚学完马上再练一遍」看不到任何变化。
const double fsrsW17 = 0.51655;

/// `C-116` 同日复习的偏移项，与 [fsrsW17] 是一对。
const double fsrsW18 = 0.6621;

/// `C-117` 遗忘曲线的衰减指数：`R(t) = (1 + factor × t / S)^decay`。
const double fsrsDecay = -0.5;

/// `C-118` 遗忘曲线的因子。**写成 `19 / 81` 而不是小数**：小数会在不同平台上
/// 四舍五入到不同位数，而它进 `R(t)` 的指数式，末位差异会被放大。
const double fsrsFactor = 19 / 81;

/// `C-119` 三档 → FSRS 档位下标（`C-04` 的映射表）。
///
/// 写成一张表而不是 `switch` 里的三个返回值：`R2` 只豁免 `0` / `1`，
/// 若把 `3` / `4` 直接写进 `fsrs.dart` 的 `switch`，那是一组「常量表里查不到」的数值。
/// 与 `operatorMinutes`（`C-14`–`C-19`）同一形态 —— 同族的值收进一处。
const Map<Grade, int> fsrsGradeIndex = <Grade, int>{
  Grade.fail: 1,
  Grade.pass: 3,
  Grade.proficient: 4,
};

/// `C-120` 难度 `D` 的下界。`D < 1` 没有意义：`1` 已经是「最容易」。
const double fsrsDifficultyMin = 1;

/// `C-121` 难度 `D` 的上界。`D₀` 的指数式与均值回归都可能把它推出域外。
const double fsrsDifficultyMax = 10;

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
  ExecutionOperator.explain: 5, // C-18
  ExecutionOperator.doStep: 30, // C-19
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

// `C-24` 备注：该行不是常量，见 `docs/specs/channel-table.md` §一。

// ──────────────────────────── 七、可信度封顶 ────────────────────────────

/// `C-25` 打卡式（判据为空）项的掌握度上限系数：`mastery = checkinCap × d × s`。
///
/// 与 `N-05`（打卡项永不毕业）同源：无观测证据的项最多给「半可信」。
const double checkinCap = 0.5;

/// `C-26` 使用了脚手架（提示 / 答案）的成绩**最高判合格**，`熟练` 档关闭。
const Grade scaffoldCap = Grade.pass;

// ──────────────────────────── 八、内容与匹配 ────────────────────────────

/// `C-27` 快速定位的首期匹配字段集合。**不扩 schema**：别名与拼音延后。
///
/// 笔 5c 按新本体改齐，**由五项降为四项**：旧表的 `item.title` → `node.name`、
/// `item.sixAxis` → `node.axis`、`space.name` → `pack.name`、`item.domainId` →
/// **删除**（域已不是项的字段，而是树上的结构节点；它的名字由 `node.name`
/// 一并覆盖，另立一项会变成同一个判据的两种写法）。
const List<String> searchMatchFields = <String>[
  'node.name',
  'node.axis',
  'pack.name',
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

// `C-28` 搜索模糊匹配阈值 —— **v0.1 不适用**（2026-10-18 裁定）。
//
// 模糊档的判据就是「子串包含」（`locate/locator.dart` 的 `_match`），不需要一个
// 「多像才算像」的阈值：那一档只参与 `exact > prefix > fuzzy` 的排序，**不是召回
// 门槛**。加阈值的方向只有一个 —— 漏召回：用户已经打出连续的一段字，却因为
// 「相似度不够」被告知没找到。
//
// 所以本文件**没有**它的常量，且这不等于漏写。编号保留不复用：将来若要真做
// 编辑距离，值回填在这里，判据只改 `_match` 的最后一步（`TC-QUANT-007` 锁的
// 正是「连续包含才命中」这条可判边界）。

/// `LearnableType` 的中文名（`entity-fields` §2）。
///
/// 与 [axisLabels] 同一条理由进常量表：取值是代码的标识、中文名是同一件事的
/// 另一种写法，两处各存一份的话，改一个类型的名字要记得翻两个文件。
/// 原本只在 `features/detail/detail_panel.dart` 里有一份私有副本，`B4` `P-8` 的
/// 候选卡「适用范围」是第二处要用的地方 —— 两份就会分叉，故上收到此处。
const Map<LearnableType, String> learnableTypeLabels = <LearnableType, String>{
  LearnableType.declarative: '陈述',
  LearnableType.procedural: '流程',
  LearnableType.skill: '技能',
  LearnableType.tacit: '默会',
};

/// `Layer` 的中文名（`entity-fields` §2）。进常量表的理由同 [learnableTypeLabels]。
const Map<Layer, String> layerLabels = <Layer, String>{
  Layer.persistent: '持久',
  Layer.view: '视图',
  Layer.ephemeral: '瞬时',
};

/// 三条容器轴的中文名（`entity-fields` §2 `Node.axis`）。理由同 [learnableTypeLabels]。
///
/// 笔 5c-1 新增：`appliesTo.axes` 取代 `spaceId` 之后，候选卡的「适用范围」
/// 那一行要写「学科」而不是 `discipline`。
const Map<Axis, String> axisLabels = <Axis, String>{
  Axis.discipline: '学科',
  Axis.major: '专业',
  Axis.occupation: '角色',
};

/// 源出处等级的中文名（`entity-fields` §11 五档）。理由同上。
///
/// 笔 5c 新增：`L0`–`L4` 编号已废（`L` 前缀在项目内撞过三处名），候选卡与详情页
/// 若直接渲染 `enum.name` 会露出 `official` / `community` 这类英文标识。
const Map<AuthorityLevel, String> authorityLabels = <AuthorityLevel, String>{
  AuthorityLevel.official: '官方',
  AuthorityLevel.standard: '标准',
  AuthorityLevel.textbook: '教材',
  AuthorityLevel.reference: '手册',
  AuthorityLevel.community: '社区',
};

/// 六类执行算子的中文名（`SPEC-STEP-012`）。理由同 [learnableTypeLabels]。
///
/// 详情页原写 `step.operator.wire`，界面上就是 `read` / `do` 这类英文标识 ——
/// 与 `authorityLabels` 那条注释是同一个坑：枚举名是代码的标识，不是给人读的。
const Map<ExecutionOperator, String> operatorLabels =
    <ExecutionOperator, String>{
      ExecutionOperator.read: '读',
      ExecutionOperator.example: '例',
      ExecutionOperator.recall: '忆',
      ExecutionOperator.practice: '练',
      ExecutionOperator.explain: '讲',
      ExecutionOperator.doStep: '做',
    };

/// 步骤相位的中文名（`entity-fields` §9.1）。
///
/// `both` 写「首次与复习」而不写「都」：另两档是「只在首次」与「只在复习」，
/// 一个「都」看不出在跟谁对比。
const Map<StepPhase, String> stepPhaseLabels = <StepPhase, String>{
  StepPhase.first: '首次',
  StepPhase.review: '复习',
  StepPhase.both: '首次与复习',
};

/// 题型的中文名（`entity-fields` §9.3）。理由同 [operatorLabels]。
const Map<QuizType, String> quizTypeLabels = <QuizType, String>{
  QuizType.choice: '选择',
  QuizType.fill: '填空',
  QuizType.code: '代码',
  QuizType.audio: '听辨',
  QuizType.freeform: '自由作答',
};

/// 判定方的中文名（`entity-fields` §9.3）。
///
/// `auto` 写「机器判」而不写「自动」：前者说清是**谁来判**，后者容易被读成
/// 「自动跳过」。
const Map<QuizJudge, String> quizJudgeLabels = <QuizJudge, String>{
  QuizJudge.auto: '机器判',
  QuizJudge.self: '自评',
};

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
///
/// ⚠️ 这两个数是**物理像素**。判定一律拿视口的 `physicalSize` 比，不拿
/// `MediaQuery.sizeOf` —— 后者是逻辑像素，100% 缩放下两者相等，缩放一变就不相等，
/// 而那时装置只会安静地等到超时，不会报错。
const double frameBenchWidth = 1920;

/// `C-33` 基准窗口的高（物理像素）。
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

/// `C-91` 树里**层与层之间**的缩进（`SPEC-TREE-008`）。
///
/// 缩进 = 相对**当前根**的路径段数 × 本值。一个数管所有层：写成每层一个字面量
/// 的话，改一层就得记得改另外几层，而漏改的那层只会「看起来有点歪」—— 没有
/// 任何东西会变红。
///
/// ⚠️ 判据是**路径段数**，不是槽位序号（`SPEC-TREE-008` 的禁令）：按槽位缩进
/// 会让学科轴与专业轴的 `star` 缩进相同，而它们在不同深度（2 段 / 3 段），并排
/// 时读不出「同一语义层」。
///
/// 旧注释引的是 `SPEC-VIEW-006` 修订的「0 / 14 / 28 / 42」—— 那条判据已随
/// `VIEW` 卷整体作废，`B17a` 笔 3 起改引 `TREE` 卷。
const double treeLevelIndent = 14;

/// `C-92` 树里**项内 `⪯` 缩进**的封顶级数（`SPEC-VIEW-006` 修订第 5 条）。
///
/// 超出不再缩进：α 包 `maxφ = 63`，按 14 px 一级算要 882 px，深层项会被整条
/// 推出屏幕右侧 —— 那时缩进表达的「多深」变成了「看不见」。
const int treePhiIndentCap = 6;

/// 树里四个层级的编号（`SPEC-VIEW-006` 修订的「深度 1/2/3/4」）。
///
/// 0 起算：`depth` 既算缩进（`depth × C-91`），也与面包屑段数对应
/// （`depth + 1`）。**不写成拼音式的 `treeDepth0`** —— 名字要说清是哪一层，
/// 否则读代码的人得回去查表。
///
/// ⚠️ 这四个值只在 `tree.dart` 构行时用到；`TreeRow.depth` 是**算好的结果**，
/// 渲染层不再自己推 —— 两处各推一次就会出现「第 3 层缩进、第 2 层图标」。
const int treeDepthRoot = 0;
const int treeDepthSpace = 1;
const int treeDepthDomain = 2;
const int treeDepthItem = 3;

/// `C-122` 树里**单级兄弟**一次最多出多少行（`SPEC-TREE-012`）。
///
/// 超出的部分折进末行「还有 M 项」(`M` = 总数 − 本值)，那一行不可点 —— 它是
/// 截断提示，不是节点。上限而不是分页：树是「位置即语义」的画布，翻页会把
/// 「我在哪一段」翻丢，一屏之外的东西本来就要靠定位过去。
///
/// 与概览页「另有 N 项排到明天」同一手法：**先给前若干项，再如实报剩下多少**。
const int treeSiblingRowCap = 50;

/// `C-123` 树里**首个真子行**的缩进级（`SPEC-TREE-008`）。
///
/// 缩进基准是 `知识` 那一行：`知识` = 0、轴根 = 1、轴根的孩子起 = 本值。
/// `B17c` 之前基准是「当前根」—— 那时 `知识` 不在树里，根自己占 0 级；
/// `知识` 成为两态都画的第一行之后，整条缩进链跟着下移一级。
///
/// 0 与 1 直接写在行集合里（`R2` 只禁 0 / 1 之外的字面量）：这两级各有唯一
/// 含义（虚拟根 / 轴根），再起两个名字只会让「谁是第 0 级」有两处答案。
const int treeIndentChildBase = 2;

/// `C-41` `φ` 轴向的居中偏移：`worldY = (φ01 − 本值) × phiHeight`。
///
/// 不居中的话整个场景永远落在赤道面**上方**（`φ01 ≥ 0`），屏幕上只可能出现在
/// 中线以上 —— 实测 1080×600 下 `y ∈ [0, 255]`、`x ∈ [-50, 0]`，左上一小撮。
const double phiCenterOffset = 0.5;

/// 自适应取景的偏航采样数：每隔 `2π/本值` 投一次，取最大包围盒。
///
/// 场景每帧自转，用单帧包围盒会每帧换焦距（画面呼吸）；用球半径又太保守
/// （薄楔形被当成实心球）。采样固定几个角度是两者的折中：与帧无关，也不浪费。
const int fitYawSamples = 8;

/// `C-43` 邻近候选的**匹配片段长度**（`SPEC-VIEW-030` 类 ②「措辞不同」）。
///
/// 与 `C-28` 不是一回事，不要合并：`C-28` 管「**命中**的模糊阈值」，是命中面内
/// 的一次判定；而邻近候选是在**已经确认没有命中**之后找相似的项，判据是
/// 「共享片段数 > 0」，排序按共享数，**不需要阈值**。
///
/// `C-28` 已于 2026-10-18 裁定为「v0.1 不适用」，两者更不会合并了 —— 但这条
/// 注释留着，是因为最容易犯的错不是「合并两条」，而是看到「搜索相似度」就
/// 回去给命中档补一个阈值。
///
/// 取 2 而不是 3：中文标题多在三到六字，三字片段在「装饰器参数」与
/// 「装饰器的参数」之间只有「参数」一处重合、在短标题上常常一处都没有。
const int locateNearGramSize = 2;

/// `C-44` 宇宙里点星的**最小可点半径**（`SPEC-VIEW-014` 入口 1）。
///
/// 命中判据本身是「点在球内」，球半径 = 绘制半径（含透视收缩）。但远处的星
/// 半径可以小到 1.6 px —— 严格按球判，用户看得见、点不中，而且会以为「这个
/// 视图不支持点击」。所以要有一个可点下限：比这更小的星，也按这个半径接住。
///
/// 取 8 px：桌面指针的定位误差在同一量级。**再往上就会让相邻的星互相抢点击**
/// —— α 包在默认取景下已有大量星挤在同一环带上，热点半径不能按「越大越好点」
/// 单向调。**不在这里另设取整**：判据只有「够不够得着」一件事，多一层取整
/// 等于多一个没人记得的口径。
const double pickMinHitRadius = 8;

// ─────────────────── 十一、五档下钻的形态（`B12` · `VIEW-036`） ───────────────────

/// `C-52` `Z0` 星系成团构型的**分布半径**占视口短边的比例。
///
/// 即「矮星系中心到构型中心多远」。真实没有等分，这一条给的是尺度而不是
/// 布局 —— 角度由 `space.id` 哈希定（`VIEW-036` 的确定性要求）。
const double z0OrbitRadiusRatio = 0.30;

/// `C-53` 星系盘半径**下限**（px）。低于它旋臂画不出（观测上退化为一个点）
/// ⇒ 该包数下 `Z0` 应判「退化为列表式」。
///
/// ⚠️ 它约束的是**全局系数 `k` 的下限**，不是 `r_i` 的下限：加在 `r_i` 上会让
/// 80 项与 150 项在高分屏下同时撞上限 ⇒ 比值变 1:1，语义静默丢失。
const double spacePlateMinRadiusPx = 40;

/// `C-59` `Z0` 星系盘的**初始**倾角（度）。用户手势可改，本值只是初值；
/// `Z1` 起倾角插值到 0（正对盘面），否则域点落点变扁、可点面积被吃掉。
const double galaxyDiscTiltDeg = 55;

/// `Z0` 星系的**最小可点直径**（px）。
///
/// 正常情况下 `C-53` 已经把盘半径顶到 40 以上，这一条只在 `k` 触底的退化情形
/// 兜底 —— 否则盘小到画得出、点不中，而用户只会以为「这个不支持点击」。
/// 与 ① 面包屑同一条 24 px 口径（`VIEW-018`）。
const double galaxyMinTapDiameter = 24;

/// `C-58` 旋臂对数螺线 `r(θ) = r₀·e^(bθ)` 的**螺距角**（度），`b = tan(螺距)`。
///
/// ⚠️ 因子是 `tan` 不是 `1/tan`：螺距角定义为「切线与**切向**的夹角」α，
/// 沿曲线 `dr/dθ = b·r` ⇒ `tan α = b`。原表写 `1/tan(15°) = 3.73`，在盘半径比
/// 12.5 下旋臂只转 39°（几根近乎笔直的径向短刺）；改回 `tan(15°) = 0.268`
/// 同一盘转约 1.5 圈。勘误记在 `docs/specs/constants.md`。
const double spiralPitchDeg = 15;

/// `C-61` 旋臂条数。真实旋涡星系多为两条（密度波 `m = 2` 模），也是 `VIEW-037` 的写法。
const int spiralArmCount = 2;

/// `C-60` 核球半径占盘半径的比例。
///
/// 旋臂从核球**边缘**起、不从圆心起 —— 从圆心起的臂会在正中叠成一个亮点，
/// 而那正是核球该在的位置。0.10 让核球看得出是个球，又不吃掉旋臂的弧长。
const double galaxyBulgeRadiusRatio = 0.10;

/// `Z1` 域点的**最小可点直径**（px）。域点本身只画 4 px，直接按图形判会
/// 「看得见点不中」；`VIEW-037` 明写命中 24 px。
const double domainMarkMinTapDiameter = 24;

/// `C-62` `Z2` 分子云的**粒子数**。**固定值，不跟项数走**（`VIEW-038`）。
///
/// 跟项数走的话，它与盘半径（`C-53`）、点密度一起构成第三条「项数」通道，
/// 而 `X-02` 只允许一通道一维度。取 240：1080p 下云的疏密看得出层次，
/// 又不会让「一颗粒子一次 draw call」把帧预算吃掉（`C-32` 的成本由填充驱动，
/// 240 个 1–3 px 的圆远低于一帧的填充上限）。
const int nebulaParticleCount = 240;

/// `C-63` `Z2` 分子云的**半径**占视口短边的比例。
///
/// 比 `Z1` 的盘（0.42，私有常量）略小：`Z2` 的云缘要放出口标记与亮结标注，
/// 按盘那么大铺会顶到 ① 与 ④ 底下。
const double nebulaRadiusRatio = 0.36;

/// `C-64` `Z1` 旋臂的**描边宽度**（px）。
///
/// 臂是一条**带**而不是一条线：真实旋臂是密度波，有宽度、边缘发虚。6 px 配合
/// `C-65` 的模糊，视觉宽度约 12 px。
///
/// ⚠️ 提号前它是 `spiral_painter.dart` 里的裸字面量 —— `R2` 只查 `core/`，所以
/// 谁也没被拦下。这类「看起来是常数、其实写死在绘制里」的值是 `R-08` 的典型：
/// 形状挡得住改、挡不住加。
const double spiralArmStrokeWidth = 6;

/// `C-65` `Z1` 旋臂的**模糊半径**（px）。臂缘发虚靠它，不靠渐变。
const double spiralArmBlurSigma = 3;

/// `C-66` `Z1` 旋臂的**不透明度**。
///
/// 0.30 是让它「像一层雾」而不是「一道划线」。⚠️ 这个值**没有经过终端观感
/// 校准** —— 截图里臂偏淡，但偏淡也可能来自 `C-65` 的模糊摊薄。改值前先看
/// `STR` 轮次 `R8` 的未验项，别把两件事混着调。
const double spiralArmAlpha = 0.30;

/// `C-67` `Z1` 域点的**绘制半径**（px）。命中半径另有 12 px —— 即
/// `domainMarkMinTapDiameter`（24）的一半。
const double spiralDomainMarkRadius = 4;

/// `C-68` `Z1` 项的**绘制半径**（px）。项是背景、不可点（`VIEW-037`）。
const double spiralItemDotRadius = 1.6;

/// `C-69` `Z1` 暗斑（`⪯` 子树）的**绘制半径**（px）。与 `C-67` 同量级 ——
/// 暗斑是容器、域点是容器，读者不该靠大小区分它们。
const double spiralBlobRadius = 3.2;

/// `C-86` `Z1` 核球径向渐变的**内端**不透明度。
///
/// 核球中心是整张盘最亮的一处 —— 域点光晕叠上来之前，它就该已经是亮的。
const double spiralBulgeCoreAlpha = 0.95;

/// `C-87` `Z1` 核球径向渐变的**外端**不透明度。
///
/// 原为 `0.10`，终端反馈「中心糊成一团」后收到 `0.02`：核球边缘必须**散开**，
/// 否则会被紧邻的域点光晕继续盖住，两层 alpha 在同一圈里累加。
/// ⚠️ 与 `C-88` 是一对 —— 只调一端只会把「糊」推成「硬边」或「一坨更大的糊」。
const double spiralBulgeEdgeAlpha = 0.02;

/// `C-88` `Z1` 域点光晕的不透明度。
///
/// 原为 `0.55`。光晕是「可点」的唯一视觉信号（`VIEW-037`），不能取消，但
/// 最内层两个域点离核球很近，两团光晕会直接压在核球上 —— 减淡是把「叠成
/// 一片」拆回「一颗亮结带一圈光」的手段，不是削弱可点性。
const double spiralDomainHaloAlpha = 0.35;

/// `C-89` `Z1` 域点光晕的半径倍数（倍 `C-67`）。
///
/// 光晕要明显大于本点、又要小于两个域点之间的距离，2.2 倍是这两条之间的一档。
const double spiralDomainHaloScale = 2.2;

/// `C-90` `Z1` 域点光晕的模糊半径（px）。
///
/// 光晕是「散开的一圈」而不是「一个更大的圆」—— 没有模糊就只剩硬边同心圆。
const double spiralDomainHaloBlurSigma = 4;

/// `C-70` 标注避让的**外推步长比**（`V-1d2`）。
///
/// 第 `k` 次尝试沿方位多让 `k × 行高 × 1.55`。取 1.55 是因为它大于 1 但小于 2：
/// 相邻两格之间留得出缝，又不会一格就飞出半屏。
const double labelAvoidStepRatio = 1.55;

/// `C-71` 标注避让的**外推上限**（格）。
///
/// 超限就接受重叠 —— 见 `label_layout.dart` 第 3 条口径。3 格在 `Z1` 的
/// 122 px 盘上是 3 × 14 × 1.55 ≈ 65 px，再远标签就与自己的点失去联系了。
const int labelAvoidMaxSteps = 3;

/// `C-72` `Z3` 恒星的**半径**占视口短边一半的比例。
///
/// ⚠️ 这是本档最明显的一处尺度妥协：真实里水星轨道是太阳半径的 84 倍，按那
/// 个比例画，恒星在屏上是一个亚像素点。`C-73` / `C-72` ≈ 5.3 倍是**为了看得见**
/// 而放大的，不承载任何语义（`VIEW-039` 只要求「一颗恒星 + 共面轨道」）。
const double stellarRadiusRatio = 0.045;

/// `C-73` `Z3` 最内轨的**半长轴**占视口短边一半的比例。
///
/// 与 `C-72` 一起定下「恒星占多大、内轨离多远」。再往内缩，行星会贴到恒星光晕
/// 上；再往外放，`C-74` 那圈就顶到 ① 与 ④ 底下了。
const double stellarOrbitInnerRatio = 0.24;

/// `C-74` `Z3` 最外轨的**半长轴**占视口短边一半的比例。
///
/// ⚠️ 层数多时轨道必然挤：`english` / `german` 每域 10 项 9 边 ⇒ 9 条轨道铺在
/// `0.24…0.46` 这段上，1080×580 下相邻轨道间距约 8 px。**任何单调映射都躲不掉**
/// —— 层数超出了这个尺度的可视容量，不是这一版没调好。
const double stellarOrbitOuterRatio = 0.46;

/// `C-75` `Z3` 轨道的**偏心率**上限。
///
/// `VIEW-039` 要求轨道是「共面**椭圆**」。真实行星 `e` 多数 < 0.1（水星 0.21
/// 是例外），所以每条轨道取 `e ∈ [0, 0.18]` 由 `item.id` 哈希定 —— 长轴朝向
/// 同样由哈希定。**不承载语义**，只是让九条轨道不是九个同心圆。
const double stellarOrbitEccentricityMax = 0.18;

/// `C-76` `Z3` 行星的**绘制半径**（px）。命中半径另有 12 px ——
/// `domainMarkMinTapDiameter`（24）的一半，与 `Z1` 域点、`Z2` 亮结同一套。
const double stellarPlanetRadius = 2.6;

/// `C-77` `Z3` 残余云气的**粒子数**。
///
/// 固定值、不跟项数走（与 `C-62` 同一条理由 `X-02`）：跟项数走就多出一条
/// 「项数」通道。28 颗是「恒星风还没吹散的淡雾」的量级，多了会盖住行星。
const int stellarWispCount = 28;

/// `C-78` `Z4` 恒星的**半径**占视口短边一半的比例。
///
/// `0.46` ⇒ 直径占短边的 92% —— 这一档叫「特写」，恒星要占满画面。留 4% 边
/// 不是气口，是**不让光晕被视口切平**：光晕画到 `1.35 × 半径`，正好压在边上。
///
/// ⚠️ 与 `C-72`（`0.045`）差十倍，是**刻意的**：`Z3` 要在一个画面里同时放下
/// 九条轨道，`Z4` 只要放下恒星与两条内轨。两档用同一个恒星比例的话，必有一档
/// 是错的。
const double closeupStarRadiusRatio = 0.46;

/// `C-79` `Z4` 最内轨的**半长轴**（倍恒星半径）。
///
/// ⚠️ **不是 `C-73 / C-72 ≈ 5.3`**。真实里最近的行星轨道是恒星半径的几十倍，
/// 把恒星填满画面时它在画面外几十个恒星直径处（`VIEW-040` 明写的「本档最大
/// 妥协」）。所以这一档的轨道比例是**为了让它出现在画面里**而定的，不承载
/// 语义 —— 规格的边界也正是「只露能放进画面边缘的 1–2 条」。
///
/// `1.26` 落在光晕（`1.35` 倍）之内侧：轨道线穿过光晕比悬在纯黑里更像「绕着
/// 它转」。再往外一点就贴到画面边缘了。
const double closeupOrbitInnerRatio = 1.26;

/// `C-80` `Z4` 次内轨的**半长轴**（倍恒星半径）。
///
/// 只在「确实有第二层」时才用。`1.82 × 0.46 = 0.837` —— 半长轴还在视口短边
/// 的一半（`1.0`）之内，倾斜之后也不会整圈跑出去。
const double closeupOrbitOuterRatio = 1.82;

/// `C-81` `Z4` 最多露几条轨道。
///
/// `VIEW-040` 的边界：「只露能放进画面边缘的 1–2 条，**不做成太阳系示意图**」。
/// 上限写成常量而不是「有几层画几层」—— 后者在 `english` 那类九层链上会把
/// `Z3` 重画一遍，只是恒星更大。
const int closeupMaxOrbits = 2;

/// `C-82` `Z4` 恒星表面**米粒组织**（亮斑）的颗数。
///
/// 真实太阳表面有百万颗，只画得出一个印象量级。固定值、不跟项数走
/// （`X-02`：任何「按项数取值」的常量都会悄悄长成第二条通道）。
const int closeupGranuleCount = 46;

/// `C-83` `Z4` 米粒的**半径**（倍恒星半径）。
///
/// 实际半径在这个数的 `0.55…1.0` 之间由哈希取 —— 一样大的一圈圆点像网点纸，
/// 不像米粒。46 颗 × 平均 `0.045` 的圆覆盖恒星盘约 30%（可见 `STR` 的读数）。
const double closeupGranuleRadiusRatio = 0.075;

/// `C-84` `Z4` **黑子**的个数。
///
/// 真实黑子成对出现（双极群），多数时候一两群。3 个是不做天文考据的上限，
/// 再多恒星盘就花了 —— 这一档的主角是「它是一颗恒星」，不是「它在活动期」。
const int closeupSpotCount = 3;

/// `C-85` `Z4` 黑子的**半径**（倍恒星半径）。
///
/// 黑子比米粒大两个量级才有得看（真实里黑子约米粒的 30 倍）。`0.10` 在
/// 0.46 的恒星半径上约 10 px —— 一眼认得出是暗斑，又不至于像被咬了个洞。
const double closeupSpotRadiusRatio = 0.10;

// ─────────────────── 十二、运动（`B12` · `VIEW-037`–`039`） ───────────────────

/// `C-54` 盘自转一周的时长（秒）。
///
/// `Z0` 盘 / `Z1` 盘 / `Z2` 背景**共用这一个角速度** —— 同一块盘在不同视角下
/// 角速度必须相同，否则「进门后世界突然变快 / 变慢」。⚠️ `Z0` 的盘没有内部
/// 图案（只有一枚椭圆），自转在投影里不可观测，那一档只接 `C-55` 构型公转，
/// 但仍用同一个时钟，进 `Z1` 时相位连续（`VIEW-036` 注）。
const int spinPeriodSeconds = 24;

/// `C-55` `Z0` 星系**构型公转**一周的时长（秒）= `3 × C-54`。
///
/// 整数倍不是为好看：`30 : 24` 落在近频拍频最糟的区间（拍周期 120 s），净速度
/// 时快时慢 —— 观感上就是「卡顿」。整数比才有「整体严格 72 s 周期」，才断言得
/// 出「`t = 0` 与 `t = 72` 整帧相同」。
///
/// ⚠️ 公转本身是**风格化让步**：真实本星系群角动量 ≈ 0，没有规则公转。
const int z0OrbitPeriodSeconds = 72;

/// `C-56` `Z3` **最内层**行星公转一周的时长（秒）。
///
/// 其余层按开普勒 `T_i = C-56 · (a_i / a_inner)^1.5` —— 见
/// `starOrbitPeriodSeconds()`。⚠️ 不能给所有层同一个周期：「越外越慢」是真实
/// 特征，同周期时一眼就看得出是假的。
///
/// ⚠️ 周期只由**层号**定，不按当前档的轨道半径反解：`Z4` 的 `C-79` / `C-80`
/// 与 `Z3` 的 `C-73` / `C-74` 不是同一个比例，各按自己的 `a` 算周期会让
/// 「推近之后行星突然加速」—— 而两档看的是同一颗行星。
const int innerOrbitPeriodSeconds = 8;

/// `C-57` 减速停转的第一个阈值（px）：离**最近可点对象**小于它 ⇒ 完全停转。
///
/// 与 `domainMarkMinTapDiameter` 同量级不是巧合：命中圈的直径就是 24 px，
/// 停在 24 px 之外意味着「停下来的时候指针刚好够得着」。
const double governorStopRadiusPx = 24;

/// `C-57` 减速停转的第二个阈值（px）：超过它恢复常速，中间线性减速。
///
/// 60 px 是「还看得出在朝它去」的距离；再近才减速会来不及 —— 一个以
/// `C-54` 转的盘，边缘线速度约 32 px/s，从 60 px 到 24 px 有约一秒的缓冲。
const double governorSlowRadiusPx = 60;

/// `C-93` `v0.1.0` 无账号体系时的**本地默认 `userId`**（`SPEC-ACC-013`）。
///
/// 取一个恒定值而非空串，是为了让 `fold` 的过滤维度只有两个分支：写 `null`
/// 会让「这条属于谁」出现第三态，之后每处读取都得特判。
/// `B10` 登录后由真实账号取代，**既有事件不批量改写** —— 认领靠新增
/// `identity_adopted` 事件（`SPEC-ACC-014`）。
const String localDefaultUserId = 'local';

// ──────────────────────── 十三、节点槽位合法性（`B13a`） ────────────────────────

/// 骨架**结构节点**的 `(axis, level_slot)` 合法对 —— **12 对**，不是 8×3 = 24。
///
/// `ADR-0007` 决策 4：三轴占用的槽位不同，所以合法组合不是全笛卡尔积。
/// 学科轴只到 `star`（研究生目录只到一级学科，二级由学位授予单位自设，
/// 不存在全国统一目录）⇒ 它跳过 `galaxy` 与 `cluster`；角色轴多出 `cluster`（小类）。
///
/// ⚠️ **`system`（行星系）不在本表内，且不是漏写**：它是载荷容器，轴继承自父恒星，
/// 三种轴都合法，所以「不限轴」比「列进表里」更准确 —— 两者的区别在恒星之下
/// 新增一级载荷时该怎么办：列进表里要回来改表，不限轴则一个新槽位都不动。
/// `StructuralNode` 的校验因此是「`system` 放行 ∨ 命中本表」。
///
/// 这张表也是**唯一的放行清单**：不在表里的组合，构造即抛 [IllegalNodeSlotError]。
const Set<(Axis, LevelSlot)> legalSkeletonSlots = <(Axis, LevelSlot)>{
  // 学科轴：超星系团 → 星系群 → 恒星（跳过星系与星团）
  (Axis.discipline, LevelSlot.supercluster),
  (Axis.discipline, LevelSlot.group),
  (Axis.discipline, LevelSlot.star),
  // 专业轴：超星系团 → 星系群 → 星系 → 恒星
  (Axis.major, LevelSlot.supercluster),
  (Axis.major, LevelSlot.group),
  (Axis.major, LevelSlot.galaxy),
  (Axis.major, LevelSlot.star),
  // 角色轴：超星系团 → 星系群 → 星系 → 星团 → 恒星
  (Axis.occupation, LevelSlot.supercluster),
  (Axis.occupation, LevelSlot.group),
  (Axis.occupation, LevelSlot.galaxy),
  (Axis.occupation, LevelSlot.cluster),
  (Axis.occupation, LevelSlot.star),
};

// ─────────────────── 十四、id / path 三元（`B13a` 笔 2 · `path-rules`） ───────────────────

/// 骨架节点 id 的前缀（`entity-fields` §2）：`skeleton:{local_id}`。
///
/// 它与 `{plugin_id}:{local_id}` 是**两条命名空间**：骨架全量内置、不走插件，
/// 所以它没有 `plugin_id`。「这个 id 属于骨架还是载荷」在三元校验里是一等判据
/// （`P-15` 跨包边界、`attach_to` 的唯一例外），故前缀进常量表而不是散在比较里。
const String skeletonNodePrefix = 'skeleton:';

/// `{plugin_id}:{local_id}` 与骨架前缀共用的命名空间分隔符。
const String idNamespaceSeparator = ':';

/// `path` 段的分隔符（`path-rules` `P-02`）。**无前后导斜杠**。
const String pathSeparator = '/';

/// `slug` 的合法字符集（`path-rules` `P-04`）。
///
/// **`_` 不在其中**：下划线开头的段是**保留段**，只允许系统生成、
/// 作者不可自取。保留与普通因此在字符层面就能区分，不必再维护一份保留字清单。
final RegExp slugPattern = RegExp(r'^[a-z0-9-]+$');

/// 保留段前缀（`path-rules` `P-04`）。
const String reservedSegmentPrefix = '_';

// ─────────────────── 十五、存储三区（`B13a` 笔 3 · `entity-fields` §〇） ───────────────────

/// 原子写用的临时文件后缀：`pack.json` → `pack.json.tmp0`。
///
/// **必须与目标同目录**（同目录才保证同一文件系统、rename 才原子），
/// 所以它只能是后缀而不是「系统临时目录里的随机名」。
const String atomicTempSuffix = '.tmp';

/// `PathClaim` 台账的文件名（`entity-fields` §6 · `path-rules` `P-14`）。
///
/// 落在**可写内容区**根下，不在包目录里 —— 台账记的是本机的占用与墓碑，
/// 而包目录是只读的（写进去就是「一次原子写改掉了分发内容」）。
const String claimsFileName = 'claims.json';

/// 台账文件的格式版本（`claims.json` 顶层的 `schema`）。
///
/// 台账是**用户机器上的持久文件**，会比代码活得久。没有版本号，加字段时只能
/// 靠「猜这份文件是哪一版」，而猜错 `state` 的后果是墓碑读成现役（或反过来）——
/// 该拦的复用拦不住，且没有任何断言会红。
const int claimsSchemaVersion = 1;

/// 事件日志的行分隔（`core/storage/store_fs.dart` 的 `appendLine`）。
///
/// 固定 `\n` 而不是 `Platform.lineTerminator`：事件日志是要跨设备同步、要被
/// 服务端同构解析的**交换格式**，平台差异必须挡在写入侧 —— 否则同一份日志在
/// Windows 上多出 `\r`，按行哈希或按字节比对的地方全部错位。
const String eventLogLineBreak = '\n';

// ─────────────────── 十六、容器树（`B17a` 笔 2 · `TREE` 卷） ───────────────────

/// 面包屑第 1 段的展示名。**不是节点**：没有 `id`、不可点（`SPEC-TREE-002`）。
///
/// 进常量表而不是散在界面里：树与宇宙共用同一份面包屑（`SPEC-TREE-007`），
/// 两处各写一个字面量，改一处忘一处时没有任何断言会红。
const String treeVirtualRootLabel = '知识';

// ─────────────────── 十七、帧预算读数（`B17a` 笔 6 · `C-32` / `C-33`） ───────────────────

/// 出快照所需的最少**帧间隔**数（`C-32`）。
///
/// 少于它一律不出读数：两帧相减也能得到一个「fps」，但那是一个样本的噪声，
/// 不是稳态。读数要么带得住，要么不给 —— 半份读数比没有读数更容易被当成结论引用。
const int frameStatsMinIntervals = 20;

/// 滚动窗口保留的最多帧数（`C-32`）。
///
/// 实测跑固定时长，理论上不封顶也不会涨到哪去；封顶是为了同一份实现将来能被
/// 常驻读数面板直接复用 —— 那时它是**不许无限增长**的。
const int frameStatsWindowCapacity = 600;

/// 中位数的分位（`C-32`）。取 0.5，与 `frameP95Fraction` 走同一段最近秩代码。
///
/// 「中位」而不是「平均」：平均会被少数长帧拉住，而长帧恰恰是要单独看的另一项
/// （p95 帧间隔）。两个指标取平均就退化成同一个数，`STR` 轮次 `R1` 的三项读数
/// 会少掉一项。
const double frameMedianFraction = 0.5;

/// 卡顿线的分位（`C-32`）。
const double frameP95Fraction = 0.95;

/// 判定「这是不是 `C-33` 基准窗口」的容差（**物理像素**）。
///
/// 客户区尺寸是运行期从视口算出来的浮点值，`1920.0` 经一次缩放换算未必逐位相等。
/// 不给容差就只有两种命运：永远判不等，或者用 `round()` 把「1920.4 也当 1920」——
/// 后者会把一个比基准宽 1 px 的窗口也认成基准。1 px 内算同一个窗口，超出就明说不是。
const double frameBenchWindowTolerance = 1;

// ─────────────────── 十八、宇宙视图落位（`B17b` 笔 1 · `ADR-0006`） ───────────────────

/// 最内层球壳的半径（世界单位）。
///
/// 星空在 100，五层最外层约 55，仍在天球之内 —— 节点是「近处的东西」，
/// 星空是「无穷远的背景」，这个层次不能反。轴根落在最内层：越往下钻，
/// 节点越靠外，视线是「向外展开」而不是「往中心挤」。
const double universeShellInnermostRadius = 8.0;

/// 相邻两层球壳的半径倍数（对数等比的「等比」）。
const double universeShellRadiusRatio = 1.62;

/// 球壳层数 = 三轴槽位的最大值（角色轴五个槽位）。
///
/// 不是「三条轴都五层」：学科轴只有三个槽位，用不满的层就空着。
/// 这个值同时是**祖上走廊的等分分母**（见 `ancestorElevationOf`）。
const int universeShellCount = 5;

/// 子级在球面上铺开的列数。
///
/// 列 × 行必须 ≥ 骨架里最大的同父子数（实测 105）。取 12 列是为了让方位角
/// 的最小间隔是 30° —— 比星点光斑的角直径大一个量级，缩到 fov 50° 时
/// 相邻两颗仍分得开。
const int universeSkyGridColumns = 12;

/// 子级在球面上铺开的行数。取 10 行而非 12：顶部两行的位置留给来路走廊，
/// 与列数取同一个值会让走廊无处可放，祖先只能和子级抢格子，
/// 而球心视角下半径不改变屏幕位置、只改变遮挡 —— 抢同一格就是叠成一个点。
const int universeSkyGridRows = 10;

/// 子级仰角的跨度（度）。以水平面为中心上下各一半，即 −60°..+60°。
///
/// 不铺满 −90°..+90°：极点附近方位角失去意义，铺到极点等于把若干颗
/// 压成同一点。
const double universeChildElevationSpanDeg = 120.0;

/// 来路走廊占球面顶部的角度跨度（度）。从子级仰角上沿（+60°）往上算到 90°。
const double universeAncestorCorridorDeg = 30.0;

/// 一整圈的度数。
///
/// 方位角按「列位置 × 整圈 − 半圈」算，但代码里不写 360 与 180 两个字面量：
/// 两条都能由本值与 `universeCellCenterOffset` 组合出来，多写一条就多一处
/// 改不干净的地方。
const double universeFullTurnDeg = 360.0;

/// 格心相对格边的偏移（半格）。
///
/// 三处用途是同一个含义 —— 「取格子的中点」：列方向定方位角、行方向定仰角、
/// 仰角半跨度取跨度的一半。共用一个名字是因为它们确实是同一件事，
/// 分开命名会让「半格」有四种写法。
const double universeCellCenterOffset = 0.5;

/// `SkyPoint.toString` 保留的小数位。
///
/// 只为读数可读，不参与任何判据。度数保留两位时，`1/255` 这种量级的差别
/// 看不出来 —— 那本来也不是要看的东西；能看出「格与格差 30°」就够。
const int skyPointDecimalPlaces = 2;

// ─────────────────── 十九、节点光点（`B17b` 笔 3 · `ADR-0006`） ───────────────────

/// 方位角与赤经之间的偏移（度）。
///
/// 落位给的是「方位角 0 = 正前」；投影层 `SkyProjection` 吃的是**星表坐标系**，
/// 它的赤经 0 在视线右手边 90°。两者差一个直角 —— 相机 `yaw` 为 0 时视线
/// 正对方位角 0，而它对应的赤经是 90°。
///
/// 单起一个名字而不是在转换处直接减 90：这个直角是两套坐标系的口径差，
/// 写进算式里就成了一个来历不明的修正量，换个地方又要再猜一次。
const double universeSkyAzimuthToRightAscensionDeg = 90.0;

/// 当前节点的光点半径（逻辑像素）。
///
/// 三档里最大：视线该先落在这里，它也是唯一恒在视野正中的点。
const double universeCurrentDotSize = 5.0;

/// 来路（祖先）的光点半径。比当前节点小一档 —— 它们是「从哪来」，不是主语。
const double universeAncestorDotSize = 3.2;

/// 直接子级的光点半径。
///
/// 最小一档：一屏最多同时有 105 个（骨架最大同父），再大就糊成一片光。
const double universeChildDotSize = 2.4;

/// 光晕半径相对光点半径的倍数。
///
/// 大于 1 才有「光晕」可言；取 2.8 是因为星点光斑的可见直径约是画布半径的
/// 六倍（`star_sprite.dart` 的贴图留白），而节点要落在同一片星空里、看着
/// 像同一套光，又不能大到盖住旁边的点。
const double universeDotGlowScale = 2.8;

/// 实心核半径相对光点半径的倍数。
///
/// 小于 1：核嵌在晕里。核负责「这个点在哪」，晕负责「它亮」。两者都取 1
/// 会变成一个边缘生硬的圆片，与旁边带柔边的星点明显不是一套。
const double universeDotCoreScale = 0.55;

/// 光晕的不透明度（0..1）。
const double universeDotGlowAlpha = 0.30;

/// 实心核的不透明度（0..1）。核要实，晕要淡 —— 反过来会糊。
const double universeDotCoreAlpha = 0.95;

// ─────────────────── 二十、节点亮度（`B17b` 笔 4 · `ADR-0006`） ───────────────────

/// 已学项的亮度底光（0..1）。
///
/// **不是一个可以随手调的观感值**：它是「已学」与「未学」唯一的分界线。
/// 已学但从未判过分的项没有 `SrsState`，掌握度按 `QUANT-004` 是 0；若亮度直接
/// 等于掌握度，这类项会与没碰过的项一样暗，而 `ADR-0006:97` 的判据是「已学项
/// 比未学项亮」。取 0.6 是让已学一眼可辨，同时给掌握度留 0.4 的连续余地 ——
/// 取 1 就没有余地（学与学精一样亮），取得太低又与未学难分。
const double universeLearnedBaseBrightness = 0.6;

/// 未学项的亮度下限系数（0..1）。
///
/// 亮度 0 不是「不透明度 0」：未学项仍要看得见，否则一片没学过的天会变成空的，
/// 与新用户分不清「还没学」和「没装载」。真正的不透明度 = 本值 + (1 − 本值) ×
/// 亮度档位。
const double universeBrightnessFloor = 0.25;

/// 亮度分几档。
///
/// 分档只为一件事：**复用 paint**。逐点建 `Paint` 会让一屏一百来个点建两百个
/// 对象、每帧重建；分 5 档后至多 3 种点径 × 5 档 × 2 个 paint = 30 个。
/// 5 档也是「一眼分得出明暗」的下限 —— 再细就与抗锯齿混在一起，看不出差别。
const int universeBrightnessSteps = 5;

/// 取不到学习数据时全体共用的亮度（0..1）。
///
/// 「不知道」不等于「没学过」：日志读不出来、没接存储、某个包算不出深度，
/// 这几种情形下把所有点画成未学的暗色，等于告诉用户「你什么都没学」。
/// 取中值，画面与笔 3 那版一致 —— 那一版本来就没有亮度语义。
const double universeBrightnessUnknown = 0.5;

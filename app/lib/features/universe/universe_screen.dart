/// 宇宙 / 树两种视图的宿主（`SPEC-VIEW-001` / `010` / `012` / `018`）。
///
/// ## 七区块在各模式下的显示规则
///
/// | # | 位置 | 宇宙 | 树 |
/// |---|---|---|---|
/// | ① | 顶部左 | 面包屑 + 模式图标（`Z0` 另有放大镜） | 同左 |
/// | ② | 顶部第二行 | 有筛选才出现 | 同左 |
/// | ③ | 右上 | 常显 | 常显 |
/// | ④ | 右侧 | **仅 `Z4`** | **常驻右栏**（`VIEW-012`） |
/// | ⑤ | 中心偏左 | 常显（焦点星） | **不渲染** —— 树里选中行就是焦点 |
/// | ⑥ | 左下 | 常显（六轴罗盘） | **不渲染**（`VIEW-011`：二维没有方位） |
/// | ⑦ | 底部中央 | **留白** | **留白** |
///
/// `V-1a`（`VIEW-018` 修订）把 ① 收成三段式、⑦ 整条作废、换根 chips 撤掉：
///
/// - **⑦ 视距刻度条作废**。下钻模型成立后，刻度会造出「直达某档但容器不明」
///   —— `Z0` 点 `Z2` 该开哪个域？没选过，没有答案。而面包屑每一段都是**实际
///   走过的**。空着比塞一个占位清楚：占位会被读成待填的坑。
/// - **① 的段数 = 走到第几层**（`VIEW-001`：面包屑段数 = 档位）。`知识` ›
///   空间 › 域 › 项，前段可点（退到该层），末段不可点（已在）。
/// - **模式切换从两个文字按钮收成 14 px 图标**，跟随面包屑末尾、命中区 44 px。
///   图标只有 14 px，直接按图形判会「看得见点不中」。
/// - **换根 chips 撤掉**（PR #59 回退）。`B3` 收尾时它是「星系不可点」的替代
///   入口；现在星系本身是入口（`VIEW-036`），且 chips 落 `Z0` 与「点星系
///   ⇒ `Z1`」直接冲突。**不留开关** —— 换根已有两个正式入口：点星系、点面包屑
///   第 1 段。
///
/// ## `Z0` 画的是空间之间（`V-1b` · `VIEW-036`）
///
/// `Z1` 起画的是某个空间**内部**（项 + 边 + 域带，走 `FramePainter`）；`Z0` 画
/// 的是**空间之间** —— 一个 `KnowledgeSpace` 一个星系，不出项、不出边。两者
/// 不同源，于是 `_universeBody` 在 `Z0` 换一套几何（`galaxy_map.dart`）与一套
/// 绘制（`galaxy_painter.dart`）。
///
/// ## `Z1` 画的是一张盘（`V-1c` · `VIEW-037`）
///
/// `Z1` 也换了一套几何（`spiral_map.dart` + `spiral_painter.dart`），理由是
/// 实测出来的：走项投影时 `Z1` 是「极坐标环带 + 24° 侧视」，而 α 包 150 项
/// **全部没有 `primaryAxis`**（继承 `ability`）⇒ 所有项落在同一个 60° 扇区里，
/// 十个域只是十条同心环 ⇒ 屏幕上是一条竖列，域与域分不开（`ADR-0003`
/// 2026-10-18 修订 §1 记的就是这件事）。
///
/// 换过之后三条行为变了，都是规格要求而不是顺手改：
///
/// - **可点对象只有域点**（亮 + 光晕），落 `Z2`。项是**背景**：照画、不参与
///   拾取、点它什么都不发生 —— 所以 `onTapUp` 里没有「点项」这条分支。
/// - **项的位置不再承载 `θ`**。它是背景，不承载语义；`θ` 通道仍由 `Z2` 起的
///   项位置承载（那一段没动）。
/// - **域点有标注**（`domainLabelKey`），只标第一条臂那个落点。
///
/// ## `Z2` 画的是一朵云（`V-1d` · `VIEW-038`）
///
/// `Z2` 又是一套几何（`nebula_map.dart` + `nebula_painter.dart`）：一个域
/// = 一朵**无边界粒子云** + 云里的项 + **亮结**（`⪯` 子树）+ 跨域出口标记。
/// 粒子数固定（`C-62`），不跟项数走 —— 否则它是第三条「项数」通道。
///
/// 可点对象在这一档**有两个**（`VIEW-001`：`Z2` 容器与星都能点）：亮结 ⇒ `Z3`
/// （单项子树直接 `Z4`）、项 ⇒ `Z4`；重叠处算容器的（亮结画在上方）。跨域边
/// 画成**朝外的箭头**而不是断线 —— 断线会被读成数据缺了。
///
/// `Z3` 画的是**一条 `⪯` 链**（一颗恒星 + 共面轨道，`VIEW-039`），恒星 = 选中项、
/// 行星 = 它的同域后继。可点对象两个：行星 ⇒ `Z4`、恒星 ⇒ `Z4`（根项的特写）。
/// `Z4` 仍走项投影 —— 单星特写（`VIEW-040`）另立一笔。
///
/// 三个后果值得记住：
///
/// - **可点对象只有星系盘**，点它 ⇒ 换根并落 `Z1`（`_jumpToSpace`，与搜索命中
///   同一条路）。点空白什么都不做。
/// - **标注是 widget 不是画布文字**：`VIEW-036` 要求它屏幕空间、不随自转旋转、
///   字号统一 —— 画进画布就会跟着盘的倾角一起变形。
/// - **没有包就没有星系**：合成回落背后没有 `KnowledgeSpace`，给它编一个空间
///   等于凭空造数据，所以那种情形退回项场景（诊断路径，不是形态）。
///
/// ## 切换为什么是交叉淡入
///
/// `VIEW-010`：宇宙位置由 `r/θ/φ` 决定、树位置由 `⪯` 缩进决定，两者**不同构**。
/// 任何「宇宙收拢成一棵树」的过渡都在造一个既不是宇宙也不是树的中间状态，
/// 所以只做 `C-22` 区间的交叉淡入。
///
/// **相机状态跨模式保留**（`VIEW-009` 末句）：来回切换不重置 yaw / pitch。
/// 树 → 宇宙的档位由**选中项的 `φ`** 定，不由「树里展开到第几层」定。
///
/// ## 跨空间搜索与换根（`VIEW-031` / `033`）
///
/// 根是**一组**（[UniverseScreen.roots]），当前停在哪一个由 `_spaceId` 决定。
/// 作用域跟着档位走：`Z0` 搜全部空间，其余档位默认只搜本空间，浮层顶部给一行
/// 「在全部空间中搜索」。
///
/// **换根 = 换 `_spaceId`**，没有第二处状态：`scene` 与 `pack` 都由它从 `roots`
/// 里查出来。把当前根同时存成 `scene` / `pack` 字段就会有两份真相，而它们迟早
/// 不一致（`R-08` 同族）。
///
/// 跨空间的命中**能跳了**：换根之后落到目标空间的那一项（`VIEW-031` 末句）。
/// 跳过去算「走过一步」—— 若当时在详情里，离开的那一项（**连同它的空间**）压进
/// `trail`；若不在详情里，则记 `returnTo` 快照（快照带 `spaceId`，`Z2` 起还带
/// `domainId`）。两条都不重置：用户是从 A 空间某处走到 B 空间某处，不是「刚打开
/// 详情」。
///
/// `VIEW-031` 给的两条路（作用域、跨空间落点）**都在浮层里**。屏幕上的入口是
/// `Z0` 那些星系本身（`VIEW-036`：一个空间一个星系，点它 ⇒ 换根 + `Z1`），
/// 以及面包屑第 1 段。`B3` 收尾时加过一排换根 chips，`V-1a` 已撤 —— 同一个
/// 动作两个入口，语义迟早分叉（chips 推 `Z0`、星系推 `Z1` 就是已经发生过的
/// 分叉）。
///
/// 面板上的空间名只有 `VIEW-033` 要求的前缀，没有额外的「已切换」提示 ——
/// 换根之后面包屑与诊断行都会写新的空间，那比一句 toast 更早也更准。
///
/// ## 导航记忆（`VIEW-015` / `VIEW-016`）
///
/// 所有改模式 / 档位 / 选中项 / 根的动作都过 [`_navigate`]，因为「要不要记导航
/// 记忆」是这些动作共有的后果。判据在 `_navigate` 的注释里。
///
/// 返回先退 `trail`、退空了才用 `returnTo`：前者是「详情里走过的步」，后者是
/// 「进详情之前」。反了就会把用户走过的那几步一次作废。
///
/// ## 本笔没有做的
///
/// 跨空间的「措辞不同」（`VIEW-030` ②）：邻近候选只从本空间取 —— 换词换的是
/// 本空间的叫法，跨空间换词要先有落点。
///
/// ## 绘制表面封顶（`C-33` / `ADR-0002` 修订三）
///
/// 窗口再大，绘制表面也只到 `C-33` 的基准面积为止，然后靠 `FittedBox` 放大贴满
/// —— 光栅成本跟的是**绘制表面**，不是窗口。判据用**物理面积**
/// （`w·h·dpr²`，见 `planViewport`）：只看逻辑尺寸的话，高分屏上这条封顶等于
/// 不存在。拾取因此必须吃**画布坐标**而不是窗口坐标，同时手势不能拿
/// `details.localPosition`（`FittedBox` 下命中的 RenderBox 不一定是画布盒）。
///
/// ## 点星与罗盘（本笔接上的两个输入器）
///
/// 这个宿主此前是**只读**的：宇宙画得出来，但点不动 —— 所有输入只能从树或
/// 定位浮层走。`VIEW-014` 的六入口里，宇宙点星是第一个；`VIEW-019` 把 ⑥ 定成
/// 「加筛选」的输入器、② 定成「看和删」的状态栏，此前只有后者是真的。
///
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/entities/content.dart';
import '../../core/enums.dart';
import '../../core/locate/locator.dart';
import '../../core/pack/pack_parse.dart';
import '../../core/view/detail.dart';
import '../../core/view/filter.dart';
import '../../core/view/navigation.dart';
import '../../core/view/tree.dart';
import '../../core/view/viewport.dart';
import '../../core/view/zoom.dart';
import '../detail/detail_panel.dart';
import '../locate/locate_overlay.dart';
import '../palette.dart';
import 'filter_chips.dart';
import 'frame_painter.dart';
import 'galaxy_map.dart';
import 'galaxy_painter.dart';
import 'label_layout.dart';
import 'nebula_map.dart';
import 'nebula_painter.dart';
import 'scene_pick.dart';
import 'scene_source.dart';
import 'spiral_map.dart';
import 'spiral_painter.dart';
import 'star_map.dart';
import 'star_painter.dart';
import 'tree_view.dart';

/// 七区块的 `Key` —— widget test 靠它断言「该出现的出现了、不该出现的没出现」。
const Key hudBreadcrumbKey = Key('hud-breadcrumb');
const Key hudFilterChipsKey = Key('hud-filter-chips');
const Key hudScopeSettingsKey = Key('hud-scope-settings');
const Key hudDetailDrawerKey = Key('hud-detail-drawer');
const Key hudFocusStarKey = Key('hud-focus-star');
const Key hudAxisCompassKey = Key('hud-axis-compass');

/// ⑦ 视距刻度条 —— **已作废**（`VIEW-018` 修订 1）。
///
/// 常量留着只作**断言靶子**：要让「这里空着」可观测，得有个确定的“不在”可以
/// 断言。靠「找不到 `Z0 宇宙` 这五个字」间接证明不行 —— 别的面板里出现同名
/// 文字时就会假绿，而那种巧合在后续笔次里迟早发生。
const Key hudZoomScaleKey = Key('hud-zoom-scale');

/// 换根 chips —— **已作废**（`VIEW-018` 修订 3，PR #59 回退）。同上，只作靶子。
const Key hudSpaceSwitchKey = Key('hud-space-switch');

/// 模式切换的命中盒（在 ① 内）。图标跟随面包屑末尾，盒子 44 px。
const Key hudModeSwitchKey = Key('hud-mode-switch');

/// ① 里的模式图标本体（14 px，`VIEW-018` 修订 2）。
const Key hudModeIconKey = Key('hud-mode-icon');

/// ① 里 `Z0` 的放大镜（`VIEW-018` 修订 2：`Z0` 不出项，搜索是唯一通路）。
const Key hudSearchKey = Key('hud-search');

/// 面包屑的**一段**。`index` 从 0 起。
///
/// 只有前段**有**这个 key —— 末段是纯文字（已在，点它没有意义），拿不到 key
/// 本身就是「不可点」这条规则的证据。
Key hudCrumbKey(int index) => Key('hud-crumb-$index');

/// ⑥ 罗盘里某个轴按钮（点它展开 / 收起该轴的取值）。`VIEW-020`。
Key compassAxisKey(String axisKey) => Key('compass-axis-$axisKey');

/// `Z0` 里某个星系的标注（`VIEW-036`）。**一个空间一个** —— 测试靠它数
/// 「屏幕上有几个星系」，也靠它确认标注是**屏幕空间里的文字**而不是画上去的
/// 像素（`VIEW-036` 要求标注恒显、不随自转旋转）。
Key galaxyLabelKey(String spaceId) => Key('z0-galaxy-$spaceId');

/// `Z0` 的退化提示：盘半径触到 `C-53` 下限 ⇒ `VIEW-036` 判「退化为列表式」。
///
/// 本笔不实现列表形态，但**必须把这件事说出来** —— 不说的话，用户看到的是
/// 「几个小得看不清的盘」，而不是「这一档画不出星系」。
const Key hudZ0DegradedKey = Key('z0-degraded');

/// `Z1` 里某个域的标注（`VIEW-037`）。一个域一个 —— 测试靠它数「盘上有几个域」，
/// 也靠它确认标注是**屏幕空间里的文字**而不是画上去的像素（同 `Z0` 的标注口径）。
///
/// ⚠️ 只有**第一条臂**那个落点带标注：两条臂各一个域点，但同一个域写两遍名字
/// 会让盘上出现成对的重复文字，反而看不出「两个点是一个域」。
Key domainLabelKey(String domainId) => Key('z1-domain-$domainId');

/// `Z2` 里某个亮结的标注（`VIEW-038`）。一个亮结一个 —— 测试靠它数「云里有
/// 几棵 `⪯` 子树」，也靠它确认标注是屏幕空间里的文字。
Key nebulaKnotKey(String rootId) => Key('z2-knot-$rootId');

/// `Z2` 里某个跨域出口的标注（`VIEW-038`：`→ 进入〈域名〉`）。
///
/// ⚠️ 规格写的是「〈动词形态〉」，而包里没有域的动词形态（无 `Domain` 实体）
/// ⇒ 退成末段域名。与 `VIEW-018` 的中文域名同一个 `PACK` 缺口。
Key nebulaExitKey(String targetDomainId) => Key('z2-exit-$targetDomainId');

/// `Z3` 里恒星的标注（`VIEW-039`）。一个恒星系一个 —— 测试靠它确认
/// 「这一档画的是一颗恒星 + 共面轨道」而不是项投影。
///
/// ⚠️ **行星不标名**：`VIEW-040` 明写 `Z4` 不标行星名，`Z3` 与它同一条口径 ——
/// 九颗行星围绕中心排，标名要么把标签甩到看不清的地方，要么九个标签互相压。
/// 要认哪颗是哪项，点它进 `Z4` 看抽屉。
Key starLabelKey(String rootId) => Key('z3-star-$rootId');

/// ⑥ 罗盘展开后，某个轴取值的那一行（点它写 / 取消筛选）。
Key compassValueKey(String axisKey, String value) =>
    Key('compass-value-$axisKey-$value');

/// ⑥ 罗盘面板宽度**下限**。六个轴名要一行排得下。
///
/// 236 这句「一行排得下」原是**没实测过的假设**：内宽 212，而按钮内边距 6 +
/// 间距 2 让六个按钮占 225 —— 「技术栈」被挤到第二行。实测（内边距 4 / 间距 1）
/// 六个按钮合计 192.3，236 够了。
///
/// 为什么不是写死一个更宽的数：`·N` 后缀在 11px 字号下要占 33.3 ——
/// 「能力」宽 30.2，带上「·1」变 63.5。两个轴同时筛就要 263.9，任何「写宽一点」
/// 的常数都得越过 288 才够，而那会让空状态下留一大片空白。所以宽度改成
/// **下限 + 上限、由内容撑开**（见 `_compass()`），空状态仍是 236。
const double _compassMinWidth = 236;

/// ⑥ 罗盘面板宽度**上限**。留到「两个轴同时筛」还排得下（263.9 + 内边距 24）。
/// 再多的轴一起筛就换行 —— `Wrap` 在那里是兜底，不是主路径。
const double _compassMaxWidth = 288;

/// ⑥ 罗盘展开取值列表的最大高度。超出就滚动 —— 一个轴的取值可能几十个，
/// 不封顶会把整块画面吃掉（而它是左下角的**输入器**，不是主视图）。
const double _compassValuesMaxHeight = 220;

/// 自转一圈的时长。慢到能看清，又不至于让人以为界面卡住。
const Duration _spinPeriod = Duration(seconds: 24);

const double _cameraPitch = 0.42;

/// 树模式右栏（详情常驻）的宽度。
const double _drawerWidth = 380;

/// 树模式给右栏让出的横向空间（含右外边距）。
const double _drawerReserve = _drawerWidth + 32;

/// ② 所在的一行占多高。树视图要在有筛选时把顶部让出这么多，
/// 否则 chips 会压在树的第一行上（`VIEW-018` 把 ② 定在顶部第二行）。
const double _filterRowHeight = 40;

/// ① 从窗口顶端算起占多高（含 16 px 外边距）。
///
/// ② 与树的让位都读它，**不能各自写一个数**：`V-1a` 之前 ① 是两行文字（约 46），
/// 模式图标换成 44 px 命中盒之后长到 76 —— 若 ② 仍按 72 摆，就会压在 ① 的下沿。
/// 一个高度出现在两处，改一处忘一处不会有任何东西变红（`R-08`）。
const double _hudTopHeight = 96;

/// 模式图标与放大镜的**图形**尺寸（`VIEW-018` 修订 2：与面包屑字号同大）。
const double _hudIconSize = 14;

/// 图标命中盒。图标只有 14 px，直接按图形判会「看得见点不中」。
const double _hudIconHit = 44;

/// 面包屑字号。与图标同大（`VIEW-018` 修订 2 把两者写成同一个数）。
const double _crumbFontSize = 14;

/// 面包屑单段的宽度上限。
///
/// 项标题可能是整句（α 包里最长 40 余字）。不封顶的话四段面包屑会把 ③ 挤出
/// 屏幕 —— 而 ③ 是「圈内/圈外 · 设置」，被挤掉时用户只会觉得少了个按钮。
const double _crumbMaxWidth = 160;

/// `Z0` 星系标注的宽度与行距（`VIEW-036`：盘下方居中、恒显）。
const double _galaxyLabelWidth = 140;
const double _galaxyLabelGap = 6;

/// 标注两行的字号。**两行都是定值**：字号不得承载项数 —— 那会成为第二条
/// 编码项数的通道，与盘半径打架（`VIEW-036` / `X-02`）。
const double _galaxyNameFontSize = 12;
const double _galaxyMetaFontSize = 10;

/// `Z1` 域点标注的宽度、与域点的间距、字号（`VIEW-037`）。
///
/// 12 个域 × 120 px 在 800 px 宽的窗口里必然有重叠 —— 本笔接受重叠（域名是
/// 辨认用的，不是布局对象），归终端观感验收。宽度取 120 是为了 `data-model`
/// 这类 10 字符的末段名一行放得下。
const double _domainLabelWidth = 120;
const double _domainLabelGap = 10;
const double _domainLabelFontSize = 10;

/// `Z2` 亮结标注与跨域出口的尺寸（`VIEW-038`）。
///
/// 132 比 `Z1` 的域标注宽一点：亮结标的是**项标题**（「装饰器的参数顺序」这类
/// 比 `domainId` 末段长），一行放不下就省略号 —— 字号仍统一，不承载任何语义。
const double _nebulaLabelWidth = 132;
const double _nebulaLabelGap = 8;
const double _nebulaLabelFontSize = 10;

/// 出口标签离云缘的距离（px）。往外让一格，免得压在粒子上。
const double _nebulaExitLabelGap = 12;

/// `Z3` 恒星标注的尺寸（`VIEW-039`）。
///
/// 宽度取 150：恒星标的是**根项标题**（「装饰器的参数顺序」这类），比域名长、
/// 与 `Z2` 的亮结同一量级。字号仍统一 —— 只有一颗星要标，不需要更小去挤。
const double _starLabelWidth = 150;
const double _starLabelGap = 8;
const double _starLabelFontSize = 11;

/// 标注包围盒的高度系数（`V-1d2`）。
///
/// 避让只需要**包围盒**，不需要像素级精确 —— `Text` 的实测高度要 `TextPainter`
/// 量，而为一行 10 px 的字去量一次，会把这个纯函数变成需要渲染上下文的东西。
/// 1.4 是 CJK 在 10–12 px 下的常见行高比，且**宁大勿小**：估小了标签会挨得比
/// 实际更近，那正是本笔要解决的问题。
const double _labelLineHeight = 1.4;

class UniverseScreen extends StatefulWidget {
  const UniverseScreen({
    required this.roots,
    this.initialZoom = ZoomLevel.z1,
    this.initialMode = ViewMode.universe,
    super.key,
  }) : assert(roots.length > 0, '至少要有根 —— 空列表会让界面变成一块空白');

  /// 只有一个根的退化写法。产品代码不走它；测试与「还没接多空间」的入口走。
  ///
  /// 它是**构造**而不是第二个状态：内部照样折成 `roots` 一项，所以「当前画的是
  /// 哪个根」始终只有 `_spaceId` 一处在管。
  UniverseScreen.single({
    required SceneBundle scene,
    LoadedPack? pack,
    ZoomLevel initialZoom = ZoomLevel.z1,
    ViewMode initialMode = ViewMode.universe,
    Key? key,
  }) : this(
         roots: <SceneResolution>[SceneResolution(bundle: scene, pack: pack)],
         initialZoom: initialZoom,
         initialMode: initialMode,
         key: key,
       );

  /// 装进内存的全部空间（`SPEC-VIEW-031`）。第一个是默认根。
  ///
  /// 一次装全部而不是「换根时再装」：换根发生在点击的那一帧里，那里不能有 IO。
  /// 代价是内存，而这是单机、书只有几本。
  final List<SceneResolution> roots;

  /// 进入时的档位。真实入口由「当前上下文」决定，本笔先给默认。
  final ZoomLevel initialZoom;

  /// 进入时的模式。默认宇宙。
  final ViewMode initialMode;

  @override
  State<UniverseScreen> createState() => _UniverseScreenState();
}

class _UniverseScreenState extends State<UniverseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  late CameraState _camera;
  late ViewMode _mode;

  /// 当前根的空间 id（`SPEC-VIEW-031` 多根）。`null` = 合成回落的根。
  ///
  /// **只有这一个字段记「我在哪个空间」**：`scene` 与 `pack` 都从它查出来。
  String? _spaceId;

  /// 当前选中项。**与 `CameraState.selectedItemId` 分开存**：后者是「宇宙里
  /// Z4 聚焦谁」，退出 Z4 就该清（`VIEW-013`）；而选中项跨模式保留，否则
  /// 树 → 宇宙 → 树 一走，用户还得重新找自己刚才在看什么。
  String? _selectedItemId;

  /// 当前所在的域（`VIEW-018` 修订 2 的面包屑第 3 段）。`null` = 还没进任何域。
  ///
  /// **为什么是独立状态，而不是从选中项现推**：点面包屑第 3 段要退到 `Z2` 并
  /// 清掉选中项（那一项已经不在视图里），而 `Z2` 的面包屑仍要显示域名 —— 现推
  /// 的话，退完立刻掉回两段，用户会以为点到了更外层。
  ///
  /// `VIEW-015` 的快照带它（`V-1f` 起）：缺了它，从 `Z4` 返回 `Z2` 会落在
  /// **第一个域**上（或干脆不画云）—— 档位 / 模式 / 空间全对、只有内容错，
  /// 没有任何东西会变红。
  String? _domainId;

  /// ② 的筛选表达式（DNF）。空 = 不过滤，② 整块不渲染（`VIEW-018`）。
  AxisFilter _axisFilter = emptyAxisFilter;

  /// 定位浮层是否打开（`VIEW-026`：浮层，不常驻）。
  bool _locating = false;

  /// 进详情前的那一帧（`VIEW-015`）。`null` = 没在详情里，或已经退回来了。
  ViewSnapshot? _returnTo;

  /// 详情页**内部**历史（`VIEW-016`），上限 `C-21`。存的是**离开的那一项**，
  /// 所以 `last` 就是「上一次停在谁那儿」——带上空间，见 `TrailStep`。
  List<TrailStep> _trail = const <TrailStep>[];

  /// 返回时要重开的搜索词（`VIEW-015` 的 `selector`）。
  ///
  /// 只在「从搜索进详情、又退回来」那一刻有值，浮层读到就清 —— 留着会让下一次
  /// `⌘K` 带着上一次的词，而 `VIEW-026` 的口径是「浮层，用完即走」。
  String? _restoreSelector;

  /// ⑥ 罗盘当前展开的轴（`VIEW-020` 就地展开）。`null` = 六个轴都收起。
  ///
  /// 一次只展开一个轴：罗盘是「选一个轴、挑几个值」的短流程，同时摊开六个
  /// 轴的取值会变成长列表，而 `VIEW-020` 否掉的正是「让用户在两处往返挑」。
  String? _compassAxis;

  /// 屏幕根的焦点节点。`⌘K` / `Ctrl+K` 靠它接键（见 `_closeLocate`）。
  final FocusNode _rootFocus = FocusNode(debugLabel: 'universe-root');

  /// 画布盒。拾取要用 `globalToLocal` 把指针位置映到它上面（见 `_universeBody`）。
  final GlobalKey _canvasKey = GlobalKey(debugLabel: 'universe-canvas');

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: _spinPeriod)..repeat();
    _camera = CameraState(
      zoom: widget.initialZoom,
      yawRadians: 0,
      pitchRadians: _cameraPitch,
    );
    _mode = widget.initialMode;
    // 默认停在第一个根。**不接受外部指定初始根**：多一个入参就多一条「传了个
    // 不存在的 id 怎么办」的不可测分支，而真实入口（空间列表）本来就从第一个
    // 开始读。跨空间落点之后由 `_spaceId` 自己走。
    _spaceId = widget.roots.first.pack?.space.id;
  }

  @override
  void dispose() {
    // 先 stop 再 dispose：`repeat()` 的 ticker 还活着时直接 dispose 会撞断言。
    _spin
      ..stop()
      ..dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  /// 按空间 id 找根。`spaceId == null` 找的是**合成回落**那一份（它没有包，
  /// 也就没有空间 id）。
  SceneResolution? _rootOf(String? spaceId) {
    for (final SceneResolution root in widget.roots) {
      if (root.pack?.space.id == spaceId) {
        return root;
      }
    }
    return null;
  }

  /// 当前根。
  ///
  /// 兜底到第一个只是为了让 `_root` 不是可空的 —— `_spaceId` 只会被写成
  /// `_rootOf(...) != null` 的值，所以兜底不该被走到。
  SceneResolution get _root => _rootOf(_spaceId) ?? widget.roots.first;

  /// 当前根的内容包。`null` = 合成回落 ⇒ 树视图与详情都拿不到 `Item`，界面
  /// 降级成「没有可展开的树」，而不是画一棵空树（`SPEC-FND-014` 未声明即不渲染）。
  LoadedPack? get _pack => _root.pack;

  SceneBundle get _scene => _root.bundle;

  /// 除当前根以外、也能被搜到的那些包（`SPEC-VIEW-031`）。
  ///
  /// 从 `roots` 推而不是从外面收：收进来的那一份与 `roots` 迟早不一致，而
  /// 不一致的表现是「多搜/少搜了一个空间」—— 没有任何东西会变红（`R-08` 同族）。
  List<LoadedPack> _otherPacks() => <LoadedPack>[
    for (final SceneResolution root in widget.roots)
      if (root.pack != null && root.pack!.space.id != _spaceId) root.pack!,
  ];

  /// 详情此刻是否可见。`VIEW-013` 把详情定义成「`Z4` 的渲染形态」，树里则是
  /// 右栏常驻 —— 两处都算「在详情里」，因为用户看到的是同样那四段。
  bool get _detailVisible =>
      _mode == ViewMode.tree || _camera.zoom == ZoomLevel.z4;

  /// 有没有可退的地方。`false` 时返回按钮**不渲染** —— 按下去什么也不会变的
  /// 按钮比没有更糟（同 `VIEW-031` 那一行放宽入口）。
  bool get _canGoBack => _trail.isNotEmpty || _returnTo != null;

  /// 当前视野的一帧。`selector` 只由「从搜索进来」的那条路径给。
  ///
  /// `domainId` 按**目标档位**判，不无条件复制 `_domainId`（`VIEW-015` 修订三
  /// 第 8 / 9 条）：只有 `Z2` 需要它 —— 那一档画面只画一个域，而这个域推不出来。
  /// `Z0` / `Z1` 不画域，存了不会被读；`Z3` / `Z4` 的域由选中项反推，存下来
  /// 反而多一条可能与选中项不一致的真相。
  ViewSnapshot _snapshot({String? selector}) => ViewSnapshot(
    mode: _mode,
    zoomLevel: _camera.zoom,
    spaceId: _spaceId,
    domainId: _camera.zoom == ZoomLevel.z2 ? _domainId : null,
    selectedItemId: _selectedItemId,
    axisFilter: _axisFilter,
    selector: selector,
  );

  /// 所有改模式 / 档位 / 选中项 / 根的动作都走这里。
  ///
  /// 为什么不让每个方法各自记：要不要写导航记忆是这些动作**共有**的后果，而
  /// 分散在七八处各写一遍必然漏一处 —— 漏了不会有任何东西变红（`R-08`）。
  ///
  /// 三条判据：
  /// - **详情从不可见变为可见** ⇒ 记 `returnTo`、`trail` 归零。这是「进详情」。
  /// - **已在详情里又换了一项** ⇒ `trail` 压入离开的那一项，`returnTo` **不动**。
  ///   覆盖它会让「返回」从「回出发地」退化成「回上一步」—— 而上一步本来就由
  ///   `trail` 管着，两处都管等于两处都不准。
  /// - **详情从可见变为不可见** ⇒ 两者一起清。这是「离开详情」。
  ///   ⚠️ 少了这一条，`Z4` 点面包屑退回上层之后 `returnTo` 会残留：抽屉里那个
  ///   「返回」按钮下一帧又出现在 `Z4`，按下去跳回**上一个** `Z4`。面包屑给了
  ///   「逐级后退」这个新入口（`V-1a`）之后，这条从「理论上可能」变成日常路径。
  ///
  /// 「换了一项」包含**换了根**：跨空间的两个同名项是两条不同的路，只比
  /// `itemId` 会把它们当成同一步，返回时落进错误的空间。
  void _navigate(VoidCallback change, {String? selector}) {
    final bool wasVisible = _detailVisible;
    final String? previousId = _selectedItemId;
    final String? previousSpaceId = _spaceId;
    final ViewSnapshot before = _snapshot(selector: selector);
    setState(() {
      change();
      final bool nowVisible = _detailVisible;
      if (!wasVisible && nowVisible) {
        _returnTo = before;
        _trail = const <TrailStep>[];
      } else if (wasVisible &&
          nowVisible &&
          (previousId != _selectedItemId || previousSpaceId != _spaceId)) {
        _trail = pushTrail(
          _trail,
          previousId == null
              ? null
              : TrailStep(spaceId: previousSpaceId, itemId: previousId),
        );
      } else if (wasVisible && !nowVisible) {
        _returnTo = null;
        _trail = const <TrailStep>[];
      }
    });
  }

  /// 返回一步（`VIEW-015` / `VIEW-016`）。
  ///
  /// 先退 `trail`，退空了才用 `returnTo` —— 顺序不能反：反了就等于把用户在详情
  /// 里走的几步一次作废，而他按的是「返回」不是「回起点」。
  ///
  /// 退 `trail` 时**连空间一起还原**：跨空间走过的那一步，回到的是「另一个空间
  /// 的那一项」，不只是「同 id 的那一项」。
  ///
  /// 不做「目标根不在了就继续退」的判空：`roots` 在本 widget 生命周期内不变，
  /// 所以 `trail` 里的 `spaceId` 必然还在。若将来 roots 变成运行期可变（例如边
  /// 用边装空间），这里要补那条 —— 否则返回会落到兜底根上，且没有任何提示。
  void _goBack() {
    final ({TrailStep? step, List<TrailStep> trail}) stepped = popTrail(_trail);
    final TrailStep? previous = stepped.step;
    if (previous != null) {
      setState(() {
        _trail = stepped.trail;
        _spaceId = previous.spaceId;
        _selectedItemId = previous.itemId;
        // 域必须跟着选中项重算：`trail` 存的是「离开的那一项」，跨域返回时
        // 域也跟着换。漏了这一行，面包屑会写着**上一项**的域配**这一项**的
        // 名字（两段都渲染得出来，只是彼此矛盾）。
        _domainId = _rootOf(previous.spaceId)?.pack
            ?.itemOf(previous.itemId)
            ?.domainId;
        // 返回详情内的一项 ⇒ 它必然在 `Z4`（那是详情唯一可见的宇宙态）。
        _camera = _camera.withZoom(
          ZoomLevel.z4,
          selectedItemId: previous.itemId,
        );
      });
      return;
    }
    final ViewSnapshot? snapshot = _returnTo;
    if (snapshot == null) {
      return;
    }
    setState(() {
      _returnTo = null;
      _trail = const <TrailStep>[];
      _spaceId = snapshot.spaceId;
      _mode = snapshot.mode;
      _axisFilter = snapshot.axisFilter;
      _selectedItemId = snapshot.selectedItemId;
      _domainId = _domainOf(snapshot);
      _camera = _camera.withZoom(
        snapshot.zoomLevel,
        selectedItemId: snapshot.selectedItemId,
      );
      // `VIEW-015` 存 `selector` 不存结果列表 ⇒ 词放回去，结果按当下重算。
      _restoreSelector = snapshot.selector;
      _locating = snapshot.selector != null;
    });
  }

  /// 从快照还原域（`VIEW-015` 修订三）。判据是「**目标档位画不画域**」，不是
  /// 「离开时在不在域里」：
  ///
  /// | 目标档位 | 域 | 为什么 |
  /// |---|---|---|
  /// | `Z0` / `Z1` | 空 | 这两档不画域；`Z1` 是全景，带着域会让面包屑多出一段 |
  /// | `Z2` | **读快照** | 这一档只画一个域，而域推不出来 —— 缺它就是「全对、只有内容错」 |
  /// | `Z3` / `Z4` | 按选中项反推 | 恒星 / 详情里的那一项自带域，反推与当初那个必然一致 |
  ///
  /// `Z2` 为什么不能也反推：从 `Z3` 点面包屑退回 `Z2` 时选中项被清空，而域
  /// 留着 —— 那一帧进详情，`selectedItemId` 是 `null`，反推只能得到 `null`。
  String? _domainOf(ViewSnapshot snapshot) {
    if (snapshot.zoomLevel == ZoomLevel.z0 ||
        snapshot.zoomLevel == ZoomLevel.z1) {
      return null;
    }
    if (snapshot.domainId != null) {
      return snapshot.domainId;
    }
    final String? id = snapshot.selectedItemId;
    if (id == null) {
      return null;
    }
    return _rootOf(snapshot.spaceId)?.pack?.itemOf(id)?.domainId;
  }

  /// 面包屑前段点击：退到该层（`VIEW-018` 修订 2，「走 `returnTo` 同一入口」）。
  ///
  /// 三个分支的差别只在**清到哪一层**：
  ///
  /// | 目标 | 选中项 | 域 | 为什么 |
  /// |---|---|---|---|
  /// | `Z0` | 清 | 清 | 宇宙层不出项，也不属于任何域 |
  /// | `Z1` | 清 | 清 | 星系层里项是背景（`VIEW-037`），留着会让「我选中了谁」失去所指 |
  /// | `Z2` | 清 | **留** | 域就是这一层的容器；清了面包屑立刻掉回两段 |
  ///
  /// 也顺手切回宇宙：树里点第 1 段等于「回 `Z0`」，而树没有 `Z0` 形态。
  /// `withZoom` 保留 yaw / pitch —— 退层不重置视角（`SPEC-VIEW-009`）。
  void _toLevel(ZoomLevel level) {
    _navigate(() {
      _mode = ViewMode.universe;
      if (level != ZoomLevel.z2) {
        _domainId = null;
      }
      _selectedItemId = null;
      _camera = _camera.withZoom(level, selectedItemId: null);
    });
  }

  void _switchMode(ViewMode next) {
    if (next == _mode) {
      return;
    }
    _navigate(() {
      if (next == ViewMode.universe) {
        // `VIEW-009`：树 → 宇宙按选中项的 `φ` 定档，不按展开深度。
        _camera = _camera.withZoom(
          _zoomForSelection(),
          selectedItemId: _selectedItemId,
        );
      }
      _mode = next;
    });
  }

  /// 选中项决定回宇宙时落哪一档。没有选中 ⇒ 留在当前档。
  ZoomLevel _zoomForSelection() {
    final LoadedPack? pack = _pack;
    final String? id = _selectedItemId;
    if (pack == null || id == null) {
      return _camera.zoom;
    }
    final bool hasChildren = pack.edges.any((Edge edge) => edge.from == id);
    return zoomForPhi(phiLevelsOf(pack)[id] ?? 0, hasChildren: hasChildren);
  }

  /// 详情内换一项（关系行点击，`VIEW-014`）。**`trail` 的唯一写入点**。
  ///
  /// 树里点项也走这里：树里的详情是常驻右栏，「从 A 翻到 B」与宇宙里「从 A 跳
  /// 到 B」对用户是同一件事。
  void _select(String itemId) => _navigate(() {
    _selectedItemId = itemId;
    // 域跟着选中项走：树里点一项，面包屑第 3 段必须是**它所在的域** —— 否则
    // 第 3、4 段会来自两个不同的位置（看着 A、面包屑写着 B），而两段都渲染得
    // 出来，只是彼此矛盾，没有任何东西会变红（`R-08` 同族）。
    _domainId = _pack?.itemOf(itemId)?.domainId ?? _domainId;
  });

  // ── 快速定位（`SPEC-VIEW-024`–`033`） ───────────────────────────────────

  void _openLocate() => setState(() => _locating = true);

  /// 关浮层，并把焦点收回屏幕根。
  ///
  /// 为什么必须收：浮层里的输入框占着主焦点，浮层一拆，那个 `FocusNode` 就被
  /// 销毁 —— 主焦点落空之后 `⌘K` 没有节点接着冒泡，**第二次搜索打不开**
  /// （表现是「快捷键只灵一次」）。等到这一帧拆完再请求焦点，否则收上来的焦点
  /// 会在同一帧里被「销毁输入框」这一步又推走。
  void _closeLocate() {
    setState(() {
      _locating = false;
      // 词已经用掉了：留着会让下一次 `⌘K` 带着上一次的输入（`VIEW-026` 的
      // 口径是「浮层，用完即走」）。
      _restoreSelector = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rootFocus.requestFocus();
      }
    });
  }

  /// 一条命中的落点。**这是整个搜索唯一的行为出口**。
  ///
  /// 浮层只负责「输入 → 命中集 → 用户选了哪条」，跳哪一档、换不换根、写不写
  /// 筛选都在这里。拆开的好处是浮层能单独测，而「点完之后世界怎么变」只有一处
  /// 可读。
  ///
  /// 每一条都带 `hit.spaceId`：命中集可跨空间，落点因此都要先确定**去哪个根**。
  void _applyHit(LocateResult result, LocateHit hit) {
    _closeLocate();
    switch (hit.kind) {
      case LocateKind.item:
        // 只有这条路径带 `selector`：用户是从「搜了什么」进来的，返回时词该
        // 还在（`VIEW-015`）。点星与树里点项都不是从搜索来的，带 null。
        _jumpToItem(hit.spaceId, hit.target, selector: result.query);
      case LocateKind.domain:
        _jumpToDomain(hit.spaceId, hit.target);
      case LocateKind.space:
        _jumpToSpace(hit.target);
      case LocateKind.axis:
        _jumpToAxisValue(hit);
    }
  }

  /// 落点：换到 [spaceId] 那个根，选中该项并**直接推到 `Z4`**（`VIEW-014` / `027`）。
  ///
  /// ⚠️ 这里**不用** `zoomForPhi`。`VIEW-009` 的「按 `φ` 定档」管的是
  /// 「树 → 宇宙」—— 那是在问「我在树里翻到的位置，换算成宇宙的哪一层」。
  /// 搜索是相反的问题：「我要这一项」。按 `φ` 定档会把用户送到它所在的
  /// 星云（`Z2`），而他要找的那颗星只有 `Z4` 才看得见 —— 那等于搜完还得
  /// 再点一次，`VIEW-027`「唯一命中直接跳转」就白写了。
  ///
  /// [spaceId] 与当前根不同 ⇒ 这就是换根：`scene` / `pack` / 树 / 罗盘的值域
  /// 全部跟着换。选中项必须先落到目标空间再取详情，否则抽屉会按旧包算。
  void _jumpToItem(String? spaceId, String itemId, {String? selector}) {
    if (_rootOf(spaceId)?.pack == null) {
      return;
    }
    _navigate(() {
      _spaceId = spaceId;
      _selectedItemId = itemId;
      // 域先按目标包取：`_spaceId` 刚改，`_pack` 下一次读才是新的 —— 这里显式
      // 从 `_rootOf` 取，不依赖 getter 的时序（读 getter 也对，但那样正确性
      // 挂在「setState 里字段已经换过」这个隐含前提上）。
      _domainId = _rootOf(spaceId)?.pack?.itemOf(itemId)?.domainId;
      _mode = ViewMode.universe;
      _camera = _camera.withZoom(ZoomLevel.z4, selectedItemId: itemId);
    }, selector: selector);
  }

  /// 空间是落点类（`VIEW-001`）⇒ 换根到它并推到 **`Z1`**。
  ///
  /// ⚠️ `V-1a` 之前这里推的是 `Z0`。`Z0` 现在是**宇宙层**（全部空间并列，
  /// `VIEW-036`），落到单个空间应当是「进去了」⇒ `Z1`。同一条规则从「进去了」
  /// 变成「没进去」只是因为 `Z0` 改了含义（`VIEW-027` / `VIEW-031` 同批修订）。
  ///
  /// 顺带清掉选中项与域：旧空间的 id 在新空间里通常不存在，留着虽然当下看不出
  /// 差别（`_detail()` 找不到 `Item` 就返回 `null`，抽屉本来就空），但「树 → 宇宙」
  /// 会按 `phiLevelsOf(newPack)[旧 id] ?? 0` 猜成 0 层 —— 那是拿一个不存在的项
  /// 去定档。**这一条没有断言**：残留 id 在任何视图里都取不出内容，与 `null`
  /// 同效，可观测差异只在那个「猜档」上，而它本身没有独立出口。
  void _jumpToSpace(String spaceId) {
    if (_rootOf(spaceId) == null) {
      return;
    }
    _navigate(() {
      _spaceId = spaceId;
      _selectedItemId = null;
      _domainId = null;
      _mode = ViewMode.universe;
      _camera = _camera.withZoom(ZoomLevel.z1, selectedItemId: null);
    });
  }

  /// 域是落点类（`VIEW-028`），但宇宙里没有「选中一个域」这个状态 ——
  /// 落到 `Z2`（星云 = 域那一层，`SPEC-VIEW-001` 的面包屑示例）并顺手选中
  /// 该域最浅的一项：档位给出「这个域有多大」，选中项给出「从哪开始看」。
  ///
  /// **不推到 `Z4`**：域不是一项，推到单星等于替用户挑了一颗星，而他刚才
  /// 问的是「这个域在哪」。
  void _jumpToDomain(String spaceId, String domainId) {
    final LoadedPack? pack = _rootOf(spaceId)?.pack;
    if (pack == null) {
      return;
    }
    final Map<String, int> levels = phiLevelsOf(pack);
    final List<Item> inDomain = <Item>[
      for (final Item item in pack.items)
        if (item.domainId == domainId) item,
    ];
    if (inDomain.isEmpty) {
      return;
    }
    inDomain.sort((Item a, Item b) {
      final int phiA = levels[a.id] ?? 0;
      final int phiB = levels[b.id] ?? 0;
      return phiA == phiB ? a.title.compareTo(b.title) : phiA.compareTo(phiB);
    });
    _navigate(() {
      _spaceId = spaceId;
      _domainId = domainId;
      _selectedItemId = inDomain.first.id;
      _mode = ViewMode.universe;
      _camera = _camera.withZoom(
        ZoomLevel.z2,
        selectedItemId: inDomain.first.id,
      );
    });
  }

  /// 轴值是筛选类：**写 `axisFilter`，不换档位**（`VIEW-028`）。
  ///
  /// 但**要换根**：`sixAxis` 的取值域属于空间，在 A 空间里写一个只属于 B 空间
  /// 的取值，筛出来是空集。`VIEW-028` 的「不换根」以「筛的是当前根」为前提，
  /// 跨空间那一格不在它的射程内 —— 不换根的话用户按下去什么也看不到，那正是
  /// `VIEW-028` 想避免的「筛选当落点」。档位仍然不动：用户是在收窄视野。
  void _jumpToAxisValue(LocateHit hit) {
    final String? axisKey = hit.axisKey;
    if (axisKey == null || _rootOf(hit.spaceId)?.pack == null) {
      return;
    }
    // 不再校验「这个取值在该空间里存在」：命中就是从那个包的 `sixAxis` 里搜出来
    // 的，再查一遍等于立第二套判据 —— 两套迟早不一致，而不一致不会有东西变红。
    _navigate(() {
      if (hit.spaceId != _spaceId) {
        // 跨空间写筛选：域属于**旧**空间，留着会让 `Z2` 的面包屑第 3 段指向一个
        // 当前根里不存在的域 —— 名字照样渲染得出来，只是它不指任何东西。
        _domainId = null;
      }
      _spaceId = hit.spaceId;
      _axisFilter = toggleAxisValue(_axisFilter, axisKey, hit.target);
    });
  }

  /// 类 ②「措辞不同」的邻近候选（`VIEW-030`）：**先关门再落点**。
  ///
  /// 与命中走同一条落点路径（`_jumpToItem`）—— 它虽然不是命中，但用户选它
  /// 就是要那一项；区别只在「选完要不要关浮层」，而命中的那条在 `_applyHit`
  /// 开头已经关了。
  ///
  /// 候选只从**当前根**的包里取（`diagnose` 就是按本空间算的），所以这里带
  /// `_spaceId`，不换根。
  void _pickNear(String itemId) {
    _closeLocate();
    _jumpToItem(_spaceId, itemId);
  }

  // ── 宇宙点星（`SPEC-VIEW-014` 入口 1） ──────────────────────────────────

  /// 点星 → 进详情。
  ///
  /// 落点与搜索命中**完全一致**（`_jumpToItem`：选中 + 推到 `Z4`），因为
  /// `VIEW-013` 把详情定义成「`Z4` 的渲染形态」，而不是另一个页面。两处若
  /// 各判各的档，同一个项从搜索进去和从星图点进去会落在不同视距上 —— 用户
  /// 会以为点错了东西。
  ///
  /// **点空白什么都不做**（见 `core/frame/pick.dart` 文件头）：清掉选中会让
  /// 详情抽屉毫无预警地消失，而点歪是常态。
  ///
  /// [point] 是**画布坐标**（手势挂在画布内部，见 `_universeBody`）。
  /// [surface] 是画布尺寸 —— 降采样后它与窗口不等，拾取必须用画布这一套。
  void _pickAt(Offset point, Size surface, Set<String>? visibleIds) {
    final String? id = pickSceneNode(
      scene: _scene,
      viewport: surface,
      // 自转一直在动：用**这一刻**的偏航，不是基准偏航。
      yawRadians: spunYaw(_camera.yawRadians, _spin.value),
      point: point,
      visibleIds: visibleIds,
    );
    if (id == null) {
      return;
    }
    // 点星只在当前根上发生 ⇒ 带 `_spaceId`，不换根。
    _jumpToItem(_spaceId, id);
  }

  /// `Z0` 点星系 ⇒ 换根 + 落到 `Z1`（`VIEW-036` / `VIEW-027` 修订）。
  ///
  /// 落点复用 [`_jumpToSpace`]：搜索「空间」类命中走的是同一条路。两处各写
  /// 一遍的话，「点星系」与「搜空间」会落到不同档位 —— 而两条路对用户是
  /// 同一个动作（「进这个空间」）。
  ///
  /// **点空白什么都不做**（同 [`_pickAt`]）：清掉选中会让详情抽屉毫无预警地
  /// 消失，而点歪是常态。
  void _pickGalaxyAt(Offset point, GalaxyLayout layout) {
    final String? spaceId = pickGalaxyAt(layout: layout, point: point);
    if (spaceId == null) {
      return;
    }
    _jumpToSpace(spaceId);
  }

  /// `Z1` 点域点 ⇒ 进 `Z2`（`VIEW-037`：**唯一可点对象**）。
  ///
  /// 落点复用 [`_jumpToDomain`]：搜索「域」类命中走的是同一条路。两处各写一遍
  /// 的话，「点域点」与「搜域」会落到不同档位 —— 而两条路对用户是同一个动作。
  ///
  /// ⚠️ **项不在这里判**。`VIEW-037` 明写「点项位置不产生任何跳转」，所以点空
  /// 白与点项**走同一条分支**：什么都不做。这不是省事 —— 给项留一条「至少选中
  /// 它」的软响应，就等于让它可点，而规格要的正是「暗 = 背景」这一条视觉契约。
  void _pickDomainAt(Offset point, SpiralLayout layout) {
    final String? domainId = pickSpiralDomainAt(layout: layout, point: point);
    final String? spaceId = _pack?.space.id;
    if (domainId == null || spaceId == null) {
      return;
    }
    _jumpToDomain(spaceId, domainId);
  }

  /// `Z2` 的拾取：**先判亮结，再判星**（`VIEW-038`）。
  ///
  /// 容器优先与 `Z1` 同一条口径（`VIEW-037` 第 3 条：拾取先判容器）。这里两个
  /// 都能点（`VIEW-001`：`Z2` 两种都有），所以不是「挡住后者」，而是「重叠处
  /// 算容器的」—— 亮结画在星上方，点在它上面本来就该进它。
  ///
  /// 空处什么都不做：清掉选中会让右侧抽屉毫无预警地消失，而点歪是常态。
  void _pickNebulaAt(Offset point, NebulaLayout layout) {
    final NebulaKnot? knot = pickNebulaKnotAt(layout: layout, point: point);
    if (knot != null) {
      _jumpToKnot(knot);
      return;
    }
    final String? itemId = pickNebulaItemAt(layout: layout, point: point);
    if (itemId == null) {
      return;
    }
    _jumpToItem(_spaceId, itemId);
  }

  /// 点亮结：**单项子树直接进 `Z4`**（`VIEW-038`），其余进 `Z3`。
  ///
  /// 为什么单项要跳过 `Z3`：给一个只有一颗行星的恒星系画共面轨道是纯粹的空转
  /// —— 点进去看到的就是那一项，还要再点一次才到详情。
  ///
  /// `Z3` 落在哪一棵子树上记在 `selectedItemId`（= 子树根）。`V-1e` 实现恒星系
  /// 时按它取链，**不新增一个「当前子树」状态** —— 两个状态说同一件事，迟早
  /// 有一处忘同步。
  void _jumpToKnot(NebulaKnot knot) {
    if (knot.isSingle) {
      _jumpToItem(_spaceId, knot.rootId);
      return;
    }
    _navigate(() {
      _selectedItemId = knot.rootId;
      _mode = ViewMode.universe;
      _camera = _camera.withZoom(ZoomLevel.z3, selectedItemId: knot.rootId);
    });
  }

  /// `Z3` 的拾取：**先判行星，再判恒星**（`VIEW-039`）。
  ///
  /// 与 `Z2` 的「后画的优先」同一条口径：绘制序是云气 → 轨道 → 恒星 → 行星，
  /// 行星压在最上面 ⇒ 重叠处算行星的。内轨极近时会真重叠（`C-73 / C-72 ≈ 5.3`
  /// 倍半径，行星命中圈 24 px 与恒星命中圈 24 px 在 1080×580 下确实相交），
  /// 那时点中的应该是最上面那颗。
  ///
  /// 空处什么都不做，理由同 `_pickAt` / `_pickNebulaAt`：清掉选中会让详情抽屉
  /// 毫无预警地消失，而点歪是常态。
  void _pickStarAt(Offset point, StarSystemLayout layout) {
    final StarPlanet? planet = pickStarPlanetAt(layout: layout, point: point);
    if (planet != null) {
      _jumpToItem(_spaceId, planet.id);
      return;
    }
    if (hitsStarAt(layout: layout, point: point)) {
      // 恒星就是根项 —— 点它进的是**它自己**的特写，不是整个恒星系。
      _jumpToItem(_spaceId, layout.rootId);
    }
  }

  /// 画布 + 一层标注。四档共用（`Z0` / `Z1` / `Z2` / `Z3`）。
  ///
  /// 两个必须保持的行为，都写在同一个地方才守得住：
  /// - `FittedBox` 只在真降了分辨率时才包 —— `scale == 1` 时它是纯开销；
  /// - 标注层包 `IgnorePointer` —— 标注是装饰，压在画布上会吃掉点击
  ///   （`V-1d` 那处「⑤ 占位吃点击」就是这类缺陷，只是那时它是自己一层）。
  Widget _withLayer(
    Widget canvas,
    ViewportPlan plan,
    List<Widget> layer,
  ) => Stack(
    children: <Widget>[
      Positioned.fill(
        child: plan.isDownscaled
            ? FittedBox(fit: BoxFit.fill, child: canvas)
            : canvas,
      ),
      Positioned.fill(
        child: IgnorePointer(child: Stack(children: layer)),
      ),
    ],
  );

  /// `Z3` 的标注层（`VIEW-039`）：**只标恒星**。
  ///
  /// 行星不标名 —— 九颗围绕中心排，标名要么把标签甩到看不清的地方、要么九个
  /// 标签互相压。要认哪颗是哪项，点它进 `Z4` 看抽屉（`VIEW-040` 也不标行星名，
  /// 同一条口径）。
  ///
  /// 锚点取**恒星下缘**而不是恒星圆心：圆心离内轨只有 `C-73 / C-72 ≈ 5.3` 倍
  /// 半径，从圆心往下让 `gap` 会直接把标签压在恒星自己的光晕上。
  List<Widget> _starLayer(
    StarSystemLayout layout,
    Size surface,
    Size window,
  ) {
    final double scale = surface.width <= 0 ? 1 : window.width / surface.width;
    final List<LabelPlacement> placed = placeLabels(
      center: layout.starCenter * scale,
      anchors: <LabelAnchor>[
        LabelAnchor(
          key: 'star:${layout.rootId}',
          anchor: Offset(
            layout.starCenter.dx * scale,
            (layout.starCenter.dy + layout.starRadius) * scale,
          ),
          size: Size(
            _starLabelWidth,
            _starLabelFontSize * _labelLineHeight,
          ),
          payload: layout,
        ),
      ],
      viewport: window,
      gap: _starLabelGap * scale,
    );
    return <Widget>[
      for (final LabelPlacement p in placed)
        if (p.payload case final StarSystemLayout star)
          _placeLabel(
            p,
            Text(
              star.rootLabel,
              key: starLabelKey(star.rootId),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: paletteTextPrimary,
                fontSize: _starLabelFontSize,
              ),
            ),
          ),
    ];
  }

  /// `Z2` 的标注层（`VIEW-038`）：亮结标题 + 跨域出口。
  ///
  /// 与 `Z1` 的域标注同一套理由：**屏幕空间、不随画面旋转、字号统一**。标签
  /// 不画进画布是因为画布里的文字会跟着降采样一起糊。
  ///
  /// `V-1d2` 起落点交给 `placeLabels()`：亮结与出口在**同一朵云里**抢地方，
  /// 两段各写一遍就会互相压（此前亮结落正下方、出口按箭头方向外让，谁也不看
  /// 谁）。放进同一次避让，冲突才能被看见。
  List<Widget> _nebulaLayer(NebulaLayout layout, Size surface, Size window) {
    final double scale = surface.width <= 0 ? 1 : window.width / surface.width;
    final Size box = Size(
      _nebulaLabelWidth,
      _nebulaLabelFontSize * _labelLineHeight,
    );
    final List<LabelPlacement> placed = placeLabels(
      center: layout.center * scale,
      anchors: <LabelAnchor>[
        for (final NebulaKnot knot in layout.knots)
          LabelAnchor(
            key: 'knot:${knot.rootId}',
            anchor: knot.center * scale,
            size: box,
            payload: _KnotLabel(knot),
          ),
        for (final NebulaExit exit in layout.exits)
          LabelAnchor(
            key: 'exit:${exit.targetDomainId}',
            // 出口先按箭头方向往外让一格 —— 它贴着云缘，压在粒子上会被糊住。
            // 之后的同方位冲突仍由 `placeLabels` 处理。
            anchor:
                (exit.center + exit.direction * _nebulaExitLabelGap) * scale,
            size: box,
            payload: _ExitLabel(exit),
          ),
      ],
      viewport: window,
      gap: _nebulaLabelGap * scale,
    );
    return <Widget>[
      for (final LabelPlacement p in placed) _nebulaLabelWidget(p),
    ];
  }

  Widget _nebulaLabelWidget(LabelPlacement p) {
    switch (p.payload) {
      case _KnotLabel(:final NebulaKnot knot):
        return _placeLabel(
          p,
          Text(
            knot.label,
            key: nebulaKnotKey(knot.rootId),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: paletteTextPrimary,
              fontSize: _nebulaLabelFontSize,
            ),
          ),
        );
      case _ExitLabel(:final NebulaExit exit):
        return _placeLabel(
          p,
          Text(
            exit.label,
            key: nebulaExitKey(exit.targetDomainId),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: paletteTextSecondary,
              fontSize: _nebulaLabelFontSize,
            ),
          ),
        );
      case _:
        return const SizedBox.shrink();
    }
  }

  /// 把一段文字摆到 [placeLabels] 给出的矩形上。
  ///
  /// 三处标注层共用：落点由算法说，这里只负责「摆」—— 免得某处手抄一遍
  /// `left: rect.left, top: rect.top` 时漏掉 `width`，那会让文字按自身宽度
  /// 居中，与包围盒对不上。
  Widget _placeLabel(LabelPlacement p, Widget child) => Positioned(
    left: p.rect.left,
    top: p.rect.top,
    width: p.rect.width,
    child: child,
  );

  /// `Z1` 的域标注层（`VIEW-037`）。
  ///
  /// 与 `Z0` 的星系标注同一套理由：**屏幕空间、不随盘自转旋转、字号统一**。
  /// 只给第一条臂的落点写名字 —— 同一个域写两遍会让盘上出现成对的重复文字，
  /// 反而看不出「那两个点是一个域」。
  ///
  /// `V-1d2` 起落点交给 `placeLabels()`。真机截图里 `verb-conjugation`(513,232)
  /// 与 `verb-frame`(571,225) 中心距 58 px、标签宽 120 ⇒ 压了约 8 px，而注释里
  /// 原本写的是「接受重叠，归终端观感验收」—— 那句话在**十一个域**时是取舍，
  /// 在**相邻两个**时只是没做。
  List<Widget> _domainLayer(SpiralLayout layout, Size surface, Size window) {
    final double scale = surface.width <= 0 ? 1 : window.width / surface.width;
    final List<LabelPlacement> placed = placeLabels(
      center: layout.center * scale,
      anchors: <LabelAnchor>[
        for (final DomainMark mark in layout.marks)
          LabelAnchor(
            key: 'domain:${mark.domainId}',
            anchor: mark.primary * scale,
            size: Size(
              _domainLabelWidth,
              _domainLabelFontSize * _labelLineHeight,
            ),
            payload: mark,
          ),
      ],
      viewport: window,
      gap: _domainLabelGap * scale,
    );
    return <Widget>[
      for (final LabelPlacement p in placed)
        if (p.payload case final DomainMark mark)
          _placeLabel(
            p,
            Text(
              mark.label,
              key: domainLabelKey(mark.domainId),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: paletteTextSecondary,
                fontSize: _domainLabelFontSize,
              ),
            ),
          ),
    ];
  }

  /// `Z0` 的标注层（`VIEW-036`）。
  ///
  /// 做成 widget 而不是画进画布，是因为规格里有两条它才守得住：
  /// **不随自转旋转**（画布里的文字会跟着盘的倾角变形）与**字号统一**。
  ///
  /// 坐标要从画布空间换到窗口空间：降采样时画布小于窗口，直接拿画布坐标摆
  /// widget 会让标注整体偏左上一截 —— 而这种偏移在 1080p 以下看不出来。
  ///
  /// `V-1d2` 起落点交给 `placeLabels()`，锚点是**盘缘**而不是盘心：三个盘
  /// 在 1080×580 下只隔 36 px，正下方的副行会正好掉进那条缝里（实测），
  /// 而「谁的标签掉进缝里」取决于盘的大小，不是设计。
  List<Widget> _galaxyLayer(GalaxyLayout layout, Size surface, Size window) {
    final double scale = surface.width <= 0 ? 1 : window.width / surface.width;
    final Offset groupCenter = _groupCenter(layout);
    final List<LabelPlacement> placed = placeLabels(
      center: groupCenter * scale,
      anchors: <LabelAnchor>[
        for (final GalaxyDisc disc in layout.discs)
          LabelAnchor(
            key: 'space:${disc.spaceId}',
            anchor: _discRim(disc, groupCenter) * scale,
            size: Size(
              _galaxyLabelWidth,
              (_galaxyNameFontSize + _galaxyMetaFontSize) * _labelLineHeight,
            ),
            payload: disc,
          ),
      ],
      viewport: window,
      gap: _galaxyLabelGap * scale,
    );
    return <Widget>[
      for (final LabelPlacement p in placed)
        if (p.payload case final GalaxyDisc disc)
          _placeLabel(
            p,
            Column(
              key: galaxyLabelKey(disc.spaceId),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  disc.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: paletteTextPrimary,
                    fontSize: _galaxyNameFontSize,
                  ),
                ),
                Text(
                  // 副行给的是**规模**而不是进度（`VIEW-035`：HUD 不放事件计数），
                  // 所以它是「N 项 · M 域」，不是「已学 x 项」。
                  '${disc.itemCount} 项 · ${disc.domainCount} 域',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: paletteTextSecondary,
                    fontSize: _galaxyMetaFontSize,
                  ),
                ),
              ],
            ),
          ),
      // 盘半径触底（`C-53`）⇒ `VIEW-036` 判「该档退化为列表式」。列表形态不在
      // 本笔射程内，但**必须把这件事说出来**：不说的话，用户看到的是「几个小得
      // 看不清的盘」，而不会想到「这一档画不出星系」。
      if (layout.degenerate)
        Positioned(
          key: hudZ0DegradedKey,
          left: 0,
          right: 0,
          top: 16,
          child: Center(
            child: _panel(
              child: const Text(
                '星系盘触到最小半径（C-53）—— 该档应改为列表',
                style: TextStyle(color: paletteTextSecondary, fontSize: 11),
              ),
            ),
          ),
        ),
    ];
  }

  /// 星系群的**重心**（各盘心等权平均）。
  ///
  /// 用重心而不是视口中心：标注要朝群外散，朝群内挪就会撞到别的盘。只有一个盘
  /// 时重心 = 盘心 ⇒ 方位退化，`placeLabels` 走「正下方、水平居中」，与 `V-1d`
  /// 之前的落法**逐像素一致**（这是本笔唯一要求「不改变」的地方）。
  Offset _groupCenter(GalaxyLayout layout) {
    if (layout.discs.isEmpty) {
      return Offset.zero;
    }
    double x = 0;
    double y = 0;
    for (final GalaxyDisc disc in layout.discs) {
      x += disc.centerX;
      y += disc.centerY;
    }
    return Offset(x / layout.discs.length, y / layout.discs.length);
  }

  /// 盘缘上、沿「重心 → 盘心」方位的那一点。
  ///
  /// 不能用「盘心 + 单位向量 × 半径」：盘是 `C-59` 压扁过的椭圆，沿半径取会让
  /// 朝上下的标签落在盘面**里面**二十几个像素，朝左右的又离盘缘老远。按半长轴
  /// 管 `x`、半短轴管 `y` 取参数点，才是「贴着椭圆边缘」。
  Offset _discRim(GalaxyDisc disc, Offset groupCenter) {
    final Offset v = Offset(
      disc.centerX - groupCenter.dx,
      disc.centerY - groupCenter.dy,
    );
    if (v.distance < 1) {
      // 单盘（或盘心与重心重合）：没有方位可说，从半短轴往下摆。
      return Offset(disc.centerX, disc.centerY + disc.minorRadius);
    }
    final Offset u = v / v.distance;
    return Offset(
      disc.centerX + u.dx * disc.radius,
      disc.centerY + u.dy * disc.minorRadius,
    );
  }

  void _removeFilter(AxisFilterChip chip) {
    setState(() {
      _axisFilter = withoutAxisValue(_axisFilter, chip.axisKey, chip.value);
    });
  }

  void _clearFilter() => setState(() => _axisFilter = emptyAxisFilter);

  // ── ⑥ 罗盘（`SPEC-VIEW-019` / `020`） ───────────────────────────────────

  /// 展开 / 收起某个轴的取值。再点同一个轴就收起。
  void _toggleCompassAxis(String axisKey) {
    setState(() => _compassAxis = _compassAxis == axisKey ? null : axisKey);
  }

  /// 点一个取值：已选则去掉，未选则加上。
  ///
  /// 与 ② 的 `×` 是**同一个操作的两处入口**（`VIEW-019`：⑥ 负责加、② 负责
  /// 看和删，「删除与取消等价」）。两处都调 `withoutAxisValue` —— 若在这里
  /// 另写「从列表里摘掉」，空轴就不会被删键，`axisFilter` 里会留下一个
  /// 没有值的幽灵轴，而 ② 会数出一个空 chip。
  void _toggleCompassValue(String axisKey, String value) {
    final bool selected = (_axisFilter[axisKey] ?? const <String>[]).contains(
      value,
    );
    setState(() {
      _axisFilter = selected
          ? withoutAxisValue(_axisFilter, axisKey, value)
          : toggleAxisValue(_axisFilter, axisKey, value);
    });
  }

  /// 当前筛选下可见的项 id。`null` = 没筛（**不是空集**）。
  Set<String>? _visibleIds() {
    final LoadedPack? pack = _pack;
    if (pack == null) {
      return null;
    }
    return visibleIdsOf(pack, _axisFilter);
  }

  ItemDetail? _detail() {
    final LoadedPack? pack = _pack;
    final String? id = _selectedItemId;
    if (pack == null || id == null) {
      return null;
    }
    return buildItemDetail(pack, id);
  }

  @override
  Widget build(BuildContext context) {
    final ItemDetail? detail = _detail();
    final bool tree = _mode == ViewMode.tree;
    final bool showDetail = tree || _camera.zoom == ZoomLevel.z4;
    final Set<String>? visibleIds = _visibleIds();
    final bool filtered = visibleIds != null;

    // `⌘K` / `Ctrl+K` 挂在屏幕根上（`VIEW-026`）：搜索的价值是「手不离开键盘」，
    // 先找一个按钮就等于把那一步省下的时间又还回去了。
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openLocate,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openLocate,
      },
      child: Focus(
        focusNode: _rootFocus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: paletteBackground,
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: viewTransitionMs),
                  // 默认 transitionBuilder 就是 FadeTransition，两个 child 叠着淡入淡出。
                  // **不加任何形变**（`VIEW-010`）：滑动 / 缩放都会让「不同构」这件事
                  // 看起来像「同一个东西的两种形态」。
                  child: KeyedSubtree(
                    key: ValueKey<ViewMode>(_mode),
                    child: tree
                        ? _treeBody(filtered)
                        : _universeBody(visibleIds),
                  ),
                ),
              ),
              if (showDetail)
                Positioned(
                  right: 16,
                  top: tree ? 64 : 80,
                  bottom: tree ? 72 : null,
                  width: _drawerWidth,
                  child: DetailPanel(
                    key: hudDetailDrawerKey,
                    detail: detail,
                    // 树里是「右栏常驻」，宽壳归整页入口（笔 4）—— 两种形态用同一个
                    // widget，只换紧凑度（`VIEW-017`）。
                    compact: true,
                    onSelectItem: _select,
                    // 没有可退的地方就不给按钮（`VIEW-015`）：`null` 时面板不渲染它。
                    onBack: _canGoBack ? _goBack : null,
                  ),
                ),
              _positioned(
                left: 16,
                top: 16,
                child: _panel(
                  key: hudBreadcrumbKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // ① = 面包屑 · 模式图标 · 放大镜（`VIEW-018` 修订 2）。
                          // 图标**跟面包屑走**，不锚在 ① 的最右：① 的宽度随路径
                          // 长度变，固定锚点会让图标与文字之间长出一段随档位伸缩的
                          // 空白（4 段时约 174 px）。「位置随档位漂移」是规格里写明
                          // 的既定行为，不是缺陷。
                          ..._breadcrumbRow(),
                          _modeIcon(),
                          if (!tree && _camera.zoom == ZoomLevel.z0)
                            _searchIcon(),
                        ],
                      ),
                      // 诊断行：**空画面时先看这一行**。若写「合成」，说明内容包没找到
                      // （运行期 CWD 不在 `app/`），而不是渲染坏了。
                      // 换根后这里跟着换 —— 它是「我现在画的是哪个空间」的唯一出处。
                      Text(
                        '${_scene.origin.label} · ${_scene.itemCount} 项'
                        ' · ${_scene.edgeCount} 边'
                        ' · ${_scene.radialSegments} 段',
                        style: const TextStyle(
                          color: paletteTextSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _positioned(
                right: 16,
                top: 16,
                child: _panel(
                  key: hudScopeSettingsKey,
                  child: const Text(
                    '圈内 · 设置',
                    style: TextStyle(color: paletteTextSecondary, fontSize: 12),
                  ),
                ),
              ),
              // ⑤ 焦点星：树里不渲染 —— 树里「选中行」就是焦点（见文件头表格）。
              // ⚠️ `IgnorePointer`：这是一个**纯占位**，却正好落在屏幕正中。
              // `V-1d` 之前没人发现它会吃点击 —— `Z2` 的云心那一项就在它下面
              // （离画面中心不到 10 px），点上去什么都不发生，而画面上一切正常。
              // 占位不该接住任何手势；将来 ⑤ 真有了内容，它自己带 gesture。
              if (!tree)
                Center(
                  child: IgnorePointer(
                    // 无文字形态（`V-1d2`）—— 理由见 `_hiddenSlot`。
                    child: _hiddenSlot(hudFocusStarKey),
                  ),
                ),
              // ⑥ 六轴罗盘：`VIEW-011` 树里没有方位，保留即成假控件。
              if (!tree) _positioned(left: 16, bottom: 72, child: _compass()),
              // ⑦ **留白**（`VIEW-018` 修订 1）。刻度条已作废：下钻模型下它会
              // 造出「直达某档但容器不明」—— `Z0` 点 `Z2` 该开哪个域？没选过，
              // 没有答案。而面包屑每一段都是实际走过的。
              //
              // 空着而不是塞个占位：占位会被读成「待填的坑」，而这一格不再有
              // 内容要填。`hudZoomScaleKey` 因此是本文件里唯一一个**渲染时不用**
              // 的 key —— 它留着给测试断言「这里空着」。
              // ② 筛选状态栏：**有筛选才出现**（`VIEW-018`），放在 ① 下方。
              if (filtered)
                _positioned(
                  left: 16,
                  // ① 现在是 44 px 的图标行 + 诊断行（见 `_hudTopHeight`）——
                  // 写死 72 会让 ② 压在 ① 的下沿上。
                  top: _hudTopHeight,
                  child: FilterChips(
                    key: hudFilterChipsKey,
                    filter: _axisFilter,
                    matched: visibleIds.length,
                    total: _pack?.items.length,
                    onRemove: _removeFilter,
                    onClear: _clearFilter,
                  ),
                ),
              // 定位浮层盖在最上层：它打开时是模态的，底下的一切都只是参照。
              if (_locating) Positioned.fill(child: _locateLayer()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locateLayer() => LocateOverlay(
    // 换了词就换一个 State：`initialQuery` 只在 `initState` 读一次，靠 key
    // 重建比在浮层里判「这个词和上次不一样」干净。
    key: ValueKey<String?>(_restoreSelector),
    initialQuery: _restoreSelector ?? '',
    pack: _pack,
    // 除当前根以外的其它空间 —— 从 `roots` 推，不由外面传（`R-08` 同族）。
    otherSpaces: _otherPacks(),
    // `VIEW-031` 的作用域：`Z0` 本就是跨空间视角 ⇒ 不限空间；其余档位默认只搜
    // 本空间，浮层顶部给一行「在全部空间中搜索」。
    scopeSpaceId: _camera.zoom == ZoomLevel.z0 ? null : _pack?.space.id,
    domainId: _domainContext(),
    onPick: _applyHit,
    // 类 ②「措辞不同」的邻近候选：点了就是真落点，与命中同一条路径。
    onPickNear: _pickNear,
    onDismiss: _closeLocate,
  );

  /// 定位浮层的域上下文 = **选中项所在的域**（`VIEW-030` ③ / ④ 的分野）。
  ///
  /// 为什么不用档位：档位只说「离得多近」。在 `Z1` 上看着一堆星系、什么都
  /// 没选时，硬说「你在某个域里」会让分诊凭空多出一个 ③，于是把新项塞进
  /// 一个用户并没有在看的域 —— 那比只记一句需求更糟。
  ///
  /// 与 ① 面包屑第 3 段**不同源**：那里读 [`_domainId`]（可以比选中项活得久 ——
  /// 点面包屑第 3 段会清掉选中项而保留域）。这里要的是「用户此刻在看哪一项」，
  /// 选中项一空就必须返回 `null`。
  String? _domainContext() {
    final LoadedPack? pack = _pack;
    final String? id = _selectedItemId;
    if (pack == null || id == null) {
      return null;
    }
    return pack.itemOf(id)?.domainId;
  }

  Widget _universeBody(Set<String>? visibleIds) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      // 视口尺寸要**与 painter 拿到的一致**。用 `constraints` 而不是
      // `context.size`：后者在首帧是 null，而首帧就点是不该崩的。
      final Size window = Size(constraints.maxWidth, constraints.maxHeight);
      // 绘制表面按**物理面积**封顶（`C-33` / `ADR-0002` 修订二）：4K、以及
      // Retina 这类高分屏，都靠这一步把光栅成本拉回基准窗口的量级。
      final ViewportPlan plan = planViewport(
        window.width,
        window.height,
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      final Size surface = Size(plan.surfaceWidth, plan.surfaceHeight);

      // `Z0` 画的是**空间之间**（一个空间一个星系，`VIEW-036`），`Z1` 画的是
      // **一个空间的盘面**（核球 + 两条旋臂 + 域点，`VIEW-037`），`Z2` 起才走
      // 项投影。三者不同源，所以这里先问两次布局：有星系就换几何、有盘就换
      // 几何，都没装出来时（两个 `isEmpty`）退回项场景 —— 那条是诊断路径，
      // 界面上真正要看的是「为什么一个包都没有」。
      final GalaxyLayout galaxies = _camera.zoom == ZoomLevel.z0
          ? layoutGalaxies(roots: widget.roots, viewport: surface)
          : GalaxyLayout.empty;
      final bool galaxyMap = !galaxies.isEmpty;

      // `Z1` 的盘。⚠️ 项在这一档**只是背景**（`VIEW-037`）：照画、不参与拾取 ——
      // 所以下面 `onTapUp` 里没有「点项」这条分支，那是规格要求，不是漏写。
      // 进项走搜索 / 树；`V-1d` / `V-1e` 落地后还有「域 → 恒星系」那条路。
      final SpiralLayout spiral = _camera.zoom == ZoomLevel.z1 && _pack != null
          ? layoutSpiral(
              pack: _pack!,
              viewport: surface,
              visibleIds: visibleIds,
            )
          : SpiralLayout.empty;
      final bool spiralDisc = !spiral.isEmpty;

      // `Z2` 画的是**一个域**：一朵分子云 + 亮结 + 跨域出口（`VIEW-038`）。
      // `Z4` 仍走项投影 —— 单星特写（`VIEW-040`）不在 `B12` 的九笔里，另立一笔。
      final NebulaLayout nebula =
          _camera.zoom == ZoomLevel.z2 && _pack != null && _domainId != null
          ? layoutNebula(
              pack: _pack!,
              domainId: _domainId!,
              viewport: surface,
              visibleIds: visibleIds,
            )
          : NebulaLayout.empty;
      final bool nebulaCloud = !nebula.isEmpty;

      // `Z3` 画的是**一条 `⪯` 链**：一颗恒星 + 共面轨道（`VIEW-039`）。
      // 恒星 = `_selectedItemId` —— `V-1d` 的 `_jumpToKnot()` 落的正是亮结的
      // 子树根，所以这里**不需要第二个「当前子树」状态**（两个状态说同一件事，
      // 迟早有一处忘同步）。
      //
      // 从树 / 搜索直接跳 `Z3` 时 `_selectedItemId` 可能是中间项：它照样当恒星，
      // 行星取它的后继 —— 「先学哪些」这条链从哪一项看都是同一条，只是视角换了。
      final StarSystemLayout starSystem =
          _camera.zoom == ZoomLevel.z3 && _pack != null && _selectedItemId != null
          ? layoutStarSystem(
              pack: _pack!,
              rootId: _selectedItemId!,
              viewport: surface,
              visibleIds: visibleIds,
            )
          : StarSystemLayout.empty;
      final bool starView = !starSystem.isEmpty;

      final Widget canvas = RepaintBoundary(
        // ⚠️ 尺寸必须由 `SizedBox` **强制**给，不能只写 `CustomPaint.size`：
        // `size` 只是 preferred，父级给的 tight 约束会把它推翻 —— 那样绘制按
        // 窗口尺寸画、拾取按画布尺寸算，两边错开。
        child: SizedBox.fromSize(
          key: _canvasKey,
          size: surface,
          child: CustomPaint(
            painter: galaxyMap
                // `Z0` 不接 `spin`：盘自转 `C-54` 与构型公转 `C-55` 归 `V-1i`，
                // 这一笔只画形态。接了会让一片不动的画面每帧重绘，帧预算读数
                // 会凭空多出一档成本。
                ? GalaxyPainter(layout: galaxies)
                // `Z1` 同理：盘自转 `C-54` 与减速停转 `C-57` 归 `V-1i`。
                : spiralDisc
                ? SpiralPainter(layout: spiral)
                // `Z2` 也一样 —— 云的整体自转归 `V-1i`（`VIEW-038`：亮结无
                // 独立轨道，只随盘整体转）。
                : nebulaCloud
                ? NebulaPainter(layout: nebula)
                // `Z3` 同样不接 `spin`：行星公转 `C-56` 归 `V-1i`。这是全项目
                // **唯一**一条真正的公转（绕的是另一个天体），接上时要改的是
                // 相位推进，不是重画几何 —— 相位方向已经排好了。
                : starView
                ? StarPainter(layout: starSystem)
                : FramePainter(
                    scene: _scene,
                    spin: _spin,
                    baseYaw: _camera.yawRadians,
                    visibleIds: visibleIds,
                    onRepaint: (_, _, _) {},
                  ),
          ),
        ),
      );

      // ⚠️ 外层 `SizedBox` 不是多余：`AnimatedSwitcher` 的 `Stack` 给的是
      // **loose 约束**，`FittedBox` 在 loose 下只会「保持比例地缩到装得下」——
      // 于是画布停在 554×416、居中显示，四周留底，降采样后的放大根本没发生
      // （实测画布盒在窗口里居中，点击坐标整体偏 (123, 92)）。
      // 给它一个 tight 的窗口尺寸，`BoxFit.fill` 才会把它铺满。
      return SizedBox.fromSize(
        size: window,
        child: GestureDetector(
          // `opaque`：空白处也要接住点击，否则点在星与星的缝里会穿透到底下。
          behavior: HitTestBehavior.opaque,
          // ⚠️ **不能用 `details.localPosition`**。它相对的是「手势命中的那个
          // RenderBox」，而 `FittedBox` 下不保证落在画布盒上。把全局坐标显式
          // 映到画布盒，不依赖命中路径怎么走。
          onTapUp: (TapUpDetails details) {
            final RenderBox? box =
                _canvasKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null || !box.hasSize) {
              return;
            }
            final Offset point = box.globalToLocal(details.globalPosition);
            if (galaxyMap) {
              _pickGalaxyAt(point, galaxies);
            } else if (spiralDisc) {
              _pickDomainAt(point, spiral);
            } else if (nebulaCloud) {
              _pickNebulaAt(point, nebula);
            } else if (starView) {
              _pickStarAt(point, starSystem);
            } else {
              _pickAt(point, surface, visibleIds);
            }
          },
          // `FittedBox` 只在真降了分辨率时才包一层：`scale == 1` 时它是纯开销，
          // 而宇宙每帧都在重绘。四档共用 [_withLayer] —— 逐档抄一份 `Stack`
          // 的话，改「标注不接手势」时要记得改四处（`R-08`：形状挡得住改、
          // 挡不住加）。
          child: galaxyMap
              ? _withLayer(canvas, plan, _galaxyLayer(galaxies, surface, window))
              : spiralDisc
              ? _withLayer(canvas, plan, _domainLayer(spiral, surface, window))
              : nebulaCloud
              ? _withLayer(canvas, plan, _nebulaLayer(nebula, surface, window))
              : starView
              ? _withLayer(canvas, plan, _starLayer(starSystem, surface, window))
              : (plan.isDownscaled
                    ? FittedBox(fit: BoxFit.fill, child: canvas)
                    : canvas),
        ),
      );
    },
  );

  Widget _treeBody(bool filtered) => Padding(
    padding: EdgeInsets.only(
      // 右栏是浮层（`hudDetailDrawerKey`），树要给它让位，否则末端的 φ 标签被盖住。
      right: _drawerReserve,
      // ① 常显 ⇒ 树永远从它下面开始；② 出现时再让一行。两个数都从常量来：
      // ① 的高度若在两处各写一个数，改一处忘一处不会有任何东西变红（`R-08`）。
      top: _hudTopHeight + (filtered ? _filterRowHeight : 0),
    ),
    child: TreeView(
      pack: _pack,
      selectedItemId: _selectedItemId,
      visibleIds: _visibleIds(),
      onSelect: _select,
    ),
  );

  // ── ① 面包屑与图标（`VIEW-018` 修订 2） ─────────────────────────────────

  /// 面包屑的段与分隔符。
  ///
  /// 每段单独成 widget 而不是拼一整个字符串：`知识 › English` 作为一条文本
  /// 没法让「前段可点、末段不可」，而那正是这一行唯一的行为。
  List<Widget> _breadcrumbRow() {
    final List<_Crumb> crumbs = _crumbs();
    return <Widget>[
      for (int i = 0; i < crumbs.length; i++) ...<Widget>[
        if (i > 0)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '\u203a',
              style: TextStyle(
                color: paletteTextSecondary,
                fontSize: _crumbFontSize,
              ),
            ),
          ),
        _crumbWidget(i, crumbs[i]),
      ],
    ];
  }

  /// 当前位置的路径（`VIEW-018` 修订 2）。段数 = 走到第几层。
  ///
  /// | 档 | 段 | 内容 |
  /// |---|---|---|
  /// | `Z0` | 1 | `知识` |
  /// | `Z1` | 2 | + 空间 |
  /// | `Z2` | 3 | + 域 |
  /// | `Z3` / `Z4` | 4 | + 项（`VIEW-001`：两者同形，区分靠抽屉） |
  ///
  /// **少一段就是「这一层还没有确定的对象」**：不补占位、不猜名字。`Z2` 只有
  /// 在真进过某个域之后才有第 3 段；合成回落没有空间名，永远只有第 1 段。
  List<_Crumb> _crumbs() {
    final List<_Crumb> raw = _rawCrumbs();
    // **末段一律抹掉 `level`** —— `VIEW-018` 修订 2 的「末段不可点」。
    // 不抹的话，`Z1` 的「空间」段会同时是「第 2 段」与「可点」：点它等于原地
    // 不动，而且测试里「末段没有 key」这条判据直接失效（`_crumbCount` 会多算
    // 一段，所有段数断言一起偏 1）。
    return <_Crumb>[...raw.take(raw.length - 1), _Crumb(raw.last.label)];
  }

  /// 未标末段的原始路径 —— 每一段都带着「点了退到哪一档」。
  List<_Crumb> _rawCrumbs() {
    final LoadedPack? pack = _pack;
    final List<_Crumb> crumbs = <_Crumb>[
      const _Crumb('知识', level: ZoomLevel.z0),
    ];
    if (pack == null) {
      // 合成回落的根背后没有 `KnowledgeSpace` —— 没有名字可写，就只写位置。
      return crumbs;
    }
    final bool tree = _mode == ViewMode.tree;
    // `Z0` 是宇宙层：并列的是全部空间，没有「进去了哪一个」这回事。
    if (!tree && _camera.zoom == ZoomLevel.z0) {
      return crumbs;
    }
    crumbs.add(_Crumb(_spaceLabel(pack.space.id), level: ZoomLevel.z1));
    if (_domainId == null || (!tree && _camera.zoom == ZoomLevel.z1)) {
      return crumbs;
    }
    // ⚠️ 第 3 段显示的是 `domainId`，不是中文域名：包里**没有** Domain 实体，
    // 域只有 `Item.domainId` 与 `KnowledgeSpace.domainIds` 两个字符串字段。
    // `VIEW-018` 的例子写「`词法形态`」，那是数据里不存在的名字 —— 等包格式补
    // `domains` 段再换（属 PACK 域修订，本笔不假造一个）。
    crumbs.add(_Crumb(_domainId!, level: ZoomLevel.z2));
    final Item? item = _selectedItem();
    if (item == null) {
      return crumbs;
    }
    // `Z2` 的形态是「一朵云」，不是某一项 ⇒ 第 3 段就是末段。
    if (!tree && _camera.zoom == ZoomLevel.z2) {
      return crumbs;
    }
    crumbs.add(_Crumb(item.title));
    return crumbs;
  }

  /// 一段面包屑。**末段没有 key** —— 它是纯文字，点了没有去处。
  Widget _crumbWidget(int index, _Crumb crumb) {
    final Widget label = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _crumbMaxWidth),
      child: Text(
        crumb.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: crumb.level == null
              ? paletteTextPrimary
              : paletteTextSecondary,
          fontSize: _crumbFontSize,
        ),
      ),
    );
    if (crumb.level == null) {
      return label;
    }
    return TextButton(
      key: hudCrumbKey(index),
      onPressed: () => _toLevel(crumb.level!),
      style: TextButton.styleFrom(
        // 24 px 是项目的最小可点尺寸；再矮就得靠「文字恰好够长」凑命中。
        minimumSize: const Size(0, 24),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: paletteTextSecondary,
      ),
      child: label,
    );
  }

  /// 空间的显示名：`space.id` 首字母大写（`VIEW-036` 的标注口径）。
  ///
  /// 不用 `space.name`：三个包的 `name` 是「Python 语法分层 / 英语语法分层 /
  /// 德语语法分层」，四段面包屑里再塞这种长度就要换行；而 id 就是包目录名，
  /// 用户核对得上的也正是它。
  String _spaceLabel(String id) =>
      id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);

  /// 模式图标（`VIEW-018` 修订 2）：14 px 图形、44 px 命中盒。
  ///
  /// 图上画的是**当前**模式而不是目标：① 的职责是「我在哪」。画目标的话，同一个
  /// 图标在宇宙里叫「树」、在树里叫「宇宙」，读起来像两个不同的按钮。
  Widget _modeIcon() => SizedBox(
    key: hudModeSwitchKey,
    width: _hudIconHit,
    height: _hudIconHit,
    child: InkResponse(
      key: hudModeIconKey,
      onTap: _toggleMode,
      radius: _hudIconHit / 2,
      child: Icon(
        _mode == ViewMode.tree ? Icons.account_tree : Icons.public,
        size: _hudIconSize,
        color: paletteTextSecondary,
      ),
    ),
  );

  /// `Z0` 的放大镜（`VIEW-018` 修订 2）。
  ///
  /// 只给 `Z0`：那一档不出项 ⇒ 搜索是进 `Z4` 的唯一通路，不给入口等于只有出口
  /// 没有入口（触屏设备没有 `⌘K`）。
  Widget _searchIcon() => SizedBox(
    key: hudSearchKey,
    width: _hudIconHit,
    height: _hudIconHit,
    child: InkResponse(
      onTap: _openLocate,
      radius: _hudIconHit / 2,
      child: const Icon(
        Icons.search,
        size: _hudIconSize,
        color: paletteTextSecondary,
      ),
    ),
  );

  void _toggleMode() =>
      _switchMode(_mode == ViewMode.tree ? ViewMode.universe : ViewMode.tree);

  Item? _selectedItem() => _pack?.itemOf(_selectedItemId ?? '');

  // ── ⑥ 罗盘的渲染 ────────────────────────────────────────────────────────

  /// ⑥ = **输入器**（`VIEW-019`）：六个轴名 → 就地展开取值 → 点一次选、再点取消。
  ///
  /// 不做「点 ⑥ 唤起 ② 再在 ② 上选」：`VIEW-020` 明确否掉了那条路 ——
  /// 六个轴各 5–8 个值，本来是一屏装得下的短选择，变成两处往返之后就没人用了。
  Widget _compass() {
    final LoadedPack? pack = _pack;
    final String? openAxis = _compassAxis;
    return ConstrainedBox(
      // 下限 + 上限，中间由内容撑开：空状态 236（六轴一行最窄），两个轴同时筛
      // 时自己长到 263.9 —— 写死任一常数都会在另一个状态下难看。
      constraints: const BoxConstraints(
        minWidth: _compassMinWidth,
        maxWidth: _compassMaxWidth,
      ),
      child: _panel(
        key: hudAxisCompassKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              // 没有包就没有轴值可选。写清原因而不是给一排按不动的按钮 ——
              // 按不动的控件会被读成「功能坏了」。
              pack == null ? '六轴罗盘 · 没有内容包' : '六轴罗盘',
              style: const TextStyle(color: paletteTextSecondary, fontSize: 10),
            ),
            if (pack != null) ...<Widget>[
              const SizedBox(height: 4),
              Wrap(
                spacing: 1,
                runSpacing: 2,
                children: <Widget>[
                  for (final String axisKey in sixAxisKeys)
                    _compassAxisChip(axisKey),
                ],
              ),
              if (openAxis != null) ...<Widget>[
                const Divider(height: 14, color: paletteLine),
                _compassValues(pack, openAxis),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 一个轴按钮。带「·N」= 这个轴已选了多少个值（`VIEW-019` 要求不看 ②
  /// 也知道自己筛了什么 —— ② 会被滚出视线的场景就是「筛完继续看星」）。
  Widget _compassAxisChip(String axisKey) {
    final int count = (_axisFilter[axisKey] ?? const <String>[]).length;
    final bool open = _compassAxis == axisKey;
    return TextButton(
      key: compassAxisKey(axisKey),
      onPressed: () => _toggleCompassAxis(axisKey),
      style: TextButton.styleFrom(
        backgroundColor: open ? paletteSelected : null,
        foregroundColor: count > 0 ? paletteTextPrimary : paletteTextSecondary,
        minimumSize: const Size(0, 26),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        count > 0
            ? '${sixAxisLabels[axisKey] ?? axisKey} ·$count'
            : sixAxisLabels[axisKey] ?? axisKey,
        // 轴名很短，任何折行都只发生在「这个按钮自己断了」的坏情形里 ——
        // 那种折行比换行更难看，且没有任何信息上的必要。
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  /// 展开后的取值列表。取值域来自包（`axisValuesOf`），**不写死任何选项**：
  /// 换个包就是另一批值，预设选项在第二个包上立刻过时。
  Widget _compassValues(LoadedPack pack, String axisKey) {
    final List<String> values = axisValuesOf(pack, axisKey);
    final List<String> selected = _axisFilter[axisKey] ?? const <String>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${sixAxisLabels[axisKey] ?? axisKey} · 再点一次取消',
          style: const TextStyle(color: paletteTextSecondary, fontSize: 10),
        ),
        const SizedBox(height: 2),
        if (values.isEmpty)
          const Text(
            '这一轴在包里没有取值',
            style: TextStyle(color: paletteTextSecondary, fontSize: 11),
          )
        else
          ConstrainedBox(
            // 上限 + 滚动，而不是 `Flexible`：外层是 `mainAxisSize.min` 的
            // `Column`，`Flexible` 在那里会拿到 0 高度（笔 4a 踩过）。
            constraints: const BoxConstraints(
              maxHeight: _compassValuesMaxHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final String value in values)
                    _compassValueRow(axisKey, value, selected.contains(value)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _compassValueRow(String axisKey, String value, bool selected) {
    return InkWell(
      key: compassValueKey(axisKey, value),
      onTap: () => _toggleCompassValue(axisKey, value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 13,
              color: selected ? paletteTextPrimary : paletteTextSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? paletteTextPrimary : paletteTextSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positioned({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required Widget child,
  }) => Positioned(
    left: left,
    right: right,
    top: top,
    bottom: bottom,
    child: child,
  );

  Widget _panel({Key? key, required Widget child}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: palettePanel,
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );

  /// 占位槽：本笔不实现内容，但**保留可见的落位**（否则七区块的规则无从测起）。
  /// 一个「有槽但没有内容」的占位。
  ///
  /// `label` 为 `null` 时渲染成**零尺寸**（`V-1d2`）：⑤ 的位置正是屏幕正中，
  /// 而 `Z1` 的核球、`Z2` 的云心也在那里 —— 「焦点星」三个字压在上面，读者会
  /// 把它读成一个域名（终端截图里被当成「核球旁一处叠字」，查了半天才发现是
  /// 这个占位）。占位不需要被看见，但**需要有个槽**：`key` 留着，`VIEW-018`
  /// 的「这里有个格子」照样可断言。
  Widget _hiddenSlot(Key key, [String? label]) {
    if (label == null) {
      return SizedBox.shrink(key: key);
    }
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        label,
        style: const TextStyle(color: paletteTextSecondary, fontSize: 10),
      ),
    );
  }
}

/// `Z2` 标注层的载荷：亮结。
///
/// 用两个私有类而不是让调用方按 `key.startsWith('exit:')` 反解 —— 「前缀即类型」
/// 是 `R-08` 要消掉的那类约定：写错前缀不会有任何东西变红，只会静默落到默认
/// 分支上（而那一段恰好是 `const SizedBox.shrink()`，看起来一切正常）。
class _KnotLabel {
  const _KnotLabel(this.knot);

  final NebulaKnot knot;
}

/// `Z2` 标注层的载荷：跨域出口。
class _ExitLabel {
  const _ExitLabel(this.exit);

  final NebulaExit exit;
}

/// 面包屑的一段（`VIEW-018` 修订 2）。
///
/// `level == null` = **末段**：当前位置本身，渲染成纯文字。拿它当「不可点」的
/// 唯一判据（而不是另存一个 `bool last`），是因为两条判据迟早会出现「level 有值
/// 但 last 也是 true」的中间态 —— 那时画出来是可点按钮、语义却是末段。
class _Crumb {
  const _Crumb(this.label, {this.level});

  final String label;

  /// 点它退到哪一档。`null` = 不可点。
  final ZoomLevel? level;
}

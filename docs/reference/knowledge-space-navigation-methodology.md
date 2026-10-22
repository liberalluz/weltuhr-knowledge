# 知识空间导航方法论

> ——宇宙↔知识映射体系  
> 版本 v1.2 ｜ 2026-10-20 ｜ 来源：2026-10-19/20 连续讨论沉淀 + 2026-10-20 勘误修订  
> 状态：文献表双轨（§11 功能分类版 + §12 文献格式版）；§9 待核实项已办结  
>
> **与 ADR 的分工**：本文是**论证与依据**（为什么是三条轴、为什么七级、锚点质量如何），
> 结论落成决策的是 [`ADR-0005`](../decisions/0005-three-axis-tree-replaces-six-axis.md)（三轴容器树取代六轴）、
> [`ADR-0006`](../decisions/0006-3d-rendering-stack-and-visual-style.md)（3D 渲染栈与视觉风格）、
> [`ADR-0007`](../decisions/0007-node-type-shape.md)（`Node` 的类型形态）。
> 两者冲突时**以 ADR 为准**：本文可继续演进，地基本文不承载。



---

## 目录

1. 核心命题
2. 三层总模型
3. 知识分类的 16 个维度
4. 定位三元组：学科 / 专业 / 角色
5. 宇宙映射：倒置宇宙树
6. 从坐标到路径：地形模型
7. 学习路径设计
8. 边界与已知失效
9. 已核实项（原待核实项，2026-10-20 办结）
10. 术语表
11. 参考核心
12. 参考文献

---

## 1. 核心命题

知识空间与宇宙空间存在**结构同构**：知识分类体系可以组织成一棵「倒置的宇宙树」——从根（知识整体）逐级下钻，经超星系团、星系群、星系，最终到达恒星（如「人工智能」）。

本方法论回答三个问题：

1. **定位**：一个知识对象在空间里哪一格（§4）
2. **走路**：从当前位置怎么一步步走到它（§5–§6）
3. **设计**：学到什么程度、按什么顺序、怎么算会（§7）

一句话总纲：**坐标靠星表，走路靠地形，裁剪靠目标，验证靠出口。**

---

## 2. 三层总模型

| 层   | 回答什么 | 交付物                  |
| --- | ---- | -------------------- |
| 坐标系 | 它在哪  | 三元组坐标（学科/专业/角色）      |
| 地形  | 怎么到  | 依赖图（先修边 + 引用边 + 重组边） |
| 路径  | 学什么  | 裁剪后的学习链              |

三层不可互相替代：

- 只有坐标没有路 = 查了星表不发射望远镜；
- 只有路没有坐标 = 走到了却说不出在哪。

---

## 3. 知识分类的 16 个维度

| 组    | 维度          | 一级划分类别                                      |
| ---- | ----------- | ------------------------------------------- |
| A 内容 | A1 领域/对象    | 人文 · 社科 · 自然科学 · 形式科学 · 专业与应用               |
| A 内容 | A2 陈述类型     | 描述性 / 规范性 / 程序性                             |
| A 内容 | A3 内容层级     | DIKW：数据→信息→知识→智慧；事实/概念/程序/元认知               |
| B 形式 | B1 命题结构     | 命题性（know-that）/ 非命题性（know-how、acquaintance） |
| B 形式 | B2 表征性质     | 陈述性（declarative）/ 程序性（procedural）           |
| B 形式 | B3 显性程度     | 显性 / 隐性                                     |
| B 形式 | B4 载体媒介     | 文字 / 数学符号 / 图像 / 身体化 / 参数化（模型权重）            |
| C 来源 | C1 认识论来源    | 先验 / 后验                                     |
| C 来源 | C2 社会证成状态   | 科学共识 / 常识 / 民间 / 本土 / 信念                    |
| D 主体 | D1 归属       | 个人 / 组织 / 社会（Popper World 3）                |
| E 制度 | **E1 建制层级** | **学科 / 专业 / 角色**（定位专用轴）                     |
| F 功能 | F1 用途口径     | know-what / why / how / who / when          |
| F 功能 | F2 理论-应用    | 硬/软 × 纯/应用                                  |
| F 功能 | F3 认知操作     | 记忆→理解→应用→分析→评价→创造（Bloom）                    |
| G 状态 | G1 可靠度      | 知识 / 信念 / 意见；确定 / 概率 / 未决                   |
| G 状态 | G2 时间成熟度    | 教科书知识 / 前沿知识                                |

注意：16 轴并非严格正交（B3 与组织维度、G1 与 C2 有重叠）；学界共识是「按轴切分、一次一个轴」。

---

## 4. 定位三元组：学科 / 专业 / 角色

> 初版为「学科/专业/职业/领域」四分，收敛为三元组：删「领域」（wiki 中仅为学科同义泛称，无编目无谱系）；「职业→角色」（Stichweh 1992 原文用词为 roles；职业只是角色中建制化程度最高的一支）。

### 4.1 三轴定义与现成星表

| 轴      | 回答的问题       | 中国官方编目                                                    | 国际编目          |
| ------ | ----------- | --------------------------------------------------------- | ------------- |
| **学科** | 知识本身怎么分     | 《研究生教育学科专业目录（2022）》（14 门类 · 117 一级学科）                     | ISCED-F       |
| **专业** | 知识怎么组装传授    | 《本科专业目录（2025）》（12 门类 · 93 专业类 · 845 专业，年度更新）              | CIP、ISCED-P   |
| **角色** | 知识被谁在什么分工里用 | 《职业分类大典（2022）》（8 大类 · 79 中类 · 449 小类 · 1636 职业 · 2967 工种） | ISCO-08、O*NET |

「编目」= 分级 + 编号 + 边界裁决权的法定目录；引用必须注明出自哪份编目（口径打架是常态，如心理学在中美分属不同门类）。

### 4.2 三轴锚点质量总览

| 轴  | wiki 锚点              | 官方编目                   | 学术谱系            | 锚点特征           |
| -- | -------------------- | ---------------------- | --------------- | -------------- |
| 学科 | 强（专条 + 三个类目）         | 中（教育侧目录）               | 强（科学社会学）        | 学科树以百年计变动      |
| 专业 | 弱（仅一条薄条目）            | **最强**（中美双编目 + UNESCO） | 中（高等教育研究）       | 建制最强、概念最浅，年年增删 |
| 角色 | 强（角色理论 + profession） | 强（ILO + 人社部）           | 强（角色理论 + 专业社会学） | 实操坐标最细，到任务级    |

一个佐证：Stichweh 1992 摘要原文即写学科从 **established professions（法/医/神学）**&#x4E2D;分化、并形成 **"appropriate" roles**——「职业→角色」的改动不是硬拗，是建制命题源头的用词。

### 4.3 分轴文献清单（按关联度）

> 排序口径：对「定位」的直接贡献——编目 > wiki 锚点 > 学术 > 论文；边界争议类文献置后。

#### 4.3.1 学科

| #  | 类型   | 来源                                                                                            | 提供了什么                                                       |
| -- | ---- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| 1  | wiki | *Academic discipline*                                                                         | 定义入口；条目内即引 Stichweh、Becher、Foucault、Gibbons                 |
| 2  | wiki | *Outline of academic disciplines* / *List of academic fields* / Category:Academic disciplines | 学科树三视图（总览/清单/分类轴），可当星表直接用                                   |
| 3  | 编目   | 《研究生教育学科专业目录（2022年）》14 门类、117 个一级学科                                                           | 中国官方学科坐标（国务院学位委员会）                                          |
| 4  | 编目   | UNESCO ISCED-F（2013，11 个宽领域）                                                                  | 教育侧全球学科坐标，跨国检索统一入口                                          |
| 5  | 学术   | **Stichweh 1992**，*The Sociology of Scientific Disciplines*，Science in Context 5(1):3–15      | 权威定义：学科=认知分化的社会建制形式；建制概念总源头                                 |
| 6  | 学术   | Becher 1989，*Academic Tribes and Territories*                                                 | 建制边界三判据：codification / acceptance by consent / teachability |
| 7  | 学术   | Whitley 1984，*The Intellectual and Social Organization of the Sciences*                       | 学科间差异 = 任务不确定性结构                                            |
| 8  | 学术   | Gibbons et al. 1994，*The New Production of Knowledge*                                         | Mode 2：学科边界被侵蚀——交叉领域定位的理论依据                                 |
| 9  | 学术   | Foucault 1975/1969                                                                            | discipline 的知识-权力双关（wiki 的批判引用源）                            |
| 10 | 论文   | Krishnan 2009，*What are academic disciplines?*                                                | 定义综述，快速校准「学科/跨学科」口径                                         |

#### 4.3.2 专业

| #  | 类型   | 来源                                                                                      | 提供了什么                                                        |
| -- | ---- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| 1  | 编目   | **《普通高等学校本科专业目录（2025年）》**：12 门类、93 专业类、845 种专业                                          | 中国专业星表；教育部已确立**年度更新机制**（2024 年度新增 1839、撤销 1428、停招 2220 个专业点） |
| 2  | 编目   | 美国 CIP 2020（NCES，2/4/6 位编码）                                                             | 全球编码化程度最高的专业坐标                                               |
| 3  | 编目   | ISCED-P（UNESCO 项目分类）                                                                    | 教育项目层坐标，与专业互译                                                |
| 4  | wiki | *Academic major*                                                                        | 定义入口（major = 教学项目/课程组合）                                      |
| 5  | wiki | *ISCED* / *Classification of Instructional Programs*                                    | 编目制度的 wiki 侧说明                                               |
| 6  | 学术   | Stark & Lattuca 1997，*Shaping the College Curriculum*                                   | academic plan：专业的结构定义                                        |
| 7  | 学术   | Trow 1973，*Problems in the Transition from Elite to Mass Higher Education*              | 大众化→专业增殖：目录年年变的根因                                            |
| 8  | 学术   | Birnbaum 1983，*Maintaining Diversity in Higher Education*                               | 专业多样化/增殖机制                                                   |
| 9  | 论文   | Brint, Cantwell & Hanneman 2008，*The Two Cultures of Undergraduate Academic Engagement* | 学术型 vs 实践型专业的实证二分                                            |
| 10 | 论文   | 教育部年度本科专业调整公告                                                                           | 「专业星表持续重绘」的实证——验证专业≠学科                                       |

#### 4.3.3 角色

| #  | 类型   | 来源                                                                                 | 提供了什么                                |
| -- | ---- | ---------------------------------------------------------------------------------- | ------------------------------------ |
| 1  | 编目   | **ILO ISCO-08**                                                                    | 全球职业坐标（现行版）                          |
| 2  | 编目   | **《职业分类大典（2022年版）》**：8 大类 · 79 中类 · 449 小类 · 1636 个职业，标注 97 个数字职业、134 个绿色职业        | 中国职业坐标（人社部）                          |
| 3  | 编目   | 岗位 JD / 胜任力模型；**O*NET**（美国劳工部，occupation ↔ knowledge/skills 直接挂接）                  | 任务级最细坐标；「角色→知识」定位的现成桥梁               |
| 4  | wiki | *Role theory* / *Social role*                                                      | 角色概念的 wiki 入口（status-role 框架）        |
| 5  | wiki | *Profession* / *Occupation*                                                        | profession = 高门槛角色的子类；occupation 是上位 |
| 6  | 学术   | Linton 1936，*The Study of Man*                                                     | status/role 区分——「角色」一词的学术源头          |
| 7  | 学术   | Merton 1957，"The Role-Set Problem"                                                 | role-set / 角色冲突概念                    |
| 8  | 学术   | Abbott 1988，*The System of Professions*                                            | 管辖权竞争：JD 边界争夺的理论解释                   |
| 9  | 学术   | Freidson 2001，*Professionalism: The Third Logic*                                   | 专业角色自主性（第三种逻辑）                       |
| 10 | 论文   | Biddle 1986（*Annual Review of Sociology*）；Kahn et al. 1964，*Organizational Stress* | 角色理论总综述；role conflict/ambiguity 经典实证 |

#### 4.3.4 三条使用提示

1. **按轴选源，不混用**：查坐标用编目（专业→MOE/CIP，角色→ISCO/大典，学科→学科目录），校准边界用 wiki，处理「这个领域到底归哪」的争议才翻学术文献——百科式全读是定位里最慢的走法。
2. **两个可操作的交叉校准工具**：O*NET 把角色坐标与知识/技能描述直接打通（做「角色→学什么」定位时最省力）；Wikidata 有 academic discipline / academic major / occupation 三个独立类目，可用 SPARQL 量化三轴重叠度。
3. **不对称性要记住**：「专业」是三轴中建制最强、概念最浅的一轴——它没有独立的概念史，它的「学术」其实是高等教育研究/课程研究；这恰好解释了为什么专业目录年年重绘而学科树百年不变。

### 4.4 三轴关系：三张网，M:N 缝合（非独立、非包含）

| 关系对     | 密度 | 性质          |
| ------- | -- | ----------- |
| 专业 ↔ 角色 | 最高 | 培养入口 ↔ 劳动出口 |
| 学科 ↔ 专业 | 高  | 知识供给 ↔ 培养组装 |
| 学科 ↔ 角色 | 中低 | 多数间接、常断连    |

**实证**（人工智能）：专业网 2003 试办智能科学与技术、2018 批 080717T（首批 35 所）；角色网 2020 才收录「人工智能训练师」；学科网至今无一级学科身份（教育部口径仍是「推动一级学科建设」）。同一对象三张网三个时点——交叉关系是**持续漂移的缝合**，不是固定矩阵。

### 4.5 覆盖边界与兜底

E1 覆盖「成建制知识」约 95%；四类星表外对象：

| 类型    | 例子                  |
| ----- | ------------------- |
| 目录滞后区 | LLM 类技能 2022 前无职业坐标 |
| 交叉模糊区 | 生物信息学归位不一           |
| 建制外   | 公司 know-how、师徒手艺    |
| 隐性核心  | 手感、直觉（Polanyi 1966） |

兜底三步：nearest-discipline 双坐标 → 类比坐标 → DACUM 自建坐标。

---

## 5. 宇宙映射：倒置宇宙树

### 5.1 三版演进

| 版            | 形态                                   | 缺陷         |
| ------------ | ------------------------------------ | ---------- |
| v1 类比字典      | 星系≈学科、星座≈专业、暗物质≈隐性知识                 | 修辞级，无操作    |
| v2 三轴映射      | 自然引力层级=学科 / IAU 人为星表=专业 / 物质循环功能态=角色 | 平铺账本，没有「路」 |
| **v3 倒置宇宙树** | 七级同构树，逐级下钻                           | **现行版**    |

### 5.2 七级同构表（现行结构）

| 宇宙层级     | 学科树                    | 专业树      | 角色树               |
| -------- | ---------------------- | -------- | ----------------- |
| 可观测宇宙（根） | 知识整体                   | 知识整体     | 知识整体              |
| **超星系团** | 学科                     | 专业       | 角色                |
| **星系群**  | 学科门类（研究生目录 14；本科口径 12） | 学科门类（12） | 职业大类（8）           |
| **星系**   | 一级学科（117）              | 专业类（93）  | 职业中类（79）/ 小类（449） |
| **恒星**   | 二级学科/研究方向              | 专业（845）  | 职业（1636）          |
| **行星系**  | 课程/教材体系                | 培养方案     | 岗位任务包（JD）         |
| **行星**   | 知识点                    | 知识点      | 技能项               |

原则：**恒星 = 目录里最细的正式条目**（有编号、可独立寻址）；行星系/行星两级由培养方案/JD/教材大纲填充（半民间数据）。

### 5.3 AI 实例：一对象三地址

| 树   | 路径                                                                                   | 说明                                            |
| --- | ------------------------------------------------------------------------------------ | --------------------------------------------- |
| 学科树 | 学科 › 工学 › 计算机科学与技术 › 人工智能（方向恒星）                                                      | 未获批一级学科，长在 CS 星系内                             |
| 专业树 | 专业 › 工学 › **电子信息类** › 人工智能 080717T                                                   | 归类与知识亲缘错位（亲缘在计算机类 0809，080907T 智能科学与技术归 0809） |
| 角色树 | 角色 › 大类 4 社会生产服务和生活服务人员 › 中类 4-04 › 小类 4-04-05 › 人工智能训练师 4-04-05-05（2020 新职业，数字职业 S） | 编外→收录的典型                                      |

**门牌不一致不是 bug**，是编目口径差；导航上显示为「一个对象、三个地址」，正是三元组模型的卖点。

### 5.4 接口四件套

| 件    | 设计                                                |
| ---- | ------------------------------------------------- |
| 寻址协议 | 节点 = 官方编号（080717T、学科代码、大典代码）+ 名称；路径 = 编号序列，可跨系统引用 |
| 导航交互 | 面包屑下钻 + 同级横移（恒星际）+ 就地展开（悬停展开恒星列表）+ 跨枝虫洞（三地址互跳）    |
| 虫洞边  | 一个 M:N 映射表把同一对象的三个树地址连起来——旧「三张网」模型不废弃，降级为跨枝跳转边    |
| 数据分层 | 上半段（根→恒星）= 官方编目，权威稳定；下半段（行星系/行星）= 培养方案/JD/教材      |

### 5.5 三边界（实现前必须知道）

1. **树形装不下交叉**：AI 横跨 CS/数学/电子，跨星系依赖只能靠虫洞边——**骨架是树，缝合是网**；
2. **一对象三地址且门牌不一致**（见 5.3）；
3. **编外恒星**：编目年度更新 vs 知识日新月异，新技能先用兜底坐标挂着。

---

## 6. 从坐标到路径：地形模型

### 6.1 星表 vs 地形

编目（学科目录/专业目录/ISCO/IAU 星座表）是**星表**：回答「归谁管、在哪一格」，但任意两格之间没有「步」的定义。能走的空间必须是**图**：节点 = 知识单元，边 = 合法的一步。

### 6.2 三种合法边

| 边           | 定义           | 例子                    |
| ----------- | ------------ | --------------------- |
| **先修边**（最硬） | 会 B 必须先会 A   | 线代→机器学习；Python→框架调参   |
| 引用/共现边      | 论文、概念、章节引证网络 | Transformer→BERT/GPT  |
| 重组边         | A×B 组合出新领域   | 数学×工程→深度学习；语言学×统计→NLP |

（下钻/上卷边只是放大镜，不是「走」。）

### 6.3 城门模型（走到 AI 的实例）

- 两条官道汇入一座城门：**数学官道**（微积分→线代→概率统计→机器学习）+ **工程官道**（Python→数据结构→框架与科学计算→训练调参）→ **城门 = 深度学习（共同先修集合）**；
- 进城之后 NLP/CV/RL 是城内街道，各有二级先修；
- **AI 是区域不是单点**；没有直达路，断边处只能补课不能硬闯；
- 四步操作：诚实标当前位置 → 选最近官道 → 沿边走 + 每节点出口验证 → 卡住 = 缺前置边，掉头补链。

---

## 7. 学习路径设计

### 7.1 维度分工

| 阶段 | 用哪个维度           | 动作                                        |
| -- | --------------- | ----------------------------------------- |
| 入口 | **F1 用途**（为什么学） | 写清目标，定 what/why/how 配比                    |
| 主干 | **A3 知识类型**     | 先陈述性、后程序性、再元认知（Anderson 1982：陈述性→程序化→自动化） |
| 定位 | **E1 三元组**      | 三问：哪个学科？挂哪个专业？服务哪个角色？                     |
| 选材 | **G2 时间成熟度**    | core 用教科书/经典，速变层（AI 前沿）用论文                |
| 验证 | **B2 表征性质**     | 会做题 ≠ 会做（Ryle 1945）；技能看表现标准               |

### 7.2 学科路线 vs 技能路线（混合目标按 F1 定配比，不混排）

| 环节 | 学科知识（命题性）     | 技能知识（程序性）                           |
| -- | ------------- | ----------------------------------- |
| 入口 | F1 用途         | 任务清单（DACUM/岗位 JD）                   |
| 定位 | 目录/wiki 坐标    | 技能树（子技能依赖 DAG）                      |
| 路径 | syllabus/培养方案 | 刻意练习环（Fitts & Posner 三阶段：认知→联结→自动化） |
| 瓶颈 | 理解力           | **高质量反馈**（教练/搭子/评审）                 |
| 验证 | 说得清、考得好       | 做得出、快且稳                             |

技能路线同样可以「按维度定位」——但坐标源要从学科星表换成**职业/技能星表**（国家职业技能标准、1+X、O*NET），再下钻 DACUM 任务清单补粒度。

### 7.3 规划四步流水线（三条链分时上场）

```
① 角色链定用途 → 目标角色 + 3~5 条「学会后能做的事」
② 专业链取路径 → 培养方案骨架，按 ① 砍分支
③ 学科链定深度 → 每块标四档：会用/理解原理/能手推/专家
④ 回角色链验出口 → 作品/证书/表现标准
```

**不是三个 AND 条件**：定位时三问并行（缺一不可）；规划时串行（有先后才有裁剪）；执行时单线（只走裁剪后的路径）。反证：若照 080717T 培养方案全学，会被迫消耗大量电子信息类课程——裁剪动作本身就证明链路有先后。

---

## 8. 边界与已知失效

1. **映射只覆盖 E1 轴**：宇宙只有一条结构主轴，知识有 16 轴；显性/隐性、可靠度等 15 轴在宇宙中无对应物；
2. **宇宙是稳态循环，知识是积累扩张**：「宇宙膨胀↔知识指数增长」只是修辞级类比，不构成同构；
3. **树形装不下交叉**：纯父子边必须配映射表作虫洞边；
4. **隐性知识无条目可挂**：目录是显性条目集合，技能的手感/直觉靠反馈环而非坐标。

---

## 9. 已核实项（原待核实项，2026-10-20 办结）

1. ~~「人工智能训练师」归属大类与代码~~ → **已核实**：大类 **4 社会生产服务和生活服务人员** → 中类 **4-04 信息传输、软件和信息技术服务人员** → 小类 **4-04-05 软件和信息技术服务人员** → 细类 **4-04-05-05**（数字职业 S）；2020-02-25 三部门 16 个新职业之一；国标（2021 版）工种=数据标注员、人工智能算法测试员（2024 增人工智能数字人训练师），五级~一级共 5 个技能等级。
2. ~~大典中类/小类的层级数量~~ → **已核实**（人社部公示公告 + 中国就业网 + 中国劳动保障报，多源一致）：大类 **8** / 中类 **79** / 小类 **449** / 细类（职业）**1636** / 工种 **2967**。⚠️ 二手口径「1639」（按 1481+158 推得）是错的，一律用 **1636**（本版已据此修订 §4.1 / §4.3.3 / §5.2）。

---

## 10. 术语表

| 术语    | 口径                                                                  |
| ----- | ------------------------------------------------------------------- |
| 编目    | 分级 + 编号 + 边界裁决权的法定目录；「官方」分行政（教育部/人社部）、统计（NCES）、国际协调（ILO/UNESCO）三种性质 |
| 成建制知识 | 被学术/职业/行政体制承认并有维护机制的知识（五判据：共同体/渠道/编码化/角色路径/合法化叙事）                   |
| 城/城门  | 知识区域 / 共同先修集合                                                       |
| 虫洞边   | 跨树跳转的 M:N 映射边                                                       |
| 编外恒星  | 已存在但编目未收录的知识对象，用兜底坐标临时挂靠                                            |

---

## 11. 参考核心

> 按功能分组组织，供按主题检索；形式完整的编号制文献表见 §12。两章内容同源，不互相替代。

- **建制理论**：Stichweh 1992（Science in Context 5(1)）；Becher 1989；Whitley 1984；Gibbons et al. 1994
- **知识论**：Polanyi 1966（隐性知识）；Nonaka & Takeuchi 1995（SECI）；Ryle 1945-46；Popper 1978（World 3）；Ackoff 1989（DIKW）；Kuhn 1962（范式）
- **认知科学**：Anderson 1976/1982/1983（ACT*）；Anderson & Krathwohl 2001（Bloom 修订）；Fitts & Posner 1967；Ericsson 1993（刻意练习）；DACUM（Norton 1997）
- **角色/专业社会学**：Linton 1936；Merton 1957；Abbott 1988；Freidson 2001；Biddle 1986
- **官方编目**：本科专业目录（2025）；研究生学科专业目录（2022）；职业分类大典（2022）；CIP；ISCED；ISCO-08；O*NET

---

## 12. 参考文献

> §11 的编号制重排与扩编（较 §11 多收 6 条，均为 §4.3 教育结构类文献）：格式遵循 Nature 期刊文献表规范（期刊：姓, 首字母. 文章标题. *期刊缩写* **卷**, 页码 (year).｜著作：姓, 首字母. *书名* (出版方, year).）。正文引用现为作者-年份夹注，故本章作为「混合式」文献表使用；若对外投稿需改编号上标，涉及正文约 30 处引用点。
>
> **两处题录修正（以本章为准）**：① Popper《Objective Knowledge: An Evolutionary Approach》初版为 **1972**（§11 所记 1978 系 Tanner 讲座年份）；② Ryle "Knowing How and Knowing That" 为 **1946** 年刊于 *Proceedings of the Aristotelian Society* 的期刊论文，非专著（§11 所记 1945-46 系 1945 宣读 / 1946 刊出的跨年记录，与本条不冲突）。

1. Stichweh, R. The sociology of scientific disciplines: on the genesis and stability of the disciplinary structure of modern science. *Sci. Context* **5**, 3–15 (1992).
2. Whitley, R. *The Intellectual and Social Organization of the Sciences* (Oxford Univ. Press, 1984).
3. Becher, T. *Academic Tribes and Territories: Intellectual Enquiry and the Cultures of Disciplines* (Open Univ. Press, 1989).
4. Gibbons, M. et al. *The New Production of Knowledge: The Dynamics of Science and Research in Contemporary Societies* (Sage, 1994).
5. Foucault, M. *Discipline and Punish: The Birth of the Prison* (Vintage, 1975).
6. Krishnan, A. *What Are Academic Disciplines? Some Observations on the Disciplinarity vs. Interdisciplinarity Debate* (NCRM Working Paper, Univ. of Southampton, 2009).
7. Polanyi, M. *The Tacit Dimension* (Doubleday, 1966).
8. Nonaka, I. & Takeuchi, H. *The Knowledge-Creating Company* (Oxford Univ. Press, 1995).
9. Ryle, G. Knowing how and knowing that. *Proc. Aristotelian Soc.* **46**, 1–16 (1946).
10. Popper, K. R. *Objective Knowledge: An Evolutionary Approach* (Oxford Univ. Press, 1972).
11. Ackoff, R. L. From data to wisdom. *J. Appl. Syst. Anal.* **16**, 3–9 (1989).
12. Kuhn, T. S. *The Structure of Scientific Revolutions* (Univ. Chicago Press, 1962).
13. Anderson, J. R. Acquisition of cognitive skill. *Psychol. Rev.* **89**, 369–406 (1982).
14. Anderson, L. W. & Krathwohl, D. R. *A Taxonomy for Learning, Teaching, and Assessing: A Revision of Bloom's Taxonomy of Educational Objectives* (Longman, 2001).
15. Fitts, P. M. & Posner, M. I. *Human Performance* (Brooks/Cole, 1967).
16. Ericsson, K. A., Krampe, R. T. & Tesch-Römer, K. The role of deliberate practice in the acquisition of expert performance. *Psychol. Rev.* **100**, 363–406 (1993).
17. Norton, R. E. *DACUM Handbook* (Center on Education and Training for Employment, Ohio State Univ., 1997).
18. Linton, R. *The Study of Man: An Introduction to Social Science* (D. Appleton-Century, 1936).
19. Merton, R. K. *Social Theory and Social Structure* (Free Press, 1957).
20. Abbott, A. *The System of Professions: An Essay on the Division of Expert Labor* (Univ. Chicago Press, 1988).
21. Freidson, E. *Professionalism: The Third Logic on the Practice of Knowledge* (Polity, 2001).
22. Biddle, B. J. Recent developments in role theory. *Annu. Rev. Sociol.* **12**, 67–92 (1986).
23. Stark, J. S. & Lattuca, L. R. *Shaping the College Curriculum: Academic Plans in Action* (Allyn & Bacon, 1997).
24. Trow, M. *Problems in the Transition from Elite to Mass Higher Education* (OECD, 1973).
25. Birnbaum, R. *Maintaining Diversity in Higher Education* (Jossey-Bass, 1983).
26. Brint, S., Cantwell, A. M. & Hanneman, R. A. The two cultures of undergraduate academic engagement. *Res. High. Educ.* **49**, 383–402 (2008).
27. 国务院学位委员会、教育部. 《研究生教育学科专业目录（2022年）》 (2022).
28. 教育部. 《普通高等学校本科专业目录（2025年）》 (2025).
29. 人力资源和社会保障部. 《中华人民共和国职业分类大典（2022年版）》 (2022).
30. UNESCO. *International Standard Classification of Education: ISCED 2011* (UNESCO Inst. for Statistics, 2012).
31. National Center for Education Statistics. *Classification of Instructional Programs (CIP 2020)* (US Dept. of Education, 2020).
32. International Labour Office. *International Standard Classification of Occupations 2008 (ISCO-08)* (ILO, 2012).
33. National Center for O*NET Development. *O\*NET OnLine* (US Dept. of Labor, accessed 2026-10-20).

---

## 修订记录

| 版本   | 日期         | 变化                                                                                                      |
| ---- | ---------- | ------------------------------------------------------------------------------------------------------- |
| v1.0 | 2026-10-19 | 首次成文：13 维度分类、定位三元组、倒置宇宙树、地形模型、学习路径设计                                                                    |
| v1.1 | 2026-10-20 | 修乱码/排版（标题层级统一、宽表拆分、修「就地展开」处乱码）；新增 §4.3 分轴文献清单（按关联度）；补目录与版本头                                             |
| v1.2 | 2026-10-20 | 保留 §11 分类版参考章不动；新增 §12 Nature 格式编号文献表（33 条）；修正两处题录：Popper 初版 1972（原记 1978）、Ryle 为 1946 期刊论文（原记 1945-46） |

/// Planner 面板骨架的 Widget 回归（`SPEC-PLAN-014` / `015` / `019`）。
///
/// 夹具刻意做成「两条源各覆盖两项、两套体系一全一窄」：
///
/// ```
/// i1 i2 ── src-a        sch-full : i1 i2 i3 i4
/// i3 i4 ── src-b        sch-part : i1 i2
/// ```
///
/// 这样「选源后体系不筛空」「选体系后源会收窄」「两者不相容时需重选」三件
/// 都能在同一个包上验，不必各造一份夹具。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/plan.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';
import 'package:project_knowledge/core/plan/plan_events.dart';
import 'package:project_knowledge/features/planner/planner_panel.dart';
import 'package:project_knowledge/features/planner/user_draft_dialogs.dart';

import '../../support/pack_fixture.dart';

Map<String, Object?> _source(String id) => <String, Object?>{
      'id': id,
      'name': id,
      'authorityLevel': 'L1',
      'version': '1.0',
      'segments': <Map<String, Object?>>[
        <String, Object?>{
          'text': '节选',
          'locator': 'p.1',
          'license': 'CC-BY-4.0',
        },
      ],
      'appliesTo': <String, Object?>{},
    };

LoadedPack _pack() => fixturePack(
      <FixtureItem>[
        const FixtureItem('i1', '一', sourceRefs: <String>['src-a']),
        const FixtureItem('i2', '二', sourceRefs: <String>['src-a']),
        const FixtureItem('i3', '三', sourceRefs: <String>['src-b']),
        const FixtureItem('i4', '四', sourceRefs: <String>['src-b']),
      ],
      schemes: <String, List<String>>{
        'sch-full': <String>['i1', 'i2', 'i3', 'i4'],
        'sch-part': <String>['i1', 'i2'],
      },
      excerpts: <Map<String, Object?>>[
        _source('src-a'),
        _source('src-b'),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  String? source,
  String? scheme,
  PlanTarget? target,
  void Function(PlanDraft draft)? onCreate,
  Size size = const Size(1200, 2600),
}) async {
  // 四段竖排在 800×600 下面要滚动，滚动会让 `find` 与坐标断言都失真 ——
  // 直接把视口撑高，验的是**顺序**而不是「能不能滚」。
  //
  // 要验布局本身（`B4-R` 的 sticky 与堆叠断点）就得传小视口，所以尺寸可覆盖。
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlannerPanel(
          pack: _pack(),
          target: target,
          initialSourceId: source,
          initialSchemeId: scheme,
          onCreate: onCreate,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TC-PLAN-036 四段按「源 → 体系 → 方法 → 确认」竖排（SPEC-PLAN-014）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;

    expect(
      y('planner-title-source'),
      lessThan(y('planner-title-scheme')),
      reason: '源在体系之上',
    );
    expect(
      y('planner-title-scheme'),
      lessThan(y('planner-title-method')),
      reason: '体系在方法之上',
    );
    expect(
      y('planner-title-method'),
      lessThan(y('planner-title-confirm')),
      reason: '确认段在最后',
    );
  });

  testWidgets('TC-PLAN-037 先选源不筛空，选体系后源按覆盖收窄（SPEC-PLAN-014 修订）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    // 先选源：体系候选不得清空 —— 单向依赖下这里会剩 0 条。
    await tester.tap(find.byKey(const Key('planner-source-src-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-scheme-sch-full')), findsOneWidget);
    expect(find.byKey(const Key('planner-scheme-sch-part')), findsOneWidget);
    expect(find.byKey(const Key('planner-empty-scheme')), findsNothing);

    // 再选窄体系：源里不该再有覆盖 0 的 src-b。
    await tester.tap(find.byKey(const Key('planner-scheme-sch-part')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-source-src-a')), findsOneWidget);
    expect(
      find.byKey(const Key('planner-source-src-b')),
      findsNothing,
      reason: 'src-b 覆盖 sch-part 的 0/2，必须被筛掉',
    );
  });

  testWidgets('TC-PLAN-038 预填两端互不相容 ⇒ 被筛掉那段标「需重选」且拦住确认（SPEC-PLAN-019）', (
    WidgetTester tester,
  ) async {
    // 重入场景：上次存的是 src-b + sch-part，而 src-b 对 sch-part 覆盖 0。
    await _pump(tester, source: 'src-b', scheme: 'sch-part');

    expect(
      find.byKey(const Key('planner-reselect-source')),
      findsOneWidget,
      reason: '静默保留会造出「界面上选着、实际不存在」的组合',
    );
    expect(
      find.textContaining('需重选'),
      findsWidgets,
    );
    expect(
      tester.widget<FilledButton>(
        find.byKey(const Key('planner-confirm-button')),
      ).onPressed,
      isNull,
      reason: '需重选时不许建计划',
    );
  });

  testWidgets('TC-PLAN-039 右栏只有三项读数，分母不随体系变（SPEC-PLAN-015）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const Key('preview-items')), findsOneWidget);
    expect(find.byKey(const Key('preview-denominator')), findsOneWidget);
    expect(find.byKey(const Key('preview-minutes')), findsOneWidget);

    String textOf(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    expect(textOf('preview-items'), '项数 4', reason: '未选体系 ⇒ 圈内全量');
    expect(textOf('preview-denominator'), '分母 4');

    await tester.tap(find.byKey(const Key('planner-scheme-sch-part')));
    await tester.pumpAndSettle();

    expect(textOf('preview-items'), '项数 2', reason: '体系只有 2 个节点');
    expect(
      textOf('preview-denominator'),
      '分母 4',
      reason: '分母是圈内项数，不随体系覆盖度变化',
    );
  });

  testWidgets('TC-PLAN-040 三段没选齐时确认按钮禁用并说明原因（SPEC-PLAN-014 ④段）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    final Finder button = find.byKey(const Key('planner-confirm-button'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('三段选齐才能建计划'), findsOneWidget);
  });

  testWidgets('TC-PLAN-041 三段选齐后可建，且确认段列出三个名字（SPEC-PLAN-014）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('planner-source-src-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-scheme-sch-full')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-method-method-bundle-memory')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(
        find.byKey(const Key('planner-confirm-button')),
      ).onPressed,
      isNotNull,
    );
    expect(find.byKey(const Key('planner-blocked')), findsNothing);

    expect(find.textContaining('src-a'), findsWidgets);
    expect(find.textContaining('sch-full'), findsWidgets);
    expect(find.textContaining('记忆优先'), findsWidgets);
  });

  testWidgets('TC-PLAN-046 面板把 target 接进预览：项数收窄、分母不动（SPEC-PLAN-015）', (
    WidgetTester tester,
  ) async {
    // `Z3` 圈定两项 i1 / i3 —— 空间圈内仍 4 项。
    await _pump(
      tester,
      target: const PlanTarget(
        selector: <String, Object?>{'kind': 'items'},
        resolved: <String>['i1', 'i3'],
      ),
    );

    String textOf(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    expect(textOf('preview-items'), '项数 2', reason: '只数 target 圈定的两项');
    expect(
      textOf('preview-denominator'),
      '分母 4',
      reason: '分母是空间规模，target 只收窄「这次走多少」',
    );
  });

  testWidgets('TC-PLAN-061 点「建计划」把草稿交出去，target 透传且 resolved 按当前包重算（SPEC-PLAN-019）', (
    WidgetTester tester,
  ) async {
    PlanDraft? captured;
    await _pump(
      tester,
      target: const PlanTarget(
        // 选择式取**合法**的一种（`PLAN-016` 的四 kind 之一）：`P-6` 时
        // 结构未定、这里曾写 `{'kind': 'items'}`，那是当时编的假 schema。
        selector: <String, Object?>{'kind': 'item', 'itemId': 'i1'},
        // 旧 resolved 里混一个不存在的项：草稿必须按当前包重算，不能照抄。
        resolved: <String>['i1', 'i3', 'ghost'],
      ),
      onCreate: (PlanDraft draft) => captured = draft,
    );

    await tester.tap(find.byKey(const Key('planner-source-src-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-scheme-sch-full')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-method-method-bundle-memory')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('planner-confirm-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull, reason: '按钮可点就必须真的交出去');
    expect(captured!.spaceId, 'python');
    expect(captured!.schemeId, 'sch-full');
    expect(captured!.methodProfileId, 'method-bundle-memory');
    expect(captured!.sourcePolicy, <String, Object?>{'primary': 'src-a'});
    expect(
      captured!.target.selector,
      <String, Object?>{'kind': 'item', 'itemId': 'i1'},
      reason: '选择式原样保留 —— 它记录的是用户当时怎么圈的',
    );
    expect(
      captured!.target.resolved,
      <String>['i1', 'i3'],
      reason: 'ghost 不在包里，必须被重算掉',
    );
  });

  // ─────────────────── 三段「+ 自建」（`B4` `P-8`） ───────────────────

  testWidgets('TC-PLAN-091 候选卡五元素齐：名字 · 出处 · 适用范围 · 读数 · 尾部「+ 自建」（SPEC-PLAN-008）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    String textOf(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    // 名字与出处在同一行（`· 平台内置` / `· 空间包` / `· 自建`）。
    expect(find.text('· 空间包'), findsWidgets);
    // 适用范围：源看 `appliesTo`，空 map = 不限。
    expect(textOf('planner-scope-source-src-a'), '适用 不限');
    // 体系没有 `appliesTo`，由 `nodes` 里实际出现的 `Item.type` 说。
    expect(textOf('planner-scope-scheme-sch-part'), '适用 陈述');
    // 方法由 `byType` 覆盖到的类型说（平台「记忆优先」四类全覆盖）。
    expect(
      textOf('planner-scope-method-method-bundle-memory'),
      '适用 陈述 / 流程 / 技能 / 默会',
    );
    // 读数与版本仍在（第五元素「版本」）。
    expect(textOf('planner-scope-method-method-bundle-memory'), isNotEmpty);
    // 尾部「+ 自建」三段都有，且是**真按钮**。
    for (final String name in <String>['source', 'scheme', 'method']) {
      expect(
        find.byKey(Key('planner-create-$name')),
        findsOneWidget,
        reason: '$name 段尾部要有自建入口',
      );
    }
    expect(
      tester.widget<TextButton>(find.byKey(const Key('planner-create-method'))),
      isNotNull,
    );
  });

  testWidgets('TC-PLAN-092 源自建：建完立刻出现在候选里并被选中（SPEC-PLAN-007）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('planner-create-source')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(userSourceNameKey), '内规');
    await tester.tap(find.byKey(userDialogAddKey));
    await tester.pumpAndSettle();

    // id 带 `user:` 前缀（不与包内 id 撞），卡片 key 因此可预测。
    expect(
      find.byKey(const Key('planner-source-user:src:内规')),
      findsOneWidget,
      reason: '建完还要回头找一遍，才叫「把建和选拆成两处」',
    );
    expect(find.text('· 自建'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('planner-confirm-source'))).data,
      contains('内规'),
      reason: '建完立刻选中 —— 用户不用再点一次',
    );
  });

  testWidgets('TC-PLAN-093 体系自建：勾选次序即 nodes，预览与确认都用它（SPEC-PLAN-007）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('planner-create-scheme')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(userSchemeNameKey), '先二后一');
    await tester.tap(find.byKey(userSchemePickKey('i2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(userSchemePickKey('i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(userDialogAddKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('planner-scheme-user:sch:先二后一')),
      findsOneWidget,
    );
    // 选中后预览真的按这套自建算 —— 不接线的话这里会抛「不存在的体系 id」。
    expect(
      tester.widget<Text>(find.byKey(const Key('preview-items'))).data,
      '项数 2',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('preview-denominator'))).data,
      '分母 4',
      reason: '分母是圈内项数，自建体系不该动它',
    );
  });

  testWidgets('TC-PLAN-094 方法自建：全「读」配方被拒，错误显示在表里且不入候选（SPEC-PLAN-011）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('planner-create-method')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(userMethodNameKey), '只读法');
    // 起手那一步就是「读」，直接提交 ⇒ 校验 ② 应当拦下。
    await tester.tap(find.byKey(userDialogAddKey));
    await tester.pumpAndSettle();

    expect(find.byKey(userDialogErrorKey), findsOneWidget);
    expect(
      find.textContaining('忆 / 练 / 讲 / 做'),
      findsOneWidget,
      reason: '要说出为什么不让存，而不是静默吞掉',
    );
    expect(
      find.byKey(const Key('planner-method-user:method:只读法#bundle')),
      findsNothing,
      reason: '没通过校验就不该进候选',
    );

    // 补一个「忆」步之后能存（同一张表不必重填）。
    await tester.tap(
      find.byKey(userMethodOpKey(0, ExecutionOperator.recall)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(userDialogAddKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('planner-method-user:method:只读法#bundle')),
      findsOneWidget,
    );
  });

  testWidgets('TC-PLAN-095 方法自建后能走完三段并建计划，草稿存的是 bundle id（SPEC-PLAN-011）', (
    WidgetTester tester,
  ) async {
    PlanDraft? captured;
    await _pump(tester, onCreate: (PlanDraft draft) => captured = draft);

    await tester.tap(find.byKey(const Key('planner-source-src-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-scheme-sch-full')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('planner-create-method')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(userMethodNameKey), '三遍法');
    await tester.tap(
      find.byKey(userMethodOpKey(0, ExecutionOperator.practice)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(userMethodCriteriaKey(0)), '连做三次不出错');
    await tester.tap(find.byKey(userDialogAddKey));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(
        find.byKey(const Key('planner-confirm-button')),
      ).onPressed,
      isNotNull,
      reason: '自建方法覆盖了陈述类，四项都是陈述 ⇒ 不该被「未覆盖」拦住',
    );
    expect(find.byKey(const Key('planner-blocked')), findsNothing);

    await tester.tap(find.byKey(const Key('planner-confirm-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(
      captured!.methodProfileId,
      'user:method:三遍法#bundle',
      reason: '`Plan.methodProfileId` 存组合的 id，不是分支的',
    );
  });

  testWidgets('TC-PLAN-096 全步骤无 hint 时 ③ 段说出来；自建带 hint 后提示消失（SPEC-PLAN-011）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    // 平台五份分支都没有 `hint` —— 这不是笔误，是 `entity-fields` §一.7 校验 ③
    // 要求的「显式标代价」：不禁止，但要说得出来。
    expect(find.byKey(const Key('planner-no-hint')), findsNothing,
        reason: '还没选 ③ 时无从谈起');

    await tester.tap(find.byKey(const Key('planner-scheme-sch-full')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('planner-method-method-bundle-memory')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-no-hint')), findsOneWidget);

    await tester.tap(find.byKey(const Key('planner-create-method')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(userMethodNameKey), '带提示法');
    await tester.tap(
      find.byKey(userMethodOpKey(0, ExecutionOperator.recall)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(userMethodHintKey(0)), '先想标题');
    await tester.tap(find.byKey(userDialogAddKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('planner-no-hint')),
      findsNothing,
      reason: '这套方法有提示可给，就不该再报警',
    );
  });

  testWidgets(
    'TC-PLAN-097 已选体系下自建的源覆盖 0 ⇒ 留在候选里标「不可选」，不凭空消失（SPEC-PLAN-007）',
    (WidgetTester tester) async {
      await _pump(tester);

      // 先选一套体系：此后源候选按「覆盖 > 0」收窄 —— 包内的源正常筛掉，
      // **自建的源例外**（`B4-R`）：它的覆盖恒 0（客户端写不了
      // `Item.sourceRefs`），筛掉就等于「建了看不见」。
      await tester.tap(find.byKey(const Key('planner-scheme-sch-full')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('planner-create-source')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(userSourceNameKey), '内规');
      await tester.tap(find.byKey(userDialogAddKey));
      await tester.pumpAndSettle();

      // 建的东西必须留在列表里：看不见它等于没建成（走查实拍）。
      expect(
        find.byKey(const Key('planner-source-user:src:内规')),
        findsOneWidget,
        reason: '建的动作要有回执',
      );
      expect(
        find.byKey(const Key('planner-user-notice')),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('planner-user-notice'))).data,
        contains('覆盖 0'),
      );
      // 覆盖 0 ⇒ 不可选，并且**不该**有「已取消选择」—— 它从没被选中过。
      expect(find.textContaining('不可选'), findsWidgets);
      expect(find.byKey(const Key('planner-reselect-source')), findsNothing);

      // 点它没有反应：确认按钮仍是灰的。
      await tester.tap(find.byKey(const Key('planner-source-user:src:内规')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(
          find.byKey(const Key('planner-confirm-button')),
        ).onPressed,
        isNull,
      );
    },
  );

  testWidgets('TC-PLAN-099 ④ 确认固定在左栏底部：候选滚到顶它仍在视口内（SPEC-PLAN-014）', (
    WidgetTester tester,
  ) async {
    // 800×420 仍走横排（断点 720），但高度不足以放下三段 ⇒ 列表必须滚。
    await _pump(tester, size: const Size(800, 420));
    final Finder button = find.byKey(const Key('planner-confirm-button'));

    // 滚到顶：旧实现下按钮在列表末尾，坐标会掉到视口外。
    await tester.drag(
      find.byKey(const Key('planner-left')),
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    final Rect top = tester.getRect(button);
    expect(top.top, greaterThanOrEqualTo(0));
    expect(
      top.bottom,
      lessThanOrEqualTo(420),
      reason: '唯一出口不该靠用户滚到底才看得见',
    );

    // 滚到底也一样 —— 它不参与滚动。
    await tester.drag(
      find.byKey(const Key('planner-left')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    final Rect bottom = tester.getRect(button);
    expect(bottom.bottom, lessThanOrEqualTo(420));
  });

  testWidgets('TC-PLAN-100 窄于断点改上下堆叠，不出溢出条（SPEC-PLAN-017）', (
    WidgetTester tester,
  ) async {
    // 窄到 520：横排会让两栏各分到几十像素，文字逐字竖排并溢出（走查实拍
    // 每张卡片挂 `RIGHT OVERFLOWED BY 52 PIXELS`）。
    await _pump(tester, size: const Size(520, 900));
    expect(
      tester.takeException(),
      isNull,
      reason: '溢出在测试里会以 FlutterError 抛出来',
    );

    final Rect left = tester.getRect(find.byKey(const Key('planner-left')));
    final Rect preview = tester.getRect(find.byKey(const Key('planner-preview')));
    expect(
      preview.top,
      greaterThanOrEqualTo(left.bottom),
      reason: '堆叠后预览在清单下方，不是并排',
    );
  });

  testWidgets('TC-PLAN-101 三段「自建」按钮只有一个加号（SPEC-PLAN-007）', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    // 不引 `PlanSegment`：它住在 `core/plan/candidates.dart`，为三个字符串再
    // 拉一条 import 不划算。
    for (final String segment in <String>['source', 'scheme', 'method']) {
      final Finder button = find.byKey(Key('planner-create-$segment'));
      expect(
        find.descendant(of: button, matching: find.text('自建')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: button, matching: find.text('+ 自建')),
        findsNothing,
        reason: '图标已是 `Icons.add`，文字再带加号就成了「＋ + 自建」',
      );
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
    }
  });

  testWidgets('TC-PLAN-102 「已取消选择」既说名字也说另一端，不再说「已选的」（SPEC-PLAN-014）', (
    WidgetTester tester,
  ) async {
    // 走**重入**这条路（`SPEC-PLAN-019`）：两个预填值互不相容 —— src-b 只覆盖
    // i3 i4，sch-part 只含 i1 i2。手动选是走不到这里的：选源会收窄体系、选体系
    // 会收窄源，两段永远兼容（`B4` `P-2` 的双向收窄）。自建源那条路在 `B4-R`
    // 之后也不再触发（它改成「保留 + 不可选」）。所以「已取消选择」这句话现在
    // 只服务重入预填。
    await _pump(tester, source: 'src-b', scheme: 'sch-part');

    final Text line = tester.widget<Text>(
      find.byKey(const Key('planner-reselect-source')),
    );
    expect(line.data, contains('src-b'), reason: '要说名字，不能甩内部 id');
    expect(line.data, contains('当前体系'), reason: '另一端要指明，别写「另一端」');
    expect(line.data, contains('已取消选择'));
    expect(
      line.data,
      isNot(contains('已选的')),
      reason: '那一项已经清空了，说「已选的」会让人去找一张不在选中态的卡片',
    );
  });
}

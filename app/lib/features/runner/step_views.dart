/// 六类执行算子的界面形态（`SPEC-STEP-012`：6 类与组件 **1:1**）。
///
/// ## 每类一个形态，不做「通用输入框」
///
/// 六类的区别不是文案，是**要不要产出**：读 / 例 只看，忆 / 练 / 讲 要留字，
/// 做 要交产物。用同一个「输入 + 下一步」套住它们，等于把「无提示复现」与
/// 「对着答案抄一遍」画成同一屏 —— 而这两件事在排期上是相反的。
///
/// ## 本笔只实现五类
///
/// `do`（真实任务 + 产物上传）没有实现：产物要文件存储与覆盖层写入，`B16`
/// 还没开工。包内 `do` 用量为零，所以不会断链；真遇到就如实显示「尚未实现」，
/// 不拿一个假的任务清单糊过去。
library;

import 'package:flutter/material.dart';

import '../../core/entities/entry.dart';
import '../../core/enums.dart';

/// 该算子的主按钮文案。主按钮同时是「这一步完成了」的唯一入口，
/// 所以文案要说人话，不能都叫「下一步」。
String primaryLabelOf(ExecutionOperator operator) {
  switch (operator) {
    case ExecutionOperator.read:
      return '读完了';
    case ExecutionOperator.example:
      return '看完了';
    case ExecutionOperator.recall:
      return '想不起来';
    case ExecutionOperator.practice:
      return '写好了';
    case ExecutionOperator.explain:
      return '讲完了';
    case ExecutionOperator.doStep:
      return '做完了';
  }
}

/// 当前这一步的界面。**只画这一步**（`SPEC-STEP-010`）—— 下一步长什么样
/// 由下一步自己决定，提前透露会让人先读完全部再动手。
class StepBody extends StatelessWidget {
  const StepBody({
    super.key,
    required this.step,
    required this.entry,
    required this.controller,
  });

  final EntryStep step;

  /// 所在项。练 / 讲 的要点与自评清单在**项**上，不在步骤上。
  final NodeEntry entry;

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('step-body'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: <Widget>[
        Text(step.instruction, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        ..._extra(context),
      ],
    );
  }

  List<Widget> _extra(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    switch (step.operator) {
      case ExecutionOperator.read:
        return <Widget>[];

      case ExecutionOperator.example:
        // 范本 = 这一步的提示；没有提示就退回该项摘要。**不解释**它为什么是范本 ——
        // 标注本身由内容作者写，界面只负责摆出来。
        final String? model = step.hint ?? entry.summary;
        if (model == null) {
          return <Widget>[];
        }
        return <Widget>[_panel(context, title: '范本', body: model)];

      case ExecutionOperator.recall:
        return <Widget>[
          TextField(
            key: const Key('step-input'),
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '不看提示，写出来',
            ),
          ),
        ];

      case ExecutionOperator.practice:
        return <Widget>[
          TextField(
            key: const Key('step-input'),
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '写出来',
            ),
          ),
          if (step.hint != null) ...<Widget>[
            const SizedBox(height: 12),
            ExpansionTile(
              key: const Key('step-hint-toggle'),
              title: Text('要点', style: text.bodyMedium),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: <Widget>[Text(step.hint!, style: text.bodyMedium)],
            ),
          ],
        ];

      case ExecutionOperator.explain:
        return <Widget>[
          TextField(
            key: const Key('step-input'),
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '讲给一个不懂的人听',
            ),
          ),
          if (entry.selfCheck.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text('自评清单', style: text.labelLarge),
            const SizedBox(height: 4),
            for (final String line in entry.selfCheck)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('· $line', style: text.bodyMedium),
              ),
          ],
        ];

      case ExecutionOperator.doStep:
        return <Widget>[
          Text(
            '这一类算子尚未实现（真实任务与产物上传要等覆盖层那一批）。',
            key: const Key('step-unimplemented'),
            style: text.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ];
    }
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: text.labelLarge),
          const SizedBox(height: 8),
          Text(body, style: text.bodyMedium),
        ],
      ),
    );
  }
}

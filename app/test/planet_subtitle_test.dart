import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/entry.dart';
import 'package:project_knowledge/main.dart';

/// 造一个只含被测字段的 entry。`body` / `steps` / `quiz` 三项决定副标题，
/// 其余字段填空表 —— 本组用例只锁「副标题报的是不是真有的东西」。
NodeEntry entryWith({String? body, int steps = 0, int quiz = 0}) {
  return NodeEntry.fromJson(<String, Object?>{
    'node_id': 'german/probe',
    'summary': '摘要',
    'outcomes': <String>[],
    'resources': <Object?>[],
    'aliases': <String>[],
    'keywords': <String>[],
    'body': body,
    'steps': <Object?>[
      for (int i = 0; i < steps; i++)
        <String, Object?>{'operator': 'read', 'instruction': '第 $i 步'},
    ],
    'selfCheck': <String>[],
    'criteria': <Object?>[],
    'quiz': <Object?>[
      for (int i = 0; i < quiz; i++)
        <String, Object?>{
          'id': 'q-$i',
          'criterion_id': 'c-$i',
          'type': 'freeform',
          'prompt': '题 $i',
          'answer': '答 $i',
          'judge': 'self',
        },
    ],
    'source_refs': <String>[],
  });
}

void main() {
  test('没有 entry 报「暂无内容」，不冒充有内容（SPEC-FND-014）', () {
    expect(planetSubtitle(null), '暂无内容');
  });

  test('有正文与步骤、没有题：报「有正文与步骤」，不写「有题目」（SPEC-FND-014）', () {
    final NodeEntry entry = entryWith(body: '正文', steps: 5);
    expect(planetSubtitle(entry), '有正文与步骤');
  });

  test('有题目时把题数写出来，题数取 quiz.length 不写死（SPEC-FND-014）', () {
    final NodeEntry one = entryWith(body: '正文', steps: 5, quiz: 1);
    final NodeEntry two = entryWith(body: '正文', steps: 5, quiz: 2);
    expect(planetSubtitle(one), '有正文与步骤 · 题目 1');
    expect(planetSubtitle(two), '有正文与步骤 · 题目 2');
  });

  test('只有题、没有正文与步骤：报「仅题目 N」，不说有正文（SPEC-FND-014）', () {
    expect(planetSubtitle(entryWith(quiz: 3)), '仅题目 3');
  });

  test('entry 存在但三项全空，与没有 entry 同样报「暂无内容」（SPEC-FND-014）', () {
    expect(planetSubtitle(entryWith()), '暂无内容');
  });
}

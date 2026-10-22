/// Markdown 相对链接的**唯一解析口径**。
///
/// 抽成独立文件的原因不是「代码复用」好听，而是两处调用者**必须同口径**：
/// - `rules.dart` 的 `D6` 用它判「链接指向的路径在不在仓里」；
/// - `migrate_docs.dart` 用它把链接解析成仓相对路径、再按新布局反算。
///
/// 口径若各写一份，迁移器算出来的结果检查器可能不认 —— 那正是「搬家搬到一半
/// 断链」的成因。两处不一致时 CI 会红，但红的原因会被误判成「迁移器有 bug」。
///
/// 全部公开（无下划线）：本文件只供 `app/tool/docs/` 内部两支使用，不要在别处引。
library;

/// 行内链接 / 图片：`](目标)`。图片（`![alt](…)`）同样命中，两者都是路径承诺。
final RegExp linkRe = RegExp(r'\]\(\s*([^)\s]+)\s*\)');

/// 代码围栏开闭行（三个反引号或三个波浪号，至多三格缩进）。
final RegExp fenceRe = RegExp(r'^ {0,3}(?:```|~~~)');

/// 行内代码：成对的同数量反引号之间。
///
/// 必须支持**多反引号**定界（`` ``…`` ``）：描述「链接文本里带反引号」这类写法时
/// 就会用到，用单反引号的正则会把 `` `` [`x`](y) `` `` 剥成半截、剩下的 `](y)`
/// 被当成真链接 —— 实跑踩过一次，`STR` 里那处示例就此报假红。
final RegExp inlineCodeRe = RegExp(r'(`+).*?\1');

/// 外链、页内锚点 —— 不判存在。
bool isExternalTarget(String raw) {
  if (raw.startsWith('#')) {
    return true;
  }
  return RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:').hasMatch(raw);
}

/// 把 [target] 按 [fromFile] 所在目录解析成仓库相对路径。
///
/// 返回 `null` 表示**上跳越过仓库根**（`../../../x` 从 `docs/x.md` 出发）——
/// 那不是「链坏了」，是这条链接根本不可能指向仓内，单独给一句更准的话。
///
/// 不调 `package:path`：这一支是纯函数、零依赖，为十行逻辑引一个包不划算；
/// 也不解 `%20` 之类的百分号编码 —— 本仓路径一律直接写中文，没有编码形态，
/// 出现编码说明写法本身就不对，应当报出来而不是替它兜。
String? resolveLink(String fromFile, String target) {
  final int slash = fromFile.lastIndexOf('/');
  final List<String> segs = slash < 0
      ? <String>[]
      : fromFile.substring(0, slash).split('/');
  for (final String part in target.split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (segs.isEmpty) {
        return null;
      }
      segs.removeLast();
      continue;
    }
    segs.add(part);
  }
  return segs.join('/');
}

/// [resolveLink] 的逆运算：从 [fromFile] 出发，指向仓相对路径 [toAbs] 该怎么写。
///
/// 用于迁移器 —— 文件搬完位置后，同一条链接的相对写法就变了（`../design/` 变成
/// `../specs/`，深度也可能变），必须从**新位置**反算，不能用字符串替换。
///
/// 例：`fromFile = docs/adr/README.md`，`toAbs = docs/decisions/0001-x.md`
/// → `../decisions/0001-x.md`
String relativeLink(String toAbs, String fromFile) {
  final int slash = fromFile.lastIndexOf('/');
  final List<String> fromDir =
      slash < 0 ? <String>[] : fromFile.substring(0, slash).split('/');
  final List<String> to = toAbs.split('/');
  int common = 0;
  while (common < fromDir.length &&
      common < to.length &&
      fromDir[common] == to[common]) {
    common++;
  }
  final List<String> out = <String>[
    for (int i = common; i < fromDir.length; i++) '..',
    ...to.sublist(common),
  ];
  // 两端同目录且目标是目录本身时，`out` 会空 —— 写成 `./` 比空串安全，
  // 空串会被渲染成「指向当前文档」的链接并可能自指。
  return out.isEmpty ? './' : out.join('/');
}

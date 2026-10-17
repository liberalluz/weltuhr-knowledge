/// id 的显示末段。
///
/// 域 id 与缺口 id 是**路径形**（`python/lexical`、`__missing__:12`），界面上只该
/// 看到最后一段。两处以上要用 ⇒ 放这里，不再各写一份。
library;

/// 取末段：`python/lexical` → `lexical`。
String idTail(String id) {
  final int slash = id.lastIndexOf('/');
  return slash < 0 ? id : id.substring(slash + 1);
}

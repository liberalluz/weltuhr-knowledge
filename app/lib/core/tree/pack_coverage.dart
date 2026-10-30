/// 作用域的**包覆盖**：一个树地址的子树里，到底落着哪些包（`SPEC-VIEW-031`）。
///
/// ## 为什么不按「节点属于哪个包」取一个包
///
/// 树是跨包的：载荷包的域节点把父边指向骨架星（`minimal-pack.md` §4.1），所以
/// 「英语」这一行在骨架包里、它下面的 `noun phrase` 在 english 包里。按「地址
/// 所在的那个包」只取一个，会把子树里另一半包丢掉 —— 选中「英语」时作用域只剩
/// 骨架，而骨架里一条可学项都没有，结果恒为 0 条。
///
/// 覆盖集是这棵子树的**真实构成**，不特判任何一层：选中轴根覆盖全部包，选中骨架
/// 星覆盖「骨架 + 挂在它下面的载荷」，选中载荷域只覆盖那一个包。
///
/// ## 为什么吃 `TreeIndex` 而不是各包的 `ParentIndex`
///
/// `PackContent.parents` 只装本包的父边，父链到骨架节点就断。`TreeIndex` 把全部
/// 包的主父边合成一张表，跨包那一段才连得上。这里要的是「这个地址的子树里有哪些
/// 节点」，正是树索引已经算好的东西。
library;

import '../pack/pack_reader.dart';
import 'tree_index.dart';

/// [addressId] 的子树覆盖到的包，按 [contents] 的原顺序。
///
/// 空表有三种来源，调用方**都**按「圈不出范围」处理：地址为空、地址不在树上、
/// 地址的子树里一个包节点都没有。返回空表而不是抛错：调用方是界面，它要的是
/// 「有没有范围」这个事实，不是异常。
List<PackContent> packsUnderRoot({
  required TreeIndex tree,
  required Iterable<PackContent> contents,
  required String? addressId,
}) {
  if (addressId == null || addressId.isEmpty) {
    return const <PackContent>[];
  }
  final Set<String> ids = <String>{
    for (final TreeRow row in tree.subtree(addressId)) row.nodeId,
  };
  if (ids.isEmpty) {
    return const <PackContent>[];
  }
  final List<PackContent> covered = <PackContent>[];
  for (final PackContent content in contents) {
    for (final node in content.nodes) {
      if (ids.contains(node.id)) {
        covered.add(content);
        break;
      }
    }
  }
  return covered;
}

/// 存储三区（`entity-fields.md` §〇）的文件系统接缝。
///
/// 三区**不是三个目录的命名约定，而是三种访问能力**：
///
/// | 区 | 能力 | 接口 |
/// |---|---|---|
/// | 只读分发区 | 只能读 | [`PackFs`](../pack/pack_fs.dart)（`StoreFs` 在包语义下的名字） |
/// | 可写内容区 | 读 + 原子写 | [WritableStoreFs] |
/// | 事件日志区 | 读 + 追加 | [AppendOnlyStoreFs] |
///
/// **为什么不是「一个可读写接口再加一个 `append` 方法」**：那等于让事件区也拿到
/// `writeStringAtomic`，整段历史就能被一次覆盖。而 `R3` 查的是**方法名**
/// （`update` / `delete` / `clear`），查不出「拿 `write` 覆盖」——
/// 形状封死比名单封死可靠：事件区拿到的接口里**根本没有**写方法。
///
/// 三个接口都只做**总函数**（不抛异常，返回 `bool` / `null`），理由与 `PackFs`
/// 同源：调用方要回答的问题是「这里为什么没写成」，而一个从 `dart:io` 穿出来的
/// `FileSystemException` 只会说「挂了」。具体原因（只读挂载 / 磁盘满 / 权限）
/// 由实现方的日志承担，接口层只给成败。
library;

/// 三个区共有的最小读能力。
///
/// 抽出来只为**一处定义**：`PackFs` 原本自带三个方法声明，若三区各自再声明一遍，
/// 加一个读方法就要改四处，而四处必然分叉。
abstract interface class StoreFs {
  /// 是否为**已存在且可读**的普通文件。
  bool isFile(String path);

  /// 列出一级子目录名（不含路径前缀），**不含**文件。目录不存在时返回空列表。
  List<String> listDirs(String path);

  /// 读 UTF-8 文本。不存在 / 权限不足 / 非 UTF-8 一律 `null`。
  String? readString(String path);
}

/// 可写内容区：读 + **原子写**（`ENTITY` §〇「可写内容区」）。
///
/// 写的东西是 `S4` 自建节点、个人 `OverlayPatch`、`PathClaim` 墓碑 ——
/// 全部是「用户攒出来的事实」，**半截写入 = 丢事实**，所以只有原子写一个写方法，
/// 不提供「先截断再写」这种会让崩溃留下空文件的形态。
abstract interface class WritableStoreFs implements StoreFs {
  /// 建目录（含中间层）。已存在视为成功。
  bool ensureDir(String path);

  /// 原子写：要么目标变成新内容，要么**保持原样**，不存在第三种结果。
  ///
  /// 实现约定（判据在 `DartIoPackFs`，但接缝层先钉死语义）：
  /// 1. 先写**同目录**下的临时文件（跨目录 rename 在跨卷时会退化成
  ///    copy + delete，那就不再是原子的）；
  /// 2. `flush` 之后再 rename —— 不 flush 的话断电留下的是「文件名对了、
  ///    内容是零字节」；
  /// 3. 任何一步失败都清掉临时文件并返回 `false`。
  bool writeStringAtomic(String path, String content);
}

/// 事件日志区：读 + **追加**（`ENTITY` §〇「事件日志区」）。
///
/// 只有 [appendLine]，没有任何改写方法 —— 这条不靠自觉、不靠 lint 名单，
/// 靠接口形状：拿不到写方法就写不出覆盖。`R3` 的名单检查仍需覆盖本接口，
/// 防的是有人在实现类上**额外**长出 `clear()`。
abstract interface class AppendOnlyStoreFs implements StoreFs {
  /// 追加一行（实现负责补行尾换行）。`true` = 已落盘。
  ///
  /// 为什么是「行」而不是「字节」：事件日志的物理形态是一行一个事件，
  /// 半行写入会让下一次读跳出解析错误。按行追加在单进程内由追加写的
  /// 偏移原子性保证，不需要 temp + rename（那反而会把整个日志重写一遍）。
  bool appendLine(String path, String line);
}

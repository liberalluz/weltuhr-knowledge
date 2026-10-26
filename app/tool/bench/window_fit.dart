/// 把窗口设成 `C-33` 的基准客户区（`R-22` 的测量前提那一半）。
///
/// ## 为什么必须由装置自己设
///
/// `C-33` 要的是 `1920×1080` **物理**客户区（`ADR-0002` 修订三：面积指物理面积）。
/// 人手拖窗口做不到，两个条件互相排斥：
///
/// - 客户区宽 `1920` 只有在**最大化**时才有 —— 非最大化时客户区宽 = 窗口宽减左右
///   边框，屏幕本身只有 `1920`，怎么拖都差十几个像素；
/// - 客户区高 `1080` 只有在**非最大化**时才调得出来 —— 最大化给的是工作区高减标题栏，
///   在 16:10 屏上比 `1080` 高，而最大化状态不许改尺寸。
///
/// 更要紧的是**可复跑**（`R-22`）：算法、剧本、样本三样都钉住了，唯独测量前提
/// 靠人手 —— 换一个人、换一台机器就是另一组数。前提由装置自己保证，那才真叫可复跑。
///
/// ## 去边框之后客户区就等于窗口矩形
///
/// 去掉 `WS_CAPTION`（它含 `WS_BORDER` | `WS_DLGFRAME`）与 `WS_THICKFRAME` 之后，
/// 窗口没有标题栏也没有边框 ⇒ **客户区 = 窗口矩形**，于是 `SetWindowPos` 的宽高
/// 就是要的客户区宽高，不必用 `AdjustWindowRectEx` 反算边框再补偿。反算那一步是
/// 错的温床：算错 8 px 不会有任何东西变红，读数只会安静地偏离前提。
///
/// 窗口摆在 `(0, 0)`，**不居中**。居中要先查屏幕尺寸（`GetSystemMetrics`），
/// 而那个符号正是 `v0.80.0`–`v0.80.1` 三跑全废的原因（见下）—— 一个纯装饰的
/// 步骤换来一个会把整段设窗静默吞掉的绑定，不划算。摆在原点还更确定：位置不再
/// 随屏幕尺寸变，`R-22` 少一个变量。
///
/// ## 失败要说得出是哪一步
///
/// `v0.80.0` 起三版代码、三次真机，日志里都是同一句**猜出来的**话（先写「前台不是
/// 本进程的窗口？」，再写「枚举不到本进程的可见顶层窗口？」），而三次的真实原因
/// 是同一个：[`_Win32`] 在构造期就抛了 —— `GetSystemMetrics` 是 `User32.dll` 的
/// 导出，代码从 `kernel32` 查，`lookupFunction` 抛 `ArgumentError`，被 `_bind()`
/// 的 `on Object` 吞成 `null`。于是 `EnumWindows` 那段**一次都没执行过**，
/// 而两版日志分别把人引去查前台、查窗口可见性。
///
/// 所以现在返回 [BenchWindowFit] 而不是 `null`：[WindowFitStage] 说明卡在
/// 绑定 / 找窗口 / 改尺寸哪一步，[BenchWindowFit.detail] 带上原始错误文本。
///
/// 取窗口时**校验进程号**：`SetWindowPos` 用错句柄会把别人正在用的窗口改成
/// `1920×1080`，那比设不上更糟 —— 所以找不到本进程的窗口就报 [WindowFitStage.noWindow]。
///
/// ## 为什么要把它提到前台
///
/// 尺寸设对但窗口留在后台，Windows 会判它**被遮挡**、引擎跳过光栅 ⇒ 采样期一个
/// `FrameTiming` 都收不到（实测 20 秒 0 个帧间隔）。所以设完尺寸还要
/// `BringWindowToTop` + `SetForegroundWindow` —— 那不是为了好看，是为了有帧。
library;

import 'dart:ffi';
import 'dart:io';

/// 设窗卡在了哪一步。
///
/// 分步的理由不是「日志好看」，是三跑三版都**失败得没信息**：`null` 一种返回值
/// 同时表示「不在 Windows 上」「符号查不到」「找不到窗口」「尺寸被拒」，而调用方
/// 只能挑一个去猜，猜错就把人引去别处（第三次猜的是窗口可见性，真实原因是绑定）。
enum WindowFitStage {
  /// 设上了。
  ok,

  /// 不在 Windows 上 —— 没有窗口可设，调用方退回「说清楚尺寸，等人手调」。
  notWindows,

  /// `user32.dll` / `kernel32.dll` 里有一个符号查不到。
  bind,

  /// 枚举完了，本进程没有可见的顶层窗口。
  noWindow,

  /// `SetWindowPos` 返回 0（尺寸被拒，例如窗口仍处于最大化）。
  resize,
}

/// 一次设窗的结果。
///
/// 宽度与高度是**设定值**，不是设完读回来的值：无边框窗口的客户区等于窗口矩形，
/// 两者本该相等。真值由调用方读视口核对 —— 这里返回「设了什么」，视口报「成了什么」，
/// 两个数分开记，才不会用一个去掩盖另一个。
class BenchWindowFit {
  const BenchWindowFit.ok({
    required this.width,
    required this.height,
    required this.frameless,
  })  : stage = WindowFitStage.ok,
        detail = '';

  const BenchWindowFit.failed(this.stage, this.detail)
      : width = 0,
        height = 0,
        frameless = false;

  final WindowFitStage stage;

  /// 失败时的原始错误文本（`lookupFunction` 的 `ArgumentError` 之类）。成功时为 `''`。
  final String detail;

  final int width;

  final int height;

  /// 边框是否已去掉。`false` 表示样式写入失败但尺寸设上了 —— 此时客户区会比
  /// 设定值小一圈，调用方据此知道「别信这个尺寸」。
  final bool frameless;

  bool get ok => stage == WindowFitStage.ok;

  /// 一句话说清结果 —— 日志直接用它，不再由调用方猜。
  String get reason => switch (stage) {
        WindowFitStage.ok => '窗口已设成 ${width}x$height 物理客户区',
        WindowFitStage.notWindows => '不在 Windows 上，没有可设的窗口',
        WindowFitStage.bind => 'Win32 绑定失败：$detail',
        WindowFitStage.noWindow => '枚举不到本进程的可见顶层窗口',
        WindowFitStage.resize => 'SetWindowPos 返回 0，尺寸没设上',
      };

  @override
  String toString() => 'BenchWindowFit($stage, ${width}x$height, '
      'frameless=$frameless${detail.isEmpty ? '' : ', $detail'})';
}

// Win32 常量。写在 `tool/` 里不进常量表：它们是平台 ABI 的一部分，不是本项目的
// 判据 —— 搬进 `constants.dart` 只会让常量表变成第二份 `windows.h`。
const int _gwlStyle = -16;
const int _wsCaption = 0x00C00000;
const int _wsThickFrame = 0x00040000;
const int _swpNoZOrder = 0x0004;
const int _swpNoActivate = 0x0010;
const int _swpFrameChanged = 0x0020;
const int _swpShowWindow = 0x0040;
const int _lmemZeroInit = 0x0040;
const int _swRestore = 9;

/// 把本进程的窗口设成 [width]×[height] 物理像素的无边框客户区、摆在原点、并
/// **提到前台**。
///
/// 成功返回 [WindowFitStage.ok]；任何一步不成立都返回带环节名的失败结果 ——
/// 调用方据此说清「为什么等不到」，而不是猜。
BenchWindowFit fitBenchWindow({required int width, required int height}) {
  if (!Platform.isWindows) {
    return const BenchWindowFit.failed(WindowFitStage.notWindows, '');
  }
  final _Win32? win32 = _bind();
  if (win32 == null) {
    return BenchWindowFit.failed(
      WindowFitStage.bind,
      _bindError ?? '原因未记录',
    );
  }
  final int? window = _ownWindow(win32);
  if (window == null) {
    return const BenchWindowFit.failed(WindowFitStage.noWindow, '');
  }
  final int hWnd = window;
  // 最小化 / 最大化的窗口改尺寸会被忽略，先还原到普通状态。
  win32.showWindow(hWnd, _swRestore);
  final int style = win32.getWindowLongPtr(hWnd, _gwlStyle);
  final int framelessStyle = style & ~(_wsCaption | _wsThickFrame);
  win32.setWindowLongPtr(hWnd, _gwlStyle, framelessStyle);
  final int ok = win32.setWindowPos(
    hWnd,
    0, // `hWndInsertAfter`：0 = `HWND_TOP`，配合 `SWP_NOZORDER` 实际不改层级。
    0, // x：原点。居中要查屏幕尺寸，那一步的绑定曾把整段设窗吞掉，不值得。
    0, // y
    width,
    height,
    _swpNoZOrder | _swpNoActivate | _swpFrameChanged | _swpShowWindow,
  );
  if (ok == 0) {
    return const BenchWindowFit.failed(WindowFitStage.resize, '');
  }
  // ⚠️ **必须在最后提到前台**，而且这不是「好看一点」：后台窗口会被 Windows 判成
  // 被遮挡（occluded），引擎跳过光栅 ⇒ 采样期一个 `FrameTiming` 都收不到（实测
  // 20 秒 0 帧间隔）。窗口尺寸设对了但没到前台，读数是零样本。
  win32.bringWindowToTop(hWnd);
  win32.setForegroundWindow(hWnd);
  return BenchWindowFit.ok(
    width: width,
    height: height,
    frameless: framelessStyle != style,
  );
}

_Win32? _win32Cache;
String? _bindError;

/// 绑定只做一次；绑不上返回 `null`，原因留在 [_bindError] 里。
///
/// ⚠️ `on Object` 这个 catch 曾经把「符号查不到」吞成「设不了」，三跑三版都因此
/// 失败得没信息 —— 现在至少把原文留住，由 [BenchWindowFit.detail] 说出去。
_Win32? _bind() {
  final _Win32? cached = _win32Cache;
  if (cached != null) {
    return cached;
  }
  try {
    return _win32Cache = _Win32();
  } on Object catch (error) {
    _bindError ??= '$error';
    return null;
  }
}

/// Win32 绑定失败的原因；绑得上返回 `null`。
///
/// 给用例留的窄口子（`TC-INF-063`）：它只碰符号表、**不碰任何窗口**，所以验
/// 「设窗的前提在本平台成立」时不会去改一个真实窗口。非 Windows 上恒为 `null`
/// —— 那里本就没有可绑的符号表，判据不成立。
String? win32BindError() {
  if (!Platform.isWindows) {
    return null;
  }
  return _bind() == null ? (_bindError ?? '原因未记录') : null;
}

/// 找出本进程那个**可见的顶层窗口**。
///
/// ⚠️ **不能用 `GetForegroundWindow`**：`flutter run` 从终端启动时前台是终端 ——
/// 第一版正是这么写的。也没用 `FindWindowW`（按 `FLUTTER_RUNNER_WIN32_WINDOW` 类名
/// 找）：那要拼 UTF-16 串并依赖 runner 的私有类名，Flutter 升级改了名就静默失效。
/// `EnumWindows` 只依赖「本进程有一个可见顶层窗口」这个事实。
int? _ownWindow(_Win32 win32) {
  int? found;
  final NativeCallable<_EnumProcNative> callable =
      NativeCallable<_EnumProcNative>.isolateLocal(
    (int hWnd, int lParam) {
      if (win32.isWindowVisible(hWnd) == 0) {
        return 1; // 继续枚举
      }
      if (_processIdOf(win32, hWnd) != win32.getCurrentProcessId()) {
        return 1;
      }
      found = hWnd;
      return 0; // 找到了，停
    },
    // 回调不该抛错，但真抛了也不能让枚举继续 —— 用 `0`（停止）当异常返回，
    // 于是「找不到窗口」与「回调出错」都表现为返回 `null`，由调用方降级。
    //
    // ⚠️ `exceptionalReturn` 是**命名**参数，写成位置参数（`isolateLocal(f, 0)`）
    // 编译不过，而且这个错**两道门禁都拦不住**：`FFI` 校验器把第一个实参之后的
    // 每个实参都当 `NamedArgument` 强转，撞上整数字面量就抛内部错、分析服务器整
    // 个中止，而 `flutter analyze` 在那种情况下照样打印「No issues found」并以 0
    // 退出；`flutter test` 不编译 `tool/`。只有真要出产物时才由前端编译器报错。
    exceptionalReturn: 0,
  );
  try {
    win32.enumWindows(callable.nativeFunction, 0);
  } finally {
    callable.close();
  }
  return found;
}

/// 句柄属于哪个进程。
///
/// 进程号靠 `GetWindowThreadProcessId` 的第二个出参拿 —— 它要一块可写内存，
/// 而 `dart:ffi` 不自带分配器（本项目零运行时依赖）。用 `LocalAlloc` / `LocalFree`：
/// 4 字节的临时缓冲，不引 `package:ffi` 只为这两个函数。
int _processIdOf(_Win32 win32, int hWnd) {
  final int memory = win32.localAlloc(_lmemZeroInit, 4);
  if (memory == 0) {
    return -1;
  }
  try {
    win32.getWindowThreadProcessId(hWnd, memory);
    return Pointer<Uint32>.fromAddress(memory).value;
  } finally {
    win32.localFree(memory);
  }
}

typedef _EnumProcNative = Int32 Function(IntPtr hWnd, IntPtr lParam);

typedef _EnumWindowsC = Int32 Function(
  Pointer<NativeFunction<_EnumProcNative>> lpEnumFunc,
  IntPtr lParam,
);
typedef _EnumWindowsD = int Function(
  Pointer<NativeFunction<_EnumProcNative>> lpEnumFunc,
  int lParam,
);

typedef _IntPtrIntC = Int32 Function(IntPtr hWnd, Int32 nCmdShow);
typedef _IntPtrIntD = int Function(int hWnd, int nCmdShow);

typedef _IntPtrToIntC = Int32 Function(IntPtr hWnd);
typedef _IntPtrToIntD = int Function(int hWnd);

typedef _GetWindowLongPtrC = IntPtr Function(IntPtr hWnd, Int32 nIndex);
typedef _GetWindowLongPtrD = int Function(int hWnd, int nIndex);

typedef _SetWindowLongPtrC = IntPtr Function(
  IntPtr hWnd,
  Int32 nIndex,
  IntPtr dwNewLong,
);
typedef _SetWindowLongPtrD = int Function(int hWnd, int nIndex, int dwNewLong);

typedef _SetWindowPosC = Int32 Function(
  IntPtr hWnd,
  IntPtr hWndInsertAfter,
  Int32 x,
  Int32 y,
  Int32 cx,
  Int32 cy,
  Uint32 uFlags,
);
typedef _SetWindowPosD = int Function(
  int hWnd,
  int hWndInsertAfter,
  int x,
  int y,
  int cx,
  int cy,
  int uFlags,
);

typedef _IsWindowVisibleC = Int32 Function(IntPtr hWnd);
typedef _IsWindowVisibleD = int Function(int hWnd);

typedef _GetWindowThreadProcessIdC = Uint32 Function(
  IntPtr hWnd,
  IntPtr lpdwProcessId,
);
typedef _GetWindowThreadProcessIdD = int Function(
  int hWnd,
  int lpdwProcessId,
);

typedef _Uint32VoidC = Uint32 Function();
typedef _Uint32VoidD = int Function();

typedef _LocalAllocC = IntPtr Function(Uint32 uFlags, IntPtr uBytes);
typedef _LocalAllocD = int Function(int uFlags, int uBytes);

typedef _LocalFreeC = IntPtr Function(IntPtr hMem);
typedef _LocalFreeD = int Function(int hMem);

class _Win32 {
  _Win32() {
    final DynamicLibrary user32 = DynamicLibrary.open('user32.dll');
    final DynamicLibrary kernel32 = DynamicLibrary.open('kernel32.dll');
    // ⚠️ 每个符号的**宿主 DLL** 要对：`lookupFunction` 查不到就抛，而本类的构造
    // 是「要么全成、要么全废」—— 一个符号错库，整段设窗就静默失效。
    // `GetSystemMetrics` 属 `User32.dll`，`v0.80.0`–`v0.80.1` 写的是 `kernel32`，
    // 三跑三版都死在构造这一行，而日志写的是「枚举不到窗口」。现在那一步已删除。
    enumWindows =
        user32.lookupFunction<_EnumWindowsC, _EnumWindowsD>('EnumWindows');
    showWindow = user32.lookupFunction<_IntPtrIntC, _IntPtrIntD>('ShowWindow');
    bringWindowToTop = user32
        .lookupFunction<_IntPtrToIntC, _IntPtrToIntD>('BringWindowToTop');
    setForegroundWindow = user32
        .lookupFunction<_IntPtrToIntC, _IntPtrToIntD>('SetForegroundWindow');
    getWindowLongPtr = user32.lookupFunction<
        _GetWindowLongPtrC, _GetWindowLongPtrD>('GetWindowLongPtrW');
    setWindowLongPtr = user32.lookupFunction<
        _SetWindowLongPtrC, _SetWindowLongPtrD>('SetWindowLongPtrW');
    setWindowPos =
        user32.lookupFunction<_SetWindowPosC, _SetWindowPosD>('SetWindowPos');
    isWindowVisible = user32.lookupFunction<
        _IsWindowVisibleC, _IsWindowVisibleD>('IsWindowVisible');
    getWindowThreadProcessId = user32.lookupFunction<
        _GetWindowThreadProcessIdC,
        _GetWindowThreadProcessIdD>('GetWindowThreadProcessId');
    getCurrentProcessId = kernel32.lookupFunction<_Uint32VoidC, _Uint32VoidD>(
        'GetCurrentProcessId');
    localAlloc =
        kernel32.lookupFunction<_LocalAllocC, _LocalAllocD>('LocalAlloc');
    localFree = kernel32.lookupFunction<_LocalFreeC, _LocalFreeD>('LocalFree');
  }

  late final int Function(
    Pointer<NativeFunction<_EnumProcNative>> lpEnumFunc,
    int lParam,
  ) enumWindows;
  late final int Function(int hWnd, int nCmdShow) showWindow;
  late final int Function(int hWnd) bringWindowToTop;
  late final int Function(int hWnd) setForegroundWindow;
  late final int Function(int hWnd, int nIndex) getWindowLongPtr;
  late final int Function(int hWnd, int nIndex, int dwNewLong) setWindowLongPtr;
  late final int Function(
    int hWnd,
    int hWndInsertAfter,
    int x,
    int y,
    int cx,
    int cy,
    int uFlags,
  ) setWindowPos;
  late final int Function(int hWnd) isWindowVisible;
  late final int Function(int hWnd, int lpdwProcessId) getWindowThreadProcessId;
  late final int Function() getCurrentProcessId;
  late final int Function(int uFlags, int uBytes) localAlloc;
  late final int Function(int hMem) localFree;
}

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
/// ## 失败不是新的失败点
///
/// 拿不到窗口（前台不是本进程）、非 Windows、API 绑定不上 —— 一律返回 `null`，
/// 由调用方退回「说清楚基准尺寸，等人手调」的老路。它只把前提自动化，不承担
/// 测量是否成立。
///
/// 只取**前台窗口**并校验进程号：`SetWindowPos` 用错句柄会把别人正在用的窗口
/// 改成 `1920×1080`，那比设不上更糟 —— 所以宁可返回 `null`。
library;

import 'dart:ffi';
import 'dart:io';

/// 设完的窗口矩形（物理像素）。
///
/// 宽度与高度是**设定值**，不是设完读回来的值：无边框窗口的客户区等于窗口矩形，
/// 两者本该相等。真值由调用方读视口核对 —— 这里返回「设了什么」，视口报「成了什么」，
/// 两个数分开记，才不会用一个去掩盖另一个。
class BenchWindowFit {
  const BenchWindowFit({
    required this.width,
    required this.height,
    required this.frameless,
  });

  final int width;

  final int height;

  /// 边框是否已去掉。`false` 表示样式写入失败但尺寸设上了 —— 此时客户区会比
  /// 设定值小一圈，调用方据此知道「别信这个尺寸」。
  final bool frameless;

  @override
  String toString() =>
      'BenchWindowFit(${width}x$height, frameless=$frameless)';
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
const int _smCxScreen = 0;
const int _smCyScreen = 1;
const int _lmemZeroInit = 0x0040;

/// 把前台窗口设成 [width]×[height] 物理像素的无边框客户区，并居中。
///
/// 成功返回设定值；任何一步不成立返回 `null`（非 Windows、拿不到本进程的前台
/// 窗口、API 绑定失败、`SetWindowPos` 返回 0）。
BenchWindowFit? fitBenchWindow({required int width, required int height}) {
  if (!Platform.isWindows) {
    return null;
  }
  final _Win32? win32 = _bind();
  if (win32 == null) {
    return null;
  }
  final int hWnd = win32.getForegroundWindow();
  if (hWnd == 0 || !_isOwnWindow(win32, hWnd)) {
    return null;
  }
  final int style = win32.getWindowLongPtr(hWnd, _gwlStyle);
  final int framelessStyle = style & ~(_wsCaption | _wsThickFrame);
  win32.setWindowLongPtr(hWnd, _gwlStyle, framelessStyle);
  final int screenWidth = win32.getSystemMetrics(_smCxScreen);
  final int screenHeight = win32.getSystemMetrics(_smCyScreen);
  final int left = ((screenWidth - width) ~/ 2).clamp(0, screenWidth);
  final int top = ((screenHeight - height) ~/ 2).clamp(0, screenHeight);
  final int ok = win32.setWindowPos(
    hWnd,
    0, // `hWndInsertAfter`：0 = `HWND_TOP`，配合 `SWP_NOZORDER` 实际不改层级。
    left,
    top,
    width,
    height,
    _swpNoZOrder | _swpNoActivate | _swpFrameChanged | _swpShowWindow,
  );
  if (ok == 0) {
    return null;
  }
  return BenchWindowFit(
    width: width,
    height: height,
    frameless: framelessStyle != style,
  );
}

_Win32? _win32Cache;

/// 绑定只做一次；绑不上返回 `null`（某些精简运行时缺 `user32.dll` 的导出）。
_Win32? _bind() {
  try {
    return _win32Cache ??= _Win32();
  } on Object {
    return null;
  }
}

/// 句柄属于本进程、且可见。
///
/// 进程号靠 `GetWindowThreadProcessId` 的第二个出参拿 —— 它要一块可写内存，
/// 而 `dart:ffi` 不自带分配器（本项目零运行时依赖）。用 `LocalAlloc` / `LocalFree`：
/// 4 字节的临时缓冲，不引 `package:ffi` 只为这两个函数。
bool _isOwnWindow(_Win32 win32, int hWnd) {
  if (win32.isWindowVisible(hWnd) == 0) {
    return false;
  }
  final int memory = win32.localAlloc(_lmemZeroInit, 4);
  if (memory == 0) {
    return false;
  }
  try {
    win32.getWindowThreadProcessId(hWnd, memory);
    return Pointer<Uint32>.fromAddress(memory).value ==
        win32.getCurrentProcessId();
  } finally {
    win32.localFree(memory);
  }
}

typedef _GetForegroundWindowC = IntPtr Function();
typedef _GetForegroundWindowD = int Function();

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

typedef _Int32Int32C = Int32 Function(Int32 index);
typedef _Int32Int32D = int Function(int index);

typedef _LocalAllocC = IntPtr Function(Uint32 uFlags, IntPtr uBytes);
typedef _LocalAllocD = int Function(int uFlags, int uBytes);

typedef _LocalFreeC = IntPtr Function(IntPtr hMem);
typedef _LocalFreeD = int Function(int hMem);

class _Win32 {
  _Win32() {
    final DynamicLibrary user32 = DynamicLibrary.open('user32.dll');
    final DynamicLibrary kernel32 = DynamicLibrary.open('kernel32.dll');
    getForegroundWindow = user32.lookupFunction<
        _GetForegroundWindowC, _GetForegroundWindowD>('GetForegroundWindow');
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
    getSystemMetrics = kernel32.lookupFunction<_Int32Int32C, _Int32Int32D>(
        'GetSystemMetrics');
    localAlloc =
        kernel32.lookupFunction<_LocalAllocC, _LocalAllocD>('LocalAlloc');
    localFree = kernel32.lookupFunction<_LocalFreeC, _LocalFreeD>('LocalFree');
  }

  late final int Function() getForegroundWindow;
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
  late final int Function(int index) getSystemMetrics;
  late final int Function(int uFlags, int uBytes) localAlloc;
  late final int Function(int hMem) localFree;
}

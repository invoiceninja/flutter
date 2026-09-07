#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <shellapi.h>
#include <windowsx.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

/// Registry home for the persisted window placement (size / position /
/// maximized), per the desktop window-state contract
/// (docs/desktop-window-state.md). Raw WINDOWPLACEMENT as REG_BINARY — the
/// Get/Set pair round-trips workspace coordinates consistently under
/// per-monitor-v2 DPI. Under an MSIX install HKCU writes are virtualized per
/// package, so dev and Store builds don't fight over the value.
constexpr const wchar_t kPlacementRegKey[] = L"Software\\InvoiceNinja\\Window";
constexpr const wchar_t kPlacementRegValue[] = L"Placement";

/// Kill switch for the app-painted title bar, beside the placement value.
///
/// Two ways in, on purpose: a developer sets IN_DISABLE_CUSTOM_FRAME=1, but a
/// Store-installed user cannot set an environment variable, so a DWORD of 0
/// here restores the stock OS caption. Worth having because the failure mode is
/// severe and self-concealing — if the Flutter chrome ever fails to render, a
/// frameless window has no close button, no minimize and no drag handle.
constexpr const wchar_t kCustomFrameRegValue[] = L"CustomFrame";

bool CustomFrameEnabled() {
  wchar_t buffer[8] = {};
  const DWORD written =
      GetEnvironmentVariable(L"IN_DISABLE_CUSTOM_FRAME", buffer, 8);
  // Exactly "1". GetEnvironmentVariable returns the character count excluding
  // the terminator, so testing it is a whole-string compare with no <wchar.h>
  // dependency — and testing buffer[0] alone would let "10" or "1abc" through.
  if (written == 1 && buffer[0] == L'1') {
    return false;
  }
  DWORD value = 1;
  DWORD size = sizeof(value);
  if (RegGetValue(HKEY_CURRENT_USER, kPlacementRegKey, kCustomFrameRegValue,
                  RRF_RT_REG_DWORD, nullptr, &value, &size) == ERROR_SUCCESS) {
    return value != 0;
  }
  return true;
}

/// Thickness of the (mostly invisible) sizing border, in physical pixels.
///
/// PerMonitorV2 is declared in runner.exe.manifest, so the un-suffixed
/// GetSystemMetrics would answer for the wrong DPI on a secondary monitor.
/// SM_CXPADDEDBORDER is axis-agnostic — it is added to both — hence the CY
/// frame plus the CX padded border.
int ResizeBorderThickness(HWND hwnd) {
  const UINT dpi = FlutterDesktopGetDpiForHWND(hwnd);
  return GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi) +
         GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
}

/// Whether an auto-hidden taskbar is docked to |edge| of |monitor|.
///
/// ABM_GETAUTOHIDEBAREX, not ABM_GETAUTOHIDEBAR: the latter only ever answers
/// for the primary monitor, which is the bug on a dual-monitor setup.
bool HasAutohideTaskbar(UINT edge, const RECT& monitor) {
  APPBARDATA data = {};
  data.cbSize = sizeof(APPBARDATA);
  data.uEdge = edge;
  data.rc = monitor;
  return SHAppBarMessage(ABM_GETAUTOHIDEBAREX, &data) != 0;
}

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

// Flips |window|'s caption between the standard light and dark immersive
// styling. A harmless no-op on Windows versions without dark-mode caption
// support (DwmSetWindowAttribute just returns a failure HRESULT).
void ApplyImmersiveDarkMode(HWND window, bool dark) {
  BOOL value = dark ? TRUE : FALSE;
  DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE, &value,
                        sizeof(value));
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  // Read once, before the window exists: WM_NCCALCSIZE arrives from inside
  // CreateWindow, so the flag has to be settled by then.
  custom_frame_ = CustomFrameEnabled();

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  // Restore-before-show: the window has no WS_VISIBLE yet and is only shown
  // at the first Flutter frame (FlutterWindow::OnCreate -> Show), and this
  // runs before OnCreate reads GetClientArea() — so the Flutter surface is
  // created at its final size with no startup resize flicker (the macOS
  // setFrameAutosaveName parity point).
  RestorePlacement();

  // Force one non-client recalculation now that the custom-frame handler is
  // installed. Without it the window is shown with the caption the ORIGINAL
  // creation-time frame reserved, so the app starts with the OS title bar AND
  // the drawn band stacked — and the first maximize or resize silently "fixes"
  // it, because that is simply the next thing to send WM_NCCALCSIZE. It runs
  // while the window is still hidden (Show() waits for Flutter's first frame),
  // so nothing flickers.
  if (custom_frame_) {
    SetWindowPos(window, nullptr, 0, 0, 0, 0,
                 SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                     SWP_NOACTIVATE);
  }

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_,
                    restore_maximized_ ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
}

void Win32Window::SavePlacement() {
  if (!window_handle_ || !placement_restored_) {
    return;
  }
  WINDOWPLACEMENT placement = {sizeof(WINDOWPLACEMENT)};
  if (!GetWindowPlacement(window_handle_, &placement)) {
    return;
  }
  RegSetKeyValue(HKEY_CURRENT_USER, kPlacementRegKey, kPlacementRegValue,
                 REG_BINARY, &placement, sizeof(placement));
}

bool Win32Window::RestorePlacement() {
  // Whatever happens below, saves are safe from here on (the creation-time
  // WM_SIZE has already passed, so nothing clobbers the stored value before
  // it was read).
  struct Arm {
    bool* flag;
    ~Arm() { *flag = true; }
  } arm{&placement_restored_};

  WINDOWPLACEMENT placement = {};
  DWORD size = sizeof(placement);
  LSTATUS result =
      RegGetValue(HKEY_CURRENT_USER, kPlacementRegKey, kPlacementRegValue,
                  RRF_RT_REG_BINARY, nullptr, &placement, &size);
  if (result != ERROR_SUCCESS || size != sizeof(placement) ||
      placement.length != sizeof(placement)) {
    return false;
  }
  // Off-screen guard: the saved rect may reference a monitor that no longer
  // exists (undocked laptop). If it doesn't intersect the nearest monitor's
  // work area at all, fall back to the template default geometry.
  HMONITOR monitor =
      MonitorFromRect(&placement.rcNormalPosition, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info = {sizeof(MONITORINFO)};
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return false;
  }
  RECT intersection;
  if (!IntersectRect(&intersection, &placement.rcNormalPosition,
                     &monitor_info.rcWork)) {
    return false;
  }
  // Never restore minimized (a minimized-at-exit save comes back normal);
  // carry a maximized exit into Show() instead of flashing the normal rect.
  restore_maximized_ = placement.showCmd == SW_SHOWMAXIMIZED;
  placement.showCmd = SW_HIDE;
  return SetWindowPlacement(window_handle_, &placement);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      // Last-chance save while the hwnd is still valid — catches
      // programmatic moves that never produced a size/move message.
      SavePlacement();
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_ENTERSIZEMOVE:
      in_size_move_ = true;
      return 0;

    case WM_EXITSIZEMOVE:
      // End of an interactive drag/resize — one save instead of the
      // per-tick WM_SIZE/WM_MOVE spam during the gesture.
      in_size_move_ = false;
      SavePlacement();
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      // No MaybePublishWindowChrome() here: the payload carries no DPI field
      // (Dart owns the band height), so maximized/active are unchanged and the
      // dedupe would suppress it anyway. Add the call back only alongside a
      // scale factor on the wire.
      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      // Caption-button maximize/restore emits no WM_EXITSIZEMOVE — persist
      // here, skipping the per-tick spam of an interactive drag.
      if (!in_size_move_ &&
          (wparam == SIZE_MAXIMIZED || wparam == SIZE_RESTORED)) {
        SavePlacement();
      }
      // Deliberately NOT gated on |in_size_move_|, unlike SavePlacement above:
      // dragging a maximized window off the top restores it mid-drag, and the
      // drawn glyph has to follow. The flood that would otherwise cause (
      // SIZE_RESTORED fires every tick of an interactive resize) is handled by
      // deduping inside MaybePublishWindowChrome instead.
      MaybePublishWindowChrome();
      return 0;
    }

    case WM_NCCALCSIZE: {
      // Drop the caption while KEEPING the sizing border, so resize, Aero Snap,
      // the minimize animation, the DWM shadow and Win11 rounded corners all
      // survive — those key off the window STYLES, which are deliberately left
      // as WS_OVERLAPPEDWINDOW, not off who painted the caption. Keeping the
      // styles is also why the persisted WINDOWPLACEMENT needs no migration:
      // AdjustWindowRectEx is unchanged, so a stored window rect still means
      // what it meant before.
      if (!custom_frame_ || wparam == FALSE) {
        break;  // fall through to DefWindowProc
      }
      auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      // rgrc[0] arrives as the proposed WINDOW rect; remember its top before
      // the default proc turns rgrc[0] into the client rect.
      const LONG proposed_top = params->rgrc[0].top;
      DefWindowProc(hwnd, message, wparam, lparam);
      // Reclaim only the caption. Left/right/bottom keep the default proc's
      // insets, which ARE the invisible resize border — so Windows keeps
      // hit-testing those three edges natively, for free.
      params->rgrc[0].top = proposed_top;
      if (IsZoomed(hwnd)) {
        ApplyMaximizedInsets(hwnd, &params->rgrc[0]);
      }
      return 0;
    }

    case WM_NCHITTEST: {
      // DefWindowProc does NOT consult WM_NCCALCSIZE: it still reports
      // HTCAPTION / HTMINBUTTON / ... over the strip the caption used to
      // occupy, which would leave the top of the Flutter surface dead to the
      // mouse and dragging the window on every click.
      if (!custom_frame_) {
        break;
      }
      const LRESULT hit = DefWindowProc(hwnd, message, wparam, lparam);
      switch (hit) {
        case HTNOWHERE:
        case HTLEFT:
        case HTRIGHT:
        case HTBOTTOM:
        case HTBOTTOMLEFT:
        case HTBOTTOMRIGHT:
          return hit;  // a real frame edge — leave it native
        default:
          break;
      }
      // A maximized window has no resize edges at all.
      if (IsZoomed(hwnd)) {
        return HTCLIENT;
      }
      // The top edge became client area, so synthesize its handles.
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      RECT frame;
      GetWindowRect(hwnd, &frame);
      const int border = ResizeBorderThickness(hwnd);
      if (point.y < frame.top + border) {
        if (point.x < frame.left + border) return HTTOPLEFT;
        if (point.x >= frame.right - border) return HTTOPRIGHT;
        return HTTOP;
      }
      // Everything the default proc still calls caption is Flutter's now.
      // NOTE: deliberately never HTMAXBUTTON — that would hand the OS all mouse
      // input over the drawn maximize button (for the Win11 Snap Layouts
      // flyout), forcing hover and clicks to be driven from WM_NCMOUSEMOVE and
      // the button's rect to be published from Dart on every layout. Win+Z,
      // drag-to-edge and Win+arrow snapping all still work without it.
      return HTCLIENT;
    }

    case WM_GETMINMAXINFO: {
      // Keep the window wide/tall enough that the title bar can't be crushed
      // to nothing (there is no OS caption left to enforce a floor).
      if (!custom_frame_ || window_handle_ == nullptr) {
        break;
      }
      const double scale = FlutterDesktopGetDpiForHWND(hwnd) / 96.0;
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = Scale(640, scale);
      info->ptMinTrackSize.y = Scale(480, scale);
      return 0;
    }

    case WM_SETTINGCHANGE:
      // WM_SETTINGCHANGE is broadcast for policy, accessibility, locale and
      // environment changes too — every one of which would otherwise force a
      // full frame recompute plus five SHAppBarMessage round trips while
      // maximized. SPI_SETWORKAREA is the only one that can move the taskbar.
      if (wparam != SPI_SETWORKAREA) break;
      [[fallthrough]];
    case WM_DISPLAYCHANGE:
      // WM_NCCALCSIZE is only recomputed on a frame change, so toggling the
      // taskbar's auto-hide while already maximized would otherwise leave the
      // stale inset behind. Deliberately falls through to DefWindowProc.
      if (custom_frame_ && IsZoomed(hwnd)) {
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                     SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE |
                         SWP_NOZORDER | SWP_NOACTIVATE);
      }
      break;

    case WM_ACTIVATE:
      // Take the answer from the message that carries it. Inferring it from
      // GetActiveWindow() here cannot work: SetFocus below is documented to
      // activate the window receiving focus (or its parent), so sampling after
      // it reads the deactivation back as ACTIVE — and MaybePublishWindowChrome
      // dedupes, so that wrong value then latches until an unrelated WM_SIZE.
      // The drawn glyphs would never dim, which is the one state the flag
      // exists to show.
      active_ = LOWORD(wparam) != WA_INACTIVE;
      active_seeded_ = true;
      // Only chase focus into the child when actually activating; the template
      // did this unconditionally, which is half of the bug above.
      if (child_content_ != nullptr && active_) {
        SetFocus(child_content_);
      }
      MaybePublishWindowChrome();
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      // Once Flutter has pushed an explicit theme it owns the caption: reapply
      // that rather than reverting to the OS value on an accent-color change.
      if (flutter_pushed_theme_) {
        ApplyImmersiveDarkMode(hwnd, pushed_dark_);
      } else {
        UpdateTheme(hwnd);
      }
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::ApplyMaximizedInsets(HWND hwnd, RECT* client) {
  // (a) A maximized window's rect is the work area GROWN by the frame on every
  // side, so the caption normally falls off-screen and the client exactly fills
  // the work area. Having reclaimed the caption, the first ~8 physical pixels
  // of the Flutter surface — the top of the band, the top of the close button —
  // would render above the visible screen. Only the top needs this; the default
  // proc already got the other three right.
  client->top += ResizeBorderThickness(hwnd);

  // (b) With auto-hide on, the work area is the full monitor (the shell
  // reserves ~2 px), so a maximized window covers the taskbar's edge and the
  // shell will not un-hide it — the taskbar becomes unreachable until the user
  // un-maximizes. A normal window is saved by its frame; this one isn't.
  APPBARDATA state = {};
  state.cbSize = sizeof(APPBARDATA);
  if ((SHAppBarMessage(ABM_GETSTATE, &state) & ABS_AUTOHIDE) == 0) {
    return;
  }
  MONITORINFO monitor = {};
  monitor.cbSize = sizeof(MONITORINFO);
  if (!GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                      &monitor)) {
    return;
  }
  // Each edge is tested independently — several auto-hide bars can coexist.
  if (HasAutohideTaskbar(ABE_TOP, monitor.rcMonitor)) client->top += 1;
  if (HasAutohideTaskbar(ABE_BOTTOM, monitor.rcMonitor)) client->bottom -= 1;
  if (HasAutohideTaskbar(ABE_LEFT, monitor.rcMonitor)) client->left += 1;
  if (HasAutohideTaskbar(ABE_RIGHT, monitor.rcMonitor)) client->right -= 1;
}

void Win32Window::BeginDrag() {
  if (window_handle_ == nullptr) return;
  POINT cursor;
  GetCursorPos(&cursor);
  ReleaseCapture();
  // PostMessage, not SendMessage: the OS move loop pumps its own
  // GetMessage/DispatchMessage, and SendMessage would spin it from inside the
  // embedder's task-runner callback — re-entering task dispatch with a task
  // still on the stack, so any Dart->platform call arriving mid-drag runs
  // inside the drag (BeginDrag can even re-enter itself), and this method's
  // channel reply is withheld for the whole gesture.
  //
  // Posting WM_SYSCOMMAND reaches the same modal loop from the WndProc instead,
  // and because the OS then owns the whole down/up pairing there is no
  // swallowed button-up to synthesize back to the Flutter child.
  PostMessage(window_handle_, WM_SYSCOMMAND, SC_MOVE | HTCAPTION,
              MAKELPARAM(cursor.x, cursor.y));
}

void Win32Window::Minimize() {
  if (window_handle_ != nullptr) ShowWindow(window_handle_, SW_MINIMIZE);
}

void Win32Window::ToggleMaximize() {
  if (window_handle_ == nullptr) return;
  ShowWindow(window_handle_, IsZoomed(window_handle_) ? SW_RESTORE
                                                      : SW_MAXIMIZE);
}

void Win32Window::RequestClose() {
  // Post, not Send, so the channel handler returns before teardown begins.
  if (window_handle_ != nullptr) {
    PostMessage(window_handle_, WM_CLOSE, 0, 0);
  }
}

void Win32Window::ShowSystemMenu() {
  if (window_handle_ == nullptr) return;
  // The cursor is the correct anchor by construction — the right-click that
  // routed this call has only just happened — and reading it here avoids
  // converting Flutter's logical, client-relative point into the physical,
  // screen-relative one TrackPopupMenu expects. Both of those errors nearly
  // vanish on a maximized window at 100% scale, so a conversion bug here would
  // look correct in exactly the setup it would first be tried in.
  POINT cursor;
  GetCursorPos(&cursor);
  HMENU menu = GetSystemMenu(window_handle_, FALSE);
  if (menu == nullptr) return;
  // Keep the enabled/disabled states honest for the current window state
  // (Maximize is greyed while maximized, and so on).
  const bool zoomed = IsZoomed(window_handle_) != FALSE;
  const UINT restore = zoomed ? MF_ENABLED : MF_GRAYED;
  const UINT normal = zoomed ? MF_GRAYED : MF_ENABLED;
  EnableMenuItem(menu, SC_RESTORE, MF_BYCOMMAND | restore);
  EnableMenuItem(menu, SC_MOVE, MF_BYCOMMAND | normal);
  EnableMenuItem(menu, SC_SIZE, MF_BYCOMMAND | normal);
  EnableMenuItem(menu, SC_MAXIMIZE, MF_BYCOMMAND | normal);
  EnableMenuItem(menu, SC_MINIMIZE, MF_BYCOMMAND | MF_ENABLED);
  const int command = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_LEFTALIGN | TPM_TOPALIGN | TPM_RIGHTBUTTON,
      cursor.x, cursor.y, 0, window_handle_, nullptr);
  if (command != 0) {
    PostMessage(window_handle_, WM_SYSCOMMAND, command, 0);
  }
}

bool Win32Window::IsWindowMaximized() const {
  return window_handle_ != nullptr && IsZoomed(window_handle_) != FALSE;
}

bool Win32Window::IsWindowFocused() {
  if (window_handle_ == nullptr) return false;
  // Before the first WM_ACTIVATE there is nothing to have recorded, and the
  // `windowChrome` pull from `main.dart` runs in exactly that window — so seed
  // once from the foreground window rather than reporting a focused app as
  // inactive for a frame. GetForegroundWindow is system-wide; GetActiveWindow
  // would answer only for this thread's queue, and is what the WM_ACTIVATE
  // branch above deliberately stopped using.
  if (!active_seeded_) {
    active_ = GetForegroundWindow() == window_handle_;
    active_seeded_ = true;
  }
  return active_;
}

void Win32Window::SetContentSize(double width, double height,
                                 double* out_width, double* out_height) {
  *out_width = 0;
  *out_height = 0;
  if (window_handle_ == nullptr) return;
  // IsZoomed is false for a MINIMIZED window, and GetClientRect on one returns
  // 0x0 — which would make the chrome deltas below the whole bogus placeholder
  // extent. Restore for either state.
  if (IsIconic(window_handle_) || IsZoomed(window_handle_)) {
    ShowWindow(window_handle_, SW_RESTORE);
  }
  // The values crossed a channel as doubles: static_cast<int> of NaN/infinity
  // is undefined and a negative width yields a negative cx.
  if (!(width >= 1.0) || !(height >= 1.0) || width > 100000.0 ||
      height > 100000.0) {
    return;
  }
  const double scale = FlutterDesktopGetDpiForHWND(window_handle_) / 96.0;
  RECT frame;
  RECT client;
  GetWindowRect(window_handle_, &frame);
  GetClientRect(window_handle_, &client);
  const int chrome_w = (frame.right - frame.left) - client.right;
  const int chrome_h = (frame.bottom - frame.top) - client.bottom;
  // SWP_NOMOVE pins the window-rect top-left, and the invisible-border offset
  // is constant, so the VISUAL top-left is preserved with no
  // DWMWA_EXTENDED_FRAME_BOUNDS arithmetic.
  //
  // Note SetWindowPos is NOT screen-constrained, unlike AppKit's setFrame — so
  // a screenshot size larger than the display actually applies here, and the
  // Debug Panel's clamp warning simply fires less often on Windows than on
  // macOS. That asymmetry is intended; don't "fix" it.
  SetWindowPos(window_handle_, nullptr, 0, 0,
               static_cast<int>(width * scale) + chrome_w,
               static_cast<int>(height * scale) + chrome_h,
               SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  GetClientRect(window_handle_, &client);
  *out_width = client.right / scale;
  *out_height = client.bottom / scale;
}

void Win32Window::MaybePublishWindowChrome() {
  if (window_handle_ == nullptr) return;
  const bool maximized = IsWindowMaximized();
  const bool active = IsWindowFocused();
  if (published_any_ && maximized == published_maximized_ &&
      active == published_active_) {
    return;
  }
  // Latch only what actually went out. OnWindowChromeChanged is a no-op until
  // FlutterWindow::OnCreate builds the channel, and every message during
  // CreateWindow arrives before that — caching there would mark a payload as
  // published that no one ever received, and the dedupe would then suppress it
  // for good if the state happened not to change again.
  if (!CanPublishWindowChrome()) return;
  published_any_ = true;
  published_maximized_ = maximized;
  published_active_ = active;
  OnWindowChromeChanged();
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    ApplyImmersiveDarkMode(window, light_mode == 0);
  }
}

void Win32Window::SetThemeBrightness(bool dark) {
  // Flutter is now the source of truth for the caption theme; remember the
  // value so OS-driven theme messages reapply it instead of reading the
  // registry (which tracks the OS theme, not the app's chosen theme).
  flutter_pushed_theme_ = true;
  pushed_dark_ = dark;
  if (window_handle_ != nullptr) {
    ApplyImmersiveDarkMode(window_handle_, dark);
  }
}

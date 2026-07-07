#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

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
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
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

#include "flutter_window.h"

#include <optional>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Mirror the macOS runner: let Flutter drive the native window theme. Dart
  // pushes the app's resolved brightness here whenever the theme changes.
  //
  // Only `brightness` is read, and now for a stronger reason than "macOS-only".
  // With the custom frame the caption is GONE, so DWMWA_CAPTION_COLOR and
  // DWMWA_TEXT_COLOR have nothing left to paint — `titleHex` is structurally
  // dead on Windows, not merely unused. What survives is the 1-px DWM border,
  // and ApplyImmersiveDarkMode below matches its brightness to the app's.
  //
  // `borderHex` IS used: DWMWA_BORDER_COLOR paints that 1-px border. The DWM
  // default is the user's system accent while the window is focused, so a dark
  // accent frames a light app in a dark line. Losing the accent-on-focus
  // affordance is the price; matching the app is worth more, because the border
  // is the only chrome the OS still draws for us.
  theme_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(),
      "invoice_ninja/native_window_theme",
      &flutter::StandardMethodCodec::GetInstance());
  theme_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() != "apply") {
          result->NotImplemented();
          return;
        }
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (args != nullptr) {
          // Optional and applied first, so a runner newer than the Dart side
          // still styles the caption from `brightness` below.
          const auto border = args->find(flutter::EncodableValue("borderHex"));
          if (border != args->end()) {
            if (const auto* hex = std::get_if<std::string>(&border->second)) {
              SetBorderColor(*hex);
            }
          }
          const auto it = args->find(flutter::EncodableValue("brightness"));
          if (it != args->end()) {
            if (const auto* brightness =
                    std::get_if<std::string>(&it->second)) {
              SetThemeBrightness(*brightness == "dark");
              result->Success();
              return;
            }
          }
        }
        result->Error("bad_args", "expected a 'brightness' string");
      });

  // Drives the app-painted title bar. The window has no OS caption once the
  // custom frame is on, so every affordance a caption provided is routed back
  // here. Window mechanics stay in Win32Window; this is only the adapter.
  window_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(),
      "invoice_ninja/native_window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const std::string& method = call.method_name();
        if (method == "startDrag") {
          BeginDrag();
          result->Success();
        } else if (method == "minimize") {
          Minimize();
          result->Success();
        } else if (method == "toggleMaximize" || method == "doubleClick") {
          // Windows has no per-user title-bar double-click setting to honour,
          // unlike macOS's AppleActionOnDoubleClick — maximize is the action.
          ToggleMaximize();
          result->Success();
        } else if (method == "close") {
          RequestClose();
          result->Success();
        } else if (method == "showSystemMenu") {
          // No coordinates on the wire — ShowSystemMenu anchors on the cursor.
          ShowSystemMenu();
          result->Success();
        } else if (method == "setWindowButtonsHidden") {
          // No native buttons exist here — the cluster is Flutter's own, so
          // hiding it is a Dart-side concern. Succeed rather than returning
          // NotImplemented, or the Debug Panel logs an error on every toggle.
          result->Success();
        } else if (method == "windowChrome") {
          result->Success(flutter::EncodableValue(WindowChromePayload()));
        } else if (method == "setContentSize") {
          double width = 0;
          double height = 0;
          if (const auto* args =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto iw = args->find(flutter::EncodableValue("width"));
            const auto ih = args->find(flutter::EncodableValue("height"));
            if (iw != args->end()) {
              if (const auto* v = std::get_if<double>(&iw->second)) width = *v;
            }
            if (ih != args->end()) {
              if (const auto* v = std::get_if<double>(&ih->second)) height = *v;
            }
          }
          double out_width = 0;
          double out_height = 0;
          SetContentSize(width, height, &out_width, &out_height);
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("width"),
               flutter::EncodableValue(out_width)},
              {flutter::EncodableValue("height"),
               flutter::EncodableValue(out_height)},
          }));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

flutter::EncodableMap FlutterWindow::WindowChromePayload() {
  return flutter::EncodableMap{
      // No Windows fullscreen mechanism yet — see docs/desktop-window-state.md.
      {flutter::EncodableValue("fullscreen"), flutter::EncodableValue(false)},
      {flutter::EncodableValue("maximized"),
       flutter::EncodableValue(IsWindowMaximized())},
      {flutter::EncodableValue("active"),
       flutter::EncodableValue(IsWindowFocused())},
      // False when the kill switch declined the custom frame. Dart draws no
      // band of its own in that case, so the stock caption is the only chrome
      // rather than a second one underneath it.
      {flutter::EncodableValue("customFrame"),
       flutter::EncodableValue(custom_frame())},
      // Explicit zero, and it has to be explicit: WindowChrome.fromMap falls
      // back to the macOS default of 70 when the KEY IS ABSENT, and only
      // preserves a zero that was actually sent. No native buttons float over
      // this window's content — Flutter draws its own, trailing.
      {flutter::EncodableValue("buttonsTrailingX"),
       flutter::EncodableValue(0.0)},
      // Deliberately no `captionHeight`: Dart owns the band height here
      // (kAppTitleBarHeight). There is no OS titlebar left to measure once the
      // frame is custom, and reporting it would make the first frame lay out at
      // one height and the second at another.
  };
}

bool FlutterWindow::CanPublishWindowChrome() {
  return window_channel_ != nullptr;
}

void FlutterWindow::OnWindowChromeChanged() {
  if (window_channel_ == nullptr) return;
  window_channel_->InvokeMethod(
      "windowChromeChanged",
      std::make_unique<flutter::EncodableValue>(WindowChromePayload()));
}

void FlutterWindow::OnDestroy() {
  // Tear the channels down before the engine/messenger they borrow from.
  window_channel_ = nullptr;
  theme_channel_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

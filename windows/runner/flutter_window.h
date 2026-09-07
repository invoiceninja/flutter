#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

  // Win32Window: pushes the measured chrome to Dart as `windowChromeChanged`.
  void OnWindowChromeChanged() override;
  bool CanPublishWindowChrome() override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Receives theme pushes from Dart (invoice_ninja/native_window_theme) and
  // forwards the resolved brightness to the native caption styling.
  std::unique_ptr<flutter::MethodChannel<>> theme_channel_;

  // Drives the app-painted title bar: window drag / minimize / maximize /
  // close / system menu from Dart, and the chrome pushes back the other way.
  std::unique_ptr<flutter::MethodChannel<>> window_channel_;

  // The payload behind both the `windowChrome` pull and the
  // `windowChromeChanged` push, so the two can never disagree.
  flutter::EncodableMap WindowChromePayload();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_

#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. New windows are created on the default monitor. Window
  // sizes are specified to the OS in physical pixels, hence to ensure a
  // consistent size this function will scale the inputted width and height as
  // as appropriate for the default monitor. The window is invisible until
  // |Show| is called. Returns true if the window was created successfully.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Show the current window. Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing Window handle to enable clients to set icon and other
  // window properties. Returns nullptr if the window has been destroyed.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Return a RECT representing the bounds of the current client area.
  RECT GetClientArea();

 protected:
  // Processes and route salient window messages for mouse handling,
  // size change and DPI. Delegates handling of these to member overloads that
  // inheriting classes can handle.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when CreateAndShow is called, allowing subclass window-related
  // setup. Subclasses should return false if setup fails.
  virtual bool OnCreate();

  // Called when Destroy is called.
  virtual void OnDestroy();

  // Applies an explicit light/dark caption styling pushed from Flutter and
  // marks Flutter as the owner of the window theme, so subsequent OS-driven
  // theme messages defer to this value instead of the system registry.
  void SetThemeBrightness(bool dark);

  // Paints the 1-px DWM window border the app's own colour, from an "RRGGBB"
  // string. Without it the border follows the user's system accent while
  // focused, which is a dark frame around a light app on a dark accent.
  void SetBorderColor(const std::string& hex);

  // --- Window actions driven by the app-painted title bar ------------------
  // The window has no caption of its own once |custom_frame_| is on, so every
  // affordance a caption used to provide is routed back here from Flutter over
  // the `invoice_ninja/native_window` channel. Window mechanics live in this
  // class; `FlutterWindow` is only the channel adapter (same split as
  // |SetThemeBrightness|).

  // Hands the window to the OS move loop, exactly as dragging a real caption
  // would — so Aero Snap, shake-to-minimize and drag-to-restore all come free.
  void BeginDrag();
  void Minimize();
  void ToggleMaximize();
  void RequestClose();
  // Opens the standard system menu (Move / Size / Close) at the cursor. The
  // band is client area now, so the right-click arrives from Flutter rather
  // than as WM_NCRBUTTONUP. Takes no coordinates on purpose — Flutter's are
  // logical and client-relative, TrackPopupMenu wants physical and screen.
  void ShowSystemMenu();
  // NOT `IsMaximized` / `CloseWindow`: <windowsx.h> defines `IsMaximized(hwnd)` as a
  // function-like macro (and <winuser.h> declares `CloseWindow(HWND)`). A one-parameter
  // function-like macro DOES expand when invoked as `IsMaximized()` — that is one
  // argument consisting of no tokens — so the member silently becomes `IsZoomed()`.
  // Worse, in any translation unit that includes <windowsx.h> BEFORE this header, the
  // macro would rewrite this declaration too, hiding the real Win32 API from every
  // `IsZoomed(hwnd)` call site in the file.
  bool IsWindowMaximized() const;
  // Not const: seeds its cache on first read (see the definition).
  bool IsWindowFocused();

  // Resizes the CLIENT area to |width|x|height| logical points, preserving the
  // visual top-left. Writes the achieved size back so Dart can detect clamping.
  void SetContentSize(double width, double height, double* out_width,
                      double* out_height);

  // Overridden by |FlutterWindow| to push `windowChromeChanged`. Called only
  // when the reported payload actually changes — WM_SIZE fires SIZE_RESTORED on
  // every tick of an interactive resize, which would otherwise flood the
  // channel at 60+ Hz.
  // Whether this window actually dropped its OS caption. Reported to Dart so
  // the app does not paint a title bar over one that is still there — the kill
  // switch would otherwise render as two stacked bars.
  bool custom_frame() const { return custom_frame_; }

  virtual void OnWindowChromeChanged() {}
  // Whether |OnWindowChromeChanged| would actually reach Dart. Overridden by
  // FlutterWindow; without it the dedupe cache below would record payloads that
  // were never sent (the channel does not exist during CreateWindow).
  virtual bool CanPublishWindowChrome() { return false; }
  void MaybePublishWindowChrome();


 private:
  friend class WindowClassRegistrar;

  // OS callback called by message pump. Handles the WM_NCCREATE message which
  // is passed when the non-client area is being created and enables automatic
  // non-client DPI scaling so that the non-client area automatically
  // responds to changes in DPI. All other messages are handled by
  // MessageHandler.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Retrieves a class instance pointer for |window|
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Update the window frame's theme to match the system theme.
  static void UpdateTheme(HWND const window);

  // Persist the current WINDOWPLACEMENT (size, position, maximized) to the
  // registry. No-op until |RestorePlacement| has run — the WM_SIZE fired
  // inside CreateWindow would otherwise overwrite the saved placement with
  // the template default before restore ever reads it.
  void SavePlacement();

  // Apply the persisted placement (if any) while the window is still hidden,
  // clamped to a visible monitor. Returns false (leaving the template
  // default geometry) when nothing usable is stored. Never restores
  // minimized; a maximized exit is re-applied by |Show|.
  bool RestorePlacement();

  // Adjusts a maximized window's client rect: a maximized frameless window's
  // rect is the work area GROWN by the frame, so the top of the Flutter
  // surface would render off-screen, and it covers an auto-hide taskbar
  // outright. See the definition for both.
  void ApplyMaximizedInsets(HWND hwnd, RECT* client);

  bool quit_on_close_ = false;

  // False disables the custom frame entirely and restores the stock OS title
  // bar. Read once before CreateWindow from IN_DISABLE_CUSTOM_FRAME=1 or the
  // HKCU CustomFrame DWORD — a recovery path that does not need a new build,
  // which matters because a frameless window whose Flutter chrome fails to
  // render has no close button at all.
  bool custom_frame_ = true;

  // Whether the window currently has focus, taken from WM_ACTIVATE's own
  // wparam rather than inferred. Seeded lazily on first read (see the
  // definition) so the `windowChrome` pull that runs before the first
  // WM_ACTIVATE does not report a focused window as inactive.
  bool active_ = false;
  bool active_seeded_ = false;

  // Last payload handed to |OnWindowChromeChanged|, for deduping.
  bool published_any_ = false;
  bool published_maximized_ = false;
  bool published_active_ = true;

  // Placement persistence state (see docs/desktop-window-state.md).
  bool placement_restored_ = false;
  bool restore_maximized_ = false;
  bool in_size_move_ = false;

  // window handle for top level window.
  HWND window_handle_ = nullptr;

  // window handle for hosted content.
  HWND child_content_ = nullptr;

  // Set once Flutter pushes an explicit theme via the platform channel. From
  // then on, OS-driven theme changes reapply |pushed_dark_| rather than reading
  // the system registry, so the caption follows the app's chosen theme.
  bool flutter_pushed_theme_ = false;
  bool pushed_dark_ = false;

  // Set once Flutter pushes a border colour; re-applied on colorization
  // changes alongside the dark-mode flag.
  bool has_border_color_ = false;
  COLORREF border_color_ = 0;
};

#endif  // RUNNER_WIN32_WINDOW_H_

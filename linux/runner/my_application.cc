#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

// Channel behind the app-painted title bar. The window is frameless (client-
// side decorations with an empty titlebar), so every affordance a header bar
// used to provide is routed back here from Flutter.
static constexpr char kWindowChannel[] = "invoice_ninja/native_window";

// Flattens the CSD titlebar we install in place of the GtkHeaderBar. Without
// it a theme can still allocate the `.titlebar` node a minimum height, leaving
// a phantom band above the Flutter surface.
static constexpr char kTitlebarCss[] =
    "window.csd > .titlebar:not(headerbar) {"
    "  min-height: 0px; padding: 0px; margin: 0px;"
    "  border: none; background: none; box-shadow: none;"
    "}";

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlMethodChannel* window_channel;
  gboolean is_fullscreen;
  // Last pointer press, cached for gtk_window_begin_move_drag. See
  // ninja_event_handler.
  guint drag_button;
  gint drag_x_root;
  gint drag_y_root;
  guint32 drag_time;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Builds the chrome payload behind both the `windowChrome` pull and the
// `windowChromeChanged` push, so the two can never disagree.
//
// `maximized` and `active` are passed IN rather than read back off the window,
// because the push path cannot read them: GtkWidget::window-state-event is
// G_SIGNAL_RUN_LAST, so a handler installed with g_signal_connect runs BEFORE
// GtkWindow's class closure — and that class closure is what assigns
// priv->maximized from the event. gtk_window_is_maximized() would therefore
// return the PREVIOUS value on every maximize, restore and snap, which is
// exactly the desync `native_window.dart` says this channel exists to prevent.
// The pull path has no such constraint and passes the live values.
static FlValue* window_chrome_value(MyApplication* self, gboolean maximized,
                                    gboolean active) {
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "fullscreen",
                           fl_value_new_bool(self->is_fullscreen));
  // Strictly maximized, never tiled: a half-snapped GNOME window is
  // GDK_WINDOW_STATE_TILED, and the drawn glyph must not offer "restore" for it.
  fl_value_set_string_take(map, "maximized", fl_value_new_bool(maximized));
  fl_value_set_string_take(map, "active", fl_value_new_bool(active));
  // Always true here: the GTK runner has no kill switch — it hides the title
  // bar unconditionally in `activate`, so there is never an OS caption for the
  // app's own band to double up on. Sent explicitly all the same, so the field
  // means the same thing on both frameless platforms.
  fl_value_set_string_take(map, "customFrame", fl_value_new_bool(TRUE));
  // Explicit zero, and it must be explicit: WindowChrome.fromMap falls back to
  // the macOS default of 70 when the KEY IS ABSENT, and only preserves a zero
  // that was actually sent. No native buttons float over this window's content.
  // Deliberately no `captionHeight` — Dart owns the band height here.
  fl_value_set_string_take(map, "buttonsTrailingX", fl_value_new_float(0.0));
  return map;
}

// The pull path: reads the window directly, which is safe outside the signal.
static FlValue* window_chrome_now(MyApplication* self) {
  const gboolean maximized =
      self->window != nullptr && gtk_window_is_maximized(self->window);
  const gboolean active =
      self->window != nullptr && gtk_window_is_active(self->window);
  return window_chrome_value(self, maximized, active);
}

static void publish_window_chrome(MyApplication* self, gboolean maximized,
                                  gboolean active) {
  if (self->window_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) value = window_chrome_value(self, maximized, active);
  fl_method_channel_invoke_method(self->window_channel, "windowChromeChanged",
                                  value, nullptr, nullptr, nullptr);
}

static gboolean window_state_cb(GtkWidget* widget, GdkEventWindowState* event,
                                gpointer data) {
  MyApplication* self = MY_APPLICATION(data);
  // Every flag comes from the event, never from the window — see
  // window_chrome_value for why reading the window here is a transition stale.
  // GDK_WINDOW_STATE_TILED is included in the mask because a GNOME half-snap
  // changes focus without changing maximized, and the glyph and the dim both
  // need refreshing; `maximized` itself deliberately ignores the tiled bit.
  const GdkWindowState mask =
      static_cast<GdkWindowState>(GDK_WINDOW_STATE_MAXIMIZED |
                                  GDK_WINDOW_STATE_FULLSCREEN |
                                  GDK_WINDOW_STATE_FOCUSED |
                                  GDK_WINDOW_STATE_TILED);
  if (event->changed_mask & mask) {
    self->is_fullscreen =
        (event->new_window_state & GDK_WINDOW_STATE_FULLSCREEN) != 0;
    publish_window_chrome(
        self, (event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) != 0,
        (event->new_window_state & GDK_WINDOW_STATE_FOCUSED) != 0);
  }
  // LOAD-BEARING: returning TRUE stops propagation, and GTK's own CSD handler
  // needs this event too — it is what applies the .maximized style class and
  // drops the shadow when tiled. It is also what updates the state this
  // handler deliberately does not read.
  return FALSE;
}

// Caches the last pointer press so `startDrag` has a valid grab serial.
//
// Platform-channel calls are dispatched from the GTK main loop but OUTSIDE
// gtk_main_do_event, so gtk_get_current_event() returns NULL and
// gtk_get_current_event_time() returns GDK_CURRENT_TIME (0). X11 usually
// tolerates a zero timestamp; Wayland's xdg_toplevel.move requires a real grab
// serial and the compositor may simply drop the request — i.e. the band would
// silently not drag on GNOME Wayland.
//
// gdk_event_handler_set is process-global and singular. None of the registered
// Linux plugins uses it today, but a future one could clash.
// GDK's default dispatcher, restored in dispose. GTK installs
// `(GdkEventFunc) gtk_main_do_event` itself in do_post_parse_initialization();
// this trampoline reaches the same place without the function-pointer cast.
static void default_event_handler(GdkEvent* event, gpointer) {
  gtk_main_do_event(event);
}

static void ninja_event_handler(GdkEvent* event, gpointer data) {
  MyApplication* self = MY_APPLICATION(data);
  if (event->type == GDK_BUTTON_PRESS) {
    self->drag_button = event->button.button;
    self->drag_x_root = static_cast<gint>(event->button.x_root);
    self->drag_y_root = static_cast<gint>(event->button.y_root);
    self->drag_time = event->button.time;
  }
  gtk_main_do_event(event);
}

static void window_method_cb(FlMethodChannel* channel,
                             FlMethodCall* method_call, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  GtkWindow* window = self->window;
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "windowChrome") == 0) {
    // Answered before the null-window guard on purpose: replying with null
    // here would leave Dart on WindowChrome's macOS defaults, which reserve
    // 70 logical px of empty leading space for traffic lights that do not
    // exist on this platform.
    g_autoptr(FlValue) value = window_chrome_now(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  } else if (window == nullptr) {
    // Every remaining method acts on the window. It can legitimately be gone —
    // `close` destroys it while the engine is still draining calls.
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "startDrag") == 0) {
    // Refuse rather than drag from a bogus origin. With no cached press the
    // fields are all 0, and X11's _NET_WM_MOVERESIZE would compute the grab
    // offset against the screen origin — the window jumps to the top-left on
    // the first pixel of movement. (The `button != 0` fallback covers only the
    // button, not the coordinates.)
    if (self->drag_time != 0) {
      gtk_window_begin_move_drag(window, self->drag_button, self->drag_x_root,
                                 self->drag_y_root, self->drag_time);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "minimize") == 0) {
    gtk_window_iconify(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "toggleMaximize") == 0 ||
             g_strcmp0(method, "doubleClick") == 0) {
    if (gtk_window_is_maximized(window)) {
      gtk_window_unmaximize(window);
    } else {
      gtk_window_maximize(window);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "close") == 0) {
    gtk_window_close(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "setWindowButtonsHidden") == 0) {
    // No native buttons here — the cluster is Flutter's own, so hiding it is a
    // Dart-side concern. Succeed rather than returning NotImplemented, or the
    // Debug Panel logs an error on every toggle.
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "setContentSize") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    double width = 0;
    double height = 0;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* w = fl_value_lookup_string(args, "width");
      FlValue* h = fl_value_lookup_string(args, "height");
      // fl_value_get_float is g_return_val_if_fail'd on the type; an int on the
      // wire would log a GLib-CRITICAL and silently yield 0.0.
      if (w != nullptr && fl_value_get_type(w) == FL_VALUE_TYPE_FLOAT) {
        width = fl_value_get_float(w);
      }
      if (h != nullptr && fl_value_get_type(h) == FL_VALUE_TYPE_FLOAT) {
        height = fl_value_get_float(h);
      }
    }
    // gtk_window_resize is g_return_if_fail'd on width > 0 && height > 0, which
    // logs two Gtk-CRITICALs and aborts outright under G_DEBUG=fatal-criticals.
    // Bail BEFORE unmaximizing, or a bad payload leaves the window restored
    // with no resize applied.
    if (width < 1.0 || height < 1.0) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "bad_args", "width and height must be >= 1", nullptr));
    } else {
      if (gtk_window_is_maximized(window)) {
        gtk_window_unmaximize(window);
      }
      gtk_window_resize(window, static_cast<gint>(width),
                        static_cast<gint>(height));
      // gtk_window_resize is a REQUEST the window manager must ack, so the
      // achieved size is not knowable synchronously. Reporting the request back
      // means the Debug Panel's clamp warning cannot fire on Linux; detecting a
      // clamp would need a one-shot configure-event handler with a timeout.
      g_autoptr(FlValue) value = fl_value_new_map();
      fl_value_set_string_take(value, "width", fl_value_new_float(width));
      fl_value_set_string_take(value, "height", fl_value_new_float(height));
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
    }
  } else {
    // `showSystemMenu` lands here on purpose. GDK's own
    // gdk_window_show_window_menu needs a live GdkEvent, which a channel call
    // does not have, and keeping a copied one alive is more machinery than the
    // affordance is worth — Linux users reach the same menu through their
    // window manager (Alt+Space on GNOME and KDE). `NativeWindow._invoke`
    // swallows the resulting error, so the right-click is simply inert.
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to respond to %s: %s", method, error->message);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  self->window = window;
  // The window is finalized on close, long before the application is disposed
  // (main.cc unrefs the app only after g_application_run returns), so a raw
  // pointer here would dangle for every channel call in between — and the
  // `window == nullptr` guard in window_method_cb would never fire, because
  // the pointer would be non-null-but-freed. A weak pointer nulls it for us.
  g_object_add_weak_pointer(G_OBJECT(window),
                            reinterpret_cast<gpointer*>(&self->window));

  // Hide the OS title bar so Flutter can paint the app's own full-width band
  // (see `WindowFrame`).
  //
  // `gtk_window_set_titlebar` with an empty widget, NOT
  // `gtk_window_set_decorated(FALSE)` — these are not two spellings of the same
  // thing. set_titlebar is what turns client-side decorations ON, which keeps
  // _GTK_FRAME_EXTENTS, the automatic .maximized/.tiled handling and — the
  // decisive part — GTK's own resize handles.
  //
  // How much that buys depends on the compositor, and the earlier version of
  // this comment overstated it. set_titlebar first evaluates
  // gtk_window_supports_client_shadow(), which needs an RGBA visual AND
  // gdk_screen_is_composited(). With a compositor: wide invisible handles on
  // all four edges, a drop shadow and rounded corners. Without one (i3,
  // openbox, VNC, some remote desktops) GTK falls back to `.solid-csd` — square
  // corners, no shadow, and a resize border on the order of a single pixel. set_decorated(FALSE) leaves client_decorated
  // false, so GTK's edge hit-testing short-circuits and there is NO mouse
  // resize at all until we reimplement eight edges (and their cursors) over
  // Flutter's pointer stream. On Wayland it is worse still: no server-side
  // decorations exist to fall back to, so the window would be neither movable
  // nor resizable.
  //
  // This also collapses the old GNOME-vs-other-WM branch: with neither a header
  // bar nor a traditional title bar wanted, the X11 WM detection decided
  // nothing, so it (and <gdk/gdkx.h>) are gone. Leaving the unused locals
  // behind would fail the build outright — linux/CMakeLists.txt sets -Werror.
  GtkWidget* titlebar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
  gtk_widget_set_size_request(titlebar, -1, 0);
  gtk_widget_show(titlebar);
  gtk_window_set_titlebar(window, titlebar);

  g_autoptr(GtkCssProvider) css = gtk_css_provider_new();
  gtk_css_provider_load_from_data(css, kTitlebarCss, -1, nullptr);
  gtk_style_context_add_provider_for_screen(
      gdk_screen_get_default(), GTK_STYLE_PROVIDER(css),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

  // Still needed with no visible title: Alt-Tab, the taskbar and _NET_WM_NAME
  // all read it.
  gtk_window_set_title(window, "Invoice Ninja");

  g_signal_connect(window, "window-state-event",
                   G_CALLBACK(window_state_cb), self);

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Drives the app-painted title bar (see WindowFrame on the Dart side).
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  // GApplication::activate can be emitted more than once; without this a second
  // activate leaks the previous channel.
  g_clear_object(&self->window_channel);
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), kWindowChannel,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel,
                                            window_method_cb, self, nullptr);

  // Must be installed before the first drag; see ninja_event_handler.
  gdk_event_handler_set(ninja_event_handler, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  // Restore the default dispatcher before this object dies. `ninja_event_handler`
  // holds a raw MyApplication* and WRITES into it, so leaving it installed is a
  // use-after-free waiting for any GDK dispatch during teardown — a plugin
  // spinning a nested main-context iteration, a shutdown dialog, a crash
  // reporter. "The main loop has stopped" is not a guarantee g_application_run
  // returning actually gives.
  // Dropping our ref is not enough: fl_method_channel_new hands the messenger a
  // ref on `self` and leaves the handler registered, so an engine that outlives
  // this object would keep dispatching into freed memory.
  if (self->window_channel != nullptr) {
    fl_method_channel_set_method_call_handler(self->window_channel, nullptr,
                                              nullptr, nullptr);
  }
  gdk_event_handler_set(default_event_handler, nullptr, nullptr);
  g_clear_object(&self->window_channel);
  if (self->window != nullptr) {
    g_object_remove_weak_pointer(G_OBJECT(self->window),
                                 reinterpret_cast<gpointer*>(&self->window));
    self->window = nullptr;
  }
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}

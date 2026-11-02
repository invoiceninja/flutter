package com.invoiceninja.admin.homewidgets

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The Android half of `invoice_ninja/home_widgets` (`HomeWidgetBridge` in
 * Dart). Registered by MainActivity with its engine — the widgets themselves
 * never start one (docs/home-screen-widgets.md).
 *
 * File work runs off the main thread, on [HomeWidgets.worker] — one thread
 * shared with every redraw — so calls land in the order Dart sent them: a
 * sign-out's stub written after a rebuild's figures must also land after
 * them, or the previous user's figures stay on screen.
 * Replies go back on the main thread.
 */
class HomeWidgetsChannel(context: Context, messenger: BinaryMessenger) {
  /** The application, never the activity: [active] outlives it. */
  private val app: Context = context.applicationContext
  private val channel = MethodChannel(messenger, CHANNEL)
  private val main = Handler(Looper.getMainLooper())

  init {
    channel.setMethodCallHandler { call, result ->
      HomeWidgets.worker.execute {
            val reply: Result<Any?> = runCatching {
              when (call.method) {
                "write" -> {
                  val json = call.argument<String>("json") ?: error("no json")
                  WidgetStore.writeSnapshot(app, json)
                  // Null reloads every kind; an empty list writes without one
                  // (the widget reads the file at its next update anyway).
                  val reload = call.argument<List<String>>("reload")
                  HomeWidgets.update(app, reload?.toSet())
                  null
                }
                "installed" -> HomeWidgets.installed(app)
                "pin" -> HomeWidgets.pin(app, call.argument<String>("kind") ?: "")
                "takeCommands" -> WidgetStore.commands(app)
                "deleteCommand" -> {
                  // No redraw here: the snapshot on disk still lists the
                  // timer, and redrawing from it would flash it back to
                  // running. Dart redraws the Timer widget after its pass
                  // (`HomeWidgetPublisher.reloadTimer`) with fresh data.
                  WidgetStore.deleteCommand(app, call.argument<String>("fileId") ?: "")
                  null
                }
                "deleteAllCommands" -> {
                  WidgetStore.deleteAllCommands(app)
                  null
                }
                else -> NOT_IMPLEMENTED
              }
            }
            main.post {
              reply.fold(
                  onSuccess = { v -> if (v === NOT_IMPLEMENTED) result.notImplemented() else result.success(v) },
                  onFailure = { e -> result.error("home_widgets", e.message, null) },
              )
            }
          }
    }
    active = this
  }

  /** Tells Dart a widget queued a command while the app was running. */
  fun notifyCommandsQueued() {
    main.post { channel.invokeMethod("commandsQueued", null) }
  }

  /** Tells Dart a widget was added or reconfigured, so it fetches what that needs. */
  fun notifyWidgetsChanged() {
    main.post { channel.invokeMethod("widgetsChanged", null) }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    if (active === this) active = null
  }

  companion object {
    /** Same name as `HomeWidgetBridge.kChannelName`. */
    const val CHANNEL = "invoice_ninja/home_widgets"

    private val NOT_IMPLEMENTED = Any()


    /**
     * The channel of the engine that is running now, if any — how a widget's
     * Stop reaches a live app without starting an engine.
     */
    // Holds only the application context (see [app]), which lives as long as
    // the process anyway.
    @SuppressLint("StaticFieldLeak") @Volatile var active: HomeWidgetsChannel? = null
  }
}

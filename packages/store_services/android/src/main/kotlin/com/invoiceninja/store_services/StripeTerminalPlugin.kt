package com.invoiceninja.store_services

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.nfc.NfcAdapter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * The Android half of `invoice_ninja/stripe_terminal` (`StripeTerminal` in
 * store_services' Dart). Stripe's SDK checks permissions but never asks for
 * them, and its own device check prompts for location and Bluetooth, so the
 * app asks here first:
 *
 * - `deviceSupport` → `{tapToPay, bluetooth, nfcEnabled,
 *   locationServicesEnabled, tapToPayBlocker}`, starting nothing and asking
 *   for nothing. Tap to Pay needs Android 13, an ARM processor, NFC and a
 *   hardware keystore — Stripe's own preflight, minus the key it generates.
 * - `requestPermissions {kind}` → `granted`, `denied` or `blocked` (denied
 *   for good: Android shows no dialog any more), for what `kind` needs:
 *   precise location always, "Nearby devices" (Android 12+) only for a
 *   Bluetooth reader. Android 12+ ignores a precise-location request made
 *   without approximate location, so both are asked for; only precise counts.
 * - `openSettings` opens this app's system settings page.
 */
class StripeTerminalPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {
  private var channel: MethodChannel? = null
  private var context: Context? = null
  private var binding: ActivityPluginBinding? = null
  private var pending: MethodChannel.Result? = null
  private var pendingNeeded: List<String> = emptyList()

  /// Whether Android would have explained each permission before this
  /// request: a refusal that leaves no rationale behind is final only if
  /// there was one, or if the app had asked before (a first dialog that was
  /// dismissed, not answered, leaves none either).
  private var pendingRationale: Map<String, Boolean> = emptyMap()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
      it.setMethodCallHandler(this)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
    context = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.binding = binding
    binding.addRequestPermissionsResultListener(this)
  }

  /** A dialog survives a config change: its answer reaches the new activity. */
  override fun onDetachedFromActivityForConfigChanges() {
    binding?.removeRequestPermissionsResultListener(this)
    binding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
      onAttachedToActivity(binding)

  override fun onDetachedFromActivity() {
    onDetachedFromActivityForConfigChanges()
    pending?.success("denied")
    pending = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "deviceSupport" -> result.success(deviceSupport())
      "requestPermissions" -> requestPermissions(call.argument<String>("kind"), result)
      "openSettings" -> result.success(openSettings())
      else -> result.notImplemented()
    }
  }

  private fun deviceSupport(): Map<String, Any?> {
    val context = context ?: return mapOf()
    val pm = context.packageManager
    val nfc = NfcAdapter.getDefaultAdapter(context)
    val keystore =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            pm.hasSystemFeature(PackageManager.FEATURE_HARDWARE_KEYSTORE)
    // Stripe ships its Tap to Pay kernels for ARM only, and an x86 device
    // that translates ARM code still runs this app's x86 build: the primary
    // ABI is what counts.
    val arm = Build.SUPPORTED_ABIS.firstOrNull()?.startsWith("arm") == true
    val blocker =
        when {
          Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU -> "unsupportedOs"
          nfc == null || !keystore || !arm -> "unsupportedDevice"
          else -> null
        }
    return mapOf(
        "tapToPay" to (blocker == null),
        "bluetooth" to pm.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE),
        "nfcEnabled" to (nfc?.isEnabled == true),
        "locationServicesEnabled" to locationEnabled(context),
        "tapToPayBlocker" to blocker,
    )
  }

  private fun locationEnabled(context: Context): Boolean {
    val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      lm.isLocationEnabled
    } else {
      lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
          lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }
  }

  private fun requestPermissions(kind: String?, result: MethodChannel.Result) {
    val activity: Activity = binding?.activity ?: return result.success("denied")
    // The Dart side shares one request; a second can't be answered by this one.
    if (pending != null) return result.success("denied")
    val needed = buildList {
      add(Manifest.permission.ACCESS_FINE_LOCATION)
      if (kind == "bluetooth" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        add(Manifest.permission.BLUETOOTH_SCAN)
        add(Manifest.permission.BLUETOOTH_CONNECT)
      }
    }
    if (granted(activity, needed)) return result.success("granted")
    pending = result
    pendingNeeded = needed
    pendingRationale = needed.associateWith { activity.shouldShowRequestPermissionRationale(it) }
    activity.requestPermissions(
        (needed + Manifest.permission.ACCESS_COARSE_LOCATION).toTypedArray(),
        REQUEST_CODE,
    )
  }

  private fun granted(activity: Activity, permissions: List<String>) =
      permissions.all { activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

  override fun onRequestPermissionsResult(
      requestCode: Int,
      permissions: Array<out String>,
      grantResults: IntArray,
  ): Boolean {
    if (requestCode != REQUEST_CODE) return false
    // Approximate alone is not enough, so the answer is what is now granted.
    val activity = binding?.activity
    val refused =
        activity?.let { a ->
          pendingNeeded.filter { a.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        }
    pending?.success(
        when {
          activity == null || refused == null -> "denied"
          refused.isEmpty() -> "granted"
          // A rationale left: Android will ask again.
          refused.any { activity.shouldShowRequestPermissionRationale(it) } -> "denied"
          // None left after one was there, or after an earlier request:
          // Android won't show the dialog again.
          refused.any { pendingRationale[it] == true || askedBefore(activity, it) } -> "blocked"
          // The first dialog was dismissed, not answered.
          else -> "denied"
        })
    activity?.let { a -> pendingNeeded.forEach { noteAsked(a, it) } }
    pending = null
    return true
  }

  private fun prefs(context: Context) =
      context.getSharedPreferences("invoice_ninja_terminal_permissions", Context.MODE_PRIVATE)

  private fun askedBefore(context: Context, permission: String) =
      prefs(context).getBoolean(permission, false)

  private fun noteAsked(context: Context, permission: String) =
      prefs(context).edit().putBoolean(permission, true).apply()

  private fun openSettings(): Boolean {
    val context = binding?.activity ?: context ?: return false
    val intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", context.packageName, null))
    if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    return try {
      context.startActivity(intent)
      true
    } catch (_: Exception) {
      false
    }
  }

  private companion object {
    const val CHANNEL = "invoice_ninja/stripe_terminal"
    const val REQUEST_CODE = 0x5754 // "ST"
  }
}

package com.invoiceninja.store_services

import android.app.Activity
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.CreateCredentialNoCreateOptionException
import androidx.credentials.exceptions.CreateCredentialProviderConfigurationException
import androidx.credentials.exceptions.CreateCredentialUnsupportedException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import androidx.credentials.exceptions.GetCredentialUnsupportedException
import androidx.credentials.exceptions.NoCredentialException
import androidx.credentials.exceptions.domerrors.InvalidStateError
import androidx.credentials.exceptions.domerrors.NotAllowedError
import androidx.credentials.exceptions.domerrors.SecurityError
import androidx.credentials.exceptions.publickeycredential.CreatePublicKeyCredentialDomException
import androidx.credentials.exceptions.publickeycredential.GetPublicKeyCredentialDomException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/**
 * The Android half of `invoice_ninja/passkeys` (`NativePasskeys`,
 * docs/passkeys.md), on Credential Manager. Store builds only: below
 * Android 14 the passkey provider is Play Services, which is non-free, so
 * the F-Droid build has no such plugin and the Dart side reads
 * `isAvailable` as false.
 *
 * WebAuthn JSON passes through untouched: `authenticate {requestJson}` and
 * `register {requestJson}` reply `{responseJson}`. Errors carry one of the
 * codes `NativePasskeys` maps: cancelled, not-associated, no-credentials,
 * already-registered, unsupported, failed.
 */
class PasskeysPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
  private var channel: MethodChannel? = null
  private var activity: Activity? = null

  /** The sheet in flight and its answer; touched on the main thread only. */
  private var pending: CancellationSignal? = null
  private var pendingReply: Reply? = null

  /**
   * Credential Manager's callbacks, moved to the main thread: from API 34 the
   * platform runs them on a binder thread.
   */
  private val mainHandler = Handler(Looper.getMainLooper())
  private val main = Executor { mainHandler.post(it) }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
      it.setMethodCallHandler(this)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  // The sheet is Credential Manager's own activity and answers through it,
  // so a recreated activity needs no cancel. (MainActivity handles rotation
  // itself, so this rarely runs.)
  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
      onAttachedToActivity(binding)

  override fun onDetachedFromActivity() {
    // A cancelled signal makes Credential Manager drop the result, so answer
    // the Dart call first or it waits for ever.
    // Read both first: answering clears them (Reply's onDone).
    val signal = pending
    val reply = pendingReply
    pending = null
    pendingReply = null
    signal?.cancel()
    reply?.error("cancelled", "The activity went away")
    activity = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      // Credential Manager has passkeys from API 28; below it MainActivity
      // reports no signing hashes either, so every ceremony would be refused.
      "isAvailable" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
      "authenticate", "register" -> {
        val requestJson = call.argument<String>("requestJson")
            ?: return result.error("failed", "Missing options", null)
        // Credential Manager shows its sheet over an activity; a background
        // engine has none.
        val activity = activity ?: return result.error("unsupported", "No activity", null)
        // One sheet at a time. Refuse a second rather than cancel the first:
        // a cancel drops the first's answer but leaves its sheet up, where a
        // finished registration would save a passkey nobody reports.
        if (pending != null) {
          return result.error("failed", "A passkey request is already running", null)
        }
        val signal = CancellationSignal()
        lateinit var reply: Reply
        reply = Reply(result) {
          if (pendingReply === reply) {
            pending = null
            pendingReply = null
          }
        }
        pending = signal
        pendingReply = reply
        try {
          if (call.method == "authenticate") {
            authenticate(activity, requestJson, signal, reply)
          } else {
            register(activity, requestJson, signal, reply)
          }
        } catch (e: Exception) {
          // Options Credential Manager rejects before any sheet (malformed
          // JSON throws IllegalArgumentException from the request's init).
          reply.error("failed", e.message)
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun authenticate(
      activity: Activity,
      requestJson: String,
      signal: CancellationSignal,
      reply: Reply,
  ) {
    val request = GetCredentialRequest(listOf(GetPublicKeyCredentialOption(requestJson)))
    CredentialManager.create(activity).getCredentialAsync(
        activity,
        request,
        signal,
        main,
        object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
          override fun onResult(result: GetCredentialResponse) {
            val credential = result.credential
            if (credential is PublicKeyCredential) {
              reply.success(credential.authenticationResponseJson)
            } else {
              reply.error("failed", "Not a passkey")
            }
          }

          override fun onError(e: GetCredentialException) = reply.error(codeFor(e), e.message)
        },
    )
  }

  private fun register(
      activity: Activity,
      requestJson: String,
      signal: CancellationSignal,
      reply: Reply,
  ) {
    CredentialManager.create(activity).createCredentialAsync(
        activity,
        CreatePublicKeyCredentialRequest(requestJson),
        signal,
        main,
        object : CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
          override fun onResult(result: CreateCredentialResponse) {
            if (result is CreatePublicKeyCredentialResponse) {
              reply.success(result.registrationResponseJson)
            } else {
              reply.error("failed", "Not a passkey")
            }
          }

          override fun onError(e: CreateCredentialException) = reply.error(codeFor(e), e.message)
        },
    )
  }

  /** Answers the Dart call once; a cancelled sheet's late callback is dropped. */
  private class Reply(private var result: MethodChannel.Result?, private val onDone: () -> Unit) {
    fun success(responseJson: String) {
      val result = result ?: return
      this.result = null
      onDone()
      result.success(mapOf("responseJson" to responseJson))
    }

    fun error(code: String, message: String?) {
      val result = result ?: return
      this.result = null
      onDone()
      result.error(code, message, null)
    }
  }

  private companion object {
    /** Same name as `NativePasskeys.channel`. */
    const val CHANNEL = "invoice_ninja/passkeys"

    // Play Services reports several outcomes only in words; these strings
    // are the ones passkeys_android 2.15.0 (MessageHandler.java) matches.
    // Classes, not getType() strings, everywhere else: R8 keeps `is` checks
    // working on a minified build.

    fun codeFor(e: GetCredentialException): String {
      // No synced Google account can decrypt the passkey here.
      if (e.message == "Failed to decrypt credential.") return "unsupported"
      return when (e) {
        is GetCredentialCancellationException -> "cancelled"
        is NoCredentialException -> "no-credentials"
        is GetCredentialUnsupportedException,
        is GetCredentialProviderConfigurationException -> "unsupported"
        is GetPublicKeyCredentialDomException -> when (e.domError) {
          // The user backed out of the screen-lock / biometric prompt.
          is NotAllowedError -> "cancelled"
          // The RP ID's assetlinks.json does not grant this app.
          is SecurityError -> "not-associated"
          else -> "failed"
        }
        else -> "failed"
      }
    }

    fun codeFor(e: CreateCredentialException): String {
      val message = e.message
      when {
        message?.contains("excluded credentials", ignoreCase = true) == true ->
            return "already-registered"
        // The user skipped the fingerprint step.
        message == "Unable to create key during registration" -> return "cancelled"
        // No Google account, or none that syncs passkeys.
        message == "User is unable to create passkeys." ||
            message == "Unable to get sync account." -> return "unsupported"
      }
      return when (e) {
        is CreateCredentialCancellationException -> "cancelled"
        is CreateCredentialUnsupportedException,
        is CreateCredentialProviderConfigurationException,
        is CreateCredentialNoCreateOptionException -> "unsupported"
        is CreatePublicKeyCredentialDomException -> when (e.domError) {
          // excludeCredentials matched a passkey this provider already holds.
          is InvalidStateError -> "already-registered"
          is NotAllowedError -> "cancelled"
          is SecurityError -> "not-associated"
          else -> "failed"
        }
        else -> "failed"
      }
    }
  }
}

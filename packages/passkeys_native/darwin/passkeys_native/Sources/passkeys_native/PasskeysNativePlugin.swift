import AuthenticationServices

#if os(iOS)
  import Flutter
  import UIKit
#else
  import FlutterMacOS
  import AppKit
#endif

/// The OS passkey sheet behind `invoice_ninja/passkeys` (docs/passkeys.md),
/// on AuthenticationServices' platform provider. The code builds at iOS 15 /
/// macOS 12, so the app's deployment targets stay where they are, but it
/// offers passkeys only from iOS 16 / macOS 13: before that they were a
/// developer-toggle preview, and every ceremony fails without the toggle.
///
/// `authenticate {rpId, challenge, allowCredentials, userVerification,
/// timeoutMs}` → `{credentialId, clientDataJSON, authenticatorData,
/// signature, userHandle?}`; `register {rpId, challenge, userId, userName,
/// excludeCredentials, userVerification, timeoutMs}` → `{credentialId,
/// clientDataJSON, attestationObject}`. Bytes travel as typed data; the Dart
/// side does the base64url. Errors carry one of the codes `NativePasskeys`
/// maps: cancelled, not-associated, no-credentials, already-registered,
/// unsupported, failed.
public class PasskeysNativePlugin: NSObject, FlutterPlugin {
  private var ceremony: Ceremony?
  private weak var registrar: FlutterPluginRegistrar?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "invoice_ninja/passkeys", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(PasskeysNativePlugin(registrar: registrar), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isAvailable":
      if #available(iOS 16.0, macOS 13.0, *) {
        result(true)
      } else {
        result(false)
      }
    case "authenticate":
      start(result, args: args) { provider, challenge in
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.allowedCredentials = Self.dataList(args["allowCredentials"]).map {
          ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
        }
        request.userVerificationPreference = Self.userVerification(args["userVerification"])
        return request
      }
    case "register":
      guard let userId = Self.data(args["userId"]), let userName = args["userName"] as? String else {
        return result(FlutterError(code: "failed", message: "Missing user", details: nil))
      }
      start(result, args: args) { provider, challenge in
        let request = provider.createCredentialRegistrationRequest(
          challenge: challenge, name: userName, userID: userId)
        request.userVerificationPreference = Self.userVerification(args["userVerification"])
        // Without it iCloud Keychain replaces the account's passkey. Ignored
        // before iOS 17.4 / macOS 13.5, where the server's row then goes stale.
        if #available(iOS 17.4, macOS 13.5, *) {
          request.excludedCredentials = Self.dataList(args["excludeCredentials"]).map {
            ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
          }
        }
        return request
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(
    _ result: @escaping FlutterResult, args: [String: Any],
    build: (ASAuthorizationPlatformPublicKeyCredentialProvider, Data) -> ASAuthorizationRequest
  ) {
    guard let rpId = args["rpId"] as? String, !rpId.isEmpty, let challenge = Self.data(args["challenge"])
    else {
      return result(FlutterError(code: "failed", message: "Missing options", details: nil))
    }
    // One sheet at a time: refuse a second rather than orphan the first's
    // sheet, which could still create a credential nobody reports.
    if ceremony != nil {
      return result(FlutterError(code: "failed", message: "A passkey request is already running", details: nil))
    }
    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
    let ceremony = Ceremony(result: result, anchor: { [weak self] in self?.window() }) {
      [weak self] in self?.ceremony = nil
    }
    self.ceremony = ceremony
    ceremony.run(build(provider, challenge), timeoutMs: (args["timeoutMs"] as? NSNumber)?.intValue)
  }

  /// The Flutter view's own window, read when the sheet presents.
  private func window() -> ASPresentationAnchor? {
    #if os(iOS)
      return registrar?.viewController?.viewIfLoaded?.window
    #else
      return registrar?.view?.window
    #endif
  }

  private static func data(_ value: Any?) -> Data? {
    (value as? FlutterStandardTypedData)?.data
  }

  private static func dataList(_ value: Any?) -> [Data] {
    (value as? [Any] ?? []).compactMap { data($0) }
  }

  private static func userVerification(_ value: Any?)
    -> ASAuthorizationPublicKeyCredentialUserVerificationPreference
  {
    switch value as? String {
    case "required": return .required
    case "discouraged": return .discouraged
    default: return .preferred
    }
  }
}

/// One sheet: the controller's delegate until it answers, then gone.
private class Ceremony: NSObject, ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding
{
  private var result: FlutterResult?
  private let anchor: () -> ASPresentationAnchor?
  private let onFinish: () -> Void
  private var controller: ASAuthorizationController?

  init(
    result: @escaping FlutterResult, anchor: @escaping () -> ASPresentationAnchor?,
    onFinish: @escaping () -> Void
  ) {
    self.result = result
    self.anchor = anchor
    self.onFinish = onFinish
  }

  func run(_ request: ASAuthorizationRequest, timeoutMs: Int?) {
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    self.controller = controller
    controller.performRequests()
    // The OS sheet has no timeout of its own, and the server's challenge
    // expires: a registration finished after that creates a passkey the
    // server rejects. Close the sheet when the options say so — and always
    // at some point (the server's 300 s challenge life), or a sheet that never
    // answers would refuse every later call.
    let delay = (timeoutMs ?? 0) > 0 ? timeoutMs! : 300_000
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
      guard let self = self, self.result != nil else { return }
      if #available(iOS 16.0, macOS 13.0, *) {
        self.controller?.cancel()
      }
      self.finish(FlutterError(code: "cancelled", message: "Timed out", details: nil))
    }
  }

  /// Answers once; later calls (a delegate callback after a timeout) are
  /// ignored.
  func finish(_ value: Any?) {
    guard let result = result else { return }
    self.result = nil
    controller = nil
    result(value)
    onFinish()
  }

  func authorizationController(
    controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
      // The assertion header is not nullability-audited, so these arrive as
      // implicitly unwrapped: never force them. A hybrid (phone) assertion
      // may omit the user handle, which the server does not need.
      let authenticatorData: Data? = assertion.rawAuthenticatorData
      let signature: Data? = assertion.signature
      let userHandle: Data? = assertion.userID
      guard let authenticatorData = authenticatorData, let signature = signature else {
        return finish(FlutterError(code: "failed", message: "Incomplete assertion", details: nil))
      }
      var reply: [String: Any] = [
        "credentialId": FlutterStandardTypedData(bytes: assertion.credentialID),
        "clientDataJSON": FlutterStandardTypedData(bytes: assertion.rawClientDataJSON),
        "authenticatorData": FlutterStandardTypedData(bytes: authenticatorData),
        "signature": FlutterStandardTypedData(bytes: signature),
      ]
      if let userHandle = userHandle, !userHandle.isEmpty {
        reply["userHandle"] = FlutterStandardTypedData(bytes: userHandle)
      }
      finish(reply)
    } else if let registration = authorization.credential
      as? ASAuthorizationPlatformPublicKeyCredentialRegistration
    {
      guard let attestation = registration.rawAttestationObject else {
        return finish(FlutterError(code: "failed", message: "No attestation object", details: nil))
      }
      finish([
        "credentialId": FlutterStandardTypedData(bytes: registration.credentialID),
        "clientDataJSON": FlutterStandardTypedData(bytes: registration.rawClientDataJSON),
        "attestationObject": FlutterStandardTypedData(bytes: attestation),
      ])
    } else {
      finish(FlutterError(code: "failed", message: "Not a passkey", details: nil))
    }
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    let nsError = error as NSError
    finish(FlutterError(code: Self.code(for: nsError), message: nsError.localizedDescription, details: nil))
  }

  /// The channel code for an error. Several outcomes are reported only in
  /// words; these are the ones passkeys_darwin 0.4.8 (`ErrorExtension.swift`)
  /// matches, searched in every text the error carries.
  private static func code(for error: NSError) -> String {
    let text = descriptions(of: error).joined(separator: "\n")
    // An excludeCredentials match before ASAuthorizationError 1006 existed
    // (iOS 18 / macOS 15) comes from WebKit's WebAuthn stack.
    let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
    for candidate in [error, underlying].compactMap({ $0 })
    where candidate.domain == "WKErrorDomain" && candidate.code == 8 {
      return "already-registered"
    }
    guard error.domain == ASAuthorizationErrorDomain else { return "failed" }
    switch error.code {
    case 1001:  // canceled — also how "no passkey here" arrives, with no sheet shown
      return text.localizedCaseInsensitiveContains("No credentials available") ? "no-credentials" : "cancelled"
    case 1006:  // matchedExcludedCredential (iOS 18 / macOS 15)
      return "already-registered"
    case 1010:  // deviceNotConfiguredForPasskeyCreation (iOS 26 / macOS 26)
      return "unsupported"
    default:
      // The OS reports a missing webcredentials association only in words.
      return text.localizedCaseInsensitiveContains("not associated") ? "not-associated" : "failed"
    }
  }

  /// The error's description, failure reason and debug description, and
  /// the same for each underlying error.
  private static func descriptions(of error: NSError) -> [String] {
    var texts = [error.localizedDescription]
    for key in [NSLocalizedFailureReasonErrorKey, NSDebugDescriptionErrorKey] {
      if let text = error.userInfo[key] as? String { texts.append(text) }
    }
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
      texts += descriptions(of: underlying)
    }
    return texts
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    if let window = anchor() { return window }
    #if os(iOS)
      // The scene lifecycle leaves the app delegate's window nil; take the
      // key window of the foreground scene.
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      let active = scenes.filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }
      let all = scenes.flatMap { $0.windows }
      return active.first { $0.isKeyWindow } ?? active.first ?? all.first { $0.isKeyWindow }
        ?? all.first ?? ASPresentationAnchor()
    #else
      return NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow
        ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
    #endif
  }
}

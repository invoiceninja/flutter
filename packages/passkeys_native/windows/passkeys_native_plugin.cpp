// The OS passkey sheet on Windows behind `invoice_ninja/passkeys`
// (docs/passkeys.md), on webauthn.dll.
//
// The DLL is resolved at runtime, never linked: linking it stops the app from
// launching at all on a Windows release without it (before 10 1903). The
// option structs are the versions WebAuthn API v1 (1903) defines — never the
// header's CURRENT — so an older DLL is never handed a struct it can't read.
//
// The calls block until the user finishes, so they run on a worker thread
// (a COM single-threaded apartment: the prompt is COM-based modal UI); the
// reply goes back to the platform thread through a message posted to the
// app's top-level window.
//
// authenticate {rpId, clientDataJSON, allowCredentials, userVerification,
//   timeoutMs} -> {credentialId, authenticatorData, signature, userHandle}
// register {rpId, rpName, clientDataJSON, userId, userName, userDisplayName,
//   algorithms, excludeCredentials, userVerification, timeoutMs}
//   -> {credentialId, attestationObject}
// The Dart side built clientDataJSON and keeps it; errors carry the codes
// `NativePasskeys` maps.

#include "include/passkeys_native/passkeys_native_plugin.h"

#include <windows.h>
#include <objbase.h>
#include <webauthn.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <variant>
#include <vector>

// The sub-structs are filled at their CURRENT_VERSION; WebAuthn API v1 knows
// only version 1 of each. A newer SDK that bumps one must not silently hand
// a v1 DLL a struct it can't read.
static_assert(WEBAUTHN_RP_ENTITY_INFORMATION_CURRENT_VERSION == 1, "API v1 struct");
static_assert(WEBAUTHN_USER_ENTITY_INFORMATION_CURRENT_VERSION == 1, "API v1 struct");
static_assert(WEBAUTHN_CLIENT_DATA_CURRENT_VERSION == 1, "API v1 struct");
static_assert(WEBAUTHN_COSE_CREDENTIAL_PARAMETER_CURRENT_VERSION == 1, "API v1 struct");
static_assert(WEBAUTHN_CREDENTIAL_EX_CURRENT_VERSION == 1, "API v1 struct");

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Bytes = std::vector<uint8_t>;
using Result = std::unique_ptr<flutter::MethodResult<EncodableValue>>;

// Never `small` / `large` etc. as names below: the Windows SDK's rpcndr.h
// `#define small char`.

// The webauthn.dll entry points this plugin uses, or null where missing.
struct WebAuthnApi {
  decltype(&WebAuthNGetApiVersionNumber) GetApiVersionNumber = nullptr;
  decltype(&WebAuthNAuthenticatorMakeCredential) MakeCredential = nullptr;
  decltype(&WebAuthNAuthenticatorGetAssertion) GetAssertion = nullptr;
  decltype(&WebAuthNFreeCredentialAttestation) FreeCredentialAttestation =
      nullptr;
  decltype(&WebAuthNFreeAssertion) FreeAssertion = nullptr;
  // Optional: without them a ceremony can't be cancelled or named.
  decltype(&WebAuthNGetCancellationId) GetCancellationId = nullptr;
  decltype(&WebAuthNCancelCurrentOperation) CancelCurrentOperation = nullptr;
  decltype(&WebAuthNGetErrorName) GetErrorName = nullptr;

  bool Usable() const {
    return GetApiVersionNumber && MakeCredential && GetAssertion &&
           FreeCredentialAttestation && FreeAssertion &&
           GetApiVersionNumber() >= WEBAUTHN_API_VERSION_1;
  }

  static const WebAuthnApi& Get() {
    static const WebAuthnApi api = [] {
      WebAuthnApi loaded;
      HMODULE dll =
          LoadLibraryExW(L"webauthn.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
      if (dll == nullptr) return loaded;
      Resolve(dll, "WebAuthNGetApiVersionNumber", loaded.GetApiVersionNumber);
      Resolve(dll, "WebAuthNAuthenticatorMakeCredential", loaded.MakeCredential);
      Resolve(dll, "WebAuthNAuthenticatorGetAssertion", loaded.GetAssertion);
      Resolve(dll, "WebAuthNFreeCredentialAttestation",
              loaded.FreeCredentialAttestation);
      Resolve(dll, "WebAuthNFreeAssertion", loaded.FreeAssertion);
      Resolve(dll, "WebAuthNGetCancellationId", loaded.GetCancellationId);
      Resolve(dll, "WebAuthNCancelCurrentOperation", loaded.CancelCurrentOperation);
      Resolve(dll, "WebAuthNGetErrorName", loaded.GetErrorName);
      return loaded;
    }();
    return api;
  }

 private:
  template <typename F>
  static void Resolve(HMODULE dll, const char* name, F& out) {
    out = reinterpret_cast<F>(reinterpret_cast<void*>(GetProcAddress(dll, name)));
  }
};

const EncodableValue* Find(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(std::string(key)));
  return it == map.end() ? nullptr : &it->second;
}

std::string String(const EncodableMap& map, const char* key) {
  const EncodableValue* value = Find(map, key);
  if (value == nullptr) return "";
  const auto* text = std::get_if<std::string>(value);
  return text == nullptr ? "" : *text;
}

Bytes Data(const EncodableMap& map, const char* key) {
  const EncodableValue* value = Find(map, key);
  if (value == nullptr) return {};
  const auto* bytes = std::get_if<std::vector<uint8_t>>(value);
  return bytes == nullptr ? Bytes() : *bytes;
}

std::vector<Bytes> DataList(const EncodableMap& map, const char* key) {
  std::vector<Bytes> list;
  const EncodableValue* value = Find(map, key);
  const auto* items = value == nullptr ? nullptr : std::get_if<EncodableList>(value);
  if (items == nullptr) return list;
  for (const auto& item : *items) {
    if (const auto* bytes = std::get_if<std::vector<uint8_t>>(&item)) {
      list.push_back(*bytes);
    }
  }
  return list;
}

// An int from the standard codec, which sends a Dart int as int32 when it
// fits and int64 otherwise.
std::optional<int64_t> Integer(const EncodableValue& value) {
  if (const auto* as_int32 = std::get_if<int32_t>(&value)) return *as_int32;
  if (const auto* as_int64 = std::get_if<int64_t>(&value)) return *as_int64;
  return std::nullopt;
}

std::vector<LONG> Algorithms(const EncodableMap& map) {
  std::vector<LONG> algorithms;
  const EncodableValue* value = Find(map, "algorithms");
  const auto* items = value == nullptr ? nullptr : std::get_if<EncodableList>(value);
  if (items != nullptr) {
    for (const auto& item : *items) {
      if (auto algorithm = Integer(item)) {
        algorithms.push_back(static_cast<LONG>(*algorithm));
      }
    }
  }
  if (algorithms.empty()) {
    algorithms.push_back(WEBAUTHN_COSE_ALGORITHM_ECDSA_P256_WITH_SHA256);
  }
  return algorithms;
}

DWORD Timeout(const EncodableMap& map) {
  const EncodableValue* value = Find(map, "timeoutMs");
  if (value != nullptr) {
    if (auto timeout = Integer(*value)) {
      if (*timeout > 0) return static_cast<DWORD>(*timeout);
    }
  }
  return 240000;
}

DWORD UserVerification(const EncodableMap& map) {
  const std::string value = String(map, "userVerification");
  if (value == "required") return WEBAUTHN_USER_VERIFICATION_REQUIREMENT_REQUIRED;
  if (value == "discouraged") {
    return WEBAUTHN_USER_VERIFICATION_REQUIREMENT_DISCOURAGED;
  }
  return WEBAUTHN_USER_VERIFICATION_REQUIREMENT_PREFERRED;
}

std::wstring Wide(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()), nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring wide(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), length);
  return wide;
}

std::string Narrow(const wchar_t* wide) {
  if (wide == nullptr || *wide == L'\0') return std::string();
  const int length =
      WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (length <= 1) return std::string();
  std::string utf8(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, utf8.data(), length, nullptr, nullptr);
  utf8.resize(static_cast<size_t>(length - 1));
  return utf8;
}

EncodableValue BytesValue(const BYTE* data, DWORD size) {
  if (data == nullptr || size == 0) return EncodableValue(std::vector<uint8_t>());
  return EncodableValue(std::vector<uint8_t>(data, data + size));
}

// A credential list (WebAuthn API v1's exclude / allow lists) that owns what
// it points at.
class CredentialList {
 public:
  explicit CredentialList(std::vector<Bytes> ids) : ids_(std::move(ids)) {
    credentials_.reserve(ids_.size());
    for (auto& id : ids_) {
      WEBAUTHN_CREDENTIAL_EX credential = {};
      credential.dwVersion = WEBAUTHN_CREDENTIAL_EX_CURRENT_VERSION;
      credential.cbId = static_cast<DWORD>(id.size());
      credential.pbId = id.data();
      credential.pwszCredentialType = WEBAUTHN_CREDENTIAL_TYPE_PUBLIC_KEY;
      credentials_.push_back(credential);
    }
    for (auto& credential : credentials_) pointers_.push_back(&credential);
    list_.cCredentials = static_cast<DWORD>(pointers_.size());
    list_.ppCredentials = pointers_.data();
  }

  CredentialList(const CredentialList&) = delete;
  CredentialList& operator=(const CredentialList&) = delete;

  PWEBAUTHN_CREDENTIAL_LIST Get() { return pointers_.empty() ? nullptr : &list_; }

 private:
  std::vector<Bytes> ids_;
  std::vector<WEBAUTHN_CREDENTIAL_EX> credentials_;
  std::vector<PWEBAUTHN_CREDENTIAL_EX> pointers_;
  WEBAUTHN_CREDENTIAL_LIST list_ = {};
};

// What a failed call means to the app — Microsoft's own HRESULT → DOM error
// table (webauthn.h, "WebAuthNGetW3CExceptionDOMError"), folded onto the
// channel's codes. (An if chain: HRESULT_FROM_WIN32 is an inline function in
// some SDK configurations, so it can't be a case label.)
std::string ErrorCode(HRESULT hr) {
  // NotAllowedError: the user cancelled, it timed out, or (by design) there
  // is no credential the user could pick.
  if (hr == NTE_USER_CANCELLED || hr == HRESULT_FROM_WIN32(ERROR_CANCELLED) ||
      hr == HRESULT_FROM_WIN32(ERROR_TIMEOUT)) {
    return "cancelled";
  }
  if (hr == NTE_NOT_FOUND) return "no-credentials";
  // No authenticator at all.
  if (hr == NTE_DEVICE_NOT_FOUND) return "unsupported";
  // InvalidStateError: excludeCredentials matched.
  if (hr == NTE_EXISTS) return "already-registered";
  // ConstraintError: the authenticator can't do what was asked.
  if (hr == NTE_NOT_SUPPORTED || hr == HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED) ||
      hr == NTE_TOKEN_KEYSET_STORAGE_FULL) {
    return "unsupported";
  }
  return "failed";
}

std::string ErrorMessage(HRESULT hr) {
  char hex[16];
  snprintf(hex, sizeof(hex), "0x%08lX", static_cast<unsigned long>(hr));
  const WebAuthnApi& api = WebAuthnApi::Get();
  const std::string name = api.GetErrorName ? Narrow(api.GetErrorName(hr)) : "";
  return name.empty() ? std::string(hex) : name + " (" + hex + ")";
}

// The outcome of one ceremony: a value or an error, built on the worker.
struct Outcome {
  bool ok = false;
  EncodableValue value;
  std::string code;
  std::string message;
};

Outcome Failure(const std::string& code, const std::string& message) {
  Outcome outcome;
  outcome.code = code;
  outcome.message = message;
  return outcome;
}

WEBAUTHN_CLIENT_DATA ClientData(Bytes& client_data) {
  WEBAUTHN_CLIENT_DATA client = {};
  client.dwVersion = WEBAUTHN_CLIENT_DATA_CURRENT_VERSION;
  client.cbClientDataJSON = static_cast<DWORD>(client_data.size());
  client.pbClientDataJSON = client_data.data();
  client.pwszHashAlgId = WEBAUTHN_HASH_ALGORITHM_SHA_256;
  return client;
}

Outcome Authenticate(HWND window, const EncodableMap& args, GUID* cancellation) {
  const WebAuthnApi& api = WebAuthnApi::Get();
  const std::wstring rp_id = Wide(String(args, "rpId"));
  Bytes client_data = Data(args, "clientDataJSON");
  if (rp_id.empty() || client_data.empty()) {
    return Failure("failed", "Missing options");
  }
  CredentialList allow(DataList(args, "allowCredentials"));
  WEBAUTHN_CLIENT_DATA client = ClientData(client_data);

  WEBAUTHN_AUTHENTICATOR_GET_ASSERTION_OPTIONS options = {};
  options.dwVersion = WEBAUTHN_AUTHENTICATOR_GET_ASSERTION_OPTIONS_VERSION_4;
  options.dwTimeoutMilliseconds = Timeout(args);
  options.dwAuthenticatorAttachment = WEBAUTHN_AUTHENTICATOR_ATTACHMENT_ANY;
  options.dwUserVerificationRequirement = UserVerification(args);
  options.pCancellationId = cancellation;
  options.pAllowCredentialList = allow.Get();

  PWEBAUTHN_ASSERTION assertion = nullptr;
  const HRESULT hr =
      api.GetAssertion(window, rp_id.c_str(), &client, &options, &assertion);
  if (FAILED(hr) || assertion == nullptr) {
    if (assertion != nullptr) api.FreeAssertion(assertion);
    return Failure(ErrorCode(hr), ErrorMessage(hr));
  }
  EncodableMap value;
  value[EncodableValue("credentialId")] =
      BytesValue(assertion->Credential.pbId, assertion->Credential.cbId);
  value[EncodableValue("authenticatorData")] =
      BytesValue(assertion->pbAuthenticatorData, assertion->cbAuthenticatorData);
  value[EncodableValue("signature")] =
      BytesValue(assertion->pbSignature, assertion->cbSignature);
  if (assertion->cbUserId > 0 && assertion->pbUserId != nullptr) {
    value[EncodableValue("userHandle")] =
        BytesValue(assertion->pbUserId, assertion->cbUserId);
  }
  api.FreeAssertion(assertion);
  Outcome outcome;
  outcome.ok = true;
  outcome.value = EncodableValue(value);
  return outcome;
}

Outcome Register(HWND window, const EncodableMap& args, GUID* cancellation) {
  const WebAuthnApi& api = WebAuthnApi::Get();
  const std::wstring rp_id = Wide(String(args, "rpId"));
  const std::wstring rp_name = Wide(String(args, "rpName"));
  const std::wstring user_name = Wide(String(args, "userName"));
  const std::wstring display_name = Wide(String(args, "userDisplayName"));
  Bytes user_id = Data(args, "userId");
  Bytes client_data = Data(args, "clientDataJSON");
  if (rp_id.empty() || user_id.empty() || client_data.empty()) {
    return Failure("failed", "Missing options");
  }
  CredentialList exclude(DataList(args, "excludeCredentials"));

  WEBAUTHN_RP_ENTITY_INFORMATION rp = {};
  rp.dwVersion = WEBAUTHN_RP_ENTITY_INFORMATION_CURRENT_VERSION;
  rp.pwszId = rp_id.c_str();
  rp.pwszName = rp_name.empty() ? rp_id.c_str() : rp_name.c_str();

  WEBAUTHN_USER_ENTITY_INFORMATION user = {};
  user.dwVersion = WEBAUTHN_USER_ENTITY_INFORMATION_CURRENT_VERSION;
  user.cbId = static_cast<DWORD>(user_id.size());
  user.pbId = user_id.data();
  user.pwszName = user_name.c_str();
  user.pwszDisplayName =
      display_name.empty() ? user_name.c_str() : display_name.c_str();

  std::vector<WEBAUTHN_COSE_CREDENTIAL_PARAMETER> parameters;
  for (const LONG algorithm : Algorithms(args)) {
    WEBAUTHN_COSE_CREDENTIAL_PARAMETER parameter = {};
    parameter.dwVersion = WEBAUTHN_COSE_CREDENTIAL_PARAMETER_CURRENT_VERSION;
    parameter.pwszCredentialType = WEBAUTHN_CREDENTIAL_TYPE_PUBLIC_KEY;
    parameter.lAlg = algorithm;
    parameters.push_back(parameter);
  }
  WEBAUTHN_COSE_CREDENTIAL_PARAMETERS cose = {};
  cose.cCredentialParameters = static_cast<DWORD>(parameters.size());
  cose.pCredentialParameters = parameters.data();

  WEBAUTHN_CLIENT_DATA client = ClientData(client_data);

  WEBAUTHN_AUTHENTICATOR_MAKE_CREDENTIAL_OPTIONS options = {};
  options.dwVersion = WEBAUTHN_AUTHENTICATOR_MAKE_CREDENTIAL_OPTIONS_VERSION_3;
  options.dwTimeoutMilliseconds = Timeout(args);
  options.dwAuthenticatorAttachment = WEBAUTHN_AUTHENTICATOR_ATTACHMENT_ANY;
  // A passkey: the server asks for a resident (discoverable) credential.
  options.bRequireResidentKey = TRUE;
  options.dwUserVerificationRequirement = UserVerification(args);
  options.dwAttestationConveyancePreference =
      WEBAUTHN_ATTESTATION_CONVEYANCE_PREFERENCE_NONE;
  options.pCancellationId = cancellation;
  options.pExcludeCredentialList = exclude.Get();

  PWEBAUTHN_CREDENTIAL_ATTESTATION attestation = nullptr;
  const HRESULT hr = api.MakeCredential(window, &rp, &user, &cose, &client,
                                        &options, &attestation);
  if (FAILED(hr) || attestation == nullptr) {
    if (attestation != nullptr) api.FreeCredentialAttestation(attestation);
    return Failure(ErrorCode(hr), ErrorMessage(hr));
  }
  EncodableMap value;
  value[EncodableValue("credentialId")] =
      BytesValue(attestation->pbCredentialId, attestation->cbCredentialId);
  value[EncodableValue("attestationObject")] = BytesValue(
      attestation->pbAttestationObject, attestation->cbAttestationObject);
  api.FreeCredentialAttestation(attestation);
  Outcome outcome;
  outcome.ok = true;
  outcome.value = EncodableValue(value);
  return outcome;
}

class PasskeysNativePlugin : public flutter::Plugin {
 public:
  explicit PasskeysNativePlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar),
        // Unique to this app, unlike a bare WM_APP offset.
        completion_message_(
            RegisterWindowMessageW(L"invoice_ninja.passkeys.completion")) {
    channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
        registrar->messenger(), "invoice_ninja/passkeys",
        &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler([this](const auto& call, auto reply) {
      HandleMethodCall(call, std::move(reply));
    });
    window_proc_id_ = registrar->RegisterTopLevelWindowProcDelegate(
        [this](HWND, UINT message, WPARAM, LPARAM) -> std::optional<LRESULT> {
          if (completion_message_ == 0 || message != completion_message_) {
            return std::nullopt;
          }
          DeliverCompletions();
          return 0;
        });
  }

  ~PasskeysNativePlugin() override {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
    // The app is closing with the sheet open: end it, or the join below waits
    // for the user (or the timeout) with the window already gone.
    const WebAuthnApi& api = WebAuthnApi::Get();
    // A worker that has not reached the DLL yet sees this and doesn't start.
    stopping_.store(true);
    if (running_.load() && has_cancellation_id_ && api.CancelCurrentOperation) {
      api.CancelCurrentOperation(&cancellation_id_);
    }
    if (worker_.joinable()) worker_.join();
  }

 private:
  void HandleMethodCall(const flutter::MethodCall<EncodableValue>& call,
                        Result reply) {
    if (call.method_name() == "isAvailable") {
      reply->Success(EncodableValue(WebAuthnApi::Get().Usable()));
      return;
    }
    const bool authenticate = call.method_name() == "authenticate";
    if (!authenticate && call.method_name() != "register") {
      reply->NotImplemented();
      return;
    }
    const WebAuthnApi& api = WebAuthnApi::Get();
    if (!api.Usable()) {
      reply->Error("unsupported", "WebAuthn is not available");
      return;
    }
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    if (args == nullptr) {
      reply->Error("failed", "Missing options");
      return;
    }
    if (running_.load()) {
      reply->Error("failed", "A passkey request is already running");
      return;
    }
    // The previous worker has finished; answer anything its lost message
    // left behind before starting the next.
    if (worker_.joinable()) worker_.join();
    DeliverCompletions();

    flutter::FlutterView* view = registrar_->GetView();
    HWND window = view == nullptr ? nullptr
                                  : GetAncestor(view->GetNativeWindow(), GA_ROOT);
    if (window == nullptr || completion_message_ == 0) {
      reply->Error("unsupported", "No window to show the passkey sheet over");
      return;
    }
    has_cancellation_id_ = api.GetCancellationId != nullptr &&
                           SUCCEEDED(api.GetCancellationId(&cancellation_id_));
    GUID* cancellation = has_cancellation_id_ ? &cancellation_id_ : nullptr;

    running_.store(true);
    std::shared_ptr<flutter::MethodResult<EncodableValue>> pending(std::move(reply));
    const UINT message = completion_message_;
    worker_ = std::thread([this, window, authenticate, options = *args, pending,
                           cancellation, message]() {
      const HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
      Outcome outcome =
          stopping_.load()
              ? Failure("cancelled", "The app is closing")
              : authenticate ? Authenticate(window, options, cancellation)
                             : Register(window, options, cancellation);
      if (SUCCEEDED(com)) CoUninitialize();
      {
        std::lock_guard<std::mutex> lock(mutex_);
        completions_.push_back([pending, done = std::move(outcome)]() {
          if (done.ok) {
            pending->Success(done.value);
          } else {
            pending->Error(done.code, done.message);
          }
        });
      }
      running_.store(false);
      // If this is lost (the window is gone), the next call delivers it.
      PostMessage(window, message, 0, 0);
    });
  }

  // On the platform thread.
  void DeliverCompletions() {
    std::deque<std::function<void()>> ready;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      ready.swap(completions_);
    }
    for (auto& completion : ready) completion();
  }

  flutter::PluginRegistrarWindows* registrar_;
  UINT completion_message_;
  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  int window_proc_id_ = -1;
  std::thread worker_;
  // Set on the platform thread before the worker starts, cleared by the
  // worker once its completion is queued.
  std::atomic<bool> running_{false};
  // Set by the destructor, read by the worker.
  std::atomic<bool> stopping_{false};
  // Written on the platform thread only while no worker runs.
  GUID cancellation_id_ = {};
  bool has_cancellation_id_ = false;
  std::mutex mutex_;
  std::deque<std::function<void()>> completions_;
};

}  // namespace

void PasskeysNativePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  windows_registrar->AddPlugin(
      std::make_unique<PasskeysNativePlugin>(windows_registrar));
}

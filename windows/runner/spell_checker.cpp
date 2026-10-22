#include "spell_checker.h"

#include <flutter/standard_method_codec.h>

#include <cstdint>

namespace {

// How many suggestions a right-click offers — the Dart side's cap too.
constexpr int kMaxSuggestions = 3;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int length = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring utf16(length, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        utf16.data(), length);
  return utf16;
}

std::string Utf8FromUtf16(const std::wstring& utf16) {
  if (utf16.empty()) return std::string();
  const int length =
      ::WideCharToMultiByte(CP_UTF8, 0, utf16.data(),
                            static_cast<int>(utf16.size()), nullptr, 0,
                            nullptr, nullptr);
  if (length <= 0) return std::string();
  std::string utf8(length, '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, utf16.data(),
                        static_cast<int>(utf16.size()), utf8.data(), length,
                        nullptr, nullptr);
  return utf8;
}

const std::string* StringArg(const flutter::EncodableMap& args,
                             const char* key) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return nullptr;
  return std::get_if<std::string>(&it->second);
}

}  // namespace

SpellChecker::SpellChecker(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<>>(
      messenger, "invoice_ninja/spell_check",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "check") {
      result->NotImplemented();
      return;
    }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    const std::string* text = args ? StringArg(*args, "text") : nullptr;
    if (text == nullptr) {
      result->Error("bad_args", "expected a 'text' string");
      return;
    }
    const std::string* language = StringArg(*args, "language");
    auto spans = Check(Utf16FromUtf8(*text),
                       language ? Utf16FromUtf8(*language) : std::wstring());
    if (!spans) {
      result->Error("unavailable", "no spell checker on this machine");
      return;
    }
    result->Success(flutter::EncodableValue(std::move(*spans)));
  });
}

ISpellChecker* SpellChecker::CheckerFor(const std::wstring& language) {
  if (factory_failed_) return nullptr;
  if (!factory_) {
    const HRESULT created = ::CoCreateInstance(
        __uuidof(SpellCheckerFactory), nullptr, CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(factory_.ReleaseAndGetAddressOf()));
    if (FAILED(created)) {
      factory_failed_ = true;
      return nullptr;
    }
  }
  const auto cached = checkers_.find(language);
  if (cached != checkers_.end()) return cached->second.Get();

  std::wstring candidates[3] = {language,
                                language.substr(0, language.find(L'-')),
                                L"en-US"};
  Microsoft::WRL::ComPtr<ISpellChecker> checker;
  for (const auto& tag : candidates) {
    if (tag.empty()) continue;
    BOOL supported = FALSE;
    if (SUCCEEDED(factory_->IsSupported(tag.c_str(), &supported)) &&
        supported &&
        SUCCEEDED(factory_->CreateSpellChecker(
            tag.c_str(), checker.ReleaseAndGetAddressOf()))) {
      break;
    }
    checker.Reset();
  }
  // Cached even when null, so a language with no dictionary isn't probed on
  // every keystroke.
  checkers_[language] = checker;
  return checker.Get();
}

std::optional<flutter::EncodableList> SpellChecker::Check(
    const std::wstring& text, const std::wstring& language) {
  ISpellChecker* checker = CheckerFor(language);
  if (checker == nullptr) return std::nullopt;

  flutter::EncodableList spans;
  Microsoft::WRL::ComPtr<IEnumSpellingError> errors;
  if (FAILED(checker->Check(text.c_str(), &errors)) || !errors) return spans;

  Microsoft::WRL::ComPtr<ISpellingError> error;
  while (errors->Next(&error) == S_OK) {
    ULONG start = 0;
    ULONG length = 0;
    CORRECTIVE_ACTION action = CORRECTIVE_ACTION_NONE;
    error->get_StartIndex(&start);
    error->get_Length(&length);
    error->get_CorrectiveAction(&action);
    if (length == 0 || start + length > text.size()) {
      error.Reset();
      continue;
    }

    flutter::EncodableList suggestions;
    if (action == CORRECTIVE_ACTION_REPLACE) {
      LPWSTR replacement = nullptr;
      if (SUCCEEDED(error->get_Replacement(&replacement)) && replacement) {
        suggestions.emplace_back(Utf8FromUtf16(replacement));
        ::CoTaskMemFree(replacement);
      }
    } else if (action == CORRECTIVE_ACTION_GET_SUGGESTIONS) {
      const std::wstring word = text.substr(start, length);
      Microsoft::WRL::ComPtr<IEnumString> guesses;
      if (SUCCEEDED(checker->Suggest(word.c_str(), &guesses)) && guesses) {
        LPOLESTR guess = nullptr;
        while (static_cast<int>(suggestions.size()) < kMaxSuggestions &&
               guesses->Next(1, &guess, nullptr) == S_OK) {
          suggestions.emplace_back(Utf8FromUtf16(guess));
          ::CoTaskMemFree(guess);
        }
      }
    }
    // CORRECTIVE_ACTION_DELETE (a repeated word) offers no replacement; the
    // underline alone says what to do.

    spans.emplace_back(flutter::EncodableMap{
        {flutter::EncodableValue("start"),
         flutter::EncodableValue(static_cast<int32_t>(start))},
        {flutter::EncodableValue("end"),
         flutter::EncodableValue(static_cast<int32_t>(start + length))},
        {flutter::EncodableValue("suggestions"),
         flutter::EncodableValue(std::move(suggestions))},
    });
    error.Reset();
  }
  return spans;
}

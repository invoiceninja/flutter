#ifndef RUNNER_SPELL_CHECKER_H_
#define RUNNER_SPELL_CHECKER_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>
#include <spellcheck.h>
#include <wrl/client.h>

#include <map>
#include <memory>
#include <optional>
#include <string>

// Answers `invoice_ninja/spell_check` for the line-item fields' underlines
// (docs/spell-check.md). Flutter's engine has no spell-check service on
// Windows, so the Dart side's `NativeSpellCheckService` asks here, and this
// asks the system's ISpellChecker (Windows 8+).
//
// `check {text, language}` replies `[{start, end, suggestions}]`, offsets in
// UTF-16 code units — what both ISpellChecker and a Dart string index in. A
// machine with no checker at all replies the error code `unavailable`, which
// the Dart side latches for the session.
//
// Everything runs on the platform thread: the factory is a COM object of the
// thread that made it (main.cpp initialises COM apartment-threaded), and line
// item text is short.
class SpellChecker {
 public:
  explicit SpellChecker(flutter::BinaryMessenger* messenger);

 private:
  // Null when this machine can't check |text| in any language.
  std::optional<flutter::EncodableList> Check(const std::wstring& text,
                                              const std::wstring& language);

  // The checker for |language|, else its base language (`de-AT` -> `de`),
  // else en-US; null when none is installed.
  ISpellChecker* CheckerFor(const std::wstring& language);

  std::unique_ptr<flutter::MethodChannel<>> channel_;
  Microsoft::WRL::ComPtr<ISpellCheckerFactory> factory_;
  bool factory_failed_ = false;
  std::map<std::wstring, Microsoft::WRL::ComPtr<ISpellChecker>> checkers_;
};

#endif  // RUNNER_SPELL_CHECKER_H_

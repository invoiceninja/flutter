#ifndef RUNNER_RECEIPT_OCR_H_
#define RUNNER_RECEIPT_OCR_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <atomic>
#include <condition_variable>
#include <deque>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

// The Windows half of `invoice_ninja/receipt_ocr` (`ReceiptTextRecognizer`,
// docs/receipt-ocr.md): Windows.Media.Ocr reads a receipt photo or a
// rasterised PDF page on the device.
//
// `isAvailable` replies whether an OCR engine exists for the user's
// languages (a machine without an OCR language pack has none). `recognize
// {path?, bytes?}` replies `[{text, x, y, w, h}]`, one per line, normalised
// with a top-left origin, or an error code: `no_language`,
// `unsupported_image` (a HEIC without the Store's HEIF/HEVC extensions), or
// `failed`. Never the recognised text in an error — a receipt is personal
// data.
//
// WinRT through the raw ABI with WRL — no C++/WinRT, because the runner
// builds without exceptions (`_HAS_EXCEPTIONS=0`) and C++/WinRT reports
// errors by throwing. The work runs on one worker thread in the
// multi-threaded apartment, blocking on each async operation; the reply is
// posted back to the window ([DoneMessage]) and sent from the platform
// thread, the only thread a MethodResult may be answered on.
class ReceiptOcr {
 public:
  // Posted to |window| when a job finishes; the window calls [Drain].
  // Registered, not a WM_APP constant, so no plugin's message can be it.
  static UINT DoneMessage();

  ReceiptOcr(flutter::BinaryMessenger* messenger, HWND window);
  // Stops the worker and waits for it, so nothing is posted to a window
  // that is gone.
  ~ReceiptOcr();

  // Sends every finished job's reply. Platform thread only.
  void Drain();

 private:
  struct Job {
    bool availability_only = false;
    std::wstring path;
    std::vector<uint8_t> bytes;
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
    // Set by the worker.
    std::optional<flutter::EncodableValue> reply;
    std::string error_code;
  };

  void Run();
  void Process(Job& job);

  std::unique_ptr<flutter::MethodChannel<>> channel_;
  HWND window_;
  std::thread worker_;
  std::mutex mutex_;
  std::condition_variable wake_;
  std::deque<std::unique_ptr<Job>> queue_;
  std::deque<std::unique_ptr<Job>> done_;
  // Atomic so a wait on the engine can notice it without the lock.
  std::atomic<bool> stopping_{false};
};

#endif  // RUNNER_RECEIPT_OCR_H_

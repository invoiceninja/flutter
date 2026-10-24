#include "receipt_ocr.h"

#include <flutter/standard_method_codec.h>
#include <roapi.h>
#include <shcore.h>
#include <shlwapi.h>
#include <windows.foundation.h>
#include <windows.graphics.imaging.h>
#include <windows.media.ocr.h>
#include <windows.storage.streams.h>
#include <winstring.h>
#include <wrl/client.h>
#include <wrl/event.h>
#include <wrl/ftm.h>
#include <wrl/wrappers/corewrappers.h>

#include <algorithm>
#include <memory>

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::FtmBase;
using Microsoft::WRL::Implements;
using Microsoft::WRL::RuntimeClassFlags;
using Microsoft::WRL::ClassicCom;
using Microsoft::WRL::Wrappers::Event;
using Microsoft::WRL::Wrappers::HStringReference;

namespace foundation = ABI::Windows::Foundation;
namespace collections = ABI::Windows::Foundation::Collections;
namespace imaging = ABI::Windows::Graphics::Imaging;
namespace ocr = ABI::Windows::Media::Ocr;
namespace streams = ABI::Windows::Storage::Streams;

namespace {

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

std::string Utf8FromHString(HSTRING value) {
  UINT32 length = 0;
  const wchar_t* raw = ::WindowsGetStringRawBuffer(value, &length);
  if (raw == nullptr || length == 0) return std::string();
  const int size = ::WideCharToMultiByte(CP_UTF8, 0, raw,
                                         static_cast<int>(length), nullptr, 0,
                                         nullptr, nullptr);
  if (size <= 0) return std::string();
  std::string utf8(size, '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, raw, static_cast<int>(length), utf8.data(),
                        size, nullptr, nullptr);
  return utf8;
}

// The longest side the engine is handed, below its own limit: a receipt
// reads fine at this size, and a 48 MP photo decoded whole is ~190 MB.
constexpr UINT32 kMaxSide = 3000;

// What a completion handler shares with its waiter. Held by both, so a
// handler firing after the waiter gave up (the window closing) writes to
// live memory.
struct Completion {
  Event done{::CreateEventEx(nullptr, nullptr, CREATE_EVENT_MANUAL_RESET,
                             EVENT_ALL_ACCESS)};
  std::atomic<foundation::AsyncStatus> status{foundation::AsyncStatus::Started};
};

// Blocks until |operation| completes and stores its result, or cancels it
// once |stopping| is set — waiting in slices, so closing the window never
// hangs on a slow read. The completion handler is free-threaded (FtmBase),
// so it fires on whatever thread WinRT finishes on while this MTA thread
// waits.
template <typename Handler, typename Operation, typename Result>
HRESULT Await(Operation* operation, Result** result,
              const std::atomic<bool>& stopping) {
  auto completion = std::make_shared<Completion>();
  if (!completion->done.IsValid()) return E_FAIL;
  HRESULT hr = operation->put_Completed(
      Callback<Implements<RuntimeClassFlags<ClassicCom>, Handler, FtmBase>>(
          [completion](Operation*, foundation::AsyncStatus s) -> HRESULT {
            completion->status = s;
            ::SetEvent(completion->done.Get());
            return S_OK;
          })
          .Get());
  if (FAILED(hr)) return hr;
  while (::WaitForSingleObjectEx(completion->done.Get(), 100, FALSE) ==
         WAIT_TIMEOUT) {
    if (stopping) {
      ComPtr<foundation::IAsyncInfo> info;
      if (SUCCEEDED(operation->QueryInterface(IID_PPV_ARGS(&info)))) {
        info->Cancel();
      }
      return E_ABORT;
    }
  }
  if (completion->status != foundation::AsyncStatus::Completed) return E_FAIL;
  return operation->GetResults(result);
}

// The engine for the user's profile languages; null when none is installed.
ComPtr<ocr::IOcrEngine> CreateEngine(UINT32* max_dimension) {
  ComPtr<ocr::IOcrEngineStatics> statics;
  if (FAILED(::RoGetActivationFactory(
          HStringReference(RuntimeClass_Windows_Media_Ocr_OcrEngine).Get(),
          IID_PPV_ARGS(&statics)))) {
    return nullptr;
  }
  if (max_dimension != nullptr) statics->get_MaxImageDimension(max_dimension);
  ComPtr<ocr::IOcrEngine> engine;
  if (FAILED(statics->TryCreateFromUserProfileLanguages(&engine))) {
    return nullptr;
  }
  return engine;
}

}  // namespace

UINT ReceiptOcr::DoneMessage() {
  static const UINT message =
      ::RegisterWindowMessageW(L"InvoiceNinja.ReceiptOcr.Done");
  return message;
}

ReceiptOcr::ReceiptOcr(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window) {
  worker_ = std::thread([this]() { Run(); });
  channel_ = std::make_unique<flutter::MethodChannel<>>(
      messenger, "invoice_ninja/receipt_ocr",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    auto job = std::make_unique<Job>();
    if (call.method_name() == "isAvailable") {
      job->availability_only = true;
    } else if (call.method_name() == "recognize") {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args != nullptr) {
        const auto path = args->find(flutter::EncodableValue("path"));
        if (path != args->end()) {
          if (const auto* s = std::get_if<std::string>(&path->second)) {
            job->path = Utf16FromUtf8(*s);
          }
        }
        const auto bytes = args->find(flutter::EncodableValue("bytes"));
        if (bytes != args->end()) {
          if (const auto* b = std::get_if<std::vector<uint8_t>>(&bytes->second)) {
            job->bytes = *b;
          }
        }
      }
      if (job->path.empty() && job->bytes.empty()) {
        result->Error("bad_args", "expected a path or bytes");
        return;
      }
    } else {
      result->NotImplemented();
      return;
    }
    job->result = std::move(result);
    {
      std::lock_guard<std::mutex> lock(mutex_);
      queue_.push_back(std::move(job));
    }
    wake_.notify_one();
  });
}

ReceiptOcr::~ReceiptOcr() {
  channel_ = nullptr;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stopping_ = true;
  }
  wake_.notify_one();
  if (worker_.joinable()) worker_.join();
}

void ReceiptOcr::Run() {
  ::RoInitialize(RO_INIT_MULTITHREADED);
  for (;;) {
    std::unique_ptr<Job> job;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      wake_.wait(lock, [this]() { return stopping_ || !queue_.empty(); });
      if (stopping_) break;
      job = std::move(queue_.front());
      queue_.pop_front();
    }
    Process(*job);
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (stopping_) break;
      done_.push_back(std::move(job));
    }
    ::PostMessage(window_, DoneMessage(), 0, 0);
  }
  ::RoUninitialize();
}

void ReceiptOcr::Drain() {
  std::deque<std::unique_ptr<Job>> finished;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    finished.swap(done_);
  }
  for (auto& job : finished) {
    if (job->reply.has_value()) {
      job->result->Success(*job->reply);
    } else {
      job->result->Error(job->error_code.empty() ? "failed" : job->error_code);
    }
  }
}

void ReceiptOcr::Process(Job& job) {
  UINT32 max_dimension = 0;
  ComPtr<ocr::IOcrEngine> engine = CreateEngine(&max_dimension);
  if (job.availability_only) {
    job.reply = flutter::EncodableValue(engine != nullptr);
    return;
  }
  if (engine == nullptr) {
    job.error_code = "no_language";
    return;
  }

  // The image as a WinRT stream: the file itself, or the bytes in memory.
  ComPtr<streams::IRandomAccessStream> stream;
  if (!job.path.empty()) {
    if (FAILED(::CreateRandomAccessStreamOnFile(
            job.path.c_str(), 0 /* FileAccessMode::Read */,
            IID_PPV_ARGS(&stream)))) {
      job.error_code = "unsupported_image";
      return;
    }
  } else {
    ComPtr<IStream> memory;
    memory.Attach(::SHCreateMemStream(job.bytes.data(),
                                      static_cast<UINT>(job.bytes.size())));
    if (memory == nullptr ||
        FAILED(::CreateRandomAccessStreamOverStream(
            memory.Get(), BSOS_DEFAULT, IID_PPV_ARGS(&stream)))) {
      job.error_code = "unsupported_image";
      return;
    }
  }

  ComPtr<imaging::IBitmapDecoderStatics> decoders;
  if (FAILED(::RoGetActivationFactory(
          HStringReference(RuntimeClass_Windows_Graphics_Imaging_BitmapDecoder)
              .Get(),
          IID_PPV_ARGS(&decoders)))) {
    job.error_code = "failed";
    return;
  }
  ComPtr<foundation::IAsyncOperation<imaging::BitmapDecoder*>> decoding;
  ComPtr<imaging::IBitmapDecoder> decoder;
  if (FAILED(decoders->CreateAsync(stream.Get(), &decoding)) ||
      FAILED((Await<foundation::IAsyncOperationCompletedHandler<
                  imaging::BitmapDecoder*>>(decoding.Get(),
                                            decoder.GetAddressOf(), stopping_)))) {
    // Includes a HEIC on a machine without the HEIF/HEVC extensions.
    job.error_code = "unsupported_image";
    return;
  }

  // Scale down to what the engine accepts; orientation from the photo's
  // EXIF, so a portrait receipt is read upright.
  ComPtr<imaging::IBitmapFrame> frame;
  ComPtr<imaging::IBitmapFrameWithSoftwareBitmap> frame_bitmap;
  if (FAILED(decoder.As(&frame)) || FAILED(decoder.As(&frame_bitmap))) {
    job.error_code = "failed";
    return;
  }
  UINT32 width = 0;
  UINT32 height = 0;
  frame->get_PixelWidth(&width);
  frame->get_PixelHeight(&height);
  ComPtr<IInspectable> instance;
  ComPtr<imaging::IBitmapTransform> transform;
  if (FAILED(::RoActivateInstance(
          HStringReference(RuntimeClass_Windows_Graphics_Imaging_BitmapTransform)
              .Get(),
          &instance)) ||
      FAILED(instance.As(&transform))) {
    job.error_code = "failed";
    return;
  }
  const UINT32 longest = (std::max)(width, height);
  const UINT32 limit =
      max_dimension > 0 ? (std::min)(max_dimension, kMaxSide) : kMaxSide;
  if (longest > limit) {
    const double scale = static_cast<double>(limit) / longest;
    transform->put_ScaledWidth(static_cast<UINT32>(width * scale));
    transform->put_ScaledHeight(static_cast<UINT32>(height * scale));
    transform->put_InterpolationMode(
        imaging::BitmapInterpolationMode::BitmapInterpolationMode_Fant);
  }
  ComPtr<foundation::IAsyncOperation<imaging::SoftwareBitmap*>> converting;
  ComPtr<imaging::ISoftwareBitmap> bitmap;
  if (FAILED(frame_bitmap->GetSoftwareBitmapTransformedAsync(
          imaging::BitmapPixelFormat::BitmapPixelFormat_Bgra8,
          imaging::BitmapAlphaMode::BitmapAlphaMode_Premultiplied,
          transform.Get(),
          imaging::ExifOrientationMode::ExifOrientationMode_RespectExifOrientation,
          imaging::ColorManagementMode::ColorManagementMode_DoNotColorManage,
          &converting)) ||
      FAILED((Await<foundation::IAsyncOperationCompletedHandler<
                  imaging::SoftwareBitmap*>>(converting.Get(),
                                             bitmap.GetAddressOf(), stopping_)))) {
    job.error_code = "unsupported_image";
    return;
  }
  INT32 bitmap_width = 0;
  INT32 bitmap_height = 0;
  bitmap->get_PixelWidth(&bitmap_width);
  bitmap->get_PixelHeight(&bitmap_height);
  if (bitmap_width <= 0 || bitmap_height <= 0) {
    job.error_code = "unsupported_image";
    return;
  }

  ComPtr<foundation::IAsyncOperation<ocr::OcrResult*>> recognizing;
  ComPtr<ocr::IOcrResult> recognized;
  if (FAILED(engine->RecognizeAsync(bitmap.Get(), &recognizing)) ||
      FAILED((Await<foundation::IAsyncOperationCompletedHandler<
                  ocr::OcrResult*>>(recognizing.Get(),
                                    recognized.GetAddressOf(), stopping_)))) {
    job.error_code = "failed";
    return;
  }

  flutter::EncodableList lines_out;
  ComPtr<collections::IVectorView<ocr::OcrLine*>> lines;
  UINT32 line_count = 0;
  if (SUCCEEDED(recognized->get_Lines(&lines))) lines->get_Size(&line_count);
  for (UINT32 i = 0; i < line_count; i++) {
    ComPtr<ocr::IOcrLine> line;
    if (FAILED(lines->GetAt(i, &line))) continue;
    HSTRING text = nullptr;
    line->get_Text(&text);
    const std::string utf8 = Utf8FromHString(text);
    ::WindowsDeleteString(text);
    if (utf8.empty()) continue;
    // A line has no rectangle of its own: the union of its words'.
    ComPtr<collections::IVectorView<ocr::OcrWord*>> words;
    UINT32 word_count = 0;
    if (SUCCEEDED(line->get_Words(&words))) words->get_Size(&word_count);
    float left = 0, top = 0, right = 0, bottom = 0;
    bool any = false;
    for (UINT32 w = 0; w < word_count; w++) {
      ComPtr<ocr::IOcrWord> word;
      foundation::Rect box{};
      if (FAILED(words->GetAt(w, &word)) || FAILED(word->get_BoundingRect(&box))) {
        continue;
      }
      if (!any) {
        left = box.X;
        top = box.Y;
        right = box.X + box.Width;
        bottom = box.Y + box.Height;
        any = true;
      } else {
        left = (std::min)(left, box.X);
        top = (std::min)(top, box.Y);
        right = (std::max)(right, box.X + box.Width);
        bottom = (std::max)(bottom, box.Y + box.Height);
      }
    }
    if (!any) continue;
    lines_out.push_back(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("text"), flutter::EncodableValue(utf8)},
        {flutter::EncodableValue("x"),
         flutter::EncodableValue(static_cast<double>(left) / bitmap_width)},
        {flutter::EncodableValue("y"),
         flutter::EncodableValue(static_cast<double>(top) / bitmap_height)},
        {flutter::EncodableValue("w"),
         flutter::EncodableValue(static_cast<double>(right - left) /
                                 bitmap_width)},
        {flutter::EncodableValue("h"),
         flutter::EncodableValue(static_cast<double>(bottom - top) /
                                 bitmap_height)},
    }));
  }
  job.reply = flutter::EncodableValue(lines_out);
}

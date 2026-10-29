# File downloads

Companion to CLAUDE.md § Strict rules. The rule lives there; this doc holds the
per-platform mechanism behind it, where a download lands on each platform, and
the tests that pin it.

## A desktop download writes to the downloads folder through `bytesSaver` / `downloadPdf`, never `Printing.sharePdf`, and every `PdfPreview` gates `allowSharing` on `pdfShareOpensTempCopy()` — on Windows and Linux both only open a temp copy

**The failure it shipped as.** A beta tester: *"Downloading an invoice as PDF
just launches the PDF file and doesn't seem to save to my downloads folder like
previous app behaviour. No settings option for where to save files either?"*
Every Download PDF action called `Printing.sharePdf`, which in printing 5.15.1
does something different on each desktop, and none of it saves a file:

| Platform | `Printing.sharePdf` |
|---|---|
| Windows | writes `%TEMP%\<name>` and `ShellExecute "open"`s it (`windows/print_job.cpp:334`) — the PDF just opens |
| Linux | writes `/tmp/<name>` and `xdg-open`s it (`linux/print_job.cc:250`) |
| macOS | shows the share picker (`PrintJob.swift:229`) |
| iOS / Android | the share sheet — which is what a phone means by Download |
| web | a browser download |

`PdfPreview`'s built-in **Share** button is `PdfShareAction`, which calls the
same `sharePdf` inside the package (`lib/src/preview/actions.dart`).

**Where a download lands now.**

- **Desktop** — `bytesSaver` (`lib/ui/core/utils/save_bytes.dart`) writes
  straight into the downloads folder via `saveToDownloadsFolder`
  (`save_download.dart`) and toasts *"saved in the downloads folder"* (or the
  chosen folder's path) with the file name as the detail and an **Open**
  action. A name already taken gets ` (1)`, ` (2)`… — created with
  `exclusive: true`, so two quick downloads can't both take the same one. This
  is the old app's behaviour (`admin-portal/lib/utils/files.dart`
  `saveDownloadedFile`).
- **Mobile / web** — unchanged: `downloadPdf` shares the PDF; `bytesSaver`
  opens the save dialog.
- **Fallback** — no usable downloads folder, or a failed write, opens the save
  dialog. A chosen folder that is gone toasts `downloads_folder_does_not_exist`
  first, then opens the dialog, so the download is never dropped.

Every "Download" goes through it — the billing-doc PDF actions, the bulk
single-row download, the PDF pane's Download button, a document's Download, the
client-portal QR code, the e-purchase-order XML. Report and CSV **exports**
call `saveBytesFile` directly and keep the dialog: they are Export, not
Download.

**The folder setting.** Device Settings → *Downloads Folder*
(`DevicePrefKeys.downloadsFolder`, device scope; empty = the OS folder).

- **Windows / Linux** choose one with Select / Reset. No free-text field: a
  typed path is how a folder that doesn't exist gets saved.
- **macOS** shows Downloads read-only, with Open. A folder picked in the
  sandboxed build is granted only for that launch — keeping it needs
  security-scoped bookmarks — so `downloadsFolderEditable()` is false there and
  a stored value is ignored. Downloads itself is always writable through the
  `com.apple.security.files.downloads.read-write` entitlement.
- **Phone / web** — no card.

**Path traps.**

- macOS: `getDownloadsDirectory()` in the sandbox is the container's
  `~/Library/Containers/<bundle>/Data/Downloads`, a link to the real
  `~/Downloads`. Writes work either way; `resolveSymbolicLinks()` (macOS only —
  on Windows it can turn a mapped drive into a UNC path) keeps the Containers
  path out of the toast and the card.
- Linux: `xdg-user-dir DOWNLOAD` prints `$HOME` when no downloads folder is
  configured, and under the snap's strict confinement `HOME` is the snap's own
  data folder. Either is treated as "no downloads folder" (the dialog), as is a
  result under `SNAP_USER_DATA` / `SNAP_USER_COMMON`.

**The Share gate.** On Windows and Linux the package's Share is the same temp
copy, so every `PdfPreview` passes `allowSharing: … && !pdfShareOpensTempCopy()`
and the billing pane and client statement add a **Download** button on desktop
(hidden while the render is stale, like Print and Share). macOS keeps Share —
there it is a real share picker. Both platform predicates check `Env.isDesktop`
first: on web `defaultTargetPlatform` is the browser's OS, and Share is the
web's download. Logged in `docs/upstream-workarounds.md` #15.

**What pins it.**

- `test/lint/desktop_downloads_test.dart` — no `Printing.sharePdf` outside
  `save_bytes.dart`; every `PdfPreview(` passes the gate.
- `test/ui/core/utils/save_download_test.dart` — folders, ` (1)`, the missing
  folder, the platform predicates (plain `test()`: file IO inside
  `testWidgets`' fake-async zone can hang).
- `test/ui/core/utils/save_bytes_test.dart` — the toast, the fallbacks, mobile
  unchanged.
- `test/ui/features/settings/widgets/downloads_folder_section_test.dart`,
  `test/ui/features/billing_shared/billing_doc_pdf_view_test.dart`.

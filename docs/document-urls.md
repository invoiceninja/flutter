# Why a document's url cannot be opened

Companion to CLAUDE.md § Detail screens. Every record's Documents tab, and the company's Documents
screen, list uploaded files; this doc carries why their **View** and **Download** fetch the bytes
through the API client instead of opening the url the server hands out, and what the viewer does
with them. The rule is enforced by `test/lint/document_url_not_opened_test.dart`. (There is no rule
line in CLAUDE.md for it: the file was at its byte cap when this shipped.)

## A document's url is a token-gated API route

A beta user's **View** on an expense's PDF opened a page reading `{"message":"Invalid token"}`.
Every document on every entity did the same.

- The server's `DocumentTransformer` sets `url` to `Document::generateRoute()`, which is
  `route('api.documents.show', …) . '/download'` — `https://<host>/api/v1/documents/{id}/download`.
- That route is in the `api/v1` group, `['throttle:api', 'token_auth', 'valid_json', 'locale']`
  (`routes/api.php`). `TokenAuth` answers any request without an `X-API-TOKEN` header with
  `403 {"message":"Invalid token"}`.
- Both lists handed that url to `launchExternalUri`. The browser sends no token.

Reproduced on `demo.invoiceninja.com`: `GET /api/v1/documents/<id>/download` with no headers gives
exactly that body (HTTP 403); with the canned token it passes auth (and 400s, the demo has no
documents — this server reports a missing entity as a 400).

There is no browser-safe alternative to hand out. The server mints signed or one-time links for
other flows (`protected_download`, `/one_time_token`, the hashed links in emails), but none for an
admin user's document, and `/documents/{hash}` — what admin-portal and React fetch — is behind
`token_auth` too. Both of those clients fetch the bytes with the token and show them themselves:
admin-portal in a dialog (`Image.memory` / `PdfPreview`), React as a blob URL.

The `isSafeHttpsUrl` gate in front of the old launch also refused every document on a self-hosted
`http://` server, which made View fail there with "Couldn't open the link" instead.

## The fetch: `DocumentsApi.download`

`GET /api/v1/documents/{id}/download` through `ApiClient.getRaw`, so it carries the token, the
hosted secret and the version headers, and its errors go through `_raiseFromResponse`.

- **No content-type check** (`expectedContentType: null`). `DocumentController::download` is a
  Laravel `streamDownload`, which sets no content type, and the file can be any uploadable type.
  The other `getRaw` callers keep their `application/pdf` pin.
- **Permission is the parent's.** `ShowDocumentRequest` → `DocumentPolicy::view` allows it iff the
  user can view the record the document hangs off. A refusal is a 403 → `ServerException` with the
  server's message; it does not end the session.
- **An empty 200 is a missing file.** The response starts streaming before `Storage::get()` reads
  the file, so a file gone from storage arrives as a 200 with no body. The viewer shows
  `document_file_empty` with Retry, and Download toasts it — neither saves an empty file.
- `readOnly: true`, so it works in demo mode.

## What View and Download do

`lib/ui/core/detail/document_open_actions.dart` holds both, shared by the two lists so their copies
cannot drift apart again.

- **View** decides by the stored type (`previewKindForType`) before fetching. A PDF or an image
  opens `showDocumentViewer`; anything else goes straight to a save — a `.docx` has nothing to show.
- **The viewer** (`lib/ui/core/widgets/document_viewer.dart`) is full screen below
  `Breakpoints.wide` and a windowed dialog above it. A PDF must also pass `isRenderablePdf`, or
  `printing`'s rasterizer throws on it; one that fails is offered as a Download. An image is judged
  by the decoder (`Image.memory`'s `errorBuilder`). Image types are the ones every platform
  decodes; `heic` and `svg` are uploadable but are saved, not previewed.
- **Download** fetches and saves through `bytesSaver` (`lib/ui/core/utils/save_bytes.dart`), which
  captures the toast host and strings before the fetch so a save still lands if the row is gone by
  the time the bytes arrive. On web the browser's own download is the feedback.
- **File names** go through `documentFileName`: the base name is sanitized and the extension put
  back after it, because `sanitizeFileName` can truncate a long name and the web save throws on a
  name with no extension.

## Checked when this was fixed

Every other place the app hands a server-supplied URL to a launcher or `Image.network` was checked,
and none is token-gated:

| Surface | URL | Why it opens in a browser |
|---|---|---|
| Bank connect, QuickBooks connect, gateway OAuth setup, calendar connect | built from a `POST /one_time_token` hash | the hash is the credential |
| QuickBooks reconnect | `quickbooks/reconnect/{token}` | outside the token group |
| Download-ready push | `URL::temporarySignedRoute('protected_download', …)` | signed, behind `protected_download.signature` |
| Gmail / Microsoft mailer connect | `auth/{provider}` | a web route, no token middleware |
| Client / vendor portal links | invitation-key URLs | the key is the credential |
| Company logo (`logo_screen`, `company_avatar`) | a public storage URL | public |

`DocumentTransformer.url` is the only field any transformer emits that is an `api.` route.

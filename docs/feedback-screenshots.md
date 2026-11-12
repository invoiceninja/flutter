# Feedback screenshots

Companion to CLAUDE.md § Strict rules (`SupportApi` is an outbox exception). How Contact Us attaches a screenshot of the app and the user's own images, marked up with pen, box and redact. Code: `lib/ui/features/feedback/` (dialog, `ContactUsViewModel`, capture, editor, painter, image loading) and `lib/domain/feedback/markup.dart` (marks, history, size rules).

## The server takes images since 5.13.53, one message a minute

`POST /api/v1/support/messages/send` accepts multipart `attachments[]` since `2a26c810a1` (v5.13.53): `SendMessageRequest` requires each to be an `image` (jpg, jpeg, png, gif, bmp, webp) and caps the total at 10 MB, with no count limit. `SupportMessageSent` attaches each under its client-supplied filename, so every part carries one (`screenshot.png`, `image-2.jpg`); without a filename PHP treats the part as a plain field. The route is throttled by `support-messages`: one per minute and ten per day per user, and the hit counts even when the request fails. A 429 shows "wait N seconds" from `RateLimitedException.retryAfter`.

React shipped the same contract on Nov 3 (`6640ec77b`: Take screenshot + attach images, no markup).

The gate is `ServerFeatures.supportAttachments` (`5.13.53`, hosted exempt as for every entry), checked by `feedbackAttachmentsEnabled`, which is also off in the demo build (uploads throw there). Below it the dialog is the old text-only one; an older server would drop the images without a word. `--dart-define=FEEDBACK_ATTACHMENTS=true` turns it on for a debug run against an older server.

## `send_logs` goes as JSON `false`, and not at all with images

A server before 5.13.53 attached its debug info and the tail of `laravel.log` whenever `send_logs !== false`. The app used to send `''`, which `ConvertEmptyStringsToNull` makes `null`, so every self-hosted message carried the server's logs, and the send failed with a 500 where that log file doesn't exist. `SupportApi.sendMessage` now sends JSON `false`, as React does. The multipart send leaves the field out: multipart turns every value into a string, and `"0"` / `"false"` are `!== false` too.

## The capture waits for what the caller closed, never for "no animations"

`captureAppScreen` snapshots the root boundary (`ScreenshotWindowController.boundaryKey`), which holds the router, the root navigator and its overlay: an open dialog is in the shot, toasts are not. So `showContactUsDialog(afterClosing:)` waits for whatever the caller just closed:

- the palette and About pass their route's `TransitionRoute.completed`, read before `pop()`;
- the rail's mail icon and the collapsed Help menu pass `Future.value()` (a `MenuAnchor` closes without animating);
- the phone drawer, What's New, Welcome and the review prompt pass nothing, which waits `kCaptureSettleWait` (300 ms, past the drawer's 246 ms close).

It does not wait for `SchedulerBinding.transientCallbackCount` to reach zero: a running task timer's pulse, any spinner and the iOS caret never let it. Then one painted frame, then `toImage` at `feedbackCaptureRatio` (the device ratio, capped so the longest edge is 2560): that re-renders the layers at that size, so text stays crisp and a 5K window isn't captured whole. The whole capture is bounded by `kCaptureTimeout` (1 s; a hidden window produces no frames), and any failure means no thumbnail, never an error.

Known gaps: an open Debug Panel band is in the shot, and platform views (the document web view, the DocuNinja embed) come out blank.

`showContactUsDialog` reads `Services`, the session, the messenger and the root navigator before its first await and opens on the root navigator, because the caller's context may be gone by then (the drawer's is). A module flag stops a second tap during the wait from opening a second dialog.

## The capture is opt-in, and a slot is kept for it

The screenshot is shown as a thumbnail with "Include screenshot of this screen", off by default, and a note that screenshots can show client names and amounts. Opening it in the editor and pressing Done ticks it. Up to three images go with a message: while there is a capture, two may be added, so ticking it can never make four. Phones pick from the gallery (where their own screenshots live); desktop and web use the file picker.

## Marks are in image pixels, kept apart from the image until Send

A mark (`PenStroke`, `BoxMark`, `RedactMark`) is stored in image pixels: the editor shows the image fitted, the thumbnail smaller, the export at full size, and only image space means the same in all three. The editor returns marks, never a flattened image, so reopening it can still undo them; Clear is one undoable step. One function, `paintMarks`, draws them in the editor, the thumbnails and the export, so what you see is what is sent. Redact is opaque black in the editor as in the export: a hatched or translucent preview would suggest what's under it survives.

## Images stay under 1.9 MB each, encoded by the engine only

A bare-metal PHP install keeps the default `upload_max_filesize` of 2 MB, below the server's own 10 MB total. So each image is kept at or under `kFeedbackMaxImageBytes` (1.9 MB):

- a picked image with no marks that is already jpg / png / gif / webp and within budget goes as its own bytes (gallery photos are already resized by the picker);
- anything marked, the capture, and anything heavier is flattened (`PictureRecorder`) and encoded to PNG by the engine (`toByteData(png)`: async off the UI thread natively, the browser's async encoder on the web); if that is over budget it is re-rendered at 0.75x, at most three times, never below a 1280 px longest edge, and refused past that.

There is no JPEG step: the engine has no JPEG encoder, and `package:image`'s runs on the UI thread on the web (`compute` is inline there), which would freeze the dialog. A picked file over 30 MB, or over 40 megapixels by its header, is refused before decoding, because on the web the browser decodes at full size before resizing.

A send with images that fails with a 422 on `attachments` / `attachments.N`, a 413, or a network error (on the web a proxy's 413 carries no CORS header and arrives as one) keeps everything and offers **Send without images**.

## Drawing is by pointer only

The editor's controls (tools, Undo, Clear, Done) are all reachable by keyboard, and ⌘Z / Ctrl+Z undoes through its own focus node (the dialog sits outside the shell's keyboard layer). Drawing a mark with the keyboard is not supported: a screenshot can be sent unmarked, and a keyboard drawing mode is a lot of code for a rare case. Zoom, more colours, tool shortcuts, a drop target, paste and the camera are a planned follow-up.

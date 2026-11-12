import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/feedback/markup.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/document_capture.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/feedback/contact_us_view_model.dart';
import 'package:admin/ui/features/feedback/feedback_images.dart';
import 'package:admin/ui/features/feedback/markup_editor.dart';
import 'package:admin/ui/features/feedback/markup_painter.dart';
import 'package:admin/ui/features/feedback/screen_capture.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_footer_actions.dart';

/// Whether Contact Us may carry images: the server takes `attachments[]`
/// (`ServerFeatures.supportAttachments`; hosted is exempt as usual), and this
/// isn't the demo build, where uploads throw. `--dart-define=
/// FEEDBACK_ATTACHMENTS=true` turns it on against an older server in a debug
/// run.
bool feedbackAttachmentsEnabled(Services services, AuthSession session) {
  if (Env.demoMode) return false;
  if (const bool.fromEnvironment('FEEDBACK_ATTACHMENTS')) return true;
  if (session.isHosted) return true;
  try {
    return ServerFeatures.supports(
      services.serverVersion.value,
      ServerFeatures.supportAttachments,
    );
  } catch (_) {
    // A `Services` test fake that doesn't carry the server version: the
    // text-only dialog, as before attachments existed.
    return false;
  }
}

/// True while [showContactUsDialog] waits for its screen capture — a second
/// tap in that gap would otherwise open a second dialog. Once the dialog is
/// up its barrier takes every tap, so the flag is down again by then.
bool _contactUsOpen = false;

/// Forgets an open Contact Us — a widget test ends with its dialog still up.
@visibleForTesting
void debugResetContactUsOpen() => _contactUsOpen = false;

/// Opens Contact Us (docs/feedback-screenshots.md).
///
/// Everything context-bound — the services, the session, the messenger and
/// the root navigator — is read before the first await, and the dialog opens
/// on the root navigator: [context] may be gone by then (the phone drawer's
/// is, once it has closed). Bails silently with no session.
///
/// Where the server takes images, the screen behind is captured first, for
/// the user to include or not. [afterClosing] is the `completed` future of
/// whatever the caller just closed (the palette, About) so that isn't in the
/// shot; `Future.value()` when nothing is closing; null when the caller can't
/// say, which waits [kCaptureSettleWait].
///
/// [intro] is a line above the message — the review prompt's "What could we
/// do better?", so the switch from its card to this one reads as one
/// conversation (docs/review-prompt.md).
Future<void> showContactUsDialog(
  BuildContext context, {
  String? intro,
  Future<void>? afterClosing,
}) async {
  if (_contactUsOpen) return;
  final services = context.read<Services>();
  final session = services.auth.session.value;
  if (session == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final dpr = View.maybeOf(context)?.devicePixelRatio ?? 1;
  final attachments = feedbackAttachmentsEnabled(services, session);
  _contactUsOpen = true;
  try {
    ui.Image? capture;
    final boundaryKey = attachments ? _boundaryKeyOf(services) : null;
    if (boundaryKey != null) {
      capture = await captureAppScreen(
        boundaryKey: boundaryKey,
        devicePixelRatio: dpr,
        afterClosing: afterClosing,
      );
    }
    // Gone during the wait: the caller's navigator, or the session (a
    // sign-out would otherwise open it over /login).
    if (!rootNavigator.mounted || services.auth.session.value == null) {
      capture?.dispose();
      return;
    }
    // Created once, here — never in the dialog builder below, which runs
    // again whenever anything above the navigator rebuilds (every /refresh
    // replaces the credentials and rebuilds the router). A view model made
    // there was replaced on each rebuild: marks, redactions, added images
    // and the sending flag all reset mid-dialog. The dialog's State
    // disposes it.
    final viewModel = ContactUsViewModel(
      // Read at send time, as it always was.
      api: () => services.support,
      attachmentsEnabled: attachments,
      capture: capture,
      encode: (image, marks) =>
          encodeMarkedImage(image, marks, color: InTheme.light.annotationMark),
      releaseSources: (sources) =>
          releaseCapturedPhotos(services.sharedIntakeFiles, sources),
    );
    final shown = showDialog<void>(
      context: rootNavigator.context,
      // A send in flight must complete (or fail) before the dialog can go.
      // Not dismissible, so Esc and a barrier tap do nothing; Cancel and
      // Android back go through the discard prompt.
      barrierDismissible: false,
      builder: (ctx) => _ContactUsDialog(
        session: session,
        messenger: messenger,
        intro: intro,
        viewModel: viewModel,
      ),
    );
    _contactUsOpen = false;
    await shown;
  } finally {
    _contactUsOpen = false;
  }
}

/// The root capture boundary, or null — under a widget test whose
/// `Services` fake doesn't carry one.
GlobalKey? _boundaryKeyOf(Services services) {
  try {
    return services.screenshotWindow.boundaryKey;
  } catch (_) {
    return null;
  }
}

class _ContactUsDialog extends StatefulWidget {
  const _ContactUsDialog({
    required this.session,
    required this.messenger,
    required this.viewModel,
    this.intro,
  });

  final AuthSession session;
  final ScaffoldMessengerState? messenger;
  final ContactUsViewModel viewModel;
  final String? intro;

  @override
  State<_ContactUsDialog> createState() => _ContactUsDialogState();
}

class _ContactUsDialogState extends State<_ContactUsDialog> {
  final _controller = TextEditingController();

  /// The server (or a proxy) turned the images down; the dialog offers to
  /// send the message without them.
  bool _imagesRefused = false;
  bool _picking = false;

  ContactUsViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    vm.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _canSend => _controller.text.trim().isNotEmpty && !vm.sending;

  /// Closing would throw away a typed message or markup work.
  bool get _hasWork => _controller.text.trim().isNotEmpty || vm.hasMarks;

  String _tr(String key, [Map<String, String>? params]) =>
      Localization.of(context)?.lookup(key, params) ?? key;

  Future<void> _send({bool withImages = true}) async {
    if (!_canSend) return;
    final services = context.read<Services>();
    final navigator = Navigator.of(context);
    final result = await vm.send(
      message: _controller.text.trim(),
      appVersion: AppVersion.supportVersionLabel(
        serverVersion: services.serverVersion.value,
      ),
      withImages: withImages,
    );
    if (!mounted) return;
    switch (result) {
      case ContactUsSent():
        _imagesRefused = false;
        navigator.pop();
        final m = widget.messenger;
        if (m != null) {
          Notify.success(
            navigator.context,
            _tr('your_message_has_been_received'),
            messenger: m,
          );
        }
      case ContactUsImagesRefused():
        setState(() => _imagesRefused = true);
      case ContactUsImageTooLarge():
        Notify.error(context, _tr('image_too_large'));
      case ContactUsRateLimited(:final retryAfter):
        // One a minute, ten a day: past a couple of minutes it's the daily
        // limit, and a countdown in seconds would read "86000".
        final seconds = math.max(2, retryAfter?.inSeconds ?? 60);
        Notify.error(
          context,
          seconds > 120
              ? _tr('send_limit_reached')
              : _tr('wait_before_sending', {'seconds': '$seconds'}),
        );
      case ContactUsFailed(:final error):
        // Outlives this dialog: the toast's action may be tapped after it
        // closes.
        final root = Navigator.of(context, rootNavigator: true).context;
        // The message goes out through the user's own server's mailer, so a
        // self-hosted server without mail set up fails here. Say so, and
        // offer the forum instead of a bare "Error" (invoiceninja/flutter#191).
        Notify.error(
          context,
          _tr('contact_us_send_failed'),
          error: error,
          messenger: widget.messenger,
          action: NotifyAction(
            _tr('support_forum'),
            () => unawaited(openExternalUrl(root, kSupportForumUrl)),
          ),
        );
    }
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop || vm.sending) return;
    if (await showDiscardChangesDialog(context) && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _editCapture() async {
    final c = vm.capture;
    if (c == null) return;
    final marks = await showMarkupEditor(
      context,
      image: c.image,
      marks: c.marks,
    );
    if (marks != null && mounted) vm.markUpCapture(marks);
  }

  Future<void> _editImage(int index) async {
    final a = vm.images[index];
    final marks = await showMarkupEditor(
      context,
      image: a.image,
      marks: a.marks,
    );
    if (marks != null && mounted) vm.markUpImage(index, marks);
  }

  void _removeImage(int index) {
    vm.removeImage(index);
    _announce(_tr('image_removed'));
  }

  Future<void> _addImages() async {
    if (_picking || vm.remainingSlots <= 0) return;
    setState(() => _picking = true);
    final intake = intakeOf(context);
    final added = <FeedbackAttachment>[];
    var tooLarge = 0;
    var unreadable = 0;
    var sources = const <UploadSource>[];
    var next = 0;
    try {
      if (Env.isMobile) {
        // Where a phone's own screenshots live.
        sources = await pickGalleryPhotos(
          context,
          multiple: vm.remainingSlots > 1,
        );
      } else {
        sources = await uploadSourcesFromPicked(
          await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
          ),
        );
      }
      for (; next < sources.length; next++) {
        final source = sources[next];
        final loaded = await loadPickedImage(source);
        if (loaded.attachment case final a?) {
          added.add(a);
        } else {
          loaded.problem == PickedImageProblem.tooLarge
              ? tooLarge++
              : unreadable++;
          await releaseCapturedPhotos(intake, [source]);
        }
      }
    } catch (_) {
      // A picker that failed, or a file that broke mid-read: release what
      // was picked but never looked at.
      unreadable++;
      await releaseCapturedPhotos(intake, sources.skip(next));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (!mounted) {
      for (final a in added) {
        a.image.dispose();
      }
      await releaseCapturedPhotos(intake, added.map((a) => a.source).nonNulls);
      return;
    }
    final dropped = vm.addImages(added);
    final kept = added.length - dropped;
    if (kept > 0) {
      _announce(
        _tr('image_added', {
          'count': '${vm.attachedCount}',
          'max': '$kFeedbackMaxImages',
        }),
      );
    }
    if (dropped > 0) {
      Notify.info(
        context,
        _tr('images_limit', {'count': '$kFeedbackMaxImages'}),
      );
    }
    if (tooLarge > 0) Notify.error(context, _tr('image_too_large'));
    if (unreadable > 0) Notify.error(context, _tr('image_not_readable'));
  }

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final email = widget.session.userEmail;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => PopScope(
        // Blocks Android back / Esc mid-send; otherwise asks before throwing
        // away a message or markup.
        canPop: !vm.sending && !_hasWork,
        onPopInvokedWithResult: _onPopInvoked,
        child: AlertDialog(
          title: Text(context.tr('contact_us')),
          content: SingleChildScrollView(
            child: SizedBox(
              width: vm.attachmentsEnabled ? 560 : 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.intro case final intro?) ...[
                    Text(
                      intro,
                      style: TextStyle(fontSize: 14, color: tokens.ink2),
                    ),
                    const SizedBox(height: InSpacing.xs),
                  ],
                  if (email.isNotEmpty)
                    Text(
                      context.tr('replies_go_to', {'email': email}),
                      style: TextStyle(fontSize: 12, color: tokens.ink3),
                    ),
                  SizedBox(height: InSpacing.md(context)),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: 6,
                    minLines: 4,
                    enabled: !vm.sending,
                    keyboardType: TextInputType.multiline,
                    // Multi-line: Enter inserts a newline (per CLAUDE.md form
                    // conventions). No FormSaveScope wiring here.
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: context.tr('message'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (vm.attachmentsEnabled) ...[
                    SizedBox(height: InSpacing.md(context)),
                    _AttachmentRow(
                      vm: vm,
                      busy: _picking,
                      onEditCapture: _editCapture,
                      onEditImage: _editImage,
                      onRemoveImage: _removeImage,
                      onAdd: _addImages,
                    ),
                    const SizedBox(height: InSpacing.sm),
                    Text(
                      context.tr('screenshot_privacy_note'),
                      style: TextStyle(fontSize: 12, color: tokens.ink3),
                    ),
                  ],
                  if (_imagesRefused) ...[
                    const SizedBox(height: InSpacing.sm),
                    _ImagesRefusedBanner(
                      onSendWithout: vm.sending
                          ? null
                          : () => _send(withImages: false),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              // Override the theme's full-width minimumSize so Cancel fits
              // beside Send instead of stacking.
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: vm.sending
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: Text(context.tr('cancel')),
            ),
            PrimaryDialogAction(
              label: context.tr('send'),
              enabled: _canSend,
              busy: vm.sending,
              // Multi-line message field: Enter inserts a newline, so it owns
              // focus and there's no Enter-to-submit path — no hint.
              autofocus: false,
              showEnterHint: false,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Your server didn't accept the images", with a way to send the words.
class _ImagesRefusedBanner extends StatelessWidget {
  const _ImagesRefusedBanner({required this.onSendWithout});

  final VoidCallback? onSendWithout;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: const EdgeInsets.all(InSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: tokens.warning),
          const SizedBox(width: InSpacing.sm),
          Expanded(child: Text(context.tr('images_not_accepted'))),
          const SizedBox(width: InSpacing.sm),
          TextButton(
            onPressed: onSendWithout,
            child: Text(context.tr('send_without_images')),
          ),
        ],
      ),
    );
  }
}

/// The capture (with its Include checkbox), the added images, and Add image.
class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.vm,
    required this.busy,
    required this.onEditCapture,
    required this.onEditImage,
    required this.onRemoveImage,
    required this.onAdd,
  });

  final ContactUsViewModel vm;
  final bool busy;
  final VoidCallback onEditCapture;
  final ValueChanged<int> onEditImage;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final capture = vm.capture;
    final images = vm.images;
    return Wrap(
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        if (capture != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(
                attachment: capture,
                dimmed: !vm.captureIncluded,
                selected: vm.captureIncluded,
                semanticsLabel: context.tr(
                  vm.captureIncluded
                      ? 'screenshot_included_label'
                      : 'screenshot_not_included_label',
                ),
                onTap: onEditCapture,
              ),
              _IncludeCheckbox(
                value: vm.captureIncluded,
                onChanged: vm.sending ? null : vm.setCaptureIncluded,
              ),
            ],
          ),
        for (var i = 0; i < images.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(
                attachment: images[i],
                dimmed: false,
                selected: true,
                semanticsLabel: context.tr('image_n_label', {'n': '${i + 1}'}),
                onTap: () => onEditImage(i),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: context.tr('mark_up_image_n', {'n': '${i + 1}'}),
                    onPressed: vm.sending ? null : () => onEditImage(i),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: context.tr('remove_image_n', {'n': '${i + 1}'}),
                    onPressed: vm.sending ? null : () => onRemoveImage(i),
                  ),
                ],
              ),
            ],
          ),
        if (vm.remainingSlots > 0)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: busy || vm.sending ? null : onAdd,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(context.tr('add_image')),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 34),
            child: Text(
              '$kFeedbackMaxImages / $kFeedbackMaxImages',
              style: TextStyle(fontSize: 12, color: tokens.ink3),
            ),
          ),
      ],
    );
  }
}

class _IncludeCheckbox extends StatelessWidget {
  const _IncludeCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(InRadii.r1),
      child: InkWell(
        borderRadius: BorderRadius.circular(InRadii.r1),
        onTap: change == null ? null : () => change(!value),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: InSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: value,
                onChanged: change == null ? null : (v) => change(v ?? false),
              ),
              Text(context.tr('include_screenshot')),
            ],
          ),
        ),
      ),
    );
  }
}

/// An image and its marks at thumbnail size — drawn by the same painter as
/// the editor and the export. A local Material + InkWell (never `Ink`).
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.attachment,
    required this.dimmed,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  static const double _height = 88;

  final FeedbackAttachment attachment;
  final bool dimmed;
  final bool selected;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final image = attachment.image;
    final aspect = image.height == 0 ? 1.0 : image.width / image.height;
    final width = (_height * aspect).clamp(56.0, 176.0);
    final radius = BorderRadius.circular(InRadii.r2);
    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: context.tr('mark_up_screenshot'),
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: context.tr('mark_up_screenshot'),
        child: SizedBox(
          width: width,
          height: _height,
          child: Opacity(
            opacity: dimmed ? 0.45 : 1,
            child: Material(
              color: tokens.surfaceAlt,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                mouseCursor: SystemMouseCursors.zoomIn,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: selected ? tokens.accent : tokens.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: CustomPaint(
                    painter: MarkedImagePainter(
                      image: image,
                      marks: attachment.marks,
                      color: tokens.annotationMark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

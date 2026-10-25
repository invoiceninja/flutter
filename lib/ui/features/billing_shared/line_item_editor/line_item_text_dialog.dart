import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/spell_check.dart';

/// What [showLineItemTextDialog] hands back: the edited line, and whether the
/// user asked to carry on in the full line-item editor (`More Fields`).
typedef LineItemTextResult = ({LineItem item, bool moreFields});

/// Editor for a text line — a description with no product, cost or quantity
/// (see `LineItem.isTextOnly`), which the PDF prints as a row of text.
///
/// Users were adding blank items and typing into the full line-item dialog's
/// three-line Description to get one, then zeroing the quantity so the PDF
/// didn't print `$0.00 1 $0.00`. This is one spell-checked box as tall as the
/// screen allows: full screen on a phone (the keyboard takes half of it), a
/// fixed 560 × 360 box in a window.
///
/// [offerMoreFields] adds a `More Fields` button for an existing text line, so
/// it can still be given a price; the caller opens the full editor on the
/// returned item.
Future<LineItemTextResult?> showLineItemTextDialog(
  BuildContext context, {
  required LineItem initial,
  required String label,
  String titleKey = 'text',
  String actionKey = 'save',
  bool offerMoreFields = false,
}) {
  return showDialog<LineItemTextResult>(
    context: context,
    builder: (_) => _LineItemTextDialog(
      initial: initial,
      label: label,
      titleKey: titleKey,
      actionKey: actionKey,
      offerMoreFields: offerMoreFields,
    ),
  );
}

class _LineItemTextDialog extends StatefulWidget {
  const _LineItemTextDialog({
    required this.initial,
    required this.label,
    required this.titleKey,
    required this.actionKey,
    required this.offerMoreFields,
  });

  final LineItem initial;
  final String label;
  final String titleKey;
  final String actionKey;
  final bool offerMoreFields;

  @override
  State<_LineItemTextDialog> createState() => _LineItemTextDialogState();
}

class _LineItemTextDialogState extends State<_LineItemTextDialog> {
  late final TextEditingController _notes = TextEditingController(
    text: widget.initial.notes,
  )..addListener(_onChanged);

  bool get _dirty => _notes.text != widget.initial.notes;
  bool get _canSave => _notes.text.trim().isNotEmpty;

  /// Rebuilds only when something the chrome shows flips — the Save button's
  /// enabled state and the discard guard — not on every keystroke. Seeded in
  /// [initState]: a lazy `late` initializer would first run inside
  /// [_onChanged], after the text had changed, and never see the flip.
  late bool _lastDirty;
  late bool _lastCanSave;

  @override
  void initState() {
    super.initState();
    _lastDirty = _dirty;
    _lastCanSave = _canSave;
  }

  void _onChanged() {
    if (_dirty == _lastDirty && _canSave == _lastCanSave) return;
    setState(() {
      _lastDirty = _dirty;
      _lastCanSave = _canSave;
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _pop({required bool moreFields}) {
    Navigator.of(context).pop<LineItemTextResult>((
      item: widget.initial.copyWith(notes: _notes.text.trimRight()),
      moreFields: moreFields,
    ));
  }

  /// A paragraph is a lot to lose to a stray back gesture.
  Future<void> _close() async {
    if (_dirty && !await showDiscardChangesDialog(context)) return;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.wide;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: narrow ? _fullscreen(context) : _windowed(context),
    );
  }

  /// The Save button lives in the app bar, not a bottom bar: the keyboard
  /// covers the bottom of the screen for as long as this is open.
  Widget _fullscreen(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr(widget.titleKey)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.tr('cancel'),
            onPressed: _close,
          ),
          actions: [
            _saveButton(context),
            SizedBox(width: InSpacing.md(context)),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(InSpacing.lg(context)),
            child: _body(context),
          ),
        ),
      ),
    );
  }

  Widget _windowed(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr(widget.titleKey)),
      content: SizedBox(width: 560, height: 360, child: _body(context)),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: _close,
              child: Text(context.tr('cancel')),
            ),
            SizedBox(width: InSpacing.md(context)),
            _saveButton(context),
          ],
        ),
      ],
    );
  }

  Widget _saveButton(BuildContext context) {
    return PrimaryDialogAction(
      label: context.tr(widget.actionKey),
      enabled: _canSave,
      onPressed: () => _pop(moreFields: false),
      // The text box owns focus, and Enter there is a new line.
      autofocus: false,
      showEnterHint: false,
    );
  }

  Widget _body(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LineItemSpellCheck(
            builder: (context, config) => TextField(
              controller: _notes,
              autofocus: true,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.label,
                alignLabelWithHint: true,
              ),
              spellCheckConfiguration: config,
              contextMenuBuilder: spellCheckContextMenuBuilder,
            ),
          ),
        ),
        if (widget.offerMoreFields)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(top: InSpacing.sm),
              child: TextButton.icon(
                icon: const Icon(Icons.tune),
                label: Text(context.tr('more_fields')),
                onPressed: () => _pop(moreFields: true),
              ),
            ),
          ),
      ],
    );
  }
}

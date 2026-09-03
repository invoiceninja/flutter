import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/in_time_field.dart';
import 'package:admin/ui/core/widgets/party_call_button.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';

/// Capture form for a manually-logged phone call (invoiceninja/flutter#120).
/// Resolves with the composed note body — ready to hand straight to
/// `repo.addComment(text: …)` — or null if the user cancelled.
///
/// Returning a `String` rather than a value object is deliberate: it makes each
/// of the ten `logCall` action arms byte-identical in shape to the `addComment`
/// arm beside it (`showAddCommentDialog` also returns `String?`), and it keeps
/// the composition — locale, company date format, military-time — in the one
/// place that has a `BuildContext` and a `Formatter`. See `call_note.dart` for
/// why the note is the only storage there is.
///
/// A bottom sheet below 600 px and a centered dialog above, the split
/// `TimeEntryEditorSheet.show` makes. Branching on width rather than
/// `Env.isTouchPrimary` is what keeps both paths cheap to test — `flutter test`
/// reports `TargetPlatform.android`, so the platform flag is `true` in every
/// widget test unless it overrides `debugDefaultTargetPlatform`.
Future<String?> showLogCallSheet(
  BuildContext context, {
  required String companyId,
  required String subject,
  List<PhoneCandidate> candidates = const <PhoneCandidate>[],
  PhoneCandidate? dialled,
  Duration? suggestedDuration,
}) async {
  final services = context.read<Services>();
  // Awaited up front rather than passed in: five of the eight billing-doc
  // Activity tabs hand their tab a null `Formatter`, and `InTimeField` reads
  // `formatter?.settings.enableMilitaryTime ?? true` — so a null here silently
  // gives a 12-hour company a 24-hour field and hint. `formatterFor` is cached
  // per company, so this is a no-op after the first call on a detail screen.
  final formatter = await services.formatterFor(companyId);
  if (!context.mounted) return null;

  final initial = dialled ?? (candidates.isEmpty ? null : candidates.first);
  final isWide = MediaQuery.sizeOf(context).width >= 600;

  // Re-provided rather than inherited, for the same reason
  // `showPhoneCandidatePicker` does it: this is a *route*, so its subtree hangs
  // off a `Navigator` that may sit above whatever `Provider<Services>` the
  // caller is under — and the contact field's picker button opens that picker,
  // which reads `Services` on the way in.
  Widget body(BuildContext ctx) => Provider<Services>.value(
    value: services,
    child: _LogCallForm(
      subject: subject,
      candidates: candidates,
      initialContact: initial,
      suggestedDuration: suggestedDuration,
      formatter: formatter,
    ),
  );

  if (isWide) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: math.min(640, MediaQuery.of(ctx).size.height * 0.9),
          ),
          child: body(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // `showModalBottomSheet` lifts nothing by itself, and this sheet ends in an
    // autofocused multi-line field — without the inset the keyboard covers the
    // one control the form exists for. `line_item_picker_sheet.dart` is the
    // reference; the sibling `showPhoneCandidatePicker` omits this legitimately
    // because it has no text input at all, so don't copy its block instead.
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: body(ctx),
    ),
  );
}

class _LogCallForm extends StatefulWidget {
  const _LogCallForm({
    required this.subject,
    required this.candidates,
    required this.initialContact,
    required this.suggestedDuration,
    required this.formatter,
  });

  /// What this call is being logged *against* — a client or vendor's display
  /// name, or a document's `#number`. Titles the form, and names the party in
  /// the contact picker.
  final String subject;
  final List<PhoneCandidate> candidates;
  final PhoneCandidate? initialContact;
  final Duration? suggestedDuration;
  final Formatter formatter;

  @override
  State<_LogCallForm> createState() => _LogCallFormState();
}

class _LogCallFormState extends State<_LogCallForm> {
  CallDirection _direction = CallDirection.outgoing;
  late DateTime _when;
  late final TextEditingController _contact;
  late final TextEditingController _duration;
  final TextEditingController _summary = TextEditingController();
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    // Local wall clock throughout: `InDateField` / `InTimeField` read and write
    // `.year` / `.hour` / `.minute`, and the composed label is rendered from
    // those same fields, so a UTC-backed value would mix zones.
    _when = DateTime.now();
    _contact = TextEditingController(text: _contactText(widget.initialContact));
    // Rounded, not truncated: `Duration.inMinutes` floors, so a 3 min 55 s
    // round trip would seed `3`.
    final secs = widget.suggestedDuration?.inSeconds;
    final minutes = secs == null ? null : (secs / 60).round();
    _duration = TextEditingController(
      text: minutes == null || minutes <= 0 ? '' : '$minutes',
    );
    _summary.addListener(_onSummaryChanged);
  }

  @override
  void dispose() {
    _summary.removeListener(_onSummaryChanged);
    _summary.dispose();
    _contact.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _onSummaryChanged() {
    final canSave = _summary.text.trim().isNotEmpty;
    if (canSave != _canSave) setState(() => _canSave = canSave);
  }

  /// "Jane Smith · +1 415 555 0123" — one editable string, because the note has
  /// one free-text slot for it and nothing ever parses the two halves back
  /// apart. A candidate with no name contributes only its number.
  static String _contactText(PhoneCandidate? c) {
    if (c == null) return '';
    final label = c.label.trim();
    final phone = c.phone.trim();
    if (label.isEmpty) return phone;
    if (phone.isEmpty) return label;
    return '$label · $phone';
  }

  Future<void> _pickContact() async {
    final picked = await showPhoneCandidatePicker(
      context,
      candidates: widget.candidates,
      partyName: widget.subject,
    );
    if (picked == null || !mounted) return;
    _contact.text = _contactText(picked);
  }

  String _whenLabel() {
    // Two calls, not `Formatter.date(showTime: true)`: that path assumes a
    // *server UTC* string — it appends `Z` and calls `.toLocal()` — so handing
    // it this local wall clock would shift the printed time by the device's
    // offset. Wrong everywhere but a UTC machine, which is exactly what CI is.
    final date = widget.formatter.date(_when.toIso8601String());
    final time = formatTimeOfDay(
      _when.hour,
      _when.minute,
      military: widget.formatter.settings.enableMilitaryTime,
    );
    return date.isEmpty ? time : '$date $time';
  }

  String _durationLabel() {
    final minutes = int.tryParse(_duration.text.trim());
    if (minutes == null || minutes <= 0) return '';
    // `count_minutes` is ':count Minutes', so a one-minute call would read
    // "1 Minutes" — into a note that is append-only and permanent. `1_minute`
    // is the translated singular Transifex already ships. Both are
    // single-placeholder (or placeholder-free) keys, so `Localization.lookup`
    // returns on its fast path — no exposure to the longest-name-first sort.
    if (minutes == 1) return context.tr('1_minute');
    return context.tr('count_minutes', {'count': '$minutes'});
  }

  void _onSave() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      composeCallNote(
        directionLabel: context.tr(
          _direction == CallDirection.outgoing ? 'outgoing' : 'incoming',
        ),
        whenLabel: _whenLabel(),
        summary: _summary.text,
        contact: _contact.text,
        durationLabel: _durationLabel(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final title = widget.subject.trim().isEmpty
        ? context.tr('log_call')
        : '${context.tr('log_call')} · ${widget.subject.trim()}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
            SizedBox(height: InSpacing.lg(context)),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A SegmentedButton, never a RadioGroup: RadioGroup's
                    // Shortcuts.manager + FocusTraversalGroup + post-frame
                    // single-selection check mutate the subtree mid-frame and
                    // crash inside sheet/dialog layout — the reason
                    // `entity_sort_filter_sheet.dart` and
                    // `tax_category_dialog.dart` both hand-roll a list. The
                    // design rule this satisfies ("two choices stay visible")
                    // is about the affordance, not that widget.
                    SegmentedButton<CallDirection>(
                      segments: [
                        ButtonSegment(
                          value: CallDirection.outgoing,
                          icon: const Icon(Icons.call_made, size: 16),
                          label: Text(context.tr('outgoing')),
                        ),
                        ButtonSegment(
                          value: CallDirection.incoming,
                          icon: const Icon(Icons.call_received, size: 16),
                          label: Text(context.tr('incoming')),
                        ),
                      ],
                      selected: {_direction},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _direction = s.first),
                    ),
                    SizedBox(height: InSpacing.md(context)),
                    Row(
                      children: [
                        Expanded(
                          child: InDateField(
                            value: _when,
                            labelText: context.tr('date'),
                            formatter: widget.formatter,
                            onChanged: (d) {
                              if (d == null) return;
                              setState(() {
                                _when = DateTime(
                                  d.year,
                                  d.month,
                                  d.day,
                                  _when.hour,
                                  _when.minute,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: InSpacing.sm),
                        Expanded(
                          child: InTimeField(
                            value: TimeOfDay.fromDateTime(_when),
                            labelText: context.tr('time'),
                            formatter: widget.formatter,
                            onChanged: (t) {
                              if (t == null) return;
                              setState(() {
                                _when = DateTime(
                                  _when.year,
                                  _when.month,
                                  _when.day,
                                  t.hour,
                                  t.minute,
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: InSpacing.md(context)),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _contact,
                            // Free text, never a SearchableDropdownField: that
                            // widget sets `TextInputType.none` for a list of
                            // six or fewer (so the soft keyboard never opens)
                            // and renders a *disabled* field when `items` is
                            // empty. Logging a call to a number that isn't on
                            // the record — the usual shape of an inbound call —
                            // has to stay typeable.
                            decoration: InputDecoration(
                              labelText: context.tr('contact'),
                              suffixIcon: widget.candidates.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.contacts_outlined,
                                        size: 18,
                                      ),
                                      tooltip: context.tr('phone_numbers'),
                                      onPressed: _pickContact,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: InSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: _duration,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr('duration'),
                              hintText: context.tr('minutes'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: InSpacing.md(context)),
                    TextField(
                      controller: _summary,
                      autofocus: true,
                      maxLines: 5,
                      minLines: 3,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: context.tr('summary'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: InSpacing.lg(context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.tr('cancel')),
                ),
                SizedBox(width: InSpacing.md(context)),
                PrimaryDialogAction(
                  label: context.tr('save'),
                  enabled: _canSave,
                  onPressed: _onSave,
                  // The summary owns Enter (newline) and the primary starts
                  // disabled, so it can't take autofocus either — two
                  // independent reasons an Enter hint would be a lie.
                  autofocus: false,
                  showEnterHint: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

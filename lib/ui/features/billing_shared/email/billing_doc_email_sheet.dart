import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/labeled_field.dart';
import 'package:admin/ui/features/billing_shared/email/schedule_email_picker.dart';
import 'package:admin/utils/formatting.dart';

/// Server-side email template names. Match admin-portal's
/// `kEmailTemplate*` constants + React's `EmailType` enum.
class BillingEmailTemplate {
  const BillingEmailTemplate._();

  static const String initial = 'invoice';
  static const String reminder1 = 'reminder1';
  static const String reminder2 = 'reminder2';
  static const String reminder3 = 'reminder3';
  static const String reminderEndless = 'reminder_endless';
  static const String custom1 = 'custom1';
  static const String custom2 = 'custom2';
  static const String custom3 = 'custom3';

  /// Default ordered set of templates for [BillingDocType.invoice]. Quote /
  /// Credit / PO start with `quote` / `credit` / `purchase_order` as the
  /// initial template name; templated reminders are invoice-only on the
  /// server today. The sheet's template picker uses [forType] to render
  /// the correct list.
  static List<({String value, String labelKey})> forType(BillingDocType t) {
    return switch (t) {
      BillingDocType.invoice => const [
        (value: initial, labelKey: 'initial_email'),
        (value: reminder1, labelKey: 'first_reminder'),
        (value: reminder2, labelKey: 'second_reminder'),
        (value: reminder3, labelKey: 'third_reminder'),
        (value: reminderEndless, labelKey: 'reminder_endless'),
        (value: custom1, labelKey: 'first_custom'),
        (value: custom2, labelKey: 'second_custom'),
        (value: custom3, labelKey: 'third_custom'),
      ],
      BillingDocType.quote => const [
        (value: 'quote', labelKey: 'initial_email'),
        (value: 'quote_reminder1', labelKey: 'first_reminder'),
        (value: custom1, labelKey: 'first_custom'),
        (value: custom2, labelKey: 'second_custom'),
        (value: custom3, labelKey: 'third_custom'),
      ],
      BillingDocType.credit => const [
        (value: 'credit', labelKey: 'initial_email'),
        (value: custom1, labelKey: 'first_custom'),
        (value: custom2, labelKey: 'second_custom'),
        (value: custom3, labelKey: 'third_custom'),
      ],
      BillingDocType.purchaseOrder => const [
        (value: 'purchase_order', labelKey: 'initial_email'),
        (value: custom1, labelKey: 'first_custom'),
        (value: custom2, labelKey: 'second_custom'),
        (value: custom3, labelKey: 'third_custom'),
      ],
      BillingDocType.recurringInvoice => const [
        (value: initial, labelKey: 'initial_email'),
      ],
    };
  }
}

/// Result of [showBillingDocEmailSheet] — caller dispatches to repo based
/// on `scheduledFor`. Null means the user cancelled.
class BillingEmailResult {
  const BillingEmailResult({
    required this.template,
    required this.subject,
    required this.body,
    required this.ccEmail,
    this.scheduledFor,
  });

  final String template;
  final String subject;
  final String body;
  final String ccEmail;

  /// When non-null, the email should be scheduled for this **local** wall
  /// clock instead of sent immediately — the picker's own value, unconverted.
  ///
  /// It documented itself as UTC and every caller then dutifully sent
  /// `.toUtc()`, which is wrong: the server truncates `send_at` to a date-only
  /// `next_run`, so converting shifts an evening pick to the NEXT calendar day
  /// east of UTC and to the PREVIOUS one west of it — the scheduled mail fires
  /// a day late, or immediately because the date is already past. Send
  /// `toIso8601String()` on this value as-is; a trailing `Z` on the wire means
  /// a conversion crept back in.
  final DateTime? scheduledFor;
}

/// Show the email-sending bottom sheet. Returns the chosen template +
/// optional overrides, or null if cancelled.
///
/// Parameterized by [BillingDocType] so future quote/credit/PO ports
/// reuse it without re-implementing the chrome. The caller wires the
/// `Send now` and `Schedule for later` outcomes through to
/// `repo.email(...)` / `repo.scheduleEmail(...)`.
///
/// The Preview / History / Activity tabs from admin-portal are
/// placeholders in M2 (templates are server-rendered, so a client-side
/// preview means fetching the rendered HTML — punted to M4 when the
/// activities feed lands).
Future<BillingEmailResult?> showBillingDocEmailSheet(
  BuildContext context, {
  required BillingDocType entity,
  required String entityNumber,
  required Formatter? formatter,
  bool allowSchedule = true,
}) {
  return showModalBottomSheet<BillingEmailResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EmailSheet(
      entity: entity,
      entityNumber: entityNumber,
      formatter: formatter,
      allowSchedule: allowSchedule,
    ),
  );
}

class _EmailSheet extends StatefulWidget {
  const _EmailSheet({
    required this.entity,
    required this.entityNumber,
    required this.formatter,
    required this.allowSchedule,
  });

  final BillingDocType entity;
  final String entityNumber;
  final Formatter? formatter;
  final bool allowSchedule;

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  late String _template;
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _ccController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _template = BillingEmailTemplate.forType(widget.entity).first.value;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _ccController.dispose();
    super.dispose();
  }

  BillingEmailResult _build({DateTime? scheduledFor}) {
    return BillingEmailResult(
      template: _template,
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      ccEmail: _ccController.text.trim(),
      scheduledFor: scheduledFor,
    );
  }

  Future<void> _onSchedule() async {
    final picked = await showScheduleEmailPicker(
      context,
      formatter: widget.formatter,
    );
    if (picked == null || !mounted) return;
    Navigator.of(context).pop(_build(scheduledFor: picked));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final templates = BillingEmailTemplate.forType(widget.entity);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Material(
            color: tokens.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(InRadii.r3),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      InSpacing.lg(context),
                      InSpacing.md(context),
                      InSpacing.md(context),
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.entityNumber.isEmpty
                                ? context.tr('send_email')
                                : '${context.tr('send_email')} · #${widget.entityNumber}',
                            style: TextStyle(
                              color: tokens.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: tokens.border),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.all(InSpacing.lg(context)),
                      children: [
                        LabeledField(
                          label: context.tr('template'),
                          child: DropdownButtonFormField<String>(
                            initialValue: _template,
                            isExpanded: true,
                            items: [
                              for (final t in templates)
                                DropdownMenuItem(
                                  value: t.value,
                                  child: Text(context.tr(t.labelKey)),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _template = v);
                            },
                          ),
                        ),
                        SizedBox(height: InSpacing.md(context)),
                        LabeledField(
                          label: context.tr('subject'),
                          child: TextField(
                            controller: _subjectController,
                            decoration: InputDecoration(
                              hintText: context.tr('use_default'),
                            ),
                          ),
                        ),
                        SizedBox(height: InSpacing.md(context)),
                        LabeledField(
                          label: context.tr('body'),
                          child: TextField(
                            controller: _bodyController,
                            maxLines: 8,
                            minLines: 4,
                            decoration: InputDecoration(
                              hintText: context.tr('use_default'),
                            ),
                          ),
                        ),
                        SizedBox(height: InSpacing.md(context)),
                        LabeledField(
                          label: context.tr('cc_email'),
                          child: TextField(
                            controller: _ccController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'name@example.com',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: tokens.border),
                  Padding(
                    padding: EdgeInsets.all(InSpacing.lg(context)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.allowSchedule)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(64, 40),
                            ),
                            icon: const Icon(Icons.schedule_outlined, size: 18),
                            label: Text(context.tr('schedule')),
                            onPressed: _onSchedule,
                          ),
                        if (widget.allowSchedule) const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(64, 44),
                          ),
                          icon: const Icon(Icons.send, size: 18),
                          label: Text(context.tr('send_now')),
                          // Just return the result — the dispatch handler
                          // owns the toast (R2 fix). Firing Notify here would
                          // use a popped context AND lie about queued state
                          // before the repository call had actually run.
                          onPressed: () => Navigator.of(context).pop(_build()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

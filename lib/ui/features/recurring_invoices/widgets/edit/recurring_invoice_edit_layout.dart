import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_layout.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_edit_field_decoration.dart';
import 'package:admin/ui/features/billing_shared/edit/e_invoice_fields_tab.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_draft_preview.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// The recurring-invoice edit body: [BillingDocEditLayout] as a recurring
/// invoice. What makes it one is [BillingDocType.recurringInvoice] — no
/// document or due date (its schedule decides them), no partial payment, no
/// "Save as default" (occurrences inherit the invoice's terms) — plus its
/// schedule (a desktop card in the dates card's place, a narrow tab after
/// Details), its auto-bill mode, its PDF fetcher and an E-Invoice tab.
///
/// Note this is the one strip that still scrolls on a phone after
/// invoiceninja/flutter#140: six sections plus Schedule is ~472 px of a
/// ~411 px viewport. Hence the edge fades — the residue is meant to look
/// scrollable, which is what it never did before.
class RecurringInvoiceEditLayout extends StatelessWidget {
  const RecurringInvoiceEditLayout({
    super.key,
    required this.vm,
    this.showPdfTab = true,
  });

  final RecurringInvoiceEditViewModel vm;

  /// Whether the narrow strip carries a `PDF` tab — see
  /// [BillingDocEditLayout.showPdfTab] (invoiceninja/flutter#140).
  final bool showPdfTab;

  @override
  Widget build(BuildContext context) => BillingDocEditLayout<RecurringInvoice>(
    type: BillingDocType.recurringInvoice,
    vm: vm,
    showPdfTab: showPdfTab,
    slots: BillingDocEditSlots(
      pdfFetcher: (context) => _draftPdfFetcher(context, vm),
      scheduleCard: (context) => _ScheduleCardDesktop(vm: vm),
      scheduleTab: (context) => _ScheduleTab(vm: vm),
      autoBillMode: (context, {required desktop}) =>
          _AutoBillModeField(vm: vm, desktop: desktop),
      eInvoiceTab: (context) => EInvoiceFieldsTab<RecurringInvoice>(
        vm: vm,
        entityKind: EInvoiceEntityKind.recurringInvoice,
        formatter: context.read<Services>().formatterIfReady(vm.companyId),
      ),
    ),
  );
}

/// The one `live_preview` fetcher for a recurring-invoice draft — shared by
/// the PDF tab, the desktop pane and the header's preview button.
BillingDocPdfFetcher _draftPdfFetcher(
  BuildContext context,
  RecurringInvoiceEditViewModel vm,
) {
  final services = context.read<Services>();
  return ({String? designId, required bool deliveryNote}) =>
      services.recurringInvoices.api.downloadPdf(
        entityJson: vm.draft.toApiJson(),
        designId:
            designId ?? (vm.draft.designId.isEmpty ? null : vm.draft.designId),
      );
}

/// The narrow edit header's draft-PDF button — see
/// [billingDocDraftPreviewButton].
Widget recurringInvoiceDraftPreviewButton(
  BuildContext context,
  RecurringInvoiceEditViewModel vm,
) => billingDocDraftPreviewButton(
  BillingDocType.recurringInvoice,
  vm,
  _draftPdfFetcher(context, vm),
);

/// The auto-bill mode (`off` / `always` / `optout` / `optin`), after Discount
/// on the desktop number card and the narrow Details tab. There is no
/// separate `auto_bill_enabled` toggle: the server derives it from this
/// field (`always` / `optout` → true) and overwrites it on save — see
/// `RecurringInvoiceEditViewModel.setAutoBill`. Matches React.
class _AutoBillModeField extends StatelessWidget {
  const _AutoBillModeField({required this.vm, required this.desktop});
  final RecurringInvoiceEditViewModel vm;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: vm.draft.autoBill.isEmpty ? 'off' : vm.draft.autoBill,
      decoration: desktop
          ? billingFieldDecoration(context, label: context.tr('auto_bill'))
          : InputDecoration(labelText: context.tr('auto_bill')),
      items: _autoBillItems(context),
      onChanged: (v) => vm.setAutoBill(v ?? 'off'),
    );
  }
}

class _ScheduleCardDesktop extends StatelessWidget {
  const _ScheduleCardDesktop({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final fmt = context.read<Services>().formatterIfReady(vm.companyId);
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        DropdownButtonFormField<String>(
          initialValue: vm.draft.frequencyId.isEmpty
              ? null
              : vm.draft.frequencyId,
          decoration: billingFieldDecoration(
            context,
            label: context.tr('frequency'),
          ),
          items: _frequencyItems(context),
          onChanged: (v) => vm.setFrequencyId(v ?? ''),
        ),
        SizedBox(height: InSpacing.md(context)),
        InDateField(
          value: vm.draft.nextSendDate?.toDateTime(),
          formatter: fmt,
          onChanged: (d) {
            if (d == null) {
              vm.setNextSendDate(null);
            } else {
              vm.setNextSendDate(Date(d.year, d.month, d.day));
            }
          },
          labelText: context.tr('next_send_date'),
          clearable: true,
        ),
        if (vm.draft.nextSendDate != null) _NextSendPreview(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        _RemainingCyclesField(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        _DueDateDaysField(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        EntityCustomFieldsSection(
          keyPrefix: 'invoice',
          companyStream: context.read<Services>().company.watchCompany(
            vm.companyId,
          ),
          formatter: context.read<Services>().formatterIfReady(vm.companyId),
          values: [
            vm.draft.customValue1,
            vm.draft.customValue2,
            vm.draft.customValue3,
            vm.draft.customValue4,
          ],
          onChanged: [
            vm.setCustomValue1,
            vm.setCustomValue2,
            vm.setCustomValue3,
            vm.setCustomValue4,
          ],
          wrapInCard: false,
          slots: const [1, 3],
        ),
      ],
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final fmt = context.read<Services>().formatterIfReady(vm.companyId);
    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: vm.draft.frequencyId.isEmpty
                ? null
                : vm.draft.frequencyId,
            decoration: InputDecoration(labelText: context.tr('frequency')),
            items: _frequencyItems(context),
            onChanged: (v) => vm.setFrequencyId(v ?? ''),
          ),
          SizedBox(height: InSpacing.md(context)),
          InDateField(
            value: vm.draft.nextSendDate?.toDateTime(),
            formatter: fmt,
            onChanged: (d) {
              if (d == null) {
                vm.setNextSendDate(null);
              } else {
                vm.setNextSendDate(Date(d.year, d.month, d.day));
              }
            },
            labelText: context.tr('next_send_date'),
            clearable: true,
          ),
          if (vm.draft.nextSendDate != null) _NextSendPreview(vm: vm),
          SizedBox(height: InSpacing.md(context)),
          _RemainingCyclesField(vm: vm),
          SizedBox(height: InSpacing.md(context)),
          _DueDateDaysField(vm: vm),
        ],
      ),
    );
  }
}

/// Frequency dropdown items, shared by the desktop card and the mobile
/// schedule tab. Backed by [kRecurringFrequencyOrdered] /
/// [kRecurringFrequencyLabelKey] (`lib/domain/recurring_frequency.dart`) —
/// the same canonical id→`freq_*` map used by recurring expenses and
/// payment links. Previously this hand-rolled its own `frequency_*` keys,
/// none of which existed in any locale file, so the desktop dropdown
/// rendered raw keys to users.
List<DropdownMenuItem<String>> _frequencyItems(BuildContext context) => [
  for (final id in kRecurringFrequencyOrdered)
    DropdownMenuItem(
      value: id,
      child: Text(context.tr(kRecurringFrequencyLabelKey[id]!)),
    ),
];

/// Auto-bill mode items, shared by the desktop card and the mobile schedule
/// tab. Values match the server (`off` / `always` / `optout` / `optin`);
/// `always` is labelled "Enabled" to match the React form.
List<DropdownMenuItem<String>> _autoBillItems(BuildContext context) => [
  DropdownMenuItem(value: 'off', child: Text(context.tr('off'))),
  DropdownMenuItem(value: 'always', child: Text(context.tr('enabled'))),
  DropdownMenuItem(value: 'optout', child: Text(context.tr('opt_out'))),
  DropdownMenuItem(value: 'optin', child: Text(context.tr('opt_in'))),
];

/// `due_date_days` options: `terms` + day-of-month `1..31` (matches React /
/// admin-portal). An unrecognized stored value (e.g. a legacy `on_receipt`) is
/// preserved at the head so the picker never silently drops it.
List<String> _dueDateDaysOptions(String current) {
  final base = <String>['terms', for (var i = 1; i <= 31; i++) '$i'];
  if (current.isNotEmpty && !base.contains(current)) return [current, ...base];
  return base;
}

String _dueDateDaysLabel(BuildContext context, String v) => switch (v) {
  'terms' => context.tr('use_payment_terms'),
  '1' => context.tr('first_day_of_the_month'),
  '31' => context.tr('last_day_of_the_month'),
  _ => int.tryParse(v) != null ? context.tr('day_count', {'count': v}) : v,
};

/// `remaining_cycles` options: endless (`-1`) + `0..36`. An out-of-range stored
/// value is preserved (same anti-drop guard as due-date days).
List<String> _remainingCyclesOptions(int current) {
  final base = <String>['-1', for (var i = 0; i <= 36; i++) '$i'];
  final cur = '$current';
  if (!base.contains(cur)) return [cur, ...base];
  return base;
}

/// Searchable `due_date_days` picker — shared by desktop + mobile so the two
/// layouts can't drift. >20 options ⇒ searchable (CLAUDE.md). Clearing falls
/// back to `terms` (the server default), never an empty value.
class _DueDateDaysField extends StatelessWidget {
  const _DueDateDaysField({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final current = vm.draft.dueDateDays;
    return SearchableDropdownField<String>(
      label: context.tr('due_date_days'),
      items: _dueDateDaysOptions(current),
      initialValue: current.isEmpty ? null : current,
      displayString: (v) => _dueDateDaysLabel(context, v),
      idOf: (v) => v,
      onChanged: (v) => vm.setDueDateDays(v ?? 'terms'),
    );
  }
}

/// Searchable `remaining_cycles` picker — shared by desktop + mobile. Clearing
/// falls back to `-1` (endless).
class _RemainingCyclesField extends StatelessWidget {
  const _RemainingCyclesField({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final current = vm.draft.remainingCycles;
    return SearchableDropdownField<String>(
      label: context.tr('remaining_cycles'),
      items: _remainingCyclesOptions(current),
      initialValue: '$current',
      displayString: (v) => v == '-1' ? context.tr('endless') : v,
      idOf: (v) => v,
      onChanged: (v) => vm.setRemainingCycles(int.tryParse(v ?? '') ?? -1),
    );
  }
}

/// "Next: d1, d2, d3" inline preview of the upcoming send dates, computed
/// client-side from `nextSendDate` + `frequencyId` via [nextSendAfter] (mirrors
/// the recurring-expense schedule preview). Dates render through the company
/// [Formatter] so they honor the configured date format.
class _NextSendPreview extends StatelessWidget {
  const _NextSendPreview({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final start = vm.draft.nextSendDate;
    final freq = vm.draft.frequencyId;
    if (start == null || freq.isEmpty) return const SizedBox.shrink();
    final fmt = context.read<Services>().formatterIfReady(vm.companyId);
    // The preview is purely informational; without a formatter, skip it rather
    // than render raw ISO dates (see the Formatter rule in CLAUDE.md).
    if (fmt == null) return const SizedBox.shrink();
    final previews = <String>[];
    for (var i = 0; i < 3; i++) {
      final d = nextSendAfter(start, freq, i);
      if (d == null) break;
      previews.add(fmt.date(d.toIso()));
    }
    if (previews.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: InSpacing.sm),
      child: Text(
        '${context.tr('next')}: ${previews.join(', ')}',
        style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
      ),
    );
  }
}

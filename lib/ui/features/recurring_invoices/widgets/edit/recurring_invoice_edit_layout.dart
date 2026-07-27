import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_contact.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/contacts/billing_doc_contacts_section.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_desktop_shell.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_fab.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_settings_tab.dart';
import 'package:admin/ui/features/billing_shared/edit/e_invoice_fields_tab.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_edit_field_decoration.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/items/billing_doc_items_tabs.dart';
import 'package:admin/ui/features/billing_shared/line_item_picker/line_item_picker_invoke.dart';
import 'package:admin/ui/features/billing_shared/markdown_notes_section.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/ui/features/billing_shared/billing_edit_totals.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_tax_surcharge_section.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Tabbed body for the recurring-invoice edit screen. Adds a Schedule
/// tab to the Quote/Credit/PO layout for frequency + next_send_date +
/// remaining_cycles + auto_bill.
class RecurringInvoiceEditLayout extends StatefulWidget {
  const RecurringInvoiceEditLayout({super.key, required this.vm});

  final RecurringInvoiceEditViewModel vm;

  @override
  State<RecurringInvoiceEditLayout> createState() =>
      _RecurringInvoiceEditLayoutState();
}

class _RecurringInvoiceEditLayoutState extends State<RecurringInvoiceEditLayout>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    // 8 tabs: Details / Schedule / Contacts / Items / Notes / Settings /
    // PDF / E-Invoice. Settings (project / vendor / user / exchange-rate /
    // auto-bill) was desktop-only; mobile now gets it as its own tab so those
    // fields are reachable on a phone.
    _tab = TabController(length: 8, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final services = context.read<Services>();
      widget.vm.hydrateSourceClientIds(
        services: services,
        companyId: widget.vm.companyId,
      );
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.vm,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1024;
            return wide
                ? _buildDesktop(context)
                : CenteredFormColumn(child: _buildMobile(context));
          },
        );
      },
    );
  }

  Widget _stickyTotals(BuildContext context) => Padding(
    padding: EdgeInsets.all(InSpacing.md(context)),
    child: BillingEditTotals(
      totalsAt: widget.vm.totalsAt,
      clientId: widget.vm.draft.clientId,
      discount: widget.vm.draft.discount,
      discountIsAmount: widget.vm.draft.isAmountDiscount,
      surchargeAmounts: [
        widget.vm.draft.customSurcharge1,
        widget.vm.draft.customSurcharge2,
        widget.vm.draft.customSurcharge3,
        widget.vm.draft.customSurcharge4,
      ],
      dense: true,
    ),
  );

  Widget _totalsCard(BuildContext context) => BillingEditTotals(
    totalsAt: widget.vm.totalsAt,
    clientId: widget.vm.draft.clientId,
    discount: widget.vm.draft.discount,
    discountIsAmount: widget.vm.draft.isAmountDiscount,
    surchargeAmounts: [
      widget.vm.draft.customSurcharge1,
      widget.vm.draft.customSurcharge2,
      widget.vm.draft.customSurcharge3,
      widget.vm.draft.customSurcharge4,
    ],
    bordered: false,
  );

  Widget _slimTotals(BuildContext context) => BillingEditTotals(
    totalsAt: widget.vm.totalsAt,
    clientId: widget.vm.draft.clientId,
    discount: widget.vm.draft.discount,
    discountIsAmount: widget.vm.draft.isAmountDiscount,
    surchargeAmounts: [
      widget.vm.draft.customSurcharge1,
      widget.vm.draft.customSurcharge2,
      widget.vm.draft.customSurcharge3,
      widget.vm.draft.customSurcharge4,
    ],
    dense: true,
    slim: true,
  );

  void _openPicker(BuildContext context) {
    final vm = widget.vm;
    openLineItemPicker(
      context,
      companyId: vm.companyId,
      clientId: vm.draft.clientId,
      showTasksAndExpenses: true,
      invoiceInclusive: vm.draft.usesInclusiveTaxes,
      currentLineItems: vm.draft.lineItems,
      currentProjectId: vm.draft.projectId,
      currentClientId: vm.draft.clientId,
      replaceLineItems: vm.replaceLineItems,
      setProjectId: vm.setProjectId,
      setClientId: vm.setClientId,
      registerSourceClientIds: (tasks, expenses) =>
          vm.registerSourceClientIds(tasks: tasks, expenses: expenses),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: tokens.surface,
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabs: [
              Tab(text: context.tr('details')),
              Tab(text: context.tr('schedule')),
              Tab(text: context.tr('contacts')),
              Tab(text: context.tr('items')),
              Tab(text: context.tr('notes')),
              Tab(text: context.tr('settings')),
              Tab(text: context.tr('pdf')),
              Tab(text: context.tr('e_invoice')),
            ],
          ),
        ),
        Divider(height: 1, color: tokens.border),
        // `Material` so every tab body's TextFields have a Material
        // ancestor (the TabBar above is already wrapped; the bodies were
        // not — that's the `No Material widget found` cluster).
        // Transparency = no visual change.
        Expanded(
          child: Material(
            type: MaterialType.transparency,
            // Rebuild children on tab change so inactive tabs are excluded
            // from directional (arrow-key) focus traversal — a kept-alive
            // off-stage tab whose RenderObject is NEEDS-LAYOUT otherwise
            // crashes `findFirstFocusInDirection` (the `hasSize` cluster).
            child: AnimatedBuilder(
              animation: _tab,
              builder: (context, _) {
                Widget tab(int i, Widget child) => ExcludeFocusTraversal(
                  excluding: i != _tab.index,
                  child: child,
                );
                return TabBarView(
                  controller: _tab,
                  children: [
                    tab(0, _DetailsTab(vm: widget.vm)),
                    tab(1, _ScheduleTab(vm: widget.vm)),
                    tab(2, _ContactsTab(vm: widget.vm)),
                    tab(
                      3,
                      _ItemsTab(
                        vm: widget.vm,
                        onPickItems: () => _openPicker(context),
                      ),
                    ),
                    tab(4, _NotesTab(vm: widget.vm)),
                    tab(5, _SettingsTab(vm: widget.vm)),
                    tab(6, _PdfTab(vm: widget.vm)),
                    tab(
                      7,
                      EInvoiceFieldsTab<RecurringInvoice>(
                        vm: widget.vm,
                        entityKind: EInvoiceEntityKind.recurringInvoice,
                        formatter: context.read<Services>().formatterIfReady(
                          widget.vm.companyId,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Divider(height: 1, color: tokens.border),
        _stickyTotals(context),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final shell = BillingDocEditDesktopShell(
      topRow: (ctx, slot) => switch (slot) {
        0 => _ClientCardDesktop(vm: widget.vm),
        1 => _ScheduleCardDesktop(vm: widget.vm),
        2 => _NumberCardDesktop(vm: widget.vm),
        _ => const SizedBox.shrink(),
      },
      itemsSection: _ItemsSectionDesktop(
        vm: widget.vm,
        onPickItems: () => _openPicker(context),
      ),
      notesTabsCard: _NotesTabsCardDesktop(vm: widget.vm),
      totalsCard: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TaxSurchargeSection(vm: widget.vm),
          _totalsCard(context),
        ],
      ),
      pdfPane: _PdfPaneDesktop(vm: widget.vm),
      stickyTotals: _slimTotals(context),
    );
    return BillingDocEditPickerShortcuts(
      onPickItems: () => _openPicker(context),
      child: Stack(
        children: [
          shell,
          Positioned(
            bottom: 72,
            right: 24,
            child: BillingDocEditFab(
              heroTag: 'recurring_invoice_picker_fab',
              onPressed: () => _openPicker(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop multi-column cards ───────────────────────────────────────

class _ClientCardDesktop extends StatelessWidget {
  const _ClientCardDesktop({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        _ClientPicker(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        _ContactsForClient(vm: vm),
      ],
    );
  }
}

class _ContactsForClient extends StatelessWidget {
  const _ContactsForClient({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.draft.clientId.isEmpty) {
      return const SizedBox.shrink();
    }
    final services = context.read<Services>();
    return StreamBuilder<Client?>(
      stream: services.clients.watch(
        companyId: vm.companyId,
        id: vm.draft.clientId,
      ),
      builder: (context, snapshot) {
        final client = snapshot.data;
        if (client == null) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        final selected = vm.draft.invitations
            .map((i) => i.clientContactId)
            .where((id) => id.isNotEmpty)
            .toSet();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(
            child: BillingDocContactsSection(
              contacts: client.contacts.map((c) => c.toBilling()).toList(),
              selectedContactIds: selected,
              onChanged: (next) {
                final added = next.difference(selected);
                final removed = selected.difference(next);
                for (final id in added) {
                  vm.setContactInvitation(id, true);
                }
                for (final id in removed) {
                  vm.setContactInvitation(id, false);
                }
              },
            ),
          ),
        );
      },
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

class _NumberCardDesktop extends StatefulWidget {
  const _NumberCardDesktop({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  State<_NumberCardDesktop> createState() => _NumberCardDesktopState();
}

class _NumberCardDesktopState extends State<_NumberCardDesktop> {
  late final TextEditingController _number;
  late final TextEditingController _poNumber;
  late final TextEditingController _discount;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: widget.vm.draft.number);
    _poNumber = TextEditingController(text: widget.vm.draft.poNumber);
    _discount = TextEditingController(
      text: widget.vm.draft.discount == Decimal.zero
          ? ''
          : widget.vm.draft.discount.toString(),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _poNumber.dispose();
    _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        TextField(
          controller: _number,
          decoration: billingFieldDecoration(
            context,
            label: context.tr('invoice_number'),
            hint: vm.isCreate ? context.tr('auto_generated') : null,
            errorText: vm.fieldErrorFor('number'),
          ),
          onChanged: vm.setNumber,
        ),
        SizedBox(height: InSpacing.md(context)),
        TextField(
          controller: _poNumber,
          decoration: billingFieldDecoration(
            context,
            label: context.tr('po_number'),
          ),
          onChanged: vm.setPoNumber,
        ),
        SizedBox(height: InSpacing.md(context)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _discount,
                decoration: billingFieldDecoration(
                  context,
                  label: context.tr('discount'),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) =>
                    vm.setDiscount(v, isAmount: vm.draft.isAmountDiscount),
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(context.tr('percent'))),
                ButtonSegment(value: true, label: Text(context.tr('amount'))),
              ],
              selected: {vm.draft.isAmountDiscount},
              onSelectionChanged: (s) =>
                  vm.setDiscount(_discount.text, isAmount: s.first),
            ),
          ],
        ),
        SizedBox(height: InSpacing.md(context)),
        DropdownButtonFormField<String>(
          initialValue: vm.draft.autoBill.isEmpty ? 'off' : vm.draft.autoBill,
          decoration: billingFieldDecoration(
            context,
            label: context.tr('auto_bill'),
          ),
          items: _autoBillItems(context),
          onChanged: (v) => vm.setAutoBill(v ?? 'off'),
        ),
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
          slots: const [2, 4],
        ),
      ],
    );
  }
}

class _ItemsSectionDesktop extends StatelessWidget {
  const _ItemsSectionDesktop({required this.vm, required this.onPickItems});
  final RecurringInvoiceEditViewModel vm;
  final VoidCallback onPickItems;

  @override
  Widget build(BuildContext context) {
    return BillingDocItemsTabs(
      vm: vm,
      companyId: vm.companyId,
      lineItems: vm.draft.lineItems,
      onChanged: vm.replaceLineItems,
      newItemFactory: emptyLineItem,
      config: const LineItemColumnConfig(showDiscount: true, taxColumnCount: 1),
      rowErrors: vm.lineItemRowErrors,
      onPickItems: onPickItems,
    );
  }
}

class _NotesTabsCardDesktop extends StatefulWidget {
  const _NotesTabsCardDesktop({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  State<_NotesTabsCardDesktop> createState() => _NotesTabsCardDesktopState();
}

class _NotesTabsCardDesktopState extends State<_NotesTabsCardDesktop>
    with SingleTickerProviderStateMixin {
  late final TabController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final tokens = context.inTheme;
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        TabBar(
          controller: _ctl,
          isScrollable: true,
          labelColor: tokens.ink,
          unselectedLabelColor: tokens.ink3,
          tabs: [
            Tab(text: context.tr('terms')),
            Tab(text: context.tr('footer')),
            Tab(text: context.tr('public_notes')),
            Tab(text: context.tr('private_notes')),
            Tab(text: context.tr('settings')),
            Tab(text: context.tr('e_invoice')),
          ],
        ),
        Divider(height: 1, color: context.inTheme.border),
        SizedBox(
          height: BillingDocEditDesktopShell.notesPaneHeight(context),
          child: TabBarView(
            controller: _ctl,
            children: [
              // Intentionally no "Save as default": recurring invoices
              // have no separate settings key — they inherit
              // invoice_terms / invoice_footer when each occurrence is
              // generated. Matches legacy admin-portal behavior.
              MarkdownNotesField(
                registerBeforeSaveHook: vm.addBeforeSaveHook,
                label: context.tr('terms'),
                showLabel: false,
                expand: true,
                value: vm.draft.terms,
                onChanged: vm.setTerms,
              ),
              MarkdownNotesField(
                registerBeforeSaveHook: vm.addBeforeSaveHook,
                label: context.tr('footer'),
                showLabel: false,
                expand: true,
                value: vm.draft.footer,
                onChanged: vm.setFooter,
              ),
              MarkdownNotesField(
                registerBeforeSaveHook: vm.addBeforeSaveHook,
                label: context.tr('public_notes'),
                showLabel: false,
                expand: true,
                value: vm.draft.publicNotes,
                onChanged: vm.setPublicNotes,
              ),
              MarkdownNotesField(
                registerBeforeSaveHook: vm.addBeforeSaveHook,
                label: context.tr('private_notes'),
                showLabel: false,
                expand: true,
                value: vm.draft.privateNotes,
                onChanged: vm.setPrivateNotes,
              ),
              SingleChildScrollView(
                child: BillingDocSettingsTab(
                  companyId: vm.companyId,
                  entityType: 'recurring_invoice',
                  tagIds: vm.draft.tagIds,
                  onTagIdsChanged: vm.setTagIds,
                  designId: vm.draft.designId,
                  onDesignChanged: vm.setDesignId,
                  userId: vm.draft.assignedUserId,
                  onUserChanged: vm.setAssignedUserId,
                  projectId: vm.draft.projectId,
                  onProjectChanged: vm.setProjectId,
                  vendorId: vm.draft.vendorId,
                  onVendorChanged: vm.setVendorId,
                  exchangeRate: vm.draft.exchangeRate.toString(),
                  onExchangeRateChanged: vm.setExchangeRate,
                  // No auto_bill_enabled toggle: for recurring invoices the
                  // server derives it from `auto_bill` (always/optout → true)
                  // and overwrites it on save, so an editable toggle here does
                  // nothing. The `auto_bill` field (Schedule tab) is the real
                  // control. Matches React, which omits the toggle entirely.
                ),
              ),
              EInvoiceFieldsTab<RecurringInvoice>(
                vm: vm,
                entityKind: EInvoiceEntityKind.recurringInvoice,
                formatter: context.read<Services>().formatterIfReady(
                  vm.companyId,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PdfPaneDesktop extends StatelessWidget {
  const _PdfPaneDesktop({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        SizedBox(
          height: BillingDocEditDesktopShell.fullWidthPdfHeight(context),
          child: _PdfTab(vm: vm),
        ),
      ],
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

/// Document-level tax tiers + custom surcharges + inclusive-tax toggle.
/// Self-collapses when the company has no enabled tax rates and no surcharge
/// labels configured (so it adds no chrome when unused).
class _TaxSurchargeSection extends StatelessWidget {
  const _TaxSurchargeSection({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final d = vm.draft;
    return BillingTaxSurchargeSection(
      companyId: vm.companyId,
      taxRows: [
        (
          name: d.taxName1,
          rate: d.taxRate1,
          onName: vm.setTaxName1,
          onRate: vm.setTaxRate1,
        ),
        (
          name: d.taxName2,
          rate: d.taxRate2,
          onName: vm.setTaxName2,
          onRate: vm.setTaxRate2,
        ),
        (
          name: d.taxName3,
          rate: d.taxRate3,
          onName: vm.setTaxName3,
          onRate: vm.setTaxRate3,
        ),
      ],
      usesInclusiveTaxes: d.usesInclusiveTaxes,
      onInclusiveChanged: vm.setUsesInclusiveTaxes,
      surcharges: [
        (amount: d.customSurcharge1, onAmount: vm.setCustomSurcharge1),
        (amount: d.customSurcharge2, onAmount: vm.setCustomSurcharge2),
        (amount: d.customSurcharge3, onAmount: vm.setCustomSurcharge3),
        (amount: d.customSurcharge4, onAmount: vm.setCustomSurcharge4),
      ],
    );
  }
}

class _DetailsTab extends StatefulWidget {
  const _DetailsTab({required this.vm});
  final RecurringInvoiceEditViewModel vm;
  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  late final TextEditingController _number;
  late final TextEditingController _poNumber;
  late final TextEditingController _discount;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: widget.vm.draft.number);
    _poNumber = TextEditingController(text: widget.vm.draft.poNumber);
    _discount = TextEditingController(
      text: widget.vm.draft.discount == Decimal.zero
          ? ''
          : widget.vm.draft.discount.toString(),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _poNumber.dispose();
    _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClientPicker(vm: vm),
          SizedBox(height: InSpacing.lg(context)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _number,
                  decoration: InputDecoration(
                    labelText: context.tr('recurring_invoice_number'),
                    hintText: vm.isCreate ? context.tr('auto_generated') : null,
                    errorText: vm.fieldErrorFor('number'),
                  ),
                  onChanged: vm.setNumber,
                ),
              ),
              SizedBox(width: InSpacing.md(context)),
              Expanded(
                child: TextField(
                  controller: _poNumber,
                  decoration: InputDecoration(
                    labelText: context.tr('po_number'),
                  ),
                  onChanged: vm.setPoNumber,
                ),
              ),
            ],
          ),
          SizedBox(height: InSpacing.md(context)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _discount,
                  decoration: InputDecoration(
                    labelText: context.tr('discount'),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) =>
                      vm.setDiscount(v, isAmount: vm.draft.isAmountDiscount),
                ),
              ),
              SizedBox(width: InSpacing.md(context)),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(context.tr('percent')),
                  ),
                  ButtonSegment(value: true, label: Text(context.tr('amount'))),
                ],
                selected: {vm.draft.isAmountDiscount},
                onSelectionChanged: (s) =>
                    vm.setDiscount(_discount.text, isAmount: s.first),
              ),
            ],
          ),
          SizedBox(height: InSpacing.md(context)),
          DropdownButtonFormField<String>(
            initialValue: vm.draft.autoBill.isEmpty ? 'off' : vm.draft.autoBill,
            decoration: InputDecoration(labelText: context.tr('auto_bill')),
            items: _autoBillItems(context),
            onChanged: (v) => vm.setAutoBill(v ?? 'off'),
          ),
          _TaxSurchargeSection(vm: vm),
          SizedBox(height: InSpacing.lg(context)),
          _DesignPicker(vm: vm),
          SizedBox(height: InSpacing.lg(context)),
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
            cardTitle: context.tr('custom_fields'),
          ),
        ],
      ),
    );
  }
}

class _DesignPicker extends StatelessWidget {
  const _DesignPicker({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<List<Design>>(
      stream: services.designs.watchAll(companyId: vm.companyId),
      builder: (context, snapshot) {
        final designs = snapshot.data ?? const <Design>[];
        Design? selected;
        for (final d in designs) {
          if (d.id == vm.draft.designId) {
            selected = d;
            break;
          }
        }
        return SearchableDropdownField<Design>(
          label: context.tr('design'),
          items: designs,
          initialValue: selected,
          displayString: (d) => d.name,
          idOf: (d) => d.id,
          onChanged: (d) => vm.setDesignId(d?.id ?? ''),
        );
      },
    );
  }
}

/// Mobile "Settings" tab — Project / Vendor / User / Exchange-Rate / Auto-Bill
/// (+ Design). Desktop renders these in a sub-tab of the notes card; mobile
/// previously had no tab for them, so those fields were uneditable on a phone.
class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: BillingDocSettingsTab(
        companyId: vm.companyId,
        entityType: 'recurring_invoice',
        tagIds: vm.draft.tagIds,
        onTagIdsChanged: vm.setTagIds,
        designId: vm.draft.designId,
        onDesignChanged: vm.setDesignId,
        userId: vm.draft.assignedUserId,
        onUserChanged: vm.setAssignedUserId,
        projectId: vm.draft.projectId,
        onProjectChanged: vm.setProjectId,
        vendorId: vm.draft.vendorId,
        onVendorChanged: vm.setVendorId,
        exchangeRate: vm.draft.exchangeRate.toString(),
        onExchangeRateChanged: vm.setExchangeRate,
        // No auto_bill_enabled toggle for recurring — server-derived from
        // `auto_bill` and overwritten on save (see the desktop layout note).
      ),
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

class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<List<Client>>(
      stream: services.clients.watchPage(
        companyId: vm.companyId,
        loadedPages: 100,
      ),
      builder: (context, snapshot) {
        final clients = snapshot.data ?? const <Client>[];
        Client? selected;
        for (final c in clients) {
          if (c.id == vm.draft.clientId) {
            selected = c;
            break;
          }
        }
        return SearchableDropdownField<Client>(
          label: context.tr('client'),
          items: clients,
          initialValue: selected,
          displayString: (c) => c.displayName.isEmpty ? c.name : c.displayName,
          idOf: (c) => c.id,
          onChanged: (c) =>
              vm.selectClient(c?.id ?? '', c?.contacts ?? const []),
          errorText: vm.fieldErrorFor('client_id'),
        );
      },
    );
  }
}

class _ContactsTab extends StatelessWidget {
  const _ContactsTab({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.draft.clientId.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Text(
            context.tr('select_a_client_first'),
            style: TextStyle(color: context.inTheme.ink3),
          ),
        ),
      );
    }
    final services = context.read<Services>();
    return StreamBuilder<Client?>(
      stream: services.clients.watch(
        companyId: vm.companyId,
        id: vm.draft.clientId,
      ),
      builder: (context, snapshot) {
        final client = snapshot.data;
        if (client == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final selected = vm.draft.invitations
            .map((i) => i.clientContactId)
            .where((id) => id.isNotEmpty)
            .toSet();
        return ListView(
          padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
          children: [
            BillingDocContactsSection(
              contacts: client.contacts.map((c) => c.toBilling()).toList(),
              selectedContactIds: selected,
              onChanged: (next) {
                final added = next.difference(selected);
                final removed = selected.difference(next);
                for (final id in added) {
                  vm.setContactInvitation(id, true);
                }
                for (final id in removed) {
                  vm.setContactInvitation(id, false);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _ItemsTab extends StatelessWidget {
  const _ItemsTab({required this.vm, required this.onPickItems});
  final RecurringInvoiceEditViewModel vm;
  final VoidCallback onPickItems;

  @override
  Widget build(BuildContext context) {
    return BillingDocEditPickerShortcuts(
      onPickItems: onPickItems,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(InSpacing.lg(context)),
            child: BillingDocItemsTabs(
              vm: vm,
              companyId: vm.companyId,
              lineItems: vm.draft.lineItems,
              onChanged: vm.replaceLineItems,
              newItemFactory: emptyLineItem,
              config: const LineItemColumnConfig(
                showDiscount: true,
                taxColumnCount: 1,
              ),
              rowErrors: vm.lineItemRowErrors,
              onPickItems: onPickItems,
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: BillingDocEditFab(
              heroTag: 'recurring_invoice_picker_fab_mobile',
              onPressed: onPickItems,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      children: [
        MarkdownNotesField(
          registerBeforeSaveHook: vm.addBeforeSaveHook,
          label: context.tr('public_notes'),
          value: vm.draft.publicNotes,
          onChanged: vm.setPublicNotes,
        ),
        SizedBox(height: InSpacing.lg(context)),
        MarkdownNotesField(
          registerBeforeSaveHook: vm.addBeforeSaveHook,
          label: context.tr('private_notes'),
          value: vm.draft.privateNotes,
          onChanged: vm.setPrivateNotes,
        ),
        SizedBox(height: InSpacing.lg(context)),
        MarkdownNotesField(
          registerBeforeSaveHook: vm.addBeforeSaveHook,
          label: context.tr('terms'),
          value: vm.draft.terms,
          onChanged: vm.setTerms,
        ),
        SizedBox(height: InSpacing.lg(context)),
        MarkdownNotesField(
          registerBeforeSaveHook: vm.addBeforeSaveHook,
          label: context.tr('footer'),
          value: vm.draft.footer,
          onChanged: vm.setFooter,
        ),
      ],
    );
  }
}

class _PdfTab extends StatelessWidget {
  const _PdfTab({required this.vm});
  final RecurringInvoiceEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.draft.clientId.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Text(
            context.tr('please_select_a_client'),
            style: TextStyle(color: context.inTheme.ink3),
          ),
        ),
      );
    }
    final services = context.read<Services>();
    return BillingDocPdfView(
      entity: BillingDocType.recurringInvoice,
      entityNumber: vm.draft.number,
      revision: vm.draft,
      fetcher: ({String? designId, required bool deliveryNote}) =>
          services.recurringInvoices.api.downloadPdf(
            entityJson: vm.draft.toApiJson(),
            designId:
                designId ??
                (vm.draft.designId.isEmpty ? null : vm.draft.designId),
          ),
    );
  }
}

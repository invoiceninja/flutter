import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_contact.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/billing_edit_totals.dart';
import 'package:admin/ui/features/billing_shared/contacts/billing_doc_contacts_section.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_client_picker.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_desktop_shell.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_fab.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_items_body.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_tab_strip.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_settings_tab.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_vendor_picker.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_edit_field_decoration.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_tax_surcharge_section.dart';
import 'package:admin/ui/features/billing_shared/edit/e_invoice_tab_gate.dart';
import 'package:admin/ui/features/billing_shared/edit/save_default_helper.dart';
import 'package:admin/ui/features/billing_shared/items/billing_doc_items_tabs.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_editor.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';
import 'package:admin/ui/features/billing_shared/line_item_picker/line_item_picker_invoke.dart';
import 'package:admin/ui/features/billing_shared/markdown_notes_section.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_draft_preview.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/tasks/widgets/create_task_from_line_item_sheet.dart';

/// What one document adds to [BillingDocEditLayout] that the layout cannot
/// build itself. Every entry is a builder or a getter, called while the
/// layout builds, so it reads the view model's CURRENT draft — a value
/// captured when the document's wrapper was built would go stale on the
/// first keystroke (the wrapper is not rebuilt; only the layout listens).
class BillingDocEditSlots {
  const BillingDocEditSlots({
    required this.pdfFetcher,
    this.deliveryNoteAvailable,
    this.eInvoiceTab,
    this.autoBillEnabled,
    this.onAutoBillEnabledChanged,
    this.scheduleCard,
    this.scheduleTab,
    this.autoBillMode,
  });

  /// The draft's `live_preview` fetcher — the PDF tab, the desktop pane and
  /// the header's preview button share it, so the three cannot disagree
  /// about the design or the variant they render.
  final BillingDocPdfFetcher Function(BuildContext context) pdfFetcher;

  /// Whether the delivery-note variant can render yet (the invoice's needs a
  /// saved id). Null leaves `BillingDocPdfView`'s default.
  final bool Function()? deliveryNoteAvailable;

  /// The E-Invoice tab's body, for a document that files e-invoices. Shown —
  /// as a narrow tab and a desktop notes sub-tab — only once the company's
  /// settings say it files them (`resolveEInvoiceTabVisible`).
  final WidgetBuilder? eInvoiceTab;

  /// The Settings tab's auto-bill toggle (the invoice). Both or neither.
  final bool Function()? autoBillEnabled;
  final ValueChanged<bool>? onAutoBillEnabledChanged;

  /// The recurring invoice's schedule: a desktop card in the dates card's
  /// place, and a narrow tab after Details.
  final WidgetBuilder? scheduleCard;
  final WidgetBuilder? scheduleTab;

  /// The recurring invoice's auto-bill mode picker, after Discount on the
  /// desktop number card ([desktop] true) and the narrow Details tab.
  final Widget Function(BuildContext context, {required bool desktop})?
  autoBillMode;
}

/// The edit body of every billing document — invoice, quote, credit,
/// purchase order and recurring invoice.
///
/// These were five layouts of 1,200–1,450 lines each, 76–92% identical, and
/// fixes kept reaching four of the five: the credit rendered custom fields 1
/// and 3 twice, the recurring invoice lacked the notes focus guard, the
/// purchase order's narrow Items tab dropped an edit typed just before Save.
/// Now the differences are named once — on [BillingDocType] (the spec) and in
/// [BillingDocEditSlots] (what only the document can build) — and everything
/// else is written here once. `billing_doc_edit_layout_characterization_test`
/// pins what each document renders at phone, tablet and desktop widths.
///
/// Narrow (< 1024): the tab strip — Details, [Schedule], Contacts, Items,
/// Notes, Settings, then PDF while [showPdfTab] and E-Invoice while the
/// company files them — over sticky totals. Wide: the card shell. Both use
/// the one [widget.vm].
class BillingDocEditLayout<T extends BillingDocFields> extends StatefulWidget {
  const BillingDocEditLayout({
    super.key,
    required this.type,
    required this.vm,
    required this.slots,
    this.showPdfTab = true,
  });

  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final BillingDocEditSlots slots;

  /// Whether the narrow strip carries a `PDF` tab.
  ///
  /// False below `Breakpoints.wide`, where the strip is over its width budget
  /// and the PDF moves to the header's preview button
  /// (invoiceninja/flutter#140). The **screen** computes this once and threads
  /// it here: the AppBar is built outside the body, so no `LayoutBuilder` in
  /// this file could inform it, and reading the width in both places yields a
  /// band showing both chromes or neither. Ignored by the >= 1024 desktop
  /// layout, which has no tab strip at all.
  final bool showPdfTab;

  @override
  State<BillingDocEditLayout<T>> createState() =>
      _BillingDocEditLayoutState<T>();
}

/// The narrow strip's tabs, in order, so every arm of the `switch` in
/// [_BillingDocEditLayoutState._tabFor] is reachable and the compiler checks
/// the map is total.
enum _Tab { details, schedule, contacts, items, notes, settings, pdf, eInvoice }

class _BillingDocEditLayoutState<T extends BillingDocFields>
    extends State<BillingDocEditLayout<T>> {
  /// Hidden until the settings cascade answers — see
  /// [resolveEInvoiceTabVisible].
  bool _showEInvoice = false;

  BillingDocType get _type => widget.type;
  BillingDocEditViewModel<T> get _vm => widget.vm;

  /// The narrow strip's tabs, in order — the only place a tab's presence is
  /// decided. [BillingDocEditTabStrip] sizes its own controller from the
  /// list [_buildMobile] hands it, and [_tabFor] maps each key to its label
  /// AND its body in one `switch`, so no second count and no parallel
  /// `tabs:` / `children:` list can fall out of step.
  List<_Tab> get _tabKeys => [
    _Tab.details,
    if (widget.slots.scheduleTab != null) _Tab.schedule,
    _Tab.contacts,
    _Tab.items,
    _Tab.notes,
    // Settings (project / vendor / user / exchange-rate / auto-bill) was
    // desktop-only; mobile gets it as its own tab so those fields are
    // reachable on a phone.
    _Tab.settings,
    if (widget.showPdfTab) _Tab.pdf,
    if (_showEInvoice) _Tab.eInvoice,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.slots.eInvoiceTab != null) unawaited(_resolveEInvoiceGate());
    if (_type.party == BillingDocParty.client) {
      // Best-effort async fetch of any existing task/expense line items'
      // source clientIds so the cross-client save validator catches drift
      // on legacy / API-imported documents. No-op when the draft has no
      // task/expense lines yet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final services = context.read<Services>();
        _vm.hydrateSourceClientIds(
          services: services,
          companyId: _vm.companyId,
        );
      });
    }
  }

  /// Reveal the E-Invoice tab if this company files them. The strip resizes
  /// its own controller when the list grows.
  Future<void> _resolveEInvoiceGate() async {
    final visible = await resolveEInvoiceTabVisible(context, _vm.companyId);
    if (!mounted || visible == _showEInvoice) return;
    setState(() => _showEInvoice = visible);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
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

  /// invoiceninja/flutter#88 — schedule the work a line item describes as a
  /// dated task, without leaving this (possibly dirty) document. Null when the
  /// document doesn't offer it, the company has Tasks off or the user can't
  /// create one, which hides the affordance in every row menu.
  ValueChanged<LineItem>? _createTaskHandler(BuildContext context) {
    if (!_type.supportsCreateTaskFromLineItem) return null;
    final vm = _vm;
    return createTaskFromLineItemHandler(
      context,
      companyId: vm.companyId,
      clientId: vm.draft.clientId,
      projectId: vm.draft.projectId,
      documentDate: vm.draft.date,
    );
  }

  void _openPicker(BuildContext context) {
    final vm = _vm;
    // A vendor-side document has no client, so the picker collapses to the
    // Products tab (no Tasks / Expenses sourcing), and the client-cascade /
    // register-source callbacks are no-ops.
    final client = _type.party == BillingDocParty.client;
    openLineItemPicker(
      context,
      companyId: vm.companyId,
      clientId: client ? vm.draft.clientId : '',
      showTasksAndExpenses: client,
      invoiceInclusive: vm.draft.usesInclusiveTaxes,
      currentLineItems: vm.draft.lineItems,
      currentProjectId: vm.draft.projectId,
      currentClientId: client ? vm.draft.clientId : '',
      isCreate: vm.isCreate,
      replaceLineItems: vm.replaceLineItems,
      setProjectId: vm.setProjectId,
      setClientId: client ? vm.setClientId : (_) {},
      registerSourceClientIds: client
          ? (tasks, expenses) =>
                vm.registerSourceClientIds(tasks: tasks, expenses: expenses)
          : (_, _) {},
      showStockQuantity: _type.showsProductStock,
    );
  }

  /// Label + body for one tab, in a single `switch` so a key can never carry
  /// one and not the other.
  ({String label, Widget body}) _tabFor(BuildContext context, _Tab key) =>
      switch (key) {
        _Tab.details => (
          label: context.tr('details'),
          body: _DetailsTab<T>(type: _type, vm: _vm, slots: widget.slots),
        ),
        _Tab.schedule => (
          label: context.tr('schedule'),
          body: widget.slots.scheduleTab!(context),
        ),
        _Tab.contacts => (
          label: context.tr('contacts'),
          body: _ContactsTab<T>(type: _type, vm: _vm),
        ),
        _Tab.items => (
          label: context.tr('items'),
          body: _ItemsTab<T>(
            type: _type,
            vm: _vm,
            onPickItems: () => _openPicker(context),
            onCreateTask: _createTaskHandler(context),
          ),
        ),
        _Tab.notes => (
          label: context.tr('notes'),
          body: _NotesTab<T>(type: _type, vm: _vm),
        ),
        _Tab.settings => (
          label: context.tr('settings'),
          body: _SettingsTab<T>(type: _type, vm: _vm, slots: widget.slots),
        ),
        _Tab.pdf => (
          label: context.tr('pdf'),
          body: _PdfTab<T>(type: _type, vm: _vm, slots: widget.slots),
        ),
        _Tab.eInvoice => (
          label: context.tr('e_invoice'),
          body: widget.slots.eInvoiceTab!(context),
        ),
      };

  Widget _buildMobile(BuildContext context) {
    final tokens = context.inTheme;
    // The transparency Material here covers the sticky totals; the strip
    // brings its own for the tab bodies.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: BillingDocEditTabStrip(
              excludeInactiveFocus: _type.excludesInactiveTabFocus,
              tabs: [for (final key in _tabKeys) _tabFor(context, key)],
            ),
          ),
          Divider(height: 1, color: tokens.border),
          Padding(
            padding: EdgeInsets.all(InSpacing.md(context)),
            child: _Totals<T>(type: _type, vm: _vm, dense: true),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final shell = BillingDocEditDesktopShell(
      topRow: (ctx, slot) => switch (slot) {
        0 => _PartyCardDesktop<T>(type: _type, vm: _vm),
        1 =>
          widget.slots.scheduleCard?.call(ctx) ??
              _DatesCardDesktop<T>(type: _type, vm: _vm),
        2 => _NumberCardDesktop<T>(type: _type, vm: _vm, slots: widget.slots),
        _ => const SizedBox.shrink(),
      },
      itemsSection: _ItemsEditor<T>(
        type: _type,
        vm: _vm,
        onPickItems: () => _openPicker(context),
        onCreateTask: _createTaskHandler(context),
      ),
      notesTabsCard: _NotesTabsCardDesktop<T>(
        type: _type,
        vm: _vm,
        slots: widget.slots,
        showEInvoice: _showEInvoice,
      ),
      totalsCard: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TaxSurchargeSection<T>(vm: _vm),
          _Totals<T>(type: _type, vm: _vm, bordered: false),
        ],
      ),
      pdfPane: _PdfPaneDesktop<T>(type: _type, vm: _vm, slots: widget.slots),
      stickyTotals: _Totals<T>(type: _type, vm: _vm, dense: true, slim: true),
    );
    // FAB anchored above the sticky totals bar so it stays in view as the
    // user scrolls the page. Shortcut wrapping covers the whole shell so
    // Cmd/Ctrl-N fires no matter which section is focused on desktop.
    return BillingDocEditPickerShortcuts(
      onPickItems: () => _openPicker(context),
      child: Stack(
        children: [
          shell,
          Positioned(
            bottom: 72,
            right: 24,
            child: BillingDocEditFab(
              heroTag: _type.pickerFabHeroTag,
              onPressed: () => _openPicker(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared pieces ────────────────────────────────────────────────────

/// The partial-payment (deposit) field's setters, when the document has one
/// — `BillingDocPartialSetters` is mixed into the invoice, quote and credit
/// view models only.
BillingDocPartialSetters<BillingDocPartialFields>? _partialSetters(
  BillingDocEditViewModel<BillingDocFields> vm,
) => vm is BillingDocPartialSetters<BillingDocPartialFields> ? vm : null;

/// The draft's partial amount / due date — zero / null where there is none.
Decimal _partialOf(BillingDocType type, BillingDocFields draft) =>
    type.hasPartial && draft is BillingDocPartialFields
    ? draft.partial
    : Decimal.zero;

Date? _partialDueDateOf(BillingDocFields draft) =>
    draft is BillingDocPartialFields ? draft.partialDueDate : null;

/// The draft's party id — the client, or a purchase order's vendor.
String _partyIdOf(BillingDocType type, BillingDocFields draft) =>
    type.party == BillingDocParty.client ? draft.clientId : draft.vendorId;

/// A date field's `onChanged`, as a `Date` (date-only) rather than a
/// `DateTime`.
ValueChanged<DateTime?> _onDate(ValueChanged<Date?> set) =>
    (d) => set(d == null ? null : Date(d.year, d.month, d.day));

String _decimalText(Decimal value) =>
    value == Decimal.zero ? '' : value.toString();

/// The totals in one of their three dresses: the narrow sticky bar
/// ([dense]), the desktop breakdown card ([bordered] false) and the desktop
/// slim bar ([dense] + [slim]).
class _Totals<T extends BillingDocFields> extends StatelessWidget {
  const _Totals({
    required this.type,
    required this.vm,
    this.dense = false,
    this.slim = false,
    this.bordered = true,
  });

  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final bool dense;
  final bool slim;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final d = vm.draft;
    final client = type.party == BillingDocParty.client;
    return BillingEditTotals(
      totalsAt: vm.totalsAt,
      clientId: client ? d.clientId : null,
      vendorId: client ? null : d.vendorId,
      discount: d.discount,
      discountIsAmount: d.isAmountDiscount,
      surchargeAmounts: [
        d.customSurcharge1,
        d.customSurcharge2,
        d.customSurcharge3,
        d.customSurcharge4,
      ],
      partial: type.hasPartial ? _partialOf(type, d) : null,
      dense: dense,
      slim: slim,
      bordered: bordered,
    );
  }
}

/// The custom-field inputs. The desktop splits the four slots over the dates
/// card (1, 3) and the number card (2, 4); the narrow Details tab renders all
/// four in one titled card.
Widget _customFields(
  BuildContext context,
  BillingDocEditViewModel<BillingDocFields> vm, {
  List<int>? slots,
}) {
  final services = context.read<Services>();
  final d = vm.draft;
  return EntityCustomFieldsSection(
    keyPrefix: 'invoice',
    companyStream: services.company.watchCompany(vm.companyId),
    formatter: services.formatterIfReady(vm.companyId),
    values: [d.customValue1, d.customValue2, d.customValue3, d.customValue4],
    onChanged: [
      vm.setCustomValue1,
      vm.setCustomValue2,
      vm.setCustomValue3,
      vm.setCustomValue4,
    ],
    wrapInCard: slots == null,
    slots: slots ?? const [1, 2, 3, 4],
    cardTitle: slots == null ? context.tr('custom_fields') : null,
  );
}

// ── Desktop multi-column cards ───────────────────────────────────────

class _PartyCardDesktop<T extends BillingDocFields> extends StatelessWidget {
  const _PartyCardDesktop({required this.type, required this.vm});
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;

  @override
  Widget build(BuildContext context) {
    final client = type.party == BillingDocParty.client;
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        if (client)
          BillingDocClientPicker(vm: vm, companyId: vm.companyId)
        else
          BillingDocVendorPicker(vm: vm, companyId: vm.companyId),
        SizedBox(height: InSpacing.md(context)),
        _PartyContacts<T>(type: type, vm: vm, dense: true),
      ],
    );
  }
}

/// The contacts of the document's party, each with the checkbox that puts an
/// invitation on the document. [dense] is the desktop card's capped list;
/// otherwise the narrow Contacts tab's full page.
class _PartyContacts<T extends BillingDocFields> extends StatelessWidget {
  const _PartyContacts({
    required this.type,
    required this.vm,
    required this.dense,
  });
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final client = type.party == BillingDocParty.client;
    final partyId = _partyIdOf(type, vm.draft);
    if (partyId.isEmpty) {
      if (dense) return const SizedBox.shrink();
      return Center(
        child: Padding(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Text(
            context.tr(
              client ? 'select_a_client_first' : 'select_a_vendor_first',
            ),
            style: TextStyle(color: context.inTheme.ink3),
          ),
        ),
      );
    }
    Widget section(List<BillingContact> contacts) {
      final selected = vm.draft.invitations
          .map((i) => client ? i.clientContactId : i.vendorContactId)
          .where((id) => id.isNotEmpty)
          .toSet();
      final list = BillingDocContactsSection(
        contacts: contacts,
        selectedContactIds: selected,
        onChanged: (next) {
          final added = next.difference(selected);
          final removed = selected.difference(next);
          for (final id in added) {
            client
                ? vm.setContactInvitation(id, true)
                : vm.setVendorContactInvitation(id, true);
          }
          for (final id in removed) {
            client
                ? vm.setContactInvitation(id, false)
                : vm.setVendorContactInvitation(id, false);
          }
        },
      );
      if (dense) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(child: list),
        );
      }
      return ListView(
        padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
        children: [list],
      );
    }

    Widget loading() => dense
        ? const LinearProgressIndicator(minHeight: 2)
        : const Center(child: CircularProgressIndicator());
    if (client) {
      return StreamBuilder<Client?>(
        stream: services.clients.watch(companyId: vm.companyId, id: partyId),
        builder: (context, snapshot) {
          final party = snapshot.data;
          if (party == null) return loading();
          return section(party.contacts.map((c) => c.toBilling()).toList());
        },
      );
    }
    return StreamBuilder<Vendor?>(
      stream: services.vendors.watch(companyId: vm.companyId, id: partyId),
      builder: (context, snapshot) {
        final party = snapshot.data;
        if (party == null) return loading();
        return section(party.contacts.map((c) => c.toBilling()).toList());
      },
    );
  }
}

class _DatesCardDesktop<T extends BillingDocFields> extends StatefulWidget {
  const _DatesCardDesktop({required this.type, required this.vm});
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;

  @override
  State<_DatesCardDesktop<T>> createState() => _DatesCardDesktopState<T>();
}

class _DatesCardDesktopState<T extends BillingDocFields>
    extends State<_DatesCardDesktop<T>> {
  late final TextEditingController _partial = TextEditingController(
    text: _decimalText(_partialOf(widget.type, widget.vm.draft)),
  );

  @override
  void dispose() {
    _partial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final type = widget.type;
    final fmt = context.read<Services>().formatterIfReady(vm.companyId);
    final partialVm = type.hasPartial ? _partialSetters(vm) : null;
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        InDateField(
          value: vm.draft.date?.toDateTime(),
          formatter: fmt,
          onChanged: _onDate(vm.setDate),
          labelText: context.tr(type.dateLabelKey ?? 'date'),
        ),
        SizedBox(height: InSpacing.md(context)),
        InDateField(
          value: vm.draft.dueDate?.toDateTime(),
          formatter: fmt,
          onChanged: _onDate(vm.setDueDate),
          labelText: context.tr(type.dueDateLabelKey ?? 'due_date'),
          clearable: true,
        ),
        SizedBox(height: InSpacing.md(context)),
        if (partialVm != null) ...[
          TextField(
            controller: _partial,
            decoration: billingFieldDecoration(
              context,
              label: context.tr('partial'),
              errorText: vm.fieldErrorFor('partial'),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: partialVm.setPartial,
          ),
          if (_partialOf(type, vm.draft) > Decimal.zero) ...[
            SizedBox(height: InSpacing.md(context)),
            InDateField(
              value: _partialDueDateOf(vm.draft)?.toDateTime(),
              formatter: fmt,
              onChanged: _onDate(partialVm.setPartialDueDate),
              labelText: context.tr('partial_due_date'),
              clearable: true,
            ),
          ],
          SizedBox(height: InSpacing.md(context)),
        ],
        _customFields(context, vm, slots: const [1, 3]),
      ],
    );
  }
}

class _NumberCardDesktop<T extends BillingDocFields> extends StatefulWidget {
  const _NumberCardDesktop({
    required this.type,
    required this.vm,
    required this.slots,
  });
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final BillingDocEditSlots slots;

  @override
  State<_NumberCardDesktop<T>> createState() => _NumberCardDesktopState<T>();
}

class _NumberCardDesktopState<T extends BillingDocFields>
    extends State<_NumberCardDesktop<T>> {
  late final TextEditingController _number = TextEditingController(
    text: widget.vm.draft.number,
  );
  late final TextEditingController _poNumber = TextEditingController(
    text: widget.vm.draft.poNumber,
  );
  late final TextEditingController _discount = TextEditingController(
    text: _decimalText(widget.vm.draft.discount),
  );

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
    final type = widget.type;
    final autoBillMode = widget.slots.autoBillMode;
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        TextField(
          controller: _number,
          decoration: billingFieldDecoration(
            context,
            label: context.tr(type.desktopNumberLabelKey),
            hint: vm.isCreate ? context.tr('auto_generated') : null,
            errorText: vm.fieldErrorFor('number'),
          ),
          onChanged: vm.setNumber,
          autocorrect: false,
        ),
        SizedBox(height: InSpacing.md(context)),
        if (type.hasPoNumberField) ...[
          TextField(
            controller: _poNumber,
            decoration: billingFieldDecoration(
              context,
              label: context.tr('po_number'),
              errorText: vm.fieldErrorFor('po_number'),
            ),
            onChanged: vm.setPoNumber,
            autocorrect: false,
          ),
          SizedBox(height: InSpacing.md(context)),
        ],
        _DiscountRow<T>(vm: vm, controller: _discount, desktop: true),
        SizedBox(height: InSpacing.md(context)),
        if (autoBillMode != null) ...[
          autoBillMode(context, desktop: true),
          SizedBox(height: InSpacing.md(context)),
        ],
        // The dates card renders slots 1 and 3; without this the number card
        // rendered all four and 1 / 3 appeared twice (the credit did, once).
        _customFields(context, vm, slots: const [2, 4]),
      ],
    );
  }
}

/// The discount amount and its percent / amount switch.
class _DiscountRow<T extends BillingDocFields> extends StatelessWidget {
  const _DiscountRow({
    required this.vm,
    required this.controller,
    required this.desktop,
  });
  final BillingDocEditViewModel<T> vm;
  final TextEditingController controller;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: desktop
                ? billingFieldDecoration(context, label: context.tr('discount'))
                : InputDecoration(labelText: context.tr('discount')),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              vm.setDiscount(controller.text, isAmount: s.first),
        ),
      ],
    );
  }
}

/// The line-item editor, for BOTH layouts.
///
/// A client document gets it from `BillingDocItemsTabs`, which owns the
/// per-tab table controllers and registers the before-save hooks that commit
/// a debounced cell edit and strip empty rows. A vendor document (the
/// purchase order) cannot — that widget is client-only — so it hosts a
/// `LineItemEditor` with the same two hooks. Its narrow Items tab used to
/// host a bare editor instead, and on a tablet, where the wide table renders
/// inside the tabbed layout, typing into a cell and saving within the
/// debounce dropped the edit.
class _ItemsEditor<T extends BillingDocFields> extends StatelessWidget {
  const _ItemsEditor({
    required this.type,
    required this.vm,
    required this.onPickItems,
    required this.onCreateTask,
  });
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final VoidCallback onPickItems;
  final ValueChanged<LineItem>? onCreateTask;

  @override
  Widget build(BuildContext context) {
    if (type.party == BillingDocParty.vendor) {
      return _VendorItemsEditor<T>(vm: vm, onPickItems: onPickItems);
    }
    return BillingDocItemsTabs(
      vm: vm,
      companyId: vm.companyId,
      lineItems: vm.draft.lineItems,
      onChanged: vm.replaceLineItems,
      newItemFactory: emptyLineItem,
      rowErrors: vm.lineItemRowErrors,
      onPickItems: onPickItems,
      showStockQuantity: type.showsProductStock,
      onCreateTaskFromLineItem: onCreateTask,
    );
  }
}

class _VendorItemsEditor<T extends BillingDocFields> extends StatefulWidget {
  const _VendorItemsEditor({required this.vm, required this.onPickItems});
  final BillingDocEditViewModel<T> vm;
  final VoidCallback onPickItems;

  @override
  State<_VendorItemsEditor<T>> createState() => _VendorItemsEditorState<T>();
}

class _VendorItemsEditorState<T extends BillingDocFields>
    extends State<_VendorItemsEditor<T>> {
  final _tableController = LineItemTableDesktopController();
  VoidCallback? _unregisterFlush;
  VoidCallback? _unregisterStrip;

  @override
  void initState() {
    super.initState();
    _unregisterFlush = widget.vm.addBeforeSaveHook(
      _tableController.flushPending,
    );
    _unregisterStrip = widget.vm.addBeforeSaveHook(
      widget.vm.stripEmptyLineItems,
    );
  }

  @override
  void dispose() {
    _unregisterFlush?.call();
    _unregisterStrip?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return LineItemEditor(
      companyId: vm.companyId,
      vendorId: vm.draft.vendorId,
      items: vm.draft.lineItems,
      onChanged: vm.replaceLineItems,
      newItemFactory: emptyLineItem,
      controller: _tableController,
      rowErrors: vm.lineItemRowErrors,
      onPickItems: widget.onPickItems,
    );
  }
}

/// A "Save as default" for the terms / footer, where the document has a
/// company default of its own — the recurring invoice inherits the
/// invoice's, so it offers none.
ValueChanged<String>? _saveAsDefault(
  BuildContext context,
  BillingDocType type,
  BillingDocEditViewModel<BillingDocFields> vm, {
  required bool terms,
}) {
  final key = terms ? type.termsDefaultKey : type.footerDefaultKey;
  if (key == null) return null;
  return (v) => saveBillingDocDefault(
    context,
    companyId: vm.companyId,
    value: v,
    fieldKey: key,
    successKey: terms ? 'updated_default_terms' : 'updated_default_footer',
    apply: (s, val) =>
        terms ? type.withDefaultTerms(s, val) : type.withDefaultFooter(s, val),
  );
}

/// The document settings — project, vendor, user, exchange rate, design,
/// tags (and the invoice's auto-bill toggle): a desktop notes sub-tab and the
/// narrow Settings tab.
Widget _settings(
  BillingDocType type,
  BillingDocEditViewModel<BillingDocFields> vm,
  BillingDocEditSlots slots,
) {
  final d = vm.draft;
  return BillingDocSettingsTab(
    companyId: vm.companyId,
    entityType: type.wireName,
    tagIds: d.tagIds,
    onTagIdsChanged: vm.setTagIds,
    designId: d.designId,
    onDesignChanged: vm.setDesignId,
    userId: d.assignedUserId,
    onUserChanged: vm.setAssignedUserId,
    projectId: d.projectId,
    onProjectChanged: vm.setProjectId,
    vendorId: d.vendorId,
    onVendorChanged: vm.setVendorId,
    exchangeRate: d.exchangeRate.toString(),
    onExchangeRateChanged: vm.setExchangeRate,
    autoBillEnabled: slots.autoBillEnabled?.call(),
    onAutoBillEnabledChanged: slots.onAutoBillEnabledChanged,
    // The vendor is a vendor document's own party, picked on its Details.
    showVendor: type.party == BillingDocParty.client,
  );
}

class _NotesTabsCardDesktop<T extends BillingDocFields> extends StatefulWidget {
  const _NotesTabsCardDesktop({
    required this.type,
    required this.vm,
    required this.slots,
    required this.showEInvoice,
  });
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final BillingDocEditSlots slots;

  /// Threaded down from the layout's own gate rather than resolved again
  /// here: the narrow strip and this card must agree, and one cascade read
  /// per screen is enough.
  final bool showEInvoice;

  @override
  State<_NotesTabsCardDesktop<T>> createState() =>
      _NotesTabsCardDesktopState<T>();
}

class _NotesTabsCardDesktopState<T extends BillingDocFields>
    extends State<_NotesTabsCardDesktop<T>>
        // PLURAL `TickerProviderStateMixin` — the sub-tab count changes when the
        // parent's E-Invoice gate resolves, and the single-ticker mixin asserts on
        // the second controller.
        with
        TickerProviderStateMixin {
  late TabController _ctl = TabController(length: _length, vsync: this);

  int get _length => widget.showEInvoice ? 6 : 5;

  @override
  void didUpdateWidget(_NotesTabsCardDesktop<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showEInvoice == widget.showEInvoice) return;
    final previousIndex = _ctl.index;
    _ctl.dispose();
    _ctl = TabController(
      length: _length,
      vsync: this,
      initialIndex: previousIndex.clamp(0, _length - 1),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final type = widget.type;
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
            if (widget.showEInvoice) Tab(text: context.tr('e_invoice')),
          ],
        ),
        Divider(height: 1, color: tokens.border),
        SizedBox(
          height: BillingDocEditDesktopShell.notesPaneHeight(context),
          // Widget-order (not geometry) Tab traversal across the notes
          // sub-tabs: TabBarView leaves non-current pages built-but-unlaid,
          // and reading-order traversal would call `FocusNode.rect` on the
          // unlaid markdown-field host nodes → `hasSize` assertion. Notes
          // fields are in source order so the Tab sequence is unchanged.
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: TabBarView(
              controller: _ctl,
              children: [
                MarkdownNotesField(
                  registerBeforeSaveHook: vm.addBeforeSaveHook,
                  label: context.tr('terms'),
                  showLabel: false,
                  expand: true,
                  value: vm.draft.terms,
                  onChanged: vm.setTerms,
                  onSaveAsDefault: _saveAsDefault(
                    context,
                    type,
                    vm,
                    terms: true,
                  ),
                ),
                MarkdownNotesField(
                  registerBeforeSaveHook: vm.addBeforeSaveHook,
                  label: context.tr('footer'),
                  showLabel: false,
                  expand: true,
                  value: vm.draft.footer,
                  onChanged: vm.setFooter,
                  onSaveAsDefault: _saveAsDefault(
                    context,
                    type,
                    vm,
                    terms: false,
                  ),
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
                SingleChildScrollView(child: _settings(type, vm, widget.slots)),
                if (widget.showEInvoice) widget.slots.eInvoiceTab!(context),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PdfPaneDesktop<T extends BillingDocFields> extends StatelessWidget {
  const _PdfPaneDesktop({
    required this.type,
    required this.vm,
    required this.slots,
  });
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final BillingDocEditSlots slots;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        SizedBox(
          height: BillingDocEditDesktopShell.fullWidthPdfHeight(context),
          child: _PdfTab<T>(type: type, vm: vm, slots: slots),
        ),
      ],
    );
  }
}

/// Document-level tax tiers + custom surcharges + inclusive-tax toggle.
/// Self-collapses when the company has no enabled tax rates and no surcharge
/// labels configured (so it adds no chrome when unused).
class _TaxSurchargeSection<T extends BillingDocFields> extends StatelessWidget {
  const _TaxSurchargeSection({required this.vm});
  final BillingDocEditViewModel<T> vm;

  @override
  Widget build(BuildContext context) {
    final d = vm.draft;
    return BillingTaxSurchargeSection(
      companyId: vm.companyId,
      useCommaAsDecimalPlace: vm.useCommaAsDecimalPlace,
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

// ── Narrow tabs ──────────────────────────────────────────────────────

/// Mobile "Settings" tab. Desktop renders these in a sub-tab of the notes
/// card; mobile previously had no tab for them, so those fields were
/// uneditable on a phone.
class _SettingsTab<T extends BillingDocFields> extends StatelessWidget {
  const _SettingsTab({
    required this.type,
    required this.vm,
    required this.slots,
  });
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final BillingDocEditSlots slots;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: _settings(type, vm, slots),
    );
  }
}

class _DetailsTab<T extends BillingDocFields> extends StatefulWidget {
  const _DetailsTab({
    required this.type,
    required this.vm,
    required this.slots,
  });
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final BillingDocEditSlots slots;

  @override
  State<_DetailsTab<T>> createState() => _DetailsTabState<T>();
}

class _DetailsTabState<T extends BillingDocFields>
    extends State<_DetailsTab<T>> {
  late final TextEditingController _number = TextEditingController(
    text: widget.vm.draft.number,
  );
  late final TextEditingController _poNumber = TextEditingController(
    text: widget.vm.draft.poNumber,
  );
  late final TextEditingController _partial = TextEditingController(
    text: _decimalText(_partialOf(widget.type, widget.vm.draft)),
  );
  late final TextEditingController _discount = TextEditingController(
    text: _decimalText(widget.vm.draft.discount),
  );

  @override
  void dispose() {
    _number.dispose();
    _poNumber.dispose();
    _partial.dispose();
    _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final type = widget.type;
    final fmt = context.read<Services>().formatterIfReady(vm.companyId);
    final placement = type.mobilePartialPlacement;
    final partialVm = type.hasPartial ? _partialSetters(vm) : null;
    final autoBillMode = widget.slots.autoBillMode;

    final numberField = TextField(
      controller: _number,
      decoration: InputDecoration(
        labelText: context.tr(type.numberLabelKey),
        hintText: vm.isCreate ? context.tr('auto_generated') : null,
        errorText: vm.fieldErrorFor('number'),
      ),
      onChanged: vm.setNumber,
      autocorrect: false,
    );
    Widget partialField() => TextField(
      controller: _partial,
      decoration: InputDecoration(
        labelText: context.tr('partial'),
        errorText: vm.fieldErrorFor('partial'),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: partialVm!.setPartial,
    );
    Widget partialDueDate() => InDateField(
      value: _partialDueDateOf(vm.draft)?.toDateTime(),
      formatter: fmt,
      onChanged: _onDate(partialVm!.setPartialDueDate),
      labelText: context.tr('partial_due_date'),
      clearable: true,
    );
    // The partial field and — once a partial is set — its due date, stacked.
    List<Widget> stackedPartial() => [
      partialField(),
      if (_partialOf(type, vm.draft) > Decimal.zero) ...[
        SizedBox(height: InSpacing.md(context)),
        partialDueDate(),
      ],
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (type.party == BillingDocParty.client)
            BillingDocClientPicker(vm: vm, companyId: vm.companyId)
          else
            BillingDocVendorPicker(vm: vm, companyId: vm.companyId),
          SizedBox(height: InSpacing.lg(context)),
          // One number field on a purchase order, labelled "PO Number" — the
          // order's own number, exactly as the desktop card, React and v1
          // present it. That layout used to add a second field writing the
          // separate `po_number` column under the same label, so "PO Number"
          // meant different data on a phone and on a desktop.
          if (type.hasPoNumberField)
            Row(
              children: [
                Expanded(child: numberField),
                SizedBox(width: InSpacing.md(context)),
                Expanded(
                  child: TextField(
                    controller: _poNumber,
                    decoration: InputDecoration(
                      labelText: context.tr('po_number'),
                      errorText: vm.fieldErrorFor('po_number'),
                    ),
                    onChanged: vm.setPoNumber,
                    autocorrect: false,
                  ),
                ),
              ],
            )
          else
            numberField,
          SizedBox(height: InSpacing.md(context)),
          if (type.dateLabelKey != null) ...[
            Row(
              children: [
                Expanded(
                  child: InDateField(
                    value: vm.draft.date?.toDateTime(),
                    formatter: fmt,
                    onChanged: _onDate(vm.setDate),
                    labelText: context.tr(type.dateLabelKey!),
                  ),
                ),
                SizedBox(width: InSpacing.md(context)),
                Expanded(
                  child: InDateField(
                    value: vm.draft.dueDate?.toDateTime(),
                    formatter: fmt,
                    onChanged: _onDate(vm.setDueDate),
                    labelText: context.tr(type.dueDateLabelKey!),
                    clearable: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: InSpacing.md(context)),
          ],
          if (partialVm != null &&
              placement == BillingDocPartialPlacement.afterDates) ...[
            ...stackedPartial(),
            SizedBox(height: InSpacing.md(context)),
          ],
          if (partialVm != null &&
              placement == BillingDocPartialPlacement.afterDatesRow) ...[
            Row(
              children: [
                Expanded(child: partialField()),
                SizedBox(width: InSpacing.md(context)),
                Expanded(child: partialDueDate()),
              ],
            ),
            SizedBox(height: InSpacing.md(context)),
          ],
          _DiscountRow<T>(vm: vm, controller: _discount, desktop: false),
          if (partialVm != null &&
              placement == BillingDocPartialPlacement.afterDiscount) ...[
            SizedBox(height: InSpacing.md(context)),
            ...stackedPartial(),
          ],
          if (autoBillMode != null) ...[
            SizedBox(height: InSpacing.md(context)),
            autoBillMode(context, desktop: false),
          ],
          _TaxSurchargeSection<T>(vm: vm),
          SizedBox(height: InSpacing.lg(context)),
          // No Design picker here: it is the Settings tab's first field, and
          // a second copy on this tab showed it twice on phones and tablets.
          _customFields(context, vm),
        ],
      ),
    );
  }
}

class _ContactsTab<T extends BillingDocFields> extends StatelessWidget {
  const _ContactsTab({required this.type, required this.vm});
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;

  @override
  Widget build(BuildContext context) =>
      _PartyContacts<T>(type: type, vm: vm, dense: false);
}

class _ItemsTab<T extends BillingDocFields> extends StatelessWidget {
  const _ItemsTab({
    required this.type,
    required this.vm,
    required this.onPickItems,
    required this.onCreateTask,
  });
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final VoidCallback onPickItems;
  final ValueChanged<LineItem>? onCreateTask;

  @override
  Widget build(BuildContext context) {
    return BillingDocEditItemsBody(
      heroTag: type.mobilePickerFabHeroTag,
      onPickItems: onPickItems,
      child: _ItemsEditor<T>(
        type: type,
        vm: vm,
        onPickItems: onPickItems,
        onCreateTask: onCreateTask,
      ),
    );
  }
}

class _NotesTab<T extends BillingDocFields> extends StatelessWidget {
  const _NotesTab({required this.type, required this.vm});
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;

  @override
  Widget build(BuildContext context) {
    // Widget-order Tab traversal: this ListView leaves off-screen markdown
    // fields built-but-unlaid, and reading-order traversal would call
    // `FocusNode.rect` on their host nodes → `hasSize` assertion. Source
    // order == visual order here, so the Tab sequence is unchanged.
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: ListView(
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
            onSaveAsDefault: _saveAsDefault(context, type, vm, terms: true),
          ),
          SizedBox(height: InSpacing.lg(context)),
          MarkdownNotesField(
            registerBeforeSaveHook: vm.addBeforeSaveHook,
            label: context.tr('footer'),
            value: vm.draft.footer,
            onChanged: vm.setFooter,
            onSaveAsDefault: _saveAsDefault(context, type, vm, terms: false),
          ),
        ],
      ),
    );
  }
}

class _PdfTab<T extends BillingDocFields> extends StatelessWidget {
  const _PdfTab({required this.type, required this.vm, required this.slots});
  final BillingDocType type;
  final BillingDocEditViewModel<T> vm;
  final BillingDocEditSlots slots;

  @override
  Widget build(BuildContext context) {
    // The server cannot render a document without its party.
    if (_partyIdOf(type, vm.draft).isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Text(
            context.tr(
              type.party == BillingDocParty.client
                  ? 'please_select_a_client'
                  : 'select_a_vendor_first',
            ),
            style: TextStyle(color: context.inTheme.ink3),
          ),
        ),
      );
    }
    final deliveryNoteAvailable = slots.deliveryNoteAvailable;
    return deliveryNoteAvailable == null
        ? BillingDocPdfView(
            entity: type,
            entityNumber: vm.draft.number,
            revision: vm.draft,
            fetcher: slots.pdfFetcher(context),
          )
        : BillingDocPdfView(
            entity: type,
            entityNumber: vm.draft.number,
            revision: vm.draft,
            deliveryNoteAvailable: deliveryNoteAvailable(),
            fetcher: slots.pdfFetcher(context),
          );
  }
}

/// The narrow edit header's draft-PDF button, sitting between `Save` and the
/// `⋮` (invoiceninja/flutter#140). Built by each edit screen's
/// `actionsBuilder` under the same `narrow` bool that drops
/// [BillingDocEditLayout.showPdfTab], so exactly one of the two surfaces
/// exists at any width. Gated on the document's party: the server cannot
/// render a document without it.
Widget billingDocDraftPreviewButton(
  BillingDocType type,
  BillingDocEditViewModel<BillingDocFields> vm,
  BillingDocPdfFetcher fetcher, {
  bool deliveryNoteAvailable = false,
}) => BillingDocPreviewButton(
  entity: type,
  entityNumber: vm.draft.number,
  enabled: _partyIdOf(type, vm.draft).isNotEmpty,
  deliveryNoteAvailable: deliveryNoteAvailable,
  fetcher: fetcher,
);

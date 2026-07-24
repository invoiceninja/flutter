import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_contact.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/contacts/billing_doc_contacts_section.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_desktop_shell.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_fab.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_edit_field_decoration.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_settings_tab.dart';
import 'package:admin/ui/features/billing_shared/edit/save_default_helper.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/items/billing_doc_items_tabs.dart';
import 'package:admin/ui/features/billing_shared/line_item_picker/line_item_picker_invoke.dart';
import 'package:admin/ui/features/billing_shared/markdown_notes_section.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/ui/features/billing_shared/billing_edit_totals.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_tax_surcharge_section.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Tabbed body for the quote edit screen. Same shape as the invoice edit
/// layout — Details / Contacts / Items / Notes / PDF. No E-Invoice tab
/// for quotes today (PEPPOL submission applies to invoices only).
class QuoteEditLayout extends StatefulWidget {
  const QuoteEditLayout({super.key, required this.vm});

  final QuoteEditViewModel vm;

  @override
  State<QuoteEditLayout> createState() => _QuoteEditLayoutState();
}

class _QuoteEditLayoutState extends State<QuoteEditLayout>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    // 6 tabs: Details / Contacts / Items / Notes / Settings / PDF.
    // Settings (project / vendor / user / exchange-rate) was desktop-only;
    // mobile now gets it as its own tab so those fields are reachable on a
    // phone.
    _tab = TabController(length: 6, vsync: this);
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
      partial: widget.vm.draft.partial,
      dense: true,
    ),
  );

  Widget _totalsCard(BuildContext context) => BillingEditTotals(
    totalsAt: widget.vm.totalsAt,
    clientId: widget.vm.draft.clientId,
    discount: widget.vm.draft.discount,
    discountIsAmount: widget.vm.draft.isAmountDiscount,
    partial: widget.vm.draft.partial,
    bordered: false,
  );

  Widget _slimTotals(BuildContext context) => BillingEditTotals(
    totalsAt: widget.vm.totalsAt,
    clientId: widget.vm.draft.clientId,
    discount: widget.vm.draft.discount,
    discountIsAmount: widget.vm.draft.isAmountDiscount,
    partial: widget.vm.draft.partial,
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
              Tab(text: context.tr('contacts')),
              Tab(text: context.tr('items')),
              Tab(text: context.tr('notes')),
              Tab(text: context.tr('settings')),
              Tab(text: context.tr('pdf')),
            ],
          ),
        ),
        Divider(height: 1, color: tokens.border),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _DetailsTab(vm: widget.vm),
              _ContactsTab(vm: widget.vm),
              _ItemsTab(vm: widget.vm, onPickItems: () => _openPicker(context)),
              _NotesTab(vm: widget.vm),
              _SettingsTab(vm: widget.vm),
              _PdfTab(vm: widget.vm),
            ],
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
        1 => _DatesCardDesktop(vm: widget.vm),
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
              heroTag: 'quote_picker_fab',
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
  final QuoteEditViewModel vm;

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
  final QuoteEditViewModel vm;

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

class _DatesCardDesktop extends StatefulWidget {
  const _DatesCardDesktop({required this.vm});
  final QuoteEditViewModel vm;

  @override
  State<_DatesCardDesktop> createState() => _DatesCardDesktopState();
}

class _DatesCardDesktopState extends State<_DatesCardDesktop> {
  late final TextEditingController _partial;

  @override
  void initState() {
    super.initState();
    _partial = TextEditingController(
      text: widget.vm.draft.partial == Decimal.zero
          ? ''
          : widget.vm.draft.partial.toString(),
    );
  }

  @override
  void dispose() {
    _partial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final fmt = context.read<Services>().formatterIfReady(vm.companyId);
    return FormSection(
      title: null,
      spacing: 0,
      elevated: false,
      children: [
        InDateField(
          value: vm.draft.date?.toDateTime(),
          formatter: fmt,
          onChanged: (d) {
            if (d == null) {
              vm.setDate(null);
            } else {
              vm.setDate(Date(d.year, d.month, d.day));
            }
          },
          labelText: context.tr('quote_date'),
        ),
        SizedBox(height: InSpacing.md(context)),
        InDateField(
          value: vm.draft.dueDate?.toDateTime(),
          formatter: fmt,
          onChanged: (d) {
            if (d == null) {
              vm.setDueDate(null);
            } else {
              vm.setDueDate(Date(d.year, d.month, d.day));
            }
          },
          labelText: context.tr('valid_until'),
          clearable: true,
        ),
        SizedBox(height: InSpacing.md(context)),
        TextField(
          controller: _partial,
          decoration: billingFieldDecoration(
            context,
            label: context.tr('partial'),
            errorText: vm.fieldErrorFor('partial'),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: vm.setPartial,
        ),
        if (vm.draft.partial > Decimal.zero) ...[
          SizedBox(height: InSpacing.md(context)),
          InDateField(
            value: vm.draft.partialDueDate?.toDateTime(),
            formatter: fmt,
            onChanged: (d) {
              if (d == null) {
                vm.setPartialDueDate(null);
              } else {
                vm.setPartialDueDate(Date(d.year, d.month, d.day));
              }
            },
            labelText: context.tr('partial_due_date'),
            clearable: true,
          ),
        ],
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
  final QuoteEditViewModel vm;

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
            label: context.tr('quote_number'),
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
  final QuoteEditViewModel vm;
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
  final QuoteEditViewModel vm;

  @override
  State<_NotesTabsCardDesktop> createState() => _NotesTabsCardDesktopState();
}

class _NotesTabsCardDesktopState extends State<_NotesTabsCardDesktop>
    with SingleTickerProviderStateMixin {
  late final TabController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TabController(length: 5, vsync: this);
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
          ],
        ),
        Divider(height: 1, color: context.inTheme.border),
        SizedBox(
          height: BillingDocEditDesktopShell.notesPaneHeight(context),
          // Widget-order Tab traversal: TabBarView leaves non-current notes
          // sub-tabs built-but-unlaid; reading-order traversal would call
          // `FocusNode.rect` on their host nodes → `hasSize` assertion.
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
                  onSaveAsDefault: (v) => saveBillingDocDefault(
                    context,
                    companyId: vm.companyId,
                    value: v,
                    fieldKey: 'quote_terms',
                    successKey: 'updated_default_terms',
                    apply: (s, val) => s.copyWith(quoteTerms: val),
                  ),
                ),
                MarkdownNotesField(
                  registerBeforeSaveHook: vm.addBeforeSaveHook,
                  label: context.tr('footer'),
                  showLabel: false,
                  expand: true,
                  value: vm.draft.footer,
                  onChanged: vm.setFooter,
                  onSaveAsDefault: (v) => saveBillingDocDefault(
                    context,
                    companyId: vm.companyId,
                    value: v,
                    fieldKey: 'quote_footer',
                    successKey: 'updated_default_footer',
                    apply: (s, val) => s.copyWith(quoteFooter: val),
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
                SingleChildScrollView(
                  child: BillingDocSettingsTab(
                    companyId: vm.companyId,
                    entityType: 'quote',
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PdfPaneDesktop extends StatelessWidget {
  const _PdfPaneDesktop({required this.vm});
  final QuoteEditViewModel vm;

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

/// Document-level tax tiers + custom surcharges + inclusive-tax toggle.
/// Self-collapses when the company has no enabled tax rates and no surcharge
/// labels configured (so it adds no chrome when unused).
class _TaxSurchargeSection extends StatelessWidget {
  const _TaxSurchargeSection({required this.vm});
  final QuoteEditViewModel vm;

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

/// Mobile "Settings" tab — Project / Vendor / User / Exchange-Rate (+ Design).
/// Desktop renders these in a sub-tab of the notes card; mobile previously had
/// no tab for them, so those fields were uneditable on a phone.
class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.vm});
  final QuoteEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: BillingDocSettingsTab(
        companyId: vm.companyId,
        entityType: 'quote',
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
      ),
    );
  }
}

class _DetailsTab extends StatefulWidget {
  const _DetailsTab({required this.vm});
  final QuoteEditViewModel vm;
  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  late final TextEditingController _number;
  late final TextEditingController _poNumber;
  late final TextEditingController _discount;
  late final TextEditingController _partial;

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
    _partial = TextEditingController(
      text: widget.vm.draft.partial == Decimal.zero
          ? ''
          : widget.vm.draft.partial.toString(),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _poNumber.dispose();
    _discount.dispose();
    _partial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final fmt = context.read<Services>().formatterIfReady(vm.companyId);
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
                    labelText: context.tr('quote_number'),
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
            children: [
              Expanded(
                child: InDateField(
                  value: vm.draft.date?.toDateTime(),
                  formatter: fmt,
                  onChanged: (d) {
                    if (d == null) {
                      vm.setDate(null);
                    } else {
                      vm.setDate(Date(d.year, d.month, d.day));
                    }
                  },
                  labelText: context.tr('quote_date'),
                ),
              ),
              SizedBox(width: InSpacing.md(context)),
              Expanded(
                child: InDateField(
                  value: vm.draft.dueDate?.toDateTime(),
                  formatter: fmt,
                  onChanged: (d) {
                    if (d == null) {
                      vm.setDueDate(null);
                    } else {
                      vm.setDueDate(Date(d.year, d.month, d.day));
                    }
                  },
                  labelText: context.tr('valid_until'),
                  clearable: true,
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
          TextField(
            controller: _partial,
            decoration: InputDecoration(
              labelText: context.tr('partial'),
              errorText: vm.fieldErrorFor('partial'),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: vm.setPartial,
          ),
          if (vm.draft.partial > Decimal.zero) ...[
            SizedBox(height: InSpacing.md(context)),
            InDateField(
              value: vm.draft.partialDueDate?.toDateTime(),
              formatter: fmt,
              onChanged: (d) {
                if (d == null) {
                  vm.setPartialDueDate(null);
                } else {
                  vm.setPartialDueDate(Date(d.year, d.month, d.day));
                }
              },
              labelText: context.tr('partial_due_date'),
              clearable: true,
            ),
          ],
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
  final QuoteEditViewModel vm;

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

class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.vm});
  final QuoteEditViewModel vm;

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
  final QuoteEditViewModel vm;

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
  final QuoteEditViewModel vm;
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
              heroTag: 'quote_picker_fab_mobile',
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
  final QuoteEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    // Widget-order Tab traversal: off-screen markdown fields in this
    // ListView are built-but-unlaid; reading-order traversal would call
    // `FocusNode.rect` on their host nodes → `hasSize` assertion.
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
            onSaveAsDefault: (v) => saveBillingDocDefault(
              context,
              companyId: vm.companyId,
              value: v,
              fieldKey: 'quote_terms',
              successKey: 'updated_default_terms',
              apply: (s, val) => s.copyWith(quoteTerms: val),
            ),
          ),
          SizedBox(height: InSpacing.lg(context)),
          MarkdownNotesField(
            registerBeforeSaveHook: vm.addBeforeSaveHook,
            label: context.tr('footer'),
            value: vm.draft.footer,
            onChanged: vm.setFooter,
            onSaveAsDefault: (v) => saveBillingDocDefault(
              context,
              companyId: vm.companyId,
              value: v,
              fieldKey: 'quote_footer',
              successKey: 'updated_default_footer',
              apply: (s, val) => s.copyWith(quoteFooter: val),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfTab extends StatelessWidget {
  const _PdfTab({required this.vm});
  final QuoteEditViewModel vm;

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
      entity: BillingDocType.quote,
      entityNumber: vm.draft.number,
      revision: vm.draft,
      fetcher: ({String? designId, required bool deliveryNote}) =>
          services.quotes.api.downloadPdf(
            entityJson: vm.draft.toApiJson(),
            designId:
                designId ??
                (vm.draft.designId.isEmpty ? null : vm.draft.designId),
          ),
    );
  }
}

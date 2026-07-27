import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/client_settings_cascade.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocations_footer.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocations_section.dart';
import 'package:admin/utils/formatting.dart';

/// Edit + create form body for a Payment. Two-column on wide widths
/// (Expanded main + 360 px sidebar @ 1000 px), single centered column (≤820 px)
/// on narrow —
/// mirrors `ExpenseEditLayout`. Main column: Identity (client + number +
/// date + amount + currency) plus the create-only allocations. Sidebar:
/// Payment metadata (type + transaction reference), Currency conversion,
/// Notes, Custom fields, and the email-receipt toggle.
///
/// Client / Currency / Payment Type use [SearchableDropdownField] per
/// CLAUDE.md § Forms — long-list bindings the user shouldn't have to
/// memorize ids for. Mirrors `expense_edit_identity_section.dart` for the
/// picker pattern. Gateway is intentionally absent: it's set by the payment
/// processor, not user-editable (matches the React + legacy Flutter apps);
/// the detail screen surfaces it read-only.
class PaymentEditLayout extends StatefulWidget {
  const PaymentEditLayout({super.key, required this.vm});

  final PaymentEditViewModel vm;

  @override
  State<PaymentEditLayout> createState() => _PaymentEditLayoutState();
}

class _PaymentEditLayoutState extends State<PaymentEditLayout>
    with FormatterHostMixin {
  static const double _sidebarWidth = 360;

  @override
  void initState() {
    super.initState();
    // Load once; cached in `formatter` on this State so currency strings
    // can render `$1,234.50` instead of raw `Decimal.toString()`.
    loadFormatter(context.read<Services>(), widget.vm.companyId);
  }

  PaymentEditViewModel get vm => widget.vm;

  bool get _useComma => formatter?.settings.useCommaAsDecimalPlace ?? false;

  /// Effective currency for the money shown in the allocations editor.
  ///
  /// `draft.currencyId` alone is not enough: it is seeded only by the client
  /// dropdown's `onChanged`, so every other entry path — "Enter payment" from
  /// an invoice, "Apply credit", a restored deep link — arrives with it empty
  /// and the rows rendered in the COMPANY currency. Resolve from the client
  /// instead (client → group → company, `watchEffectiveClientCurrency`), and
  /// let an explicit pick in the currency dropdown win over it.
  Stream<String>? _clientCurrency;
  String? _clientCurrencyFor;

  Stream<String> _effectiveCurrencyStream(String clientId) {
    if (_clientCurrency != null && _clientCurrencyFor == clientId) {
      return _clientCurrency!;
    }
    final services = context.read<Services>();
    _clientCurrencyFor = clientId;
    return _clientCurrency = watchEffectiveClientCurrency(
      clients: services.clients,
      groups: services.groupSettings,
      companyId: vm.companyId,
      clientId: clientId,
    );
  }

  @override
  Widget build(BuildContext context) {
    // NO inner FormSaveScope here: this layout is the bodyBuilder of
    // EntityEditScreenScaffold, which already wraps the body in a
    // FormSaveScope wired to its own _onSave (navigation + success toast +
    // busy guard). An inner scope shadowed that (FormSaveScope.maybeOf returns
    // the NEAREST), so Enter called a bare vm.save() with no nav/toast and a
    // follow-up Save click created a DUPLICATE payment. Let the scaffold own it.
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final twoCol =
              constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
          return SingleChildScrollView(
            padding: EdgeInsets.all(InSpacing.lg(context)),
            child: twoCol
                ? _wide(context)
                : CenteredFormColumn(child: _narrow(context)),
          );
        },
      ),
    );
  }

  Widget _wide(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _mainColumn(context)),
        SizedBox(width: InSpacing.md(context)),
        SizedBox(width: _sidebarWidth, child: _sidebarColumn(context)),
      ],
    );
  }

  Widget _narrow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mainColumn(context),
        SizedBox(height: InSpacing.lg(context)),
        _sidebarColumn(context),
      ],
    );
  }

  Widget _mainColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _IdentitySection(vm: vm, useCommaAsDecimalPlace: _useComma),
        SizedBox(height: InSpacing.lg(context)),
        DashboardCardShell(
          title: context.tr('tags'),
          child: EntityTagsField(
            entityType: 'payment',
            selectedIds: vm.draft.tagIds,
            onChanged: vm.setTagIds,
          ),
        ),
        if (vm.isCreate) ...[
          SizedBox(height: InSpacing.lg(context)),
          StreamBuilder<String>(
            stream: _effectiveCurrencyStream(vm.draft.clientId),
            builder: (context, snap) {
              final currencyId = vm.draft.currencyId.isNotEmpty
                  ? vm.draft.currencyId
                  : (snap.data ?? '');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PaymentAllocationsSection(
                    kind: AllocationKind.invoice,
                    paymentables: vm.draft.paymentables,
                    clientId: vm.draft.clientId,
                    paymentAmount: vm.draft.amount,
                    onChanged: vm.replacePaymentables,
                    formatter: formatter,
                    currencyId: currencyId,
                  ),
                  SizedBox(height: InSpacing.lg(context)),
                  _CreditsSectionGate(
                    vm: vm,
                    formatter: formatter,
                    currencyId: currencyId,
                  ),
                  SizedBox(height: InSpacing.md(context)),
                  PaymentAllocationsFooter(
                    vm: vm,
                    formatter: formatter,
                    currencyId: currencyId,
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _sidebarColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PaymentMetaSection(vm: vm),
        SizedBox(height: InSpacing.lg(context)),
        _CurrencyConversionSection(vm: vm, formatter: formatter),
        SizedBox(height: InSpacing.lg(context)),
        _NotesSection(vm: vm),
        SizedBox(height: InSpacing.lg(context)),
        _CustomFieldsSection(vm: vm, formatter: formatter),
        SizedBox(height: InSpacing.lg(context)),
        _emailReceiptToggle(context, vm),
      ],
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.vm,
    required this.useCommaAsDecimalPlace,
  });
  final PaymentEditViewModel vm;
  final bool useCommaAsDecimalPlace;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: context.tr('details'),
      children: [
        _ClientPicker(vm: vm),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: vm.draft.number,
          decoration: InputDecoration(labelText: context.tr('number')),
          onChanged: vm.setNumber,
        ),
        const SizedBox(height: 12),
        InDateField(
          labelText: context.tr('date'),
          value: vm.draft.date?.toDateTime(),
          onChanged: (dt) =>
              vm.setDate(dt == null ? null : Date(dt.year, dt.month, dt.day)),
        ),
        const SizedBox(height: 12),
        // Controller-based so the auto-sync from allocations
        // (`PaymentEditViewModel.replacePaymentables`) actually updates
        // the visible text. `TextFormField(initialValue: …)` only consumes
        // its seed on first build, which would freeze this field at zero
        // while `draft.amount` drifts upward as the user picks invoices.
        _AmountField(vm: vm, useCommaAsDecimalPlace: useCommaAsDecimalPlace),
        const SizedBox(height: 12),
        _CurrencyPicker(vm: vm),
      ],
    );
  }
}

class _PaymentMetaSection extends StatelessWidget {
  const _PaymentMetaSection({required this.vm});
  final PaymentEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: context.tr('payment'),
      children: [
        _PaymentTypePicker(vm: vm),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: vm.draft.transactionReference,
          decoration: InputDecoration(
            labelText: context.tr('transaction_reference'),
          ),
          onChanged: vm.setTransactionReference,
        ),
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.vm});
  final PaymentEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: context.tr('notes'),
      children: [
        TextFormField(
          initialValue: vm.draft.privateNotes,
          decoration: InputDecoration(labelText: context.tr('private_notes')),
          maxLines: 4,
          onChanged: vm.setPrivateNotes,
        ),
      ],
    );
  }
}

class _CustomFieldsSection extends StatelessWidget {
  const _CustomFieldsSection({required this.vm, required this.formatter});
  final PaymentEditViewModel vm;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    // Type-aware, gated by the company's configured `payment1..4` labels —
    // self-collapses (renders nothing) when no slots are configured.
    return EntityCustomFieldsSection(
      keyPrefix: 'payment',
      companyStream: context.read<Services>().company.watchCompany(
        vm.companyId,
      ),
      formatter: formatter,
      cardTitle: context.tr('custom_fields'),
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
    );
  }
}

class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.vm});
  final PaymentEditViewModel vm;

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
          displayString: (c) => c.displayName.isEmpty
              ? (c.name.isEmpty ? c.id : c.name)
              : c.displayName,
          idOf: (c) => c.id,
          onChanged: (c) => _onClientChanged(context, c),
          errorText: vm.fieldErrorFor('client_id'),
        );
      },
    );
  }

  Future<void> _onClientChanged(BuildContext context, Client? next) async {
    final nextId = next?.id ?? '';
    if (nextId == vm.draft.clientId) return;
    // If the user has already allocated paymentables, switching client
    // would orphan them. Confirm first.
    if (vm.draft.paymentables.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('change_client')),
          content: Text(ctx.tr('change_client_clears_allocations')),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(ctx.tr('cancel')),
                ),
                const SizedBox(width: 8),
                PrimaryDialogAction(
                  label: ctx.tr('continue_label'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ],
        ),
      );
      if (ok != true) return;
      vm.replaceClientAndClearPaymentables(nextId);
    } else {
      vm.setClientId(nextId);
    }
    // Seed the payment currency from the client when the form hasn't
    // picked one yet — mirrors admin-portal's behavior.
    if (next != null && vm.draft.currencyId.isEmpty) {
      vm.setCurrencyId(next.currencyId);
    }
  }
}

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({required this.vm});
  final PaymentEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final currencies = services.statics.currencies.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    Currency? selected;
    for (final c in currencies) {
      if (c.id == vm.draft.currencyId) {
        selected = c;
        break;
      }
    }
    return SearchableDropdownField<Currency>(
      label: context.tr('currency'),
      items: currencies,
      initialValue: selected,
      displayString: (c) => '${c.code} · ${c.name}',
      idOf: (c) => c.id,
      onChanged: (c) => vm.setCurrencyId(c?.id ?? ''),
      errorText: vm.fieldErrorFor('currency_id'),
    );
  }
}

class _PaymentTypePicker extends StatelessWidget {
  const _PaymentTypePicker({required this.vm});
  final PaymentEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final types = services.statics.paymentTypes.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    PaymentType? selected;
    for (final t in types) {
      if (t.id == vm.draft.typeId) {
        selected = t;
        break;
      }
    }
    return SearchableDropdownField<PaymentType>(
      label: context.tr('type'),
      items: types,
      initialValue: selected,
      displayString: (t) => t.name.isEmpty ? t.id : t.name,
      idOf: (t) => t.id,
      onChanged: (t) => vm.setTypeId(t?.id ?? ''),
      errorText: vm.fieldErrorFor('type_id'),
    );
  }
}

/// Optional currency-conversion sub-form, behind a "Convert currency" toggle.
/// Hidden by default; reveals an exchange-currency picker + rate field + a
/// read-only converted-amount preview when enabled. The toggle's initial
/// state derives from whether the draft already carries an exchange currency
/// (so editing a converted payment shows the fields). Mirrors
/// `ExpenseEditCurrencyConversionSection` (incl. the auto-rate seed on
/// currency pick); payments differ in that the converted amount is purely
/// derived (`amount × rate`) — there is no stored foreign-amount field.
class _CurrencyConversionSection extends StatefulWidget {
  const _CurrencyConversionSection({required this.vm, required this.formatter});
  final PaymentEditViewModel vm;
  final Formatter? formatter;

  @override
  State<_CurrencyConversionSection> createState() =>
      _CurrencyConversionSectionState();
}

class _CurrencyConversionSectionState
    extends State<_CurrencyConversionSection> {
  late bool _enabled = widget.vm.draft.exchangeCurrencyId.isNotEmpty;

  PaymentEditViewModel get vm => widget.vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final currencies = services.statics.currencies.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    Currency? selected;
    for (final c in currencies) {
      if (c.id == vm.draft.exchangeCurrencyId) {
        selected = c;
        break;
      }
    }

    return _Section(
      title: context.tr('currency_conversion'),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('convert_currency')),
          value: _enabled,
          onChanged: (v) {
            setState(() => _enabled = v);
            // Clearing the foreign currency + resetting the rate keeps the
            // wire payload single-currency when the user turns this off.
            if (!v) {
              vm.setExchangeCurrencyId('');
              vm.setExchangeRate('1');
            }
          },
        ),
        if (_enabled) ...[
          const SizedBox(height: 12),
          SearchableDropdownField<Currency>(
            label: context.tr('exchange_currency'),
            items: currencies,
            initialValue: selected,
            displayString: (c) => '${c.code} · ${c.name}',
            idOf: (c) => c.id,
            onChanged: (c) {
              vm.setExchangeCurrencyId(c?.id ?? '');
              // Seed the rate from the two currencies' base (vs-USD) rates so
              // the user doesn't have to look it up (React parity). Leaves the
              // rate untouched when it can't be resolved.
              if (c != null) {
                final rate = crossCurrencyRate(
                  services.statics.currencies,
                  fromExpenseCurrencyId: vm.draft.currencyId,
                  toInvoiceCurrencyId: c.id,
                );
                if (rate != null) vm.setExchangeRate(rate.toString());
              }
            },
            errorText: vm.fieldErrorFor('exchange_currency_id'),
          ),
          // Focus-aware so typing a decimal rate (e.g. `1.08`) isn't reseeded
          // mid-keystroke; still updates when the currency-pick auto-seeds it.
          _RateField(
            vm: vm,
            useCommaAsDecimalPlace:
                widget.formatter?.settings.useCommaAsDecimalPlace ?? false,
          ),
          // Read-only preview in the foreign currency: amount × rate.
          EntityEditField(
            label: context.tr('converted_amount'),
            initial: _convertedText(),
            onChanged: (_) {},
            readOnly: true,
          ),
        ],
      ],
    );
  }

  String _convertedText() {
    final converted = vm.draft.amount * vm.draft.effectiveExchangeRate;
    final f = widget.formatter;
    return f == null
        ? converted.toString()
        : f.money(converted, clientCurrencyId: vm.draft.exchangeCurrencyId);
  }
}

Widget _emailReceiptToggle(BuildContext context, PaymentEditViewModel vm) {
  return SwitchListTile(
    title: Text(context.tr('send_email')),
    value: vm.sendEmail,
    onChanged: (v) => vm.sendEmail = v,
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.ink,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CreditsSectionGate extends StatefulWidget {
  const _CreditsSectionGate({
    required this.vm,
    required this.formatter,
    required this.currencyId,
  });
  final PaymentEditViewModel vm;
  final Formatter? formatter;
  final String? currencyId;

  @override
  State<_CreditsSectionGate> createState() => _CreditsSectionGateState();
}

class _CreditsSectionGateState extends State<_CreditsSectionGate> {
  // Memoize the company watch — without this the StreamBuilder cancels +
  // resubscribes on every parent rebuild (every amount keystroke flows
  // through `vm.notifyListeners()` and rebuilds this whole subtree).
  Stream<Company?>? _stream;

  Stream<Company?> _resolveStream(BuildContext context) {
    if (_stream != null) return _stream!;
    final services = context.read<Services>();
    return _stream = services.company.watchCompany(widget.vm.companyId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Company?>(
      stream: _resolveStream(context),
      builder: (context, snapshot) {
        final company = snapshot.data;
        if (company == null) return const SizedBox.shrink();
        if (!isModuleEnabled(company.enabledModules, EnabledModule.credits)) {
          return const SizedBox.shrink();
        }
        return PaymentAllocationsSection(
          kind: AllocationKind.credit,
          paymentables: widget.vm.draft.paymentables,
          clientId: widget.vm.draft.clientId,
          paymentAmount: widget.vm.draft.amount,
          onChanged: widget.vm.replacePaymentables,
          formatter: widget.formatter,
          currencyId: widget.currencyId,
          // Invoices section owns the "select a client first" hint — keep
          // the credits side silent to avoid the duplicate prompt.
          showClientFirstHint: false,
        );
      },
    );
  }
}

/// Controller-backed top-form Amount input. Re-seeds from `vm.draft.amount`
/// when the external value drifts (auto-sync from allocations) without
/// stealing the user's cursor or wiping mid-keystroke text.
class _AmountField extends StatefulWidget {
  const _AmountField({required this.vm, required this.useCommaAsDecimalPlace});
  final PaymentEditViewModel vm;
  final bool useCommaAsDecimalPlace;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: decimalInputText(widget.vm.draft.amount),
    );
    widget.vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    // Don't fight the user's typing — only re-seed when the external
    // Decimal differs from what's parsed in the field AND the field isn't
    // focused. Compare on Decimal value so trailing-zero variants ("100"
    // vs "100.00") don't trigger a needless reseed.
    if (_focusNode.hasFocus) return;
    final external = widget.vm.draft.amount;
    final typed =
        parseDecimal(
          _controller.text,
          useCommaAsDecimalPlace: widget.useCommaAsDecimalPlace,
        ) ??
        Decimal.zero;
    if (typed == external) return;
    final next = decimalInputText(external);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVmChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The server ignores `amount` on PUT /payments/{id} (it is derived from
    // the payment's applications); React greys the field out on edit for the
    // same reason. Leaving it editable let users "change" the amount, get a
    // success toast, and watch the value snap back on the next sync.
    final locked = !widget.vm.isCreate;
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: !locked,
      decoration: InputDecoration(labelText: context.tr('amount')),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: widget.vm.setAmount,
    );
  }
}

/// Controller-backed exchange-rate input. Mirrors [_AmountField]: re-seeds from
/// `vm.draft.exchangeRate` when the external value drifts (e.g. the auto-rate
/// seed after picking an exchange currency) but never while focused — so a
/// decimal rate like `1.08` isn't clobbered mid-keystroke by the round-trip
/// through `parseDecimal` / `decimalInputText`.
class _RateField extends StatefulWidget {
  const _RateField({required this.vm, required this.useCommaAsDecimalPlace});
  final PaymentEditViewModel vm;
  final bool useCommaAsDecimalPlace;

  @override
  State<_RateField> createState() => _RateFieldState();
}

class _RateFieldState extends State<_RateField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: decimalInputText(widget.vm.draft.exchangeRate),
    );
    widget.vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (_focusNode.hasFocus) return;
    final external = widget.vm.draft.exchangeRate;
    final typed =
        parseDecimal(
          _controller.text,
          useCommaAsDecimalPlace: widget.useCommaAsDecimalPlace,
        ) ??
        Decimal.one;
    if (typed == external) return;
    final next = decimalInputText(external);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVmChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        labelText: context.tr('exchange_rate'),
        errorText: widget.vm.fieldErrorFor('exchange_rate'),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: widget.vm.setExchangeRate,
    );
  }
}

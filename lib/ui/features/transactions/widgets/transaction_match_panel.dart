import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/widgets/client_picker_field.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';
import 'package:admin/ui/core/widgets/locked_entity_field_row.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/transactions/widgets/multi_pick_sheet.dart';
import 'package:admin/utils/formatting.dart';

/// Match panel for an unmatched/matched bank transaction. Two tabs:
///   * **Create** — turn the transaction into a new payment (CREDIT) /
///     expense (DEBIT) by picking the linked entities.
///   * **Link** — attach to an existing payment / expense.
///
/// All four flows route through the existing
/// `BankTransactionRepository.matchTo* / linkTo*` helpers — which enqueue
/// the correct outbox rows with the right wire payloads.
/// Runs one conversion (create / link a payment or expense) and reports it.
/// [successKey] is the toast for a conversion that stays put; a host that
/// moves on to the next transaction shows its own.
typedef TransactionConversionRunner =
    Future<void> Function(Future<void> Function() convert, String successKey);

/// The outbox kinds that convert a transaction. While one is queued the
/// transaction is converted as far as the user is concerned — its local
/// status only changes when the server answers.
const Set<MutationKind> _kConversionKinds = {
  MutationKind.matchToPayment,
  MutationKind.linkToPayment,
  MutationKind.matchToExpense,
  MutationKind.linkToExpense,
};

class TransactionMatchPanel extends StatefulWidget {
  const TransactionMatchPanel({
    super.key,
    required this.transaction,
    this.formatter,
    this.runner,
  });

  final BankTransaction transaction;

  /// Active-company [Formatter] for rendering amounts; null while it is
  /// still resolving on a cold start (amounts fall back to raw fixed-2).
  final Formatter? formatter;

  /// How a conversion runs — the detail screen supplies one that advances to
  /// the next unconverted transaction (React #3396). Null: run it and toast.
  final TransactionConversionRunner? runner;

  @override
  State<TransactionMatchPanel> createState() => _TransactionMatchPanelState();
}

class _TransactionMatchPanelState extends State<TransactionMatchPanel> {
  late Stream<List<OutboxRow>> _pending;

  @override
  void initState() {
    super.initState();
    _pending = _watchPending();
  }

  @override
  void didUpdateWidget(TransactionMatchPanel old) {
    super.didUpdateWidget(old);
    if (old.transaction.id != widget.transaction.id) _pending = _watchPending();
  }

  // Hoisted out of build: a per-build watch re-subscribes on every frame.
  Stream<List<OutboxRow>> _watchPending() {
    final services = context.read<Services>();
    return services.db.outboxDao.watchPendingForEntity(
      companyId: services.auth.session.value?.currentCompanyId ?? '',
      entityType: 'bank_transaction',
      entityId: widget.transaction.id,
    );
  }

  Future<void> _defaultRun(
    Future<void> Function() convert,
    String successKey,
  ) async {
    await convert();
    if (mounted) Notify.success(context, context.tr(successKey));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OutboxRow>>(
      stream: _pending,
      builder: (context, snap) {
        // Nothing changes locally until the queued conversion syncs, so the
        // panel used to stay live — offline, the same transaction could be
        // converted twice. Hold it until the server has answered.
        final converting = (snap.data ?? const <OutboxRow>[]).any(
          (r) =>
              _kConversionKinds.contains(MutationKind.tryParse(r.mutationKind)),
        );
        if (converting) {
          return EmptyState(
            key: const Key('transaction_conversion_pending'),
            icon: Icons.cloud_upload_outlined,
            title: context.tr('conversion_pending_sync'),
          );
        }
        return _tabs(context);
      },
    );
  }

  Widget _tabs(BuildContext context) {
    final run = widget.runner ?? _defaultRun;
    final tx = widget.transaction;
    // Hide the create/link flows when their target module is disabled. A
    // deposit reconciles to a payment (invoices module), a withdrawal to an
    // expense (expenses module). Gating both tabs out would hand
    // EntityDetailTabs an empty list and crash its TabController, so fall back
    // to an empty state instead.
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final target = tx.isDeposit ? EntityType.payment : EntityType.expense;
    if (!(me?.moduleEnabled(target) ?? false)) {
      return EmptyState(
        icon: Icons.toggle_off_outlined,
        title: context.tr('disabled'),
      );
    }
    final createLabelKey = tx.isDeposit ? 'create_payment' : 'create_expense';
    final linkLabelKey = tx.isDeposit ? 'link_payment' : 'link_expense';
    return EntityDetailTabs(
      tabs: [
        EntityDetailTab(
          label: context.tr(createLabelKey),
          icon: Icons.add_circle_outline,
          bodyBuilder: (ctx) => Padding(
            padding: EdgeInsets.all(InSpacing.lg(ctx)),
            child: tx.isDeposit
                ? _CreditCreateTab(
                    transaction: tx,
                    formatter: widget.formatter,
                    run: run,
                  )
                : _DebitCreateTab(transaction: tx, run: run),
          ),
        ),
        EntityDetailTab(
          label: context.tr(linkLabelKey),
          icon: Icons.link_outlined,
          bodyBuilder: (ctx) => Padding(
            padding: EdgeInsets.all(InSpacing.lg(ctx)),
            child: tx.isDeposit
                ? _CreditLinkTab(
                    transaction: tx,
                    formatter: widget.formatter,
                    run: run,
                  )
                : _DebitLinkTab(
                    transaction: tx,
                    formatter: widget.formatter,
                    run: run,
                  ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// CREDIT — Create Payment (pick client → multi-pick invoices)
// ──────────────────────────────────────────────────────────────────────

class _CreditCreateTab extends StatefulWidget {
  const _CreditCreateTab({
    required this.transaction,
    this.formatter,
    required this.run,
  });
  final BankTransaction transaction;
  final TransactionConversionRunner run;
  final Formatter? formatter;

  @override
  State<_CreditCreateTab> createState() => _CreditCreateTabState();
}

class _CreditCreateTabState extends State<_CreditCreateTab> {
  Client? _selectedClient;
  List<Invoice> _selectableInvoices = const <Invoice>[];
  Set<String> _selectedInvoiceIds = <String>{};
  bool _submitting = false;
  StreamSubscription<List<Invoice>>? _invoiceSub;

  @override
  void dispose() {
    _invoiceSub?.cancel();
    super.dispose();
  }

  void _bindInvoices(Client? client) {
    _invoiceSub?.cancel();
    if (client == null) {
      setState(() {
        _selectableInvoices = const <Invoice>[];
        _selectedInvoiceIds = <String>{};
      });
      return;
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    _invoiceSub = services.invoices
        .watchForClient(companyId: companyId, clientId: client.id)
        .listen((list) {
          if (!mounted) return;
          // Filter to unpaid, non-deleted, non-archived invoices with a
          // positive balance — the only ones a payment could plausibly match.
          final unpaid = list
              .where(
                (i) =>
                    !i.isDeleted &&
                    i.archivedAt == null &&
                    i.balance > Decimal.zero,
              )
              .toList(growable: false);
          setState(() {
            _selectableInvoices = unpaid;
            _selectedInvoiceIds = _selectedInvoiceIds
                .where((id) => unpaid.any((inv) => inv.id == id))
                .toSet();
          });
        });
  }

  Decimal get _selectedTotal {
    var total = Decimal.zero;
    for (final inv in _selectableInvoices) {
      if (_selectedInvoiceIds.contains(inv.id)) total += inv.balance;
    }
    return total;
  }

  /// Format an invoice-side amount through the central [Formatter] (company
  /// default currency — invoices carry no row currency), falling back to a
  /// raw fixed-2 string while the formatter is still resolving.
  String _money(Decimal value) {
    final formatted = widget.formatter?.money(value);
    return (formatted != null && formatted.isNotEmpty)
        ? formatted
        : value.toStringAsFixed(2);
  }

  Future<void> _pickInvoices(BuildContext context) async {
    final picked = await showMultiPickSheet<Invoice>(
      context: context,
      title: context.tr('select_invoices'),
      items: _selectableInvoices,
      idOf: (i) => i.id,
      displayString: (i) => i.number.isEmpty ? i.id : '#${i.number}',
      // Invoices carry no row currency (only clientId), so format with the
      // company default — matching the invoice list tile's `cellMoney`.
      subtitleOf: (i) => _money(i.balance),
      amountOf: (i) => i.balance,
      formatter: widget.formatter,
      initialSelected: _selectedInvoiceIds.toList(),
    );
    if (picked != null) {
      setState(() => _selectedInvoiceIds = picked.toSet());
    }
  }

  Future<void> _submit() async {
    if (_selectedInvoiceIds.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    setState(() => _submitting = true);
    try {
      await widget.run(
        () => services.bankTransactions.matchToPayment(
          companyId: companyId,
          transactionId: widget.transaction.id,
          invoiceIds: _selectedInvoiceIds.toList(),
        ),
        'created_payment',
      );
      // The match dispatcher applies the server's updated transaction via
      // applyUpdateResponse, so the detail + list refresh reactively. No
      // manual refreshAll — it raced the outbox drain and a stale list GET
      // could revert the freshly-matched (non-dirty) row to "unmatched".
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final tokens = context.inTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<List<Client>>(
          stream: services.clients.watchPage(
            companyId: companyId,
            loadedPages: 10,
          ),
          builder: (context, snapshot) {
            final clients = snapshot.data ?? const <Client>[];
            return SearchableDropdownField<Client>(
              label: context.tr('client'),
              items: clients,
              initialValue: _selectedClient,
              idOf: (c) => c.id,
              displayString: (c) =>
                  c.displayName.isEmpty ? c.id : c.displayName,
              onChanged: (c) {
                setState(() => _selectedClient = c);
                _bindInvoices(c);
              },
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
          icon: const Icon(Icons.checklist, size: 18),
          label: Text(
            _selectedInvoiceIds.isEmpty
                ? context.tr('select_invoices')
                : context.tr('n_selected', {
                    'count': _selectedInvoiceIds.length.toString(),
                  }),
          ),
          onPressed: _selectedClient == null
              ? null
              : () => _pickInvoices(context),
        ),
        if (_selectedInvoiceIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('calculate_total'),
                  style: TextStyle(color: tokens.ink2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _money(_selectedTotal),
                style: moneyTextStyle(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              icon: const Icon(Icons.check, size: 18),
              label: Text(context.tr('create_payment')),
              onPressed: _submitting || _selectedInvoiceIds.isEmpty
                  ? null
                  : _submit,
            ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// CREDIT — Link Payment (pick one existing payment → {id, payment_id})
// ──────────────────────────────────────────────────────────────────────

class _CreditLinkTab extends StatefulWidget {
  const _CreditLinkTab({
    required this.transaction,
    this.formatter,
    required this.run,
  });
  final BankTransaction transaction;
  final TransactionConversionRunner run;
  final Formatter? formatter;

  @override
  State<_CreditLinkTab> createState() => _CreditLinkTabState();
}

class _CreditLinkTabState extends State<_CreditLinkTab> {
  Payment? _selectedPayment;
  bool _submitting = false;

  Future<void> _submit() async {
    final payment = _selectedPayment;
    if (payment == null) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    setState(() => _submitting = true);
    try {
      await widget.run(
        () => services.bankTransactions.linkToPayment(
          companyId: companyId,
          transactionId: widget.transaction.id,
          paymentId: payment.id,
        ),
        'linked_payment',
      );
      // Status flows in via applyUpdateResponse (see _CreditCreateTab).
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<List<Payment>>(
          stream: services.payments.watchPage(
            companyId: companyId,
            loadedPages: 10,
          ),
          builder: (context, snapshot) {
            final payments = (snapshot.data ?? const <Payment>[])
                // Exclude payments already linked to a bank transaction: the
                // server (MatchBankTransactionRequest) silently drops the link
                // for those, so offering them yields a no-op "linked" toast.
                // Mirrors the sibling expense-link tab's transactionId filter.
                .where(
                  (p) =>
                      !p.isDeleted &&
                      p.archivedAt == null &&
                      p.transactionId.isEmpty,
                )
                .toList(growable: false);
            return SearchableDropdownField<Payment>(
              label: context.tr('payment'),
              items: payments,
              initialValue: _selectedPayment,
              idOf: (p) => p.id,
              displayString: (p) {
                final num = p.number.isEmpty ? p.id : '#${p.number}';
                // Payments carry their own currency_id.
                final formatted = widget.formatter?.money(
                  p.amount,
                  currencyId: p.currencyId,
                );
                final amount = (formatted != null && formatted.isNotEmpty)
                    ? formatted
                    : p.amount.toStringAsFixed(2);
                return '$num · $amount';
              },
              onChanged: (p) => setState(() => _selectedPayment = p),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              icon: const Icon(Icons.link, size: 18),
              label: Text(context.tr('link_payment')),
              onPressed: _submitting || _selectedPayment == null
                  ? null
                  : _submit,
            ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// DEBIT — Create Expense (vendor + category single-select pickers)
// ──────────────────────────────────────────────────────────────────────

class _DebitCreateTab extends StatefulWidget {
  const _DebitCreateTab({required this.transaction, required this.run});
  final BankTransaction transaction;
  final TransactionConversionRunner run;

  @override
  State<_DebitCreateTab> createState() => _DebitCreateTabState();
}

class _DebitCreateTabState extends State<_DebitCreateTab> {
  Vendor? _selectedVendor;
  ExpenseCategory? _selectedCategory;
  bool _submitting = false;
  bool _seededFromRule = false;

  // Who the expense is billed to (React #3397). A picked project decides the
  // client — the server takes it from the project — so the client field
  // locks rather than disappearing.
  String _projectId = '';
  String _clientId = '';

  /// Null until the company has loaded, then its `mark_expenses_invoiceable`
  /// default until the user flips it.
  bool? _shouldBeInvoiced;

  @override
  void initState() {
    super.initState();
    // Seed once on mount — `context.read` is valid in initState (no listen).
    _seedFromRuleIfApplicable();
    _seedShouldBeInvoiced();
  }

  void _seedShouldBeInvoiced() {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    services.company.watchCompany(companyId).first.then((company) {
      if (mounted && _shouldBeInvoiced == null) {
        setState(
          () => _shouldBeInvoiced = company?.markExpensesInvoiceable ?? false,
        );
      }
    }, onError: (Object _) {});
  }

  /// Pre-fill from the matched transaction rule (if any). The rule already
  /// carries `vendorId` / `categoryId` server-side; resolve through the
  /// local repos so the user lands on a one-tap confirm.
  void _seedFromRuleIfApplicable() {
    if (_seededFromRule || widget.transaction.transactionRuleId.isEmpty) {
      return;
    }
    _seededFromRule = true;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    services.transactionRules
        .watch(companyId: companyId, id: widget.transaction.transactionRuleId)
        .first
        .then((rule) async {
          if (!mounted || rule == null) return;
          if (rule.vendorId.isNotEmpty) {
            final vendor = await services.vendors
                .watch(companyId: companyId, id: rule.vendorId)
                .first;
            if (mounted && vendor != null && _selectedVendor == null) {
              setState(() => _selectedVendor = vendor);
            }
          }
          if (rule.categoryId.isNotEmpty) {
            final cat = await services.expenseCategories
                .watch(companyId: companyId, id: rule.categoryId)
                .first;
            if (mounted && cat != null && _selectedCategory == null) {
              setState(() => _selectedCategory = cat);
            }
          }
        });
  }

  Future<void> _submit() async {
    final vendor = _selectedVendor;
    final cat = _selectedCategory;
    if (vendor == null && cat == null) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    setState(() => _submitting = true);
    try {
      await widget.run(
        () => services.bankTransactions.matchToExpense(
          companyId: companyId,
          transactionId: widget.transaction.id,
          vendorId: vendor?.id ?? '',
          categoryId: cat?.id ?? '',
          projectId: _projectId,
          clientId: _clientId,
          shouldBeInvoiced: _shouldBeInvoiced,
        ),
        'created_expense',
      );
      // Status flows in via applyUpdateResponse (see _CreditCreateTab).
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final projectsOn =
        services.auth.session.value?.currentCompany?.moduleEnabled(
          EntityType.project,
        ) ??
        false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<List<Vendor>>(
          stream: services.vendors.watchPage(
            companyId: companyId,
            loadedPages: 10,
          ),
          builder: (context, snapshot) {
            final vendors = snapshot.data ?? const <Vendor>[];
            return SearchableDropdownField<Vendor>(
              label: context.tr('vendor'),
              items: vendors,
              initialValue: _selectedVendor,
              idOf: (v) => v.id,
              displayString: (v) => v.name.isEmpty ? v.id : v.name,
              onChanged: (v) => setState(() => _selectedVendor = v),
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<ExpenseCategory>>(
          stream: services.expenseCategories.watchActive(companyId: companyId),
          builder: (context, snapshot) {
            final cats = snapshot.data ?? const <ExpenseCategory>[];
            return SearchableDropdownField<ExpenseCategory>(
              label: context.tr('category'),
              items: cats,
              initialValue: _selectedCategory,
              idOf: (c) => c.id,
              displayString: (c) => c.name.isEmpty ? c.id : c.name,
              onChanged: (c) => setState(() => _selectedCategory = c),
            );
          },
        ),
        if (projectsOn) ...[
          const SizedBox(height: 12),
          EntityPickerField<Project>(
            label: context.tr('project'),
            // Narrowed to the picked client, so the client is part of what
            // invalidates the stream (as on the expense form).
            cacheKey: (companyId, _projectId.isEmpty ? _clientId : ''),
            selectedId: _projectId,
            itemsStream: () => _clientId.isEmpty || _projectId.isNotEmpty
                ? services.projects.watchPage(
                    companyId: companyId,
                    loadedPages: 100,
                  )
                : services.projects.watchForClient(
                    companyId: companyId,
                    clientId: _clientId,
                  ),
            watchById: (id) =>
                services.projects.watch(companyId: companyId, id: id),
            displayString: (p) => p.name.isEmpty ? p.id : p.name,
            idOf: (p) => p.id,
            onChanged: (p) => setState(() {
              _projectId = p?.id ?? '';
              if (p != null) _clientId = p.clientId;
            }),
          ),
        ],
        const SizedBox(height: 12),
        if (_projectId.isNotEmpty)
          // The project decides the client; clear the project to change it.
          LockedClientFieldRow(
            clientId: _clientId,
            helperText: context.tr('project_drives_client'),
            tappable: false,
          )
        else
          ClientPickerField(
            companyId: companyId,
            selectedClientId: _clientId,
            onSelected: (c) => setState(() => _clientId = c?.id ?? ''),
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('should_be_invoiced')),
          value: _shouldBeInvoiced ?? false,
          onChanged: _shouldBeInvoiced == null
              ? null
              : (v) => setState(() => _shouldBeInvoiced = v),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              icon: const Icon(Icons.check, size: 18),
              label: Text(context.tr('create_expense')),
              onPressed:
                  _submitting ||
                      (_selectedVendor == null && _selectedCategory == null)
                  ? null
                  : _submit,
            ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// DEBIT — Link Expense (multi-pick unmatched expenses)
// ──────────────────────────────────────────────────────────────────────

class _DebitLinkTab extends StatefulWidget {
  const _DebitLinkTab({
    required this.transaction,
    this.formatter,
    required this.run,
  });
  final BankTransaction transaction;
  final TransactionConversionRunner run;
  final Formatter? formatter;

  @override
  State<_DebitLinkTab> createState() => _DebitLinkTabState();
}

class _DebitLinkTabState extends State<_DebitLinkTab> {
  Set<String> _selectedExpenseIds = <String>{};
  bool _submitting = false;

  Future<void> _pickExpenses(BuildContext context) async {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    // Watch one page of active expenses; filter to rows not already linked
    // to a bank transaction. `transactionId` is the expense's own
    // back-reference to a matched bank transaction, so an empty value means
    // it's still available to match (a closer proxy than "has no invoice").
    final expenses = await services.expenses
        .watchPage(
          companyId: companyId,
          // Load a wide slice so the target expense is in range; the sheet's
          // search filters this set client-side.
          loadedPages: 20,
          states: const {EntityState.active},
        )
        .first;
    final candidates = expenses
        .where((e) => e.transactionId.isEmpty && !e.isDeleted)
        .toList(growable: false);
    if (!context.mounted) return;
    final picked = await showMultiPickSheet<Expense>(
      context: context,
      title: context.tr('select_expenses'),
      items: candidates,
      idOf: (e) => e.id,
      displayString: (e) => e.number.isEmpty ? e.id : '#${e.number}',
      // Expenses carry their own currency_id — format through it. Fall back
      // to the raw `amount (CODE)` shape while the formatter is resolving.
      subtitleOf: (e) {
        final formatted = widget.formatter?.money(
          e.amount,
          currencyId: e.currencyId,
        );
        return (formatted != null && formatted.isNotEmpty)
            ? formatted
            : '${e.amount.toStringAsFixed(2)} '
                  '${e.currencyId.isEmpty ? '' : '(${e.currencyId})'}';
      },
      amountOf: (e) => e.amount,
      currencyOf: (e) => e.currencyId,
      formatter: widget.formatter,
      initialSelected: _selectedExpenseIds.toList(),
      addSelectAllButton: true,
    );
    if (picked != null) {
      setState(() => _selectedExpenseIds = picked.toSet());
    }
  }

  Future<void> _submit() async {
    if (_selectedExpenseIds.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    setState(() => _submitting = true);
    try {
      // The `match` endpoint takes one expense_id per `transactions`
      // entry, so we loop and enqueue N mutations rather than a single
      // bulk call. Each row hits the same outbox pipeline.
      // The `match` endpoint takes one expense_id per `transactions`
      // entry, so we enqueue N mutations rather than a single bulk
      // call. `Future.wait` fires them in parallel — each call only
      // hits local Drift + the outbox, so there's no server contention.
      await widget.run(
        () => Future.wait([
          for (final id in _selectedExpenseIds)
            services.bankTransactions.linkToExpense(
              companyId: companyId,
              transactionId: widget.transaction.id,
              expenseId: id,
            ),
        ]),
        'linked_expense',
      );
      // Each linkToExpense applies its server response via applyUpdateResponse
      // (see _CreditCreateTab) — no manual refreshAll.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
          icon: const Icon(Icons.checklist, size: 18),
          label: Text(
            _selectedExpenseIds.isEmpty
                ? context.tr('select_expenses')
                : context.tr('n_selected', {
                    'count': _selectedExpenseIds.length.toString(),
                  }),
          ),
          onPressed: () => _pickExpenses(context),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              icon: const Icon(Icons.link, size: 18),
              label: Text(context.tr('link_expense')),
              onPressed: _submitting || _selectedExpenseIds.isEmpty
                  ? null
                  : _submit,
            ),
          ],
        ),
      ],
    );
  }
}

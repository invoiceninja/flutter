import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:store_services/store_services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/domain/terminal/terminal_eligibility.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/haptics.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/qr_code_image.dart';
import 'package:admin/ui/features/terminal/terminal_error_text.dart';
import 'package:admin/ui/features/terminal/view_models/collect_card_payment_view_model.dart';
import 'package:admin/ui/features/terminal/widgets/reader_picker_sheet.dart';
import 'package:admin/utils/formatting.dart';

/// "Collect card payment" for one invoice (docs/in-person-payments.md): a
/// full-screen step on the root navigator, never part of the saved route.
Future<void> showCollectCardPaymentScreen(
  BuildContext context, {
  required String companyId,
  required Invoice invoice,
  Client? client,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => CollectCardPaymentScreen(
      companyId: companyId,
      invoice: invoice,
      client: client,
    ),
  ),
);

class CollectCardPaymentScreen extends StatefulWidget {
  const CollectCardPaymentScreen({
    super.key,
    required this.companyId,
    required this.invoice,
    this.client,
    @visibleForTesting this.viewModel,
  });

  final String companyId;
  final Invoice invoice;

  /// The invoice's client, for its currency and email, when known.
  final Client? client;

  /// Tests drive the screen with their own (faked) view model.
  final CollectCardPaymentViewModel? viewModel;

  @override
  State<CollectCardPaymentScreen> createState() =>
      _CollectCardPaymentScreenState();
}

class _CollectCardPaymentScreenState extends State<CollectCardPaymentScreen> {
  late final Services _services;
  late final CollectCardPaymentViewModel _vm;
  late final VoidCallback _unregisterGuard;
  late final TextEditingController _amount;
  late final TextEditingController _email;
  Formatter? _formatter;
  Client? _client;
  TerminalDisplayMessage? _readerMessage;
  CollectStage? _lastStage;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    final session = _services.auth.session.value;
    final company = session?.currentCompany;
    _client = widget.client;
    _formatter = _services.formatterIfReady(widget.companyId);
    final precision =
        _formatter?.precisionFor(clientCurrencyId: _client?.currencyId) ?? 2;
    _vm =
        (widget.viewModel ??
              CollectCardPaymentViewModel(
                companyId: widget.companyId,
                invoice: widget.invoice,
                terminal: _services.terminal,
                repository: _services.terminal.repository,
                isAdmin:
                    (company?.isAdmin ?? false) || (company?.isOwner ?? false),
                merchantDisplayName: company?.name ?? '',
                precision: precision,
                clientEmail: _primaryEmail(_client),
              ))
          ..addListener(_onChanged);
    _amount = TextEditingController(text: _moneyInput(_vm.amount));
    _email = TextEditingController(text: _vm.clientEmail)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _services.terminal.platform.events = TerminalReaderEvents(
      onDisplayMessage: (m) => setState(() => _readerMessage = m),
    );
    // A deep link's company switch asks first while a payment is underway.
    _unregisterGuard = _services.unsavedChangesGuard.register(
      isDirty: () => _vm.inProgress,
      source: _vm,
      onDiscard: () => unawaited(_vm.cancel()),
    );
    if (_formatter == null) {
      _services.formatterFor(widget.companyId).then((f) {
        if (mounted) setState(() => _formatter = f);
      });
    }
    unawaited(_vm.start());
  }

  static String _primaryEmail(Client? client) {
    final contacts = [...?client?.contacts]
      ..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));
    for (final c in contacts) {
      if (c.email.trim().isNotEmpty) return c.email.trim();
    }
    return '';
  }

  String _moneyInput(Decimal value) =>
      _formatter?.inputMoney(value, currencyId: _client?.currencyId) ??
      value.toString();

  String _money(Decimal? value) =>
      _formatter?.money(value, clientCurrencyId: _client?.currencyId) ??
      '${value ?? ''}';

  void _onChanged() {
    if (!mounted) return;
    final stage = _vm.stage;
    if (stage != _lastStage) {
      _lastStage = stage;
      _readerMessage = null;
      switch (stage) {
        case CollectStage.approved:
          unawaited(InHaptics.success());
        case CollectStage.waiting || CollectStage.declined:
          unawaited(InHaptics.light());
        default:
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _services.terminal.platform.events = const TerminalReaderEvents();
    _unregisterGuard();
    _vm
      ..removeListener(_onChanged)
      ..dispose();
    _amount.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Commits the field; true when that changed the amount (then quoted
  /// anew). The field shows the amount as the currency rounds it.
  bool _setAmount() {
    final value = parseDecimal(
      _amount.text,
      useCommaAsDecimalPlace:
          _formatter?.settings.useCommaAsDecimalPlace ?? false,
    );
    if (value == null) return false;
    final changed = _vm.setAmount(value);
    final shown = _moneyInput(_vm.amount);
    if (_amount.text != shown) _amount.text = shown;
    return changed;
  }

  /// A typed amount counts even when the field never lost focus (a tap on
  /// touch doesn't unfocus it): a changed amount is quoted first, and the
  /// next tap collects it.
  Future<void> _collect() async {
    if (_setAmount()) return;
    await _vm.collect();
  }

  Future<void> _close() async {
    if (_vm.locked) return;
    if (_vm.inProgress) await _vm.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _acknowledgeSurcharge() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('terminal_surcharge_rules_title')),
        content: SingleChildScrollView(
          child: Text(context.tr('terminal_surcharge_rules')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('terminal_surcharge_accept'),
            // A legal acknowledgement: never Enter's default.
            autofocus: false,
            showEnterHint: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (ok == true) await _vm.acknowledgeSurcharge();
  }

  Future<void> _pickReader() async {
    final reader = await showReaderPickerSheet(
      context,
      readers: _vm.discoverReaders(),
    );
    if (reader != null) await _vm.connectReader(reader);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.inTheme;
    return PopScope(
      canPop: !_vm.locked && !_vm.inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: theme.surface,
        appBar: AppBar(
          title: Text(context.tr('collect_card_payment')),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.tr('close'),
            onPressed: _vm.locked ? null : _close,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: EdgeInsets.all(InSpacing.lg(context)),
                children: [
                  if (!_vm.livemode) _TestModeBadge(),
                  ..._body(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) => switch (_vm.stage) {
    CollectStage.configure => _configure(context),
    CollectStage.creating => [
      _Status(text: context.tr('terminal_preparing'), busy: true),
    ],
    CollectStage.openCollection => [
      _Status(text: _problemText(context)),
      const SizedBox(height: InSpacing.xl),
      _Buttons(
        primary: context.tr('terminal_cancel_open'),
        onPrimary: _vm.cancelOpenCollection,
        secondary: context.tr('close'),
        onSecondary: () async => Navigator.of(context).pop(),
      ),
    ],
    CollectStage.waiting => _waiting(context),
    CollectStage.finalizing => [
      _Total(text: _totalText()),
      _Status(text: context.tr('terminal_checking_card'), busy: true),
    ],
    CollectStage.processing => [
      _Total(text: _totalText()),
      _Status(text: context.tr('terminal_processing'), busy: true),
    ],
    CollectStage.declined => [
      _Total(text: _totalText()),
      _Status(
        text: _problemText(context),
        icon: Icons.credit_card_off_outlined,
      ),
      const SizedBox(height: InSpacing.xl),
      _Buttons(
        primary: context.tr(switch (_vm.problem?.code) {
          TerminalErrorCode.declined ||
          TerminalErrorCode.cardNotRead ||
          TerminalErrorCode.pinUnavailable => 'terminal_try_another_card',
          _ => 'terminal_try_again',
        }),
        onPrimary: _vm.tryAnotherCard,
        secondary: context.tr('cancel'),
        onSecondary: _close,
      ),
    ],
    CollectStage.approved => _approved(context),
    CollectStage.recording => _pending(
      context,
      context.tr('terminal_recording'),
    ),
    CollectStage.checking => [
      ..._pending(context, context.tr('terminal_checking_help')),
      const SizedBox(height: InSpacing.sm),
      Center(
        child: TextButton(
          onPressed: _vm.cancelUnconfirmed,
          child: Text(context.tr('terminal_cancel_payment')),
        ),
      ),
    ],
    CollectStage.unrecorded => [
      _Status(
        text: context.tr('terminal_unrecorded'),
        icon: Icons.report_outlined,
      ),
      const SizedBox(height: InSpacing.xl),
      _Buttons(
        primary: context.tr('close'),
        onPrimary: () async => Navigator.of(context).pop(),
      ),
    ],
    CollectStage.cancelled => [
      _Status(
        text: context.tr('terminal_cancelled'),
        icon: Icons.block_outlined,
      ),
      if (_vm.problem != null) ...[
        const SizedBox(height: InSpacing.sm),
        Text(_problemText(context), textAlign: TextAlign.center),
      ],
      const SizedBox(height: InSpacing.xl),
      _Buttons(
        primary: context.tr('close'),
        onPrimary: () async => Navigator.of(context).pop(),
      ),
    ],
  };

  String _problemText(BuildContext context) {
    final problem = _vm.problem;
    return problem == null ? '' : terminalProblemText(problem, context.tr);
  }

  String _totalText() {
    final finalized = _vm.finalized;
    if (finalized != null && _vm.readAgain) return _money(finalized.amount);
    return _money(_vm.quote?.total ?? _vm.amount);
  }

  List<Widget> _configure(BuildContext context) {
    final quote = _vm.quote;
    final surchargeShown = _vm.applySurcharge && quote != null;
    return [
      Text(
        context.tr('terminal_for_invoice', {'number': widget.invoice.number}),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (widget.invoice.isDraft) ...[
        const SizedBox(height: InSpacing.xs),
        Text(context.tr('terminal_draft_marked_sent')),
      ],
      const SizedBox(height: InSpacing.sm),
      FormSaveScope(
        onSubmit: _setAmount,
        child: Focus(
          onFocusChange: (focused) {
            if (!focused) _setAmount();
          },
          child: TextField(
            controller: _amount,
            decoration: InputDecoration(labelText: context.tr('amount')),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _setAmount(),
          ),
        ),
      ),
      if (_vm.surchargeNeedsAcknowledgement) ...[
        const SizedBox(height: InSpacing.sm),
        if (_vm.isAdmin)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _acknowledgeSurcharge,
              child: Text(context.tr('terminal_surcharge_set_up')),
            ),
          )
        else
          Text(context.tr('terminal_surcharge_ask_admin')),
      ],
      if (_vm.surchargeOffered)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _vm.applySurcharge,
          onChanged: _vm.setSurcharge,
          title: Text(_surchargeLabel(context)),
          subtitle: Text(context.tr('terminal_surcharge_credit_only')),
        ),
      const SizedBox(height: InSpacing.sm),
      if (quote != null)
        Semantics(
          liveRegion: true,
          child: Text(
            surchargeShown && quote.feeGross > Decimal.zero
                ? context.tr('terminal_customer_pays_surcharge', {
                    'total': _money(quote.total),
                    'amount': _money(quote.amount),
                  })
                : context.tr('terminal_customer_pays', {
                    'total': _money(quote.total),
                  }),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        )
      else if (_vm.quoting)
        const LinearProgressIndicator()
      else
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _vm.requote,
            child: Text(context.tr('retry')),
          ),
        ),
      SizedBox(height: InSpacing.md(context)),
      _ReaderRow(vm: _vm, onPickReader: _pickReader),
      if (_vm.problem != null && _vm.readerState != ReaderState.failed) ...[
        const SizedBox(height: InSpacing.sm),
        Text(
          _problemText(context),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: InSpacing.xl),
      FilledButton(
        onPressed: _vm.canCollect ? _collect : null,
        child: Text(
          quote == null
              ? context.tr('collect_card_payment')
              : context.tr('terminal_collect_amount', {
                  'amount': _money(quote.total),
                }),
        ),
      ),
    ];
  }

  /// "Add credit card surcharge (3%)", or without the figure when the fee
  /// is a fixed amount.
  String _surchargeLabel(BuildContext context) {
    final percent = _vm.gateway?.surcharge.feePercent ?? Decimal.zero;
    if (percent <= Decimal.zero) {
      return context.tr('terminal_add_surcharge_plain');
    }
    final f = _formatter;
    final text = f == null
        ? percent.toString()
        : f.inputAmount(percent.toDouble());
    return context.tr('terminal_add_surcharge', {'percent': text});
  }

  List<Widget> _waiting(BuildContext context) {
    final message = _readerMessage;
    final tapToPay = _vm.reader?.kind == TerminalReaderKind.tapToPay;
    final finalized = _vm.finalized;
    final again = _vm.readAgain && finalized != null;
    return [
      _Total(text: _totalText()),
      _Status(
        icon: Icons.contactless_outlined,
        text: again
            ? (finalized.surcharge > Decimal.zero
                  ? context.tr('terminal_tap_again_surcharge', {
                      'amount': _money(finalized.amount),
                    })
                  : context.tr('terminal_tap_again'))
            : message != null
            ? context.tr(_readerMessageKey(message))
            : context.tr(
                tapToPay ? 'terminal_hold_card' : 'terminal_present_card',
              ),
      ),
      const SizedBox(height: InSpacing.xl),
      _Buttons(
        primary: context.tr('cancel'),
        onPrimary: _vm.cancel,
        tonal: true,
      ),
    ];
  }

  List<Widget> _approved(BuildContext context) {
    final done = _vm.completion;
    // What the server recorded: after a refunded surcharge, or for another
    // attempt's payment, that is not what this screen quoted.
    final charged = done != null && done.isRecorded
        ? _money(done.applied + done.unapplied)
        : _money(_vm.finalized?.amount ?? _vm.quote?.total);
    final card = [
      if ((done?.brand ?? '').isNotEmpty) done!.brand.toUpperCase(),
      if ((done?.last4 ?? '').isNotEmpty) '•• ${done!.last4}',
    ].join(' ');
    final receiptUrl = done?.receiptUrl ?? '';
    return [
      _Status(
        icon: Icons.check_circle_outline,
        text: context.tr('terminal_approved'),
      ),
      _Total(text: charged),
      if (card.isNotEmpty) Center(child: LtrText(card)),
      if (done?.status == 'unapplied')
        Padding(
          padding: const EdgeInsets.only(top: InSpacing.sm),
          child: Text(
            context.tr('terminal_unapplied', {
              'amount': _money(done!.unapplied),
            }),
            textAlign: TextAlign.center,
          ),
        )
      else if (done?.invoiceBalance != null)
        Padding(
          padding: const EdgeInsets.only(top: InSpacing.sm),
          child: Text(
            context.tr('terminal_remaining_balance', {
              'amount': _money(done!.invoiceBalance),
            }),
            textAlign: TextAlign.center,
          ),
        ),
      const SizedBox(height: InSpacing.xl),
      if (_vm.receiptSent)
        Text(context.tr('terminal_receipt_sent'), textAlign: TextAlign.center)
      else ...[
        TextField(
          controller: _email,
          decoration: InputDecoration(labelText: context.tr('email')),
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendReceipt(),
        ),
        const SizedBox(height: InSpacing.sm),
        OutlinedButton(
          onPressed: _vm.sendingReceipt ? null : _sendReceipt,
          child: Text(context.tr('terminal_send_receipt')),
        ),
        if (_vm.problem != null) ...[
          const SizedBox(height: InSpacing.sm),
          Text(
            _problemText(context),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_email.text.trim().isEmpty && receiptUrl.isNotEmpty) ...[
          SizedBox(height: InSpacing.md(context)),
          Text(
            context.tr('terminal_scan_receipt'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: InSpacing.sm),
          Center(child: QrCodeImage(data: receiptUrl, size: 180)),
        ],
      ],
      const SizedBox(height: InSpacing.xl),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr('done')),
      ),
    ];
  }

  Future<void> _sendReceipt() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    await _vm.sendReceipt(email);
  }

  List<Widget> _pending(BuildContext context, String text) => [
    _Total(text: _totalText()),
    _Status(text: text, icon: Icons.hourglass_top_outlined),
    const SizedBox(height: InSpacing.xl),
    _Buttons(
      primary: context.tr('terminal_check_again'),
      onPrimary: _vm.checkAgain,
      secondary: context.tr('close'),
      onSecondary: () async => Navigator.of(context).pop(),
    ),
  ];
}

class _ReaderRow extends StatelessWidget {
  const _ReaderRow({required this.vm, required this.onPickReader});

  final CollectCardPaymentViewModel vm;
  final Future<void> Function() onPickReader;

  @override
  Widget build(BuildContext context) {
    final tapToPay = vm.readerChoice == TerminalReaderChoice.tapToPay;
    final (String text, Widget? action) = switch (vm.readerState) {
      ReaderState.idle || ReaderState.permissions => (
        context.tr('terminal_permissions_help'),
        null,
      ),
      ReaderState.blocked => (
        context.tr('terminal_error_permission'),
        TextButton(
          onPressed: vm.openSettings,
          child: Text(context.tr('open_settings')),
        ),
      ),
      ReaderState.connecting => (
        context.tr(
          tapToPay
              ? 'terminal_tap_to_pay_preparing'
              : 'terminal_reader_connecting',
        ),
        null,
      ),
      ReaderState.needsReader => (
        context.tr('terminal_reader_needed'),
        TextButton(
          onPressed: onPickReader,
          child: Text(context.tr('terminal_connect_reader')),
        ),
      ),
      ReaderState.ready => (
        tapToPay
            ? context.tr('terminal_tap_to_pay_ready')
            : context.tr('terminal_reader_ready', {
                'reader': vm.reader?.label ?? '',
              }),
        null,
      ),
      ReaderState.failed => (
        vm.problem == null
            ? context.tr('terminal_error_unknown')
            : terminalProblemText(vm.problem!, context.tr),
        TextButton(
          onPressed: vm.prepareReader,
          child: Text(context.tr('retry')),
        ),
      ),
    };
    final busy =
        vm.readerState == ReaderState.connecting ||
        vm.readerState == ReaderState.permissions;
    return Row(
      children: [
        Icon(
          vm.readerState == ReaderState.ready
              ? Icons.contactless_outlined
              : Icons.info_outline,
          size: 20,
        ),
        const SizedBox(width: InSpacing.sm),
        Expanded(child: Text(text)),
        if (busy)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ?action,
      ],
    );
  }
}

class _TestModeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: InSpacing.sm),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.inTheme.warningSoft,
          borderRadius: BorderRadius.circular(InRadii.r1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            context.tr('test_mode').toUpperCase(),
            style: TextStyle(
              color: context.inTheme.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Total extends StatelessWidget {
  const _Total({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
    child: Center(
      child: LtrText(
        text,
        style: Theme.of(context).textTheme.displaySmall,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.text, this.icon, this.busy = false});

  final String text;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      children: [
        SizedBox(height: InSpacing.md(context)),
        if (busy)
          const CircularProgressIndicator()
        else if (icon != null)
          Icon(icon, size: 48),
        SizedBox(height: InSpacing.md(context)),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.tonal = false,
  });

  final String primary;
  final Future<void> Function() onPrimary;
  final String? secondary;
  final Future<void> Function()? onSecondary;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    const size = Size(64, 44);
    final main = tonal
        ? FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: size),
            onPressed: onPrimary,
            child: Text(primary),
          )
        : FilledButton(
            style: FilledButton.styleFrom(minimumSize: size),
            onPressed: onPrimary,
            child: Text(primary),
          );
    final second = secondary;
    if (second == null) return main;
    // Side by side, the way out next to the way on (CLAUDE.md § Design
    // system (v2)).
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: onSecondary,
            child: Text(second),
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        Expanded(child: main),
      ],
    );
  }
}

/// A Bluetooth reader's prompt, in words.
String _readerMessageKey(TerminalDisplayMessage message) => switch (message) {
  TerminalDisplayMessage.retryCard => 'terminal_reader_retry_card',
  TerminalDisplayMessage.insertCard => 'terminal_reader_insert_card',
  TerminalDisplayMessage.insertOrSwipeCard =>
    'terminal_reader_insert_or_swipe_card',
  TerminalDisplayMessage.swipeCard => 'terminal_reader_swipe_card',
  TerminalDisplayMessage.removeCard => 'terminal_reader_remove_card',
  TerminalDisplayMessage.multipleContactlessCardsDetected =>
    'terminal_reader_multiple_cards',
  TerminalDisplayMessage.tryAnotherReadMethod =>
    'terminal_reader_try_another_read_method',
  TerminalDisplayMessage.tryAnotherCard => 'terminal_reader_try_another_card',
  TerminalDisplayMessage.cardRemovedTooEarly =>
    'terminal_reader_card_removed_too_early',
  TerminalDisplayMessage.checkMobileDevice =>
    'terminal_reader_check_mobile_device',
};

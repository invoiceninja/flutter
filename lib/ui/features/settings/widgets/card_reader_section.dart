import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:store_services/store_services.dart';

import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/terminal_controller.dart';
import 'package:admin/domain/terminal/terminal_eligibility.dart';
import 'package:admin/data/services/terminal_server_error.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/terminal/terminal_error_text.dart';
import 'package:admin/ui/features/terminal/widgets/reader_picker_sheet.dart';

/// Search keys for the settings sidebar search, colocated with the card (see
/// `search_catalog_consistency_test`).
const kCardReaderSearchKeys = <String>[
  'card_readers',
  'tap_to_pay',
  'bluetooth_card_reader',
];

/// Whether [CardReaderSection] renders here — and so whether settings search
/// offers its keys: the store build of the mobile app.
bool cardReaderSectionShown() =>
    kCardPresentEnabled && Env.isMobile && StripeTerminal.isAvailable;

/// Device Settings → Phone: what this phone can take cards with
/// (docs/in-person-payments.md) — Tap to Pay, or why not; the Bluetooth card
/// reader, connected or not; and where the feature is turned on. Connecting a
/// reader here is how a phone without Tap to Pay starts offering "Collect
/// card payment" on invoices.
class CardReaderSection extends StatefulWidget {
  const CardReaderSection({super.key});

  @override
  State<CardReaderSection> createState() => _CardReaderSectionState();
}

class _CardReaderSectionState extends State<CardReaderSection> {
  late final Services _services;
  late final String? _companyId;
  bool _busy = false;

  TerminalController get _terminal => _services.terminal;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value?.currentCompanyId;
    if (cardReaderSectionShown() && _companyId != null) {
      _terminal.ensureConfig(_companyId);
    }
  }

  Future<void> _connect() async {
    final companyId = _companyId;
    final config = companyId == null ? null : _terminal.configFor(companyId);
    final gateway = config?.usableGateway;
    if (companyId == null || gateway == null) {
      Notify.warning(context, context.tr('terminal_server_not_enabled'));
      return;
    }
    final company = _services.auth.session.value?.currentCompany;
    final isAdmin = (company?.isAdmin ?? false) || (company?.isOwner ?? false);
    var location = gateway.locations.firstOrNull;
    if (location == null && !isAdmin) {
      Notify.warning(context, context.tr('terminal_ask_admin_location'));
      return;
    }
    setState(() => _busy = true);
    try {
      // The gateway's first reader: an admin creates its Stripe Location
      // from the company address, as the collect screen does.
      location ??= await _terminal.repository.createLocation(
        companyId,
        companyGatewayId: gateway.companyGatewayId,
      );
      if (!mounted) return;
      unawaited(_terminal.refreshConfig(companyId));
      final permission = await _terminal.platform.requestPermissions(
        TerminalReaderKind.bluetooth,
      );
      if (!mounted) return;
      if (permission != TerminalPermission.granted) {
        Notify.warning(context, context.tr('terminal_error_permission'));
        if (permission == TerminalPermission.blocked) {
          await _terminal.platform.openSettings();
        }
        return;
      }
      await _terminal.prepare(
        companyId: companyId,
        gateway: gateway,
        location: location,
      );
      if (!mounted) return;
      final reader = await showReaderPickerSheet(
        context,
        readers: () => _terminal.discoverBluetooth(gateway),
      );
      if (reader == null) return;
      await _terminal.connectBluetooth(
        reader,
        location: location,
        merchantDisplayName:
            _services.auth.session.value?.currentCompany?.name ?? '',
      );
    } on TerminalError catch (e) {
      if (mounted) {
        Notify.error(context, context.tr(terminalErrorKey(e.code)));
      }
    } on TerminalServerError catch (e) {
      if (mounted) {
        Notify.error(
          context,
          context.tr(
            terminalServerErrorKey(e.code) ?? 'terminal_error_unknown',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Notify.error(context, context.tr('terminal_error_unknown'), error: e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What the server said for this company, when it isn't "ready".
  String? _stateKey() {
    final companyId = _companyId;
    if (companyId == null) return null;
    return switch (_terminal.configState(companyId)) {
      TerminalConfigState.noPermission => 'terminal_state_no_permission',
      TerminalConfigState.serverTooOld => 'terminal_state_server_too_old',
      TerminalConfigState.unreachable => 'terminal_state_unreachable',
      TerminalConfigState.switchedOff => 'terminal_server_disabled',
      TerminalConfigState.notEnabled => 'terminal_server_not_enabled',
      TerminalConfigState.accountInactive => 'terminal_state_account_inactive',
      TerminalConfigState.planRequired => 'terminal_server_plan_required',
      TerminalConfigState.unavailable ||
      TerminalConfigState.loading ||
      TerminalConfigState.ready => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!cardReaderSectionShown()) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: _terminal,
      builder: (context, _) {
        final device = _terminal.device;
        final reader = _terminal.reader;
        final bluetoothReader =
            reader != null && reader.kind == TerminalReaderKind.bluetooth;
        final tapToPay = device?.tapToPay ?? false;
        return FormSection(
          title: context.tr('card_readers'),
          spacing: 0,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.contactless_outlined),
              title: Text(context.tr('tap_to_pay')),
              subtitle: Text(
                tapToPay
                    ? context.tr('terminal_tap_to_pay_ready')
                    : context.tr(switch (device?.tapToPayBlocker) {
                        TerminalErrorCode.unsupportedOs =>
                          'terminal_error_unsupported_os',
                        _ => 'terminal_tap_to_pay_unavailable',
                      }),
              ),
            ),
            if (kCardPresentBluetooth)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.point_of_sale_outlined),
                title: Text(context.tr('bluetooth_card_reader')),
                subtitle: Text(
                  bluetoothReader
                      ? reader.label
                      : context.tr('terminal_no_reader'),
                ),
                trailing: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : bluetoothReader
                    ? TextButton(
                        onPressed: _terminal.disconnect,
                        child: Text(context.tr('disconnect')),
                      )
                    : TextButton(
                        onPressed: _connect,
                        child: Text(context.tr('terminal_connect_reader')),
                      ),
              ),
            if (_stateKey() case final key?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.tr(key)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr('terminal_setup_help'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

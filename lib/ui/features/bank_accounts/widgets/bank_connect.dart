import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_list_screen.dart'
    show connectBankUrl;

/// The aggregator's hosted connect page, launched in the system browser.
///
/// Single implementation behind three surfaces — the list's overflow
/// "Connect Accounts", the per-row Connect chip (invoiceninja/flutter#70), and
/// `ReconnectBanner` — which were three copies of the same 30 lines.
///
/// The aggregator + server own the OAuth/credential exchange; the app just
/// mints a one-time token, opens the URL, and lets the next Refresh /
/// pull-to-refresh pull down whatever got linked. Not an outbox mutation —
/// you can't link a bank offline.
///
/// Returns true when the browser opened.
Future<bool> startBankConnect(
  BuildContext context, {
  String? provider,
  String? institutionId,
}) async {
  final resolved = provider ?? await _pickProvider(context);
  if (resolved == null || !context.mounted) return false;

  final services = context.read<Services>();
  final baseUrl = services.auth.session.value?.baseUrl ?? '';
  final toasts = Notify.capture(context);
  final tr = context.tr;

  try {
    final hash = await services.bankAccounts.api.oneTimeToken(
      context: resolved,
      institutionId: institutionId,
    );
    final opened = await launchExternalUri(
      Uri.parse(connectBankUrl(resolved, hash, baseUrl)),
    );
    if (opened) {
      toasts?.success(tr('complete_in_browser'));
    } else {
      toasts?.error(tr('failed_to_open_url'));
    }
    return opened;
  } catch (e) {
    toasts?.error(bankConnectErrorMessage(e, tr));
    return false;
  }
}

/// Turn a failed connect into something the user can act on.
///
/// "An error occurred: The given data was invalid." told the reporter nothing
/// (invoiceninja/flutter#69) — the actionable detail was sitting in the 422's
/// per-field messages, unread. Those are flattened out here.
///
/// A 5xx deliberately does **not** get its message surfaced:
/// `ApiClient._raiseFromResponse` splices up to 240 raw bytes of the response
/// body into it, which for an HTML error page is gibberish in a toast.
String bankConnectErrorMessage(Object error, String Function(String) tr) {
  if (error is ValidationException) {
    final lines = error.fieldErrors.values
        .expand((v) => v)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    if (lines.isNotEmpty) return lines.join(' · ');
  }
  if (error is ServerException) return tr('an_error_occurred');
  if (error is ApiException) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  return tr('an_error_occurred');
}

/// Self-hosted connects via Nordigen directly (React parity — no provider
/// modal); hosted enterprise picks a provider first. Null = cancelled.
Future<String?> _pickProvider(BuildContext context) async {
  final session = context.read<Services>().auth.session.value;
  if (session?.isSelfHosted ?? false) return 'nordigen';
  return showDialog<String>(
    context: context,
    builder: (d) => SimpleDialog(
      title: Text(d.tr('connect_accounts')),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(d).pop('yodlee'),
          // i18n-exempt: brand name
          child: const Text('Yodlee'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(d).pop('nordigen'),
          // i18n-exempt: brand name
          child: const Text('Nordigen (GoCardless)'),
        ),
      ],
    ),
  );
}

/// True when the account is a plain manual ledger — added, but never wired to
/// a bank feed, so it will never produce transactions on its own. Distinct
/// from [BankAccount.needsReconnect], which is a *linked* account whose
/// upstream connection has since gone stale.
bool bankAccountNeedsConnecting(BankAccount account) =>
    account.integrationType.isEmpty;

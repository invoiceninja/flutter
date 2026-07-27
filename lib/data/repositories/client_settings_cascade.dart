/// The client→group→company settings cascade, client-side.
///
/// The server resolves a client setting in THREE tiers — `Client::getSetting()`
/// checks the client's own sparse `settings`, then its
/// `group_settings->settings`, then the company. The app modelled tiers 1 and 3
/// and skipped the group entirely, so a client that inherits from a group
/// rendered in the COMPANY currency (wrong symbol, separators and precision vs
/// the PDF and the portal) and the client-scope settings editor showed the
/// company's value greyed out as "inherited".
///
/// These helpers resolve the missing tier. They deliberately do NOT overwrite
/// `Client.currencyId`: that field is the client's own OVERRIDE, and the edit
/// screen binds it directly — folding an inherited value into it would persist
/// the group's currency as a per-client override on the next save.
library;

import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/group_setting_repository.dart';

/// Currency the client actually bills in: its own override, else its group's,
/// else empty (meaning "fall through to the company", which every
/// `Formatter.money` call already does).
///
/// Re-emits on any change to the CLIENT — its own currency, or its
/// `group_settings_id` (reassigning a client to a different group re-resolves
/// without a screen rebuild). See the note in the body for why a group's *own*
/// currency edit is picked up on remount rather than pushed live.
Stream<String> watchEffectiveClientCurrency({
  required ClientRepository clients,
  required GroupSettingRepository groups,
  required String companyId,
  required String clientId,
}) async* {
  if (clientId.isEmpty) {
    yield '';
    return;
  }
  // The group tier is read as a one-shot map, lazily (only when a client
  // actually inherits) and cached for the life of this subscription — NOT as a
  // second live watch. A live one would mean two Drift streams per consumer,
  // and `party_money_cell` mounts one of these per list row. Group settings
  // are a small, bundled set, so one map is cheap.
  //
  // Consequence, by design: edits to the CLIENT (its own currency, its group
  // assignment) re-resolve immediately; editing a GROUP's own currency while a
  // screen is open does not push — that screen re-resolves on remount. Groups
  // are rarely edited mid-flow.
  Map<String, String>? groupCurrencies;
  // `await for` (not `asyncExpand`): asyncExpand pauses the source until the
  // inner stream COMPLETES, and a Drift watch never completes — so the client
  // stream would be paused for good after the first group-branch resolution,
  // and later client changes would never arrive.
  await for (final client in clients.watch(
    companyId: companyId,
    id: clientId,
  )) {
    if (client == null || client.currencyId.isNotEmpty) {
      yield client?.currencyId ?? '';
      continue;
    }
    final groupId = client.groupSettingsId;
    if (groupId.isEmpty) {
      yield '';
      continue;
    }
    groupCurrencies ??= await _groupCurrencies(groups, companyId);
    yield groupCurrencies[groupId] ?? '';
  }
}

/// `{groupId: currencyId}` for the company's groups. A failed read degrades to
/// "client's own override, else company" — what the app did before this
/// cascade existed — rather than killing the stream.
Future<Map<String, String>> _groupCurrencies(
  GroupSettingRepository groups,
  String companyId,
) async {
  try {
    final all = await groups.watchAll(companyId: companyId).first;
    return {
      for (final g in all)
        if ((g.currencyId ?? '').isNotEmpty) g.id: g.currencyId!,
    };
  } catch (_) {
    return const {};
  }
}

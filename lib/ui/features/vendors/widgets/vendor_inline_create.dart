import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/entity_name_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/search_fold.dart';

/// How long the pre-create server search may take before the create goes
/// ahead on the local cache alone. A connection that is up but not answering
/// (a captive portal, dead Wi-Fi) would otherwise hold the field's spinner for
/// the full request timeout.
const Duration kVendorDuplicateSearchTimeout = Duration(seconds: 4);

/// Server pages the duplicate search may read. The server's vendor search is
/// broad — a LIKE over name, id number, contacts and custom values — so a
/// short name's exact match can sit past page 1.
const int _kDuplicateSearchPages = 3;

/// Rows the local exact-name check reads. Generous on purpose: a common word
/// can match many vendors that sort before the exact one.
const int _kDuplicateScanPages = 20;

/// A picker's inline "New Vendor" / `Create "«query»"` (old app parity: the
/// vendor is created from its name alone, the rest filled in later).
///
/// An empty [query] asks for the name first. Before creating, the server is
/// searched for that exact name — a large account's local cache need not hold
/// every vendor, and a duplicate is far harder to undo than a pick. The check
/// spans **every state**: an active match is selected instead; an archived or
/// deleted one is refused with a toast, as the category create does (vendor
/// names aren't unique server-side, so this one is about the user, not a 422).
/// Offline, or when the search outlasts [kVendorDuplicateSearchTimeout], only
/// the local cache is checked and the create goes ahead; the vendor queues like
/// any other offline create, and an expense saved against its `tmp_` id is
/// rewritten when it syncs.
///
/// Resolves to the vendor to select, or null when cancelled, refused or failed
/// (each toasted here).
Future<Vendor?> createVendorInline(
  BuildContext context, {
  required String companyId,
  required String query,
}) async {
  final services = context.read<Services>();
  final name = query.trim().isNotEmpty
      ? query.trim()
      : await showEntityNameDialog(context, titleKey: 'new_vendor');
  if (name == null || !context.mounted) return null;

  try {
    final existing = await _findExactVendor(services, companyId, name);
    if (!context.mounted) return null;
    if (existing != null) {
      if (existing.archivedAt != null || existing.isDeleted) {
        Notify.warning(
          context,
          context.tr('inline_create_name_taken', {'name': existing.name}),
        );
        return null;
      }
      Notify.info(
        context,
        context.tr('inline_create_used_existing', {'name': existing.name}),
      );
      return existing;
    }
    final company = await services.company.get(companyId);
    final created = (await services.vendors.create(
      companyId: companyId,
      draft: emptyVendor().copyWith(
        name: name,
        // The server would default it to the company's currency anyway; doing
        // it here too lets the expense form seed its currency from the vendor
        // the moment it is picked.
        currencyId: company?.settings.currencyId ?? '',
      ),
    )).entity;
    if (!context.mounted) return created;
    Notify.success(context, context.tr('created_vendor'));
    return created;
  } catch (e) {
    if (context.mounted) {
      Notify.error(context, context.tr('could_not_save'), error: e);
    }
    return null;
  }
}

/// A vendor in any state whose name folds to the same text as [name], after a
/// best-effort, time-boxed server search so one outside the local cache counts.
Future<Vendor?> _findExactVendor(
  Services services,
  String companyId,
  String name,
) async {
  const allStates = {...EntityState.values};
  try {
    if (await services.connectivity.isOnline) {
      Future<void> search() async {
        for (var page = 1; page <= _kDuplicateSearchPages; page++) {
          final more = await services.vendors.ensurePageLoaded(
            companyId: companyId,
            page: page,
            search: name,
            states: allStates,
          );
          if (!more) break;
        }
      }

      // One budget for every page, not one per page.
      await search().timeout(kVendorDuplicateSearchTimeout);
    }
  } catch (_) {
    // Offline, slow, or a server hiccup — the local cache is all there is.
  }
  final rows = await services.vendors
      .watchPage(
        companyId: companyId,
        search: name,
        states: allStates,
        loadedPages: _kDuplicateScanPages,
      )
      .first;
  final want = foldSearchText(name);
  Vendor? inactive;
  for (final v in rows) {
    if (foldSearchText(v.name.trim()) != want) continue;
    // An active match wins over an archived namesake.
    if (v.archivedAt == null && !v.isDeleted) return v;
    inactive ??= v;
  }
  return inactive;
}

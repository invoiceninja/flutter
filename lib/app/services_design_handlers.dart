import 'package:logging/logging.dart';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/domain/sync/base_entity_sync_dispatcher.dart';
import 'package:admin/domain/sync/mutation.dart';

final _log = Logger('SetDefaultDesignHandlers');

/// The [MutationKind.setDefaultDesign] dispatcher — the Invoice Design
/// "Update all records" retro-apply at client/group scope. Spread into the
/// Client + GroupSetting dispatchers' `customActions` (company scope fires the
/// same `POST /designs/set/default` inline from `CompanySyncDispatcher`).
///
/// The endpoint lives on [CompaniesApi] but is scope-parameterised; the outbox
/// payload carries `settings_level` plus whichever scope id applies
/// (`client_id` / `group_settings_id`), so one closure serves both scopes.
/// Returns no entity to upsert — fire-and-forget, returns `null`.
Map<MutationKind, CustomMutationHandler<TInner>>
setDefaultDesignHandlers<TInner>(CompaniesApi companiesApi) {
  return {
    MutationKind.setDefaultDesign: ({required row, required payload}) async {
      // Permanent 4xx failures are best-effort: the retro-apply is a separate
      // row from the settings save (which already succeeded), and the server
      // 400s on a design id it doesn't yet know — letting that mark the row
      // dead would surface a misleading "sync failed". Transient failures
      // (offline NetworkException, 5xx, 429) MUST rethrow so the row backs
      // off and retries — swallowing them silently dropped an offline
      // "Update all records" retro-apply forever. (The company-scope path in
      // CompanySyncDispatcher still swallows everything: there the call
      // piggybacks on the settings row itself, right after its PUT succeeded
      // on the same connection, so a rethrow would misreport the settings
      // save.)
      try {
        await companiesApi.setDefaultDesign(
          designId: payload['design_id'] as String,
          entity: payload['entity'] as String,
          settingsLevel: payload['settings_level'] as String,
          clientId: payload['client_id'] as String?,
          groupSettingsId: payload['group_settings_id'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
      } catch (e) {
        if (isTransientError(e)) rethrow;
        _log.warning(
          'set/default failed (design=${payload['design_id']} '
          'entity=${payload['entity']} level=${payload['settings_level']}) — '
          'settings save unaffected, retro-apply skipped.',
          e,
        );
      }
      return null;
    },
  };
}

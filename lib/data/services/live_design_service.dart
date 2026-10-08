import 'dart:typed_data';

import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_exception.dart';

/// Wraps `POST /api/v1/live_design` — the server-side preview renderer
/// behind the Invoice Design page's Preview pane.
///
/// Response shape is raw PDF bytes (`content-type: application/pdf`), so we
/// route through [ApiClient.postRaw] (which validates the content-type to
/// guard against a misrouted JSON-error envelope being handed to a PDF
/// renderer).
///
/// The payload mirrors React's `pages/general-settings/components/
/// GeneralSettings.tsx` and admin-portal's `settings_model.dart:1080-1114`:
/// `entity_type` + a snapshot of the current settings + the scope identifiers
/// so previews at client / group scope render the cascade-merged result.
class LiveDesignService {
  LiveDesignService(this._apiClient);

  final ApiClient _apiClient;

  /// Render a single PDF preview for the current draft settings.
  ///
  /// - [entityType] one of `invoice` / `quote` / `credit` / `purchase_order`.
  /// - [settings] the **draft** settings (overlay applied) — pass
  ///   `host.settings`.
  /// - [settingsType] cascade level: `'company'` / `'group'` / `'client'`.
  /// - [groupId] required when [settingsType] = `'group'`.
  /// - [clientId] required when [settingsType] = `'client'`.
  /// - [entityId] when previewing a specific record; usually null for the
  ///   settings screen's generic preview.
  Future<Uint8List> renderPreview({
    required String entityType,
    required CompanySettings settings,
    String settingsType = 'company',
    String? groupId,
    String? clientId,
    String? entityId,
  }) {
    final payload = <String, dynamic>{
      'entity_type': entityType,
      'settings_type': settingsType,
      'settings': settings.toJson(),
      if (groupId != null) 'group_id': groupId,
      if (clientId != null) 'client_id': clientId,
      if (entityId != null) 'entity_id': entityId,
    };
    return _apiClient.postRaw(
      '/api/v1/live_design',
      body: payload,
      // Live preview is a read-equivalent operation — the server doesn't
      // persist anything. Allow it through demo mode so the demo account
      // can still preview design changes.
      readOnly: true,
    );
  }

  /// Render a PDF preview of an **in-progress design object** — distinct from
  /// [renderPreview], which previews company *settings*. Powers the Custom
  /// Design editor's live preview pane.
  ///
  /// Endpoint + payload were probed against the live server (2026-05-18):
  /// `POST /api/v1/preview?html=false` returns `application/pdf` for body
  /// `{ design: <Design.toApiJson()>, entity: <type>, entity_id: "-1" }`.
  /// `entity_id:"-1"` leaves the choice of document to the server (it picks
  /// one of the company's own, or fakes one); a real id — [entityId] — renders
  /// that record in the request's design, which is how the designer shows the
  /// same invoice on its page and in its preview (`docs/invoice-designer.md`).
  /// There is **no `settings_type`** here (that's a `/live_design` field).
  ///
  /// - [entityType] one of `invoice` / `quote` / `credit` / `purchase_order`.
  /// - [design] the in-progress draft (template + flags). Its `is_custom` /
  ///   `is_template` flags are sent as-is, so a built-in copy must already
  ///   carry `isCustom:true` / `isTemplate:false`.
  ///
  /// On invalid Twig/HTML the server replies 422; [ApiClient.postRaw] maps
  /// that to a [ValidationException] whose `fieldErrors` are keyed
  /// `design.design.<section>` — see [designSectionErrors] to project them
  /// back onto the editor's section tabs.
  Future<Uint8List> renderDesignPreview({
    required String entityType,
    required Design design,
    String? entityId,
  }) {
    // A brand-new design has an empty id; `toApiJson()` still emits the key
    // (`''` doesn't start with `tmp_`). The demo server tolerates `"id":""`,
    // but React / admin-portal omit it for new designs and a stricter server
    // build could reject it — drop an empty id so the payload is well-formed
    // for every server version. Real ids are preserved unchanged.
    final designJson = design.toApiJson();
    if ((designJson['id'] as String?)?.isEmpty ?? false) {
      designJson.remove('id');
    }
    return _apiClient.postRaw(
      '/api/v1/preview?html=false',
      body: <String, dynamic>{
        'design': designJson,
        'entity': entityType,
        // An id the server has never seen (an unsynced record) would 4xx.
        'entity_id':
            entityId == null || entityId.isEmpty || entityId.startsWith('tmp_')
            ? '-1'
            : entityId,
      },
      // Read-equivalent: the server renders but persists nothing. Demo-safe.
      readOnly: true,
    );
  }
}

/// Section keys a `/preview` 422 can carry, in editor-tab order. The server
/// keys validation errors as `design.design.<section>`.
const kDesignSections = <String>[
  'body',
  'header',
  'footer',
  'includes',
  'product',
  'task',
];

/// Projects a [ValidationException] from [LiveDesignService.renderDesignPreview]
/// onto `{ section: firstMessage }` so the editor can surface the Twig/HTML
/// error next to the offending section tab. A non-section-scoped or empty
/// error map yields `{}` (caller falls back to the generic message).
///
/// Only keys of the exact probed shape `design.design.<section>` are mapped.
/// Any other key shape (a future server build keying as `design.body`, or a
/// non-section error) is intentionally not projected — it still reaches the
/// user via the preview pane's generic error banner, just not pinned to a
/// section tab. Revisit this matcher if the server contract changes.
Map<String, String> designSectionErrors(ValidationException e) {
  final out = <String, String>{};
  for (final entry in e.fieldErrors.entries) {
    for (final section in kDesignSections) {
      if (entry.key == 'design.design.$section' && entry.value.isNotEmpty) {
        out[section] = entry.value.first;
      }
    }
  }
  return out;
}

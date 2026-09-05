import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';

/// Where to send the user when they ask to "open" or "view" a record of
/// [handlers]' type, by id.
///
/// **Not every registered entity is an addressable `<root>/<id>` route**, and
/// `handlers.routePath` alone does not tell you which. Two are settings
/// screens rather than record routes:
///
///   * `user` — registered as `/settings/account`, which is not a route at
///     all;
///   * `company` — registered as `/settings/company_details`, whose only
///     children are the tab slugs `address|logo|defaults|documents`.
///
/// Building `'${handlers.routePath}/$id/edit'` for either matches nothing, and
/// go_router's top-level `errorBuilder` then replaces the WHOLE app with the
/// route-error screen — outside the shell, sidebar gone. That is what a 422 on
/// Settings → Email Settings (a malformed reply-to address is enough) used to
/// do to anyone who tapped **View** on the failure toast.
///
/// The Outbox screen has always special-cased this; the sync-failure toasts did
/// not. Both go through here now so the two can't drift apart again.
///
/// The same three types are listed as `kNonRecordRouteEntityTypes` in
/// `lib/app/entity_links.dart` (not imported here, so this is a plain
/// reference), which deep-link building and parsing filter on.
/// Deliberately not shared in one direction or the other: that set answers
/// "can a record of this type be addressed by id at all" (no — so refuse the
/// link), while this switch answers "where do we send the user instead" (a
/// settings screen). Keep them in step — `entity_links_test.dart` asserts the
/// set covers every registered `routePath` that isn't a record route.
String entityDestination({
  required EntityHandlers handlers,
  required String entityId,
  bool edit = false,
}) {
  switch (handlers.type) {
    // Editing "the user" means the signed-in user's own settings screen.
    case EntityType.user:
      return '/settings/user_details';
    // Company-level changes belong to Company Details, not a record route.
    case EntityType.company:
      return '/settings/company_details';
    // Custom designs are created / edited in a modal (`showDesignEditScreen`),
    // so `custom_designs` exists only as an Invoice Design tab slug.
    case EntityType.design:
      return '/settings/invoice_design/custom_designs';
    default:
      return '${handlers.routePath}/$entityId${edit ? '/edit' : ''}';
  }
}

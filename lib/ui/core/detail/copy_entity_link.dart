import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/entity_links.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Copy a shareable deep link to one record. The dispatch half of
/// [copyLinkActionItem] — every entity's `<Entity>Actions.dispatch` routes its
/// `copyLink` case here.
///
/// The toast is labelled `link` rather than the URL itself, so it reads
/// "Copied Link to the clipboard" instead of a URL chopped at 40 characters by
/// `ellipsizeForToast`.
Future<void> copyEntityLink(
  BuildContext context,
  EntityType type,
  String id,
) async {
  final services = context.read<Services>();
  final link = buildEntityDeepLink(
    handlers: services.entityRegistry[type],
    entityId: id,
    companyId: services.auth.session.value?.currentCompanyId ?? '',
  );
  // Nothing linkable (no active company, or a `tmp_` id that slipped past the
  // item's own gate). Say so — silently leaving the clipboard untouched, or
  // worse writing an empty string over what was there, is the one outcome a
  // share action must never have.
  if (link == null) {
    // No await has run yet, so `context` is necessarily still mounted.
    Notify.error(context, context.tr('an_error_occurred'));
    return;
  }
  await copyToClipboard(context, link, label: context.tr('link'));
}

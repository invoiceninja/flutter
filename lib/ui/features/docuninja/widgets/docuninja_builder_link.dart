import 'package:flutter/widgets.dart';

import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:admin/ui/core/utils/external_url.dart';

/// Opens React's field builder for [documentId] in the browser, on
/// [companyId] (`dnBuilderWebUri`). The builder runs there until it is
/// embedded in the app (docs/docuninja.md § The field builder opens in the
/// browser for now). Shows the standard toast when nothing opens.
Future<bool> openDocuNinjaBuilder(
  BuildContext context, {
  required String documentId,
  required String companyId,
}) => openExternalUrl(
  context,
  dnBuilderWebUri(documentId: documentId, companyId: companyId).toString(),
);

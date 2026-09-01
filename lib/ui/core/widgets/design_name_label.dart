import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/design.dart';

/// Resolves a design's name from the local Drift cache and renders it as a
/// `Text`. Falls back to the raw [designId] while the watch is unresolved and to
/// an em-dash when [designId] is empty.
///
/// The designs catalog — the 11 standard designs plus any custom ones — is
/// seeded up front by `DesignRepository.applyBundle` from the `/login` /
/// `/refresh` envelope, so there is no lazy per-id hydrate. Drift dedupes
/// identical watch queries, so N rows referencing the same design share one
/// subscription.
class DesignNameLabel extends StatelessWidget {
  const DesignNameLabel({
    super.key,
    required this.designId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String designId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (designId.isEmpty) {
      return Text(
        '—',
        style:
            style ?? TextStyle(fontSize: 13, height: 1.2, color: tokens.ink3),
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _text(context, designId);
    }
    return StreamBuilder<Design?>(
      initialData: services.designs.peek(companyId: companyId, id: designId),
      stream: services.designs.watch(companyId: companyId, id: designId),
      builder: (context, snapshot) {
        final design = snapshot.data;
        final name = design == null || design.name.isEmpty
            ? designId
            : design.name;
        return _text(context, name);
      },
    );
  }

  Widget _text(BuildContext context, String text) => Text(
    text,
    style:
        style ??
        TextStyle(fontSize: 13, height: 1.2, color: context.inTheme.ink),
    maxLines: maxLines,
    overflow: overflow,
  );
}

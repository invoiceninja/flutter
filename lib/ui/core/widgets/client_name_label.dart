import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// Resolves the client display name from the local Drift cache and
/// renders it as a `Text` (or a link when [link]). On a cache miss it triggers
/// a lazy per-id hydrate (`ClientRepository.ensureLoaded`) so the name
/// resolves even when the client isn't on the prefetched first page.
///
/// **Never renders the raw `clientId`.** A hashid is meaningless to the user in
/// every state — loading, deleted, or permission-denied — and it used to be
/// painted on every master-detail row click (the pane re-keys its subtree per
/// `:id`, so each click MOUNTS this label afresh), producing a
/// `Wpmbk5ezJn` → `Acme Corp` flash in the same style slot. Unresolved renders
/// the muted em-dash instead, matching the empty-id branch below and
/// `UserNameLabel` / `UserAvatar`, which reached the same conclusion first:
/// a blank frame beats a flash of raw hashed id. The id stays available to
/// screen readers and `debugDumpApp` via [Semantics].
///
/// The first frame after a remount is usually not blank at all —
/// `ClientRepository.peek` seeds it from what the list already resolved.
///
/// Drift dedupes identical watch queries (and the repo dedupes the
/// hydrate fetch), so N rows for the same client share one subscription
/// and one network call.
class ClientNameLabel extends StatefulWidget {
  const ClientNameLabel({
    super.key,
    required this.clientId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.link = false,
  });

  final String clientId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  /// When true the resolved name renders as a hover-underlined link to
  /// the client's full-screen view. Off by default so non-list usages
  /// (detail headers, pickers) stay plain text.
  final bool link;

  @override
  State<ClientNameLabel> createState() => _ClientNameLabelState();
}

class _ClientNameLabelState extends State<ClientNameLabel> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(ClientNameLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId) _ensure();
  }

  /// Lazily hydrate the referenced client into Drift if it isn't cached
  /// (paginated lists prefetch only page 1). No-op / deduped / negative-
  /// cached in the repo, so it's safe to fire unconditionally here.
  void _ensure() {
    final id = widget.clientId;
    if (id.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    services.clients.ensureLoaded(companyId: companyId, id: id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (widget.clientId.isEmpty) {
      return Text(
        '—',
        style: widget.style ?? TextStyle(fontSize: 13, color: tokens.ink3),
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _unresolved(context, tokens);
    }
    return StreamBuilder<Client?>(
      // First-frame seed. The detail pane re-keys per `:id`, so every row click
      // MOUNTS this label afresh and `StreamBuilder` would otherwise start at
      // `AsyncSnapshot.nothing()` and paint the raw hashid for a frame. The
      // datatable's own Client column resolved this client moments ago, so the
      // value is already in memory. Derived from the same two locals as
      // `stream:` below, so the seed and the stream cannot disagree.
      initialData: services.clients.peek(
        companyId: companyId,
        id: widget.clientId,
      ),
      stream: services.clients.watch(companyId: companyId, id: widget.clientId),
      builder: (context, snapshot) {
        final client = snapshot.data;
        if (client == null) return _unresolved(context, tokens);
        // Resolved but nameless is NOT unresolved. `Client.displayName` is
        // empty only when the client has no name of its own AND the server's
        // computed `display_name` was dropped as a minted placeholder
        // (`clientDisplayNameOf`, invoiceninja/flutter#116) — the record loaded
        // fine, so claiming it can't be resolved is a lie the user can't act
        // on. Same distinction `ClientListTile._displayName` makes.
        if (client.displayName.isEmpty) {
          return _text(context, context.tr('no_name_fallback'));
        }
        return _text(context, client.displayName);
      },
    );
  }

  /// Shown while the name is resolving AND when it never will (deleted client,
  /// no permission). Deliberately the same in both: the user can act on
  /// neither, and distinguishing them would just be a second thing that
  /// flickers. The id rides along in [Semantics] so it stays debuggable.
  Widget _unresolved(BuildContext context, InTheme tokens) => Semantics(
    label: widget.clientId,
    child: Text(
      '—',
      style: widget.style ?? TextStyle(fontSize: 13, color: tokens.ink3),
    ),
  );

  Widget _text(BuildContext context, String text) => linkOrText(
    link: widget.link,
    label: text,
    onTap: widget.link
        ? () => goEntityFullDetail(context, '/clients', widget.clientId)
        : null,
    style: widget.style,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// Resolves the vendor display name from the local Drift cache and
/// renders it as a `Text` (or a link when [link]). Falls back to the
/// raw `vendorId` while the watch is empty; on a cache miss it triggers
/// a lazy per-id hydrate (`VendorRepository.ensureLoaded`) so the name
/// resolves even when the vendor isn't on the prefetched first page.
///
/// Drift dedupes identical watch queries (and the repo dedupes the
/// hydrate fetch), so N rows for the same vendor share one subscription
/// and one network call.
class VendorNameLabel extends StatefulWidget {
  const VendorNameLabel({
    super.key,
    required this.vendorId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.link = false,
  });

  final String vendorId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  /// When true the resolved name renders as a link to the vendor's full-screen
  /// view — hover-underlined on a pointer platform, underlined and recoloured
  /// **at rest** on touch, where hover can never fire.
  ///
  /// Set it where the slot is **labelled** (a wide-table column under a
  /// `Vendor` header) or where nothing else on the surface takes a tap (a
  /// detail header). Off by default, and it must stay off in a **narrow list
  /// row**: the row owns the tap there, and this widget's `LinkText` is
  /// `HitTestBehavior.opaque`, so it would steal every tap that landed on the
  /// name — invoiceninja/flutter#128, pinned by
  /// `test/lint/no_list_tile_name_link_test.dart`.
  final bool link;

  @override
  State<VendorNameLabel> createState() => _VendorNameLabelState();
}

class _VendorNameLabelState extends State<VendorNameLabel> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(VendorNameLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vendorId != widget.vendorId) _ensure();
  }

  /// Lazily hydrate the referenced vendor into Drift if it isn't cached
  /// (paginated lists prefetch only page 1). No-op / deduped / negative-
  /// cached in the repo, so it's safe to fire unconditionally here.
  void _ensure() {
    final id = widget.vendorId;
    if (id.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    services.vendors.ensureLoaded(companyId: companyId, id: id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (widget.vendorId.isEmpty) {
      return Text(
        '—',
        style: widget.style ?? TextStyle(fontSize: 13, color: tokens.ink3),
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _text(context, widget.vendorId);
    }
    return StreamBuilder<Vendor?>(
      initialData: services.vendors.peek(
        companyId: companyId,
        id: widget.vendorId,
      ),
      stream: services.vendors.watch(companyId: companyId, id: widget.vendorId),
      builder: (context, snapshot) {
        final vendor = snapshot.data;
        final name = vendor == null || vendor.name.isEmpty
            ? widget.vendorId
            : vendor.name;
        return _text(context, name);
      },
    );
  }

  Widget _text(BuildContext context, String text) => linkOrText(
    context: context,
    link: widget.link,
    label: text,
    onTap: widget.link
        ? () => goEntityFullDetail(context, '/vendors', widget.vendorId)
        : null,
    style: widget.style,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
  );
}

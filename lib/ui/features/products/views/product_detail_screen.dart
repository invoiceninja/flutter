import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/products/view_models/product_detail_view_model.dart';
import 'package:admin/ui/features/products/widgets/detail/product_detail_header.dart';
import 'package:admin/ui/features/products/widgets/detail/product_detail_profile.dart';
import 'package:admin/ui/features/products/widgets/detail/product_detail_standing.dart';
import 'package:admin/ui/features/products/widgets/product_actions.dart';
import 'package:admin/utils/formatting.dart';

/// The product record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions, standing and
/// the profile above a pinned tab strip.
///
/// Everything that used to sit under an Overview tab is above the strip now,
/// which leaves the strip with one tab: Documents. It stays a strip — pinned
/// and counted like every other record's — rather than becoming a card of its
/// own, so the files are found in the same place on every screen.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with FormatterHostMixin {
  late final ProductDetailViewModel _vm;
  late final RecordScreenController _record;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ProductDetailViewModel.bound(
      _services.products.watch(companyId: _companyId, id: widget.id),
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'product',
      refreshRecord: (id) =>
          _services.products.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(Product p, ProductAction action) =>
      ProductActions.dispatch(context, _services, _companyId, p, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Product>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.products.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.product),
      emptyIcon: Icons.inventory_2_outlined,
      emptyTitle: context.tr('product_not_found'),
      // `p` is captured at item-tap time — a late-arriving stream update
      // can't change which product gets archived mid-action.
      actionsForItem: (context, p) => EntityDetailActionsRow<ProductAction>(
        items: ProductActions.itemsFor(context, p, (a) => _dispatch(p, a)),
      ),
      compactTitleForItem: (context, p) =>
          _CompactTitle(product: p, formatter: formatter),
      // A deleted product is read-only until restored.
      isReadOnly: (p) => p.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, p) => recordStateBanner<ProductAction>(
        context,
        items: ProductActions.itemsFor(context, p, (a) => _dispatch(p, a)),
        restoreKind: ProductAction.restore,
        entityId: p.id,
        isDeleted: p.isDeleted,
        archivedAt: p.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, p) => _body(context, p),
    );
  }

  Widget _body(BuildContext context, Product p) {
    _record.attach(recordId: p.id, revision: p.updatedAt);
    // The tabs own the `TabController`, so they wrap the page and hand back
    // the strip and the body for it to place — which is what keeps the strip
    // pinned while the page scrolls under it.
    return EntityDetailTabs(
      selectTab: _record.selectTab,
      onReveal: _record.page.revealTabs,
      layoutBuilder: (context, strip, body) =>
          _record.buildPage(strip: strip, body: body, top: _top(context, p)),
      tabs: [
        buildStandardDocumentsTab(
          context: context,
          companyId: _companyId,
          entityId: p.id,
          documents: p.documents,
          repo: _services.products,
          formatter: formatter,
          // A deleted product keeps its files readable and takes no more.
          readOnly: p.isDeleted,
        ),
      ],
    );
  }

  /// Everything above the tabs.
  ///
  /// One company watch, hoisted here, feeds both cards that need it: the
  /// standing card (is inventory tracked, and at what threshold is stock
  /// low) and the profile (custom-field labels decide which Details rows
  /// exist).
  Widget _top(BuildContext context, Product p) {
    return WatchBuilder<Company?>(
      cacheKey: _companyId,
      // Seeded, so a record opened from a list has its company in the frame
      // it mounts rather than one frame later.
      initialData: _services.company.peek(
        companyId: _companyId,
        id: _companyId,
      ),
      create: () => _services.company.watchCompany(_companyId),
      builder: (context, company) => EntityRecordColumn(
        header: ProductDetailHeader(
          product: p,
          formatter: formatter,
          // The banner above the page already says Deleted / Archived.
          showStatePills: !p.isDeleted && p.archivedAt == null,
        ),
        quickActions: EntityQuickActions<ProductAction>(
          priority: ProductActions.quickItemsFor(
            context,
            p,
            (a) => _dispatch(p, a),
          ),
        ),
        standing: ProductDetailStanding(
          product: p,
          company: company.data,
          formatter: formatter,
        ),
        profile: ProductDetailProfile(
          product: p,
          company: company.data,
          formatter: formatter,
        ),
      ),
    );
  }
}

/// The product's key and price, for the fixed bar once the header has
/// scrolled away.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.product, required this.formatter});

  final Product product;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // The header's own fallback, so this is never a blank line.
          product.productKey.isEmpty
              ? context.tr('no_name_fallback')
              : product.productKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          formatter?.money(product.price) ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: tokens.ink2)
              .merge(moneyTextStyle()),
        ),
      ],
    );
  }
}

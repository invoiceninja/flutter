import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/data/db/app_database.dart' show OutboxRow;
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/ui/features/clients/views/client_detail_screen.dart';
import 'package:admin/ui/features/clients/views/client_edit_screen.dart';
import 'package:admin/ui/features/clients/views/client_list_screen.dart';
import 'package:admin/ui/features/clients/views/client_statement_screen.dart';
import 'package:admin/ui/features/expense_categories/views/expense_category_detail_screen.dart';
import 'package:admin/ui/features/expense_categories/views/expense_category_edit_screen.dart';
import 'package:admin/ui/features/expense_categories/views/expense_category_list_screen.dart';
import 'package:admin/ui/features/expenses/views/expense_detail_screen.dart';
import 'package:admin/ui/features/expenses/views/expense_edit_screen.dart';
import 'package:admin/ui/features/expenses/views/expense_list_screen.dart';
import 'package:admin/ui/features/gateways/views/company_gateway_detail_screen.dart';
import 'package:admin/ui/features/gateways/views/company_gateway_edit_screen.dart';
import 'package:admin/ui/features/gateways/views/company_gateway_list_screen.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/ui/features/invoices/views/invoice_detail_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_edit_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_list_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_pdf_route_screen.dart';
import 'package:admin/ui/features/quotes/views/quote_detail_screen.dart';
import 'package:admin/ui/features/quotes/views/quote_edit_screen.dart';
import 'package:admin/ui/features/quotes/views/quote_list_screen.dart';
import 'package:admin/ui/features/quotes/views/quote_pdf_route_screen.dart';
import 'package:admin/ui/features/credits/views/credit_detail_screen.dart';
import 'package:admin/ui/features/credits/views/credit_edit_screen.dart';
import 'package:admin/ui/features/credits/views/credit_list_screen.dart';
import 'package:admin/ui/features/credits/views/credit_pdf_route_screen.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_detail_screen.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_edit_screen.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_list_screen.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_pdf_route_screen.dart';
import 'package:admin/ui/features/recurring_invoices/views/recurring_invoice_detail_screen.dart';
import 'package:admin/ui/features/recurring_invoices/views/recurring_invoice_edit_screen.dart';
import 'package:admin/ui/features/recurring_invoices/views/recurring_invoice_list_screen.dart';
import 'package:admin/ui/features/recurring_invoices/views/recurring_invoice_pdf_route_screen.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_route_screen.dart';
import 'package:admin/ui/features/products/views/product_detail_screen.dart';
import 'package:admin/ui/features/products/views/product_edit_screen.dart';
import 'package:admin/ui/features/products/views/product_list_screen.dart';
import 'package:admin/ui/features/projects/views/project_detail_screen.dart';
import 'package:admin/ui/features/projects/views/project_edit_screen.dart';
import 'package:admin/ui/features/projects/views/project_list_screen.dart';
import 'package:admin/ui/features/recurring_expenses/views/recurring_expense_detail_screen.dart';
import 'package:admin/ui/features/recurring_expenses/views/recurring_expense_edit_screen.dart';
import 'package:admin/ui/features/recurring_expenses/views/recurring_expense_list_screen.dart';
import 'package:admin/ui/features/payments/views/payment_detail_screen.dart';
import 'package:admin/ui/features/payments/views/payment_edit_screen.dart';
import 'package:admin/ui/features/payments/views/payment_list_screen.dart';
import 'package:admin/ui/features/payments/views/payment_refund_screen.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_detail_screen.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_edit_screen.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_list_screen.dart';
import 'package:admin/ui/features/tasks/views/task_detail_screen.dart';
import 'package:admin/ui/features/tasks/views/task_edit_screen.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';
import 'package:admin/ui/features/transactions/views/transaction_detail_screen.dart';
import 'package:admin/ui/features/transactions/views/transaction_edit_screen.dart';
import 'package:admin/ui/features/transactions/views/transaction_list_screen.dart';
import 'package:admin/ui/features/vendors/views/vendor_detail_screen.dart';
import 'package:admin/ui/features/vendors/views/vendor_edit_screen.dart';
import 'package:admin/ui/features/vendors/views/vendor_list_screen.dart';

/// Static UI module description for one entity. Carries everything the
/// router and sidebar need to render an entity module + the metadata used
/// when wiring its [EntityHandlers] in DI.
///
/// Separated from [EntityHandlers] because module specs are compile-time
/// constants (screen builders, icons, route paths) while the dispatcher
/// is constructed at runtime against the live db + api client.
class EntityModuleSpec {
  const EntityModuleSpec({
    required this.type,
    required this.wireName,
    required this.apiPath,
    required this.routePath,
    required this.icon,
    required this.outlinedIcon,
    required this.labelKey,
    required this.sidebarOrder,
    this.sidebarSection = SidebarSection.top,
    this.disabled = false,
    this.requiresPasswordFor = const {},
    this.listBuilder,
    this.createBuilder,
    this.detailBuilder,
    this.editBuilder,
    this.extraChildRoutes = const [],
    this.badgeStream,
    this.badgeModes = kDefaultBadgeModes,
  });

  final EntityType type;
  final String wireName;
  final String apiPath;
  final String routePath;
  final IconData icon;
  final IconData outlinedIcon;
  final String labelKey;
  final int sidebarOrder;

  /// Which section of the main workspace sidebar this entity renders in.
  /// Defaults to [SidebarSection.top]; pass [SidebarSection.none] for
  /// entities that are routable + sync-wired but shouldn't surface in the
  /// workspace nav (e.g. CompanyGateway, which is reachable only via the
  /// Settings sidebar).
  final SidebarSection sidebarSection;

  final bool disabled;
  final Set<MutationKind> requiresPasswordFor;
  final GoRouterWidgetBuilder? listBuilder;
  final GoRouterWidgetBuilder? createBuilder;
  final GoRouterWidgetBuilder? detailBuilder;
  final GoRouterWidgetBuilder? editBuilder;
  final List<RouteBase> extraChildRoutes;
  final SidebarBadgeStream? badgeStream;

  /// What the sidebar badge is allowed to count for this entity — the user
  /// picks one from Settings → Device Settings, or by right-clicking the row.
  /// Defaults to [kDefaultBadgeModes] (total / hide); every sidebar entity
  /// passes its own list from `lib/domain/sidebar_badge_modes.dart`.
  final List<SidebarBadgeMode> badgeModes;

  /// Convert this spec into an [EntityHandlers]. The caller supplies the
  /// [dispatcher] (which depends on runtime DI state) and we copy the
  /// static fields across.
  EntityHandlers toHandlers(SyncDispatcher dispatcher) => EntityHandlers(
    type: type,
    wireName: wireName,
    apiPath: apiPath,
    routePath: routePath,
    icon: icon,
    outlinedIcon: outlinedIcon,
    labelKey: labelKey,
    sidebarSection: sidebarSection,
    sidebarOrder: sidebarOrder,
    disabled: disabled,
    requiresPasswordFor: requiresPasswordFor,
    dispatcher: dispatcher,
    listBuilder: listBuilder,
    createBuilder: createBuilder,
    detailBuilder: detailBuilder,
    editBuilder: editBuilder,
    extraChildRoutes: extraChildRoutes,
    badgeStream: badgeStream,
    badgeModes: badgeModes,
  );
}

/// Wired entity modules: every entity that has list/detail/edit screens
/// today. Adding a new entity = adding one entry here + its per-entity
/// files + one DI block in `services.dart`. The router and sidebar both
/// iterate this list (via [EntityRegistry]) — they need no per-entity
/// touch.
final kWiredEntityModules = <EntityModuleSpec>[
  // DI: wireEntity<ClientItemApi, ClientApi>(...) in lib/app/services.dart.
  EntityModuleSpec(
    type: EntityType.client,
    wireName: 'client',
    apiPath: '/api/v1/clients',
    routePath: '/clients',
    icon: Icons.people,
    outlinedIcon: Icons.people_outline,
    labelKey: 'clients',
    sidebarOrder: 10,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
    listBuilder: (context, state) => const ClientListScreen(),
    // Create-mode seed comes from `Services.takeCreateDraft('/clients')`.
    createBuilder: (context, state) => const ClientEditScreen(),
    detailBuilder: (context, state) =>
        ClientDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        ClientEditScreen(existingId: state.pathParameters['id']),
    extraChildRoutes: [
      GoRoute(
        path: 'statement',
        builder: (context, state) =>
            ClientStatementScreen(clientId: state.pathParameters['id']!),
      ),
      // M2 cross-entity nav (invoices, tasks, payments) lands here.
    ],
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.client, companyId, modeId: modeId),
    badgeModes: kClientBadgeModes,
  ),
  // DI: wireEntity<ProductItemApi, ProductApi>(...) in lib/app/services.dart.
  EntityModuleSpec(
    type: EntityType.product,
    wireName: 'product',
    apiPath: '/api/v1/products',
    routePath: '/products',
    icon: Icons.inventory_2,
    outlinedIcon: Icons.inventory_2_outlined,
    labelKey: 'products',
    sidebarOrder: 20,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
    listBuilder: (context, state) => const ProductListScreen(),
    createBuilder: (context, state) => ProductEditScreen(
      cloneFrom: state.extra is Product ? state.extra as Product : null,
    ),
    detailBuilder: (context, state) =>
        ProductDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        ProductEditScreen(existingId: state.pathParameters['id']),
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.product, companyId, modeId: modeId),
    badgeModes: kProductBadgeModes,
  ),
  EntityModuleSpec(
    type: EntityType.task,
    wireName: 'task',
    apiPath: '/api/v1/tasks',
    routePath: '/tasks',
    icon: Icons.task,
    outlinedIcon: Icons.task_outlined,
    labelKey: 'tasks',
    sidebarOrder: 90,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
    listBuilder: (context, state) {
      final clientId = state.uri.queryParameters['client_id'];
      // `?view=` selects the body (list / daily / weekly / calendar / kanban);
      // `?date=YYYY-MM-DD` seeds the focused day for the time-oriented views.
      // Read here (not in the screen) so deep links open in the right view
      // from the first frame.
      final view = switch (state.uri.queryParameters['view']) {
        'kanban' => TasksViewMode.kanban,
        'daily' => TasksViewMode.daily,
        'weekly' => TasksViewMode.weekly,
        'calendar' => TasksViewMode.calendar,
        _ => TasksViewMode.list,
      };
      return TaskListScreen(
        view: view,
        focusDate: Date.tryParse(state.uri.queryParameters['date']),
        clientId: clientId == null || clientId.isEmpty ? null : clientId,
      );
    },
    // Create-mode seed comes from `Services.takeCreateDraft('/tasks')`.
    createBuilder: (context, state) => const TaskEditScreen(),
    detailBuilder: (context, state) =>
        TaskDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        TaskEditScreen(existingId: state.pathParameters['id']),
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.task, companyId, modeId: modeId),
    badgeModes: kTaskBadgeModes,
  ),
  // DI: wireEntity<CompanyGatewayItemApi, CompanyGatewayApi>(...) in lib/app/services.dart.
  EntityModuleSpec(
    type: EntityType.companyGateway,
    wireName: 'company_gateway',
    apiPath: '/api/v1/company_gateways',
    routePath: '/settings/company_gateways',
    icon: Icons.account_balance_wallet,
    outlinedIcon: Icons.account_balance_wallet_outlined,
    labelKey: 'company_gateways',
    // Settings-only entity — reached via the Settings sidebar / the
    // Online Payments "Configure Gateways" button. Keeping it out of the
    // main workspace sidebar matches the legacy admin-portal + React.
    sidebarSection: SidebarSection.none,
    sidebarOrder: 200,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
    listBuilder: (context, state) => const CompanyGatewayListScreen(),
    createBuilder: (context, state) => CompanyGatewayEditScreen(
      initialGatewayKey: state.uri.queryParameters['gateway'],
    ),
    detailBuilder: (context, state) =>
        CompanyGatewayDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        CompanyGatewayEditScreen(existingId: state.pathParameters['id']),
  ),
  // DI: wireEntity<GroupSettingItemApi, GroupSettingApi>(...) in lib/app/services.dart.
  // Settings-only — reached via Settings → Advanced → Group Settings; the
  // settings router owns the actual route tree (see settings_routes.dart).
  EntityModuleSpec(
    type: EntityType.group,
    wireName: 'group',
    apiPath: '/api/v1/group_settings',
    routePath: '/settings/group_settings',
    icon: Icons.group_work_outlined,
    outlinedIcon: Icons.group_work_outlined,
    labelKey: 'group_settings',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 210,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.documentDelete,
    },
  ),
  // DI: wireEntity<TaskStatusItemApi, TaskStatusApi>(...) in lib/app/services.dart.
  EntityModuleSpec(
    type: EntityType.taskStatus,
    wireName: 'task_status',
    apiPath: '/api/v1/task_statuses',
    routePath: '/settings/task_statuses',
    icon: Icons.label_outline,
    outlinedIcon: Icons.label_outline,
    labelKey: 'task_statuses',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 220,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
  ),
  // DI: wire<TagItemApi, TagApi>(...) in lib/app/services_entity_wiring.dart.
  // Not bundled / not sidebar-listed; loaded via TagRepository.refreshAll.
  EntityModuleSpec(
    type: EntityType.tag,
    wireName: 'tag',
    apiPath: '/api/v1/tags',
    routePath: '/settings/tags',
    icon: Icons.local_offer,
    outlinedIcon: Icons.local_offer_outlined,
    labelKey: 'tags',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 225,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
  ),
  // DI: wireEntity<PaymentTermItemApi, PaymentTermApi>(...) in lib/app/services.dart.
  EntityModuleSpec(
    type: EntityType.paymentTerm,
    wireName: 'payment_term',
    apiPath: '/api/v1/payment_terms',
    routePath: '/settings/payment_terms',
    icon: Icons.schedule_outlined,
    outlinedIcon: Icons.schedule_outlined,
    labelKey: 'payment_terms',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 230,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
  ),
  // DI: wire<ScheduleItemApi, ScheduleApi>(...) in services_entity_wiring.dart.
  // Bundled settings entity — no screen builders here; the list/edit
  // screens are reached through settings_routes.dart.
  EntityModuleSpec(
    type: EntityType.schedule,
    wireName: 'schedule',
    apiPath: '/api/v1/task_schedulers',
    routePath: '/settings/schedules',
    icon: Icons.schedule_outlined,
    outlinedIcon: Icons.schedule_outlined,
    labelKey: 'schedules',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 240,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
  ),
  // DI: wireEntity<ProjectItemApi, ProjectApi>(...) in lib/app/services.dart.
  EntityModuleSpec(
    type: EntityType.project,
    wireName: 'project',
    apiPath: '/api/v1/projects',
    routePath: '/projects',
    icon: Icons.work,
    outlinedIcon: Icons.work_outline,
    labelKey: 'projects',
    sidebarOrder: 80,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) {
      final clientId = state.uri.queryParameters['client_id'];
      return ProjectListScreen(
        clientId: clientId == null || clientId.isEmpty ? null : clientId,
      );
    },
    // Create-mode seed comes from `Services.takeCreateDraft('/projects')`.
    createBuilder: (context, state) => const ProjectEditScreen(),
    detailBuilder: (context, state) =>
        ProjectDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        ProjectEditScreen(existingId: state.pathParameters['id']),
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.project, companyId, modeId: modeId),
    badgeModes: kProjectBadgeModes,
  ),
  // DI: wire<VendorItemApi, VendorApi>(...) in lib/app/services_entity_wiring.dart.
  EntityModuleSpec(
    type: EntityType.vendor,
    wireName: 'vendor',
    apiPath: '/api/v1/vendors',
    routePath: '/vendors',
    icon: Icons.store,
    outlinedIcon: Icons.store_outlined,
    labelKey: 'vendors',
    sidebarOrder: 100,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) => const VendorListScreen(),
    createBuilder: (context, state) => VendorEditScreen(
      cloneFrom: state.extra is Vendor ? state.extra as Vendor : null,
    ),
    detailBuilder: (context, state) =>
        VendorDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        VendorEditScreen(existingId: state.pathParameters['id']),
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.vendor, companyId, modeId: modeId),
    badgeModes: kVendorBadgeModes,
  ),
  // DI: wire<PaymentItemApi, PaymentApi>(...) in lib/app/services_entity_wiring.dart.
  // Document-bearing, password-gated delete/purge/documentDelete. Two
  // payment-only custom actions ride the outbox: refundPayment and
  // applyPayment. The refund flow uses a dedicated sub-route at
  // `/payments/:id/refund`; apply lives inline on the detail screen.
  EntityModuleSpec(
    type: EntityType.payment,
    wireName: 'payment',
    apiPath: '/api/v1/payments',
    routePath: '/payments',
    icon: Icons.payments,
    outlinedIcon: Icons.payments_outlined,
    labelKey: 'payments',
    sidebarOrder: 50,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) {
      final clientId = state.uri.queryParameters['client_id'];
      return PaymentListScreen(
        clientId: clientId == null || clientId.isEmpty ? null : clientId,
      );
    },
    // Create-mode seed comes from `Services.takeCreateDraft('/payments')`.
    createBuilder: (context, state) => const PaymentEditScreen(),
    detailBuilder: (context, state) =>
        PaymentDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        PaymentEditScreen(existingId: state.pathParameters['id']),
    extraChildRoutes: [
      GoRoute(
        path: 'refund',
        builder: (context, state) =>
            PaymentRefundScreen(id: state.pathParameters['id']!),
      ),
    ],
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.payment, companyId, modeId: modeId),
    badgeModes: kPaymentBadgeModes,
  ),
  // DI: wire<ExpenseItemApi, ExpenseApi>(...) in lib/app/services_entity_wiring.dart.
  EntityModuleSpec(
    type: EntityType.expense,
    wireName: 'expense',
    apiPath: '/api/v1/expenses',
    routePath: '/expenses',
    icon: Icons.receipt_outlined,
    outlinedIcon: Icons.receipt_outlined,
    labelKey: 'expenses',
    sidebarOrder: 120,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) {
      final clientId = state.uri.queryParameters['client_id'];
      final vendorId = state.uri.queryParameters['vendor_id'];
      return ExpenseListScreen(
        clientId: clientId == null || clientId.isEmpty ? null : clientId,
        vendorId: vendorId == null || vendorId.isEmpty ? null : vendorId,
      );
    },
    // Create-mode seed comes from `Services.takeCreateDraft('/expenses')`.
    createBuilder: (context, state) => const ExpenseEditScreen(),
    detailBuilder: (context, state) =>
        ExpenseDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        ExpenseEditScreen(existingId: state.pathParameters['id']),
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.expense, companyId, modeId: modeId),
    badgeModes: kExpenseBadgeModes,
  ),
  // DI: wire<InvoiceItemApi, InvoiceApi>(...) in
  // lib/app/services_entity_wiring.dart. Document-bearing, with eleven
  // non-CRUD custom actions (markSent/markPaid/email/scheduleEmail/cloneTo*
  // /autoBill/cancel/runTemplate). M1 ships the read-only list + detail
  // header + stub edit; M2 adds PDF/email; M3 adds the full edit form
  // (Details / Contacts / Items / Notes / PDF / E-Invoice tabs); M4 adds
  // payment-schedule wizard + Verifactu + reminders.
  EntityModuleSpec(
    type: EntityType.invoice,
    wireName: 'invoice',
    apiPath: '/api/v1/invoices',
    routePath: '/invoices',
    icon: Icons.receipt_long,
    outlinedIcon: Icons.receipt_long_outlined,
    labelKey: 'invoices',
    sidebarOrder: 30,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) {
      final clientId = state.uri.queryParameters['client_id'];
      return InvoiceListScreen(
        clientId: clientId == null || clientId.isEmpty ? null : clientId,
      );
    },
    // Create-mode seed comes from `Services.takeCreateDraft('/invoices')`
    // (staged by the "New Invoice" sources), consumed in the screen's buildVm.
    createBuilder: (context, state) => const InvoiceEditScreen(),
    detailBuilder: (context, state) =>
        InvoiceDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) => InvoiceEditScreen(
      existingId: state.pathParameters['id'],
      // "Add to invoice" (task / expense) routes here with the chosen
      // invoice + appended line item as `extra` so the user reviews
      // before the normal update mutation. Normal edit navigation passes
      // no extra → behaves exactly as before.
      cloneFrom: state.extra is Invoice ? state.extra as Invoice : null,
    ),
    extraChildRoutes: [
      GoRoute(
        path: 'pdf',
        // Full-screen server-rendered PDF preview with print/share/download
        // toolbar provided by the `printing` package. Reached from the
        // detail screen's "View PDF" action or directly via deep link.
        builder: (context, state) => InvoicePdfRouteScreen(
          id: state.pathParameters['id']!,
          initialDeliveryNote:
              state.uri.queryParameters['delivery_note'] == 'true',
        ),
      ),
      GoRoute(
        path: 'email',
        builder: (context, state) => BillingDocEmailRouteScreen(
          type: BillingDocType.invoice,
          id: state.pathParameters['id']!,
        ),
      ),
    ],
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.invoice, companyId, modeId: modeId),
    badgeModes: kInvoiceBadgeModes,
  ),
  // DI: wire<QuoteItemApi, QuoteApi>(...) in
  // lib/app/services_entity_wiring.dart. Mirrors Invoice but with quote-
  // specific custom actions (approve, convertToInvoice, convertToProject)
  // instead of mark_paid / auto_bill. Shares every billing_shared widget
  // (LineItemEditor, TotalsWidget, BillingDocPdfView, email sheet,
  // contacts section, markdown notes) verbatim.
  EntityModuleSpec(
    type: EntityType.quote,
    wireName: 'quote',
    apiPath: '/api/v1/quotes',
    routePath: '/quotes',
    icon: Icons.request_quote,
    outlinedIcon: Icons.request_quote_outlined,
    labelKey: 'quotes',
    sidebarOrder: 60,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) {
      final clientId = state.uri.queryParameters['client_id'];
      return QuoteListScreen(
        clientId: clientId == null || clientId.isEmpty ? null : clientId,
      );
    },
    // Create-mode seed comes from `Services.takeCreateDraft('/quotes')`,
    // consumed in the screen's buildVm.
    createBuilder: (context, state) => const QuoteEditScreen(),
    detailBuilder: (context, state) =>
        QuoteDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        QuoteEditScreen(existingId: state.pathParameters['id']),
    extraChildRoutes: [
      GoRoute(
        path: 'pdf',
        builder: (context, state) =>
            QuotePdfRouteScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'email',
        builder: (context, state) => BillingDocEmailRouteScreen(
          type: BillingDocType.quote,
          id: state.pathParameters['id']!,
        ),
      ),
    ],
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.quote, companyId, modeId: modeId),
    badgeModes: kQuoteBadgeModes,
  ),
  // DI: wire<CreditItemApi, CreditApi>(...) in
  // lib/app/services_entity_wiring.dart. Mirrors Quote — every
  // billing_shared widget (LineItemEditor, TotalsWidget, BillingDocPdfView,
  // email sheet, contacts section, markdown notes) is reused verbatim.
  // Credits have no convert-to-X actions and ship a 4-state lifecycle
  // (draft / sent / partial / applied).
  EntityModuleSpec(
    type: EntityType.credit,
    wireName: 'credit',
    apiPath: '/api/v1/credits',
    routePath: '/credits',
    icon: Icons.assignment_return,
    outlinedIcon: Icons.assignment_return_outlined,
    labelKey: 'credits',
    sidebarOrder: 70,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) {
      final clientId = state.uri.queryParameters['client_id'];
      return CreditListScreen(
        clientId: clientId == null || clientId.isEmpty ? null : clientId,
      );
    },
    // Create-mode seed comes from `Services.takeCreateDraft('/credits')`.
    createBuilder: (context, state) => const CreditEditScreen(),
    detailBuilder: (context, state) =>
        CreditDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        CreditEditScreen(existingId: state.pathParameters['id']),
    extraChildRoutes: [
      GoRoute(
        path: 'pdf',
        builder: (context, state) =>
            CreditPdfRouteScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'email',
        builder: (context, state) => BillingDocEmailRouteScreen(
          type: BillingDocType.credit,
          id: state.pathParameters['id']!,
        ),
      ),
    ],
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.credit, companyId, modeId: modeId),
    badgeModes: kCreditBadgeModes,
  ),
  // DI: wire<PurchaseOrderItemApi, PurchaseOrderApi>(...) in
  // lib/app/services_entity_wiring.dart. Vendor-centric mirror of Quote;
  // reuses every billing_shared widget (LineItemEditor, TotalsWidget,
  // BillingDocPdfView, email sheet, contacts section via VendorContact
  // .toBilling(), markdown notes). Owns two PO-specific actions: `accept`
  // and `convert_to_expense`.
  EntityModuleSpec(
    type: EntityType.purchaseOrder,
    wireName: 'purchase_order',
    apiPath: '/api/v1/purchase_orders',
    routePath: '/purchase_orders',
    icon: Icons.shopping_bag,
    outlinedIcon: Icons.shopping_bag_outlined,
    labelKey: 'purchase_orders',
    sidebarOrder: 110,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) {
      final vendorId = state.uri.queryParameters['vendor_id'];
      return PurchaseOrderListScreen(
        vendorId: vendorId == null || vendorId.isEmpty ? null : vendorId,
      );
    },
    // Create-mode seed comes from `Services.takeCreateDraft('/purchase_orders')`.
    createBuilder: (context, state) => const PurchaseOrderEditScreen(),
    detailBuilder: (context, state) =>
        PurchaseOrderDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        PurchaseOrderEditScreen(existingId: state.pathParameters['id']),
    extraChildRoutes: [
      GoRoute(
        path: 'pdf',
        builder: (context, state) =>
            PurchaseOrderPdfRouteScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'email',
        builder: (context, state) => BillingDocEmailRouteScreen(
          type: BillingDocType.purchaseOrder,
          id: state.pathParameters['id']!,
        ),
      ),
    ],
    badgeStream: (ctx, companyId, modeId) => ctx.watchEntityCount(
      EntityType.purchaseOrder,
      companyId,
      modeId: modeId,
    ),
    badgeModes: kPurchaseOrderBadgeModes,
  ),
  // DI: wire<RecurringInvoiceItemApi, RecurringInvoiceApi>(...) in
  // lib/app/services_entity_wiring.dart. Invoice-shaped template with
  // recurring lifecycle. Uses the shared `start` / `stop` MutationKinds
  // (added for RecurringExpense — reused here). The edit screen adds a
  // Schedule tab for frequency + next_send_date + remaining_cycles +
  // auto_bill on top of the standard billing-doc tab set.
  EntityModuleSpec(
    type: EntityType.recurringInvoice,
    wireName: 'recurring_invoice',
    apiPath: '/api/v1/recurring_invoices',
    routePath: '/recurring_invoices',
    icon: Icons.event_repeat,
    outlinedIcon: Icons.event_repeat_outlined,
    labelKey: 'recurring_invoices',
    sidebarOrder: 40,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) {
      final clientId = state.uri.queryParameters['client_id'];
      return RecurringInvoiceListScreen(
        clientId: clientId == null || clientId.isEmpty ? null : clientId,
      );
    },
    // Create-mode seed: `Services.takeCreateDraft('/recurring_invoices')`.
    createBuilder: (context, state) => const RecurringInvoiceEditScreen(),
    detailBuilder: (context, state) =>
        RecurringInvoiceDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        RecurringInvoiceEditScreen(existingId: state.pathParameters['id']),
    extraChildRoutes: [
      GoRoute(
        path: 'pdf',
        builder: (context, state) =>
            RecurringInvoicePdfRouteScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'email',
        builder: (context, state) => BillingDocEmailRouteScreen(
          type: BillingDocType.recurringInvoice,
          id: state.pathParameters['id']!,
        ),
      ),
    ],
    badgeStream: (ctx, companyId, modeId) => ctx.watchEntityCount(
      EntityType.recurringInvoice,
      companyId,
      modeId: modeId,
    ),
    badgeModes: kRecurringInvoiceBadgeModes,
  ),
  // DI: wire<RecurringExpenseItemApi, RecurringExpenseApi>(...) in
  // lib/app/services_entity_wiring.dart. `start` / `stop` flow through
  // dedicated MutationKind values; the dispatcher's customActions block
  // translates them to `?start=true` / `?stop=true` PUTs.
  EntityModuleSpec(
    type: EntityType.recurringExpense,
    wireName: 'recurring_expense',
    apiPath: '/api/v1/recurring_expenses',
    routePath: '/recurring_expenses',
    icon: Icons.event_repeat,
    outlinedIcon: Icons.event_repeat_outlined,
    labelKey: 'recurring_expenses',
    sidebarOrder: 130,
    requiresPasswordFor: const {
      MutationKind.delete,
      MutationKind.purge,
      MutationKind.documentDelete,
    },
    listBuilder: (context, state) {
      final vendorId = state.uri.queryParameters['vendor_id'];
      return RecurringExpenseListScreen(
        vendorId: vendorId == null || vendorId.isEmpty ? null : vendorId,
      );
    },
    createBuilder: (context, state) => RecurringExpenseEditScreen(
      cloneFrom: state.extra is RecurringExpense
          ? state.extra as RecurringExpense
          : null,
    ),
    detailBuilder: (context, state) =>
        RecurringExpenseDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        RecurringExpenseEditScreen(existingId: state.pathParameters['id']),
    badgeStream: (ctx, companyId, modeId) => ctx.watchEntityCount(
      EntityType.recurringExpense,
      companyId,
      modeId: modeId,
    ),
    badgeModes: kRecurringExpenseBadgeModes,
  ),
  // DI: wire<ExpenseCategoryItemApi, ExpenseCategoryApi>(...) in
  // lib/app/services_entity_wiring.dart. Settings-only entity reached via
  // Settings → Advanced. Bundled via the `/refresh` envelope alongside
  // task_statuses / payment_terms / tax_rates.
  EntityModuleSpec(
    type: EntityType.expenseCategory,
    wireName: 'expense_category',
    apiPath: '/api/v1/expense_categories',
    routePath: '/settings/expense_categories',
    icon: Icons.label_outlined,
    outlinedIcon: Icons.label_outlined,
    labelKey: 'expense_categories',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 250,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
    listBuilder: (context, state) => const ExpenseCategoryListScreen(),
    createBuilder: (context, state) => ExpenseCategoryEditScreen(
      cloneFrom: state.extra is ExpenseCategory
          ? state.extra as ExpenseCategory
          : null,
    ),
    detailBuilder: (context, state) =>
        ExpenseCategoryDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        ExpenseCategoryEditScreen(existingId: state.pathParameters['id']),
  ),
  // DI: wire<SubscriptionItemApi, SubscriptionApi>(...) in
  // lib/app/services_entity_wiring.dart. The HTTP wire stays as
  // `subscription` (URL: /api/v1/subscriptions, DTO: SubscriptionApi,
  // bundled envelope key: company.subscriptions). The local outbox
  // `entity_type` column + the entity registry's wireName are
  // `payment_link` — these never touch the server. Settings-only entity
  // reached via Settings → Advanced → Payment Links. Bundled via the
  // `/refresh` envelope alongside task_statuses / payment_terms /
  // tax_rates / expense_categories.
  EntityModuleSpec(
    type: EntityType.paymentLink,
    wireName: 'payment_link',
    apiPath: '/api/v1/subscriptions',
    routePath: '/settings/payment_links',
    icon: Icons.link_outlined,
    outlinedIcon: Icons.link_outlined,
    labelKey: 'payment_links',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 260,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
    listBuilder: (context, state) => const PaymentLinkListScreen(),
    createBuilder: (context, state) => PaymentLinkEditScreen(
      cloneFrom: state.extra is PaymentLink ? state.extra as PaymentLink : null,
    ),
    detailBuilder: (context, state) =>
        PaymentLinkDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        PaymentLinkEditScreen(existingId: state.pathParameters['id']),
  ),
  // DI: wire<BankAccountItemApi, BankAccountApi>(...) in
  // lib/app/services_entity_wiring.dart. Settings-only entity — reached
  // via Settings → Bank Accounts; the settings router owns the route
  // tree (see `settings_routes.dart`). No screen builders are wired
  // here so the spec stays compatible with the settings-router-driven
  // route (no duplicate registration).
  EntityModuleSpec(
    type: EntityType.bankAccount,
    wireName: 'bank_account',
    apiPath: '/api/v1/bank_integrations',
    routePath: '/settings/bank_accounts',
    icon: Icons.account_balance_outlined,
    outlinedIcon: Icons.account_balance_outlined,
    labelKey: 'bank_accounts',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 255,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
  ),
  // DI: wire<BankTransactionItemApi, BankTransactionApi>(...) in
  // lib/app/services_entity_wiring.dart. Top-level workspace entity at
  // `/transactions`. The four `match` variants + two bulk actions
  // (convert_matched, unlink) all drain through customActions on the
  // dispatcher; the UI dispatches them via row + bulk actions on
  // TransactionListScreen / TransactionDetailScreen.
  EntityModuleSpec(
    type: EntityType.transaction,
    wireName: 'bank_transaction',
    apiPath: '/api/v1/bank_transactions',
    routePath: '/transactions',
    icon: Icons.swap_horiz,
    outlinedIcon: Icons.swap_horiz_outlined,
    labelKey: 'transactions',
    sidebarOrder: 140,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
    listBuilder: (context, state) {
      // `/transactions?bank_account_id=<id>` from the bank-account
      // detail screen's "View all transactions" link arrives here —
      // read the query param so the standalone list lands scoped to
      // the right integration.
      final filter = state.uri.queryParameters['bank_account_id'];
      return TransactionListScreen(
        bankAccountId: filter == null || filter.isEmpty ? null : filter,
      );
    },
    createBuilder: (context, state) => const TransactionEditScreen(),
    detailBuilder: (context, state) =>
        TransactionDetailScreen(id: state.pathParameters['id']!),
    editBuilder: (context, state) =>
        TransactionEditScreen(existingId: state.pathParameters['id']),
    badgeStream: (ctx, companyId, modeId) =>
        ctx.watchEntityCount(EntityType.transaction, companyId, modeId: modeId),
    badgeModes: kTransactionBadgeModes,
  ),
  // DI: wire<TransactionRuleItemApi, TransactionRuleApi>(...) in
  // lib/app/services_entity_wiring.dart. Settings-only entity reached
  // via Settings → Bank Accounts → Rules. Settings router owns the
  // route tree.
  EntityModuleSpec(
    type: EntityType.transactionRule,
    wireName: 'transaction_rule',
    apiPath: '/api/v1/bank_transaction_rules',
    routePath: '/settings/bank_accounts/transaction_rules',
    icon: Icons.rule_outlined,
    outlinedIcon: Icons.rule_outlined,
    labelKey: 'transaction_rules',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 256,
    requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
  ),
  // DI: wire<WebhookItemApi, WebhookApi>(...) in services_entity_wiring.dart.
  // Settings-only entity reached via Settings → Integrations → API Webhooks.
  // Bundled on `/refresh?first_load=true` (small list — typically a handful
  // of rows per company).
  EntityModuleSpec(
    type: EntityType.webhook,
    wireName: 'webhook',
    apiPath: '/api/v1/webhooks',
    routePath: '/settings/account_management/integrations/api_webhooks',
    icon: Icons.webhook_outlined,
    outlinedIcon: Icons.webhook_outlined,
    labelKey: 'api_webhooks',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 257,
    // WebhookController applies no `password_protected` middleware (unlike
    // TokenController), so no webhook mutation is password-gated.
    requiresPasswordFor: const {},
  ),
  // DI: wire<TokenItemApi, TokenApi>(...) in services_entity_wiring.dart.
  // Settings-only entity reached via Settings → Integrations → API Tokens.
  // Bundled on `/refresh?first_load=true` via `tokens_hashed` (masked).
  EntityModuleSpec(
    type: EntityType.token,
    wireName: 'token',
    apiPath: '/api/v1/tokens',
    routePath: '/settings/account_management/integrations/api_tokens',
    icon: Icons.key_outlined,
    outlinedIcon: Icons.key_outlined,
    labelKey: 'api_tokens',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 258,
    // Server applies `password_protected` to token store/update/destroy
    // (TokenController), so create + update are gated up-front too — not just
    // delete/purge.
    requiresPasswordFor: const {
      MutationKind.create,
      MutationKind.update,
      MutationKind.delete,
      MutationKind.purge,
    },
  ),
];

/// Disabled placeholder entities — visible in the sidebar greyed-out with a
/// `coming_soon` tooltip so the legacy admin-portal nav surface stays
/// discoverable. Drop the `disabled: true` flag and supply screen builders
/// when each entity's module lands; nothing else in router/sidebar/DI
/// needs to change.
const kDisabledEntityModules = <EntityModuleSpec>[
  // Tax rates — modeled and persisted (via bundle) for the default-tax
  // pickers on Settings → Tax Settings. No CRUD screen yet; the spec sits
  // here so the entity registry knows the type without rendering sidebar
  // chrome. Promote to `kWiredEntityModules` when the list/edit screens land.
  EntityModuleSpec(
    type: EntityType.taxRate,
    wireName: 'tax_rate',
    apiPath: '/api/v1/tax_rates',
    routePath: '/settings/tax_rates',
    icon: Icons.percent_outlined,
    outlinedIcon: Icons.percent_outlined,
    labelKey: 'tax_rates',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 240,
    disabled: true,
    requiresPasswordFor: {MutationKind.delete, MutationKind.purge},
  ),
  // Designs — modeled and persisted (via bundle) for the Invoice Design
  // pickers and the upcoming Custom Designs CRUD list. Promote to
  // `kWiredEntityModules` when the list / edit screens land (the wiring
  // already lives in `services_entity_wiring.dart`).
  EntityModuleSpec(
    type: EntityType.design,
    wireName: 'design',
    apiPath: '/api/v1/designs',
    routePath: '/settings/invoice_design/custom_designs',
    icon: Icons.design_services_outlined,
    outlinedIcon: Icons.design_services_outlined,
    labelKey: 'custom_designs',
    sidebarSection: SidebarSection.none,
    sidebarOrder: 250,
    disabled: true,
    requiresPasswordFor: {MutationKind.delete, MutationKind.purge},
  ),
];

/// Router branch order. Indices stay stable across releases so persisted
/// navigation state (last-visited branch in `nav_state`) keeps working.
/// New branches **append**; never reorder the existing entries.
const kBranchOrder = <BranchSpec>[
  EntityBranch(EntityType.client), // 0
  FixedBranch(FixedBranchKind.dashboard), // 1
  EntityBranch(EntityType.product), // 2
  FixedBranch(FixedBranchKind.settings), // 3
  FixedBranch(FixedBranchKind.outbox), // 4
  EntityBranch(EntityType.task), // 5
  EntityBranch(EntityType.project), // 6
  EntityBranch(EntityType.companyGateway), // 7 — settings entity, sidebar
  //     entry under Advanced.
  EntityBranch(EntityType.vendor), // 8
  EntityBranch(EntityType.expense), // 9
  EntityBranch(EntityType.recurringExpense), // 10
  EntityBranch(EntityType.expenseCategory), // 11 — settings entity, no
  //     workspace sidebar entry. Reached via Settings → Advanced.
  // Tax Rate intentionally skipped — it's a disabled entity (no CRUD screen
  // today). Add an `EntityBranch(EntityType.taxRate)` here when the Tax
  // Rates settings page lands and the spec moves to `kWiredEntityModules`.
  EntityBranch(EntityType.paymentLink), // 12 — Payment Links settings
  //     entity, no workspace sidebar entry. Reached via Settings → Advanced.
  EntityBranch(EntityType.invoice), // 13
  EntityBranch(EntityType.quote), // 14
  EntityBranch(EntityType.credit), // 15
  EntityBranch(EntityType.purchaseOrder), // 16
  FixedBranch(FixedBranchKind.reports), // 17
  EntityBranch(EntityType.recurringInvoice), // 18
  EntityBranch(EntityType.transaction), // 19 — bank transactions list at
  //     `/transactions`. Settings-only entities (bankAccount,
  //     transactionRule) are reached via the Settings router, so they
  //     don't get a branch entry here.
  EntityBranch(EntityType.payment), // 20
  // Future enabled entities append here (21, 22, …) so existing branch
  // indices keep their meaning.
];

/// Dispatcher used for disabled-but-registered entities. Outbox rows for
/// these will never appear (no UI to enqueue them), but if one ever does
/// the throw surfaces as a "marked dead" entry on the outbox screen rather
/// than a silent no-op.
class DisabledEntityDispatcher implements SyncDispatcher {
  const DisabledEntityDispatcher(this.type);
  final EntityType type;
  @override
  Future<void> dispatch({required OutboxRow row, required MutationKind kind}) {
    throw UnimplementedError(
      'No sync dispatcher for $type — entity is registered as disabled. '
      'Drop EntityModuleSpec.disabled=true and supply a real dispatcher.',
    );
  }

  // Disabled entities have no UI to enqueue a create, so no ghost can
  // exist. See SyncDispatcher.deleteLocalRecord.
  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {}

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async {}
}

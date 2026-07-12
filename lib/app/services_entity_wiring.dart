import 'package:admin/app/services_document_handlers.dart';
import 'package:admin/app/services_email_handlers.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/bank_account_api_model.dart';
import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/api/recurring_invoice_api_model.dart';
import 'package:admin/data/models/api/expense_category_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/models/api/company_gateway_api_model.dart';
import 'package:admin/data/models/api/design_api_model.dart';
import 'package:admin/data/models/api/group_setting_api_model.dart';
import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/api/payment_term_api_model.dart';
import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/api/schedule_api_model.dart';
import 'package:admin/data/models/api/subscription_api_model.dart';
import 'package:admin/data/models/api/tag_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/api/task_status_api_model.dart';
import 'package:admin/data/models/api/tax_rate_api_model.dart';
import 'package:admin/data/models/api/token_api_model.dart';
import 'package:admin/data/models/api/transaction_rule_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/api/webhook_api_model.dart';
import 'package:admin/data/repositories/bank_account_repository.dart';
import 'package:admin/data/repositories/bank_transaction_repository.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/company_gateway_repository.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/group_setting_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/repositories/payment_term_repository.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/repositories/payment_link_repository.dart';
import 'package:admin/data/repositories/recurring_expense_repository.dart';
import 'package:admin/data/repositories/schedule_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/data/repositories/tax_rate_repository.dart';
import 'package:admin/data/repositories/token_repository.dart';
import 'package:admin/data/repositories/transaction_rule_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/repositories/webhook_repository.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/bank_accounts_api.dart';
import 'package:admin/data/services/bank_transactions_api.dart';
import 'package:admin/data/services/base_entity_api.dart';
import 'package:admin/app/services_design_handlers.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/data/services/company_gateways_api.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/data/services/emails_api.dart';
import 'package:admin/data/services/expense_categories_api.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/services/group_settings_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/locations_api.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/recurring_invoices_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/data/services/payment_terms_api.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/data/services/products_api.dart';
import 'package:admin/data/services/projects_api.dart';
import 'package:admin/data/services/recurring_expenses_api.dart';
import 'package:admin/data/services/schedules_api.dart';
import 'package:admin/data/services/subscriptions_api.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/data/services/task_statuses_api.dart';
import 'package:admin/data/services/tasks_api.dart';
import 'package:admin/data/services/tax_rates_api.dart';
import 'package:admin/data/services/tokens_api.dart';
import 'package:admin/data/services/transaction_rules_api.dart';
import 'package:admin/data/services/vendors_api.dart';
import 'package:admin/data/services/webhooks_api.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/base_entity_sync_dispatcher.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';

/// Shared services a per-entity wiring block reads from.
class EntityWiringContext {
  EntityWiringContext({
    required this.apiClient,
    required this.db,
    required this.activitiesApi,
    required this.documentsApi,
    required this.emailsApi,
    required this.kickDrain,
    required this.dispatchers,
  });

  final ApiClient apiClient;
  final AppDatabase db;
  final ActivitiesApi activitiesApi;
  final DocumentsApi documentsApi;
  final EmailsApi emailsApi;
  final void Function(String companyId) kickDrain;
  final Map<EntityType, SyncDispatcher> dispatchers;
}

/// Closure that mirrors a single bundled-entity upsert. Called once per
/// `/refresh` envelope from `auth.onPersistBundles`.
typedef BundleApplier =
    Future<void> Function({
      required String companyId,
      required CompanyEnvelopeApi company,
      required bool fullSync,
    });

/// The full set of per-entity APIs + repositories built by [wireEntities],
/// returned typed so [Services.build] can unpack them into its named
/// constructor params without going through a runtime cast bag.
class WiredEntities {
  WiredEntities({
    required this.clientsApi,
    required this.clients,
    required this.productsApi,
    required this.products,
    required this.tasksApi,
    required this.tasks,
    required this.projectsApi,
    required this.projects,
    required this.vendorsApi,
    required this.vendors,
    required this.expensesApi,
    required this.expenses,
    required this.recurringExpensesApi,
    required this.recurringExpenses,
    required this.expenseCategoriesApi,
    required this.expenseCategories,
    required this.companyGatewaysApi,
    required this.companyGateways,
    required this.paymentTermsApi,
    required this.paymentTerms,
    required this.taxRatesApi,
    required this.taxRates,
    required this.taskStatusesApi,
    required this.taskStatuses,
    required this.tagsApi,
    required this.tags,
    required this.designsApi,
    required this.designs,
    required this.groupSettingsApi,
    required this.groupSettings,
    required this.subscriptionsApi,
    required this.paymentLinks,
    required this.schedulesApi,
    required this.schedules,
    required this.invoicesApi,
    required this.invoices,
    required this.quotesApi,
    required this.quotes,
    required this.creditsApi,
    required this.credits,
    required this.purchaseOrdersApi,
    required this.purchaseOrders,
    required this.recurringInvoicesApi,
    required this.recurringInvoices,
    required this.bankAccountsApi,
    required this.bankAccounts,
    required this.bankTransactionsApi,
    required this.bankTransactions,
    required this.transactionRulesApi,
    required this.transactionRules,
    required this.paymentsApi,
    required this.payments,
    required this.webhooksApi,
    required this.webhooks,
    required this.tokensApi,
    required this.tokens,
    required this.bundleAppliers,
    required this.countWatchers,
    required this.firstPagePrefetchers,
  });

  final ClientsApi clientsApi;
  final ClientRepository clients;
  final ProductsApi productsApi;
  final ProductRepository products;
  final TasksApi tasksApi;
  final TaskRepository tasks;
  final ProjectsApi projectsApi;
  final ProjectRepository projects;
  final VendorsApi vendorsApi;
  final VendorRepository vendors;
  final ExpensesApi expensesApi;
  final ExpenseRepository expenses;
  final RecurringExpensesApi recurringExpensesApi;
  final RecurringExpenseRepository recurringExpenses;
  final ExpenseCategoriesApi expenseCategoriesApi;
  final ExpenseCategoryRepository expenseCategories;
  final CompanyGatewaysApi companyGatewaysApi;
  final CompanyGatewayRepository companyGateways;
  final PaymentTermsApi paymentTermsApi;
  final PaymentTermRepository paymentTerms;
  final TaxRatesApi taxRatesApi;
  final TaxRateRepository taxRates;
  final TaskStatusesApi taskStatusesApi;
  final TaskStatusRepository taskStatuses;
  final TagsApi tagsApi;
  final TagRepository tags;
  final DesignsApi designsApi;
  final DesignRepository designs;
  final GroupSettingsApi groupSettingsApi;
  final GroupSettingRepository groupSettings;
  final SubscriptionsApi subscriptionsApi;
  final PaymentLinkRepository paymentLinks;
  final SchedulesApi schedulesApi;
  final ScheduleRepository schedules;
  final InvoicesApi invoicesApi;
  final InvoiceRepository invoices;
  final QuotesApi quotesApi;
  final QuoteRepository quotes;
  final CreditsApi creditsApi;
  final CreditRepository credits;
  final PurchaseOrdersApi purchaseOrdersApi;
  final PurchaseOrderRepository purchaseOrders;
  final RecurringInvoicesApi recurringInvoicesApi;
  final RecurringInvoiceRepository recurringInvoices;
  final BankAccountsApi bankAccountsApi;
  final BankAccountRepository bankAccounts;
  final BankTransactionsApi bankTransactionsApi;
  final BankTransactionRepository bankTransactions;
  final TransactionRulesApi transactionRulesApi;
  final TransactionRuleRepository transactionRules;
  final PaymentsApi paymentsApi;
  final PaymentRepository payments;
  final WebhooksApi webhooksApi;
  final WebhookRepository webhooks;
  final TokensApi tokensApi;
  final TokenRepository tokens;

  /// Bundled-entity upsert callbacks. Iterate in `auth.onPersistBundles` —
  /// the order matches the order of construction here so a single `for` loop
  /// reproduces what the prior hand-written chain did.
  final List<BundleApplier> bundleAppliers;

  /// Live count streams per entity type, scoped by [companyId]. Backs the
  /// generic `SidebarBadgeContext.watchEntityCount(...)` accessor so each
  /// sidebar row can read its repo's `watchCount` without per-entity plumbing
  /// on `Services`. Populated only for entities with a workspace sidebar
  /// nav row (entries whose `EntityModuleSpec.sidebarSection != none`).
  final Map<EntityType, Stream<int> Function(String companyId)> countWatchers;

  /// First-page prefetch callbacks per entity type. Fired in parallel on
  /// every `auth.onActiveCompanyChanged` (login, refresh, switchCompany,
  /// restore) so sidebar count badges are live before the user opens the
  /// corresponding list screen. Each closure calls the repo's
  /// `ensurePageLoaded(page: 1)` with the default cursor behavior, so
  /// subsequent fires do a cheap delta rather than a full re-pull.
  final Map<EntityType, Future<bool> Function(String companyId)>
  firstPagePrefetchers;
}

/// Builds every CRUD-list entity wired into the sync engine. Lifts the
/// previous ~260 LOC of per-entity api+repo+wireEntity blocks out of
/// `Services.build` so adding the next document-bearing entity
/// (expense / vendor / invoice) only touches this file (one block) plus
/// `kWiredEntityModules` (one spec) — not `services.dart` directly.
///
/// `customActions` factories live next to each entity below; sharable trios
/// (documents) flow through [documentMutationHandlers].
WiredEntities wireEntities(EntityWiringContext ctx) {
  // Registry of every wired repo by type, so the cross-entity refresher
  // (`refreshRelatedEntities`) can reach any sibling repo generically via
  // `repos[type]?.refreshByIds(...)`.
  final repos = <EntityType, BaseEntityRepository<dynamic, dynamic>>{};
  // Local closure that mirrors the original `wireEntity<TItem, TInner>(...)`
  // in services.dart — generic functions can't be passed as values, so we
  // re-declare the helper here with access to `ctx.dispatchers`.
  void wire<TItem, TInner>({
    required EntityType type,
    required BaseEntityApi<dynamic, TItem> api,
    required BaseEntityRepository<dynamic, TInner> repo,
    Map<MutationKind, CustomMutationHandler<TInner>>? customActions,
  }) {
    ctx.dispatchers[type] = BaseEntitySyncDispatcher<TItem, TInner>(
      api: api,
      repo: repo,
      dataOf: (i) => (i as dynamic).data as TInner,
      customActions: customActions,
    );
    repos[type] = repo;
  }

  // Shared cross-entity side-effect refresh (issue #7 + the stale-sibling sweep):
  // after a mutation whose server side-effects touch OTHER entities, force-refetch
  // them by type so the local rows converge without a manual full resync. Injected
  // as `onRelatedEntitiesAffected` into every culprit repo. Runs inside the outbox
  // drain; `refreshByIds` swallows per-id errors, so this never fails the mutation.
  // Invoices cascade to their clients (a bank-transaction match knows the invoice,
  // not the client); all other types dispatch through `repos`. Defined here (before
  // the repos it reaches) closing over the `repos` map, which is fully populated by
  // the time any mutation fires.
  Future<void> refreshRelatedEntities(
    String companyId,
    Map<EntityType, Set<String>> byType,
  ) async {
    final clientIds = <String>{...?byType[EntityType.client]};
    final invoiceIds = byType[EntityType.invoice];
    if (invoiceIds != null && invoiceIds.isNotEmpty) {
      // Cast to reach the Set-returning override (base `refreshByIds` is void).
      final invoiceRepo = repos[EntityType.invoice] as InvoiceRepository?;
      if (invoiceRepo != null) {
        clientIds.addAll(
          await invoiceRepo.refreshByIds(companyId: companyId, ids: invoiceIds),
        );
      }
    }
    for (final entry in byType.entries) {
      if (entry.key == EntityType.invoice || entry.key == EntityType.client) {
        continue; // invoice handled above; client handled below (cascade).
      }
      if (entry.value.isEmpty) continue;
      await repos[entry.key]?.refreshByIds(
        companyId: companyId,
        ids: entry.value,
      );
    }
    if (clientIds.isNotEmpty) {
      await repos[EntityType.client]?.refreshByIds(
        companyId: companyId,
        ids: clientIds,
      );
    }
  }

  // markPaid / autoBill (invoice + credit) record a synthetic Payment the
  // invoice/credit response doesn't carry (unknown id). Force-refetch the newest
  // payments page (the new row is today-dated → on page 1) so it lands locally
  // without a manual resync. `ignoreCursor` bypasses the page-1 short-circuit.
  // Runs inside the drain; errors swallowed.
  Future<void> refreshRecentPayments(String companyId) async {
    try {
      await (repos[EntityType.payment] as PaymentRepository?)?.ensurePageLoaded(
        companyId: companyId,
        page: 1,
        ignoreCursor: true,
      );
    } catch (_) {
      // Self-heals on the next resync; never fail the mutation.
    }
  }

  // cloneTo* creates a NEW entity of the target type (cross-type: cloning an
  // invoice→quote yields a Quote). The handlers return null (the clone isn't
  // applied to the source row), so force-refetch the new entity by id — the
  // clone endpoint returns its envelope, so `.data.id` is the new id. Errors
  // swallowed; the clone's detail also self-heals via the edit-screen fetch.
  Future<void> refreshCloneTarget(
    String companyId,
    String? newId,
    EntityType targetType,
  ) async {
    if (newId == null || newId.isEmpty) return;
    try {
      await refreshRelatedEntities(companyId, {
        targetType: {newId},
      });
    } catch (_) {
      // Self-heals on the next resync; never fail the mutation.
    }
  }

  // ---- Client --------------------------------------------------------------
  // Shared across the Client + GroupSetting `setDefaultDesign` handlers (the
  // client/group-scope "Update all records" design retro-apply). The endpoint
  // lives on CompaniesApi but is scope-parameterised, so one stateless
  // instance serves both dispatchers.
  final companiesApi = CompaniesApi(ctx.apiClient);
  final clientsApi = ClientsApi(ctx.apiClient);
  final locationsApi = LocationsApi(ctx.apiClient);
  final clientRepo = ClientRepository(
    db: ctx.db,
    api: clientsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<ClientItemApi, ClientApi>(
    type: EntityType.client,
    api: clientsApi,
    repo: clientRepo,
    // `customActions` is the canonical hook for non-CRUD entity actions
    // (Invoice's `markPaid`, Task's `start/stop`, etc.). Each entry adds a
    // `MutationKind` value the repository can `enqueueMutation(...)`, plus
    // a one-line dispatch closure invoked when the outbox row drains. See
    // CLAUDE.md § "Adding a new entity" → "Non-standard actions".
    customActions: {
      // POST /api/v1/activities/notes — append a comment. The endpoint
      // isn't under /clients/, so it can't ride [api.action]; we route
      // through the dedicated [ActivitiesApi]. Server response is
      // discarded — the Activity tab refetches once the pending outbox
      // row drains.
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'clients',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      // POST /clients/{into}/{from}/merge — absorb `from` into `into`.
      // Password-gated (row.requiresPassword ⇒ X-API-PASSWORD-BASE64).
      // The absorbed client is gone server-side: drop its local row, then
      // return the survivor so the dispatcher upserts it
      // (base_entity_sync_dispatcher.dart:54-60).
      MutationKind.merge: ({required row, required payload}) async {
        final survivor = await clientsApi.merge(
          mergeIntoId: payload['merge_into_id'] as String,
          mergeFromId: payload['merge_from_id'] as String,
          idempotencyKey: row.idempotencyKey,
          requiresPassword: row.requiresPassword,
        );
        await clientRepo.applyDeleteResponse(
          companyId: row.companyId,
          id: payload['merge_from_id'] as String,
        );
        // The absorbed client's children (invoices/quotes/credits/payments/
        // expenses/tasks/projects/recurring) were reassigned to the survivor
        // server-side. Force-refetch them so their local client_id converges
        // instead of pointing at the now-deleted client (issue #7 sweep).
        final movedChildren = await clientRepo.childIdsForClient(
          companyId: row.companyId,
          clientId: payload['merge_from_id'] as String,
        );
        if (movedChildren.isNotEmpty) {
          await refreshRelatedEntities(row.companyId, movedChildren);
        }
        return survivor;
      },
      // POST /clients/bulk action:bulk_update — mass-update one whitelisted
      // column across the selection (fired per-id; the repo already applied
      // the optimistic local patch).
      MutationKind.bulkUpdate: clientBulkUpdateHandler(clientsApi, clientRepo),
      // POST /designs/set/default settings_level=client — the client-scope
      // "Update all records" design retro-apply (shared factory; group uses
      // the same handler).
      ...setDefaultDesignHandlers<ClientApi>(companiesApi),
      // Client locations — standalone /api/v1/locations resource, read-
      // embedded on the client. After the write lands, re-pull the parent
      // client and return its envelope so the dispatcher upserts it (the
      // refreshed `locations[]` flows in via `applyUpdateResponse`).
      MutationKind.locationCreate: ({required row, required payload}) async {
        await locationsApi.create(
          body: (payload['body'] as Map).cast<String, dynamic>(),
          idempotencyKey: row.idempotencyKey,
        );
        final client = await clientsApi.get(payload['client_id'] as String);
        return client.data;
      },
      MutationKind.locationUpdate: ({required row, required payload}) async {
        await locationsApi.update(
          id: payload['location_id'] as String,
          body: (payload['body'] as Map).cast<String, dynamic>(),
          idempotencyKey: row.idempotencyKey,
        );
        final client = await clientsApi.get(payload['client_id'] as String);
        return client.data;
      },
      MutationKind.locationDelete: ({required row, required payload}) async {
        await locationsApi.delete(
          id: payload['location_id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        final client = await clientsApi.get(payload['client_id'] as String);
        return client.data;
      },
      ...reactivateEmailHandlers<ClientApi>(ctx.emailsApi),
      ...documentMutationHandlers<ClientApi>(
        documentsApi: ctx.documentsApi,
        upload: clientsApi.uploadDocument,
        applyChanged: clientRepo.applyDocumentChanged,
        applyDeleted: clientRepo.applyDocumentDeleted,
      ),
    },
  );

  // ---- Product -------------------------------------------------------------
  final productsApi = ProductsApi(ctx.apiClient);
  final productRepo = ProductRepository(
    db: ctx.db,
    api: productsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<ProductItemApi, ProductApi>(
    type: EntityType.product,
    api: productsApi,
    repo: productRepo,
    customActions: documentMutationHandlers<ProductApi>(
      documentsApi: ctx.documentsApi,
      upload: productsApi.uploadDocument,
      applyChanged: productRepo.applyDocumentChanged,
      applyDeleted: productRepo.applyDocumentDeleted,
    ),
  );

  // ---- Task ----------------------------------------------------------------
  final tasksApi = TasksApi(ctx.apiClient);
  final taskRepo = TaskRepository(
    db: ctx.db,
    api: tasksApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<TaskItemApi, TaskApi>(
    type: EntityType.task,
    api: tasksApi,
    repo: taskRepo,
    customActions: {
      // Kanban drag-drop + task-statuses reorder both ride this handler.
      // Payload carries `{status_ids, task_ids}` (tasks) or just
      // `{status_ids}` (statuses, routed via the task_statuses block below).
      MutationKind.reorder: ({required row, required payload}) async {
        await tasksApi.sort(
          payload: payload,
          idempotencyKey: row.idempotencyKey,
        );
        // Server returned 200. Clear the optimistic `is_dirty` flag on every
        // task in the batch so a subsequent inbound delta can refresh them
        // without being blocked by the in-memory pending flag. The local
        // rows already carry the new ordering — no `applyUpdateResponse`
        // needed (the dispatcher skips it when we return null).
        final taskIdsByStatus =
            (payload['task_ids'] as Map<String, dynamic>?) ?? const {};
        final touched = <String>{
          for (final list in taskIdsByStatus.values)
            ...(list as List).cast<String>(),
        };
        if (touched.isNotEmpty) {
          await taskRepo.clearDirtyForReorder(
            companyId: row.companyId,
            taskIds: touched,
          );
        }
        return null;
      },
      ...documentMutationHandlers<TaskApi>(
        documentsApi: ctx.documentsApi,
        upload: tasksApi.uploadDocument,
        applyChanged: taskRepo.applyDocumentChanged,
        applyDeleted: taskRepo.applyDocumentDeleted,
      ),
    },
  );

  // ---- Project -------------------------------------------------------------
  final projectsApi = ProjectsApi(ctx.apiClient);
  final projectRepo = ProjectRepository(
    db: ctx.db,
    api: projectsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<ProjectItemApi, ProjectApi>(
    type: EntityType.project,
    api: projectsApi,
    repo: projectRepo,
    customActions: {
      MutationKind.runTemplate: ({required row, required payload}) async {
        final response = await projectsApi.runTemplate(
          id: payload['id'] as String,
          templateId: payload['template_id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      ...documentMutationHandlers<ProjectApi>(
        documentsApi: ctx.documentsApi,
        upload: projectsApi.uploadDocument,
        applyChanged: projectRepo.applyDocumentChanged,
        applyDeleted: projectRepo.applyDocumentDeleted,
      ),
    },
  );

  // ---- Vendor --------------------------------------------------------------
  final vendorsApi = VendorsApi(ctx.apiClient);
  final vendorRepo = VendorRepository(
    db: ctx.db,
    api: vendorsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<VendorItemApi, VendorApi>(
    type: EntityType.vendor,
    api: vendorsApi,
    repo: vendorRepo,
    customActions: {
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'vendors',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      // POST /vendors/{into}/{from}/merge — absorb `from` into `into`.
      // Password-gated; the absorbed vendor is gone server-side, so drop its
      // local row and return the survivor for the dispatcher to upsert.
      // Mirrors the Client merge handler.
      MutationKind.merge: ({required row, required payload}) async {
        final survivor = await vendorsApi.merge(
          mergeIntoId: payload['merge_into_id'] as String,
          mergeFromId: payload['merge_from_id'] as String,
          idempotencyKey: row.idempotencyKey,
          requiresPassword: row.requiresPassword,
        );
        await vendorRepo.applyDeleteResponse(
          companyId: row.companyId,
          id: payload['merge_from_id'] as String,
        );
        // The absorbed vendor's children (expenses/purchase orders/recurring
        // expenses) were reassigned to the survivor server-side. Force-refetch
        // them so their local vendor_id converges (issue #7 sweep).
        final movedChildren = await vendorRepo.childIdsForVendor(
          companyId: row.companyId,
          vendorId: payload['merge_from_id'] as String,
        );
        if (movedChildren.isNotEmpty) {
          await refreshRelatedEntities(row.companyId, movedChildren);
        }
        return survivor;
      },
      ...documentMutationHandlers<VendorApi>(
        documentsApi: ctx.documentsApi,
        upload: vendorsApi.uploadDocument,
        applyChanged: vendorRepo.applyDocumentChanged,
        applyDeleted: vendorRepo.applyDocumentDeleted,
      ),
    },
  );

  // ---- Expense -------------------------------------------------------------
  final expensesApi = ExpensesApi(ctx.apiClient);
  final expenseRepo = ExpenseRepository(
    db: ctx.db,
    api: expensesApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<ExpenseItemApi, ExpenseApi>(
    type: EntityType.expense,
    api: expensesApi,
    repo: expenseRepo,
    customActions: {
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'expenses',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      MutationKind.runTemplate: ({required row, required payload}) async {
        final response = await expensesApi.runTemplate(
          id: payload['id'] as String,
          templateId: payload['template_id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      ...documentMutationHandlers<ExpenseApi>(
        documentsApi: ctx.documentsApi,
        upload: expensesApi.uploadDocument,
        applyChanged: expenseRepo.applyDocumentChanged,
        applyDeleted: expenseRepo.applyDocumentDeleted,
      ),
    },
  );

  // ---- RecurringExpense ----------------------------------------------------
  // `start` / `stop` route through dedicated `PUT /recurring_expenses/{id}?
  // start=true` / `&stop=true` endpoints. Repository enqueues these as
  // [MutationKind.start] / [MutationKind.stop]; the customActions handlers
  // below call the dedicated API methods. Reused verbatim when
  // `recurring_invoice` lands (three entities × two enum values = same total
  // cardinality as one-value-with-payload, and keeps `customActions`
  // type-safe + the Outbox screen readable).
  final recurringExpensesApi = RecurringExpensesApi(ctx.apiClient);
  final recurringExpenseRepo = RecurringExpenseRepository(
    db: ctx.db,
    api: recurringExpensesApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<RecurringExpenseItemApi, RecurringExpenseApi>(
    type: EntityType.recurringExpense,
    api: recurringExpensesApi,
    repo: recurringExpenseRepo,
    customActions: {
      MutationKind.start: ({required row, required payload}) async {
        final response = await recurringExpensesApi.start(
          id: payload['id'] as String,
          payload: payload,
          idempotencyKey: row.idempotencyKey,
        );
        return response.data;
      },
      MutationKind.stop: ({required row, required payload}) async {
        final response = await recurringExpensesApi.stop(
          id: payload['id'] as String,
          payload: payload,
          idempotencyKey: row.idempotencyKey,
        );
        return response.data;
      },
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'recurring_expenses',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      ...documentMutationHandlers<RecurringExpenseApi>(
        documentsApi: ctx.documentsApi,
        upload: recurringExpensesApi.uploadDocument,
        applyChanged: recurringExpenseRepo.applyDocumentChanged,
        applyDeleted: recurringExpenseRepo.applyDocumentDeleted,
      ),
    },
  );

  // ---- ExpenseCategory -----------------------------------------------------
  // Settings-only entity reached via Settings → Advanced → Expense
  // Categories. Bundled via `/refresh?first_load=true` (same pattern as
  // task_statuses / payment_terms): the bundleApplier closure at the bottom
  // upserts on every refresh; CRUD also flows through the paginated path
  // for offline edits.
  final expenseCategoriesApi = ExpenseCategoriesApi(ctx.apiClient);
  final expenseCategoryRepo = ExpenseCategoryRepository(
    db: ctx.db,
    api: expenseCategoriesApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<ExpenseCategoryItemApi, ExpenseCategoryApi>(
    type: EntityType.expenseCategory,
    api: expenseCategoriesApi,
    repo: expenseCategoryRepo,
  );

  // ---- CompanyGateway ------------------------------------------------------
  final companyGatewaysApi = CompanyGatewaysApi(ctx.apiClient);
  final companyGatewayRepo = CompanyGatewayRepository(
    db: ctx.db,
    api: companyGatewaysApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<CompanyGatewayItemApi, CompanyGatewayApi>(
    type: EntityType.companyGateway,
    api: companyGatewaysApi,
    repo: companyGatewayRepo,
  );

  // ---- PaymentTerm ---------------------------------------------------------
  final paymentTermsApi = PaymentTermsApi(ctx.apiClient);
  final paymentTermRepo = PaymentTermRepository(
    db: ctx.db,
    api: paymentTermsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<PaymentTermItemApi, PaymentTermApi>(
    type: EntityType.paymentTerm,
    api: paymentTermsApi,
    repo: paymentTermRepo,
  );

  // ---- Schedule ------------------------------------------------------------
  // Bundled settings entity. Server includes `company.task_schedulers` in
  // the `/refresh?first_load=true` envelope; `applyBundle` upserts into
  // the local table. Per-entity paged fetch is still wired so the list
  // can pull a fresh snapshot if the bundle was stale.
  final schedulesApi = SchedulesApi(ctx.apiClient);
  final scheduleRepo = ScheduleRepository(
    db: ctx.db,
    api: schedulesApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<ScheduleItemApi, ScheduleApi>(
    type: EntityType.schedule,
    api: schedulesApi,
    repo: scheduleRepo,
  );

  // ---- TaxRate -------------------------------------------------------------
  // Bundled-only repo today (no CRUD screen) — the Settings → Tax Settings
  // pickers read from Drift via `watchAll`. Wiring `wire<...>(...)` here is
  // fine: `kDisabledEntityModules` carries the matching spec so the entity
  // registry consistency test stays green. When the Tax Rates CRUD page
  // lands, move the spec from `kDisabledEntityModules` to `kWiredEntityModules`
  // and the existing dispatcher / api / repo all keep working.
  //
  // Trade-off: this entity gets a real (functional) sync dispatcher even
  // though it's listed as disabled. There is no UI path today that enqueues
  // a TaxRate mutation, so the live dispatcher is dormant. If a future bug
  // does enqueue one, the outbox will fire real HTTP — preferable to a
  // silent no-op (we'd hear about it via the outbox screen) and matches
  // the contract the CRUD screen will eventually rely on.
  final taxRatesApi = TaxRatesApi(ctx.apiClient);
  final taxRateRepo = TaxRateRepository(
    db: ctx.db,
    api: taxRatesApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<TaxRateItemApi, TaxRateApi>(
    type: EntityType.taxRate,
    api: taxRatesApi,
    repo: taxRateRepo,
  );

  // ---- TaskStatus ----------------------------------------------------------
  final taskStatusesApi = TaskStatusesApi(ctx.apiClient);
  final taskStatusRepo = TaskStatusRepository(
    db: ctx.db,
    api: taskStatusesApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<TaskStatusItemApi, TaskStatusApi>(
    type: EntityType.taskStatus,
    api: taskStatusesApi,
    repo: taskStatusRepo,
    customActions: {
      MutationKind.reorder: ({required row, required payload}) async {
        // No bulk sort endpoint for task statuses — PUT the single moved
        // status; the server shifts + renumbers its siblings (1..N). See
        // `TaskStatusRepository.reorder`.
        final movedPayload = (payload['status'] as Map).cast<String, dynamic>();
        final movedId = movedPayload['id'] as String;
        await taskStatusesApi.reorderOne(
          id: movedId,
          payload: movedPayload,
          idempotencyKey: row.idempotencyKey,
        );
        // Local rows already carry the new ordering — just drop the
        // optimistic `is_dirty` flags so a later delta can refresh them.
        final ids = (payload['all_ids'] as List?)?.cast<String>() ?? const [];
        if (ids.isNotEmpty) {
          await taskStatusRepo.clearDirtyForReorder(
            companyId: row.companyId,
            statusIds: ids,
          );
        }
        return null;
      },
    },
  );

  // ---- Tag -----------------------------------------------------------------
  // NOT bundled and NOT generically paginated — `TagRepository.refreshAll`
  // fetches both entity types via `/api/v1/tags?entity_type=...` on company
  // activate. Wired here only so create/update/delete/archive/restore from the
  // tag picker + Settings → Tags drain through the standard outbox.
  final tagsApi = TagsApi(ctx.apiClient);
  final tagRepo = TagRepository(
    db: ctx.db,
    api: tagsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<TagItemApi, TagApi>(type: EntityType.tag, api: tagsApi, repo: tagRepo);

  // ---- Design --------------------------------------------------------------
  // Bundled via `/refresh?first_load=true` (data[N].company.designs) — the
  // Invoice Design pickers consume the resulting `designs` Drift table.
  // Modeled as a wired entity so the outbox dispatcher handles future
  // create/update/delete from the Custom Designs CRUD screens. No reorder
  // (server has no sort endpoint for designs).
  final designsApi = DesignsApi(ctx.apiClient);
  final designRepo = DesignRepository(
    db: ctx.db,
    api: designsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<DesignItemApi, DesignApi>(
    type: EntityType.design,
    api: designsApi,
    repo: designRepo,
  );

  // ---- GroupSetting --------------------------------------------------------
  final groupSettingsApi = GroupSettingsApi(ctx.apiClient);
  final groupSettingRepo = GroupSettingRepository(
    db: ctx.db,
    api: groupSettingsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<GroupSettingItemApi, GroupSettingApi>(
    type: EntityType.group,
    api: groupSettingsApi,
    repo: groupSettingRepo,
    customActions: {
      ...documentMutationHandlers<GroupSettingApi>(
        documentsApi: ctx.documentsApi,
        upload: groupSettingsApi.uploadDocument,
        applyChanged: groupSettingRepo.applyDocumentChanged,
        applyDeleted: groupSettingRepo.applyDocumentDeleted,
      ),
      // POST /designs/set/default settings_level=group_settings — the
      // group-scope "Update all records" design retro-apply (shared factory).
      ...setDefaultDesignHandlers<GroupSettingApi>(companiesApi),
    },
  );

  // ---- PaymentLink (wire: `subscription`) ---------------------------------
  // Settings-only entity reached via Settings → Advanced → Payment Links.
  // Bundled via `/refresh?first_load=true` (same pattern as
  // expense_categories): the bundleApplier closure at the bottom upserts on
  // every refresh; CRUD also flows through the paginated path for offline
  // edits.
  final subscriptionsApi = SubscriptionsApi(ctx.apiClient);
  final paymentLinkRepo = PaymentLinkRepository(
    db: ctx.db,
    api: subscriptionsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<SubscriptionItemApi, SubscriptionApi>(
    type: EntityType.paymentLink,
    api: subscriptionsApi,
    repo: paymentLinkRepo,
  );

  // ---- Invoice ------------------------------------------------------------
  // Document-bearing, with eleven non-CRUD custom actions (mark_sent /
  // mark_paid / email / schedule_email / clone_to_{invoice,quote,credit,
  // recurring,purchase_order} / auto_bill / cancel / run_template). The
  // shape will be reused verbatim by Quote / Credit / PurchaseOrder /
  // RecurringInvoice — the customActions map varies only in *which* kinds
  // it registers.
  final invoicesApi = InvoicesApi(ctx.apiClient);
  final invoiceRepo = InvoiceRepository(
    db: ctx.db,
    api: invoicesApi,
    onEnqueued: ctx.kickDrain,
    onRelatedEntitiesAffected: refreshRelatedEntities,
    // SettingsRepository is a stateless Drift wrapper — a local instance is
    // equivalent to the one services.dart builds, and avoids reordering
    // construction just to thread it through EntityWiringContext.
    settings: SettingsRepository(db: ctx.db),
  );
  wire<InvoiceItemApi, InvoiceApi>(
    type: EntityType.invoice,
    api: invoicesApi,
    repo: invoiceRepo,
    customActions: {
      // Payment schedule — each handler performs the write then re-fetches
      // the invoice WITH `?show_schedule=true` and returns the InvoiceApi
      // so the dispatcher upserts it → the `schedule` column refreshes →
      // the detail tab updates (the 112-location dispatcher shape).
      MutationKind.paymentScheduleCreate:
          ({required row, required payload}) async {
            await invoicesApi.createPaymentSchedule(
              id: payload['id'] as String,
              body: (payload['body'] as Map).cast<String, dynamic>(),
              idempotencyKey: row.idempotencyKey,
            );
            return (await invoicesApi.getWithSchedule(
              payload['id'] as String,
            )).data;
          },
      MutationKind.paymentScheduleCreateCustom:
          ({required row, required payload}) async {
            await invoicesApi.createCustomPaymentSchedule(
              body: (payload['body'] as Map).cast<String, dynamic>(),
              idempotencyKey: row.idempotencyKey,
            );
            return (await invoicesApi.getWithSchedule(
              payload['id'] as String,
            )).data;
          },
      MutationKind.paymentScheduleDelete:
          ({required row, required payload}) async {
            await invoicesApi.deletePaymentSchedule(
              id: payload['id'] as String,
              idempotencyKey: row.idempotencyKey,
            );
            return (await invoicesApi.getWithSchedule(
              payload['id'] as String,
            )).data;
          },
      MutationKind.markSent: ({required row, required payload}) async {
        final response = await invoicesApi.markSent(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.sendEInvoice: ({required row, required payload}) async {
        final id = payload['id'] as String;
        await invoicesApi.sendEInvoice(
          id: id,
          idempotencyKey: row.idempotencyKey,
        );
        // Server owns the transmission; re-fetch so backup/status update.
        return (await invoicesApi.getWithSchedule(id)).data;
      },
      MutationKind.markPaid: ({required row, required payload}) async {
        final response = await invoicesApi.markPaid(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        // markPaid records a synthetic Payment server-side (not in the invoice
        // response) + moves the client balance. The returned invoice refreshes
        // itself + its client/tasks/expenses via applyUpdateResponse; also pull
        // the new payment into the local list.
        await refreshRecentPayments(row.companyId);
        return response?.data;
      },
      MutationKind.emailEntity: ({required row, required payload}) async {
        final response = await invoicesApi.email(
          id: payload['id'] as String,
          template: payload['template'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.scheduleEmail: ({required row, required payload}) async {
        final response = await invoicesApi.scheduleEmail(
          id: payload['id'] as String,
          template: payload['template'] as String,
          sendAt: payload['send_at'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.cloneToInvoice: ({required row, required payload}) async {
        // The clone endpoint returns the *new* entity envelope. We don't apply
        // it onto the source row (return null so the dispatcher skips
        // applyUpdateResponse), but we force-refetch it by id so it appears in
        // its list without a manual resync.
        final clone = await invoicesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'invoice',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.invoice,
        );
        return null;
      },
      MutationKind.cloneToQuote: ({required row, required payload}) async {
        final clone = await invoicesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'quote',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.quote,
        );
        return null;
      },
      MutationKind.cloneToCredit: ({required row, required payload}) async {
        final clone = await invoicesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'credit',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.credit,
        );
        return null;
      },
      MutationKind.cloneToRecurring: ({required row, required payload}) async {
        final clone = await invoicesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'recurring_invoice',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.recurringInvoice,
        );
        return null;
      },
      MutationKind.cloneToPurchaseOrder:
          ({required row, required payload}) async {
            final clone = await invoicesApi.cloneTo(
              id: payload['id'] as String,
              targetType: 'purchase_order',
              idempotencyKey: row.idempotencyKey,
            );
            await refreshCloneTarget(
              row.companyId,
              clone?.data.id,
              EntityType.purchaseOrder,
            );
            return null;
          },
      MutationKind.autoBill: ({required row, required payload}) async {
        final response = await invoicesApi.autoBill(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        // autoBill creates a Payment (gateway/credit) not in the invoice
        // response — pull the newest payments into the local list.
        await refreshRecentPayments(row.companyId);
        return response?.data;
      },
      MutationKind.cancelEntity: ({required row, required payload}) async {
        final response = await invoicesApi.cancel(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.runTemplate: ({required row, required payload}) async {
        final response = await invoicesApi.runTemplate(
          id: payload['id'] as String,
          templateId: payload['template_id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'invoices',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      ...reactivateEmailHandlers<InvoiceApi>(ctx.emailsApi),
      ...documentMutationHandlers<InvoiceApi>(
        documentsApi: ctx.documentsApi,
        upload: invoicesApi.uploadDocument,
        applyChanged: invoiceRepo.applyDocumentChanged,
        applyDeleted: invoiceRepo.applyDocumentDeleted,
      ),
    },
  );

  // ---- Quote -------------------------------------------------------------
  // Mirrors Invoice but with quote-specific custom actions (approve,
  // convertToInvoice, convertToProject) instead of mark_paid / auto_bill.
  // All shared kinds (mark_sent, email, schedule_email, clone_to_*,
  // cancel, run_template, addComment, document trio) reuse the exact
  // same handler shape.
  final quotesApi = QuotesApi(ctx.apiClient);
  final quoteRepo = QuoteRepository(
    db: ctx.db,
    api: quotesApi,
    onEnqueued: ctx.kickDrain,
    onRelatedEntitiesAffected: refreshRelatedEntities,
  );
  wire<QuoteItemApi, QuoteApi>(
    type: EntityType.quote,
    api: quotesApi,
    repo: quoteRepo,
    customActions: {
      MutationKind.markSent: ({required row, required payload}) async {
        final response = await quotesApi.markSent(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.approve: ({required row, required payload}) async {
        final response = await quotesApi.approve(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.convertToInvoice: ({required row, required payload}) async {
        // `/quotes/bulk` convert returns the *updated quote* (status →
        // converted, `invoice_id` set) via QuoteTransformer — verified
        // against the server's QuoteController::bulk + ConvertQuote. Apply
        // it so the source quote flips to "Converted" and surfaces its
        // "View invoice" link. (The new invoice lands in the invoices list
        // on the next sync.)
        final response = await quotesApi.convertToInvoice(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.convertToProject: ({required row, required payload}) async {
        // Likewise returns the updated quote (now carrying `project_id`),
        // so applying it hides the "Convert to project" action afterward.
        final response = await quotesApi.convertToProject(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.emailEntity: ({required row, required payload}) async {
        final response = await quotesApi.email(
          id: payload['id'] as String,
          template: payload['template'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.scheduleEmail: ({required row, required payload}) async {
        final response = await quotesApi.scheduleEmail(
          id: payload['id'] as String,
          template: payload['template'] as String,
          sendAt: payload['send_at'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.cloneToInvoice: ({required row, required payload}) async {
        final clone = await quotesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'invoice',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.invoice,
        );
        return null;
      },
      MutationKind.cloneToQuote: ({required row, required payload}) async {
        final clone = await quotesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'quote',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.quote,
        );
        return null;
      },
      MutationKind.cloneToCredit: ({required row, required payload}) async {
        final clone = await quotesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'credit',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.credit,
        );
        return null;
      },
      MutationKind.cloneToRecurring: ({required row, required payload}) async {
        final clone = await quotesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'recurring_invoice',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.recurringInvoice,
        );
        return null;
      },
      MutationKind.cloneToPurchaseOrder:
          ({required row, required payload}) async {
            final clone = await quotesApi.cloneTo(
              id: payload['id'] as String,
              targetType: 'purchase_order',
              idempotencyKey: row.idempotencyKey,
            );
            await refreshCloneTarget(
              row.companyId,
              clone?.data.id,
              EntityType.purchaseOrder,
            );
            return null;
          },
      MutationKind.cancelEntity: ({required row, required payload}) async {
        final response = await quotesApi.cancel(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.runTemplate: ({required row, required payload}) async {
        final response = await quotesApi.runTemplate(
          id: payload['id'] as String,
          templateId: payload['template_id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'quotes',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      ...reactivateEmailHandlers<QuoteApi>(ctx.emailsApi),
      ...documentMutationHandlers<QuoteApi>(
        documentsApi: ctx.documentsApi,
        upload: quotesApi.uploadDocument,
        applyChanged: quoteRepo.applyDocumentChanged,
        applyDeleted: quoteRepo.applyDocumentDeleted,
      ),
    },
  );

  // ---- BankAccount ---------------------------------------------------------
  // Settings-only entity reached via Settings → Bank Accounts. The
  // `refresh_accounts` custom action asks the upstream provider
  // (Yodlee/Nordigen) to refresh balances + the connected account list.
  final bankAccountsApi = BankAccountsApi(ctx.apiClient);
  final bankAccountRepo = BankAccountRepository(
    db: ctx.db,
    api: bankAccountsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<BankAccountItemApi, BankAccountApi>(
    type: EntityType.bankAccount,
    api: bankAccountsApi,
    repo: bankAccountRepo,
    customActions: {
      MutationKind.refreshAccounts: ({required row, required payload}) async {
        await bankAccountsApi.refreshAccounts(
          idempotencyKey: row.idempotencyKey,
        );
        // Server returns the full list envelope; we discard it here
        // because the bank-accounts list screen is already watching Drift
        // — the next ensurePageLoaded picks up the fresh balances.
        return null;
      },
    },
  );

  // ---- BankTransaction -----------------------------------------------------
  // Top-level workspace entity at `/transactions`. Four `match` variants +
  // two bulk actions (`convert_matched`, `unlink`) all route through this
  // dispatcher's customActions map.
  final bankTransactionsApi = BankTransactionsApi(ctx.apiClient);
  final bankTransactionRepo = BankTransactionRepository(
    db: ctx.db,
    api: bankTransactionsApi,
    onEnqueued: ctx.kickDrain,
    onRelatedEntitiesAffected: refreshRelatedEntities,
  );
  wire<BankTransactionItemApi, BankTransactionApi>(
    type: EntityType.transaction,
    api: bankTransactionsApi,
    repo: bankTransactionRepo,
    customActions: {
      MutationKind.matchToPayment: ({required row, required payload}) async {
        final response = await bankTransactionsApi.match(
          transactions: (payload['transactions'] as List)
              .cast<Map<String, dynamic>>(),
          idempotencyKey: row.idempotencyKey,
        );
        return response.data.isEmpty ? null : response.data.first;
      },
      MutationKind.linkToPayment: ({required row, required payload}) async {
        final response = await bankTransactionsApi.match(
          transactions: (payload['transactions'] as List)
              .cast<Map<String, dynamic>>(),
          idempotencyKey: row.idempotencyKey,
        );
        return response.data.isEmpty ? null : response.data.first;
      },
      MutationKind.matchToExpense: ({required row, required payload}) async {
        final response = await bankTransactionsApi.match(
          transactions: (payload['transactions'] as List)
              .cast<Map<String, dynamic>>(),
          idempotencyKey: row.idempotencyKey,
        );
        return response.data.isEmpty ? null : response.data.first;
      },
      MutationKind.linkToExpense: ({required row, required payload}) async {
        final response = await bankTransactionsApi.match(
          transactions: (payload['transactions'] as List)
              .cast<Map<String, dynamic>>(),
          idempotencyKey: row.idempotencyKey,
        );
        return response.data.isEmpty ? null : response.data.first;
      },
      MutationKind.convertMatched: ({required row, required payload}) async {
        final response = await bankTransactionsApi.bulkAction(
          action: 'convert_matched',
          ids: (payload['ids'] as List).cast<String>(),
          idempotencyKey: row.idempotencyKey,
        );
        // Apply every returned row so local status updates immediately —
        // no global refreshAll. Return null so the dispatcher doesn't also
        // try to apply a single response (this is a multi-row bulk action).
        for (final tx in response.data) {
          await bankTransactionRepo.applyUpdateResponse(
            companyId: row.companyId,
            serverResponse: tx,
          );
        }
        return null;
      },
      MutationKind.unlinkTransaction: ({required row, required payload}) async {
        final response = await bankTransactionsApi.bulkAction(
          action: 'unlink',
          ids: (payload['ids'] as List).cast<String>(),
          idempotencyKey: row.idempotencyKey,
        );
        for (final tx in response.data) {
          await bankTransactionRepo.applyUpdateResponse(
            companyId: row.companyId,
            serverResponse: tx,
          );
        }
        return null;
      },
    },
  );

  // ---- TransactionRule -----------------------------------------------------
  // Settings-only entity reached via Settings → Bank Accounts → Rules.
  final transactionRulesApi = TransactionRulesApi(ctx.apiClient);
  final transactionRuleRepo = TransactionRuleRepository(
    db: ctx.db,
    api: transactionRulesApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<TransactionRuleItemApi, TransactionRuleApi>(
    type: EntityType.transactionRule,
    api: transactionRulesApi,
    repo: transactionRuleRepo,
  );

  // ---- Webhook -----------------------------------------------------------
  // Settings-only entity reached via Settings → Integrations → API Webhooks.
  // Bundled on `/refresh?first_load=true` (small list — typically a handful
  // of rows per company).
  final webhooksApi = WebhooksApi(ctx.apiClient);
  final webhookRepo = WebhookRepository(
    db: ctx.db,
    api: webhooksApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<WebhookItemApi, WebhookApi>(
    type: EntityType.webhook,
    api: webhooksApi,
    repo: webhookRepo,
  );

  // ---- Token (API Tokens) -----------------------------------------------
  // Settings-only entity reached via Settings → Integrations → API Tokens.
  // Bundled on `/refresh?first_load=true` via `tokens_hashed`. The server
  // returns masked `token` values on the bundle / list; the raw bearer
  // secret only appears on the create response and is broadcast via
  // `TokenRepository.newSecrets` for the one-time "copy now" dialog.
  final tokensApi = TokensApi(ctx.apiClient);
  final tokenRepo = TokenRepository(
    db: ctx.db,
    api: tokensApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<TokenItemApi, TokenApi>(
    type: EntityType.token,
    api: tokensApi,
    repo: tokenRepo,
  );

  // ---- Credit ------------------------------------------------------------
  // Mirrors Quote shape without the convert-to-X actions. Reuses every
  // shared MutationKind (mark_sent, email, schedule_email, clone_to_*,
  // run_template, addComment, document trio). Credits have a 4-step
  // status (Draft / Sent / Partial / Applied).
  final creditsApi = CreditsApi(ctx.apiClient);
  final creditRepo = CreditRepository(
    db: ctx.db,
    api: creditsApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<CreditItemApi, CreditApi>(
    type: EntityType.credit,
    api: creditsApi,
    repo: creditRepo,
    customActions: {
      MutationKind.markSent: ({required row, required payload}) async {
        final response = await creditsApi.markSent(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.markPaid: ({required row, required payload}) async {
        final response = await creditsApi.markPaid(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        // Credit markPaid records a synthetic Payment — pull it into the list.
        await refreshRecentPayments(row.companyId);
        return response?.data;
      },
      MutationKind.emailEntity: ({required row, required payload}) async {
        final response = await creditsApi.email(
          id: payload['id'] as String,
          template: payload['template'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.scheduleEmail: ({required row, required payload}) async {
        final response = await creditsApi.scheduleEmail(
          id: payload['id'] as String,
          template: payload['template'] as String,
          sendAt: payload['send_at'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.cloneToInvoice: ({required row, required payload}) async {
        final clone = await creditsApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'invoice',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.invoice,
        );
        return null;
      },
      MutationKind.cloneToQuote: ({required row, required payload}) async {
        final clone = await creditsApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'quote',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.quote,
        );
        return null;
      },
      MutationKind.cloneToCredit: ({required row, required payload}) async {
        final clone = await creditsApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'credit',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.credit,
        );
        return null;
      },
      MutationKind.cloneToRecurring: ({required row, required payload}) async {
        final clone = await creditsApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'recurring_invoice',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.recurringInvoice,
        );
        return null;
      },
      MutationKind.cloneToPurchaseOrder:
          ({required row, required payload}) async {
            final clone = await creditsApi.cloneTo(
              id: payload['id'] as String,
              targetType: 'purchase_order',
              idempotencyKey: row.idempotencyKey,
            );
            await refreshCloneTarget(
              row.companyId,
              clone?.data.id,
              EntityType.purchaseOrder,
            );
            return null;
          },
      MutationKind.runTemplate: ({required row, required payload}) async {
        final response = await creditsApi.runTemplate(
          id: payload['id'] as String,
          templateId: payload['template_id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'credits',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      ...reactivateEmailHandlers<CreditApi>(ctx.emailsApi),
      ...documentMutationHandlers<CreditApi>(
        documentsApi: ctx.documentsApi,
        upload: creditsApi.uploadDocument,
        applyChanged: creditRepo.applyDocumentChanged,
        applyDeleted: creditRepo.applyDocumentDeleted,
      ),
    },
  );

  // PurchaseOrder — vendor-centric mirror of Quote/Credit. Adds the
  // PO-specific custom actions (`convert_to_expense`, `add_to_inventory`) on
  // top of the shared mark_sent / email / schedule_email / run_template /
  // addComment / cancelEntity / document trio. Status lifecycle:
  // Draft → Sent → Accepted → Received → Cancelled. Accept is vendor-portal
  // only (no admin route); cross-type clone is client-side (the server's
  // /bulk has no clone_to_* for POs), so no clone_to_* handlers here.
  final purchaseOrdersApi = PurchaseOrdersApi(ctx.apiClient);
  final purchaseOrderRepo = PurchaseOrderRepository(
    db: ctx.db,
    api: purchaseOrdersApi,
    onEnqueued: ctx.kickDrain,
    onRelatedEntitiesAffected: refreshRelatedEntities,
  );
  wire<PurchaseOrderItemApi, PurchaseOrderApi>(
    type: EntityType.purchaseOrder,
    api: purchaseOrdersApi,
    repo: purchaseOrderRepo,
    customActions: {
      MutationKind.markSent: ({required row, required payload}) async {
        final response = await purchaseOrdersApi.markSent(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.addToInventory: ({required row, required payload}) async {
        final response = await purchaseOrdersApi.addToInventory(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.cancelEntity: ({required row, required payload}) async {
        final response = await purchaseOrdersApi.cancel(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.convertToExpense: ({required row, required payload}) async {
        // Server returns the updated purchase_order (with `expense_id` now
        // set); applying it flips the menu to "View expense" as soon as the
        // outbox drains, instead of leaving "Convert to expense" visible until
        // the next sync (a second click would 400 `already_expensed`).
        final response = await purchaseOrdersApi.expense(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.emailEntity: ({required row, required payload}) async {
        final response = await purchaseOrdersApi.email(
          id: payload['id'] as String,
          template: payload['template'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.scheduleEmail: ({required row, required payload}) async {
        final response = await purchaseOrdersApi.scheduleEmail(
          id: payload['id'] as String,
          template: payload['template'] as String,
          sendAt: payload['send_at'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.runTemplate: ({required row, required payload}) async {
        final response = await purchaseOrdersApi.runTemplate(
          id: payload['id'] as String,
          templateId: payload['template_id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'purchase_orders',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      ...reactivateEmailHandlers<PurchaseOrderApi>(ctx.emailsApi),
      ...documentMutationHandlers<PurchaseOrderApi>(
        documentsApi: ctx.documentsApi,
        upload: purchaseOrdersApi.uploadDocument,
        applyChanged: purchaseOrderRepo.applyDocumentChanged,
        applyDeleted: purchaseOrderRepo.applyDocumentDeleted,
      ),
    },
  );

  // RecurringInvoice — invoice-shaped template with recurring lifecycle.
  // Uses the shared `start` / `stop` MutationKinds (originally added for
  // RecurringExpense) plus the usual mark_sent / email / schedule_email /
  // clone_to_* / run_template / addComment / document trio. Status
  // lifecycle: Draft → Active → Paused → Completed.
  final recurringInvoicesApi = RecurringInvoicesApi(ctx.apiClient);
  final recurringInvoiceRepo = RecurringInvoiceRepository(
    db: ctx.db,
    api: recurringInvoicesApi,
    onEnqueued: ctx.kickDrain,
  );
  wire<RecurringInvoiceItemApi, RecurringInvoiceApi>(
    type: EntityType.recurringInvoice,
    api: recurringInvoicesApi,
    repo: recurringInvoiceRepo,
    customActions: {
      MutationKind.start: ({required row, required payload}) async {
        final response = await recurringInvoicesApi.start(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.stop: ({required row, required payload}) async {
        final response = await recurringInvoicesApi.stop(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.emailEntity: ({required row, required payload}) async {
        final response = await recurringInvoicesApi.email(
          id: payload['id'] as String,
          template: payload['template'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.scheduleEmail: ({required row, required payload}) async {
        final response = await recurringInvoicesApi.scheduleEmail(
          id: payload['id'] as String,
          template: payload['template'] as String,
          sendAt: payload['send_at'] as String,
          subject: payload['subject'] as String?,
          body: payload['body'] as String?,
          ccEmail: payload['cc_email'] as String?,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.cloneToInvoice: ({required row, required payload}) async {
        final clone = await recurringInvoicesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'invoice',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.invoice,
        );
        return null;
      },
      MutationKind.cloneToQuote: ({required row, required payload}) async {
        final clone = await recurringInvoicesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'quote',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.quote,
        );
        return null;
      },
      MutationKind.cloneToCredit: ({required row, required payload}) async {
        final clone = await recurringInvoicesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'credit',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.credit,
        );
        return null;
      },
      MutationKind.cloneToRecurring: ({required row, required payload}) async {
        final clone = await recurringInvoicesApi.cloneTo(
          id: payload['id'] as String,
          targetType: 'recurring_invoice',
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(
          row.companyId,
          clone?.data.id,
          EntityType.recurringInvoice,
        );
        return null;
      },
      MutationKind.cloneToPurchaseOrder:
          ({required row, required payload}) async {
            final clone = await recurringInvoicesApi.cloneTo(
              id: payload['id'] as String,
              targetType: 'purchase_order',
              idempotencyKey: row.idempotencyKey,
            );
            await refreshCloneTarget(
              row.companyId,
              clone?.data.id,
              EntityType.purchaseOrder,
            );
            return null;
          },
      MutationKind.runTemplate: ({required row, required payload}) async {
        final response = await recurringInvoicesApi.runTemplate(
          id: payload['id'] as String,
          templateId: payload['template_id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.updatePrices: ({required row, required payload}) async {
        final response = await recurringInvoicesApi.updatePrices(
          id: payload['id'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.increasePrices: ({required row, required payload}) async {
        final response = await recurringInvoicesApi.increasePrices(
          id: payload['id'] as String,
          percentageIncrease: payload['percentage_increase'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return response?.data;
      },
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'recurring_invoices',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      ...reactivateEmailHandlers<RecurringInvoiceApi>(ctx.emailsApi),
      ...documentMutationHandlers<RecurringInvoiceApi>(
        documentsApi: ctx.documentsApi,
        upload: recurringInvoicesApi.uploadDocument,
        applyChanged: recurringInvoiceRepo.applyDocumentChanged,
        applyDeleted: recurringInvoiceRepo.applyDocumentDeleted,
      ),
    },
  );

  // ---- Payment -------------------------------------------------------------
  // Document-bearing, password-gated delete/purge/documentDelete. Two
  // payment-only customActions handle the non-CRUD endpoints:
  //   * refundPayment → POST /payments/refund with body {id, date, invoices}
  //     and `?email_receipt=…[&gateway_refund=true]`
  //   * applyPayment  → PUT /payments/{id} with body {invoices: [...]}
  final paymentsApi = PaymentsApi(ctx.apiClient);
  final paymentRepo = PaymentRepository(
    db: ctx.db,
    api: paymentsApi,
    onEnqueued: ctx.kickDrain,
    onRelatedEntitiesAffected: refreshRelatedEntities,
  );
  wire<PaymentItemApi, PaymentApi>(
    type: EntityType.payment,
    api: paymentsApi,
    repo: paymentRepo,
    customActions: {
      MutationKind.refundPayment: ({required row, required payload}) async {
        final sendEmail = payload['send_email'] == true;
        final gatewayRefund = payload['gateway_refund'] == true;
        return paymentsApi.refund(
          id: payload['id'] as String,
          body: <String, dynamic>{
            'id': payload['id'],
            'date': payload['date'],
            'invoices': payload['invoices'],
          },
          idempotencyKey: row.idempotencyKey,
          sendEmail: sendEmail,
          gatewayRefund: gatewayRefund,
        );
      },
      MutationKind.applyPayment: ({required row, required payload}) async {
        final allocations = (payload['invoices'] as List)
            .cast<Map<String, dynamic>>();
        return paymentsApi.apply(
          id: payload['id'] as String,
          allocations: allocations,
          idempotencyKey: row.idempotencyKey,
        );
      },
      MutationKind.addComment: ({required row, required payload}) async {
        await ctx.activitiesApi.addNote(
          entity: 'payments',
          entityId: payload['entity_id'] as String,
          notes: payload['notes'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        return null;
      },
      ...documentMutationHandlers<PaymentApi>(
        documentsApi: ctx.documentsApi,
        upload: paymentsApi.uploadDocument,
        applyChanged: paymentRepo.applyDocumentChanged,
        applyDeleted: paymentRepo.applyDocumentDeleted,
      ),
    },
  );

  // Count + first-page prefetch maps for every workspace-sidebar entity.
  // Keep in sync with `kWiredEntityModules` — any entry whose
  // `sidebarSection != none` needs both a count (drives the sidebar badge)
  // and a prefetch (fires on every `auth.onActiveCompanyChanged` so the
  // badge is non-zero before the user opens the list). Settings-only and
  // bundled-only entities are intentionally absent.
  final countWatchers = <EntityType, Stream<int> Function(String)>{
    EntityType.client: (c) => clientRepo.watchCount(companyId: c),
    EntityType.product: (c) => productRepo.watchCount(companyId: c),
    EntityType.task: (c) => taskRepo.watchCount(companyId: c),
    EntityType.project: (c) => projectRepo.watchCount(companyId: c),
    EntityType.vendor: (c) => vendorRepo.watchCount(companyId: c),
    EntityType.expense: (c) => expenseRepo.watchCount(companyId: c),
    EntityType.recurringExpense: (c) =>
        recurringExpenseRepo.watchCount(companyId: c),
    EntityType.invoice: (c) => invoiceRepo.watchCount(companyId: c),
    EntityType.quote: (c) => quoteRepo.watchCount(companyId: c),
    EntityType.credit: (c) => creditRepo.watchCount(companyId: c),
    EntityType.purchaseOrder: (c) => purchaseOrderRepo.watchCount(companyId: c),
    EntityType.recurringInvoice: (c) =>
        recurringInvoiceRepo.watchCount(companyId: c),
    EntityType.payment: (c) => paymentRepo.watchCount(companyId: c),
    EntityType.transaction: (c) => bankTransactionRepo.watchCount(companyId: c),
  };
  final firstPagePrefetchers = <EntityType, Future<bool> Function(String)>{
    EntityType.client: (c) =>
        clientRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.product: (c) =>
        productRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.task: (c) => taskRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.project: (c) =>
        projectRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.vendor: (c) =>
        vendorRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.expense: (c) =>
        expenseRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.recurringExpense: (c) =>
        recurringExpenseRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.invoice: (c) =>
        invoiceRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.quote: (c) => quoteRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.credit: (c) =>
        creditRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.purchaseOrder: (c) =>
        purchaseOrderRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.recurringInvoice: (c) =>
        recurringInvoiceRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.payment: (c) =>
        paymentRepo.ensurePageLoaded(companyId: c, page: 1),
    EntityType.transaction: (c) =>
        bankTransactionRepo.ensurePageLoaded(companyId: c, page: 1),
  };

  return WiredEntities(
    clientsApi: clientsApi,
    clients: clientRepo,
    productsApi: productsApi,
    products: productRepo,
    tasksApi: tasksApi,
    tasks: taskRepo,
    projectsApi: projectsApi,
    projects: projectRepo,
    vendorsApi: vendorsApi,
    vendors: vendorRepo,
    expensesApi: expensesApi,
    expenses: expenseRepo,
    recurringExpensesApi: recurringExpensesApi,
    recurringExpenses: recurringExpenseRepo,
    expenseCategoriesApi: expenseCategoriesApi,
    expenseCategories: expenseCategoryRepo,
    companyGatewaysApi: companyGatewaysApi,
    companyGateways: companyGatewayRepo,
    paymentTermsApi: paymentTermsApi,
    paymentTerms: paymentTermRepo,
    taxRatesApi: taxRatesApi,
    taxRates: taxRateRepo,
    taskStatusesApi: taskStatusesApi,
    taskStatuses: taskStatusRepo,
    tagsApi: tagsApi,
    tags: tagRepo,
    designsApi: designsApi,
    designs: designRepo,
    groupSettingsApi: groupSettingsApi,
    groupSettings: groupSettingRepo,
    subscriptionsApi: subscriptionsApi,
    paymentLinks: paymentLinkRepo,
    schedulesApi: schedulesApi,
    schedules: scheduleRepo,
    invoicesApi: invoicesApi,
    invoices: invoiceRepo,
    quotesApi: quotesApi,
    quotes: quoteRepo,
    creditsApi: creditsApi,
    credits: creditRepo,
    purchaseOrdersApi: purchaseOrdersApi,
    purchaseOrders: purchaseOrderRepo,
    recurringInvoicesApi: recurringInvoicesApi,
    recurringInvoices: recurringInvoiceRepo,
    bankAccountsApi: bankAccountsApi,
    bankAccounts: bankAccountRepo,
    bankTransactionsApi: bankTransactionsApi,
    bankTransactions: bankTransactionRepo,
    transactionRulesApi: transactionRulesApi,
    transactionRules: transactionRuleRepo,
    paymentsApi: paymentsApi,
    payments: paymentRepo,
    webhooksApi: webhooksApi,
    webhooks: webhookRepo,
    tokensApi: tokensApi,
    tokens: tokenRepo,
    // Fan-out the bundled per-entity arrays the `/refresh` envelope carries
    // alongside the company. Order doesn't matter for correctness (each repo
    // upserts its own slice) but kept stable for log determinism. Add a new
    // bundled entity by appending a closure here.
    bundleAppliers: [
      ({required companyId, required company, required fullSync}) =>
          taskStatusRepo.applyBundle(
            companyId: companyId,
            bundle: company.taskStatuses,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          companyGatewayRepo.applyBundle(
            companyId: companyId,
            bundle: company.companyGateways,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          paymentTermRepo.applyBundle(
            companyId: companyId,
            bundle: company.paymentTerms,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          taxRateRepo.applyBundle(
            companyId: companyId,
            bundle: company.taxRates,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          expenseCategoryRepo.applyBundle(
            companyId: companyId,
            bundle: company.expenseCategories,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          designRepo.applyBundle(
            companyId: companyId,
            bundle: company.designs,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          paymentLinkRepo.applyBundle(
            companyId: companyId,
            bundle: company.subscriptions,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          scheduleRepo.applyBundle(
            companyId: companyId,
            bundle: company.taskSchedulers,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          groupSettingRepo.applyBundle(
            companyId: companyId,
            bundle: company.groups,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          transactionRuleRepo.applyBundle(
            companyId: companyId,
            bundle: company.bankTransactionRules,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          bankAccountRepo.applyBundle(
            companyId: companyId,
            bundle: company.bankIntegrations,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          webhookRepo.applyBundle(
            companyId: companyId,
            bundle: company.webhooks,
            fullSync: fullSync,
          ),
      ({required companyId, required company, required fullSync}) =>
          tokenRepo.applyBundle(
            companyId: companyId,
            bundle: company.tokensHashed,
            fullSync: fullSync,
          ),
    ],
    countWatchers: countWatchers,
    firstPagePrefetchers: firstPagePrefetchers,
  );
}

/// `POST /clients/bulk action:bulk_update` handler — extracted as a factory so
/// the null-echo reconciliation below is unit-testable (the inline-closure
/// form had no seam; precedent: [setDefaultDesignHandlers]).
///
/// `bulkActionOne` returns the item envelope, so unwrap `.data` for the
/// dispatcher to upsert (clearing the optimistic `is_dirty` the repo wrote).
/// A NULL echo means the server's re-query omitted the row (deleted /
/// filtered server-side while the mutation was queued) — there is nothing to
/// upsert, so mirror the archive/restore null-echo reconciliation (L8,
/// base_entity_sync_dispatcher.dart) and clear the dirty flag directly:
/// leaving it set would exempt the row from every future refresh, freezing
/// the optimistic value on screen forever.
CustomMutationHandler<ClientApi> clientBulkUpdateHandler(
  ClientsApi clientsApi,
  ClientRepository clientRepo,
) => ({required row, required payload}) async {
  final item = await clientsApi.bulkActionOne(
    id: payload['id'] as String,
    action: 'bulk_update',
    idempotencyKey: row.idempotencyKey,
    extra: {
      'column': payload['column'] as String,
      'new_value': payload['new_value'] as String,
    },
  );
  if (item == null) {
    await clientRepo.clearLocalDirty(
      companyId: row.companyId,
      id: row.entityId,
    );
    return null;
  }
  return item.data;
};

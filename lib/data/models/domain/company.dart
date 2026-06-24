import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/client_registration_field_api_model.dart';
import 'package:admin/data/models/api/company_api_model.dart';
import 'package:admin/data/models/api/company_settings_api_model.dart';
import 'package:admin/data/models/api/tax_config_api_model.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/document.dart';

export 'package:admin/data/models/api/client_registration_field_api_model.dart';
// `Document` moved out of this file when Client and Product started carrying
// document arrays too. Re-exported so existing call sites that `import
// 'company.dart'` keep working without churn.
export 'package:admin/data/models/domain/document.dart';

part 'company.freezed.dart';

/// Domain `Company` — what the UI sees.
///
/// The settings blob is carried in two parallel shapes:
///  * [settings] — typed [CompanySettings], holds the ~200 fields the app
///    actively understands. Field mutations flow through this.
///  * [rawSettings] — the original server JSON map. Holds every key the
///    server sent, including the ~50 we haven't modeled.
///
/// On save we merge `{...rawSettings, ...settings.toJson()}` so the PUT body
/// preserves every unknown key alongside the user's typed edits. Without
/// this, fields like `mailgun_secret` or `e_invoice_type` would silently
/// disappear from the server on the first settings save.
///
/// `legalEntityId != 0` is the signal that this tenant has bound a legal
/// entity; the Details tab disables the `id_number` and `vat_number` fields
/// when set (matches React `Details.tsx`).
@freezed
abstract class Company with _$Company {
  const Company._();

  const factory Company({
    @Default('') String id,
    @Default('') String displayName,
    @Default('') String name,
    @Default('') String companyKey,
    @Default('') String sizeId,
    @Default('') String industryId,
    @Default('') String firstMonthOfYear,
    @Default('') String firstDayOfWeek,
    @Default(false) bool useCommaAsDecimalPlace,
    @Default(0) int enabledModules,
    @Default(0) int legalEntityId,
    // Top-level e-invoice certificate state. The passphrase is the only field
    // the user edits directly; the two `has*` flags are server-set (set
    // server-side on upload, cleared on removal). Round-trip through the
    // outbox alongside other top-level company fields.
    @Default(false) bool hasEInvoiceCertificate,
    @Default('') String eInvoiceCertificatePassphrase,
    @Default(false) bool hasEInvoiceCertificatePassphrase,
    @Default('') String subdomain,
    @Default('') String portalDomain,
    @Default('') String portalMode,
    // Top-level company column (the server gates registration on
    // `companies.client_can_register`; the copy inside `settings` is
    // server-deprecated). Round-trips alongside the other portal fields.
    @Default(false) bool clientCanRegister,
    @Default(<ClientRegistrationFieldApi>[])
    List<ClientRegistrationFieldApi> clientRegistrationFields,
    @Default(<String, String>{}) Map<String, String> customFields,
    @Default(<String, dynamic>{}) Map<String, dynamic> rawSettings,
    @Default(CompanySettings()) CompanySettings settings,
    @Default(false) bool enableApplyingPayments,
    @Default(false) bool convertPaymentCurrency,
    @Default(0) int enabledTaxRates,
    @Default(0) int enabledItemTaxRates,
    @Default(0) int enabledExpenseTaxRates,
    @Default(false) bool calculateTaxes,
    TaxConfigApi? taxData,
    // Server's e-invoice config blob (nested UBL-ish map), carried untyped so
    // the Payment Means card can seed from `e_invoice.Invoice.PaymentMeans[0]`
    // (matches React). Deliberately omitted from [toApiJson] — it's server-
    // derived and writes go through `/einvoice/configurations`, so we never
    // send it back on a company PUT.
    Map<String, dynamic>? eInvoice,
    // Per-surcharge "charge taxes" toggles paired with the four surcharge
    // custom-field slots (`customFields['surcharge1'..'surcharge4']`).
    @Default(false) bool customSurchargeTaxes1,
    @Default(false) bool customSurchargeTaxes2,
    @Default(false) bool customSurchargeTaxes3,
    @Default(false) bool customSurchargeTaxes4,
    // Top-level product configuration. Edited by Settings → Product Settings;
    // round-trips through the outbox without touching the `settings` JSON.
    @Default(false) bool trackInventory,
    @Default(false) bool stockNotification,
    @Default(0) int inventoryNotificationThreshold,
    @Default(false) bool enableProductDiscount,
    @Default(false) bool enableProductCost,
    @Default(false) bool enableProductQuantity,
    @Default(false) bool defaultQuantity,
    @Default(false) bool showProductDetails,
    @Default(false) bool fillProducts,
    @Default(false) bool updateProducts,
    @Default(false) bool convertProducts,
    @Default(false) bool convertRateToClient,
    // Top-level workflow configuration. Edited by Settings → Workflow Settings
    // alongside the cascade `settings.*` workflow toggles.
    @Default(false) bool stopOnUnpaidRecurring,
    @Default(false) bool useQuoteTermsOnConversion,
    // Top-level task configuration. Edited by Settings → Task Settings.
    @Default(false) bool autoStartTasks,
    @Default(false) bool showTaskEndDate,
    @Default(false) bool showTasksTable,
    @Default(false) bool invoiceTaskDatelog,
    @Default(false) bool invoiceTaskTimelog,
    @Default(false) bool invoiceTaskHours,
    @Default(false) bool invoiceTaskItemDescription,
    @Default(false) bool invoiceTaskProject,
    @Default(false) bool invoiceTaskProjectHeader,
    @Default(false) bool invoiceTaskLock,
    @Default(false) bool invoiceTaskDocuments,
    // Top-level expense configuration. Edited by Settings → Expense Settings.
    // Cascade `defaultExpensePaymentTypeId` lives on `CompanySettings`. The
    // `inboundMailbox*` block is self-hosted only.
    @Default(false) bool markExpensesInvoiceable,
    @Default(false) bool markExpensesPaid,
    @Default(false) bool convertExpenseCurrency,
    @Default(false) bool invoiceExpenseDocuments,
    @Default(false) bool notifyVendorWhenPaid,
    @Default(false) bool calculateExpenseTaxByAmount,
    @Default(false) bool expenseInclusiveTaxes,
    @Default(false) bool expenseMailboxActive,
    @Default('') String expenseMailbox,
    @Default(false) bool inboundMailboxAllowCompanyUsers,
    @Default(false) bool inboundMailboxAllowVendors,
    @Default(false) bool inboundMailboxAllowClients,
    @Default('') String inboundMailboxWhitelist,
    @Default('') String inboundMailboxBlacklist,
    @Default(false) bool inboundMailboxAllowUnknown,
    // Top-level email / SMTP transport. Edited by Settings → Email Settings
    // when the `smtp` provider is selected. Cascade-aware email properties
    // live on `CompanySettings`; these seven are top-level only.
    @Default('') String smtpHost,
    @Default(0) int smtpPort,
    @Default('TLS') String smtpEncryption,
    @Default('') String smtpUsername,
    @Default('') String smtpPassword,
    @Default('') String smtpLocalDomain,
    @Default(true) bool smtpVerifyPeer,
    // Account Management → Integrations: top-level analytics fields.
    @Default('') String googleAnalyticsKey,
    @Default('') String matomoId,
    @Default('') String matomoUrl,
    // Account Management → Security Settings: top-level company fields.
    // Timeouts in milliseconds; 0 = never time out.
    @Default(0) int sessionTimeout,
    @Default(0) int defaultPasswordTimeout,
    @Default(false) bool oauthPasswordRequired,
    // Account Management → Overview: top-level company toggles.
    @Default(false) bool isDisabled,
    @Default(false) bool markdownEnabled,
    @Default(false) bool markdownEmailEnabled,
    @Default(false) bool reportIncludeDrafts,
    @Default(false) bool reportIncludeDeleted,
    // QuickBooks integration blob. `null` when the account hasn't connected;
    // otherwise the raw server JSON (decoded). Preserved as `Map` rather
    // than a typed model so the round-trip through Drift survives schema
    // drift on the server's `quickbooks.settings.*` sub-object.
    Map<String, dynamic>? quickbooks,
    @Default(<Document>[]) List<Document> documents,
    @Default(0) int updatedAt,
    @Default(0) int archivedAt,
  }) = _Company;

  factory Company.fromApi(CompanyApi api) => Company(
    id: api.id,
    displayName: api.displayName,
    name: api.name,
    companyKey: api.companyKey,
    sizeId: api.sizeId,
    industryId: api.industryId,
    firstMonthOfYear: api.firstMonthOfYear,
    firstDayOfWeek: api.firstDayOfWeek,
    useCommaAsDecimalPlace: api.useCommaAsDecimalPlace,
    enabledModules: api.enabledModules,
    legalEntityId: api.legalEntityId,
    hasEInvoiceCertificate: api.hasEInvoiceCertificate,
    eInvoiceCertificatePassphrase: api.eInvoiceCertificatePassphrase,
    hasEInvoiceCertificatePassphrase: api.hasEInvoiceCertificatePassphrase,
    subdomain: api.subdomain,
    portalDomain: api.portalDomain,
    portalMode: api.portalMode,
    clientCanRegister: api.clientCanRegister,
    clientRegistrationFields: api.clientRegistrationFields,
    customFields: api.customFields,
    rawSettings: api.settings,
    // Lenient: the server ships several settings as number-or-string / 0|1
    // bools, so the raw blob can mix types. fromJsonLenient coerces the known
    // numeric/bool keys (and tolerates an int in endless_reminder_frequency_id)
    // before the strict parse — same path the group/client settings VMs use.
    settings: CompanySettingsApi.fromJsonLenient(api.settings),
    enableApplyingPayments: api.enableApplyingPayments,
    convertPaymentCurrency: api.convertPaymentCurrency,
    enabledTaxRates: api.enabledTaxRates,
    enabledItemTaxRates: api.enabledItemTaxRates,
    enabledExpenseTaxRates: api.enabledExpenseTaxRates,
    calculateTaxes: api.calculateTaxes,
    taxData: api.taxData,
    eInvoice: api.eInvoice,
    customSurchargeTaxes1: api.customSurchargeTaxes1,
    customSurchargeTaxes2: api.customSurchargeTaxes2,
    customSurchargeTaxes3: api.customSurchargeTaxes3,
    customSurchargeTaxes4: api.customSurchargeTaxes4,
    trackInventory: api.trackInventory,
    stockNotification: api.stockNotification,
    inventoryNotificationThreshold: api.inventoryNotificationThreshold,
    enableProductDiscount: api.enableProductDiscount,
    enableProductCost: api.enableProductCost,
    enableProductQuantity: api.enableProductQuantity,
    defaultQuantity: api.defaultQuantity,
    showProductDetails: api.showProductDetails,
    fillProducts: api.fillProducts,
    updateProducts: api.updateProducts,
    convertProducts: api.convertProducts,
    convertRateToClient: api.convertRateToClient,
    stopOnUnpaidRecurring: api.stopOnUnpaidRecurring,
    useQuoteTermsOnConversion: api.useQuoteTermsOnConversion,
    autoStartTasks: api.autoStartTasks,
    showTaskEndDate: api.showTaskEndDate,
    showTasksTable: api.showTasksTable,
    invoiceTaskDatelog: api.invoiceTaskDatelog,
    invoiceTaskTimelog: api.invoiceTaskTimelog,
    invoiceTaskHours: api.invoiceTaskHours,
    invoiceTaskItemDescription: api.invoiceTaskItemDescription,
    invoiceTaskProject: api.invoiceTaskProject,
    invoiceTaskProjectHeader: api.invoiceTaskProjectHeader,
    invoiceTaskLock: api.invoiceTaskLock,
    invoiceTaskDocuments: api.invoiceTaskDocuments,
    markExpensesInvoiceable: api.markExpensesInvoiceable,
    markExpensesPaid: api.markExpensesPaid,
    convertExpenseCurrency: api.convertExpenseCurrency,
    invoiceExpenseDocuments: api.invoiceExpenseDocuments,
    notifyVendorWhenPaid: api.notifyVendorWhenPaid,
    calculateExpenseTaxByAmount: api.calculateExpenseTaxByAmount,
    expenseInclusiveTaxes: api.expenseInclusiveTaxes,
    expenseMailboxActive: api.expenseMailboxActive,
    expenseMailbox: api.expenseMailbox,
    inboundMailboxAllowCompanyUsers: api.inboundMailboxAllowCompanyUsers,
    inboundMailboxAllowVendors: api.inboundMailboxAllowVendors,
    inboundMailboxAllowClients: api.inboundMailboxAllowClients,
    inboundMailboxWhitelist: api.inboundMailboxWhitelist,
    inboundMailboxBlacklist: api.inboundMailboxBlacklist,
    inboundMailboxAllowUnknown: api.inboundMailboxAllowUnknown,
    smtpHost: api.smtpHost,
    smtpPort: api.smtpPort,
    smtpEncryption: api.smtpEncryption,
    smtpUsername: api.smtpUsername,
    smtpPassword: api.smtpPassword,
    smtpLocalDomain: api.smtpLocalDomain,
    smtpVerifyPeer: api.smtpVerifyPeer,
    googleAnalyticsKey: api.googleAnalyticsKey,
    matomoId: api.matomoId,
    matomoUrl: api.matomoUrl,
    sessionTimeout: api.sessionTimeout,
    defaultPasswordTimeout: api.defaultPasswordTimeout,
    oauthPasswordRequired: api.oauthPasswordRequired,
    isDisabled: api.isDisabled,
    markdownEnabled: api.markdownEnabled,
    markdownEmailEnabled: api.markdownEmailEnabled,
    reportIncludeDrafts: api.reportIncludeDrafts,
    reportIncludeDeleted: api.reportIncludeDeleted,
    quickbooks: api.quickbooks,
    documents: api.documents.map(Document.fromApi).toList(growable: false),
    updatedAt: api.updatedAt,
    archivedAt: api.archivedAt,
  );

  /// Build the PUT body. The `settings` map merges `rawSettings` (so unknown
  /// server keys round-trip) with the typed `settings.toJson()` (so the
  /// user's typed edits win).
  Map<String, dynamic> toApiJson() {
    final mergedSettings = <String, dynamic>{
      ...rawSettings,
      ...settings.toJson(),
    };
    return CompanyApi(
      id: id,
      displayName: displayName,
      name: name,
      companyKey: companyKey,
      sizeId: sizeId,
      industryId: industryId,
      firstMonthOfYear: firstMonthOfYear,
      firstDayOfWeek: firstDayOfWeek,
      useCommaAsDecimalPlace: useCommaAsDecimalPlace,
      enabledModules: enabledModules,
      legalEntityId: legalEntityId,
      hasEInvoiceCertificate: hasEInvoiceCertificate,
      eInvoiceCertificatePassphrase: eInvoiceCertificatePassphrase,
      hasEInvoiceCertificatePassphrase: hasEInvoiceCertificatePassphrase,
      subdomain: subdomain,
      portalDomain: portalDomain,
      portalMode: portalMode,
      clientCanRegister: clientCanRegister,
      clientRegistrationFields: clientRegistrationFields,
      customFields: customFields,
      settings: mergedSettings,
      enableApplyingPayments: enableApplyingPayments,
      convertPaymentCurrency: convertPaymentCurrency,
      enabledTaxRates: enabledTaxRates,
      enabledItemTaxRates: enabledItemTaxRates,
      enabledExpenseTaxRates: enabledExpenseTaxRates,
      calculateTaxes: calculateTaxes,
      taxData: taxData,
      customSurchargeTaxes1: customSurchargeTaxes1,
      customSurchargeTaxes2: customSurchargeTaxes2,
      customSurchargeTaxes3: customSurchargeTaxes3,
      customSurchargeTaxes4: customSurchargeTaxes4,
      trackInventory: trackInventory,
      stockNotification: stockNotification,
      inventoryNotificationThreshold: inventoryNotificationThreshold,
      enableProductDiscount: enableProductDiscount,
      enableProductCost: enableProductCost,
      enableProductQuantity: enableProductQuantity,
      defaultQuantity: defaultQuantity,
      showProductDetails: showProductDetails,
      fillProducts: fillProducts,
      updateProducts: updateProducts,
      convertProducts: convertProducts,
      convertRateToClient: convertRateToClient,
      stopOnUnpaidRecurring: stopOnUnpaidRecurring,
      useQuoteTermsOnConversion: useQuoteTermsOnConversion,
      autoStartTasks: autoStartTasks,
      showTaskEndDate: showTaskEndDate,
      showTasksTable: showTasksTable,
      invoiceTaskDatelog: invoiceTaskDatelog,
      invoiceTaskTimelog: invoiceTaskTimelog,
      invoiceTaskHours: invoiceTaskHours,
      invoiceTaskItemDescription: invoiceTaskItemDescription,
      invoiceTaskProject: invoiceTaskProject,
      invoiceTaskProjectHeader: invoiceTaskProjectHeader,
      invoiceTaskLock: invoiceTaskLock,
      invoiceTaskDocuments: invoiceTaskDocuments,
      markExpensesInvoiceable: markExpensesInvoiceable,
      markExpensesPaid: markExpensesPaid,
      convertExpenseCurrency: convertExpenseCurrency,
      invoiceExpenseDocuments: invoiceExpenseDocuments,
      notifyVendorWhenPaid: notifyVendorWhenPaid,
      calculateExpenseTaxByAmount: calculateExpenseTaxByAmount,
      expenseInclusiveTaxes: expenseInclusiveTaxes,
      expenseMailboxActive: expenseMailboxActive,
      expenseMailbox: expenseMailbox,
      inboundMailboxAllowCompanyUsers: inboundMailboxAllowCompanyUsers,
      inboundMailboxAllowVendors: inboundMailboxAllowVendors,
      inboundMailboxAllowClients: inboundMailboxAllowClients,
      inboundMailboxWhitelist: inboundMailboxWhitelist,
      inboundMailboxBlacklist: inboundMailboxBlacklist,
      inboundMailboxAllowUnknown: inboundMailboxAllowUnknown,
      smtpHost: smtpHost,
      smtpPort: smtpPort,
      smtpEncryption: smtpEncryption,
      smtpUsername: smtpUsername,
      smtpPassword: smtpPassword,
      smtpLocalDomain: smtpLocalDomain,
      smtpVerifyPeer: smtpVerifyPeer,
      googleAnalyticsKey: googleAnalyticsKey,
      matomoId: matomoId,
      matomoUrl: matomoUrl,
      sessionTimeout: sessionTimeout,
      defaultPasswordTimeout: defaultPasswordTimeout,
      oauthPasswordRequired: oauthPasswordRequired,
      isDisabled: isDisabled,
      markdownEnabled: markdownEnabled,
      markdownEmailEnabled: markdownEmailEnabled,
      reportIncludeDrafts: reportIncludeDrafts,
      reportIncludeDeleted: reportIncludeDeleted,
      quickbooks: quickbooks,
      updatedAt: updatedAt,
      archivedAt: archivedAt,
    ).toJson();
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'company_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CompanyApi {

 String get id;@JsonKey(name: 'display_name') String get displayName; String get name;@JsonKey(name: 'company_key') String get companyKey;@JsonKey(name: 'size_id') String get sizeId;@JsonKey(name: 'industry_id') String get industryId;@JsonKey(name: 'first_month_of_year') String get firstMonthOfYear;@JsonKey(name: 'first_day_of_week') String get firstDayOfWeek;@JsonKey(name: 'use_comma_as_decimal_place') bool get useCommaAsDecimalPlace;@JsonKey(name: 'enabled_modules') int get enabledModules;@JsonKey(name: 'legal_entity_id') int get legalEntityId;@JsonKey(name: 'has_e_invoice_certificate') bool get hasEInvoiceCertificate;@JsonKey(name: 'e_invoice_certificate_passphrase') String get eInvoiceCertificatePassphrase;@JsonKey(name: 'has_e_invoice_certificate_passphrase') bool get hasEInvoiceCertificatePassphrase;@JsonKey(name: 'subdomain') String get subdomain;@JsonKey(name: 'portal_domain') String get portalDomain;@JsonKey(name: 'portal_mode') String get portalMode;@JsonKey(name: 'client_can_register') bool get clientCanRegister;@JsonKey(name: 'client_registration_fields') List<ClientRegistrationFieldApi> get clientRegistrationFields;@JsonKey(name: 'custom_fields') Map<String, String> get customFields; Map<String, dynamic> get settings;@JsonKey(name: 'enable_applying_payments') bool get enableApplyingPayments;@JsonKey(name: 'convert_payment_currency') bool get convertPaymentCurrency;@JsonKey(name: 'enabled_tax_rates') int get enabledTaxRates;@JsonKey(name: 'enabled_item_tax_rates') int get enabledItemTaxRates;@JsonKey(name: 'enabled_expense_tax_rates') int get enabledExpenseTaxRates;@JsonKey(name: 'calculate_taxes') bool get calculateTaxes;@JsonKey(name: 'tax_data') TaxConfigApi? get taxData;@JsonKey(name: 'e_invoice', includeIfNull: false) Map<String, dynamic>? get eInvoice;@JsonKey(name: 'custom_surcharge_taxes1') bool get customSurchargeTaxes1;@JsonKey(name: 'custom_surcharge_taxes2') bool get customSurchargeTaxes2;@JsonKey(name: 'custom_surcharge_taxes3') bool get customSurchargeTaxes3;@JsonKey(name: 'custom_surcharge_taxes4') bool get customSurchargeTaxes4;@JsonKey(name: 'track_inventory') bool get trackInventory;@JsonKey(name: 'stock_notification') bool get stockNotification;@JsonKey(name: 'inventory_notification_threshold') int get inventoryNotificationThreshold;@JsonKey(name: 'enable_product_discount') bool get enableProductDiscount;@JsonKey(name: 'enable_product_cost') bool get enableProductCost;@JsonKey(name: 'enable_product_quantity') bool get enableProductQuantity;@JsonKey(name: 'default_quantity') bool get defaultQuantity;@JsonKey(name: 'show_product_details') bool get showProductDetails;@JsonKey(name: 'fill_products') bool get fillProducts;@JsonKey(name: 'update_products') bool get updateProducts;@JsonKey(name: 'convert_products') bool get convertProducts;@JsonKey(name: 'convert_rate_to_client') bool get convertRateToClient;@JsonKey(name: 'stop_on_unpaid_recurring') bool get stopOnUnpaidRecurring;@JsonKey(name: 'use_quote_terms_on_conversion') bool get useQuoteTermsOnConversion;@JsonKey(name: 'auto_start_tasks') bool get autoStartTasks;@JsonKey(name: 'show_task_end_date') bool get showTaskEndDate;@JsonKey(name: 'show_tasks_table') bool get showTasksTable;@JsonKey(name: 'invoice_task_datelog') bool get invoiceTaskDatelog;@JsonKey(name: 'invoice_task_timelog') bool get invoiceTaskTimelog;@JsonKey(name: 'invoice_task_hours') bool get invoiceTaskHours;@JsonKey(name: 'invoice_task_item_description') bool get invoiceTaskItemDescription;@JsonKey(name: 'invoice_task_project') bool get invoiceTaskProject;@JsonKey(name: 'invoice_task_project_header') bool get invoiceTaskProjectHeader;@JsonKey(name: 'invoice_task_lock') bool get invoiceTaskLock;@JsonKey(name: 'invoice_task_documents') bool get invoiceTaskDocuments;@JsonKey(name: 'mark_expenses_invoiceable') bool get markExpensesInvoiceable;@JsonKey(name: 'mark_expenses_paid') bool get markExpensesPaid;@JsonKey(name: 'convert_expense_currency') bool get convertExpenseCurrency;@JsonKey(name: 'invoice_expense_documents') bool get invoiceExpenseDocuments;@JsonKey(name: 'notify_vendor_when_paid') bool get notifyVendorWhenPaid;@JsonKey(name: 'calculate_expense_tax_by_amount') bool get calculateExpenseTaxByAmount;@JsonKey(name: 'expense_inclusive_taxes') bool get expenseInclusiveTaxes;@JsonKey(name: 'expense_mailbox_active') bool get expenseMailboxActive;@JsonKey(name: 'expense_mailbox') String get expenseMailbox;@JsonKey(name: 'inbound_mailbox_allow_company_users') bool get inboundMailboxAllowCompanyUsers;@JsonKey(name: 'inbound_mailbox_allow_vendors') bool get inboundMailboxAllowVendors;@JsonKey(name: 'inbound_mailbox_allow_clients') bool get inboundMailboxAllowClients;@JsonKey(name: 'inbound_mailbox_whitelist') String get inboundMailboxWhitelist;@JsonKey(name: 'inbound_mailbox_blacklist') String get inboundMailboxBlacklist;@JsonKey(name: 'inbound_mailbox_allow_unknown') bool get inboundMailboxAllowUnknown;@JsonKey(name: 'smtp_host') String get smtpHost;@JsonKey(name: 'smtp_port') int get smtpPort;@JsonKey(name: 'smtp_encryption') String get smtpEncryption;@JsonKey(name: 'smtp_username') String get smtpUsername;@JsonKey(name: 'smtp_password') String get smtpPassword;@JsonKey(name: 'smtp_local_domain') String get smtpLocalDomain;@JsonKey(name: 'smtp_verify_peer') bool get smtpVerifyPeer;@JsonKey(name: 'google_analytics_key') String get googleAnalyticsKey;@JsonKey(name: 'matomo_id') String get matomoId;@JsonKey(name: 'matomo_url') String get matomoUrl;@JsonKey(name: 'session_timeout') int get sessionTimeout;@JsonKey(name: 'default_password_timeout') int get defaultPasswordTimeout;@JsonKey(name: 'oauth_password_required') bool get oauthPasswordRequired;@JsonKey(name: 'is_disabled') bool get isDisabled;@JsonKey(name: 'markdown_enabled') bool get markdownEnabled;@JsonKey(name: 'markdown_email_enabled') bool get markdownEmailEnabled;@JsonKey(name: 'report_include_drafts') bool get reportIncludeDrafts;@JsonKey(name: 'report_include_deleted') bool get reportIncludeDeleted;@JsonKey(name: 'quickbooks') Map<String, dynamic>? get quickbooks; List<DocumentApi> get documents;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of CompanyApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyApiCopyWith<CompanyApi> get copyWith => _$CompanyApiCopyWithImpl<CompanyApi>(this as CompanyApi, _$identity);

  /// Serializes this CompanyApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CompanyApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyApi&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.companyKey, _this.companyKey) || other.companyKey == _this.companyKey)&&(identical(other.sizeId, _this.sizeId) || other.sizeId == _this.sizeId)&&(identical(other.industryId, _this.industryId) || other.industryId == _this.industryId)&&(identical(other.firstMonthOfYear, _this.firstMonthOfYear) || other.firstMonthOfYear == _this.firstMonthOfYear)&&(identical(other.firstDayOfWeek, _this.firstDayOfWeek) || other.firstDayOfWeek == _this.firstDayOfWeek)&&(identical(other.useCommaAsDecimalPlace, _this.useCommaAsDecimalPlace) || other.useCommaAsDecimalPlace == _this.useCommaAsDecimalPlace)&&(identical(other.enabledModules, _this.enabledModules) || other.enabledModules == _this.enabledModules)&&(identical(other.legalEntityId, _this.legalEntityId) || other.legalEntityId == _this.legalEntityId)&&(identical(other.hasEInvoiceCertificate, _this.hasEInvoiceCertificate) || other.hasEInvoiceCertificate == _this.hasEInvoiceCertificate)&&(identical(other.eInvoiceCertificatePassphrase, _this.eInvoiceCertificatePassphrase) || other.eInvoiceCertificatePassphrase == _this.eInvoiceCertificatePassphrase)&&(identical(other.hasEInvoiceCertificatePassphrase, _this.hasEInvoiceCertificatePassphrase) || other.hasEInvoiceCertificatePassphrase == _this.hasEInvoiceCertificatePassphrase)&&(identical(other.subdomain, _this.subdomain) || other.subdomain == _this.subdomain)&&(identical(other.portalDomain, _this.portalDomain) || other.portalDomain == _this.portalDomain)&&(identical(other.portalMode, _this.portalMode) || other.portalMode == _this.portalMode)&&(identical(other.clientCanRegister, _this.clientCanRegister) || other.clientCanRegister == _this.clientCanRegister)&&const DeepCollectionEquality().equals(other.clientRegistrationFields, _this.clientRegistrationFields)&&const DeepCollectionEquality().equals(other.customFields, _this.customFields)&&const DeepCollectionEquality().equals(other.settings, _this.settings)&&(identical(other.enableApplyingPayments, _this.enableApplyingPayments) || other.enableApplyingPayments == _this.enableApplyingPayments)&&(identical(other.convertPaymentCurrency, _this.convertPaymentCurrency) || other.convertPaymentCurrency == _this.convertPaymentCurrency)&&(identical(other.enabledTaxRates, _this.enabledTaxRates) || other.enabledTaxRates == _this.enabledTaxRates)&&(identical(other.enabledItemTaxRates, _this.enabledItemTaxRates) || other.enabledItemTaxRates == _this.enabledItemTaxRates)&&(identical(other.enabledExpenseTaxRates, _this.enabledExpenseTaxRates) || other.enabledExpenseTaxRates == _this.enabledExpenseTaxRates)&&(identical(other.calculateTaxes, _this.calculateTaxes) || other.calculateTaxes == _this.calculateTaxes)&&(identical(other.taxData, _this.taxData) || other.taxData == _this.taxData)&&const DeepCollectionEquality().equals(other.eInvoice, _this.eInvoice)&&(identical(other.customSurchargeTaxes1, _this.customSurchargeTaxes1) || other.customSurchargeTaxes1 == _this.customSurchargeTaxes1)&&(identical(other.customSurchargeTaxes2, _this.customSurchargeTaxes2) || other.customSurchargeTaxes2 == _this.customSurchargeTaxes2)&&(identical(other.customSurchargeTaxes3, _this.customSurchargeTaxes3) || other.customSurchargeTaxes3 == _this.customSurchargeTaxes3)&&(identical(other.customSurchargeTaxes4, _this.customSurchargeTaxes4) || other.customSurchargeTaxes4 == _this.customSurchargeTaxes4)&&(identical(other.trackInventory, _this.trackInventory) || other.trackInventory == _this.trackInventory)&&(identical(other.stockNotification, _this.stockNotification) || other.stockNotification == _this.stockNotification)&&(identical(other.inventoryNotificationThreshold, _this.inventoryNotificationThreshold) || other.inventoryNotificationThreshold == _this.inventoryNotificationThreshold)&&(identical(other.enableProductDiscount, _this.enableProductDiscount) || other.enableProductDiscount == _this.enableProductDiscount)&&(identical(other.enableProductCost, _this.enableProductCost) || other.enableProductCost == _this.enableProductCost)&&(identical(other.enableProductQuantity, _this.enableProductQuantity) || other.enableProductQuantity == _this.enableProductQuantity)&&(identical(other.defaultQuantity, _this.defaultQuantity) || other.defaultQuantity == _this.defaultQuantity)&&(identical(other.showProductDetails, _this.showProductDetails) || other.showProductDetails == _this.showProductDetails)&&(identical(other.fillProducts, _this.fillProducts) || other.fillProducts == _this.fillProducts)&&(identical(other.updateProducts, _this.updateProducts) || other.updateProducts == _this.updateProducts)&&(identical(other.convertProducts, _this.convertProducts) || other.convertProducts == _this.convertProducts)&&(identical(other.convertRateToClient, _this.convertRateToClient) || other.convertRateToClient == _this.convertRateToClient)&&(identical(other.stopOnUnpaidRecurring, _this.stopOnUnpaidRecurring) || other.stopOnUnpaidRecurring == _this.stopOnUnpaidRecurring)&&(identical(other.useQuoteTermsOnConversion, _this.useQuoteTermsOnConversion) || other.useQuoteTermsOnConversion == _this.useQuoteTermsOnConversion)&&(identical(other.autoStartTasks, _this.autoStartTasks) || other.autoStartTasks == _this.autoStartTasks)&&(identical(other.showTaskEndDate, _this.showTaskEndDate) || other.showTaskEndDate == _this.showTaskEndDate)&&(identical(other.showTasksTable, _this.showTasksTable) || other.showTasksTable == _this.showTasksTable)&&(identical(other.invoiceTaskDatelog, _this.invoiceTaskDatelog) || other.invoiceTaskDatelog == _this.invoiceTaskDatelog)&&(identical(other.invoiceTaskTimelog, _this.invoiceTaskTimelog) || other.invoiceTaskTimelog == _this.invoiceTaskTimelog)&&(identical(other.invoiceTaskHours, _this.invoiceTaskHours) || other.invoiceTaskHours == _this.invoiceTaskHours)&&(identical(other.invoiceTaskItemDescription, _this.invoiceTaskItemDescription) || other.invoiceTaskItemDescription == _this.invoiceTaskItemDescription)&&(identical(other.invoiceTaskProject, _this.invoiceTaskProject) || other.invoiceTaskProject == _this.invoiceTaskProject)&&(identical(other.invoiceTaskProjectHeader, _this.invoiceTaskProjectHeader) || other.invoiceTaskProjectHeader == _this.invoiceTaskProjectHeader)&&(identical(other.invoiceTaskLock, _this.invoiceTaskLock) || other.invoiceTaskLock == _this.invoiceTaskLock)&&(identical(other.invoiceTaskDocuments, _this.invoiceTaskDocuments) || other.invoiceTaskDocuments == _this.invoiceTaskDocuments)&&(identical(other.markExpensesInvoiceable, _this.markExpensesInvoiceable) || other.markExpensesInvoiceable == _this.markExpensesInvoiceable)&&(identical(other.markExpensesPaid, _this.markExpensesPaid) || other.markExpensesPaid == _this.markExpensesPaid)&&(identical(other.convertExpenseCurrency, _this.convertExpenseCurrency) || other.convertExpenseCurrency == _this.convertExpenseCurrency)&&(identical(other.invoiceExpenseDocuments, _this.invoiceExpenseDocuments) || other.invoiceExpenseDocuments == _this.invoiceExpenseDocuments)&&(identical(other.notifyVendorWhenPaid, _this.notifyVendorWhenPaid) || other.notifyVendorWhenPaid == _this.notifyVendorWhenPaid)&&(identical(other.calculateExpenseTaxByAmount, _this.calculateExpenseTaxByAmount) || other.calculateExpenseTaxByAmount == _this.calculateExpenseTaxByAmount)&&(identical(other.expenseInclusiveTaxes, _this.expenseInclusiveTaxes) || other.expenseInclusiveTaxes == _this.expenseInclusiveTaxes)&&(identical(other.expenseMailboxActive, _this.expenseMailboxActive) || other.expenseMailboxActive == _this.expenseMailboxActive)&&(identical(other.expenseMailbox, _this.expenseMailbox) || other.expenseMailbox == _this.expenseMailbox)&&(identical(other.inboundMailboxAllowCompanyUsers, _this.inboundMailboxAllowCompanyUsers) || other.inboundMailboxAllowCompanyUsers == _this.inboundMailboxAllowCompanyUsers)&&(identical(other.inboundMailboxAllowVendors, _this.inboundMailboxAllowVendors) || other.inboundMailboxAllowVendors == _this.inboundMailboxAllowVendors)&&(identical(other.inboundMailboxAllowClients, _this.inboundMailboxAllowClients) || other.inboundMailboxAllowClients == _this.inboundMailboxAllowClients)&&(identical(other.inboundMailboxWhitelist, _this.inboundMailboxWhitelist) || other.inboundMailboxWhitelist == _this.inboundMailboxWhitelist)&&(identical(other.inboundMailboxBlacklist, _this.inboundMailboxBlacklist) || other.inboundMailboxBlacklist == _this.inboundMailboxBlacklist)&&(identical(other.inboundMailboxAllowUnknown, _this.inboundMailboxAllowUnknown) || other.inboundMailboxAllowUnknown == _this.inboundMailboxAllowUnknown)&&(identical(other.smtpHost, _this.smtpHost) || other.smtpHost == _this.smtpHost)&&(identical(other.smtpPort, _this.smtpPort) || other.smtpPort == _this.smtpPort)&&(identical(other.smtpEncryption, _this.smtpEncryption) || other.smtpEncryption == _this.smtpEncryption)&&(identical(other.smtpUsername, _this.smtpUsername) || other.smtpUsername == _this.smtpUsername)&&(identical(other.smtpPassword, _this.smtpPassword) || other.smtpPassword == _this.smtpPassword)&&(identical(other.smtpLocalDomain, _this.smtpLocalDomain) || other.smtpLocalDomain == _this.smtpLocalDomain)&&(identical(other.smtpVerifyPeer, _this.smtpVerifyPeer) || other.smtpVerifyPeer == _this.smtpVerifyPeer)&&(identical(other.googleAnalyticsKey, _this.googleAnalyticsKey) || other.googleAnalyticsKey == _this.googleAnalyticsKey)&&(identical(other.matomoId, _this.matomoId) || other.matomoId == _this.matomoId)&&(identical(other.matomoUrl, _this.matomoUrl) || other.matomoUrl == _this.matomoUrl)&&(identical(other.sessionTimeout, _this.sessionTimeout) || other.sessionTimeout == _this.sessionTimeout)&&(identical(other.defaultPasswordTimeout, _this.defaultPasswordTimeout) || other.defaultPasswordTimeout == _this.defaultPasswordTimeout)&&(identical(other.oauthPasswordRequired, _this.oauthPasswordRequired) || other.oauthPasswordRequired == _this.oauthPasswordRequired)&&(identical(other.isDisabled, _this.isDisabled) || other.isDisabled == _this.isDisabled)&&(identical(other.markdownEnabled, _this.markdownEnabled) || other.markdownEnabled == _this.markdownEnabled)&&(identical(other.markdownEmailEnabled, _this.markdownEmailEnabled) || other.markdownEmailEnabled == _this.markdownEmailEnabled)&&(identical(other.reportIncludeDrafts, _this.reportIncludeDrafts) || other.reportIncludeDrafts == _this.reportIncludeDrafts)&&(identical(other.reportIncludeDeleted, _this.reportIncludeDeleted) || other.reportIncludeDeleted == _this.reportIncludeDeleted)&&const DeepCollectionEquality().equals(other.quickbooks, _this.quickbooks)&&const DeepCollectionEquality().equals(other.documents, _this.documents)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CompanyApi;
  return Object.hashAll([runtimeType,_this.id,_this.displayName,_this.name,_this.companyKey,_this.sizeId,_this.industryId,_this.firstMonthOfYear,_this.firstDayOfWeek,_this.useCommaAsDecimalPlace,_this.enabledModules,_this.legalEntityId,_this.hasEInvoiceCertificate,_this.eInvoiceCertificatePassphrase,_this.hasEInvoiceCertificatePassphrase,_this.subdomain,_this.portalDomain,_this.portalMode,_this.clientCanRegister,const DeepCollectionEquality().hash(_this.clientRegistrationFields),const DeepCollectionEquality().hash(_this.customFields),const DeepCollectionEquality().hash(_this.settings),_this.enableApplyingPayments,_this.convertPaymentCurrency,_this.enabledTaxRates,_this.enabledItemTaxRates,_this.enabledExpenseTaxRates,_this.calculateTaxes,_this.taxData,const DeepCollectionEquality().hash(_this.eInvoice),_this.customSurchargeTaxes1,_this.customSurchargeTaxes2,_this.customSurchargeTaxes3,_this.customSurchargeTaxes4,_this.trackInventory,_this.stockNotification,_this.inventoryNotificationThreshold,_this.enableProductDiscount,_this.enableProductCost,_this.enableProductQuantity,_this.defaultQuantity,_this.showProductDetails,_this.fillProducts,_this.updateProducts,_this.convertProducts,_this.convertRateToClient,_this.stopOnUnpaidRecurring,_this.useQuoteTermsOnConversion,_this.autoStartTasks,_this.showTaskEndDate,_this.showTasksTable,_this.invoiceTaskDatelog,_this.invoiceTaskTimelog,_this.invoiceTaskHours,_this.invoiceTaskItemDescription,_this.invoiceTaskProject,_this.invoiceTaskProjectHeader,_this.invoiceTaskLock,_this.invoiceTaskDocuments,_this.markExpensesInvoiceable,_this.markExpensesPaid,_this.convertExpenseCurrency,_this.invoiceExpenseDocuments,_this.notifyVendorWhenPaid,_this.calculateExpenseTaxByAmount,_this.expenseInclusiveTaxes,_this.expenseMailboxActive,_this.expenseMailbox,_this.inboundMailboxAllowCompanyUsers,_this.inboundMailboxAllowVendors,_this.inboundMailboxAllowClients,_this.inboundMailboxWhitelist,_this.inboundMailboxBlacklist,_this.inboundMailboxAllowUnknown,_this.smtpHost,_this.smtpPort,_this.smtpEncryption,_this.smtpUsername,_this.smtpPassword,_this.smtpLocalDomain,_this.smtpVerifyPeer,_this.googleAnalyticsKey,_this.matomoId,_this.matomoUrl,_this.sessionTimeout,_this.defaultPasswordTimeout,_this.oauthPasswordRequired,_this.isDisabled,_this.markdownEnabled,_this.markdownEmailEnabled,_this.reportIncludeDrafts,_this.reportIncludeDeleted,const DeepCollectionEquality().hash(_this.quickbooks),const DeepCollectionEquality().hash(_this.documents),_this.updatedAt,_this.archivedAt]);
}

@override
String toString() {
  final _this = this as CompanyApi;
  return 'CompanyApi(id: ${_this.id}, displayName: ${_this.displayName}, name: ${_this.name}, companyKey: ${_this.companyKey}, sizeId: ${_this.sizeId}, industryId: ${_this.industryId}, firstMonthOfYear: ${_this.firstMonthOfYear}, firstDayOfWeek: ${_this.firstDayOfWeek}, useCommaAsDecimalPlace: ${_this.useCommaAsDecimalPlace}, enabledModules: ${_this.enabledModules}, legalEntityId: ${_this.legalEntityId}, hasEInvoiceCertificate: ${_this.hasEInvoiceCertificate}, eInvoiceCertificatePassphrase: ${_this.eInvoiceCertificatePassphrase}, hasEInvoiceCertificatePassphrase: ${_this.hasEInvoiceCertificatePassphrase}, subdomain: ${_this.subdomain}, portalDomain: ${_this.portalDomain}, portalMode: ${_this.portalMode}, clientCanRegister: ${_this.clientCanRegister}, clientRegistrationFields: ${_this.clientRegistrationFields}, customFields: ${_this.customFields}, settings: ${_this.settings}, enableApplyingPayments: ${_this.enableApplyingPayments}, convertPaymentCurrency: ${_this.convertPaymentCurrency}, enabledTaxRates: ${_this.enabledTaxRates}, enabledItemTaxRates: ${_this.enabledItemTaxRates}, enabledExpenseTaxRates: ${_this.enabledExpenseTaxRates}, calculateTaxes: ${_this.calculateTaxes}, taxData: ${_this.taxData}, eInvoice: ${_this.eInvoice}, customSurchargeTaxes1: ${_this.customSurchargeTaxes1}, customSurchargeTaxes2: ${_this.customSurchargeTaxes2}, customSurchargeTaxes3: ${_this.customSurchargeTaxes3}, customSurchargeTaxes4: ${_this.customSurchargeTaxes4}, trackInventory: ${_this.trackInventory}, stockNotification: ${_this.stockNotification}, inventoryNotificationThreshold: ${_this.inventoryNotificationThreshold}, enableProductDiscount: ${_this.enableProductDiscount}, enableProductCost: ${_this.enableProductCost}, enableProductQuantity: ${_this.enableProductQuantity}, defaultQuantity: ${_this.defaultQuantity}, showProductDetails: ${_this.showProductDetails}, fillProducts: ${_this.fillProducts}, updateProducts: ${_this.updateProducts}, convertProducts: ${_this.convertProducts}, convertRateToClient: ${_this.convertRateToClient}, stopOnUnpaidRecurring: ${_this.stopOnUnpaidRecurring}, useQuoteTermsOnConversion: ${_this.useQuoteTermsOnConversion}, autoStartTasks: ${_this.autoStartTasks}, showTaskEndDate: ${_this.showTaskEndDate}, showTasksTable: ${_this.showTasksTable}, invoiceTaskDatelog: ${_this.invoiceTaskDatelog}, invoiceTaskTimelog: ${_this.invoiceTaskTimelog}, invoiceTaskHours: ${_this.invoiceTaskHours}, invoiceTaskItemDescription: ${_this.invoiceTaskItemDescription}, invoiceTaskProject: ${_this.invoiceTaskProject}, invoiceTaskProjectHeader: ${_this.invoiceTaskProjectHeader}, invoiceTaskLock: ${_this.invoiceTaskLock}, invoiceTaskDocuments: ${_this.invoiceTaskDocuments}, markExpensesInvoiceable: ${_this.markExpensesInvoiceable}, markExpensesPaid: ${_this.markExpensesPaid}, convertExpenseCurrency: ${_this.convertExpenseCurrency}, invoiceExpenseDocuments: ${_this.invoiceExpenseDocuments}, notifyVendorWhenPaid: ${_this.notifyVendorWhenPaid}, calculateExpenseTaxByAmount: ${_this.calculateExpenseTaxByAmount}, expenseInclusiveTaxes: ${_this.expenseInclusiveTaxes}, expenseMailboxActive: ${_this.expenseMailboxActive}, expenseMailbox: ${_this.expenseMailbox}, inboundMailboxAllowCompanyUsers: ${_this.inboundMailboxAllowCompanyUsers}, inboundMailboxAllowVendors: ${_this.inboundMailboxAllowVendors}, inboundMailboxAllowClients: ${_this.inboundMailboxAllowClients}, inboundMailboxWhitelist: ${_this.inboundMailboxWhitelist}, inboundMailboxBlacklist: ${_this.inboundMailboxBlacklist}, inboundMailboxAllowUnknown: ${_this.inboundMailboxAllowUnknown}, smtpHost: ${_this.smtpHost}, smtpPort: ${_this.smtpPort}, smtpEncryption: ${_this.smtpEncryption}, smtpUsername: ${_this.smtpUsername}, smtpPassword: ${_this.smtpPassword}, smtpLocalDomain: ${_this.smtpLocalDomain}, smtpVerifyPeer: ${_this.smtpVerifyPeer}, googleAnalyticsKey: ${_this.googleAnalyticsKey}, matomoId: ${_this.matomoId}, matomoUrl: ${_this.matomoUrl}, sessionTimeout: ${_this.sessionTimeout}, defaultPasswordTimeout: ${_this.defaultPasswordTimeout}, oauthPasswordRequired: ${_this.oauthPasswordRequired}, isDisabled: ${_this.isDisabled}, markdownEnabled: ${_this.markdownEnabled}, markdownEmailEnabled: ${_this.markdownEmailEnabled}, reportIncludeDrafts: ${_this.reportIncludeDrafts}, reportIncludeDeleted: ${_this.reportIncludeDeleted}, quickbooks: ${_this.quickbooks}, documents: ${_this.documents}, updatedAt: ${_this.updatedAt}, archivedAt: ${_this.archivedAt})';
}


}

/// @nodoc
abstract mixin class $CompanyApiCopyWith<$Res>  {
  factory $CompanyApiCopyWith(CompanyApi value, $Res Function(CompanyApi) _then) = _$CompanyApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'display_name') String displayName, String name,@JsonKey(name: 'company_key') String companyKey,@JsonKey(name: 'size_id') String sizeId,@JsonKey(name: 'industry_id') String industryId,@JsonKey(name: 'first_month_of_year') String firstMonthOfYear,@JsonKey(name: 'first_day_of_week') String firstDayOfWeek,@JsonKey(name: 'use_comma_as_decimal_place') bool useCommaAsDecimalPlace,@JsonKey(name: 'enabled_modules') int enabledModules,@JsonKey(name: 'legal_entity_id') int legalEntityId,@JsonKey(name: 'has_e_invoice_certificate') bool hasEInvoiceCertificate,@JsonKey(name: 'e_invoice_certificate_passphrase') String eInvoiceCertificatePassphrase,@JsonKey(name: 'has_e_invoice_certificate_passphrase') bool hasEInvoiceCertificatePassphrase,@JsonKey(name: 'subdomain') String subdomain,@JsonKey(name: 'portal_domain') String portalDomain,@JsonKey(name: 'portal_mode') String portalMode,@JsonKey(name: 'client_can_register') bool clientCanRegister,@JsonKey(name: 'client_registration_fields') List<ClientRegistrationFieldApi> clientRegistrationFields,@JsonKey(name: 'custom_fields') Map<String, String> customFields, Map<String, dynamic> settings,@JsonKey(name: 'enable_applying_payments') bool enableApplyingPayments,@JsonKey(name: 'convert_payment_currency') bool convertPaymentCurrency,@JsonKey(name: 'enabled_tax_rates') int enabledTaxRates,@JsonKey(name: 'enabled_item_tax_rates') int enabledItemTaxRates,@JsonKey(name: 'enabled_expense_tax_rates') int enabledExpenseTaxRates,@JsonKey(name: 'calculate_taxes') bool calculateTaxes,@JsonKey(name: 'tax_data') TaxConfigApi? taxData,@JsonKey(name: 'e_invoice', includeIfNull: false) Map<String, dynamic>? eInvoice,@JsonKey(name: 'custom_surcharge_taxes1') bool customSurchargeTaxes1,@JsonKey(name: 'custom_surcharge_taxes2') bool customSurchargeTaxes2,@JsonKey(name: 'custom_surcharge_taxes3') bool customSurchargeTaxes3,@JsonKey(name: 'custom_surcharge_taxes4') bool customSurchargeTaxes4,@JsonKey(name: 'track_inventory') bool trackInventory,@JsonKey(name: 'stock_notification') bool stockNotification,@JsonKey(name: 'inventory_notification_threshold') int inventoryNotificationThreshold,@JsonKey(name: 'enable_product_discount') bool enableProductDiscount,@JsonKey(name: 'enable_product_cost') bool enableProductCost,@JsonKey(name: 'enable_product_quantity') bool enableProductQuantity,@JsonKey(name: 'default_quantity') bool defaultQuantity,@JsonKey(name: 'show_product_details') bool showProductDetails,@JsonKey(name: 'fill_products') bool fillProducts,@JsonKey(name: 'update_products') bool updateProducts,@JsonKey(name: 'convert_products') bool convertProducts,@JsonKey(name: 'convert_rate_to_client') bool convertRateToClient,@JsonKey(name: 'stop_on_unpaid_recurring') bool stopOnUnpaidRecurring,@JsonKey(name: 'use_quote_terms_on_conversion') bool useQuoteTermsOnConversion,@JsonKey(name: 'auto_start_tasks') bool autoStartTasks,@JsonKey(name: 'show_task_end_date') bool showTaskEndDate,@JsonKey(name: 'show_tasks_table') bool showTasksTable,@JsonKey(name: 'invoice_task_datelog') bool invoiceTaskDatelog,@JsonKey(name: 'invoice_task_timelog') bool invoiceTaskTimelog,@JsonKey(name: 'invoice_task_hours') bool invoiceTaskHours,@JsonKey(name: 'invoice_task_item_description') bool invoiceTaskItemDescription,@JsonKey(name: 'invoice_task_project') bool invoiceTaskProject,@JsonKey(name: 'invoice_task_project_header') bool invoiceTaskProjectHeader,@JsonKey(name: 'invoice_task_lock') bool invoiceTaskLock,@JsonKey(name: 'invoice_task_documents') bool invoiceTaskDocuments,@JsonKey(name: 'mark_expenses_invoiceable') bool markExpensesInvoiceable,@JsonKey(name: 'mark_expenses_paid') bool markExpensesPaid,@JsonKey(name: 'convert_expense_currency') bool convertExpenseCurrency,@JsonKey(name: 'invoice_expense_documents') bool invoiceExpenseDocuments,@JsonKey(name: 'notify_vendor_when_paid') bool notifyVendorWhenPaid,@JsonKey(name: 'calculate_expense_tax_by_amount') bool calculateExpenseTaxByAmount,@JsonKey(name: 'expense_inclusive_taxes') bool expenseInclusiveTaxes,@JsonKey(name: 'expense_mailbox_active') bool expenseMailboxActive,@JsonKey(name: 'expense_mailbox') String expenseMailbox,@JsonKey(name: 'inbound_mailbox_allow_company_users') bool inboundMailboxAllowCompanyUsers,@JsonKey(name: 'inbound_mailbox_allow_vendors') bool inboundMailboxAllowVendors,@JsonKey(name: 'inbound_mailbox_allow_clients') bool inboundMailboxAllowClients,@JsonKey(name: 'inbound_mailbox_whitelist') String inboundMailboxWhitelist,@JsonKey(name: 'inbound_mailbox_blacklist') String inboundMailboxBlacklist,@JsonKey(name: 'inbound_mailbox_allow_unknown') bool inboundMailboxAllowUnknown,@JsonKey(name: 'smtp_host') String smtpHost,@JsonKey(name: 'smtp_port') int smtpPort,@JsonKey(name: 'smtp_encryption') String smtpEncryption,@JsonKey(name: 'smtp_username') String smtpUsername,@JsonKey(name: 'smtp_password') String smtpPassword,@JsonKey(name: 'smtp_local_domain') String smtpLocalDomain,@JsonKey(name: 'smtp_verify_peer') bool smtpVerifyPeer,@JsonKey(name: 'google_analytics_key') String googleAnalyticsKey,@JsonKey(name: 'matomo_id') String matomoId,@JsonKey(name: 'matomo_url') String matomoUrl,@JsonKey(name: 'session_timeout') int sessionTimeout,@JsonKey(name: 'default_password_timeout') int defaultPasswordTimeout,@JsonKey(name: 'oauth_password_required') bool oauthPasswordRequired,@JsonKey(name: 'is_disabled') bool isDisabled,@JsonKey(name: 'markdown_enabled') bool markdownEnabled,@JsonKey(name: 'markdown_email_enabled') bool markdownEmailEnabled,@JsonKey(name: 'report_include_drafts') bool reportIncludeDrafts,@JsonKey(name: 'report_include_deleted') bool reportIncludeDeleted,@JsonKey(name: 'quickbooks') Map<String, dynamic>? quickbooks, List<DocumentApi> documents,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});


$TaxConfigApiCopyWith<$Res>? get taxData;

}
/// @nodoc
class _$CompanyApiCopyWithImpl<$Res>
    implements $CompanyApiCopyWith<$Res> {
  _$CompanyApiCopyWithImpl(this._self, this._then);

  final CompanyApi _self;
  final $Res Function(CompanyApi) _then;

/// Create a copy of CompanyApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? name = null,Object? companyKey = null,Object? sizeId = null,Object? industryId = null,Object? firstMonthOfYear = null,Object? firstDayOfWeek = null,Object? useCommaAsDecimalPlace = null,Object? enabledModules = null,Object? legalEntityId = null,Object? hasEInvoiceCertificate = null,Object? eInvoiceCertificatePassphrase = null,Object? hasEInvoiceCertificatePassphrase = null,Object? subdomain = null,Object? portalDomain = null,Object? portalMode = null,Object? clientCanRegister = null,Object? clientRegistrationFields = null,Object? customFields = null,Object? settings = null,Object? enableApplyingPayments = null,Object? convertPaymentCurrency = null,Object? enabledTaxRates = null,Object? enabledItemTaxRates = null,Object? enabledExpenseTaxRates = null,Object? calculateTaxes = null,Object? taxData = freezed,Object? eInvoice = freezed,Object? customSurchargeTaxes1 = null,Object? customSurchargeTaxes2 = null,Object? customSurchargeTaxes3 = null,Object? customSurchargeTaxes4 = null,Object? trackInventory = null,Object? stockNotification = null,Object? inventoryNotificationThreshold = null,Object? enableProductDiscount = null,Object? enableProductCost = null,Object? enableProductQuantity = null,Object? defaultQuantity = null,Object? showProductDetails = null,Object? fillProducts = null,Object? updateProducts = null,Object? convertProducts = null,Object? convertRateToClient = null,Object? stopOnUnpaidRecurring = null,Object? useQuoteTermsOnConversion = null,Object? autoStartTasks = null,Object? showTaskEndDate = null,Object? showTasksTable = null,Object? invoiceTaskDatelog = null,Object? invoiceTaskTimelog = null,Object? invoiceTaskHours = null,Object? invoiceTaskItemDescription = null,Object? invoiceTaskProject = null,Object? invoiceTaskProjectHeader = null,Object? invoiceTaskLock = null,Object? invoiceTaskDocuments = null,Object? markExpensesInvoiceable = null,Object? markExpensesPaid = null,Object? convertExpenseCurrency = null,Object? invoiceExpenseDocuments = null,Object? notifyVendorWhenPaid = null,Object? calculateExpenseTaxByAmount = null,Object? expenseInclusiveTaxes = null,Object? expenseMailboxActive = null,Object? expenseMailbox = null,Object? inboundMailboxAllowCompanyUsers = null,Object? inboundMailboxAllowVendors = null,Object? inboundMailboxAllowClients = null,Object? inboundMailboxWhitelist = null,Object? inboundMailboxBlacklist = null,Object? inboundMailboxAllowUnknown = null,Object? smtpHost = null,Object? smtpPort = null,Object? smtpEncryption = null,Object? smtpUsername = null,Object? smtpPassword = null,Object? smtpLocalDomain = null,Object? smtpVerifyPeer = null,Object? googleAnalyticsKey = null,Object? matomoId = null,Object? matomoUrl = null,Object? sessionTimeout = null,Object? defaultPasswordTimeout = null,Object? oauthPasswordRequired = null,Object? isDisabled = null,Object? markdownEnabled = null,Object? markdownEmailEnabled = null,Object? reportIncludeDrafts = null,Object? reportIncludeDeleted = null,Object? quickbooks = freezed,Object? documents = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(CompanyApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,companyKey: null == companyKey ? _self.companyKey : companyKey // ignore: cast_nullable_to_non_nullable
as String,sizeId: null == sizeId ? _self.sizeId : sizeId // ignore: cast_nullable_to_non_nullable
as String,industryId: null == industryId ? _self.industryId : industryId // ignore: cast_nullable_to_non_nullable
as String,firstMonthOfYear: null == firstMonthOfYear ? _self.firstMonthOfYear : firstMonthOfYear // ignore: cast_nullable_to_non_nullable
as String,firstDayOfWeek: null == firstDayOfWeek ? _self.firstDayOfWeek : firstDayOfWeek // ignore: cast_nullable_to_non_nullable
as String,useCommaAsDecimalPlace: null == useCommaAsDecimalPlace ? _self.useCommaAsDecimalPlace : useCommaAsDecimalPlace // ignore: cast_nullable_to_non_nullable
as bool,enabledModules: null == enabledModules ? _self.enabledModules : enabledModules // ignore: cast_nullable_to_non_nullable
as int,legalEntityId: null == legalEntityId ? _self.legalEntityId : legalEntityId // ignore: cast_nullable_to_non_nullable
as int,hasEInvoiceCertificate: null == hasEInvoiceCertificate ? _self.hasEInvoiceCertificate : hasEInvoiceCertificate // ignore: cast_nullable_to_non_nullable
as bool,eInvoiceCertificatePassphrase: null == eInvoiceCertificatePassphrase ? _self.eInvoiceCertificatePassphrase : eInvoiceCertificatePassphrase // ignore: cast_nullable_to_non_nullable
as String,hasEInvoiceCertificatePassphrase: null == hasEInvoiceCertificatePassphrase ? _self.hasEInvoiceCertificatePassphrase : hasEInvoiceCertificatePassphrase // ignore: cast_nullable_to_non_nullable
as bool,subdomain: null == subdomain ? _self.subdomain : subdomain // ignore: cast_nullable_to_non_nullable
as String,portalDomain: null == portalDomain ? _self.portalDomain : portalDomain // ignore: cast_nullable_to_non_nullable
as String,portalMode: null == portalMode ? _self.portalMode : portalMode // ignore: cast_nullable_to_non_nullable
as String,clientCanRegister: null == clientCanRegister ? _self.clientCanRegister : clientCanRegister // ignore: cast_nullable_to_non_nullable
as bool,clientRegistrationFields: null == clientRegistrationFields ? _self.clientRegistrationFields : clientRegistrationFields // ignore: cast_nullable_to_non_nullable
as List<ClientRegistrationFieldApi>,customFields: null == customFields ? _self.customFields : customFields // ignore: cast_nullable_to_non_nullable
as Map<String, String>,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,enableApplyingPayments: null == enableApplyingPayments ? _self.enableApplyingPayments : enableApplyingPayments // ignore: cast_nullable_to_non_nullable
as bool,convertPaymentCurrency: null == convertPaymentCurrency ? _self.convertPaymentCurrency : convertPaymentCurrency // ignore: cast_nullable_to_non_nullable
as bool,enabledTaxRates: null == enabledTaxRates ? _self.enabledTaxRates : enabledTaxRates // ignore: cast_nullable_to_non_nullable
as int,enabledItemTaxRates: null == enabledItemTaxRates ? _self.enabledItemTaxRates : enabledItemTaxRates // ignore: cast_nullable_to_non_nullable
as int,enabledExpenseTaxRates: null == enabledExpenseTaxRates ? _self.enabledExpenseTaxRates : enabledExpenseTaxRates // ignore: cast_nullable_to_non_nullable
as int,calculateTaxes: null == calculateTaxes ? _self.calculateTaxes : calculateTaxes // ignore: cast_nullable_to_non_nullable
as bool,taxData: freezed == taxData ? _self.taxData : taxData // ignore: cast_nullable_to_non_nullable
as TaxConfigApi?,eInvoice: freezed == eInvoice ? _self.eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,customSurchargeTaxes1: null == customSurchargeTaxes1 ? _self.customSurchargeTaxes1 : customSurchargeTaxes1 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes2: null == customSurchargeTaxes2 ? _self.customSurchargeTaxes2 : customSurchargeTaxes2 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes3: null == customSurchargeTaxes3 ? _self.customSurchargeTaxes3 : customSurchargeTaxes3 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes4: null == customSurchargeTaxes4 ? _self.customSurchargeTaxes4 : customSurchargeTaxes4 // ignore: cast_nullable_to_non_nullable
as bool,trackInventory: null == trackInventory ? _self.trackInventory : trackInventory // ignore: cast_nullable_to_non_nullable
as bool,stockNotification: null == stockNotification ? _self.stockNotification : stockNotification // ignore: cast_nullable_to_non_nullable
as bool,inventoryNotificationThreshold: null == inventoryNotificationThreshold ? _self.inventoryNotificationThreshold : inventoryNotificationThreshold // ignore: cast_nullable_to_non_nullable
as int,enableProductDiscount: null == enableProductDiscount ? _self.enableProductDiscount : enableProductDiscount // ignore: cast_nullable_to_non_nullable
as bool,enableProductCost: null == enableProductCost ? _self.enableProductCost : enableProductCost // ignore: cast_nullable_to_non_nullable
as bool,enableProductQuantity: null == enableProductQuantity ? _self.enableProductQuantity : enableProductQuantity // ignore: cast_nullable_to_non_nullable
as bool,defaultQuantity: null == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as bool,showProductDetails: null == showProductDetails ? _self.showProductDetails : showProductDetails // ignore: cast_nullable_to_non_nullable
as bool,fillProducts: null == fillProducts ? _self.fillProducts : fillProducts // ignore: cast_nullable_to_non_nullable
as bool,updateProducts: null == updateProducts ? _self.updateProducts : updateProducts // ignore: cast_nullable_to_non_nullable
as bool,convertProducts: null == convertProducts ? _self.convertProducts : convertProducts // ignore: cast_nullable_to_non_nullable
as bool,convertRateToClient: null == convertRateToClient ? _self.convertRateToClient : convertRateToClient // ignore: cast_nullable_to_non_nullable
as bool,stopOnUnpaidRecurring: null == stopOnUnpaidRecurring ? _self.stopOnUnpaidRecurring : stopOnUnpaidRecurring // ignore: cast_nullable_to_non_nullable
as bool,useQuoteTermsOnConversion: null == useQuoteTermsOnConversion ? _self.useQuoteTermsOnConversion : useQuoteTermsOnConversion // ignore: cast_nullable_to_non_nullable
as bool,autoStartTasks: null == autoStartTasks ? _self.autoStartTasks : autoStartTasks // ignore: cast_nullable_to_non_nullable
as bool,showTaskEndDate: null == showTaskEndDate ? _self.showTaskEndDate : showTaskEndDate // ignore: cast_nullable_to_non_nullable
as bool,showTasksTable: null == showTasksTable ? _self.showTasksTable : showTasksTable // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskDatelog: null == invoiceTaskDatelog ? _self.invoiceTaskDatelog : invoiceTaskDatelog // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskTimelog: null == invoiceTaskTimelog ? _self.invoiceTaskTimelog : invoiceTaskTimelog // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskHours: null == invoiceTaskHours ? _self.invoiceTaskHours : invoiceTaskHours // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskItemDescription: null == invoiceTaskItemDescription ? _self.invoiceTaskItemDescription : invoiceTaskItemDescription // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskProject: null == invoiceTaskProject ? _self.invoiceTaskProject : invoiceTaskProject // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskProjectHeader: null == invoiceTaskProjectHeader ? _self.invoiceTaskProjectHeader : invoiceTaskProjectHeader // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskLock: null == invoiceTaskLock ? _self.invoiceTaskLock : invoiceTaskLock // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskDocuments: null == invoiceTaskDocuments ? _self.invoiceTaskDocuments : invoiceTaskDocuments // ignore: cast_nullable_to_non_nullable
as bool,markExpensesInvoiceable: null == markExpensesInvoiceable ? _self.markExpensesInvoiceable : markExpensesInvoiceable // ignore: cast_nullable_to_non_nullable
as bool,markExpensesPaid: null == markExpensesPaid ? _self.markExpensesPaid : markExpensesPaid // ignore: cast_nullable_to_non_nullable
as bool,convertExpenseCurrency: null == convertExpenseCurrency ? _self.convertExpenseCurrency : convertExpenseCurrency // ignore: cast_nullable_to_non_nullable
as bool,invoiceExpenseDocuments: null == invoiceExpenseDocuments ? _self.invoiceExpenseDocuments : invoiceExpenseDocuments // ignore: cast_nullable_to_non_nullable
as bool,notifyVendorWhenPaid: null == notifyVendorWhenPaid ? _self.notifyVendorWhenPaid : notifyVendorWhenPaid // ignore: cast_nullable_to_non_nullable
as bool,calculateExpenseTaxByAmount: null == calculateExpenseTaxByAmount ? _self.calculateExpenseTaxByAmount : calculateExpenseTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,expenseInclusiveTaxes: null == expenseInclusiveTaxes ? _self.expenseInclusiveTaxes : expenseInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,expenseMailboxActive: null == expenseMailboxActive ? _self.expenseMailboxActive : expenseMailboxActive // ignore: cast_nullable_to_non_nullable
as bool,expenseMailbox: null == expenseMailbox ? _self.expenseMailbox : expenseMailbox // ignore: cast_nullable_to_non_nullable
as String,inboundMailboxAllowCompanyUsers: null == inboundMailboxAllowCompanyUsers ? _self.inboundMailboxAllowCompanyUsers : inboundMailboxAllowCompanyUsers // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowVendors: null == inboundMailboxAllowVendors ? _self.inboundMailboxAllowVendors : inboundMailboxAllowVendors // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowClients: null == inboundMailboxAllowClients ? _self.inboundMailboxAllowClients : inboundMailboxAllowClients // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxWhitelist: null == inboundMailboxWhitelist ? _self.inboundMailboxWhitelist : inboundMailboxWhitelist // ignore: cast_nullable_to_non_nullable
as String,inboundMailboxBlacklist: null == inboundMailboxBlacklist ? _self.inboundMailboxBlacklist : inboundMailboxBlacklist // ignore: cast_nullable_to_non_nullable
as String,inboundMailboxAllowUnknown: null == inboundMailboxAllowUnknown ? _self.inboundMailboxAllowUnknown : inboundMailboxAllowUnknown // ignore: cast_nullable_to_non_nullable
as bool,smtpHost: null == smtpHost ? _self.smtpHost : smtpHost // ignore: cast_nullable_to_non_nullable
as String,smtpPort: null == smtpPort ? _self.smtpPort : smtpPort // ignore: cast_nullable_to_non_nullable
as int,smtpEncryption: null == smtpEncryption ? _self.smtpEncryption : smtpEncryption // ignore: cast_nullable_to_non_nullable
as String,smtpUsername: null == smtpUsername ? _self.smtpUsername : smtpUsername // ignore: cast_nullable_to_non_nullable
as String,smtpPassword: null == smtpPassword ? _self.smtpPassword : smtpPassword // ignore: cast_nullable_to_non_nullable
as String,smtpLocalDomain: null == smtpLocalDomain ? _self.smtpLocalDomain : smtpLocalDomain // ignore: cast_nullable_to_non_nullable
as String,smtpVerifyPeer: null == smtpVerifyPeer ? _self.smtpVerifyPeer : smtpVerifyPeer // ignore: cast_nullable_to_non_nullable
as bool,googleAnalyticsKey: null == googleAnalyticsKey ? _self.googleAnalyticsKey : googleAnalyticsKey // ignore: cast_nullable_to_non_nullable
as String,matomoId: null == matomoId ? _self.matomoId : matomoId // ignore: cast_nullable_to_non_nullable
as String,matomoUrl: null == matomoUrl ? _self.matomoUrl : matomoUrl // ignore: cast_nullable_to_non_nullable
as String,sessionTimeout: null == sessionTimeout ? _self.sessionTimeout : sessionTimeout // ignore: cast_nullable_to_non_nullable
as int,defaultPasswordTimeout: null == defaultPasswordTimeout ? _self.defaultPasswordTimeout : defaultPasswordTimeout // ignore: cast_nullable_to_non_nullable
as int,oauthPasswordRequired: null == oauthPasswordRequired ? _self.oauthPasswordRequired : oauthPasswordRequired // ignore: cast_nullable_to_non_nullable
as bool,isDisabled: null == isDisabled ? _self.isDisabled : isDisabled // ignore: cast_nullable_to_non_nullable
as bool,markdownEnabled: null == markdownEnabled ? _self.markdownEnabled : markdownEnabled // ignore: cast_nullable_to_non_nullable
as bool,markdownEmailEnabled: null == markdownEmailEnabled ? _self.markdownEmailEnabled : markdownEmailEnabled // ignore: cast_nullable_to_non_nullable
as bool,reportIncludeDrafts: null == reportIncludeDrafts ? _self.reportIncludeDrafts : reportIncludeDrafts // ignore: cast_nullable_to_non_nullable
as bool,reportIncludeDeleted: null == reportIncludeDeleted ? _self.reportIncludeDeleted : reportIncludeDeleted // ignore: cast_nullable_to_non_nullable
as bool,quickbooks: freezed == quickbooks ? _self.quickbooks : quickbooks // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of CompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaxConfigApiCopyWith<$Res>? get taxData {
    if (_self.taxData == null) {
    return null;
  }

  return $TaxConfigApiCopyWith<$Res>(_self.taxData!, (value) {
    return _then(_self.copyWith(taxData: value));
  });
}
}


/// Adds pattern-matching-related methods to [CompanyApi].
extension CompanyApiPatterns on CompanyApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyApi value)  $default,){
final _that = this;
switch (_that) {
case _CompanyApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyApi value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'display_name')  String displayName,  String name, @JsonKey(name: 'company_key')  String companyKey, @JsonKey(name: 'size_id')  String sizeId, @JsonKey(name: 'industry_id')  String industryId, @JsonKey(name: 'first_month_of_year')  String firstMonthOfYear, @JsonKey(name: 'first_day_of_week')  String firstDayOfWeek, @JsonKey(name: 'use_comma_as_decimal_place')  bool useCommaAsDecimalPlace, @JsonKey(name: 'enabled_modules')  int enabledModules, @JsonKey(name: 'legal_entity_id')  int legalEntityId, @JsonKey(name: 'has_e_invoice_certificate')  bool hasEInvoiceCertificate, @JsonKey(name: 'e_invoice_certificate_passphrase')  String eInvoiceCertificatePassphrase, @JsonKey(name: 'has_e_invoice_certificate_passphrase')  bool hasEInvoiceCertificatePassphrase, @JsonKey(name: 'subdomain')  String subdomain, @JsonKey(name: 'portal_domain')  String portalDomain, @JsonKey(name: 'portal_mode')  String portalMode, @JsonKey(name: 'client_can_register')  bool clientCanRegister, @JsonKey(name: 'client_registration_fields')  List<ClientRegistrationFieldApi> clientRegistrationFields, @JsonKey(name: 'custom_fields')  Map<String, String> customFields,  Map<String, dynamic> settings, @JsonKey(name: 'enable_applying_payments')  bool enableApplyingPayments, @JsonKey(name: 'convert_payment_currency')  bool convertPaymentCurrency, @JsonKey(name: 'enabled_tax_rates')  int enabledTaxRates, @JsonKey(name: 'enabled_item_tax_rates')  int enabledItemTaxRates, @JsonKey(name: 'enabled_expense_tax_rates')  int enabledExpenseTaxRates, @JsonKey(name: 'calculate_taxes')  bool calculateTaxes, @JsonKey(name: 'tax_data')  TaxConfigApi? taxData, @JsonKey(name: 'e_invoice', includeIfNull: false)  Map<String, dynamic>? eInvoice, @JsonKey(name: 'custom_surcharge_taxes1')  bool customSurchargeTaxes1, @JsonKey(name: 'custom_surcharge_taxes2')  bool customSurchargeTaxes2, @JsonKey(name: 'custom_surcharge_taxes3')  bool customSurchargeTaxes3, @JsonKey(name: 'custom_surcharge_taxes4')  bool customSurchargeTaxes4, @JsonKey(name: 'track_inventory')  bool trackInventory, @JsonKey(name: 'stock_notification')  bool stockNotification, @JsonKey(name: 'inventory_notification_threshold')  int inventoryNotificationThreshold, @JsonKey(name: 'enable_product_discount')  bool enableProductDiscount, @JsonKey(name: 'enable_product_cost')  bool enableProductCost, @JsonKey(name: 'enable_product_quantity')  bool enableProductQuantity, @JsonKey(name: 'default_quantity')  bool defaultQuantity, @JsonKey(name: 'show_product_details')  bool showProductDetails, @JsonKey(name: 'fill_products')  bool fillProducts, @JsonKey(name: 'update_products')  bool updateProducts, @JsonKey(name: 'convert_products')  bool convertProducts, @JsonKey(name: 'convert_rate_to_client')  bool convertRateToClient, @JsonKey(name: 'stop_on_unpaid_recurring')  bool stopOnUnpaidRecurring, @JsonKey(name: 'use_quote_terms_on_conversion')  bool useQuoteTermsOnConversion, @JsonKey(name: 'auto_start_tasks')  bool autoStartTasks, @JsonKey(name: 'show_task_end_date')  bool showTaskEndDate, @JsonKey(name: 'show_tasks_table')  bool showTasksTable, @JsonKey(name: 'invoice_task_datelog')  bool invoiceTaskDatelog, @JsonKey(name: 'invoice_task_timelog')  bool invoiceTaskTimelog, @JsonKey(name: 'invoice_task_hours')  bool invoiceTaskHours, @JsonKey(name: 'invoice_task_item_description')  bool invoiceTaskItemDescription, @JsonKey(name: 'invoice_task_project')  bool invoiceTaskProject, @JsonKey(name: 'invoice_task_project_header')  bool invoiceTaskProjectHeader, @JsonKey(name: 'invoice_task_lock')  bool invoiceTaskLock, @JsonKey(name: 'invoice_task_documents')  bool invoiceTaskDocuments, @JsonKey(name: 'mark_expenses_invoiceable')  bool markExpensesInvoiceable, @JsonKey(name: 'mark_expenses_paid')  bool markExpensesPaid, @JsonKey(name: 'convert_expense_currency')  bool convertExpenseCurrency, @JsonKey(name: 'invoice_expense_documents')  bool invoiceExpenseDocuments, @JsonKey(name: 'notify_vendor_when_paid')  bool notifyVendorWhenPaid, @JsonKey(name: 'calculate_expense_tax_by_amount')  bool calculateExpenseTaxByAmount, @JsonKey(name: 'expense_inclusive_taxes')  bool expenseInclusiveTaxes, @JsonKey(name: 'expense_mailbox_active')  bool expenseMailboxActive, @JsonKey(name: 'expense_mailbox')  String expenseMailbox, @JsonKey(name: 'inbound_mailbox_allow_company_users')  bool inboundMailboxAllowCompanyUsers, @JsonKey(name: 'inbound_mailbox_allow_vendors')  bool inboundMailboxAllowVendors, @JsonKey(name: 'inbound_mailbox_allow_clients')  bool inboundMailboxAllowClients, @JsonKey(name: 'inbound_mailbox_whitelist')  String inboundMailboxWhitelist, @JsonKey(name: 'inbound_mailbox_blacklist')  String inboundMailboxBlacklist, @JsonKey(name: 'inbound_mailbox_allow_unknown')  bool inboundMailboxAllowUnknown, @JsonKey(name: 'smtp_host')  String smtpHost, @JsonKey(name: 'smtp_port')  int smtpPort, @JsonKey(name: 'smtp_encryption')  String smtpEncryption, @JsonKey(name: 'smtp_username')  String smtpUsername, @JsonKey(name: 'smtp_password')  String smtpPassword, @JsonKey(name: 'smtp_local_domain')  String smtpLocalDomain, @JsonKey(name: 'smtp_verify_peer')  bool smtpVerifyPeer, @JsonKey(name: 'google_analytics_key')  String googleAnalyticsKey, @JsonKey(name: 'matomo_id')  String matomoId, @JsonKey(name: 'matomo_url')  String matomoUrl, @JsonKey(name: 'session_timeout')  int sessionTimeout, @JsonKey(name: 'default_password_timeout')  int defaultPasswordTimeout, @JsonKey(name: 'oauth_password_required')  bool oauthPasswordRequired, @JsonKey(name: 'is_disabled')  bool isDisabled, @JsonKey(name: 'markdown_enabled')  bool markdownEnabled, @JsonKey(name: 'markdown_email_enabled')  bool markdownEmailEnabled, @JsonKey(name: 'report_include_drafts')  bool reportIncludeDrafts, @JsonKey(name: 'report_include_deleted')  bool reportIncludeDeleted, @JsonKey(name: 'quickbooks')  Map<String, dynamic>? quickbooks,  List<DocumentApi> documents, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyApi() when $default != null:
return $default(_that.id,_that.displayName,_that.name,_that.companyKey,_that.sizeId,_that.industryId,_that.firstMonthOfYear,_that.firstDayOfWeek,_that.useCommaAsDecimalPlace,_that.enabledModules,_that.legalEntityId,_that.hasEInvoiceCertificate,_that.eInvoiceCertificatePassphrase,_that.hasEInvoiceCertificatePassphrase,_that.subdomain,_that.portalDomain,_that.portalMode,_that.clientCanRegister,_that.clientRegistrationFields,_that.customFields,_that.settings,_that.enableApplyingPayments,_that.convertPaymentCurrency,_that.enabledTaxRates,_that.enabledItemTaxRates,_that.enabledExpenseTaxRates,_that.calculateTaxes,_that.taxData,_that.eInvoice,_that.customSurchargeTaxes1,_that.customSurchargeTaxes2,_that.customSurchargeTaxes3,_that.customSurchargeTaxes4,_that.trackInventory,_that.stockNotification,_that.inventoryNotificationThreshold,_that.enableProductDiscount,_that.enableProductCost,_that.enableProductQuantity,_that.defaultQuantity,_that.showProductDetails,_that.fillProducts,_that.updateProducts,_that.convertProducts,_that.convertRateToClient,_that.stopOnUnpaidRecurring,_that.useQuoteTermsOnConversion,_that.autoStartTasks,_that.showTaskEndDate,_that.showTasksTable,_that.invoiceTaskDatelog,_that.invoiceTaskTimelog,_that.invoiceTaskHours,_that.invoiceTaskItemDescription,_that.invoiceTaskProject,_that.invoiceTaskProjectHeader,_that.invoiceTaskLock,_that.invoiceTaskDocuments,_that.markExpensesInvoiceable,_that.markExpensesPaid,_that.convertExpenseCurrency,_that.invoiceExpenseDocuments,_that.notifyVendorWhenPaid,_that.calculateExpenseTaxByAmount,_that.expenseInclusiveTaxes,_that.expenseMailboxActive,_that.expenseMailbox,_that.inboundMailboxAllowCompanyUsers,_that.inboundMailboxAllowVendors,_that.inboundMailboxAllowClients,_that.inboundMailboxWhitelist,_that.inboundMailboxBlacklist,_that.inboundMailboxAllowUnknown,_that.smtpHost,_that.smtpPort,_that.smtpEncryption,_that.smtpUsername,_that.smtpPassword,_that.smtpLocalDomain,_that.smtpVerifyPeer,_that.googleAnalyticsKey,_that.matomoId,_that.matomoUrl,_that.sessionTimeout,_that.defaultPasswordTimeout,_that.oauthPasswordRequired,_that.isDisabled,_that.markdownEnabled,_that.markdownEmailEnabled,_that.reportIncludeDrafts,_that.reportIncludeDeleted,_that.quickbooks,_that.documents,_that.updatedAt,_that.archivedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'display_name')  String displayName,  String name, @JsonKey(name: 'company_key')  String companyKey, @JsonKey(name: 'size_id')  String sizeId, @JsonKey(name: 'industry_id')  String industryId, @JsonKey(name: 'first_month_of_year')  String firstMonthOfYear, @JsonKey(name: 'first_day_of_week')  String firstDayOfWeek, @JsonKey(name: 'use_comma_as_decimal_place')  bool useCommaAsDecimalPlace, @JsonKey(name: 'enabled_modules')  int enabledModules, @JsonKey(name: 'legal_entity_id')  int legalEntityId, @JsonKey(name: 'has_e_invoice_certificate')  bool hasEInvoiceCertificate, @JsonKey(name: 'e_invoice_certificate_passphrase')  String eInvoiceCertificatePassphrase, @JsonKey(name: 'has_e_invoice_certificate_passphrase')  bool hasEInvoiceCertificatePassphrase, @JsonKey(name: 'subdomain')  String subdomain, @JsonKey(name: 'portal_domain')  String portalDomain, @JsonKey(name: 'portal_mode')  String portalMode, @JsonKey(name: 'client_can_register')  bool clientCanRegister, @JsonKey(name: 'client_registration_fields')  List<ClientRegistrationFieldApi> clientRegistrationFields, @JsonKey(name: 'custom_fields')  Map<String, String> customFields,  Map<String, dynamic> settings, @JsonKey(name: 'enable_applying_payments')  bool enableApplyingPayments, @JsonKey(name: 'convert_payment_currency')  bool convertPaymentCurrency, @JsonKey(name: 'enabled_tax_rates')  int enabledTaxRates, @JsonKey(name: 'enabled_item_tax_rates')  int enabledItemTaxRates, @JsonKey(name: 'enabled_expense_tax_rates')  int enabledExpenseTaxRates, @JsonKey(name: 'calculate_taxes')  bool calculateTaxes, @JsonKey(name: 'tax_data')  TaxConfigApi? taxData, @JsonKey(name: 'e_invoice', includeIfNull: false)  Map<String, dynamic>? eInvoice, @JsonKey(name: 'custom_surcharge_taxes1')  bool customSurchargeTaxes1, @JsonKey(name: 'custom_surcharge_taxes2')  bool customSurchargeTaxes2, @JsonKey(name: 'custom_surcharge_taxes3')  bool customSurchargeTaxes3, @JsonKey(name: 'custom_surcharge_taxes4')  bool customSurchargeTaxes4, @JsonKey(name: 'track_inventory')  bool trackInventory, @JsonKey(name: 'stock_notification')  bool stockNotification, @JsonKey(name: 'inventory_notification_threshold')  int inventoryNotificationThreshold, @JsonKey(name: 'enable_product_discount')  bool enableProductDiscount, @JsonKey(name: 'enable_product_cost')  bool enableProductCost, @JsonKey(name: 'enable_product_quantity')  bool enableProductQuantity, @JsonKey(name: 'default_quantity')  bool defaultQuantity, @JsonKey(name: 'show_product_details')  bool showProductDetails, @JsonKey(name: 'fill_products')  bool fillProducts, @JsonKey(name: 'update_products')  bool updateProducts, @JsonKey(name: 'convert_products')  bool convertProducts, @JsonKey(name: 'convert_rate_to_client')  bool convertRateToClient, @JsonKey(name: 'stop_on_unpaid_recurring')  bool stopOnUnpaidRecurring, @JsonKey(name: 'use_quote_terms_on_conversion')  bool useQuoteTermsOnConversion, @JsonKey(name: 'auto_start_tasks')  bool autoStartTasks, @JsonKey(name: 'show_task_end_date')  bool showTaskEndDate, @JsonKey(name: 'show_tasks_table')  bool showTasksTable, @JsonKey(name: 'invoice_task_datelog')  bool invoiceTaskDatelog, @JsonKey(name: 'invoice_task_timelog')  bool invoiceTaskTimelog, @JsonKey(name: 'invoice_task_hours')  bool invoiceTaskHours, @JsonKey(name: 'invoice_task_item_description')  bool invoiceTaskItemDescription, @JsonKey(name: 'invoice_task_project')  bool invoiceTaskProject, @JsonKey(name: 'invoice_task_project_header')  bool invoiceTaskProjectHeader, @JsonKey(name: 'invoice_task_lock')  bool invoiceTaskLock, @JsonKey(name: 'invoice_task_documents')  bool invoiceTaskDocuments, @JsonKey(name: 'mark_expenses_invoiceable')  bool markExpensesInvoiceable, @JsonKey(name: 'mark_expenses_paid')  bool markExpensesPaid, @JsonKey(name: 'convert_expense_currency')  bool convertExpenseCurrency, @JsonKey(name: 'invoice_expense_documents')  bool invoiceExpenseDocuments, @JsonKey(name: 'notify_vendor_when_paid')  bool notifyVendorWhenPaid, @JsonKey(name: 'calculate_expense_tax_by_amount')  bool calculateExpenseTaxByAmount, @JsonKey(name: 'expense_inclusive_taxes')  bool expenseInclusiveTaxes, @JsonKey(name: 'expense_mailbox_active')  bool expenseMailboxActive, @JsonKey(name: 'expense_mailbox')  String expenseMailbox, @JsonKey(name: 'inbound_mailbox_allow_company_users')  bool inboundMailboxAllowCompanyUsers, @JsonKey(name: 'inbound_mailbox_allow_vendors')  bool inboundMailboxAllowVendors, @JsonKey(name: 'inbound_mailbox_allow_clients')  bool inboundMailboxAllowClients, @JsonKey(name: 'inbound_mailbox_whitelist')  String inboundMailboxWhitelist, @JsonKey(name: 'inbound_mailbox_blacklist')  String inboundMailboxBlacklist, @JsonKey(name: 'inbound_mailbox_allow_unknown')  bool inboundMailboxAllowUnknown, @JsonKey(name: 'smtp_host')  String smtpHost, @JsonKey(name: 'smtp_port')  int smtpPort, @JsonKey(name: 'smtp_encryption')  String smtpEncryption, @JsonKey(name: 'smtp_username')  String smtpUsername, @JsonKey(name: 'smtp_password')  String smtpPassword, @JsonKey(name: 'smtp_local_domain')  String smtpLocalDomain, @JsonKey(name: 'smtp_verify_peer')  bool smtpVerifyPeer, @JsonKey(name: 'google_analytics_key')  String googleAnalyticsKey, @JsonKey(name: 'matomo_id')  String matomoId, @JsonKey(name: 'matomo_url')  String matomoUrl, @JsonKey(name: 'session_timeout')  int sessionTimeout, @JsonKey(name: 'default_password_timeout')  int defaultPasswordTimeout, @JsonKey(name: 'oauth_password_required')  bool oauthPasswordRequired, @JsonKey(name: 'is_disabled')  bool isDisabled, @JsonKey(name: 'markdown_enabled')  bool markdownEnabled, @JsonKey(name: 'markdown_email_enabled')  bool markdownEmailEnabled, @JsonKey(name: 'report_include_drafts')  bool reportIncludeDrafts, @JsonKey(name: 'report_include_deleted')  bool reportIncludeDeleted, @JsonKey(name: 'quickbooks')  Map<String, dynamic>? quickbooks,  List<DocumentApi> documents, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _CompanyApi():
return $default(_that.id,_that.displayName,_that.name,_that.companyKey,_that.sizeId,_that.industryId,_that.firstMonthOfYear,_that.firstDayOfWeek,_that.useCommaAsDecimalPlace,_that.enabledModules,_that.legalEntityId,_that.hasEInvoiceCertificate,_that.eInvoiceCertificatePassphrase,_that.hasEInvoiceCertificatePassphrase,_that.subdomain,_that.portalDomain,_that.portalMode,_that.clientCanRegister,_that.clientRegistrationFields,_that.customFields,_that.settings,_that.enableApplyingPayments,_that.convertPaymentCurrency,_that.enabledTaxRates,_that.enabledItemTaxRates,_that.enabledExpenseTaxRates,_that.calculateTaxes,_that.taxData,_that.eInvoice,_that.customSurchargeTaxes1,_that.customSurchargeTaxes2,_that.customSurchargeTaxes3,_that.customSurchargeTaxes4,_that.trackInventory,_that.stockNotification,_that.inventoryNotificationThreshold,_that.enableProductDiscount,_that.enableProductCost,_that.enableProductQuantity,_that.defaultQuantity,_that.showProductDetails,_that.fillProducts,_that.updateProducts,_that.convertProducts,_that.convertRateToClient,_that.stopOnUnpaidRecurring,_that.useQuoteTermsOnConversion,_that.autoStartTasks,_that.showTaskEndDate,_that.showTasksTable,_that.invoiceTaskDatelog,_that.invoiceTaskTimelog,_that.invoiceTaskHours,_that.invoiceTaskItemDescription,_that.invoiceTaskProject,_that.invoiceTaskProjectHeader,_that.invoiceTaskLock,_that.invoiceTaskDocuments,_that.markExpensesInvoiceable,_that.markExpensesPaid,_that.convertExpenseCurrency,_that.invoiceExpenseDocuments,_that.notifyVendorWhenPaid,_that.calculateExpenseTaxByAmount,_that.expenseInclusiveTaxes,_that.expenseMailboxActive,_that.expenseMailbox,_that.inboundMailboxAllowCompanyUsers,_that.inboundMailboxAllowVendors,_that.inboundMailboxAllowClients,_that.inboundMailboxWhitelist,_that.inboundMailboxBlacklist,_that.inboundMailboxAllowUnknown,_that.smtpHost,_that.smtpPort,_that.smtpEncryption,_that.smtpUsername,_that.smtpPassword,_that.smtpLocalDomain,_that.smtpVerifyPeer,_that.googleAnalyticsKey,_that.matomoId,_that.matomoUrl,_that.sessionTimeout,_that.defaultPasswordTimeout,_that.oauthPasswordRequired,_that.isDisabled,_that.markdownEnabled,_that.markdownEmailEnabled,_that.reportIncludeDrafts,_that.reportIncludeDeleted,_that.quickbooks,_that.documents,_that.updatedAt,_that.archivedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'display_name')  String displayName,  String name, @JsonKey(name: 'company_key')  String companyKey, @JsonKey(name: 'size_id')  String sizeId, @JsonKey(name: 'industry_id')  String industryId, @JsonKey(name: 'first_month_of_year')  String firstMonthOfYear, @JsonKey(name: 'first_day_of_week')  String firstDayOfWeek, @JsonKey(name: 'use_comma_as_decimal_place')  bool useCommaAsDecimalPlace, @JsonKey(name: 'enabled_modules')  int enabledModules, @JsonKey(name: 'legal_entity_id')  int legalEntityId, @JsonKey(name: 'has_e_invoice_certificate')  bool hasEInvoiceCertificate, @JsonKey(name: 'e_invoice_certificate_passphrase')  String eInvoiceCertificatePassphrase, @JsonKey(name: 'has_e_invoice_certificate_passphrase')  bool hasEInvoiceCertificatePassphrase, @JsonKey(name: 'subdomain')  String subdomain, @JsonKey(name: 'portal_domain')  String portalDomain, @JsonKey(name: 'portal_mode')  String portalMode, @JsonKey(name: 'client_can_register')  bool clientCanRegister, @JsonKey(name: 'client_registration_fields')  List<ClientRegistrationFieldApi> clientRegistrationFields, @JsonKey(name: 'custom_fields')  Map<String, String> customFields,  Map<String, dynamic> settings, @JsonKey(name: 'enable_applying_payments')  bool enableApplyingPayments, @JsonKey(name: 'convert_payment_currency')  bool convertPaymentCurrency, @JsonKey(name: 'enabled_tax_rates')  int enabledTaxRates, @JsonKey(name: 'enabled_item_tax_rates')  int enabledItemTaxRates, @JsonKey(name: 'enabled_expense_tax_rates')  int enabledExpenseTaxRates, @JsonKey(name: 'calculate_taxes')  bool calculateTaxes, @JsonKey(name: 'tax_data')  TaxConfigApi? taxData, @JsonKey(name: 'e_invoice', includeIfNull: false)  Map<String, dynamic>? eInvoice, @JsonKey(name: 'custom_surcharge_taxes1')  bool customSurchargeTaxes1, @JsonKey(name: 'custom_surcharge_taxes2')  bool customSurchargeTaxes2, @JsonKey(name: 'custom_surcharge_taxes3')  bool customSurchargeTaxes3, @JsonKey(name: 'custom_surcharge_taxes4')  bool customSurchargeTaxes4, @JsonKey(name: 'track_inventory')  bool trackInventory, @JsonKey(name: 'stock_notification')  bool stockNotification, @JsonKey(name: 'inventory_notification_threshold')  int inventoryNotificationThreshold, @JsonKey(name: 'enable_product_discount')  bool enableProductDiscount, @JsonKey(name: 'enable_product_cost')  bool enableProductCost, @JsonKey(name: 'enable_product_quantity')  bool enableProductQuantity, @JsonKey(name: 'default_quantity')  bool defaultQuantity, @JsonKey(name: 'show_product_details')  bool showProductDetails, @JsonKey(name: 'fill_products')  bool fillProducts, @JsonKey(name: 'update_products')  bool updateProducts, @JsonKey(name: 'convert_products')  bool convertProducts, @JsonKey(name: 'convert_rate_to_client')  bool convertRateToClient, @JsonKey(name: 'stop_on_unpaid_recurring')  bool stopOnUnpaidRecurring, @JsonKey(name: 'use_quote_terms_on_conversion')  bool useQuoteTermsOnConversion, @JsonKey(name: 'auto_start_tasks')  bool autoStartTasks, @JsonKey(name: 'show_task_end_date')  bool showTaskEndDate, @JsonKey(name: 'show_tasks_table')  bool showTasksTable, @JsonKey(name: 'invoice_task_datelog')  bool invoiceTaskDatelog, @JsonKey(name: 'invoice_task_timelog')  bool invoiceTaskTimelog, @JsonKey(name: 'invoice_task_hours')  bool invoiceTaskHours, @JsonKey(name: 'invoice_task_item_description')  bool invoiceTaskItemDescription, @JsonKey(name: 'invoice_task_project')  bool invoiceTaskProject, @JsonKey(name: 'invoice_task_project_header')  bool invoiceTaskProjectHeader, @JsonKey(name: 'invoice_task_lock')  bool invoiceTaskLock, @JsonKey(name: 'invoice_task_documents')  bool invoiceTaskDocuments, @JsonKey(name: 'mark_expenses_invoiceable')  bool markExpensesInvoiceable, @JsonKey(name: 'mark_expenses_paid')  bool markExpensesPaid, @JsonKey(name: 'convert_expense_currency')  bool convertExpenseCurrency, @JsonKey(name: 'invoice_expense_documents')  bool invoiceExpenseDocuments, @JsonKey(name: 'notify_vendor_when_paid')  bool notifyVendorWhenPaid, @JsonKey(name: 'calculate_expense_tax_by_amount')  bool calculateExpenseTaxByAmount, @JsonKey(name: 'expense_inclusive_taxes')  bool expenseInclusiveTaxes, @JsonKey(name: 'expense_mailbox_active')  bool expenseMailboxActive, @JsonKey(name: 'expense_mailbox')  String expenseMailbox, @JsonKey(name: 'inbound_mailbox_allow_company_users')  bool inboundMailboxAllowCompanyUsers, @JsonKey(name: 'inbound_mailbox_allow_vendors')  bool inboundMailboxAllowVendors, @JsonKey(name: 'inbound_mailbox_allow_clients')  bool inboundMailboxAllowClients, @JsonKey(name: 'inbound_mailbox_whitelist')  String inboundMailboxWhitelist, @JsonKey(name: 'inbound_mailbox_blacklist')  String inboundMailboxBlacklist, @JsonKey(name: 'inbound_mailbox_allow_unknown')  bool inboundMailboxAllowUnknown, @JsonKey(name: 'smtp_host')  String smtpHost, @JsonKey(name: 'smtp_port')  int smtpPort, @JsonKey(name: 'smtp_encryption')  String smtpEncryption, @JsonKey(name: 'smtp_username')  String smtpUsername, @JsonKey(name: 'smtp_password')  String smtpPassword, @JsonKey(name: 'smtp_local_domain')  String smtpLocalDomain, @JsonKey(name: 'smtp_verify_peer')  bool smtpVerifyPeer, @JsonKey(name: 'google_analytics_key')  String googleAnalyticsKey, @JsonKey(name: 'matomo_id')  String matomoId, @JsonKey(name: 'matomo_url')  String matomoUrl, @JsonKey(name: 'session_timeout')  int sessionTimeout, @JsonKey(name: 'default_password_timeout')  int defaultPasswordTimeout, @JsonKey(name: 'oauth_password_required')  bool oauthPasswordRequired, @JsonKey(name: 'is_disabled')  bool isDisabled, @JsonKey(name: 'markdown_enabled')  bool markdownEnabled, @JsonKey(name: 'markdown_email_enabled')  bool markdownEmailEnabled, @JsonKey(name: 'report_include_drafts')  bool reportIncludeDrafts, @JsonKey(name: 'report_include_deleted')  bool reportIncludeDeleted, @JsonKey(name: 'quickbooks')  Map<String, dynamic>? quickbooks,  List<DocumentApi> documents, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _CompanyApi() when $default != null:
return $default(_that.id,_that.displayName,_that.name,_that.companyKey,_that.sizeId,_that.industryId,_that.firstMonthOfYear,_that.firstDayOfWeek,_that.useCommaAsDecimalPlace,_that.enabledModules,_that.legalEntityId,_that.hasEInvoiceCertificate,_that.eInvoiceCertificatePassphrase,_that.hasEInvoiceCertificatePassphrase,_that.subdomain,_that.portalDomain,_that.portalMode,_that.clientCanRegister,_that.clientRegistrationFields,_that.customFields,_that.settings,_that.enableApplyingPayments,_that.convertPaymentCurrency,_that.enabledTaxRates,_that.enabledItemTaxRates,_that.enabledExpenseTaxRates,_that.calculateTaxes,_that.taxData,_that.eInvoice,_that.customSurchargeTaxes1,_that.customSurchargeTaxes2,_that.customSurchargeTaxes3,_that.customSurchargeTaxes4,_that.trackInventory,_that.stockNotification,_that.inventoryNotificationThreshold,_that.enableProductDiscount,_that.enableProductCost,_that.enableProductQuantity,_that.defaultQuantity,_that.showProductDetails,_that.fillProducts,_that.updateProducts,_that.convertProducts,_that.convertRateToClient,_that.stopOnUnpaidRecurring,_that.useQuoteTermsOnConversion,_that.autoStartTasks,_that.showTaskEndDate,_that.showTasksTable,_that.invoiceTaskDatelog,_that.invoiceTaskTimelog,_that.invoiceTaskHours,_that.invoiceTaskItemDescription,_that.invoiceTaskProject,_that.invoiceTaskProjectHeader,_that.invoiceTaskLock,_that.invoiceTaskDocuments,_that.markExpensesInvoiceable,_that.markExpensesPaid,_that.convertExpenseCurrency,_that.invoiceExpenseDocuments,_that.notifyVendorWhenPaid,_that.calculateExpenseTaxByAmount,_that.expenseInclusiveTaxes,_that.expenseMailboxActive,_that.expenseMailbox,_that.inboundMailboxAllowCompanyUsers,_that.inboundMailboxAllowVendors,_that.inboundMailboxAllowClients,_that.inboundMailboxWhitelist,_that.inboundMailboxBlacklist,_that.inboundMailboxAllowUnknown,_that.smtpHost,_that.smtpPort,_that.smtpEncryption,_that.smtpUsername,_that.smtpPassword,_that.smtpLocalDomain,_that.smtpVerifyPeer,_that.googleAnalyticsKey,_that.matomoId,_that.matomoUrl,_that.sessionTimeout,_that.defaultPasswordTimeout,_that.oauthPasswordRequired,_that.isDisabled,_that.markdownEnabled,_that.markdownEmailEnabled,_that.reportIncludeDrafts,_that.reportIncludeDeleted,_that.quickbooks,_that.documents,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _CompanyApi implements CompanyApi {
  const _CompanyApi({this.id = '', @JsonKey(name: 'display_name') this.displayName = '', this.name = '', @JsonKey(name: 'company_key') this.companyKey = '', @JsonKey(name: 'size_id') this.sizeId = '', @JsonKey(name: 'industry_id') this.industryId = '', @JsonKey(name: 'first_month_of_year') this.firstMonthOfYear = '', @JsonKey(name: 'first_day_of_week') this.firstDayOfWeek = '', @JsonKey(name: 'use_comma_as_decimal_place') this.useCommaAsDecimalPlace = false, @JsonKey(name: 'enabled_modules') this.enabledModules = 0, @JsonKey(name: 'legal_entity_id') this.legalEntityId = 0, @JsonKey(name: 'has_e_invoice_certificate') this.hasEInvoiceCertificate = false, @JsonKey(name: 'e_invoice_certificate_passphrase') this.eInvoiceCertificatePassphrase = '', @JsonKey(name: 'has_e_invoice_certificate_passphrase') this.hasEInvoiceCertificatePassphrase = false, @JsonKey(name: 'subdomain') this.subdomain = '', @JsonKey(name: 'portal_domain') this.portalDomain = '', @JsonKey(name: 'portal_mode') this.portalMode = '', @JsonKey(name: 'client_can_register') this.clientCanRegister = false, @JsonKey(name: 'client_registration_fields')  List<ClientRegistrationFieldApi> clientRegistrationFields = const <ClientRegistrationFieldApi>[], @JsonKey(name: 'custom_fields')  Map<String, String> customFields = const <String, String>{},  Map<String, dynamic> settings = const <String, dynamic>{}, @JsonKey(name: 'enable_applying_payments') this.enableApplyingPayments = false, @JsonKey(name: 'convert_payment_currency') this.convertPaymentCurrency = false, @JsonKey(name: 'enabled_tax_rates') this.enabledTaxRates = 0, @JsonKey(name: 'enabled_item_tax_rates') this.enabledItemTaxRates = 0, @JsonKey(name: 'enabled_expense_tax_rates') this.enabledExpenseTaxRates = 0, @JsonKey(name: 'calculate_taxes') this.calculateTaxes = false, @JsonKey(name: 'tax_data') this.taxData, @JsonKey(name: 'e_invoice', includeIfNull: false)  Map<String, dynamic>? eInvoice, @JsonKey(name: 'custom_surcharge_taxes1') this.customSurchargeTaxes1 = false, @JsonKey(name: 'custom_surcharge_taxes2') this.customSurchargeTaxes2 = false, @JsonKey(name: 'custom_surcharge_taxes3') this.customSurchargeTaxes3 = false, @JsonKey(name: 'custom_surcharge_taxes4') this.customSurchargeTaxes4 = false, @JsonKey(name: 'track_inventory') this.trackInventory = false, @JsonKey(name: 'stock_notification') this.stockNotification = false, @JsonKey(name: 'inventory_notification_threshold') this.inventoryNotificationThreshold = 0, @JsonKey(name: 'enable_product_discount') this.enableProductDiscount = false, @JsonKey(name: 'enable_product_cost') this.enableProductCost = false, @JsonKey(name: 'enable_product_quantity') this.enableProductQuantity = false, @JsonKey(name: 'default_quantity') this.defaultQuantity = false, @JsonKey(name: 'show_product_details') this.showProductDetails = false, @JsonKey(name: 'fill_products') this.fillProducts = false, @JsonKey(name: 'update_products') this.updateProducts = false, @JsonKey(name: 'convert_products') this.convertProducts = false, @JsonKey(name: 'convert_rate_to_client') this.convertRateToClient = false, @JsonKey(name: 'stop_on_unpaid_recurring') this.stopOnUnpaidRecurring = false, @JsonKey(name: 'use_quote_terms_on_conversion') this.useQuoteTermsOnConversion = false, @JsonKey(name: 'auto_start_tasks') this.autoStartTasks = false, @JsonKey(name: 'show_task_end_date') this.showTaskEndDate = false, @JsonKey(name: 'show_tasks_table') this.showTasksTable = false, @JsonKey(name: 'invoice_task_datelog') this.invoiceTaskDatelog = false, @JsonKey(name: 'invoice_task_timelog') this.invoiceTaskTimelog = false, @JsonKey(name: 'invoice_task_hours') this.invoiceTaskHours = false, @JsonKey(name: 'invoice_task_item_description') this.invoiceTaskItemDescription = false, @JsonKey(name: 'invoice_task_project') this.invoiceTaskProject = false, @JsonKey(name: 'invoice_task_project_header') this.invoiceTaskProjectHeader = false, @JsonKey(name: 'invoice_task_lock') this.invoiceTaskLock = false, @JsonKey(name: 'invoice_task_documents') this.invoiceTaskDocuments = false, @JsonKey(name: 'mark_expenses_invoiceable') this.markExpensesInvoiceable = false, @JsonKey(name: 'mark_expenses_paid') this.markExpensesPaid = false, @JsonKey(name: 'convert_expense_currency') this.convertExpenseCurrency = false, @JsonKey(name: 'invoice_expense_documents') this.invoiceExpenseDocuments = false, @JsonKey(name: 'notify_vendor_when_paid') this.notifyVendorWhenPaid = false, @JsonKey(name: 'calculate_expense_tax_by_amount') this.calculateExpenseTaxByAmount = false, @JsonKey(name: 'expense_inclusive_taxes') this.expenseInclusiveTaxes = false, @JsonKey(name: 'expense_mailbox_active') this.expenseMailboxActive = false, @JsonKey(name: 'expense_mailbox') this.expenseMailbox = '', @JsonKey(name: 'inbound_mailbox_allow_company_users') this.inboundMailboxAllowCompanyUsers = false, @JsonKey(name: 'inbound_mailbox_allow_vendors') this.inboundMailboxAllowVendors = false, @JsonKey(name: 'inbound_mailbox_allow_clients') this.inboundMailboxAllowClients = false, @JsonKey(name: 'inbound_mailbox_whitelist') this.inboundMailboxWhitelist = '', @JsonKey(name: 'inbound_mailbox_blacklist') this.inboundMailboxBlacklist = '', @JsonKey(name: 'inbound_mailbox_allow_unknown') this.inboundMailboxAllowUnknown = false, @JsonKey(name: 'smtp_host') this.smtpHost = '', @JsonKey(name: 'smtp_port') this.smtpPort = 0, @JsonKey(name: 'smtp_encryption') this.smtpEncryption = 'TLS', @JsonKey(name: 'smtp_username') this.smtpUsername = '', @JsonKey(name: 'smtp_password') this.smtpPassword = '', @JsonKey(name: 'smtp_local_domain') this.smtpLocalDomain = '', @JsonKey(name: 'smtp_verify_peer') this.smtpVerifyPeer = true, @JsonKey(name: 'google_analytics_key') this.googleAnalyticsKey = '', @JsonKey(name: 'matomo_id') this.matomoId = '', @JsonKey(name: 'matomo_url') this.matomoUrl = '', @JsonKey(name: 'session_timeout') this.sessionTimeout = 0, @JsonKey(name: 'default_password_timeout') this.defaultPasswordTimeout = 0, @JsonKey(name: 'oauth_password_required') this.oauthPasswordRequired = false, @JsonKey(name: 'is_disabled') this.isDisabled = false, @JsonKey(name: 'markdown_enabled') this.markdownEnabled = false, @JsonKey(name: 'markdown_email_enabled') this.markdownEmailEnabled = false, @JsonKey(name: 'report_include_drafts') this.reportIncludeDrafts = false, @JsonKey(name: 'report_include_deleted') this.reportIncludeDeleted = false, @JsonKey(name: 'quickbooks')  Map<String, dynamic>? quickbooks,  List<DocumentApi> documents = const <DocumentApi>[], @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0}): _clientRegistrationFields = clientRegistrationFields,_customFields = customFields,_settings = settings,_eInvoice = eInvoice,_quickbooks = quickbooks,_documents = documents;
  factory _CompanyApi.fromJson(Map<String, dynamic> json) => _$CompanyApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'display_name') final  String displayName;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'company_key') final  String companyKey;
@override@JsonKey(name: 'size_id') final  String sizeId;
@override@JsonKey(name: 'industry_id') final  String industryId;
@override@JsonKey(name: 'first_month_of_year') final  String firstMonthOfYear;
@override@JsonKey(name: 'first_day_of_week') final  String firstDayOfWeek;
@override@JsonKey(name: 'use_comma_as_decimal_place') final  bool useCommaAsDecimalPlace;
@override@JsonKey(name: 'enabled_modules') final  int enabledModules;
@override@JsonKey(name: 'legal_entity_id') final  int legalEntityId;
@override@JsonKey(name: 'has_e_invoice_certificate') final  bool hasEInvoiceCertificate;
@override@JsonKey(name: 'e_invoice_certificate_passphrase') final  String eInvoiceCertificatePassphrase;
@override@JsonKey(name: 'has_e_invoice_certificate_passphrase') final  bool hasEInvoiceCertificatePassphrase;
@override@JsonKey(name: 'subdomain') final  String subdomain;
@override@JsonKey(name: 'portal_domain') final  String portalDomain;
@override@JsonKey(name: 'portal_mode') final  String portalMode;
@override@JsonKey(name: 'client_can_register') final  bool clientCanRegister;
 final  List<ClientRegistrationFieldApi> _clientRegistrationFields;
@override@JsonKey(name: 'client_registration_fields') List<ClientRegistrationFieldApi> get clientRegistrationFields {
  if (_clientRegistrationFields is EqualUnmodifiableListView) return _clientRegistrationFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clientRegistrationFields);
}

 final  Map<String, String> _customFields;
@override@JsonKey(name: 'custom_fields') Map<String, String> get customFields {
  if (_customFields is EqualUnmodifiableMapView) return _customFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_customFields);
}

 final  Map<String, dynamic> _settings;
@override@JsonKey() Map<String, dynamic> get settings {
  if (_settings is EqualUnmodifiableMapView) return _settings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_settings);
}

@override@JsonKey(name: 'enable_applying_payments') final  bool enableApplyingPayments;
@override@JsonKey(name: 'convert_payment_currency') final  bool convertPaymentCurrency;
@override@JsonKey(name: 'enabled_tax_rates') final  int enabledTaxRates;
@override@JsonKey(name: 'enabled_item_tax_rates') final  int enabledItemTaxRates;
@override@JsonKey(name: 'enabled_expense_tax_rates') final  int enabledExpenseTaxRates;
@override@JsonKey(name: 'calculate_taxes') final  bool calculateTaxes;
@override@JsonKey(name: 'tax_data') final  TaxConfigApi? taxData;
 final  Map<String, dynamic>? _eInvoice;
@override@JsonKey(name: 'e_invoice', includeIfNull: false) Map<String, dynamic>? get eInvoice {
  final value = _eInvoice;
  if (value == null) return null;
  if (_eInvoice is EqualUnmodifiableMapView) return _eInvoice;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'custom_surcharge_taxes1') final  bool customSurchargeTaxes1;
@override@JsonKey(name: 'custom_surcharge_taxes2') final  bool customSurchargeTaxes2;
@override@JsonKey(name: 'custom_surcharge_taxes3') final  bool customSurchargeTaxes3;
@override@JsonKey(name: 'custom_surcharge_taxes4') final  bool customSurchargeTaxes4;
@override@JsonKey(name: 'track_inventory') final  bool trackInventory;
@override@JsonKey(name: 'stock_notification') final  bool stockNotification;
@override@JsonKey(name: 'inventory_notification_threshold') final  int inventoryNotificationThreshold;
@override@JsonKey(name: 'enable_product_discount') final  bool enableProductDiscount;
@override@JsonKey(name: 'enable_product_cost') final  bool enableProductCost;
@override@JsonKey(name: 'enable_product_quantity') final  bool enableProductQuantity;
@override@JsonKey(name: 'default_quantity') final  bool defaultQuantity;
@override@JsonKey(name: 'show_product_details') final  bool showProductDetails;
@override@JsonKey(name: 'fill_products') final  bool fillProducts;
@override@JsonKey(name: 'update_products') final  bool updateProducts;
@override@JsonKey(name: 'convert_products') final  bool convertProducts;
@override@JsonKey(name: 'convert_rate_to_client') final  bool convertRateToClient;
@override@JsonKey(name: 'stop_on_unpaid_recurring') final  bool stopOnUnpaidRecurring;
@override@JsonKey(name: 'use_quote_terms_on_conversion') final  bool useQuoteTermsOnConversion;
@override@JsonKey(name: 'auto_start_tasks') final  bool autoStartTasks;
@override@JsonKey(name: 'show_task_end_date') final  bool showTaskEndDate;
@override@JsonKey(name: 'show_tasks_table') final  bool showTasksTable;
@override@JsonKey(name: 'invoice_task_datelog') final  bool invoiceTaskDatelog;
@override@JsonKey(name: 'invoice_task_timelog') final  bool invoiceTaskTimelog;
@override@JsonKey(name: 'invoice_task_hours') final  bool invoiceTaskHours;
@override@JsonKey(name: 'invoice_task_item_description') final  bool invoiceTaskItemDescription;
@override@JsonKey(name: 'invoice_task_project') final  bool invoiceTaskProject;
@override@JsonKey(name: 'invoice_task_project_header') final  bool invoiceTaskProjectHeader;
@override@JsonKey(name: 'invoice_task_lock') final  bool invoiceTaskLock;
@override@JsonKey(name: 'invoice_task_documents') final  bool invoiceTaskDocuments;
@override@JsonKey(name: 'mark_expenses_invoiceable') final  bool markExpensesInvoiceable;
@override@JsonKey(name: 'mark_expenses_paid') final  bool markExpensesPaid;
@override@JsonKey(name: 'convert_expense_currency') final  bool convertExpenseCurrency;
@override@JsonKey(name: 'invoice_expense_documents') final  bool invoiceExpenseDocuments;
@override@JsonKey(name: 'notify_vendor_when_paid') final  bool notifyVendorWhenPaid;
@override@JsonKey(name: 'calculate_expense_tax_by_amount') final  bool calculateExpenseTaxByAmount;
@override@JsonKey(name: 'expense_inclusive_taxes') final  bool expenseInclusiveTaxes;
@override@JsonKey(name: 'expense_mailbox_active') final  bool expenseMailboxActive;
@override@JsonKey(name: 'expense_mailbox') final  String expenseMailbox;
@override@JsonKey(name: 'inbound_mailbox_allow_company_users') final  bool inboundMailboxAllowCompanyUsers;
@override@JsonKey(name: 'inbound_mailbox_allow_vendors') final  bool inboundMailboxAllowVendors;
@override@JsonKey(name: 'inbound_mailbox_allow_clients') final  bool inboundMailboxAllowClients;
@override@JsonKey(name: 'inbound_mailbox_whitelist') final  String inboundMailboxWhitelist;
@override@JsonKey(name: 'inbound_mailbox_blacklist') final  String inboundMailboxBlacklist;
@override@JsonKey(name: 'inbound_mailbox_allow_unknown') final  bool inboundMailboxAllowUnknown;
@override@JsonKey(name: 'smtp_host') final  String smtpHost;
@override@JsonKey(name: 'smtp_port') final  int smtpPort;
@override@JsonKey(name: 'smtp_encryption') final  String smtpEncryption;
@override@JsonKey(name: 'smtp_username') final  String smtpUsername;
@override@JsonKey(name: 'smtp_password') final  String smtpPassword;
@override@JsonKey(name: 'smtp_local_domain') final  String smtpLocalDomain;
@override@JsonKey(name: 'smtp_verify_peer') final  bool smtpVerifyPeer;
@override@JsonKey(name: 'google_analytics_key') final  String googleAnalyticsKey;
@override@JsonKey(name: 'matomo_id') final  String matomoId;
@override@JsonKey(name: 'matomo_url') final  String matomoUrl;
@override@JsonKey(name: 'session_timeout') final  int sessionTimeout;
@override@JsonKey(name: 'default_password_timeout') final  int defaultPasswordTimeout;
@override@JsonKey(name: 'oauth_password_required') final  bool oauthPasswordRequired;
@override@JsonKey(name: 'is_disabled') final  bool isDisabled;
@override@JsonKey(name: 'markdown_enabled') final  bool markdownEnabled;
@override@JsonKey(name: 'markdown_email_enabled') final  bool markdownEmailEnabled;
@override@JsonKey(name: 'report_include_drafts') final  bool reportIncludeDrafts;
@override@JsonKey(name: 'report_include_deleted') final  bool reportIncludeDeleted;
 final  Map<String, dynamic>? _quickbooks;
@override@JsonKey(name: 'quickbooks') Map<String, dynamic>? get quickbooks {
  final value = _quickbooks;
  if (value == null) return null;
  if (_quickbooks is EqualUnmodifiableMapView) return _quickbooks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<DocumentApi> _documents;
@override@JsonKey() List<DocumentApi> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}

@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of CompanyApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyApiCopyWith<_CompanyApi> get copyWith => __$CompanyApiCopyWithImpl<_CompanyApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyApi&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.name, name) || other.name == name)&&(identical(other.companyKey, companyKey) || other.companyKey == companyKey)&&(identical(other.sizeId, sizeId) || other.sizeId == sizeId)&&(identical(other.industryId, industryId) || other.industryId == industryId)&&(identical(other.firstMonthOfYear, firstMonthOfYear) || other.firstMonthOfYear == firstMonthOfYear)&&(identical(other.firstDayOfWeek, firstDayOfWeek) || other.firstDayOfWeek == firstDayOfWeek)&&(identical(other.useCommaAsDecimalPlace, useCommaAsDecimalPlace) || other.useCommaAsDecimalPlace == useCommaAsDecimalPlace)&&(identical(other.enabledModules, enabledModules) || other.enabledModules == enabledModules)&&(identical(other.legalEntityId, legalEntityId) || other.legalEntityId == legalEntityId)&&(identical(other.hasEInvoiceCertificate, hasEInvoiceCertificate) || other.hasEInvoiceCertificate == hasEInvoiceCertificate)&&(identical(other.eInvoiceCertificatePassphrase, eInvoiceCertificatePassphrase) || other.eInvoiceCertificatePassphrase == eInvoiceCertificatePassphrase)&&(identical(other.hasEInvoiceCertificatePassphrase, hasEInvoiceCertificatePassphrase) || other.hasEInvoiceCertificatePassphrase == hasEInvoiceCertificatePassphrase)&&(identical(other.subdomain, subdomain) || other.subdomain == subdomain)&&(identical(other.portalDomain, portalDomain) || other.portalDomain == portalDomain)&&(identical(other.portalMode, portalMode) || other.portalMode == portalMode)&&(identical(other.clientCanRegister, clientCanRegister) || other.clientCanRegister == clientCanRegister)&&const DeepCollectionEquality().equals(other.clientRegistrationFields, _clientRegistrationFields)&&const DeepCollectionEquality().equals(other.customFields, _customFields)&&const DeepCollectionEquality().equals(other.settings, _settings)&&(identical(other.enableApplyingPayments, enableApplyingPayments) || other.enableApplyingPayments == enableApplyingPayments)&&(identical(other.convertPaymentCurrency, convertPaymentCurrency) || other.convertPaymentCurrency == convertPaymentCurrency)&&(identical(other.enabledTaxRates, enabledTaxRates) || other.enabledTaxRates == enabledTaxRates)&&(identical(other.enabledItemTaxRates, enabledItemTaxRates) || other.enabledItemTaxRates == enabledItemTaxRates)&&(identical(other.enabledExpenseTaxRates, enabledExpenseTaxRates) || other.enabledExpenseTaxRates == enabledExpenseTaxRates)&&(identical(other.calculateTaxes, calculateTaxes) || other.calculateTaxes == calculateTaxes)&&(identical(other.taxData, taxData) || other.taxData == taxData)&&const DeepCollectionEquality().equals(other.eInvoice, _eInvoice)&&(identical(other.customSurchargeTaxes1, customSurchargeTaxes1) || other.customSurchargeTaxes1 == customSurchargeTaxes1)&&(identical(other.customSurchargeTaxes2, customSurchargeTaxes2) || other.customSurchargeTaxes2 == customSurchargeTaxes2)&&(identical(other.customSurchargeTaxes3, customSurchargeTaxes3) || other.customSurchargeTaxes3 == customSurchargeTaxes3)&&(identical(other.customSurchargeTaxes4, customSurchargeTaxes4) || other.customSurchargeTaxes4 == customSurchargeTaxes4)&&(identical(other.trackInventory, trackInventory) || other.trackInventory == trackInventory)&&(identical(other.stockNotification, stockNotification) || other.stockNotification == stockNotification)&&(identical(other.inventoryNotificationThreshold, inventoryNotificationThreshold) || other.inventoryNotificationThreshold == inventoryNotificationThreshold)&&(identical(other.enableProductDiscount, enableProductDiscount) || other.enableProductDiscount == enableProductDiscount)&&(identical(other.enableProductCost, enableProductCost) || other.enableProductCost == enableProductCost)&&(identical(other.enableProductQuantity, enableProductQuantity) || other.enableProductQuantity == enableProductQuantity)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.showProductDetails, showProductDetails) || other.showProductDetails == showProductDetails)&&(identical(other.fillProducts, fillProducts) || other.fillProducts == fillProducts)&&(identical(other.updateProducts, updateProducts) || other.updateProducts == updateProducts)&&(identical(other.convertProducts, convertProducts) || other.convertProducts == convertProducts)&&(identical(other.convertRateToClient, convertRateToClient) || other.convertRateToClient == convertRateToClient)&&(identical(other.stopOnUnpaidRecurring, stopOnUnpaidRecurring) || other.stopOnUnpaidRecurring == stopOnUnpaidRecurring)&&(identical(other.useQuoteTermsOnConversion, useQuoteTermsOnConversion) || other.useQuoteTermsOnConversion == useQuoteTermsOnConversion)&&(identical(other.autoStartTasks, autoStartTasks) || other.autoStartTasks == autoStartTasks)&&(identical(other.showTaskEndDate, showTaskEndDate) || other.showTaskEndDate == showTaskEndDate)&&(identical(other.showTasksTable, showTasksTable) || other.showTasksTable == showTasksTable)&&(identical(other.invoiceTaskDatelog, invoiceTaskDatelog) || other.invoiceTaskDatelog == invoiceTaskDatelog)&&(identical(other.invoiceTaskTimelog, invoiceTaskTimelog) || other.invoiceTaskTimelog == invoiceTaskTimelog)&&(identical(other.invoiceTaskHours, invoiceTaskHours) || other.invoiceTaskHours == invoiceTaskHours)&&(identical(other.invoiceTaskItemDescription, invoiceTaskItemDescription) || other.invoiceTaskItemDescription == invoiceTaskItemDescription)&&(identical(other.invoiceTaskProject, invoiceTaskProject) || other.invoiceTaskProject == invoiceTaskProject)&&(identical(other.invoiceTaskProjectHeader, invoiceTaskProjectHeader) || other.invoiceTaskProjectHeader == invoiceTaskProjectHeader)&&(identical(other.invoiceTaskLock, invoiceTaskLock) || other.invoiceTaskLock == invoiceTaskLock)&&(identical(other.invoiceTaskDocuments, invoiceTaskDocuments) || other.invoiceTaskDocuments == invoiceTaskDocuments)&&(identical(other.markExpensesInvoiceable, markExpensesInvoiceable) || other.markExpensesInvoiceable == markExpensesInvoiceable)&&(identical(other.markExpensesPaid, markExpensesPaid) || other.markExpensesPaid == markExpensesPaid)&&(identical(other.convertExpenseCurrency, convertExpenseCurrency) || other.convertExpenseCurrency == convertExpenseCurrency)&&(identical(other.invoiceExpenseDocuments, invoiceExpenseDocuments) || other.invoiceExpenseDocuments == invoiceExpenseDocuments)&&(identical(other.notifyVendorWhenPaid, notifyVendorWhenPaid) || other.notifyVendorWhenPaid == notifyVendorWhenPaid)&&(identical(other.calculateExpenseTaxByAmount, calculateExpenseTaxByAmount) || other.calculateExpenseTaxByAmount == calculateExpenseTaxByAmount)&&(identical(other.expenseInclusiveTaxes, expenseInclusiveTaxes) || other.expenseInclusiveTaxes == expenseInclusiveTaxes)&&(identical(other.expenseMailboxActive, expenseMailboxActive) || other.expenseMailboxActive == expenseMailboxActive)&&(identical(other.expenseMailbox, expenseMailbox) || other.expenseMailbox == expenseMailbox)&&(identical(other.inboundMailboxAllowCompanyUsers, inboundMailboxAllowCompanyUsers) || other.inboundMailboxAllowCompanyUsers == inboundMailboxAllowCompanyUsers)&&(identical(other.inboundMailboxAllowVendors, inboundMailboxAllowVendors) || other.inboundMailboxAllowVendors == inboundMailboxAllowVendors)&&(identical(other.inboundMailboxAllowClients, inboundMailboxAllowClients) || other.inboundMailboxAllowClients == inboundMailboxAllowClients)&&(identical(other.inboundMailboxWhitelist, inboundMailboxWhitelist) || other.inboundMailboxWhitelist == inboundMailboxWhitelist)&&(identical(other.inboundMailboxBlacklist, inboundMailboxBlacklist) || other.inboundMailboxBlacklist == inboundMailboxBlacklist)&&(identical(other.inboundMailboxAllowUnknown, inboundMailboxAllowUnknown) || other.inboundMailboxAllowUnknown == inboundMailboxAllowUnknown)&&(identical(other.smtpHost, smtpHost) || other.smtpHost == smtpHost)&&(identical(other.smtpPort, smtpPort) || other.smtpPort == smtpPort)&&(identical(other.smtpEncryption, smtpEncryption) || other.smtpEncryption == smtpEncryption)&&(identical(other.smtpUsername, smtpUsername) || other.smtpUsername == smtpUsername)&&(identical(other.smtpPassword, smtpPassword) || other.smtpPassword == smtpPassword)&&(identical(other.smtpLocalDomain, smtpLocalDomain) || other.smtpLocalDomain == smtpLocalDomain)&&(identical(other.smtpVerifyPeer, smtpVerifyPeer) || other.smtpVerifyPeer == smtpVerifyPeer)&&(identical(other.googleAnalyticsKey, googleAnalyticsKey) || other.googleAnalyticsKey == googleAnalyticsKey)&&(identical(other.matomoId, matomoId) || other.matomoId == matomoId)&&(identical(other.matomoUrl, matomoUrl) || other.matomoUrl == matomoUrl)&&(identical(other.sessionTimeout, sessionTimeout) || other.sessionTimeout == sessionTimeout)&&(identical(other.defaultPasswordTimeout, defaultPasswordTimeout) || other.defaultPasswordTimeout == defaultPasswordTimeout)&&(identical(other.oauthPasswordRequired, oauthPasswordRequired) || other.oauthPasswordRequired == oauthPasswordRequired)&&(identical(other.isDisabled, isDisabled) || other.isDisabled == isDisabled)&&(identical(other.markdownEnabled, markdownEnabled) || other.markdownEnabled == markdownEnabled)&&(identical(other.markdownEmailEnabled, markdownEmailEnabled) || other.markdownEmailEnabled == markdownEmailEnabled)&&(identical(other.reportIncludeDrafts, reportIncludeDrafts) || other.reportIncludeDrafts == reportIncludeDrafts)&&(identical(other.reportIncludeDeleted, reportIncludeDeleted) || other.reportIncludeDeleted == reportIncludeDeleted)&&const DeepCollectionEquality().equals(other.quickbooks, _quickbooks)&&const DeepCollectionEquality().equals(other.documents, _documents)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,displayName,name,companyKey,sizeId,industryId,firstMonthOfYear,firstDayOfWeek,useCommaAsDecimalPlace,enabledModules,legalEntityId,hasEInvoiceCertificate,eInvoiceCertificatePassphrase,hasEInvoiceCertificatePassphrase,subdomain,portalDomain,portalMode,clientCanRegister,const DeepCollectionEquality().hash(_clientRegistrationFields),const DeepCollectionEquality().hash(_customFields),const DeepCollectionEquality().hash(_settings),enableApplyingPayments,convertPaymentCurrency,enabledTaxRates,enabledItemTaxRates,enabledExpenseTaxRates,calculateTaxes,taxData,const DeepCollectionEquality().hash(_eInvoice),customSurchargeTaxes1,customSurchargeTaxes2,customSurchargeTaxes3,customSurchargeTaxes4,trackInventory,stockNotification,inventoryNotificationThreshold,enableProductDiscount,enableProductCost,enableProductQuantity,defaultQuantity,showProductDetails,fillProducts,updateProducts,convertProducts,convertRateToClient,stopOnUnpaidRecurring,useQuoteTermsOnConversion,autoStartTasks,showTaskEndDate,showTasksTable,invoiceTaskDatelog,invoiceTaskTimelog,invoiceTaskHours,invoiceTaskItemDescription,invoiceTaskProject,invoiceTaskProjectHeader,invoiceTaskLock,invoiceTaskDocuments,markExpensesInvoiceable,markExpensesPaid,convertExpenseCurrency,invoiceExpenseDocuments,notifyVendorWhenPaid,calculateExpenseTaxByAmount,expenseInclusiveTaxes,expenseMailboxActive,expenseMailbox,inboundMailboxAllowCompanyUsers,inboundMailboxAllowVendors,inboundMailboxAllowClients,inboundMailboxWhitelist,inboundMailboxBlacklist,inboundMailboxAllowUnknown,smtpHost,smtpPort,smtpEncryption,smtpUsername,smtpPassword,smtpLocalDomain,smtpVerifyPeer,googleAnalyticsKey,matomoId,matomoUrl,sessionTimeout,defaultPasswordTimeout,oauthPasswordRequired,isDisabled,markdownEnabled,markdownEmailEnabled,reportIncludeDrafts,reportIncludeDeleted,const DeepCollectionEquality().hash(_quickbooks),const DeepCollectionEquality().hash(_documents),updatedAt,archivedAt]);
}

@override
String toString() {
    return 'CompanyApi(id: $id, displayName: $displayName, name: $name, companyKey: $companyKey, sizeId: $sizeId, industryId: $industryId, firstMonthOfYear: $firstMonthOfYear, firstDayOfWeek: $firstDayOfWeek, useCommaAsDecimalPlace: $useCommaAsDecimalPlace, enabledModules: $enabledModules, legalEntityId: $legalEntityId, hasEInvoiceCertificate: $hasEInvoiceCertificate, eInvoiceCertificatePassphrase: $eInvoiceCertificatePassphrase, hasEInvoiceCertificatePassphrase: $hasEInvoiceCertificatePassphrase, subdomain: $subdomain, portalDomain: $portalDomain, portalMode: $portalMode, clientCanRegister: $clientCanRegister, clientRegistrationFields: $clientRegistrationFields, customFields: $customFields, settings: $settings, enableApplyingPayments: $enableApplyingPayments, convertPaymentCurrency: $convertPaymentCurrency, enabledTaxRates: $enabledTaxRates, enabledItemTaxRates: $enabledItemTaxRates, enabledExpenseTaxRates: $enabledExpenseTaxRates, calculateTaxes: $calculateTaxes, taxData: $taxData, eInvoice: $eInvoice, customSurchargeTaxes1: $customSurchargeTaxes1, customSurchargeTaxes2: $customSurchargeTaxes2, customSurchargeTaxes3: $customSurchargeTaxes3, customSurchargeTaxes4: $customSurchargeTaxes4, trackInventory: $trackInventory, stockNotification: $stockNotification, inventoryNotificationThreshold: $inventoryNotificationThreshold, enableProductDiscount: $enableProductDiscount, enableProductCost: $enableProductCost, enableProductQuantity: $enableProductQuantity, defaultQuantity: $defaultQuantity, showProductDetails: $showProductDetails, fillProducts: $fillProducts, updateProducts: $updateProducts, convertProducts: $convertProducts, convertRateToClient: $convertRateToClient, stopOnUnpaidRecurring: $stopOnUnpaidRecurring, useQuoteTermsOnConversion: $useQuoteTermsOnConversion, autoStartTasks: $autoStartTasks, showTaskEndDate: $showTaskEndDate, showTasksTable: $showTasksTable, invoiceTaskDatelog: $invoiceTaskDatelog, invoiceTaskTimelog: $invoiceTaskTimelog, invoiceTaskHours: $invoiceTaskHours, invoiceTaskItemDescription: $invoiceTaskItemDescription, invoiceTaskProject: $invoiceTaskProject, invoiceTaskProjectHeader: $invoiceTaskProjectHeader, invoiceTaskLock: $invoiceTaskLock, invoiceTaskDocuments: $invoiceTaskDocuments, markExpensesInvoiceable: $markExpensesInvoiceable, markExpensesPaid: $markExpensesPaid, convertExpenseCurrency: $convertExpenseCurrency, invoiceExpenseDocuments: $invoiceExpenseDocuments, notifyVendorWhenPaid: $notifyVendorWhenPaid, calculateExpenseTaxByAmount: $calculateExpenseTaxByAmount, expenseInclusiveTaxes: $expenseInclusiveTaxes, expenseMailboxActive: $expenseMailboxActive, expenseMailbox: $expenseMailbox, inboundMailboxAllowCompanyUsers: $inboundMailboxAllowCompanyUsers, inboundMailboxAllowVendors: $inboundMailboxAllowVendors, inboundMailboxAllowClients: $inboundMailboxAllowClients, inboundMailboxWhitelist: $inboundMailboxWhitelist, inboundMailboxBlacklist: $inboundMailboxBlacklist, inboundMailboxAllowUnknown: $inboundMailboxAllowUnknown, smtpHost: $smtpHost, smtpPort: $smtpPort, smtpEncryption: $smtpEncryption, smtpUsername: $smtpUsername, smtpPassword: $smtpPassword, smtpLocalDomain: $smtpLocalDomain, smtpVerifyPeer: $smtpVerifyPeer, googleAnalyticsKey: $googleAnalyticsKey, matomoId: $matomoId, matomoUrl: $matomoUrl, sessionTimeout: $sessionTimeout, defaultPasswordTimeout: $defaultPasswordTimeout, oauthPasswordRequired: $oauthPasswordRequired, isDisabled: $isDisabled, markdownEnabled: $markdownEnabled, markdownEmailEnabled: $markdownEmailEnabled, reportIncludeDrafts: $reportIncludeDrafts, reportIncludeDeleted: $reportIncludeDeleted, quickbooks: $quickbooks, documents: $documents, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$CompanyApiCopyWith<$Res> implements $CompanyApiCopyWith<$Res> {
  factory _$CompanyApiCopyWith(_CompanyApi value, $Res Function(_CompanyApi) _then) = __$CompanyApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'display_name') String displayName, String name,@JsonKey(name: 'company_key') String companyKey,@JsonKey(name: 'size_id') String sizeId,@JsonKey(name: 'industry_id') String industryId,@JsonKey(name: 'first_month_of_year') String firstMonthOfYear,@JsonKey(name: 'first_day_of_week') String firstDayOfWeek,@JsonKey(name: 'use_comma_as_decimal_place') bool useCommaAsDecimalPlace,@JsonKey(name: 'enabled_modules') int enabledModules,@JsonKey(name: 'legal_entity_id') int legalEntityId,@JsonKey(name: 'has_e_invoice_certificate') bool hasEInvoiceCertificate,@JsonKey(name: 'e_invoice_certificate_passphrase') String eInvoiceCertificatePassphrase,@JsonKey(name: 'has_e_invoice_certificate_passphrase') bool hasEInvoiceCertificatePassphrase,@JsonKey(name: 'subdomain') String subdomain,@JsonKey(name: 'portal_domain') String portalDomain,@JsonKey(name: 'portal_mode') String portalMode,@JsonKey(name: 'client_can_register') bool clientCanRegister,@JsonKey(name: 'client_registration_fields') List<ClientRegistrationFieldApi> clientRegistrationFields,@JsonKey(name: 'custom_fields') Map<String, String> customFields, Map<String, dynamic> settings,@JsonKey(name: 'enable_applying_payments') bool enableApplyingPayments,@JsonKey(name: 'convert_payment_currency') bool convertPaymentCurrency,@JsonKey(name: 'enabled_tax_rates') int enabledTaxRates,@JsonKey(name: 'enabled_item_tax_rates') int enabledItemTaxRates,@JsonKey(name: 'enabled_expense_tax_rates') int enabledExpenseTaxRates,@JsonKey(name: 'calculate_taxes') bool calculateTaxes,@JsonKey(name: 'tax_data') TaxConfigApi? taxData,@JsonKey(name: 'e_invoice', includeIfNull: false) Map<String, dynamic>? eInvoice,@JsonKey(name: 'custom_surcharge_taxes1') bool customSurchargeTaxes1,@JsonKey(name: 'custom_surcharge_taxes2') bool customSurchargeTaxes2,@JsonKey(name: 'custom_surcharge_taxes3') bool customSurchargeTaxes3,@JsonKey(name: 'custom_surcharge_taxes4') bool customSurchargeTaxes4,@JsonKey(name: 'track_inventory') bool trackInventory,@JsonKey(name: 'stock_notification') bool stockNotification,@JsonKey(name: 'inventory_notification_threshold') int inventoryNotificationThreshold,@JsonKey(name: 'enable_product_discount') bool enableProductDiscount,@JsonKey(name: 'enable_product_cost') bool enableProductCost,@JsonKey(name: 'enable_product_quantity') bool enableProductQuantity,@JsonKey(name: 'default_quantity') bool defaultQuantity,@JsonKey(name: 'show_product_details') bool showProductDetails,@JsonKey(name: 'fill_products') bool fillProducts,@JsonKey(name: 'update_products') bool updateProducts,@JsonKey(name: 'convert_products') bool convertProducts,@JsonKey(name: 'convert_rate_to_client') bool convertRateToClient,@JsonKey(name: 'stop_on_unpaid_recurring') bool stopOnUnpaidRecurring,@JsonKey(name: 'use_quote_terms_on_conversion') bool useQuoteTermsOnConversion,@JsonKey(name: 'auto_start_tasks') bool autoStartTasks,@JsonKey(name: 'show_task_end_date') bool showTaskEndDate,@JsonKey(name: 'show_tasks_table') bool showTasksTable,@JsonKey(name: 'invoice_task_datelog') bool invoiceTaskDatelog,@JsonKey(name: 'invoice_task_timelog') bool invoiceTaskTimelog,@JsonKey(name: 'invoice_task_hours') bool invoiceTaskHours,@JsonKey(name: 'invoice_task_item_description') bool invoiceTaskItemDescription,@JsonKey(name: 'invoice_task_project') bool invoiceTaskProject,@JsonKey(name: 'invoice_task_project_header') bool invoiceTaskProjectHeader,@JsonKey(name: 'invoice_task_lock') bool invoiceTaskLock,@JsonKey(name: 'invoice_task_documents') bool invoiceTaskDocuments,@JsonKey(name: 'mark_expenses_invoiceable') bool markExpensesInvoiceable,@JsonKey(name: 'mark_expenses_paid') bool markExpensesPaid,@JsonKey(name: 'convert_expense_currency') bool convertExpenseCurrency,@JsonKey(name: 'invoice_expense_documents') bool invoiceExpenseDocuments,@JsonKey(name: 'notify_vendor_when_paid') bool notifyVendorWhenPaid,@JsonKey(name: 'calculate_expense_tax_by_amount') bool calculateExpenseTaxByAmount,@JsonKey(name: 'expense_inclusive_taxes') bool expenseInclusiveTaxes,@JsonKey(name: 'expense_mailbox_active') bool expenseMailboxActive,@JsonKey(name: 'expense_mailbox') String expenseMailbox,@JsonKey(name: 'inbound_mailbox_allow_company_users') bool inboundMailboxAllowCompanyUsers,@JsonKey(name: 'inbound_mailbox_allow_vendors') bool inboundMailboxAllowVendors,@JsonKey(name: 'inbound_mailbox_allow_clients') bool inboundMailboxAllowClients,@JsonKey(name: 'inbound_mailbox_whitelist') String inboundMailboxWhitelist,@JsonKey(name: 'inbound_mailbox_blacklist') String inboundMailboxBlacklist,@JsonKey(name: 'inbound_mailbox_allow_unknown') bool inboundMailboxAllowUnknown,@JsonKey(name: 'smtp_host') String smtpHost,@JsonKey(name: 'smtp_port') int smtpPort,@JsonKey(name: 'smtp_encryption') String smtpEncryption,@JsonKey(name: 'smtp_username') String smtpUsername,@JsonKey(name: 'smtp_password') String smtpPassword,@JsonKey(name: 'smtp_local_domain') String smtpLocalDomain,@JsonKey(name: 'smtp_verify_peer') bool smtpVerifyPeer,@JsonKey(name: 'google_analytics_key') String googleAnalyticsKey,@JsonKey(name: 'matomo_id') String matomoId,@JsonKey(name: 'matomo_url') String matomoUrl,@JsonKey(name: 'session_timeout') int sessionTimeout,@JsonKey(name: 'default_password_timeout') int defaultPasswordTimeout,@JsonKey(name: 'oauth_password_required') bool oauthPasswordRequired,@JsonKey(name: 'is_disabled') bool isDisabled,@JsonKey(name: 'markdown_enabled') bool markdownEnabled,@JsonKey(name: 'markdown_email_enabled') bool markdownEmailEnabled,@JsonKey(name: 'report_include_drafts') bool reportIncludeDrafts,@JsonKey(name: 'report_include_deleted') bool reportIncludeDeleted,@JsonKey(name: 'quickbooks') Map<String, dynamic>? quickbooks, List<DocumentApi> documents,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});


@override $TaxConfigApiCopyWith<$Res>? get taxData;

}
/// @nodoc
class __$CompanyApiCopyWithImpl<$Res>
    implements _$CompanyApiCopyWith<$Res> {
  __$CompanyApiCopyWithImpl(this._self, this._then);

  final _CompanyApi _self;
  final $Res Function(_CompanyApi) _then;

/// Create a copy of CompanyApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? name = null,Object? companyKey = null,Object? sizeId = null,Object? industryId = null,Object? firstMonthOfYear = null,Object? firstDayOfWeek = null,Object? useCommaAsDecimalPlace = null,Object? enabledModules = null,Object? legalEntityId = null,Object? hasEInvoiceCertificate = null,Object? eInvoiceCertificatePassphrase = null,Object? hasEInvoiceCertificatePassphrase = null,Object? subdomain = null,Object? portalDomain = null,Object? portalMode = null,Object? clientCanRegister = null,Object? clientRegistrationFields = null,Object? customFields = null,Object? settings = null,Object? enableApplyingPayments = null,Object? convertPaymentCurrency = null,Object? enabledTaxRates = null,Object? enabledItemTaxRates = null,Object? enabledExpenseTaxRates = null,Object? calculateTaxes = null,Object? taxData = freezed,Object? eInvoice = freezed,Object? customSurchargeTaxes1 = null,Object? customSurchargeTaxes2 = null,Object? customSurchargeTaxes3 = null,Object? customSurchargeTaxes4 = null,Object? trackInventory = null,Object? stockNotification = null,Object? inventoryNotificationThreshold = null,Object? enableProductDiscount = null,Object? enableProductCost = null,Object? enableProductQuantity = null,Object? defaultQuantity = null,Object? showProductDetails = null,Object? fillProducts = null,Object? updateProducts = null,Object? convertProducts = null,Object? convertRateToClient = null,Object? stopOnUnpaidRecurring = null,Object? useQuoteTermsOnConversion = null,Object? autoStartTasks = null,Object? showTaskEndDate = null,Object? showTasksTable = null,Object? invoiceTaskDatelog = null,Object? invoiceTaskTimelog = null,Object? invoiceTaskHours = null,Object? invoiceTaskItemDescription = null,Object? invoiceTaskProject = null,Object? invoiceTaskProjectHeader = null,Object? invoiceTaskLock = null,Object? invoiceTaskDocuments = null,Object? markExpensesInvoiceable = null,Object? markExpensesPaid = null,Object? convertExpenseCurrency = null,Object? invoiceExpenseDocuments = null,Object? notifyVendorWhenPaid = null,Object? calculateExpenseTaxByAmount = null,Object? expenseInclusiveTaxes = null,Object? expenseMailboxActive = null,Object? expenseMailbox = null,Object? inboundMailboxAllowCompanyUsers = null,Object? inboundMailboxAllowVendors = null,Object? inboundMailboxAllowClients = null,Object? inboundMailboxWhitelist = null,Object? inboundMailboxBlacklist = null,Object? inboundMailboxAllowUnknown = null,Object? smtpHost = null,Object? smtpPort = null,Object? smtpEncryption = null,Object? smtpUsername = null,Object? smtpPassword = null,Object? smtpLocalDomain = null,Object? smtpVerifyPeer = null,Object? googleAnalyticsKey = null,Object? matomoId = null,Object? matomoUrl = null,Object? sessionTimeout = null,Object? defaultPasswordTimeout = null,Object? oauthPasswordRequired = null,Object? isDisabled = null,Object? markdownEnabled = null,Object? markdownEmailEnabled = null,Object? reportIncludeDrafts = null,Object? reportIncludeDeleted = null,Object? quickbooks = freezed,Object? documents = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_CompanyApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,companyKey: null == companyKey ? _self.companyKey : companyKey // ignore: cast_nullable_to_non_nullable
as String,sizeId: null == sizeId ? _self.sizeId : sizeId // ignore: cast_nullable_to_non_nullable
as String,industryId: null == industryId ? _self.industryId : industryId // ignore: cast_nullable_to_non_nullable
as String,firstMonthOfYear: null == firstMonthOfYear ? _self.firstMonthOfYear : firstMonthOfYear // ignore: cast_nullable_to_non_nullable
as String,firstDayOfWeek: null == firstDayOfWeek ? _self.firstDayOfWeek : firstDayOfWeek // ignore: cast_nullable_to_non_nullable
as String,useCommaAsDecimalPlace: null == useCommaAsDecimalPlace ? _self.useCommaAsDecimalPlace : useCommaAsDecimalPlace // ignore: cast_nullable_to_non_nullable
as bool,enabledModules: null == enabledModules ? _self.enabledModules : enabledModules // ignore: cast_nullable_to_non_nullable
as int,legalEntityId: null == legalEntityId ? _self.legalEntityId : legalEntityId // ignore: cast_nullable_to_non_nullable
as int,hasEInvoiceCertificate: null == hasEInvoiceCertificate ? _self.hasEInvoiceCertificate : hasEInvoiceCertificate // ignore: cast_nullable_to_non_nullable
as bool,eInvoiceCertificatePassphrase: null == eInvoiceCertificatePassphrase ? _self.eInvoiceCertificatePassphrase : eInvoiceCertificatePassphrase // ignore: cast_nullable_to_non_nullable
as String,hasEInvoiceCertificatePassphrase: null == hasEInvoiceCertificatePassphrase ? _self.hasEInvoiceCertificatePassphrase : hasEInvoiceCertificatePassphrase // ignore: cast_nullable_to_non_nullable
as bool,subdomain: null == subdomain ? _self.subdomain : subdomain // ignore: cast_nullable_to_non_nullable
as String,portalDomain: null == portalDomain ? _self.portalDomain : portalDomain // ignore: cast_nullable_to_non_nullable
as String,portalMode: null == portalMode ? _self.portalMode : portalMode // ignore: cast_nullable_to_non_nullable
as String,clientCanRegister: null == clientCanRegister ? _self.clientCanRegister : clientCanRegister // ignore: cast_nullable_to_non_nullable
as bool,clientRegistrationFields: null == clientRegistrationFields ? _self._clientRegistrationFields : clientRegistrationFields // ignore: cast_nullable_to_non_nullable
as List<ClientRegistrationFieldApi>,customFields: null == customFields ? _self._customFields : customFields // ignore: cast_nullable_to_non_nullable
as Map<String, String>,settings: null == settings ? _self._settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,enableApplyingPayments: null == enableApplyingPayments ? _self.enableApplyingPayments : enableApplyingPayments // ignore: cast_nullable_to_non_nullable
as bool,convertPaymentCurrency: null == convertPaymentCurrency ? _self.convertPaymentCurrency : convertPaymentCurrency // ignore: cast_nullable_to_non_nullable
as bool,enabledTaxRates: null == enabledTaxRates ? _self.enabledTaxRates : enabledTaxRates // ignore: cast_nullable_to_non_nullable
as int,enabledItemTaxRates: null == enabledItemTaxRates ? _self.enabledItemTaxRates : enabledItemTaxRates // ignore: cast_nullable_to_non_nullable
as int,enabledExpenseTaxRates: null == enabledExpenseTaxRates ? _self.enabledExpenseTaxRates : enabledExpenseTaxRates // ignore: cast_nullable_to_non_nullable
as int,calculateTaxes: null == calculateTaxes ? _self.calculateTaxes : calculateTaxes // ignore: cast_nullable_to_non_nullable
as bool,taxData: freezed == taxData ? _self.taxData : taxData // ignore: cast_nullable_to_non_nullable
as TaxConfigApi?,eInvoice: freezed == eInvoice ? _self._eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,customSurchargeTaxes1: null == customSurchargeTaxes1 ? _self.customSurchargeTaxes1 : customSurchargeTaxes1 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes2: null == customSurchargeTaxes2 ? _self.customSurchargeTaxes2 : customSurchargeTaxes2 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes3: null == customSurchargeTaxes3 ? _self.customSurchargeTaxes3 : customSurchargeTaxes3 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes4: null == customSurchargeTaxes4 ? _self.customSurchargeTaxes4 : customSurchargeTaxes4 // ignore: cast_nullable_to_non_nullable
as bool,trackInventory: null == trackInventory ? _self.trackInventory : trackInventory // ignore: cast_nullable_to_non_nullable
as bool,stockNotification: null == stockNotification ? _self.stockNotification : stockNotification // ignore: cast_nullable_to_non_nullable
as bool,inventoryNotificationThreshold: null == inventoryNotificationThreshold ? _self.inventoryNotificationThreshold : inventoryNotificationThreshold // ignore: cast_nullable_to_non_nullable
as int,enableProductDiscount: null == enableProductDiscount ? _self.enableProductDiscount : enableProductDiscount // ignore: cast_nullable_to_non_nullable
as bool,enableProductCost: null == enableProductCost ? _self.enableProductCost : enableProductCost // ignore: cast_nullable_to_non_nullable
as bool,enableProductQuantity: null == enableProductQuantity ? _self.enableProductQuantity : enableProductQuantity // ignore: cast_nullable_to_non_nullable
as bool,defaultQuantity: null == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as bool,showProductDetails: null == showProductDetails ? _self.showProductDetails : showProductDetails // ignore: cast_nullable_to_non_nullable
as bool,fillProducts: null == fillProducts ? _self.fillProducts : fillProducts // ignore: cast_nullable_to_non_nullable
as bool,updateProducts: null == updateProducts ? _self.updateProducts : updateProducts // ignore: cast_nullable_to_non_nullable
as bool,convertProducts: null == convertProducts ? _self.convertProducts : convertProducts // ignore: cast_nullable_to_non_nullable
as bool,convertRateToClient: null == convertRateToClient ? _self.convertRateToClient : convertRateToClient // ignore: cast_nullable_to_non_nullable
as bool,stopOnUnpaidRecurring: null == stopOnUnpaidRecurring ? _self.stopOnUnpaidRecurring : stopOnUnpaidRecurring // ignore: cast_nullable_to_non_nullable
as bool,useQuoteTermsOnConversion: null == useQuoteTermsOnConversion ? _self.useQuoteTermsOnConversion : useQuoteTermsOnConversion // ignore: cast_nullable_to_non_nullable
as bool,autoStartTasks: null == autoStartTasks ? _self.autoStartTasks : autoStartTasks // ignore: cast_nullable_to_non_nullable
as bool,showTaskEndDate: null == showTaskEndDate ? _self.showTaskEndDate : showTaskEndDate // ignore: cast_nullable_to_non_nullable
as bool,showTasksTable: null == showTasksTable ? _self.showTasksTable : showTasksTable // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskDatelog: null == invoiceTaskDatelog ? _self.invoiceTaskDatelog : invoiceTaskDatelog // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskTimelog: null == invoiceTaskTimelog ? _self.invoiceTaskTimelog : invoiceTaskTimelog // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskHours: null == invoiceTaskHours ? _self.invoiceTaskHours : invoiceTaskHours // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskItemDescription: null == invoiceTaskItemDescription ? _self.invoiceTaskItemDescription : invoiceTaskItemDescription // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskProject: null == invoiceTaskProject ? _self.invoiceTaskProject : invoiceTaskProject // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskProjectHeader: null == invoiceTaskProjectHeader ? _self.invoiceTaskProjectHeader : invoiceTaskProjectHeader // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskLock: null == invoiceTaskLock ? _self.invoiceTaskLock : invoiceTaskLock // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskDocuments: null == invoiceTaskDocuments ? _self.invoiceTaskDocuments : invoiceTaskDocuments // ignore: cast_nullable_to_non_nullable
as bool,markExpensesInvoiceable: null == markExpensesInvoiceable ? _self.markExpensesInvoiceable : markExpensesInvoiceable // ignore: cast_nullable_to_non_nullable
as bool,markExpensesPaid: null == markExpensesPaid ? _self.markExpensesPaid : markExpensesPaid // ignore: cast_nullable_to_non_nullable
as bool,convertExpenseCurrency: null == convertExpenseCurrency ? _self.convertExpenseCurrency : convertExpenseCurrency // ignore: cast_nullable_to_non_nullable
as bool,invoiceExpenseDocuments: null == invoiceExpenseDocuments ? _self.invoiceExpenseDocuments : invoiceExpenseDocuments // ignore: cast_nullable_to_non_nullable
as bool,notifyVendorWhenPaid: null == notifyVendorWhenPaid ? _self.notifyVendorWhenPaid : notifyVendorWhenPaid // ignore: cast_nullable_to_non_nullable
as bool,calculateExpenseTaxByAmount: null == calculateExpenseTaxByAmount ? _self.calculateExpenseTaxByAmount : calculateExpenseTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,expenseInclusiveTaxes: null == expenseInclusiveTaxes ? _self.expenseInclusiveTaxes : expenseInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,expenseMailboxActive: null == expenseMailboxActive ? _self.expenseMailboxActive : expenseMailboxActive // ignore: cast_nullable_to_non_nullable
as bool,expenseMailbox: null == expenseMailbox ? _self.expenseMailbox : expenseMailbox // ignore: cast_nullable_to_non_nullable
as String,inboundMailboxAllowCompanyUsers: null == inboundMailboxAllowCompanyUsers ? _self.inboundMailboxAllowCompanyUsers : inboundMailboxAllowCompanyUsers // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowVendors: null == inboundMailboxAllowVendors ? _self.inboundMailboxAllowVendors : inboundMailboxAllowVendors // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowClients: null == inboundMailboxAllowClients ? _self.inboundMailboxAllowClients : inboundMailboxAllowClients // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxWhitelist: null == inboundMailboxWhitelist ? _self.inboundMailboxWhitelist : inboundMailboxWhitelist // ignore: cast_nullable_to_non_nullable
as String,inboundMailboxBlacklist: null == inboundMailboxBlacklist ? _self.inboundMailboxBlacklist : inboundMailboxBlacklist // ignore: cast_nullable_to_non_nullable
as String,inboundMailboxAllowUnknown: null == inboundMailboxAllowUnknown ? _self.inboundMailboxAllowUnknown : inboundMailboxAllowUnknown // ignore: cast_nullable_to_non_nullable
as bool,smtpHost: null == smtpHost ? _self.smtpHost : smtpHost // ignore: cast_nullable_to_non_nullable
as String,smtpPort: null == smtpPort ? _self.smtpPort : smtpPort // ignore: cast_nullable_to_non_nullable
as int,smtpEncryption: null == smtpEncryption ? _self.smtpEncryption : smtpEncryption // ignore: cast_nullable_to_non_nullable
as String,smtpUsername: null == smtpUsername ? _self.smtpUsername : smtpUsername // ignore: cast_nullable_to_non_nullable
as String,smtpPassword: null == smtpPassword ? _self.smtpPassword : smtpPassword // ignore: cast_nullable_to_non_nullable
as String,smtpLocalDomain: null == smtpLocalDomain ? _self.smtpLocalDomain : smtpLocalDomain // ignore: cast_nullable_to_non_nullable
as String,smtpVerifyPeer: null == smtpVerifyPeer ? _self.smtpVerifyPeer : smtpVerifyPeer // ignore: cast_nullable_to_non_nullable
as bool,googleAnalyticsKey: null == googleAnalyticsKey ? _self.googleAnalyticsKey : googleAnalyticsKey // ignore: cast_nullable_to_non_nullable
as String,matomoId: null == matomoId ? _self.matomoId : matomoId // ignore: cast_nullable_to_non_nullable
as String,matomoUrl: null == matomoUrl ? _self.matomoUrl : matomoUrl // ignore: cast_nullable_to_non_nullable
as String,sessionTimeout: null == sessionTimeout ? _self.sessionTimeout : sessionTimeout // ignore: cast_nullable_to_non_nullable
as int,defaultPasswordTimeout: null == defaultPasswordTimeout ? _self.defaultPasswordTimeout : defaultPasswordTimeout // ignore: cast_nullable_to_non_nullable
as int,oauthPasswordRequired: null == oauthPasswordRequired ? _self.oauthPasswordRequired : oauthPasswordRequired // ignore: cast_nullable_to_non_nullable
as bool,isDisabled: null == isDisabled ? _self.isDisabled : isDisabled // ignore: cast_nullable_to_non_nullable
as bool,markdownEnabled: null == markdownEnabled ? _self.markdownEnabled : markdownEnabled // ignore: cast_nullable_to_non_nullable
as bool,markdownEmailEnabled: null == markdownEmailEnabled ? _self.markdownEmailEnabled : markdownEmailEnabled // ignore: cast_nullable_to_non_nullable
as bool,reportIncludeDrafts: null == reportIncludeDrafts ? _self.reportIncludeDrafts : reportIncludeDrafts // ignore: cast_nullable_to_non_nullable
as bool,reportIncludeDeleted: null == reportIncludeDeleted ? _self.reportIncludeDeleted : reportIncludeDeleted // ignore: cast_nullable_to_non_nullable
as bool,quickbooks: freezed == quickbooks ? _self._quickbooks : quickbooks // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of CompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaxConfigApiCopyWith<$Res>? get taxData {
    if (_self.taxData == null) {
    return null;
  }

  return $TaxConfigApiCopyWith<$Res>(_self.taxData!, (value) {
    return _then(_self.copyWith(taxData: value));
  });
}
}


/// @nodoc
mixin _$CompanyItemApi {

 CompanyApi get data;
/// Create a copy of CompanyItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyItemApiCopyWith<CompanyItemApi> get copyWith => _$CompanyItemApiCopyWithImpl<CompanyItemApi>(this as CompanyItemApi, _$identity);

  /// Serializes this CompanyItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CompanyItemApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyItemApi&&(identical(other.data, _this.data) || other.data == _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CompanyItemApi;
  return Object.hash(runtimeType,_this.data);
}

@override
String toString() {
  final _this = this as CompanyItemApi;
  return 'CompanyItemApi(data: ${_this.data})';
}


}

/// @nodoc
abstract mixin class $CompanyItemApiCopyWith<$Res>  {
  factory $CompanyItemApiCopyWith(CompanyItemApi value, $Res Function(CompanyItemApi) _then) = _$CompanyItemApiCopyWithImpl;
@useResult
$Res call({
 CompanyApi data
});


$CompanyApiCopyWith<$Res> get data;

}
/// @nodoc
class _$CompanyItemApiCopyWithImpl<$Res>
    implements $CompanyItemApiCopyWith<$Res> {
  _$CompanyItemApiCopyWithImpl(this._self, this._then);

  final CompanyItemApi _self;
  final $Res Function(CompanyItemApi) _then;

/// Create a copy of CompanyItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(CompanyItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as CompanyApi,
  ));
}
/// Create a copy of CompanyItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyApiCopyWith<$Res> get data {
  
  return $CompanyApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [CompanyItemApi].
extension CompanyItemApiPatterns on CompanyItemApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyItemApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyItemApi value)  $default,){
final _that = this;
switch (_that) {
case _CompanyItemApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyItemApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CompanyApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyItemApi() when $default != null:
return $default(_that.data);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CompanyApi data)  $default,) {final _that = this;
switch (_that) {
case _CompanyItemApi():
return $default(_that.data);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CompanyApi data)?  $default,) {final _that = this;
switch (_that) {
case _CompanyItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompanyItemApi implements CompanyItemApi {
  const _CompanyItemApi({required this.data});
  factory _CompanyItemApi.fromJson(Map<String, dynamic> json) => _$CompanyItemApiFromJson(json);

@override final  CompanyApi data;

/// Create a copy of CompanyItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyItemApiCopyWith<_CompanyItemApi> get copyWith => __$CompanyItemApiCopyWithImpl<_CompanyItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,data);
}

@override
String toString() {
    return 'CompanyItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$CompanyItemApiCopyWith<$Res> implements $CompanyItemApiCopyWith<$Res> {
  factory _$CompanyItemApiCopyWith(_CompanyItemApi value, $Res Function(_CompanyItemApi) _then) = __$CompanyItemApiCopyWithImpl;
@override @useResult
$Res call({
 CompanyApi data
});


@override $CompanyApiCopyWith<$Res> get data;

}
/// @nodoc
class __$CompanyItemApiCopyWithImpl<$Res>
    implements _$CompanyItemApiCopyWith<$Res> {
  __$CompanyItemApiCopyWithImpl(this._self, this._then);

  final _CompanyItemApi _self;
  final $Res Function(_CompanyItemApi) _then;

/// Create a copy of CompanyItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_CompanyItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as CompanyApi,
  ));
}

/// Create a copy of CompanyItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyApiCopyWith<$Res> get data {
  
  return $CompanyApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on

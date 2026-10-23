// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'company.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Company {

 String get id; String get displayName; String get name; String get companyKey; String get sizeId; String get industryId; String get firstMonthOfYear; String get firstDayOfWeek; bool get useCommaAsDecimalPlace; int get enabledModules; int get legalEntityId; bool get hasEInvoiceCertificate; String get eInvoiceCertificatePassphrase; bool get hasEInvoiceCertificatePassphrase; String get subdomain; String get portalDomain; String get portalMode; bool get clientCanRegister; List<ClientRegistrationFieldApi> get clientRegistrationFields; Map<String, String> get customFields; Map<String, dynamic> get rawSettings; CompanySettings get settings; bool get enableApplyingPayments; bool get convertPaymentCurrency; int get enabledTaxRates; int get enabledItemTaxRates; int get enabledExpenseTaxRates; bool get calculateTaxes; TaxConfigApi? get taxData; Map<String, dynamic>? get eInvoice; bool get customSurchargeTaxes1; bool get customSurchargeTaxes2; bool get customSurchargeTaxes3; bool get customSurchargeTaxes4; bool get trackInventory; bool get stockNotification; int get inventoryNotificationThreshold; bool get enableProductDiscount; bool get enableProductCost; bool get enableProductQuantity; bool get defaultQuantity; bool get showProductDetails; bool get fillProducts; bool get updateProducts; bool get convertProducts; bool get convertRateToClient; bool get stopOnUnpaidRecurring; bool get useQuoteTermsOnConversion; bool get autoStartTasks; bool get showTaskEndDate; bool get showTasksTable; bool get invoiceTaskDatelog; bool get invoiceTaskTimelog; bool get invoiceTaskHours; bool get invoiceTaskItemDescription; bool get invoiceTaskProject; bool get invoiceTaskProjectHeader; bool get invoiceTaskLock; bool get invoiceTaskDocuments; bool get markExpensesInvoiceable; bool get markExpensesPaid; bool get convertExpenseCurrency; bool get invoiceExpenseDocuments; bool get notifyVendorWhenPaid; bool get calculateExpenseTaxByAmount; bool get expenseInclusiveTaxes; bool get expenseMailboxActive; String get expenseMailbox; bool get inboundMailboxAllowCompanyUsers; bool get inboundMailboxAllowVendors; bool get inboundMailboxAllowClients; String get inboundMailboxWhitelist; String get inboundMailboxBlacklist; bool get inboundMailboxAllowUnknown; String get smtpHost; int get smtpPort; String get smtpEncryption; String get smtpUsername; String get smtpPassword; String get smtpLocalDomain; bool get smtpVerifyPeer; String get googleAnalyticsKey; String get matomoId; String get matomoUrl; int get sessionTimeout; int get defaultPasswordTimeout; bool get oauthPasswordRequired; bool get isDisabled; bool get markdownEnabled; bool get markdownEmailEnabled; bool get reportIncludeDrafts; bool get reportIncludeDeleted; Map<String, dynamic>? get quickbooks; List<Document> get documents; int get updatedAt; int get archivedAt;
/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyCopyWith<Company> get copyWith => _$CompanyCopyWithImpl<Company>(this as Company, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Company;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Company&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.companyKey, _this.companyKey) || other.companyKey == _this.companyKey)&&(identical(other.sizeId, _this.sizeId) || other.sizeId == _this.sizeId)&&(identical(other.industryId, _this.industryId) || other.industryId == _this.industryId)&&(identical(other.firstMonthOfYear, _this.firstMonthOfYear) || other.firstMonthOfYear == _this.firstMonthOfYear)&&(identical(other.firstDayOfWeek, _this.firstDayOfWeek) || other.firstDayOfWeek == _this.firstDayOfWeek)&&(identical(other.useCommaAsDecimalPlace, _this.useCommaAsDecimalPlace) || other.useCommaAsDecimalPlace == _this.useCommaAsDecimalPlace)&&(identical(other.enabledModules, _this.enabledModules) || other.enabledModules == _this.enabledModules)&&(identical(other.legalEntityId, _this.legalEntityId) || other.legalEntityId == _this.legalEntityId)&&(identical(other.hasEInvoiceCertificate, _this.hasEInvoiceCertificate) || other.hasEInvoiceCertificate == _this.hasEInvoiceCertificate)&&(identical(other.eInvoiceCertificatePassphrase, _this.eInvoiceCertificatePassphrase) || other.eInvoiceCertificatePassphrase == _this.eInvoiceCertificatePassphrase)&&(identical(other.hasEInvoiceCertificatePassphrase, _this.hasEInvoiceCertificatePassphrase) || other.hasEInvoiceCertificatePassphrase == _this.hasEInvoiceCertificatePassphrase)&&(identical(other.subdomain, _this.subdomain) || other.subdomain == _this.subdomain)&&(identical(other.portalDomain, _this.portalDomain) || other.portalDomain == _this.portalDomain)&&(identical(other.portalMode, _this.portalMode) || other.portalMode == _this.portalMode)&&(identical(other.clientCanRegister, _this.clientCanRegister) || other.clientCanRegister == _this.clientCanRegister)&&const DeepCollectionEquality().equals(other.clientRegistrationFields, _this.clientRegistrationFields)&&const DeepCollectionEquality().equals(other.customFields, _this.customFields)&&const DeepCollectionEquality().equals(other.rawSettings, _this.rawSettings)&&(identical(other.settings, _this.settings) || other.settings == _this.settings)&&(identical(other.enableApplyingPayments, _this.enableApplyingPayments) || other.enableApplyingPayments == _this.enableApplyingPayments)&&(identical(other.convertPaymentCurrency, _this.convertPaymentCurrency) || other.convertPaymentCurrency == _this.convertPaymentCurrency)&&(identical(other.enabledTaxRates, _this.enabledTaxRates) || other.enabledTaxRates == _this.enabledTaxRates)&&(identical(other.enabledItemTaxRates, _this.enabledItemTaxRates) || other.enabledItemTaxRates == _this.enabledItemTaxRates)&&(identical(other.enabledExpenseTaxRates, _this.enabledExpenseTaxRates) || other.enabledExpenseTaxRates == _this.enabledExpenseTaxRates)&&(identical(other.calculateTaxes, _this.calculateTaxes) || other.calculateTaxes == _this.calculateTaxes)&&(identical(other.taxData, _this.taxData) || other.taxData == _this.taxData)&&const DeepCollectionEquality().equals(other.eInvoice, _this.eInvoice)&&(identical(other.customSurchargeTaxes1, _this.customSurchargeTaxes1) || other.customSurchargeTaxes1 == _this.customSurchargeTaxes1)&&(identical(other.customSurchargeTaxes2, _this.customSurchargeTaxes2) || other.customSurchargeTaxes2 == _this.customSurchargeTaxes2)&&(identical(other.customSurchargeTaxes3, _this.customSurchargeTaxes3) || other.customSurchargeTaxes3 == _this.customSurchargeTaxes3)&&(identical(other.customSurchargeTaxes4, _this.customSurchargeTaxes4) || other.customSurchargeTaxes4 == _this.customSurchargeTaxes4)&&(identical(other.trackInventory, _this.trackInventory) || other.trackInventory == _this.trackInventory)&&(identical(other.stockNotification, _this.stockNotification) || other.stockNotification == _this.stockNotification)&&(identical(other.inventoryNotificationThreshold, _this.inventoryNotificationThreshold) || other.inventoryNotificationThreshold == _this.inventoryNotificationThreshold)&&(identical(other.enableProductDiscount, _this.enableProductDiscount) || other.enableProductDiscount == _this.enableProductDiscount)&&(identical(other.enableProductCost, _this.enableProductCost) || other.enableProductCost == _this.enableProductCost)&&(identical(other.enableProductQuantity, _this.enableProductQuantity) || other.enableProductQuantity == _this.enableProductQuantity)&&(identical(other.defaultQuantity, _this.defaultQuantity) || other.defaultQuantity == _this.defaultQuantity)&&(identical(other.showProductDetails, _this.showProductDetails) || other.showProductDetails == _this.showProductDetails)&&(identical(other.fillProducts, _this.fillProducts) || other.fillProducts == _this.fillProducts)&&(identical(other.updateProducts, _this.updateProducts) || other.updateProducts == _this.updateProducts)&&(identical(other.convertProducts, _this.convertProducts) || other.convertProducts == _this.convertProducts)&&(identical(other.convertRateToClient, _this.convertRateToClient) || other.convertRateToClient == _this.convertRateToClient)&&(identical(other.stopOnUnpaidRecurring, _this.stopOnUnpaidRecurring) || other.stopOnUnpaidRecurring == _this.stopOnUnpaidRecurring)&&(identical(other.useQuoteTermsOnConversion, _this.useQuoteTermsOnConversion) || other.useQuoteTermsOnConversion == _this.useQuoteTermsOnConversion)&&(identical(other.autoStartTasks, _this.autoStartTasks) || other.autoStartTasks == _this.autoStartTasks)&&(identical(other.showTaskEndDate, _this.showTaskEndDate) || other.showTaskEndDate == _this.showTaskEndDate)&&(identical(other.showTasksTable, _this.showTasksTable) || other.showTasksTable == _this.showTasksTable)&&(identical(other.invoiceTaskDatelog, _this.invoiceTaskDatelog) || other.invoiceTaskDatelog == _this.invoiceTaskDatelog)&&(identical(other.invoiceTaskTimelog, _this.invoiceTaskTimelog) || other.invoiceTaskTimelog == _this.invoiceTaskTimelog)&&(identical(other.invoiceTaskHours, _this.invoiceTaskHours) || other.invoiceTaskHours == _this.invoiceTaskHours)&&(identical(other.invoiceTaskItemDescription, _this.invoiceTaskItemDescription) || other.invoiceTaskItemDescription == _this.invoiceTaskItemDescription)&&(identical(other.invoiceTaskProject, _this.invoiceTaskProject) || other.invoiceTaskProject == _this.invoiceTaskProject)&&(identical(other.invoiceTaskProjectHeader, _this.invoiceTaskProjectHeader) || other.invoiceTaskProjectHeader == _this.invoiceTaskProjectHeader)&&(identical(other.invoiceTaskLock, _this.invoiceTaskLock) || other.invoiceTaskLock == _this.invoiceTaskLock)&&(identical(other.invoiceTaskDocuments, _this.invoiceTaskDocuments) || other.invoiceTaskDocuments == _this.invoiceTaskDocuments)&&(identical(other.markExpensesInvoiceable, _this.markExpensesInvoiceable) || other.markExpensesInvoiceable == _this.markExpensesInvoiceable)&&(identical(other.markExpensesPaid, _this.markExpensesPaid) || other.markExpensesPaid == _this.markExpensesPaid)&&(identical(other.convertExpenseCurrency, _this.convertExpenseCurrency) || other.convertExpenseCurrency == _this.convertExpenseCurrency)&&(identical(other.invoiceExpenseDocuments, _this.invoiceExpenseDocuments) || other.invoiceExpenseDocuments == _this.invoiceExpenseDocuments)&&(identical(other.notifyVendorWhenPaid, _this.notifyVendorWhenPaid) || other.notifyVendorWhenPaid == _this.notifyVendorWhenPaid)&&(identical(other.calculateExpenseTaxByAmount, _this.calculateExpenseTaxByAmount) || other.calculateExpenseTaxByAmount == _this.calculateExpenseTaxByAmount)&&(identical(other.expenseInclusiveTaxes, _this.expenseInclusiveTaxes) || other.expenseInclusiveTaxes == _this.expenseInclusiveTaxes)&&(identical(other.expenseMailboxActive, _this.expenseMailboxActive) || other.expenseMailboxActive == _this.expenseMailboxActive)&&(identical(other.expenseMailbox, _this.expenseMailbox) || other.expenseMailbox == _this.expenseMailbox)&&(identical(other.inboundMailboxAllowCompanyUsers, _this.inboundMailboxAllowCompanyUsers) || other.inboundMailboxAllowCompanyUsers == _this.inboundMailboxAllowCompanyUsers)&&(identical(other.inboundMailboxAllowVendors, _this.inboundMailboxAllowVendors) || other.inboundMailboxAllowVendors == _this.inboundMailboxAllowVendors)&&(identical(other.inboundMailboxAllowClients, _this.inboundMailboxAllowClients) || other.inboundMailboxAllowClients == _this.inboundMailboxAllowClients)&&(identical(other.inboundMailboxWhitelist, _this.inboundMailboxWhitelist) || other.inboundMailboxWhitelist == _this.inboundMailboxWhitelist)&&(identical(other.inboundMailboxBlacklist, _this.inboundMailboxBlacklist) || other.inboundMailboxBlacklist == _this.inboundMailboxBlacklist)&&(identical(other.inboundMailboxAllowUnknown, _this.inboundMailboxAllowUnknown) || other.inboundMailboxAllowUnknown == _this.inboundMailboxAllowUnknown)&&(identical(other.smtpHost, _this.smtpHost) || other.smtpHost == _this.smtpHost)&&(identical(other.smtpPort, _this.smtpPort) || other.smtpPort == _this.smtpPort)&&(identical(other.smtpEncryption, _this.smtpEncryption) || other.smtpEncryption == _this.smtpEncryption)&&(identical(other.smtpUsername, _this.smtpUsername) || other.smtpUsername == _this.smtpUsername)&&(identical(other.smtpPassword, _this.smtpPassword) || other.smtpPassword == _this.smtpPassword)&&(identical(other.smtpLocalDomain, _this.smtpLocalDomain) || other.smtpLocalDomain == _this.smtpLocalDomain)&&(identical(other.smtpVerifyPeer, _this.smtpVerifyPeer) || other.smtpVerifyPeer == _this.smtpVerifyPeer)&&(identical(other.googleAnalyticsKey, _this.googleAnalyticsKey) || other.googleAnalyticsKey == _this.googleAnalyticsKey)&&(identical(other.matomoId, _this.matomoId) || other.matomoId == _this.matomoId)&&(identical(other.matomoUrl, _this.matomoUrl) || other.matomoUrl == _this.matomoUrl)&&(identical(other.sessionTimeout, _this.sessionTimeout) || other.sessionTimeout == _this.sessionTimeout)&&(identical(other.defaultPasswordTimeout, _this.defaultPasswordTimeout) || other.defaultPasswordTimeout == _this.defaultPasswordTimeout)&&(identical(other.oauthPasswordRequired, _this.oauthPasswordRequired) || other.oauthPasswordRequired == _this.oauthPasswordRequired)&&(identical(other.isDisabled, _this.isDisabled) || other.isDisabled == _this.isDisabled)&&(identical(other.markdownEnabled, _this.markdownEnabled) || other.markdownEnabled == _this.markdownEnabled)&&(identical(other.markdownEmailEnabled, _this.markdownEmailEnabled) || other.markdownEmailEnabled == _this.markdownEmailEnabled)&&(identical(other.reportIncludeDrafts, _this.reportIncludeDrafts) || other.reportIncludeDrafts == _this.reportIncludeDrafts)&&(identical(other.reportIncludeDeleted, _this.reportIncludeDeleted) || other.reportIncludeDeleted == _this.reportIncludeDeleted)&&const DeepCollectionEquality().equals(other.quickbooks, _this.quickbooks)&&const DeepCollectionEquality().equals(other.documents, _this.documents)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt));
}


@override
int get hashCode {
  final _this = this as Company;
  return Object.hashAll([runtimeType,_this.id,_this.displayName,_this.name,_this.companyKey,_this.sizeId,_this.industryId,_this.firstMonthOfYear,_this.firstDayOfWeek,_this.useCommaAsDecimalPlace,_this.enabledModules,_this.legalEntityId,_this.hasEInvoiceCertificate,_this.eInvoiceCertificatePassphrase,_this.hasEInvoiceCertificatePassphrase,_this.subdomain,_this.portalDomain,_this.portalMode,_this.clientCanRegister,const DeepCollectionEquality().hash(_this.clientRegistrationFields),const DeepCollectionEquality().hash(_this.customFields),const DeepCollectionEquality().hash(_this.rawSettings),_this.settings,_this.enableApplyingPayments,_this.convertPaymentCurrency,_this.enabledTaxRates,_this.enabledItemTaxRates,_this.enabledExpenseTaxRates,_this.calculateTaxes,_this.taxData,const DeepCollectionEquality().hash(_this.eInvoice),_this.customSurchargeTaxes1,_this.customSurchargeTaxes2,_this.customSurchargeTaxes3,_this.customSurchargeTaxes4,_this.trackInventory,_this.stockNotification,_this.inventoryNotificationThreshold,_this.enableProductDiscount,_this.enableProductCost,_this.enableProductQuantity,_this.defaultQuantity,_this.showProductDetails,_this.fillProducts,_this.updateProducts,_this.convertProducts,_this.convertRateToClient,_this.stopOnUnpaidRecurring,_this.useQuoteTermsOnConversion,_this.autoStartTasks,_this.showTaskEndDate,_this.showTasksTable,_this.invoiceTaskDatelog,_this.invoiceTaskTimelog,_this.invoiceTaskHours,_this.invoiceTaskItemDescription,_this.invoiceTaskProject,_this.invoiceTaskProjectHeader,_this.invoiceTaskLock,_this.invoiceTaskDocuments,_this.markExpensesInvoiceable,_this.markExpensesPaid,_this.convertExpenseCurrency,_this.invoiceExpenseDocuments,_this.notifyVendorWhenPaid,_this.calculateExpenseTaxByAmount,_this.expenseInclusiveTaxes,_this.expenseMailboxActive,_this.expenseMailbox,_this.inboundMailboxAllowCompanyUsers,_this.inboundMailboxAllowVendors,_this.inboundMailboxAllowClients,_this.inboundMailboxWhitelist,_this.inboundMailboxBlacklist,_this.inboundMailboxAllowUnknown,_this.smtpHost,_this.smtpPort,_this.smtpEncryption,_this.smtpUsername,_this.smtpPassword,_this.smtpLocalDomain,_this.smtpVerifyPeer,_this.googleAnalyticsKey,_this.matomoId,_this.matomoUrl,_this.sessionTimeout,_this.defaultPasswordTimeout,_this.oauthPasswordRequired,_this.isDisabled,_this.markdownEnabled,_this.markdownEmailEnabled,_this.reportIncludeDrafts,_this.reportIncludeDeleted,const DeepCollectionEquality().hash(_this.quickbooks),const DeepCollectionEquality().hash(_this.documents),_this.updatedAt,_this.archivedAt]);
}

@override
String toString() {
  final _this = this as Company;
  return 'Company(id: ${_this.id}, displayName: ${_this.displayName}, name: ${_this.name}, companyKey: ${_this.companyKey}, sizeId: ${_this.sizeId}, industryId: ${_this.industryId}, firstMonthOfYear: ${_this.firstMonthOfYear}, firstDayOfWeek: ${_this.firstDayOfWeek}, useCommaAsDecimalPlace: ${_this.useCommaAsDecimalPlace}, enabledModules: ${_this.enabledModules}, legalEntityId: ${_this.legalEntityId}, hasEInvoiceCertificate: ${_this.hasEInvoiceCertificate}, eInvoiceCertificatePassphrase: ${_this.eInvoiceCertificatePassphrase}, hasEInvoiceCertificatePassphrase: ${_this.hasEInvoiceCertificatePassphrase}, subdomain: ${_this.subdomain}, portalDomain: ${_this.portalDomain}, portalMode: ${_this.portalMode}, clientCanRegister: ${_this.clientCanRegister}, clientRegistrationFields: ${_this.clientRegistrationFields}, customFields: ${_this.customFields}, rawSettings: ${_this.rawSettings}, settings: ${_this.settings}, enableApplyingPayments: ${_this.enableApplyingPayments}, convertPaymentCurrency: ${_this.convertPaymentCurrency}, enabledTaxRates: ${_this.enabledTaxRates}, enabledItemTaxRates: ${_this.enabledItemTaxRates}, enabledExpenseTaxRates: ${_this.enabledExpenseTaxRates}, calculateTaxes: ${_this.calculateTaxes}, taxData: ${_this.taxData}, eInvoice: ${_this.eInvoice}, customSurchargeTaxes1: ${_this.customSurchargeTaxes1}, customSurchargeTaxes2: ${_this.customSurchargeTaxes2}, customSurchargeTaxes3: ${_this.customSurchargeTaxes3}, customSurchargeTaxes4: ${_this.customSurchargeTaxes4}, trackInventory: ${_this.trackInventory}, stockNotification: ${_this.stockNotification}, inventoryNotificationThreshold: ${_this.inventoryNotificationThreshold}, enableProductDiscount: ${_this.enableProductDiscount}, enableProductCost: ${_this.enableProductCost}, enableProductQuantity: ${_this.enableProductQuantity}, defaultQuantity: ${_this.defaultQuantity}, showProductDetails: ${_this.showProductDetails}, fillProducts: ${_this.fillProducts}, updateProducts: ${_this.updateProducts}, convertProducts: ${_this.convertProducts}, convertRateToClient: ${_this.convertRateToClient}, stopOnUnpaidRecurring: ${_this.stopOnUnpaidRecurring}, useQuoteTermsOnConversion: ${_this.useQuoteTermsOnConversion}, autoStartTasks: ${_this.autoStartTasks}, showTaskEndDate: ${_this.showTaskEndDate}, showTasksTable: ${_this.showTasksTable}, invoiceTaskDatelog: ${_this.invoiceTaskDatelog}, invoiceTaskTimelog: ${_this.invoiceTaskTimelog}, invoiceTaskHours: ${_this.invoiceTaskHours}, invoiceTaskItemDescription: ${_this.invoiceTaskItemDescription}, invoiceTaskProject: ${_this.invoiceTaskProject}, invoiceTaskProjectHeader: ${_this.invoiceTaskProjectHeader}, invoiceTaskLock: ${_this.invoiceTaskLock}, invoiceTaskDocuments: ${_this.invoiceTaskDocuments}, markExpensesInvoiceable: ${_this.markExpensesInvoiceable}, markExpensesPaid: ${_this.markExpensesPaid}, convertExpenseCurrency: ${_this.convertExpenseCurrency}, invoiceExpenseDocuments: ${_this.invoiceExpenseDocuments}, notifyVendorWhenPaid: ${_this.notifyVendorWhenPaid}, calculateExpenseTaxByAmount: ${_this.calculateExpenseTaxByAmount}, expenseInclusiveTaxes: ${_this.expenseInclusiveTaxes}, expenseMailboxActive: ${_this.expenseMailboxActive}, expenseMailbox: ${_this.expenseMailbox}, inboundMailboxAllowCompanyUsers: ${_this.inboundMailboxAllowCompanyUsers}, inboundMailboxAllowVendors: ${_this.inboundMailboxAllowVendors}, inboundMailboxAllowClients: ${_this.inboundMailboxAllowClients}, inboundMailboxWhitelist: ${_this.inboundMailboxWhitelist}, inboundMailboxBlacklist: ${_this.inboundMailboxBlacklist}, inboundMailboxAllowUnknown: ${_this.inboundMailboxAllowUnknown}, smtpHost: ${_this.smtpHost}, smtpPort: ${_this.smtpPort}, smtpEncryption: ${_this.smtpEncryption}, smtpUsername: ${_this.smtpUsername}, smtpPassword: ${_this.smtpPassword}, smtpLocalDomain: ${_this.smtpLocalDomain}, smtpVerifyPeer: ${_this.smtpVerifyPeer}, googleAnalyticsKey: ${_this.googleAnalyticsKey}, matomoId: ${_this.matomoId}, matomoUrl: ${_this.matomoUrl}, sessionTimeout: ${_this.sessionTimeout}, defaultPasswordTimeout: ${_this.defaultPasswordTimeout}, oauthPasswordRequired: ${_this.oauthPasswordRequired}, isDisabled: ${_this.isDisabled}, markdownEnabled: ${_this.markdownEnabled}, markdownEmailEnabled: ${_this.markdownEmailEnabled}, reportIncludeDrafts: ${_this.reportIncludeDrafts}, reportIncludeDeleted: ${_this.reportIncludeDeleted}, quickbooks: ${_this.quickbooks}, documents: ${_this.documents}, updatedAt: ${_this.updatedAt}, archivedAt: ${_this.archivedAt})';
}


}

/// @nodoc
abstract mixin class $CompanyCopyWith<$Res>  {
  factory $CompanyCopyWith(Company value, $Res Function(Company) _then) = _$CompanyCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String name, String companyKey, String sizeId, String industryId, String firstMonthOfYear, String firstDayOfWeek, bool useCommaAsDecimalPlace, int enabledModules, int legalEntityId, bool hasEInvoiceCertificate, String eInvoiceCertificatePassphrase, bool hasEInvoiceCertificatePassphrase, String subdomain, String portalDomain, String portalMode, bool clientCanRegister, List<ClientRegistrationFieldApi> clientRegistrationFields, Map<String, String> customFields, Map<String, dynamic> rawSettings, CompanySettings settings, bool enableApplyingPayments, bool convertPaymentCurrency, int enabledTaxRates, int enabledItemTaxRates, int enabledExpenseTaxRates, bool calculateTaxes, TaxConfigApi? taxData, Map<String, dynamic>? eInvoice, bool customSurchargeTaxes1, bool customSurchargeTaxes2, bool customSurchargeTaxes3, bool customSurchargeTaxes4, bool trackInventory, bool stockNotification, int inventoryNotificationThreshold, bool enableProductDiscount, bool enableProductCost, bool enableProductQuantity, bool defaultQuantity, bool showProductDetails, bool fillProducts, bool updateProducts, bool convertProducts, bool convertRateToClient, bool stopOnUnpaidRecurring, bool useQuoteTermsOnConversion, bool autoStartTasks, bool showTaskEndDate, bool showTasksTable, bool invoiceTaskDatelog, bool invoiceTaskTimelog, bool invoiceTaskHours, bool invoiceTaskItemDescription, bool invoiceTaskProject, bool invoiceTaskProjectHeader, bool invoiceTaskLock, bool invoiceTaskDocuments, bool markExpensesInvoiceable, bool markExpensesPaid, bool convertExpenseCurrency, bool invoiceExpenseDocuments, bool notifyVendorWhenPaid, bool calculateExpenseTaxByAmount, bool expenseInclusiveTaxes, bool expenseMailboxActive, String expenseMailbox, bool inboundMailboxAllowCompanyUsers, bool inboundMailboxAllowVendors, bool inboundMailboxAllowClients, String inboundMailboxWhitelist, String inboundMailboxBlacklist, bool inboundMailboxAllowUnknown, String smtpHost, int smtpPort, String smtpEncryption, String smtpUsername, String smtpPassword, String smtpLocalDomain, bool smtpVerifyPeer, String googleAnalyticsKey, String matomoId, String matomoUrl, int sessionTimeout, int defaultPasswordTimeout, bool oauthPasswordRequired, bool isDisabled, bool markdownEnabled, bool markdownEmailEnabled, bool reportIncludeDrafts, bool reportIncludeDeleted, Map<String, dynamic>? quickbooks, List<Document> documents, int updatedAt, int archivedAt
});


$CompanySettingsApiCopyWith<$Res> get settings;$TaxConfigApiCopyWith<$Res>? get taxData;

}
/// @nodoc
class _$CompanyCopyWithImpl<$Res>
    implements $CompanyCopyWith<$Res> {
  _$CompanyCopyWithImpl(this._self, this._then);

  final Company _self;
  final $Res Function(Company) _then;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? name = null,Object? companyKey = null,Object? sizeId = null,Object? industryId = null,Object? firstMonthOfYear = null,Object? firstDayOfWeek = null,Object? useCommaAsDecimalPlace = null,Object? enabledModules = null,Object? legalEntityId = null,Object? hasEInvoiceCertificate = null,Object? eInvoiceCertificatePassphrase = null,Object? hasEInvoiceCertificatePassphrase = null,Object? subdomain = null,Object? portalDomain = null,Object? portalMode = null,Object? clientCanRegister = null,Object? clientRegistrationFields = null,Object? customFields = null,Object? rawSettings = null,Object? settings = null,Object? enableApplyingPayments = null,Object? convertPaymentCurrency = null,Object? enabledTaxRates = null,Object? enabledItemTaxRates = null,Object? enabledExpenseTaxRates = null,Object? calculateTaxes = null,Object? taxData = freezed,Object? eInvoice = freezed,Object? customSurchargeTaxes1 = null,Object? customSurchargeTaxes2 = null,Object? customSurchargeTaxes3 = null,Object? customSurchargeTaxes4 = null,Object? trackInventory = null,Object? stockNotification = null,Object? inventoryNotificationThreshold = null,Object? enableProductDiscount = null,Object? enableProductCost = null,Object? enableProductQuantity = null,Object? defaultQuantity = null,Object? showProductDetails = null,Object? fillProducts = null,Object? updateProducts = null,Object? convertProducts = null,Object? convertRateToClient = null,Object? stopOnUnpaidRecurring = null,Object? useQuoteTermsOnConversion = null,Object? autoStartTasks = null,Object? showTaskEndDate = null,Object? showTasksTable = null,Object? invoiceTaskDatelog = null,Object? invoiceTaskTimelog = null,Object? invoiceTaskHours = null,Object? invoiceTaskItemDescription = null,Object? invoiceTaskProject = null,Object? invoiceTaskProjectHeader = null,Object? invoiceTaskLock = null,Object? invoiceTaskDocuments = null,Object? markExpensesInvoiceable = null,Object? markExpensesPaid = null,Object? convertExpenseCurrency = null,Object? invoiceExpenseDocuments = null,Object? notifyVendorWhenPaid = null,Object? calculateExpenseTaxByAmount = null,Object? expenseInclusiveTaxes = null,Object? expenseMailboxActive = null,Object? expenseMailbox = null,Object? inboundMailboxAllowCompanyUsers = null,Object? inboundMailboxAllowVendors = null,Object? inboundMailboxAllowClients = null,Object? inboundMailboxWhitelist = null,Object? inboundMailboxBlacklist = null,Object? inboundMailboxAllowUnknown = null,Object? smtpHost = null,Object? smtpPort = null,Object? smtpEncryption = null,Object? smtpUsername = null,Object? smtpPassword = null,Object? smtpLocalDomain = null,Object? smtpVerifyPeer = null,Object? googleAnalyticsKey = null,Object? matomoId = null,Object? matomoUrl = null,Object? sessionTimeout = null,Object? defaultPasswordTimeout = null,Object? oauthPasswordRequired = null,Object? isDisabled = null,Object? markdownEnabled = null,Object? markdownEmailEnabled = null,Object? reportIncludeDrafts = null,Object? reportIncludeDeleted = null,Object? quickbooks = freezed,Object? documents = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(Company(
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
as Map<String, String>,rawSettings: null == rawSettings ? _self.rawSettings : rawSettings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as CompanySettings,enableApplyingPayments: null == enableApplyingPayments ? _self.enableApplyingPayments : enableApplyingPayments // ignore: cast_nullable_to_non_nullable
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
as List<Document>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanySettingsApiCopyWith<$Res> get settings {
  
  return $CompanySettingsApiCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}/// Create a copy of Company
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


/// Adds pattern-matching-related methods to [Company].
extension CompanyPatterns on Company {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Company value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Company() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Company value)  $default,){
final _that = this;
switch (_that) {
case _Company():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Company value)?  $default,){
final _that = this;
switch (_that) {
case _Company() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String name,  String companyKey,  String sizeId,  String industryId,  String firstMonthOfYear,  String firstDayOfWeek,  bool useCommaAsDecimalPlace,  int enabledModules,  int legalEntityId,  bool hasEInvoiceCertificate,  String eInvoiceCertificatePassphrase,  bool hasEInvoiceCertificatePassphrase,  String subdomain,  String portalDomain,  String portalMode,  bool clientCanRegister,  List<ClientRegistrationFieldApi> clientRegistrationFields,  Map<String, String> customFields,  Map<String, dynamic> rawSettings,  CompanySettings settings,  bool enableApplyingPayments,  bool convertPaymentCurrency,  int enabledTaxRates,  int enabledItemTaxRates,  int enabledExpenseTaxRates,  bool calculateTaxes,  TaxConfigApi? taxData,  Map<String, dynamic>? eInvoice,  bool customSurchargeTaxes1,  bool customSurchargeTaxes2,  bool customSurchargeTaxes3,  bool customSurchargeTaxes4,  bool trackInventory,  bool stockNotification,  int inventoryNotificationThreshold,  bool enableProductDiscount,  bool enableProductCost,  bool enableProductQuantity,  bool defaultQuantity,  bool showProductDetails,  bool fillProducts,  bool updateProducts,  bool convertProducts,  bool convertRateToClient,  bool stopOnUnpaidRecurring,  bool useQuoteTermsOnConversion,  bool autoStartTasks,  bool showTaskEndDate,  bool showTasksTable,  bool invoiceTaskDatelog,  bool invoiceTaskTimelog,  bool invoiceTaskHours,  bool invoiceTaskItemDescription,  bool invoiceTaskProject,  bool invoiceTaskProjectHeader,  bool invoiceTaskLock,  bool invoiceTaskDocuments,  bool markExpensesInvoiceable,  bool markExpensesPaid,  bool convertExpenseCurrency,  bool invoiceExpenseDocuments,  bool notifyVendorWhenPaid,  bool calculateExpenseTaxByAmount,  bool expenseInclusiveTaxes,  bool expenseMailboxActive,  String expenseMailbox,  bool inboundMailboxAllowCompanyUsers,  bool inboundMailboxAllowVendors,  bool inboundMailboxAllowClients,  String inboundMailboxWhitelist,  String inboundMailboxBlacklist,  bool inboundMailboxAllowUnknown,  String smtpHost,  int smtpPort,  String smtpEncryption,  String smtpUsername,  String smtpPassword,  String smtpLocalDomain,  bool smtpVerifyPeer,  String googleAnalyticsKey,  String matomoId,  String matomoUrl,  int sessionTimeout,  int defaultPasswordTimeout,  bool oauthPasswordRequired,  bool isDisabled,  bool markdownEnabled,  bool markdownEmailEnabled,  bool reportIncludeDrafts,  bool reportIncludeDeleted,  Map<String, dynamic>? quickbooks,  List<Document> documents,  int updatedAt,  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that.id,_that.displayName,_that.name,_that.companyKey,_that.sizeId,_that.industryId,_that.firstMonthOfYear,_that.firstDayOfWeek,_that.useCommaAsDecimalPlace,_that.enabledModules,_that.legalEntityId,_that.hasEInvoiceCertificate,_that.eInvoiceCertificatePassphrase,_that.hasEInvoiceCertificatePassphrase,_that.subdomain,_that.portalDomain,_that.portalMode,_that.clientCanRegister,_that.clientRegistrationFields,_that.customFields,_that.rawSettings,_that.settings,_that.enableApplyingPayments,_that.convertPaymentCurrency,_that.enabledTaxRates,_that.enabledItemTaxRates,_that.enabledExpenseTaxRates,_that.calculateTaxes,_that.taxData,_that.eInvoice,_that.customSurchargeTaxes1,_that.customSurchargeTaxes2,_that.customSurchargeTaxes3,_that.customSurchargeTaxes4,_that.trackInventory,_that.stockNotification,_that.inventoryNotificationThreshold,_that.enableProductDiscount,_that.enableProductCost,_that.enableProductQuantity,_that.defaultQuantity,_that.showProductDetails,_that.fillProducts,_that.updateProducts,_that.convertProducts,_that.convertRateToClient,_that.stopOnUnpaidRecurring,_that.useQuoteTermsOnConversion,_that.autoStartTasks,_that.showTaskEndDate,_that.showTasksTable,_that.invoiceTaskDatelog,_that.invoiceTaskTimelog,_that.invoiceTaskHours,_that.invoiceTaskItemDescription,_that.invoiceTaskProject,_that.invoiceTaskProjectHeader,_that.invoiceTaskLock,_that.invoiceTaskDocuments,_that.markExpensesInvoiceable,_that.markExpensesPaid,_that.convertExpenseCurrency,_that.invoiceExpenseDocuments,_that.notifyVendorWhenPaid,_that.calculateExpenseTaxByAmount,_that.expenseInclusiveTaxes,_that.expenseMailboxActive,_that.expenseMailbox,_that.inboundMailboxAllowCompanyUsers,_that.inboundMailboxAllowVendors,_that.inboundMailboxAllowClients,_that.inboundMailboxWhitelist,_that.inboundMailboxBlacklist,_that.inboundMailboxAllowUnknown,_that.smtpHost,_that.smtpPort,_that.smtpEncryption,_that.smtpUsername,_that.smtpPassword,_that.smtpLocalDomain,_that.smtpVerifyPeer,_that.googleAnalyticsKey,_that.matomoId,_that.matomoUrl,_that.sessionTimeout,_that.defaultPasswordTimeout,_that.oauthPasswordRequired,_that.isDisabled,_that.markdownEnabled,_that.markdownEmailEnabled,_that.reportIncludeDrafts,_that.reportIncludeDeleted,_that.quickbooks,_that.documents,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String name,  String companyKey,  String sizeId,  String industryId,  String firstMonthOfYear,  String firstDayOfWeek,  bool useCommaAsDecimalPlace,  int enabledModules,  int legalEntityId,  bool hasEInvoiceCertificate,  String eInvoiceCertificatePassphrase,  bool hasEInvoiceCertificatePassphrase,  String subdomain,  String portalDomain,  String portalMode,  bool clientCanRegister,  List<ClientRegistrationFieldApi> clientRegistrationFields,  Map<String, String> customFields,  Map<String, dynamic> rawSettings,  CompanySettings settings,  bool enableApplyingPayments,  bool convertPaymentCurrency,  int enabledTaxRates,  int enabledItemTaxRates,  int enabledExpenseTaxRates,  bool calculateTaxes,  TaxConfigApi? taxData,  Map<String, dynamic>? eInvoice,  bool customSurchargeTaxes1,  bool customSurchargeTaxes2,  bool customSurchargeTaxes3,  bool customSurchargeTaxes4,  bool trackInventory,  bool stockNotification,  int inventoryNotificationThreshold,  bool enableProductDiscount,  bool enableProductCost,  bool enableProductQuantity,  bool defaultQuantity,  bool showProductDetails,  bool fillProducts,  bool updateProducts,  bool convertProducts,  bool convertRateToClient,  bool stopOnUnpaidRecurring,  bool useQuoteTermsOnConversion,  bool autoStartTasks,  bool showTaskEndDate,  bool showTasksTable,  bool invoiceTaskDatelog,  bool invoiceTaskTimelog,  bool invoiceTaskHours,  bool invoiceTaskItemDescription,  bool invoiceTaskProject,  bool invoiceTaskProjectHeader,  bool invoiceTaskLock,  bool invoiceTaskDocuments,  bool markExpensesInvoiceable,  bool markExpensesPaid,  bool convertExpenseCurrency,  bool invoiceExpenseDocuments,  bool notifyVendorWhenPaid,  bool calculateExpenseTaxByAmount,  bool expenseInclusiveTaxes,  bool expenseMailboxActive,  String expenseMailbox,  bool inboundMailboxAllowCompanyUsers,  bool inboundMailboxAllowVendors,  bool inboundMailboxAllowClients,  String inboundMailboxWhitelist,  String inboundMailboxBlacklist,  bool inboundMailboxAllowUnknown,  String smtpHost,  int smtpPort,  String smtpEncryption,  String smtpUsername,  String smtpPassword,  String smtpLocalDomain,  bool smtpVerifyPeer,  String googleAnalyticsKey,  String matomoId,  String matomoUrl,  int sessionTimeout,  int defaultPasswordTimeout,  bool oauthPasswordRequired,  bool isDisabled,  bool markdownEnabled,  bool markdownEmailEnabled,  bool reportIncludeDrafts,  bool reportIncludeDeleted,  Map<String, dynamic>? quickbooks,  List<Document> documents,  int updatedAt,  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _Company():
return $default(_that.id,_that.displayName,_that.name,_that.companyKey,_that.sizeId,_that.industryId,_that.firstMonthOfYear,_that.firstDayOfWeek,_that.useCommaAsDecimalPlace,_that.enabledModules,_that.legalEntityId,_that.hasEInvoiceCertificate,_that.eInvoiceCertificatePassphrase,_that.hasEInvoiceCertificatePassphrase,_that.subdomain,_that.portalDomain,_that.portalMode,_that.clientCanRegister,_that.clientRegistrationFields,_that.customFields,_that.rawSettings,_that.settings,_that.enableApplyingPayments,_that.convertPaymentCurrency,_that.enabledTaxRates,_that.enabledItemTaxRates,_that.enabledExpenseTaxRates,_that.calculateTaxes,_that.taxData,_that.eInvoice,_that.customSurchargeTaxes1,_that.customSurchargeTaxes2,_that.customSurchargeTaxes3,_that.customSurchargeTaxes4,_that.trackInventory,_that.stockNotification,_that.inventoryNotificationThreshold,_that.enableProductDiscount,_that.enableProductCost,_that.enableProductQuantity,_that.defaultQuantity,_that.showProductDetails,_that.fillProducts,_that.updateProducts,_that.convertProducts,_that.convertRateToClient,_that.stopOnUnpaidRecurring,_that.useQuoteTermsOnConversion,_that.autoStartTasks,_that.showTaskEndDate,_that.showTasksTable,_that.invoiceTaskDatelog,_that.invoiceTaskTimelog,_that.invoiceTaskHours,_that.invoiceTaskItemDescription,_that.invoiceTaskProject,_that.invoiceTaskProjectHeader,_that.invoiceTaskLock,_that.invoiceTaskDocuments,_that.markExpensesInvoiceable,_that.markExpensesPaid,_that.convertExpenseCurrency,_that.invoiceExpenseDocuments,_that.notifyVendorWhenPaid,_that.calculateExpenseTaxByAmount,_that.expenseInclusiveTaxes,_that.expenseMailboxActive,_that.expenseMailbox,_that.inboundMailboxAllowCompanyUsers,_that.inboundMailboxAllowVendors,_that.inboundMailboxAllowClients,_that.inboundMailboxWhitelist,_that.inboundMailboxBlacklist,_that.inboundMailboxAllowUnknown,_that.smtpHost,_that.smtpPort,_that.smtpEncryption,_that.smtpUsername,_that.smtpPassword,_that.smtpLocalDomain,_that.smtpVerifyPeer,_that.googleAnalyticsKey,_that.matomoId,_that.matomoUrl,_that.sessionTimeout,_that.defaultPasswordTimeout,_that.oauthPasswordRequired,_that.isDisabled,_that.markdownEnabled,_that.markdownEmailEnabled,_that.reportIncludeDrafts,_that.reportIncludeDeleted,_that.quickbooks,_that.documents,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String name,  String companyKey,  String sizeId,  String industryId,  String firstMonthOfYear,  String firstDayOfWeek,  bool useCommaAsDecimalPlace,  int enabledModules,  int legalEntityId,  bool hasEInvoiceCertificate,  String eInvoiceCertificatePassphrase,  bool hasEInvoiceCertificatePassphrase,  String subdomain,  String portalDomain,  String portalMode,  bool clientCanRegister,  List<ClientRegistrationFieldApi> clientRegistrationFields,  Map<String, String> customFields,  Map<String, dynamic> rawSettings,  CompanySettings settings,  bool enableApplyingPayments,  bool convertPaymentCurrency,  int enabledTaxRates,  int enabledItemTaxRates,  int enabledExpenseTaxRates,  bool calculateTaxes,  TaxConfigApi? taxData,  Map<String, dynamic>? eInvoice,  bool customSurchargeTaxes1,  bool customSurchargeTaxes2,  bool customSurchargeTaxes3,  bool customSurchargeTaxes4,  bool trackInventory,  bool stockNotification,  int inventoryNotificationThreshold,  bool enableProductDiscount,  bool enableProductCost,  bool enableProductQuantity,  bool defaultQuantity,  bool showProductDetails,  bool fillProducts,  bool updateProducts,  bool convertProducts,  bool convertRateToClient,  bool stopOnUnpaidRecurring,  bool useQuoteTermsOnConversion,  bool autoStartTasks,  bool showTaskEndDate,  bool showTasksTable,  bool invoiceTaskDatelog,  bool invoiceTaskTimelog,  bool invoiceTaskHours,  bool invoiceTaskItemDescription,  bool invoiceTaskProject,  bool invoiceTaskProjectHeader,  bool invoiceTaskLock,  bool invoiceTaskDocuments,  bool markExpensesInvoiceable,  bool markExpensesPaid,  bool convertExpenseCurrency,  bool invoiceExpenseDocuments,  bool notifyVendorWhenPaid,  bool calculateExpenseTaxByAmount,  bool expenseInclusiveTaxes,  bool expenseMailboxActive,  String expenseMailbox,  bool inboundMailboxAllowCompanyUsers,  bool inboundMailboxAllowVendors,  bool inboundMailboxAllowClients,  String inboundMailboxWhitelist,  String inboundMailboxBlacklist,  bool inboundMailboxAllowUnknown,  String smtpHost,  int smtpPort,  String smtpEncryption,  String smtpUsername,  String smtpPassword,  String smtpLocalDomain,  bool smtpVerifyPeer,  String googleAnalyticsKey,  String matomoId,  String matomoUrl,  int sessionTimeout,  int defaultPasswordTimeout,  bool oauthPasswordRequired,  bool isDisabled,  bool markdownEnabled,  bool markdownEmailEnabled,  bool reportIncludeDrafts,  bool reportIncludeDeleted,  Map<String, dynamic>? quickbooks,  List<Document> documents,  int updatedAt,  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that.id,_that.displayName,_that.name,_that.companyKey,_that.sizeId,_that.industryId,_that.firstMonthOfYear,_that.firstDayOfWeek,_that.useCommaAsDecimalPlace,_that.enabledModules,_that.legalEntityId,_that.hasEInvoiceCertificate,_that.eInvoiceCertificatePassphrase,_that.hasEInvoiceCertificatePassphrase,_that.subdomain,_that.portalDomain,_that.portalMode,_that.clientCanRegister,_that.clientRegistrationFields,_that.customFields,_that.rawSettings,_that.settings,_that.enableApplyingPayments,_that.convertPaymentCurrency,_that.enabledTaxRates,_that.enabledItemTaxRates,_that.enabledExpenseTaxRates,_that.calculateTaxes,_that.taxData,_that.eInvoice,_that.customSurchargeTaxes1,_that.customSurchargeTaxes2,_that.customSurchargeTaxes3,_that.customSurchargeTaxes4,_that.trackInventory,_that.stockNotification,_that.inventoryNotificationThreshold,_that.enableProductDiscount,_that.enableProductCost,_that.enableProductQuantity,_that.defaultQuantity,_that.showProductDetails,_that.fillProducts,_that.updateProducts,_that.convertProducts,_that.convertRateToClient,_that.stopOnUnpaidRecurring,_that.useQuoteTermsOnConversion,_that.autoStartTasks,_that.showTaskEndDate,_that.showTasksTable,_that.invoiceTaskDatelog,_that.invoiceTaskTimelog,_that.invoiceTaskHours,_that.invoiceTaskItemDescription,_that.invoiceTaskProject,_that.invoiceTaskProjectHeader,_that.invoiceTaskLock,_that.invoiceTaskDocuments,_that.markExpensesInvoiceable,_that.markExpensesPaid,_that.convertExpenseCurrency,_that.invoiceExpenseDocuments,_that.notifyVendorWhenPaid,_that.calculateExpenseTaxByAmount,_that.expenseInclusiveTaxes,_that.expenseMailboxActive,_that.expenseMailbox,_that.inboundMailboxAllowCompanyUsers,_that.inboundMailboxAllowVendors,_that.inboundMailboxAllowClients,_that.inboundMailboxWhitelist,_that.inboundMailboxBlacklist,_that.inboundMailboxAllowUnknown,_that.smtpHost,_that.smtpPort,_that.smtpEncryption,_that.smtpUsername,_that.smtpPassword,_that.smtpLocalDomain,_that.smtpVerifyPeer,_that.googleAnalyticsKey,_that.matomoId,_that.matomoUrl,_that.sessionTimeout,_that.defaultPasswordTimeout,_that.oauthPasswordRequired,_that.isDisabled,_that.markdownEnabled,_that.markdownEmailEnabled,_that.reportIncludeDrafts,_that.reportIncludeDeleted,_that.quickbooks,_that.documents,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Company extends Company {
  const _Company({this.id = '', this.displayName = '', this.name = '', this.companyKey = '', this.sizeId = '', this.industryId = '', this.firstMonthOfYear = '', this.firstDayOfWeek = '', this.useCommaAsDecimalPlace = false, this.enabledModules = 0, this.legalEntityId = 0, this.hasEInvoiceCertificate = false, this.eInvoiceCertificatePassphrase = '', this.hasEInvoiceCertificatePassphrase = false, this.subdomain = '', this.portalDomain = '', this.portalMode = '', this.clientCanRegister = false,  List<ClientRegistrationFieldApi> clientRegistrationFields = const <ClientRegistrationFieldApi>[],  Map<String, String> customFields = const <String, String>{},  Map<String, dynamic> rawSettings = const <String, dynamic>{}, this.settings = const CompanySettings(), this.enableApplyingPayments = false, this.convertPaymentCurrency = false, this.enabledTaxRates = 0, this.enabledItemTaxRates = 0, this.enabledExpenseTaxRates = 0, this.calculateTaxes = false, this.taxData,  Map<String, dynamic>? eInvoice, this.customSurchargeTaxes1 = false, this.customSurchargeTaxes2 = false, this.customSurchargeTaxes3 = false, this.customSurchargeTaxes4 = false, this.trackInventory = false, this.stockNotification = false, this.inventoryNotificationThreshold = 0, this.enableProductDiscount = false, this.enableProductCost = false, this.enableProductQuantity = false, this.defaultQuantity = false, this.showProductDetails = false, this.fillProducts = false, this.updateProducts = false, this.convertProducts = false, this.convertRateToClient = false, this.stopOnUnpaidRecurring = false, this.useQuoteTermsOnConversion = false, this.autoStartTasks = false, this.showTaskEndDate = false, this.showTasksTable = false, this.invoiceTaskDatelog = false, this.invoiceTaskTimelog = false, this.invoiceTaskHours = false, this.invoiceTaskItemDescription = false, this.invoiceTaskProject = false, this.invoiceTaskProjectHeader = false, this.invoiceTaskLock = false, this.invoiceTaskDocuments = false, this.markExpensesInvoiceable = false, this.markExpensesPaid = false, this.convertExpenseCurrency = false, this.invoiceExpenseDocuments = false, this.notifyVendorWhenPaid = false, this.calculateExpenseTaxByAmount = false, this.expenseInclusiveTaxes = false, this.expenseMailboxActive = false, this.expenseMailbox = '', this.inboundMailboxAllowCompanyUsers = false, this.inboundMailboxAllowVendors = false, this.inboundMailboxAllowClients = false, this.inboundMailboxWhitelist = '', this.inboundMailboxBlacklist = '', this.inboundMailboxAllowUnknown = false, this.smtpHost = '', this.smtpPort = 0, this.smtpEncryption = 'TLS', this.smtpUsername = '', this.smtpPassword = '', this.smtpLocalDomain = '', this.smtpVerifyPeer = true, this.googleAnalyticsKey = '', this.matomoId = '', this.matomoUrl = '', this.sessionTimeout = 0, this.defaultPasswordTimeout = 0, this.oauthPasswordRequired = false, this.isDisabled = false, this.markdownEnabled = false, this.markdownEmailEnabled = false, this.reportIncludeDrafts = false, this.reportIncludeDeleted = false,  Map<String, dynamic>? quickbooks,  List<Document> documents = const <Document>[], this.updatedAt = 0, this.archivedAt = 0}): _clientRegistrationFields = clientRegistrationFields,_customFields = customFields,_rawSettings = rawSettings,_eInvoice = eInvoice,_quickbooks = quickbooks,_documents = documents,super._();
  

@override@JsonKey() final  String id;
@override@JsonKey() final  String displayName;
@override@JsonKey() final  String name;
@override@JsonKey() final  String companyKey;
@override@JsonKey() final  String sizeId;
@override@JsonKey() final  String industryId;
@override@JsonKey() final  String firstMonthOfYear;
@override@JsonKey() final  String firstDayOfWeek;
@override@JsonKey() final  bool useCommaAsDecimalPlace;
@override@JsonKey() final  int enabledModules;
@override@JsonKey() final  int legalEntityId;
@override@JsonKey() final  bool hasEInvoiceCertificate;
@override@JsonKey() final  String eInvoiceCertificatePassphrase;
@override@JsonKey() final  bool hasEInvoiceCertificatePassphrase;
@override@JsonKey() final  String subdomain;
@override@JsonKey() final  String portalDomain;
@override@JsonKey() final  String portalMode;
@override@JsonKey() final  bool clientCanRegister;
 final  List<ClientRegistrationFieldApi> _clientRegistrationFields;
@override@JsonKey() List<ClientRegistrationFieldApi> get clientRegistrationFields {
  if (_clientRegistrationFields is EqualUnmodifiableListView) return _clientRegistrationFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clientRegistrationFields);
}

 final  Map<String, String> _customFields;
@override@JsonKey() Map<String, String> get customFields {
  if (_customFields is EqualUnmodifiableMapView) return _customFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_customFields);
}

 final  Map<String, dynamic> _rawSettings;
@override@JsonKey() Map<String, dynamic> get rawSettings {
  if (_rawSettings is EqualUnmodifiableMapView) return _rawSettings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_rawSettings);
}

@override@JsonKey() final  CompanySettings settings;
@override@JsonKey() final  bool enableApplyingPayments;
@override@JsonKey() final  bool convertPaymentCurrency;
@override@JsonKey() final  int enabledTaxRates;
@override@JsonKey() final  int enabledItemTaxRates;
@override@JsonKey() final  int enabledExpenseTaxRates;
@override@JsonKey() final  bool calculateTaxes;
@override final  TaxConfigApi? taxData;
 final  Map<String, dynamic>? _eInvoice;
@override Map<String, dynamic>? get eInvoice {
  final value = _eInvoice;
  if (value == null) return null;
  if (_eInvoice is EqualUnmodifiableMapView) return _eInvoice;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  bool customSurchargeTaxes1;
@override@JsonKey() final  bool customSurchargeTaxes2;
@override@JsonKey() final  bool customSurchargeTaxes3;
@override@JsonKey() final  bool customSurchargeTaxes4;
@override@JsonKey() final  bool trackInventory;
@override@JsonKey() final  bool stockNotification;
@override@JsonKey() final  int inventoryNotificationThreshold;
@override@JsonKey() final  bool enableProductDiscount;
@override@JsonKey() final  bool enableProductCost;
@override@JsonKey() final  bool enableProductQuantity;
@override@JsonKey() final  bool defaultQuantity;
@override@JsonKey() final  bool showProductDetails;
@override@JsonKey() final  bool fillProducts;
@override@JsonKey() final  bool updateProducts;
@override@JsonKey() final  bool convertProducts;
@override@JsonKey() final  bool convertRateToClient;
@override@JsonKey() final  bool stopOnUnpaidRecurring;
@override@JsonKey() final  bool useQuoteTermsOnConversion;
@override@JsonKey() final  bool autoStartTasks;
@override@JsonKey() final  bool showTaskEndDate;
@override@JsonKey() final  bool showTasksTable;
@override@JsonKey() final  bool invoiceTaskDatelog;
@override@JsonKey() final  bool invoiceTaskTimelog;
@override@JsonKey() final  bool invoiceTaskHours;
@override@JsonKey() final  bool invoiceTaskItemDescription;
@override@JsonKey() final  bool invoiceTaskProject;
@override@JsonKey() final  bool invoiceTaskProjectHeader;
@override@JsonKey() final  bool invoiceTaskLock;
@override@JsonKey() final  bool invoiceTaskDocuments;
@override@JsonKey() final  bool markExpensesInvoiceable;
@override@JsonKey() final  bool markExpensesPaid;
@override@JsonKey() final  bool convertExpenseCurrency;
@override@JsonKey() final  bool invoiceExpenseDocuments;
@override@JsonKey() final  bool notifyVendorWhenPaid;
@override@JsonKey() final  bool calculateExpenseTaxByAmount;
@override@JsonKey() final  bool expenseInclusiveTaxes;
@override@JsonKey() final  bool expenseMailboxActive;
@override@JsonKey() final  String expenseMailbox;
@override@JsonKey() final  bool inboundMailboxAllowCompanyUsers;
@override@JsonKey() final  bool inboundMailboxAllowVendors;
@override@JsonKey() final  bool inboundMailboxAllowClients;
@override@JsonKey() final  String inboundMailboxWhitelist;
@override@JsonKey() final  String inboundMailboxBlacklist;
@override@JsonKey() final  bool inboundMailboxAllowUnknown;
@override@JsonKey() final  String smtpHost;
@override@JsonKey() final  int smtpPort;
@override@JsonKey() final  String smtpEncryption;
@override@JsonKey() final  String smtpUsername;
@override@JsonKey() final  String smtpPassword;
@override@JsonKey() final  String smtpLocalDomain;
@override@JsonKey() final  bool smtpVerifyPeer;
@override@JsonKey() final  String googleAnalyticsKey;
@override@JsonKey() final  String matomoId;
@override@JsonKey() final  String matomoUrl;
@override@JsonKey() final  int sessionTimeout;
@override@JsonKey() final  int defaultPasswordTimeout;
@override@JsonKey() final  bool oauthPasswordRequired;
@override@JsonKey() final  bool isDisabled;
@override@JsonKey() final  bool markdownEnabled;
@override@JsonKey() final  bool markdownEmailEnabled;
@override@JsonKey() final  bool reportIncludeDrafts;
@override@JsonKey() final  bool reportIncludeDeleted;
 final  Map<String, dynamic>? _quickbooks;
@override Map<String, dynamic>? get quickbooks {
  final value = _quickbooks;
  if (value == null) return null;
  if (_quickbooks is EqualUnmodifiableMapView) return _quickbooks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<Document> _documents;
@override@JsonKey() List<Document> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}

@override@JsonKey() final  int updatedAt;
@override@JsonKey() final  int archivedAt;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyCopyWith<_Company> get copyWith => __$CompanyCopyWithImpl<_Company>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Company&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.name, name) || other.name == name)&&(identical(other.companyKey, companyKey) || other.companyKey == companyKey)&&(identical(other.sizeId, sizeId) || other.sizeId == sizeId)&&(identical(other.industryId, industryId) || other.industryId == industryId)&&(identical(other.firstMonthOfYear, firstMonthOfYear) || other.firstMonthOfYear == firstMonthOfYear)&&(identical(other.firstDayOfWeek, firstDayOfWeek) || other.firstDayOfWeek == firstDayOfWeek)&&(identical(other.useCommaAsDecimalPlace, useCommaAsDecimalPlace) || other.useCommaAsDecimalPlace == useCommaAsDecimalPlace)&&(identical(other.enabledModules, enabledModules) || other.enabledModules == enabledModules)&&(identical(other.legalEntityId, legalEntityId) || other.legalEntityId == legalEntityId)&&(identical(other.hasEInvoiceCertificate, hasEInvoiceCertificate) || other.hasEInvoiceCertificate == hasEInvoiceCertificate)&&(identical(other.eInvoiceCertificatePassphrase, eInvoiceCertificatePassphrase) || other.eInvoiceCertificatePassphrase == eInvoiceCertificatePassphrase)&&(identical(other.hasEInvoiceCertificatePassphrase, hasEInvoiceCertificatePassphrase) || other.hasEInvoiceCertificatePassphrase == hasEInvoiceCertificatePassphrase)&&(identical(other.subdomain, subdomain) || other.subdomain == subdomain)&&(identical(other.portalDomain, portalDomain) || other.portalDomain == portalDomain)&&(identical(other.portalMode, portalMode) || other.portalMode == portalMode)&&(identical(other.clientCanRegister, clientCanRegister) || other.clientCanRegister == clientCanRegister)&&const DeepCollectionEquality().equals(other.clientRegistrationFields, _clientRegistrationFields)&&const DeepCollectionEquality().equals(other.customFields, _customFields)&&const DeepCollectionEquality().equals(other.rawSettings, _rawSettings)&&(identical(other.settings, settings) || other.settings == settings)&&(identical(other.enableApplyingPayments, enableApplyingPayments) || other.enableApplyingPayments == enableApplyingPayments)&&(identical(other.convertPaymentCurrency, convertPaymentCurrency) || other.convertPaymentCurrency == convertPaymentCurrency)&&(identical(other.enabledTaxRates, enabledTaxRates) || other.enabledTaxRates == enabledTaxRates)&&(identical(other.enabledItemTaxRates, enabledItemTaxRates) || other.enabledItemTaxRates == enabledItemTaxRates)&&(identical(other.enabledExpenseTaxRates, enabledExpenseTaxRates) || other.enabledExpenseTaxRates == enabledExpenseTaxRates)&&(identical(other.calculateTaxes, calculateTaxes) || other.calculateTaxes == calculateTaxes)&&(identical(other.taxData, taxData) || other.taxData == taxData)&&const DeepCollectionEquality().equals(other.eInvoice, _eInvoice)&&(identical(other.customSurchargeTaxes1, customSurchargeTaxes1) || other.customSurchargeTaxes1 == customSurchargeTaxes1)&&(identical(other.customSurchargeTaxes2, customSurchargeTaxes2) || other.customSurchargeTaxes2 == customSurchargeTaxes2)&&(identical(other.customSurchargeTaxes3, customSurchargeTaxes3) || other.customSurchargeTaxes3 == customSurchargeTaxes3)&&(identical(other.customSurchargeTaxes4, customSurchargeTaxes4) || other.customSurchargeTaxes4 == customSurchargeTaxes4)&&(identical(other.trackInventory, trackInventory) || other.trackInventory == trackInventory)&&(identical(other.stockNotification, stockNotification) || other.stockNotification == stockNotification)&&(identical(other.inventoryNotificationThreshold, inventoryNotificationThreshold) || other.inventoryNotificationThreshold == inventoryNotificationThreshold)&&(identical(other.enableProductDiscount, enableProductDiscount) || other.enableProductDiscount == enableProductDiscount)&&(identical(other.enableProductCost, enableProductCost) || other.enableProductCost == enableProductCost)&&(identical(other.enableProductQuantity, enableProductQuantity) || other.enableProductQuantity == enableProductQuantity)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.showProductDetails, showProductDetails) || other.showProductDetails == showProductDetails)&&(identical(other.fillProducts, fillProducts) || other.fillProducts == fillProducts)&&(identical(other.updateProducts, updateProducts) || other.updateProducts == updateProducts)&&(identical(other.convertProducts, convertProducts) || other.convertProducts == convertProducts)&&(identical(other.convertRateToClient, convertRateToClient) || other.convertRateToClient == convertRateToClient)&&(identical(other.stopOnUnpaidRecurring, stopOnUnpaidRecurring) || other.stopOnUnpaidRecurring == stopOnUnpaidRecurring)&&(identical(other.useQuoteTermsOnConversion, useQuoteTermsOnConversion) || other.useQuoteTermsOnConversion == useQuoteTermsOnConversion)&&(identical(other.autoStartTasks, autoStartTasks) || other.autoStartTasks == autoStartTasks)&&(identical(other.showTaskEndDate, showTaskEndDate) || other.showTaskEndDate == showTaskEndDate)&&(identical(other.showTasksTable, showTasksTable) || other.showTasksTable == showTasksTable)&&(identical(other.invoiceTaskDatelog, invoiceTaskDatelog) || other.invoiceTaskDatelog == invoiceTaskDatelog)&&(identical(other.invoiceTaskTimelog, invoiceTaskTimelog) || other.invoiceTaskTimelog == invoiceTaskTimelog)&&(identical(other.invoiceTaskHours, invoiceTaskHours) || other.invoiceTaskHours == invoiceTaskHours)&&(identical(other.invoiceTaskItemDescription, invoiceTaskItemDescription) || other.invoiceTaskItemDescription == invoiceTaskItemDescription)&&(identical(other.invoiceTaskProject, invoiceTaskProject) || other.invoiceTaskProject == invoiceTaskProject)&&(identical(other.invoiceTaskProjectHeader, invoiceTaskProjectHeader) || other.invoiceTaskProjectHeader == invoiceTaskProjectHeader)&&(identical(other.invoiceTaskLock, invoiceTaskLock) || other.invoiceTaskLock == invoiceTaskLock)&&(identical(other.invoiceTaskDocuments, invoiceTaskDocuments) || other.invoiceTaskDocuments == invoiceTaskDocuments)&&(identical(other.markExpensesInvoiceable, markExpensesInvoiceable) || other.markExpensesInvoiceable == markExpensesInvoiceable)&&(identical(other.markExpensesPaid, markExpensesPaid) || other.markExpensesPaid == markExpensesPaid)&&(identical(other.convertExpenseCurrency, convertExpenseCurrency) || other.convertExpenseCurrency == convertExpenseCurrency)&&(identical(other.invoiceExpenseDocuments, invoiceExpenseDocuments) || other.invoiceExpenseDocuments == invoiceExpenseDocuments)&&(identical(other.notifyVendorWhenPaid, notifyVendorWhenPaid) || other.notifyVendorWhenPaid == notifyVendorWhenPaid)&&(identical(other.calculateExpenseTaxByAmount, calculateExpenseTaxByAmount) || other.calculateExpenseTaxByAmount == calculateExpenseTaxByAmount)&&(identical(other.expenseInclusiveTaxes, expenseInclusiveTaxes) || other.expenseInclusiveTaxes == expenseInclusiveTaxes)&&(identical(other.expenseMailboxActive, expenseMailboxActive) || other.expenseMailboxActive == expenseMailboxActive)&&(identical(other.expenseMailbox, expenseMailbox) || other.expenseMailbox == expenseMailbox)&&(identical(other.inboundMailboxAllowCompanyUsers, inboundMailboxAllowCompanyUsers) || other.inboundMailboxAllowCompanyUsers == inboundMailboxAllowCompanyUsers)&&(identical(other.inboundMailboxAllowVendors, inboundMailboxAllowVendors) || other.inboundMailboxAllowVendors == inboundMailboxAllowVendors)&&(identical(other.inboundMailboxAllowClients, inboundMailboxAllowClients) || other.inboundMailboxAllowClients == inboundMailboxAllowClients)&&(identical(other.inboundMailboxWhitelist, inboundMailboxWhitelist) || other.inboundMailboxWhitelist == inboundMailboxWhitelist)&&(identical(other.inboundMailboxBlacklist, inboundMailboxBlacklist) || other.inboundMailboxBlacklist == inboundMailboxBlacklist)&&(identical(other.inboundMailboxAllowUnknown, inboundMailboxAllowUnknown) || other.inboundMailboxAllowUnknown == inboundMailboxAllowUnknown)&&(identical(other.smtpHost, smtpHost) || other.smtpHost == smtpHost)&&(identical(other.smtpPort, smtpPort) || other.smtpPort == smtpPort)&&(identical(other.smtpEncryption, smtpEncryption) || other.smtpEncryption == smtpEncryption)&&(identical(other.smtpUsername, smtpUsername) || other.smtpUsername == smtpUsername)&&(identical(other.smtpPassword, smtpPassword) || other.smtpPassword == smtpPassword)&&(identical(other.smtpLocalDomain, smtpLocalDomain) || other.smtpLocalDomain == smtpLocalDomain)&&(identical(other.smtpVerifyPeer, smtpVerifyPeer) || other.smtpVerifyPeer == smtpVerifyPeer)&&(identical(other.googleAnalyticsKey, googleAnalyticsKey) || other.googleAnalyticsKey == googleAnalyticsKey)&&(identical(other.matomoId, matomoId) || other.matomoId == matomoId)&&(identical(other.matomoUrl, matomoUrl) || other.matomoUrl == matomoUrl)&&(identical(other.sessionTimeout, sessionTimeout) || other.sessionTimeout == sessionTimeout)&&(identical(other.defaultPasswordTimeout, defaultPasswordTimeout) || other.defaultPasswordTimeout == defaultPasswordTimeout)&&(identical(other.oauthPasswordRequired, oauthPasswordRequired) || other.oauthPasswordRequired == oauthPasswordRequired)&&(identical(other.isDisabled, isDisabled) || other.isDisabled == isDisabled)&&(identical(other.markdownEnabled, markdownEnabled) || other.markdownEnabled == markdownEnabled)&&(identical(other.markdownEmailEnabled, markdownEmailEnabled) || other.markdownEmailEnabled == markdownEmailEnabled)&&(identical(other.reportIncludeDrafts, reportIncludeDrafts) || other.reportIncludeDrafts == reportIncludeDrafts)&&(identical(other.reportIncludeDeleted, reportIncludeDeleted) || other.reportIncludeDeleted == reportIncludeDeleted)&&const DeepCollectionEquality().equals(other.quickbooks, _quickbooks)&&const DeepCollectionEquality().equals(other.documents, _documents)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,displayName,name,companyKey,sizeId,industryId,firstMonthOfYear,firstDayOfWeek,useCommaAsDecimalPlace,enabledModules,legalEntityId,hasEInvoiceCertificate,eInvoiceCertificatePassphrase,hasEInvoiceCertificatePassphrase,subdomain,portalDomain,portalMode,clientCanRegister,const DeepCollectionEquality().hash(_clientRegistrationFields),const DeepCollectionEquality().hash(_customFields),const DeepCollectionEquality().hash(_rawSettings),settings,enableApplyingPayments,convertPaymentCurrency,enabledTaxRates,enabledItemTaxRates,enabledExpenseTaxRates,calculateTaxes,taxData,const DeepCollectionEquality().hash(_eInvoice),customSurchargeTaxes1,customSurchargeTaxes2,customSurchargeTaxes3,customSurchargeTaxes4,trackInventory,stockNotification,inventoryNotificationThreshold,enableProductDiscount,enableProductCost,enableProductQuantity,defaultQuantity,showProductDetails,fillProducts,updateProducts,convertProducts,convertRateToClient,stopOnUnpaidRecurring,useQuoteTermsOnConversion,autoStartTasks,showTaskEndDate,showTasksTable,invoiceTaskDatelog,invoiceTaskTimelog,invoiceTaskHours,invoiceTaskItemDescription,invoiceTaskProject,invoiceTaskProjectHeader,invoiceTaskLock,invoiceTaskDocuments,markExpensesInvoiceable,markExpensesPaid,convertExpenseCurrency,invoiceExpenseDocuments,notifyVendorWhenPaid,calculateExpenseTaxByAmount,expenseInclusiveTaxes,expenseMailboxActive,expenseMailbox,inboundMailboxAllowCompanyUsers,inboundMailboxAllowVendors,inboundMailboxAllowClients,inboundMailboxWhitelist,inboundMailboxBlacklist,inboundMailboxAllowUnknown,smtpHost,smtpPort,smtpEncryption,smtpUsername,smtpPassword,smtpLocalDomain,smtpVerifyPeer,googleAnalyticsKey,matomoId,matomoUrl,sessionTimeout,defaultPasswordTimeout,oauthPasswordRequired,isDisabled,markdownEnabled,markdownEmailEnabled,reportIncludeDrafts,reportIncludeDeleted,const DeepCollectionEquality().hash(_quickbooks),const DeepCollectionEquality().hash(_documents),updatedAt,archivedAt]);
}

@override
String toString() {
    return 'Company(id: $id, displayName: $displayName, name: $name, companyKey: $companyKey, sizeId: $sizeId, industryId: $industryId, firstMonthOfYear: $firstMonthOfYear, firstDayOfWeek: $firstDayOfWeek, useCommaAsDecimalPlace: $useCommaAsDecimalPlace, enabledModules: $enabledModules, legalEntityId: $legalEntityId, hasEInvoiceCertificate: $hasEInvoiceCertificate, eInvoiceCertificatePassphrase: $eInvoiceCertificatePassphrase, hasEInvoiceCertificatePassphrase: $hasEInvoiceCertificatePassphrase, subdomain: $subdomain, portalDomain: $portalDomain, portalMode: $portalMode, clientCanRegister: $clientCanRegister, clientRegistrationFields: $clientRegistrationFields, customFields: $customFields, rawSettings: $rawSettings, settings: $settings, enableApplyingPayments: $enableApplyingPayments, convertPaymentCurrency: $convertPaymentCurrency, enabledTaxRates: $enabledTaxRates, enabledItemTaxRates: $enabledItemTaxRates, enabledExpenseTaxRates: $enabledExpenseTaxRates, calculateTaxes: $calculateTaxes, taxData: $taxData, eInvoice: $eInvoice, customSurchargeTaxes1: $customSurchargeTaxes1, customSurchargeTaxes2: $customSurchargeTaxes2, customSurchargeTaxes3: $customSurchargeTaxes3, customSurchargeTaxes4: $customSurchargeTaxes4, trackInventory: $trackInventory, stockNotification: $stockNotification, inventoryNotificationThreshold: $inventoryNotificationThreshold, enableProductDiscount: $enableProductDiscount, enableProductCost: $enableProductCost, enableProductQuantity: $enableProductQuantity, defaultQuantity: $defaultQuantity, showProductDetails: $showProductDetails, fillProducts: $fillProducts, updateProducts: $updateProducts, convertProducts: $convertProducts, convertRateToClient: $convertRateToClient, stopOnUnpaidRecurring: $stopOnUnpaidRecurring, useQuoteTermsOnConversion: $useQuoteTermsOnConversion, autoStartTasks: $autoStartTasks, showTaskEndDate: $showTaskEndDate, showTasksTable: $showTasksTable, invoiceTaskDatelog: $invoiceTaskDatelog, invoiceTaskTimelog: $invoiceTaskTimelog, invoiceTaskHours: $invoiceTaskHours, invoiceTaskItemDescription: $invoiceTaskItemDescription, invoiceTaskProject: $invoiceTaskProject, invoiceTaskProjectHeader: $invoiceTaskProjectHeader, invoiceTaskLock: $invoiceTaskLock, invoiceTaskDocuments: $invoiceTaskDocuments, markExpensesInvoiceable: $markExpensesInvoiceable, markExpensesPaid: $markExpensesPaid, convertExpenseCurrency: $convertExpenseCurrency, invoiceExpenseDocuments: $invoiceExpenseDocuments, notifyVendorWhenPaid: $notifyVendorWhenPaid, calculateExpenseTaxByAmount: $calculateExpenseTaxByAmount, expenseInclusiveTaxes: $expenseInclusiveTaxes, expenseMailboxActive: $expenseMailboxActive, expenseMailbox: $expenseMailbox, inboundMailboxAllowCompanyUsers: $inboundMailboxAllowCompanyUsers, inboundMailboxAllowVendors: $inboundMailboxAllowVendors, inboundMailboxAllowClients: $inboundMailboxAllowClients, inboundMailboxWhitelist: $inboundMailboxWhitelist, inboundMailboxBlacklist: $inboundMailboxBlacklist, inboundMailboxAllowUnknown: $inboundMailboxAllowUnknown, smtpHost: $smtpHost, smtpPort: $smtpPort, smtpEncryption: $smtpEncryption, smtpUsername: $smtpUsername, smtpPassword: $smtpPassword, smtpLocalDomain: $smtpLocalDomain, smtpVerifyPeer: $smtpVerifyPeer, googleAnalyticsKey: $googleAnalyticsKey, matomoId: $matomoId, matomoUrl: $matomoUrl, sessionTimeout: $sessionTimeout, defaultPasswordTimeout: $defaultPasswordTimeout, oauthPasswordRequired: $oauthPasswordRequired, isDisabled: $isDisabled, markdownEnabled: $markdownEnabled, markdownEmailEnabled: $markdownEmailEnabled, reportIncludeDrafts: $reportIncludeDrafts, reportIncludeDeleted: $reportIncludeDeleted, quickbooks: $quickbooks, documents: $documents, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$CompanyCopyWith<$Res> implements $CompanyCopyWith<$Res> {
  factory _$CompanyCopyWith(_Company value, $Res Function(_Company) _then) = __$CompanyCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String name, String companyKey, String sizeId, String industryId, String firstMonthOfYear, String firstDayOfWeek, bool useCommaAsDecimalPlace, int enabledModules, int legalEntityId, bool hasEInvoiceCertificate, String eInvoiceCertificatePassphrase, bool hasEInvoiceCertificatePassphrase, String subdomain, String portalDomain, String portalMode, bool clientCanRegister, List<ClientRegistrationFieldApi> clientRegistrationFields, Map<String, String> customFields, Map<String, dynamic> rawSettings, CompanySettings settings, bool enableApplyingPayments, bool convertPaymentCurrency, int enabledTaxRates, int enabledItemTaxRates, int enabledExpenseTaxRates, bool calculateTaxes, TaxConfigApi? taxData, Map<String, dynamic>? eInvoice, bool customSurchargeTaxes1, bool customSurchargeTaxes2, bool customSurchargeTaxes3, bool customSurchargeTaxes4, bool trackInventory, bool stockNotification, int inventoryNotificationThreshold, bool enableProductDiscount, bool enableProductCost, bool enableProductQuantity, bool defaultQuantity, bool showProductDetails, bool fillProducts, bool updateProducts, bool convertProducts, bool convertRateToClient, bool stopOnUnpaidRecurring, bool useQuoteTermsOnConversion, bool autoStartTasks, bool showTaskEndDate, bool showTasksTable, bool invoiceTaskDatelog, bool invoiceTaskTimelog, bool invoiceTaskHours, bool invoiceTaskItemDescription, bool invoiceTaskProject, bool invoiceTaskProjectHeader, bool invoiceTaskLock, bool invoiceTaskDocuments, bool markExpensesInvoiceable, bool markExpensesPaid, bool convertExpenseCurrency, bool invoiceExpenseDocuments, bool notifyVendorWhenPaid, bool calculateExpenseTaxByAmount, bool expenseInclusiveTaxes, bool expenseMailboxActive, String expenseMailbox, bool inboundMailboxAllowCompanyUsers, bool inboundMailboxAllowVendors, bool inboundMailboxAllowClients, String inboundMailboxWhitelist, String inboundMailboxBlacklist, bool inboundMailboxAllowUnknown, String smtpHost, int smtpPort, String smtpEncryption, String smtpUsername, String smtpPassword, String smtpLocalDomain, bool smtpVerifyPeer, String googleAnalyticsKey, String matomoId, String matomoUrl, int sessionTimeout, int defaultPasswordTimeout, bool oauthPasswordRequired, bool isDisabled, bool markdownEnabled, bool markdownEmailEnabled, bool reportIncludeDrafts, bool reportIncludeDeleted, Map<String, dynamic>? quickbooks, List<Document> documents, int updatedAt, int archivedAt
});


@override $CompanySettingsApiCopyWith<$Res> get settings;@override $TaxConfigApiCopyWith<$Res>? get taxData;

}
/// @nodoc
class __$CompanyCopyWithImpl<$Res>
    implements _$CompanyCopyWith<$Res> {
  __$CompanyCopyWithImpl(this._self, this._then);

  final _Company _self;
  final $Res Function(_Company) _then;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? name = null,Object? companyKey = null,Object? sizeId = null,Object? industryId = null,Object? firstMonthOfYear = null,Object? firstDayOfWeek = null,Object? useCommaAsDecimalPlace = null,Object? enabledModules = null,Object? legalEntityId = null,Object? hasEInvoiceCertificate = null,Object? eInvoiceCertificatePassphrase = null,Object? hasEInvoiceCertificatePassphrase = null,Object? subdomain = null,Object? portalDomain = null,Object? portalMode = null,Object? clientCanRegister = null,Object? clientRegistrationFields = null,Object? customFields = null,Object? rawSettings = null,Object? settings = null,Object? enableApplyingPayments = null,Object? convertPaymentCurrency = null,Object? enabledTaxRates = null,Object? enabledItemTaxRates = null,Object? enabledExpenseTaxRates = null,Object? calculateTaxes = null,Object? taxData = freezed,Object? eInvoice = freezed,Object? customSurchargeTaxes1 = null,Object? customSurchargeTaxes2 = null,Object? customSurchargeTaxes3 = null,Object? customSurchargeTaxes4 = null,Object? trackInventory = null,Object? stockNotification = null,Object? inventoryNotificationThreshold = null,Object? enableProductDiscount = null,Object? enableProductCost = null,Object? enableProductQuantity = null,Object? defaultQuantity = null,Object? showProductDetails = null,Object? fillProducts = null,Object? updateProducts = null,Object? convertProducts = null,Object? convertRateToClient = null,Object? stopOnUnpaidRecurring = null,Object? useQuoteTermsOnConversion = null,Object? autoStartTasks = null,Object? showTaskEndDate = null,Object? showTasksTable = null,Object? invoiceTaskDatelog = null,Object? invoiceTaskTimelog = null,Object? invoiceTaskHours = null,Object? invoiceTaskItemDescription = null,Object? invoiceTaskProject = null,Object? invoiceTaskProjectHeader = null,Object? invoiceTaskLock = null,Object? invoiceTaskDocuments = null,Object? markExpensesInvoiceable = null,Object? markExpensesPaid = null,Object? convertExpenseCurrency = null,Object? invoiceExpenseDocuments = null,Object? notifyVendorWhenPaid = null,Object? calculateExpenseTaxByAmount = null,Object? expenseInclusiveTaxes = null,Object? expenseMailboxActive = null,Object? expenseMailbox = null,Object? inboundMailboxAllowCompanyUsers = null,Object? inboundMailboxAllowVendors = null,Object? inboundMailboxAllowClients = null,Object? inboundMailboxWhitelist = null,Object? inboundMailboxBlacklist = null,Object? inboundMailboxAllowUnknown = null,Object? smtpHost = null,Object? smtpPort = null,Object? smtpEncryption = null,Object? smtpUsername = null,Object? smtpPassword = null,Object? smtpLocalDomain = null,Object? smtpVerifyPeer = null,Object? googleAnalyticsKey = null,Object? matomoId = null,Object? matomoUrl = null,Object? sessionTimeout = null,Object? defaultPasswordTimeout = null,Object? oauthPasswordRequired = null,Object? isDisabled = null,Object? markdownEnabled = null,Object? markdownEmailEnabled = null,Object? reportIncludeDrafts = null,Object? reportIncludeDeleted = null,Object? quickbooks = freezed,Object? documents = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_Company(
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
as Map<String, String>,rawSettings: null == rawSettings ? _self._rawSettings : rawSettings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as CompanySettings,enableApplyingPayments: null == enableApplyingPayments ? _self.enableApplyingPayments : enableApplyingPayments // ignore: cast_nullable_to_non_nullable
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
as List<Document>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanySettingsApiCopyWith<$Res> get settings {
  
  return $CompanySettingsApiCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}/// Create a copy of Company
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

// dart format on

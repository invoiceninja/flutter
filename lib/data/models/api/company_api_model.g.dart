// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CompanyApi _$CompanyApiFromJson(Map<String, dynamic> json) => _CompanyApi(
  id: json['id'] as String? ?? '',
  displayName: json['display_name'] as String? ?? '',
  name: json['name'] as String? ?? '',
  companyKey: json['company_key'] as String? ?? '',
  sizeId: json['size_id'] as String? ?? '',
  industryId: json['industry_id'] as String? ?? '',
  firstMonthOfYear: json['first_month_of_year'] as String? ?? '',
  firstDayOfWeek: json['first_day_of_week'] as String? ?? '',
  useCommaAsDecimalPlace: json['use_comma_as_decimal_place'] as bool? ?? false,
  enabledModules: (json['enabled_modules'] as num?)?.toInt() ?? 0,
  enableModules: json['enable_modules'] == null
      ? false
      : jsonScalarToBool(json['enable_modules']),
  legalEntityId: (json['legal_entity_id'] as num?)?.toInt() ?? 0,
  hasEInvoiceCertificate: json['has_e_invoice_certificate'] as bool? ?? false,
  eInvoiceCertificatePassphrase:
      json['e_invoice_certificate_passphrase'] as String? ?? '',
  hasEInvoiceCertificatePassphrase:
      json['has_e_invoice_certificate_passphrase'] as bool? ?? false,
  subdomain: json['subdomain'] as String? ?? '',
  portalDomain: json['portal_domain'] as String? ?? '',
  portalMode: json['portal_mode'] as String? ?? '',
  clientCanRegister: json['client_can_register'] as bool? ?? false,
  clientRegistrationFields:
      (json['client_registration_fields'] as List<dynamic>?)
          ?.map(
            (e) =>
                ClientRegistrationFieldApi.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <ClientRegistrationFieldApi>[],
  customFields:
      (json['custom_fields'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  settings:
      json['settings'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  enableApplyingPayments: json['enable_applying_payments'] as bool? ?? false,
  convertPaymentCurrency: json['convert_payment_currency'] as bool? ?? false,
  enabledTaxRates: (json['enabled_tax_rates'] as num?)?.toInt() ?? 0,
  enabledItemTaxRates: (json['enabled_item_tax_rates'] as num?)?.toInt() ?? 0,
  enabledExpenseTaxRates:
      (json['enabled_expense_tax_rates'] as num?)?.toInt() ?? 0,
  calculateTaxes: json['calculate_taxes'] as bool? ?? false,
  taxData: json['tax_data'] == null
      ? null
      : TaxConfigApi.fromJson(json['tax_data'] as Map<String, dynamic>),
  eInvoice: json['e_invoice'] as Map<String, dynamic>?,
  customSurchargeTaxes1: json['custom_surcharge_taxes1'] as bool? ?? false,
  customSurchargeTaxes2: json['custom_surcharge_taxes2'] as bool? ?? false,
  customSurchargeTaxes3: json['custom_surcharge_taxes3'] as bool? ?? false,
  customSurchargeTaxes4: json['custom_surcharge_taxes4'] as bool? ?? false,
  trackInventory: json['track_inventory'] as bool? ?? false,
  stockNotification: json['stock_notification'] as bool? ?? false,
  inventoryNotificationThreshold:
      (json['inventory_notification_threshold'] as num?)?.toInt() ?? 0,
  enableProductDiscount: json['enable_product_discount'] as bool? ?? false,
  enableProductCost: json['enable_product_cost'] as bool? ?? false,
  enableProductQuantity: json['enable_product_quantity'] as bool? ?? false,
  defaultQuantity: json['default_quantity'] as bool? ?? false,
  showProductDetails: json['show_product_details'] as bool? ?? false,
  fillProducts: json['fill_products'] as bool? ?? false,
  updateProducts: json['update_products'] as bool? ?? false,
  convertProducts: json['convert_products'] as bool? ?? false,
  convertRateToClient: json['convert_rate_to_client'] as bool? ?? false,
  stopOnUnpaidRecurring: json['stop_on_unpaid_recurring'] as bool? ?? false,
  useQuoteTermsOnConversion:
      json['use_quote_terms_on_conversion'] as bool? ?? false,
  autoStartTasks: json['auto_start_tasks'] as bool? ?? false,
  showTaskEndDate: json['show_task_end_date'] as bool? ?? false,
  showTasksTable: json['show_tasks_table'] as bool? ?? false,
  invoiceTaskDatelog: json['invoice_task_datelog'] as bool? ?? false,
  invoiceTaskTimelog: json['invoice_task_timelog'] as bool? ?? false,
  invoiceTaskHours: json['invoice_task_hours'] as bool? ?? false,
  invoiceTaskItemDescription:
      json['invoice_task_item_description'] as bool? ?? false,
  invoiceTaskProject: json['invoice_task_project'] as bool? ?? false,
  invoiceTaskProjectHeader:
      json['invoice_task_project_header'] as bool? ?? false,
  invoiceTaskLock: json['invoice_task_lock'] as bool? ?? false,
  invoiceTaskDocuments: json['invoice_task_documents'] as bool? ?? false,
  markExpensesInvoiceable: json['mark_expenses_invoiceable'] as bool? ?? false,
  markExpensesPaid: json['mark_expenses_paid'] as bool? ?? false,
  convertExpenseCurrency: json['convert_expense_currency'] as bool? ?? false,
  invoiceExpenseDocuments: json['invoice_expense_documents'] as bool? ?? false,
  notifyVendorWhenPaid: json['notify_vendor_when_paid'] as bool? ?? false,
  calculateExpenseTaxByAmount:
      json['calculate_expense_tax_by_amount'] as bool? ?? false,
  expenseInclusiveTaxes: json['expense_inclusive_taxes'] as bool? ?? false,
  expenseMailboxActive: json['expense_mailbox_active'] as bool? ?? false,
  expenseMailbox: json['expense_mailbox'] as String? ?? '',
  inboundMailboxAllowCompanyUsers:
      json['inbound_mailbox_allow_company_users'] as bool? ?? false,
  inboundMailboxAllowVendors:
      json['inbound_mailbox_allow_vendors'] as bool? ?? false,
  inboundMailboxAllowClients:
      json['inbound_mailbox_allow_clients'] as bool? ?? false,
  inboundMailboxWhitelist: json['inbound_mailbox_whitelist'] as String? ?? '',
  inboundMailboxBlacklist: json['inbound_mailbox_blacklist'] as String? ?? '',
  inboundMailboxAllowUnknown:
      json['inbound_mailbox_allow_unknown'] as bool? ?? false,
  smtpHost: json['smtp_host'] as String? ?? '',
  smtpPort: (json['smtp_port'] as num?)?.toInt() ?? 0,
  smtpEncryption: json['smtp_encryption'] as String? ?? 'TLS',
  smtpUsername: json['smtp_username'] as String? ?? '',
  smtpPassword: json['smtp_password'] as String? ?? '',
  smtpLocalDomain: json['smtp_local_domain'] as String? ?? '',
  smtpVerifyPeer: json['smtp_verify_peer'] as bool? ?? true,
  googleAnalyticsKey: json['google_analytics_key'] as String? ?? '',
  matomoId: json['matomo_id'] as String? ?? '',
  matomoUrl: json['matomo_url'] as String? ?? '',
  sessionTimeout: (json['session_timeout'] as num?)?.toInt() ?? 0,
  defaultPasswordTimeout:
      (json['default_password_timeout'] as num?)?.toInt() ?? 0,
  oauthPasswordRequired: json['oauth_password_required'] as bool? ?? false,
  isDisabled: json['is_disabled'] as bool? ?? false,
  markdownEnabled: json['markdown_enabled'] as bool? ?? false,
  markdownEmailEnabled: json['markdown_email_enabled'] as bool? ?? false,
  reportIncludeDrafts: json['report_include_drafts'] as bool? ?? false,
  reportIncludeDeleted: json['report_include_deleted'] as bool? ?? false,
  quickbooks: json['quickbooks'] as Map<String, dynamic>?,
  documents:
      (json['documents'] as List<dynamic>?)
          ?.map((e) => DocumentApi.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <DocumentApi>[],
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CompanyApiToJson(
  _CompanyApi instance,
) => <String, dynamic>{
  'id': instance.id,
  'display_name': instance.displayName,
  'name': instance.name,
  'company_key': instance.companyKey,
  'size_id': instance.sizeId,
  'industry_id': instance.industryId,
  'first_month_of_year': instance.firstMonthOfYear,
  'first_day_of_week': instance.firstDayOfWeek,
  'use_comma_as_decimal_place': instance.useCommaAsDecimalPlace,
  'enabled_modules': instance.enabledModules,
  'legal_entity_id': instance.legalEntityId,
  'has_e_invoice_certificate': instance.hasEInvoiceCertificate,
  'e_invoice_certificate_passphrase': instance.eInvoiceCertificatePassphrase,
  'has_e_invoice_certificate_passphrase':
      instance.hasEInvoiceCertificatePassphrase,
  'subdomain': instance.subdomain,
  'portal_domain': instance.portalDomain,
  'portal_mode': instance.portalMode,
  'client_can_register': instance.clientCanRegister,
  'client_registration_fields': instance.clientRegistrationFields,
  'custom_fields': instance.customFields,
  'settings': instance.settings,
  'enable_applying_payments': instance.enableApplyingPayments,
  'convert_payment_currency': instance.convertPaymentCurrency,
  'enabled_tax_rates': instance.enabledTaxRates,
  'enabled_item_tax_rates': instance.enabledItemTaxRates,
  'enabled_expense_tax_rates': instance.enabledExpenseTaxRates,
  'calculate_taxes': instance.calculateTaxes,
  'tax_data': ?instance.taxData,
  'e_invoice': ?instance.eInvoice,
  'custom_surcharge_taxes1': instance.customSurchargeTaxes1,
  'custom_surcharge_taxes2': instance.customSurchargeTaxes2,
  'custom_surcharge_taxes3': instance.customSurchargeTaxes3,
  'custom_surcharge_taxes4': instance.customSurchargeTaxes4,
  'track_inventory': instance.trackInventory,
  'stock_notification': instance.stockNotification,
  'inventory_notification_threshold': instance.inventoryNotificationThreshold,
  'enable_product_discount': instance.enableProductDiscount,
  'enable_product_cost': instance.enableProductCost,
  'enable_product_quantity': instance.enableProductQuantity,
  'default_quantity': instance.defaultQuantity,
  'show_product_details': instance.showProductDetails,
  'fill_products': instance.fillProducts,
  'update_products': instance.updateProducts,
  'convert_products': instance.convertProducts,
  'convert_rate_to_client': instance.convertRateToClient,
  'stop_on_unpaid_recurring': instance.stopOnUnpaidRecurring,
  'use_quote_terms_on_conversion': instance.useQuoteTermsOnConversion,
  'auto_start_tasks': instance.autoStartTasks,
  'show_task_end_date': instance.showTaskEndDate,
  'show_tasks_table': instance.showTasksTable,
  'invoice_task_datelog': instance.invoiceTaskDatelog,
  'invoice_task_timelog': instance.invoiceTaskTimelog,
  'invoice_task_hours': instance.invoiceTaskHours,
  'invoice_task_item_description': instance.invoiceTaskItemDescription,
  'invoice_task_project': instance.invoiceTaskProject,
  'invoice_task_project_header': instance.invoiceTaskProjectHeader,
  'invoice_task_lock': instance.invoiceTaskLock,
  'invoice_task_documents': instance.invoiceTaskDocuments,
  'mark_expenses_invoiceable': instance.markExpensesInvoiceable,
  'mark_expenses_paid': instance.markExpensesPaid,
  'convert_expense_currency': instance.convertExpenseCurrency,
  'invoice_expense_documents': instance.invoiceExpenseDocuments,
  'notify_vendor_when_paid': instance.notifyVendorWhenPaid,
  'calculate_expense_tax_by_amount': instance.calculateExpenseTaxByAmount,
  'expense_inclusive_taxes': instance.expenseInclusiveTaxes,
  'expense_mailbox_active': instance.expenseMailboxActive,
  'expense_mailbox': instance.expenseMailbox,
  'inbound_mailbox_allow_company_users':
      instance.inboundMailboxAllowCompanyUsers,
  'inbound_mailbox_allow_vendors': instance.inboundMailboxAllowVendors,
  'inbound_mailbox_allow_clients': instance.inboundMailboxAllowClients,
  'inbound_mailbox_whitelist': instance.inboundMailboxWhitelist,
  'inbound_mailbox_blacklist': instance.inboundMailboxBlacklist,
  'inbound_mailbox_allow_unknown': instance.inboundMailboxAllowUnknown,
  'smtp_host': instance.smtpHost,
  'smtp_port': instance.smtpPort,
  'smtp_encryption': instance.smtpEncryption,
  'smtp_username': instance.smtpUsername,
  'smtp_password': instance.smtpPassword,
  'smtp_local_domain': instance.smtpLocalDomain,
  'smtp_verify_peer': instance.smtpVerifyPeer,
  'google_analytics_key': instance.googleAnalyticsKey,
  'matomo_id': instance.matomoId,
  'matomo_url': instance.matomoUrl,
  'session_timeout': instance.sessionTimeout,
  'default_password_timeout': instance.defaultPasswordTimeout,
  'oauth_password_required': instance.oauthPasswordRequired,
  'is_disabled': instance.isDisabled,
  'markdown_enabled': instance.markdownEnabled,
  'markdown_email_enabled': instance.markdownEmailEnabled,
  'report_include_drafts': instance.reportIncludeDrafts,
  'report_include_deleted': instance.reportIncludeDeleted,
  'quickbooks': ?instance.quickbooks,
  'documents': instance.documents,
  'updated_at': instance.updatedAt,
  'archived_at': instance.archivedAt,
};

_CompanyItemApi _$CompanyItemApiFromJson(Map<String, dynamic> json) =>
    _CompanyItemApi(
      data: CompanyApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CompanyItemApiToJson(_CompanyItemApi instance) =>
    <String, dynamic>{'data': instance.data};

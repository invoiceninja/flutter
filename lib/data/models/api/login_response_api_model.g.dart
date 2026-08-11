// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_response_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LoginResponseApi _$LoginResponseApiFromJson(Map<String, dynamic> json) =>
    _LoginResponseApi(
      data: json['data'] == null
          ? const <UserCompanyApi>[]
          : _userCompanyListData(json['data']),
      staticData:
          json['static'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

Map<String, dynamic> _$LoginResponseApiToJson(_LoginResponseApi instance) =>
    <String, dynamic>{'data': instance.data, 'static': instance.staticData};

_UserCompanyApi _$UserCompanyApiFromJson(
  Map<String, dynamic> json,
) => _UserCompanyApi(
  isAdmin: json['is_admin'] as bool? ?? false,
  isOwner: json['is_owner'] as bool? ?? false,
  permissions: json['permissions'] as String? ?? '',
  permissionsUpdatedAt: (json['permissions_updated_at'] as num?)?.toInt() ?? 0,
  company: CompanyEnvelopeApi.fromJson(json['company'] as Map<String, dynamic>),
  token: json['token'] == null
      ? const SessionTokenApi()
      : SessionTokenApi.fromJson(json['token'] as Map<String, dynamic>),
  account: AccountEnvelopeApi.fromJson(json['account'] as Map<String, dynamic>),
  settings:
      json['settings'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  user: json['user'] == null
      ? const UserSummaryApi()
      : UserSummaryApi.fromJson(json['user'] as Map<String, dynamic>),
  ninjaPortalUrl: json['ninja_portal_url'] as String? ?? '',
);

Map<String, dynamic> _$UserCompanyApiToJson(_UserCompanyApi instance) =>
    <String, dynamic>{
      'is_admin': instance.isAdmin,
      'is_owner': instance.isOwner,
      'permissions': instance.permissions,
      'permissions_updated_at': instance.permissionsUpdatedAt,
      'company': instance.company,
      'token': instance.token,
      'account': instance.account,
      'settings': instance.settings,
      'user': instance.user,
      'ninja_portal_url': instance.ninjaPortalUrl,
    };

_UserSummaryApi _$UserSummaryApiFromJson(Map<String, dynamic> json) =>
    _UserSummaryApi(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      languageId: json['language_id'] as String? ?? '',
      customValue1: json['custom_value1'] as String? ?? '',
      customValue2: json['custom_value2'] as String? ?? '',
      customValue3: json['custom_value3'] as String? ?? '',
      customValue4: json['custom_value4'] as String? ?? '',
      oauthProviderId: json['oauth_provider_id'] as String? ?? '',
      google2faSecret: json['google_2fa_secret'] == null
          ? false
          : _boolFromJson(json['google_2fa_secret']),
      verifiedPhoneNumber: json['verified_phone_number'] == null
          ? false
          : _boolFromJson(json['verified_phone_number']),
      referralCode: json['referral_code'] as String? ?? '',
      referralMeta: json['referral_meta'] == null
          ? const <String, int>{}
          : _referralMetaFromJson(json['referral_meta']),
    );

Map<String, dynamic> _$UserSummaryApiToJson(_UserSummaryApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'email': instance.email,
      'phone': instance.phone,
      'signature': instance.signature,
      'language_id': instance.languageId,
      'custom_value1': instance.customValue1,
      'custom_value2': instance.customValue2,
      'custom_value3': instance.customValue3,
      'custom_value4': instance.customValue4,
      'oauth_provider_id': instance.oauthProviderId,
      'google_2fa_secret': instance.google2faSecret,
      'verified_phone_number': instance.verifiedPhoneNumber,
      'referral_code': instance.referralCode,
      'referral_meta': instance.referralMeta,
    };

_CompanyEnvelopeApi _$CompanyEnvelopeApiFromJson(
  Map<String, dynamic> json,
) => _CompanyEnvelopeApi(
  id: json['id'] as String? ?? '',
  displayName: json['display_name'] as String? ?? '',
  name: json['name'] as String? ?? '',
  companyKey: json['company_key'] as String? ?? '',
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  subdomain: json['subdomain'] as String? ?? '',
  portalDomain: json['portal_domain'] as String? ?? '',
  portalMode: json['portal_mode'] as String? ?? '',
  clientCanRegister: json['client_can_register'] as bool? ?? false,
  clientRegistrationFields: json['client_registration_fields'] == null
      ? const <ClientRegistrationFieldApi>[]
      : _clientRegistrationFieldListData(json['client_registration_fields']),
  customFields:
      (json['custom_fields'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  documents: json['documents'] == null
      ? const <DocumentApi>[]
      : _companyDocumentListData(json['documents']),
  sizeId: json['size_id'] as String? ?? '',
  industryId: json['industry_id'] as String? ?? '',
  firstMonthOfYear: json['first_month_of_year'] as String? ?? '',
  firstDayOfWeek: json['first_day_of_week'] as String? ?? '',
  useCommaAsDecimalPlace: json['use_comma_as_decimal_place'] as bool? ?? false,
  legalEntityId: (json['legal_entity_id'] as num?)?.toInt() ?? 0,
  enabledModules: (json['enabled_modules'] as num?)?.toInt() ?? 0,
  settings:
      json['settings'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  users: json['users'] == null
      ? const <UserApi>[]
      : _bundledUserListData(json['users']),
  taskStatuses: json['task_statuses'] == null
      ? const <TaskStatusApi>[]
      : _taskStatusListData(json['task_statuses']),
  companyGateways: json['company_gateways'] == null
      ? const <CompanyGatewayApi>[]
      : _companyGatewayListData(json['company_gateways']),
  paymentTerms: json['payment_terms'] == null
      ? const <PaymentTermApi>[]
      : _paymentTermListData(json['payment_terms']),
  taxRates: json['tax_rates'] == null
      ? const <TaxRateApi>[]
      : _taxRateListData(json['tax_rates']),
  expenseCategories: json['expense_categories'] == null
      ? const <ExpenseCategoryApi>[]
      : _expenseCategoryListData(json['expense_categories']),
  groups: json['groups'] == null
      ? const <GroupSettingApi>[]
      : _groupSettingListData(json['groups']),
  bankTransactionRules: json['bank_transaction_rules'] == null
      ? const <TransactionRuleApi>[]
      : _transactionRuleListData(json['bank_transaction_rules']),
  bankIntegrations: json['bank_integrations'] == null
      ? const <BankAccountApi>[]
      : _bankIntegrationListData(json['bank_integrations']),
  webhooks: json['webhooks'] == null
      ? const <WebhookApi>[]
      : _webhookListData(json['webhooks']),
  tokensHashed: json['tokens_hashed'] == null
      ? const <TokenApi>[]
      : _tokenListData(json['tokens_hashed']),
  taskSchedulers: json['task_schedulers'] == null
      ? const <ScheduleApi>[]
      : _taskSchedulerListData(json['task_schedulers']),
  subscriptions: json['subscriptions'] == null
      ? const <SubscriptionApi>[]
      : _subscriptionListData(json['subscriptions']),
  designs: json['designs'] == null
      ? const <DesignApi>[]
      : _designListData(json['designs']),
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
);

Map<String, dynamic> _$CompanyEnvelopeApiToJson(
  _CompanyEnvelopeApi instance,
) => <String, dynamic>{
  'id': instance.id,
  'display_name': instance.displayName,
  'name': instance.name,
  'company_key': instance.companyKey,
  'updated_at': instance.updatedAt,
  'subdomain': instance.subdomain,
  'portal_domain': instance.portalDomain,
  'portal_mode': instance.portalMode,
  'client_can_register': instance.clientCanRegister,
  'client_registration_fields': instance.clientRegistrationFields,
  'custom_fields': instance.customFields,
  'documents': instance.documents,
  'size_id': instance.sizeId,
  'industry_id': instance.industryId,
  'first_month_of_year': instance.firstMonthOfYear,
  'first_day_of_week': instance.firstDayOfWeek,
  'use_comma_as_decimal_place': instance.useCommaAsDecimalPlace,
  'legal_entity_id': instance.legalEntityId,
  'enabled_modules': instance.enabledModules,
  'settings': instance.settings,
  'users': instance.users,
  'task_statuses': instance.taskStatuses,
  'company_gateways': instance.companyGateways,
  'payment_terms': instance.paymentTerms,
  'tax_rates': instance.taxRates,
  'expense_categories': instance.expenseCategories,
  'groups': instance.groups,
  'bank_transaction_rules': instance.bankTransactionRules,
  'bank_integrations': instance.bankIntegrations,
  'webhooks': instance.webhooks,
  'tokens_hashed': instance.tokensHashed,
  'task_schedulers': instance.taskSchedulers,
  'subscriptions': instance.subscriptions,
  'designs': instance.designs,
  'enabled_tax_rates': instance.enabledTaxRates,
  'enabled_item_tax_rates': instance.enabledItemTaxRates,
  'enabled_expense_tax_rates': instance.enabledExpenseTaxRates,
  'calculate_taxes': instance.calculateTaxes,
  'tax_data': instance.taxData,
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
  'quickbooks': instance.quickbooks,
};

_SessionTokenApi _$SessionTokenApiFromJson(Map<String, dynamic> json) =>
    _SessionTokenApi(
      token: json['token'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );

Map<String, dynamic> _$SessionTokenApiToJson(_SessionTokenApi instance) =>
    <String, dynamic>{'token': instance.token, 'name': instance.name};

_AccountEnvelopeApi _$AccountEnvelopeApiFromJson(Map<String, dynamic> json) =>
    _AccountEnvelopeApi(
      id: json['id'] as String? ?? '',
      defaultCompanyId: json['default_company_id'] as String? ?? '',
      plan: json['plan'] as String? ?? '',
      planExpires: json['plan_expires'] as String? ?? '',
      trialStarted: json['trial_started'] as String? ?? '',
      trialPlan: json['trial_plan'] as String? ?? '',
      numTrialDays: (json['num_trial_days'] as num?)?.toInt() ?? 0,
      trialDaysLeft: (json['trial_days_left'] as num?)?.toInt() ?? -1,
      hasIapPlan: json['has_iap_plan'] as bool? ?? false,
      hostedClientCount: (json['hosted_client_count'] as num?)?.toInt() ?? 0,
      hostedCompanyCount: (json['hosted_company_count'] as num?)?.toInt() ?? 0,
      eInvoicingToken: json['e_invoicing_token'] as String? ?? '',
      reportErrors: json['report_errors'] as bool? ?? false,
    );

Map<String, dynamic> _$AccountEnvelopeApiToJson(_AccountEnvelopeApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'default_company_id': instance.defaultCompanyId,
      'plan': instance.plan,
      'plan_expires': instance.planExpires,
      'trial_started': instance.trialStarted,
      'trial_plan': instance.trialPlan,
      'num_trial_days': instance.numTrialDays,
      'trial_days_left': instance.trialDaysLeft,
      'has_iap_plan': instance.hasIapPlan,
      'hosted_client_count': instance.hostedClientCount,
      'hosted_company_count': instance.hostedCompanyCount,
      'e_invoicing_token': instance.eInvoicingToken,
      'report_errors': instance.reportErrors,
    };

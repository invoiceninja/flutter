import 'package:freezed_annotation/freezed_annotation.dart';

part 'company_settings_api_model.freezed.dart';
part 'company_settings_api_model.g.dart';

/// Wire shape of `company.settings` (and `group.settings`, `client.settings` —
/// the same blob nests inside each entity in the cascade).
///
/// **Every field is nullable.** A null value means "inherit from the parent in
/// the cascade (group → company)." The Company Details page treats nulls as
/// empty when editing at company level; at group/client level it renders an
/// override checkbox per field, leaving null fields disabled and showing the
/// inherited value as a placeholder.
///
/// Field names mirror the server keys verbatim via `@JsonKey`. Mirrors the
/// React TS `Settings` interface
/// (`react/src/common/interfaces/company.interface.ts:98-354`) and admin-portal
/// `SettingsEntity` (`admin-portal/lib/data/models/settings_model.dart:164-906`).
@freezed
abstract class CompanySettingsApi with _$CompanySettingsApi {
  @JsonSerializable(includeIfNull: false)
  const factory CompanySettingsApi({
    // ── Identity / brand ────────────────────────────────────────────────
    String? id,
    String? name,
    @JsonKey(name: 'company_logo') String? companyLogo,
    @JsonKey(name: 'company_logo_size') String? companyLogoSize,
    String? website,
    String? phone,
    String? email,
    String? address1,
    String? address2,
    String? city,
    String? state,
    @JsonKey(name: 'postal_code') String? postalCode,
    @JsonKey(name: 'country_id') String? countryId,
    @JsonKey(name: 'vat_number') String? vatNumber,
    @JsonKey(name: 'id_number') String? idNumber,
    String? classification,
    @JsonKey(name: 'qr_iban') String? qrIban,
    @JsonKey(name: 'besr_id') String? besrId,
    @JsonKey(name: 'custom_value1') String? customValue1,
    @JsonKey(name: 'custom_value2') String? customValue2,
    @JsonKey(name: 'custom_value3') String? customValue3,
    @JsonKey(name: 'custom_value4') String? customValue4,

    // ── Localization ────────────────────────────────────────────────────
    @JsonKey(name: 'timezone_id') String? timezoneId,
    @JsonKey(name: 'date_format_id') String? dateFormatId,
    @JsonKey(name: 'language_id') String? languageId,
    @JsonKey(name: 'currency_id') String? currencyId,
    @JsonKey(name: 'military_time') bool? militaryTime,
    @JsonKey(name: 'show_currency_code') bool? showCurrencyCode,
    // NOTE: first_month_of_year, first_day_of_week and use_comma_as_decimal_place
    // are intentionally NOT here — they're top-level company fields (see
    // CompanyApi), not cascade settings. The server returns them on `company`,
    // never on `company.settings`, and the money formatter reads
    // use_comma_as_decimal_place via Services._buildFormatter's row overlay.

    // ── Defaults: terms & footers ───────────────────────────────────────
    @JsonKey(name: 'invoice_terms') String? invoiceTerms,
    @JsonKey(name: 'invoice_footer') String? invoiceFooter,
    @JsonKey(name: 'quote_terms') String? quoteTerms,
    @JsonKey(name: 'quote_footer') String? quoteFooter,
    @JsonKey(name: 'credit_terms') String? creditTerms,
    @JsonKey(name: 'credit_footer') String? creditFooter,
    @JsonKey(name: 'purchase_order_terms') String? purchaseOrderTerms,
    @JsonKey(name: 'purchase_order_footer') String? purchaseOrderFooter,
    @JsonKey(name: 'purchase_order_public_notes')
    String? purchaseOrderPublicNotes,
    @JsonKey(name: 'invoice_labels') String? invoiceLabels,

    // ── Design ids ──────────────────────────────────────────────────────
    @JsonKey(name: 'invoice_design_id') String? invoiceDesignId,
    @JsonKey(name: 'quote_design_id') String? quoteDesignId,
    @JsonKey(name: 'credit_design_id') String? creditDesignId,
    @JsonKey(name: 'purchase_order_design_id') String? purchaseOrderDesignId,
    @JsonKey(name: 'statement_design_id') String? statementDesignId,
    @JsonKey(name: 'delivery_note_design_id') String? deliveryNoteDesignId,
    @JsonKey(name: 'payment_receipt_design_id') String? paymentReceiptDesignId,
    @JsonKey(name: 'payment_refund_design_id') String? paymentRefundDesignId,
    @JsonKey(name: 'portal_design_id') String? portalDesignId,

    // ── Numbering & counters ────────────────────────────────────────────
    @JsonKey(name: 'invoice_number_pattern') String? invoiceNumberPattern,
    @JsonKey(name: 'invoice_number_counter') int? invoiceNumberCounter,
    @JsonKey(name: 'recurring_invoice_number_pattern')
    String? recurringInvoiceNumberPattern,
    @JsonKey(name: 'recurring_invoice_number_counter')
    int? recurringInvoiceNumberCounter,
    @JsonKey(name: 'quote_number_pattern') String? quoteNumberPattern,
    @JsonKey(name: 'quote_number_counter') int? quoteNumberCounter,
    @JsonKey(name: 'recurring_quote_number_pattern')
    String? recurringQuoteNumberPattern,
    @JsonKey(name: 'recurring_quote_number_counter')
    int? recurringQuoteNumberCounter,
    @JsonKey(name: 'client_number_pattern') String? clientNumberPattern,
    @JsonKey(name: 'client_number_counter') int? clientNumberCounter,
    @JsonKey(name: 'credit_number_pattern') String? creditNumberPattern,
    @JsonKey(name: 'credit_number_counter') int? creditNumberCounter,
    @JsonKey(name: 'task_number_pattern') String? taskNumberPattern,
    @JsonKey(name: 'task_number_counter') int? taskNumberCounter,
    @JsonKey(name: 'expense_number_pattern') String? expenseNumberPattern,
    @JsonKey(name: 'expense_number_counter') int? expenseNumberCounter,
    @JsonKey(name: 'recurring_expense_number_pattern')
    String? recurringExpenseNumberPattern,
    @JsonKey(name: 'recurring_expense_number_counter')
    int? recurringExpenseNumberCounter,
    @JsonKey(name: 'vendor_number_pattern') String? vendorNumberPattern,
    @JsonKey(name: 'vendor_number_counter') int? vendorNumberCounter,
    @JsonKey(name: 'ticket_number_pattern') String? ticketNumberPattern,
    @JsonKey(name: 'ticket_number_counter') int? ticketNumberCounter,
    @JsonKey(name: 'payment_number_pattern') String? paymentNumberPattern,
    @JsonKey(name: 'payment_number_counter') int? paymentNumberCounter,
    @JsonKey(name: 'project_number_pattern') String? projectNumberPattern,
    @JsonKey(name: 'project_number_counter') int? projectNumberCounter,
    @JsonKey(name: 'purchase_order_number_pattern')
    String? purchaseOrderNumberPattern,
    @JsonKey(name: 'purchase_order_number_counter')
    int? purchaseOrderNumberCounter,
    @JsonKey(name: 'shared_invoice_quote_counter')
    bool? sharedInvoiceQuoteCounter,
    @JsonKey(name: 'shared_invoice_credit_counter')
    bool? sharedInvoiceCreditCounter,
    @JsonKey(name: 'recurring_number_prefix') String? recurringNumberPrefix,
    @JsonKey(name: 'reset_counter_frequency_id') int? resetCounterFrequencyId,
    @JsonKey(name: 'reset_counter_date') String? resetCounterDate,
    @JsonKey(name: 'counter_padding') int? counterPadding,
    @JsonKey(name: 'counter_number_applied') String? counterNumberApplied,
    @JsonKey(name: 'quote_number_applied') String? quoteNumberApplied,

    // ── Taxes ───────────────────────────────────────────────────────────
    @JsonKey(name: 'tax_name1') String? taxName1,
    @JsonKey(name: 'tax_rate1') double? taxRate1,
    @JsonKey(name: 'tax_name2') String? taxName2,
    @JsonKey(name: 'tax_rate2') double? taxRate2,
    @JsonKey(name: 'tax_name3') String? taxName3,
    @JsonKey(name: 'tax_rate3') double? taxRate3,
    @JsonKey(name: 'inclusive_taxes') bool? inclusiveTaxes,
    @JsonKey(name: 'enable_rappen_rounding') bool? enableRappenRounding,
    @JsonKey(name: 'track_inventory') bool? trackInventory,

    // ── Email config ────────────────────────────────────────────────────
    @JsonKey(name: 'email_sending_method') String? emailSendingMethod,
    @JsonKey(name: 'gmail_sending_user_id') String? gmailSendingUserId,
    @JsonKey(name: 'reply_to_email') String? replyToEmail,
    @JsonKey(name: 'reply_to_name') String? replyToName,
    @JsonKey(name: 'bcc_email') String? bccEmail,
    @JsonKey(name: 'email_from_name') String? emailFromName,
    @JsonKey(name: 'custom_sending_email') String? customSendingEmail,
    @JsonKey(name: 'email_style') String? emailStyle,
    @JsonKey(name: 'email_alignment') String? emailAlignment,
    @JsonKey(name: 'email_style_custom') String? emailStyleCustom,
    @JsonKey(name: 'email_signature') String? emailSignature,
    @JsonKey(name: 'enable_email_markup') bool? enableEmailMarkup,
    @JsonKey(name: 'show_email_footer') bool? showEmailFooter,
    @JsonKey(name: 'pdf_email_attachment') bool? pdfEmailAttachment,
    @JsonKey(name: 'ubl_email_attachment') bool? ublEmailAttachment,
    @JsonKey(name: 'document_email_attachment') bool? documentEmailAttachment,
    @JsonKey(name: 'send_email_on_mark_paid') bool? sendEmailOnMarkPaid,
    @JsonKey(name: 'payment_email_all_contacts') bool? paymentEmailAllContacts,

    // Mail service secrets
    @JsonKey(name: 'postmark_secret') String? postmarkSecret,
    @JsonKey(name: 'mailgun_secret') String? mailgunSecret,
    @JsonKey(name: 'mailgun_domain') String? mailgunDomain,
    @JsonKey(name: 'mailgun_endpoint') String? mailgunEndpoint,
    @JsonKey(name: 'brevo_secret') String? brevoSecret,
    @JsonKey(name: 'ses_secret_key') String? sesSecretKey,
    @JsonKey(name: 'ses_access_key') String? sesAccessKey,
    @JsonKey(name: 'ses_region') String? sesRegion,
    @JsonKey(name: 'ses_topic_arn') String? sesTopicArn,
    @JsonKey(name: 'ses_from_address') String? sesFromAddress,

    // Email subjects (per entity)
    @JsonKey(name: 'email_subject_invoice') String? emailSubjectInvoice,
    @JsonKey(name: 'email_subject_quote') String? emailSubjectQuote,
    @JsonKey(name: 'email_subject_credit') String? emailSubjectCredit,
    @JsonKey(name: 'email_subject_payment') String? emailSubjectPayment,
    @JsonKey(name: 'email_subject_payment_partial')
    String? emailSubjectPaymentPartial,
    @JsonKey(name: 'email_subject_payment_failed')
    String? emailSubjectPaymentFailed,
    @JsonKey(name: 'email_subject_statement') String? emailSubjectStatement,
    @JsonKey(name: 'email_subject_purchase_order')
    String? emailSubjectPurchaseOrder,
    @JsonKey(name: 'email_subject_reminder1') String? emailSubjectReminder1,
    @JsonKey(name: 'email_subject_reminder2') String? emailSubjectReminder2,
    @JsonKey(name: 'email_subject_reminder3') String? emailSubjectReminder3,
    @JsonKey(name: 'email_subject_reminder_endless')
    String? emailSubjectReminderEndless,
    @JsonKey(name: 'email_subject_custom1') String? emailSubjectCustom1,
    @JsonKey(name: 'email_subject_custom2') String? emailSubjectCustom2,
    @JsonKey(name: 'email_subject_custom3') String? emailSubjectCustom3,

    // Email templates (per entity)
    @JsonKey(name: 'email_template_invoice') String? emailTemplateInvoice,
    @JsonKey(name: 'email_template_quote') String? emailTemplateQuote,
    @JsonKey(name: 'email_template_credit') String? emailTemplateCredit,
    @JsonKey(name: 'email_template_payment') String? emailTemplatePayment,
    @JsonKey(name: 'email_template_payment_partial')
    String? emailTemplatePaymentPartial,
    @JsonKey(name: 'email_template_payment_failed')
    String? emailTemplatePaymentFailed,
    @JsonKey(name: 'email_template_statement') String? emailTemplateStatement,
    @JsonKey(name: 'email_template_purchase_order')
    String? emailTemplatePurchaseOrder,
    @JsonKey(name: 'email_template_reminder1') String? emailTemplateReminder1,
    @JsonKey(name: 'email_template_reminder2') String? emailTemplateReminder2,
    @JsonKey(name: 'email_template_reminder3') String? emailTemplateReminder3,
    @JsonKey(name: 'email_template_reminder_endless')
    String? emailTemplateReminderEndless,
    @JsonKey(name: 'email_template_custom1') String? emailTemplateCustom1,
    @JsonKey(name: 'email_template_custom2') String? emailTemplateCustom2,
    @JsonKey(name: 'email_template_custom3') String? emailTemplateCustom3,

    // ── Reminders ───────────────────────────────────────────────────────
    @JsonKey(name: 'send_reminders') bool? sendReminders,
    @JsonKey(name: 'enable_reminder1') bool? enableReminder1,
    @JsonKey(name: 'enable_reminder2') bool? enableReminder2,
    @JsonKey(name: 'enable_reminder3') bool? enableReminder3,
    @JsonKey(name: 'enable_reminder_endless') bool? enableReminderEndless,
    @JsonKey(name: 'num_days_reminder1') int? numDaysReminder1,
    @JsonKey(name: 'num_days_reminder2') int? numDaysReminder2,
    @JsonKey(name: 'num_days_reminder3') int? numDaysReminder3,
    @JsonKey(name: 'schedule_reminder1') String? scheduleReminder1,
    @JsonKey(name: 'schedule_reminder2') String? scheduleReminder2,
    @JsonKey(name: 'schedule_reminder3') String? scheduleReminder3,
    @JsonKey(name: 'reminder_send_time') int? reminderSendTime,
    @JsonKey(name: 'late_fee_amount1') double? lateFeeAmount1,
    @JsonKey(name: 'late_fee_amount2') double? lateFeeAmount2,
    @JsonKey(name: 'late_fee_amount3') double? lateFeeAmount3,
    @JsonKey(name: 'late_fee_percent1') double? lateFeePercent1,
    @JsonKey(name: 'late_fee_percent2') double? lateFeePercent2,
    @JsonKey(name: 'late_fee_percent3') double? lateFeePercent3,
    @JsonKey(name: 'endless_reminder_frequency_id')
    String? endlessReminderFrequencyId,
    @JsonKey(name: 'late_fee_endless_amount') double? lateFeeEndlessAmount,
    @JsonKey(name: 'late_fee_endless_percent') double? lateFeeEndlessPercent,

    // Quote Reminder 1 — wire names from admin-portal settings_model.dart:
    // the `quote_` infix sits before `subject`/`template`, not after.
    @JsonKey(name: 'enable_quote_reminder1') bool? enableQuoteReminder1,
    @JsonKey(name: 'quote_num_days_reminder1') int? quoteNumDaysReminder1,
    @JsonKey(name: 'quote_schedule_reminder1') String? quoteScheduleReminder1,
    @JsonKey(name: 'quote_late_fee_amount1') double? quoteLateFeeAmount1,
    @JsonKey(name: 'quote_late_fee_percent1') double? quoteLateFeePercent1,
    @JsonKey(name: 'email_quote_subject_reminder1')
    String? emailSubjectQuoteReminder1,
    @JsonKey(name: 'email_quote_template_reminder1')
    String? emailTemplateQuoteReminder1,

    // ── Invoice / quote behavior ───────────────────────────────────────
    @JsonKey(name: 'auto_archive_invoice') bool? autoArchiveInvoice,
    @JsonKey(name: 'auto_archive_invoice_cancelled')
    bool? autoArchiveInvoiceCancelled,
    @JsonKey(name: 'auto_archive_quote') bool? autoArchiveQuote,
    @JsonKey(name: 'auto_convert_quote') bool? autoConvertQuote,
    @JsonKey(name: 'auto_email_invoice') bool? autoEmailInvoice,
    // Server-side tag cascade on create (BaseRepository); the client only
    // persists the toggle — see Settings → Workflow Settings.
    @JsonKey(name: 'global_tag_inheritance') bool? globalTagInheritance,
    @JsonKey(name: 'auto_bill_standard_invoices')
    bool? autoBillStandardInvoices,
    @JsonKey(name: 'auto_bill') String? autoBill,
    @JsonKey(name: 'auto_bill_date') String? autoBillDate,
    @JsonKey(name: 'lock_invoices') String? lockInvoices,
    @JsonKey(name: 'entity_send_time') int? entitySendTime,
    @JsonKey(name: 'show_accept_invoice_terms') bool? showAcceptInvoiceTerms,
    @JsonKey(name: 'show_accept_quote_terms') bool? showAcceptQuoteTerms,
    @JsonKey(name: 'require_invoice_signature') bool? requireInvoiceSignature,
    @JsonKey(name: 'require_quote_signature') bool? requireQuoteSignature,
    @JsonKey(name: 'require_purchase_order_signature')
    bool? requirePurchaseOrderSignature,
    @JsonKey(name: 'signature_on_pdf') bool? signatureOnPdf,
    @JsonKey(name: 'accept_client_input_quote_approval')
    bool? acceptClientInputQuoteApproval,
    @JsonKey(name: 'sync_invoice_quote_columns') bool? syncInvoiceQuoteColumns,
    @JsonKey(name: 'show_shipping_address') bool? showShippingAddress,
    @JsonKey(name: 'show_paid_stamp') bool? showPaidStamp,

    // ── PDF / page layout ──────────────────────────────────────────────
    @JsonKey(name: 'page_size') String? pageSize,
    @JsonKey(name: 'page_layout') String? pageLayout,
    @JsonKey(name: 'font_size') int? fontSize,
    @JsonKey(name: 'primary_font') String? primaryFont,
    @JsonKey(name: 'secondary_font') String? secondaryFont,
    @JsonKey(name: 'primary_color') String? primaryColor,
    @JsonKey(name: 'secondary_color') String? secondaryColor,
    @JsonKey(name: 'page_numbering') bool? pageNumbering,
    @JsonKey(name: 'page_numbering_alignment') String? pageNumberingAlignment,
    @JsonKey(name: 'hide_paid_to_date') bool? hidePaidToDate,
    @JsonKey(name: 'hide_empty_columns_on_pdf') bool? hideEmptyColumnsOnPdf,
    @JsonKey(name: 'embed_documents') bool? embedDocuments,
    @JsonKey(name: 'all_pages_header') bool? allPagesHeader,
    @JsonKey(name: 'all_pages_footer') bool? allPagesFooter,
    @JsonKey(name: 'pdf_variables') Map<String, List<String>>? pdfVariables,
    @JsonKey(name: 'show_pdfhtml_on_mobile') bool? showPdfhtmlOnMobile,

    // ── Portal ─────────────────────────────────────────────────────────
    @JsonKey(name: 'enable_client_portal') bool? enableClientPortal,
    @JsonKey(name: 'enable_client_portal_dashboard')
    bool? enableClientPortalDashboard,
    @JsonKey(name: 'enable_client_portal_tasks') bool? enableClientPortalTasks,
    @JsonKey(name: 'show_all_tasks_client_portal')
    String? showAllTasksClientPortal,
    @JsonKey(name: 'enable_client_portal_password')
    bool? enableClientPortalPassword,
    @JsonKey(name: 'client_portal_terms') String? clientPortalTerms,
    @JsonKey(name: 'client_portal_privacy_policy')
    String? clientPortalPrivacyPolicy,
    @JsonKey(name: 'client_portal_enable_uploads')
    bool? clientPortalEnableUploads,
    @JsonKey(name: 'client_portal_allow_under_payment')
    bool? clientPortalAllowUnderPayment,
    @JsonKey(name: 'client_portal_under_payment_minimum')
    double? clientPortalUnderPaymentMinimum,
    @JsonKey(name: 'client_portal_allow_over_payment')
    bool? clientPortalAllowOverPayment,
    @JsonKey(name: 'portal_custom_head') String? portalCustomHead,
    @JsonKey(name: 'portal_custom_css') String? portalCustomCss,
    @JsonKey(name: 'portal_custom_footer') String? portalCustomFooter,
    @JsonKey(name: 'portal_custom_js') String? portalCustomJs,
    // Deprecated: `client_can_register` is now a top-level `Company` column
    // (the server gates registration on it). Kept here for wire-compat
    // deserialization only — do NOT bind it in the UI; edit the top-level
    // `Company.clientCanRegister` via `host.updateCompany(...)` instead.
    @JsonKey(name: 'client_can_register') bool? clientCanRegister,
    @JsonKey(name: 'client_initiated_payments') bool? clientInitiatedPayments,
    @JsonKey(name: 'client_initiated_payments_minimum')
    double? clientInitiatedPaymentsMinimum,
    @JsonKey(name: 'enable_client_profile_update')
    bool? enableClientProfileUpdate,
    @JsonKey(name: 'client_online_payment_notification')
    bool? clientOnlinePaymentNotification,
    @JsonKey(name: 'client_manual_payment_notification')
    bool? clientManualPaymentNotification,
    @JsonKey(name: 'vendor_portal_enable_uploads')
    bool? vendorPortalEnableUploads,
    @JsonKey(name: 'use_credits_payment') String? useCreditsPayment,
    @JsonKey(name: 'use_unapplied_payment') String? useUnappliedPayment,

    // ── Payments / billing ─────────────────────────────────────────────
    @JsonKey(name: 'payment_terms') String? paymentTerms,
    @JsonKey(name: 'valid_until') String? validUntil,
    @JsonKey(name: 'payment_type_id') String? paymentTypeId,
    @JsonKey(name: 'default_expense_payment_type_id')
    String? defaultExpensePaymentTypeId,
    @JsonKey(name: 'company_gateway_ids') String? companyGatewayIds,
    @JsonKey(name: 'payment_flow') String? paymentFlow,
    @JsonKey(name: 'unlock_invoice_documents_after_payment')
    bool? unlockInvoiceDocumentsAfterPayment,

    // ── Tasks ──────────────────────────────────────────────────────────
    @JsonKey(name: 'show_task_item_description') bool? showTaskItemDescription,
    @JsonKey(name: 'allow_billable_task_items') bool? allowBillableTaskItems,
    @JsonKey(name: 'default_task_rate') double? defaultTaskRate,
    @JsonKey(name: 'task_round_up') bool? taskRoundUp,
    @JsonKey(name: 'task_round_to_nearest') double? taskRoundToNearest,

    // ── e-Invoice ──────────────────────────────────────────────────────
    @JsonKey(name: 'enable_e_invoice') bool? enableEInvoice,
    @JsonKey(name: 'e_invoice_type') String? eInvoiceType,
    @JsonKey(name: 'e_quote_type') String? eQuoteType,
    @JsonKey(name: 'merge_e_invoice_to_pdf') bool? mergeEInvoiceToPdf,
    @JsonKey(name: 'skip_automatic_email_with_peppol')
    bool? skipAutomaticEmailWithPeppol,
    @JsonKey(name: 'e_invoice_forward_email') String? eInvoiceForwardEmail,
    @JsonKey(name: 'e_expense_forward_email') String? eExpenseForwardEmail,
    @JsonKey(name: 'france_reporting_enabled') bool? franceReportingEnabled,
    @JsonKey(name: 'france_reporting_schedule') String? franceReportingSchedule,
    @JsonKey(name: 'preference_product_notes_for_html_view')
    bool? preferenceProductNotesForHtmlView,

    // ── Dashboard / messages ───────────────────────────────────────────
    @JsonKey(name: 'custom_message_dashboard') String? customMessageDashboard,
    @JsonKey(name: 'custom_message_unpaid_invoice')
    String? customMessageUnpaidInvoice,
    @JsonKey(name: 'custom_message_paid_invoice')
    String? customMessagePaidInvoice,
    @JsonKey(name: 'custom_message_unapproved_quote')
    String? customMessageUnapprovedQuote,

    // ── Misc ───────────────────────────────────────────────────────────
    // The server ships `translations` as a Map (`{lang_key: override}` or
    // `{}` for unset accounts). admin-portal types it as
    // `BuiltMap<String?, String>?`; we keep `dynamic` values since some
    // accounts store nested objects under the lang key.
    Map<String, dynamic>? translations,
  }) = _CompanySettingsApi;

  factory CompanySettingsApi.fromJson(Map<String, dynamic> json) =>
      _$CompanySettingsApiFromJson(json);

  /// Tolerant alternative to [fromJson]. The Invoice Ninja PHP server ships
  /// several numeric fields as strings (`"1"`, `"5.50"`) and several legacy
  /// boolean fields as `0`/`1` ints — the generated strict parser uses
  /// `as num?` / `as bool?` casts and crashes on those.
  ///
  /// This factory pre-sanitizes the map via [_sanitizeSettingsJson] (coerces
  /// known-numeric/bool keys), then delegates to the strict generator.
  /// Unknown keys pass through untouched.
  factory CompanySettingsApi.fromJsonLenient(Map<String, dynamic> json) =>
      CompanySettingsApi.fromJson(_sanitizeSettingsJson(json));
}

/// Snake_case keys that map to an `int?` or `double?` field on
/// [CompanySettingsApi]. When the server ships any of these as a String, the
/// generated `_$$CompanySettingsApiImplFromJson` crashes at `as num?` —
/// [_sanitizeSettingsJson] coerces via `num.tryParse` before the cast runs.
///
/// Stay in sync with the freezed factory above when adding new numeric
/// fields. Tests in `test/data/models/company_settings_mapping_test.dart`
/// guard the canonical cases.
const Set<String> _settingsNumericKeys = {
  'invoice_number_counter',
  'recurring_invoice_number_counter',
  'quote_number_counter',
  'recurring_quote_number_counter',
  'client_number_counter',
  'credit_number_counter',
  'task_number_counter',
  'expense_number_counter',
  'recurring_expense_number_counter',
  'vendor_number_counter',
  'ticket_number_counter',
  'payment_number_counter',
  'project_number_counter',
  'purchase_order_number_counter',
  'reset_counter_frequency_id',
  'counter_padding',
  'tax_rate1',
  'tax_rate2',
  'tax_rate3',
  'num_days_reminder1',
  'num_days_reminder2',
  'num_days_reminder3',
  'quote_num_days_reminder1',
  'reminder_send_time',
  'late_fee_amount1',
  'late_fee_amount2',
  'late_fee_amount3',
  'quote_late_fee_amount1',
  'late_fee_percent1',
  'late_fee_percent2',
  'late_fee_percent3',
  'quote_late_fee_percent1',
  'late_fee_endless_amount',
  'late_fee_endless_percent',
  'entity_send_time',
  'font_size',
  'client_portal_under_payment_minimum',
  'client_initiated_payments_minimum',
  'default_task_rate',
  'task_round_to_nearest',
};

/// Snake_case keys that map to a `bool?` field on [CompanySettingsApi].
/// The server sometimes ships these as `0`/`1` (int) or as `"0"`/`"1"`/
/// `"true"`/`"false"` (string). Coerced before the strict cast.
const Set<String> _settingsBoolKeys = {
  'military_time',
  'show_currency_code',
  'use_comma_as_decimal_place',
  'shared_invoice_quote_counter',
  'shared_invoice_credit_counter',
  'inclusive_taxes',
  'enable_rappen_rounding',
  'track_inventory',
  'enable_email_markup',
  'show_email_footer',
  'pdf_email_attachment',
  'ubl_email_attachment',
  'document_email_attachment',
  'send_email_on_mark_paid',
  'payment_email_all_contacts',
  'send_reminders',
  'enable_reminder1',
  'enable_reminder2',
  'enable_reminder3',
  'enable_reminder_endless',
  'enable_quote_reminder1',
  'auto_archive_invoice',
  'auto_archive_invoice_cancelled',
  'auto_archive_quote',
  'auto_convert_quote',
  'auto_email_invoice',
  'global_tag_inheritance',
  'auto_bill_standard_invoices',
  'show_accept_invoice_terms',
  'show_accept_quote_terms',
  'require_invoice_signature',
  'require_quote_signature',
  'require_purchase_order_signature',
  'signature_on_pdf',
  'accept_client_input_quote_approval',
  'sync_invoice_quote_columns',
  'show_shipping_address',
  'show_paid_stamp',
  'page_numbering',
  'hide_paid_to_date',
  'hide_empty_columns_on_pdf',
  'embed_documents',
  'all_pages_header',
  'all_pages_footer',
  'show_pdfhtml_on_mobile',
  'enable_client_portal',
  'enable_client_portal_dashboard',
  'enable_client_portal_tasks',
  'enable_client_portal_password',
  'client_portal_enable_uploads',
  'client_portal_allow_under_payment',
  'client_portal_allow_over_payment',
  'client_can_register',
  'client_initiated_payments',
  'enable_client_profile_update',
  'client_online_payment_notification',
  'client_manual_payment_notification',
  'vendor_portal_enable_uploads',
  'unlock_invoice_documents_after_payment',
  'show_task_item_description',
  'allow_billable_task_items',
  'task_round_up',
  'enable_e_invoice',
  'merge_e_invoice_to_pdf',
  'skip_automatic_email_with_peppol',
  'preference_product_notes_for_html_view',
  'france_reporting_enabled',
};

/// Walk [raw] and coerce known-numeric/bool keys whose values come in the
/// wrong wire type. Returns a new map; unknown keys pass through unchanged.
///
/// Coercion rules:
///   * Numeric key + String value: `num.tryParse(value)` (parse-fail → drop).
///   * Bool key + int value: `0` → false, anything else → true.
///   * Bool key + String value: `"0"`/`"false"` → false, `"1"`/`"true"` → true.
///     Other strings → drop (the strict parser would crash anyway; better
///     to silently lose a single field than the whole row).
Map<String, dynamic> _sanitizeSettingsJson(Map<String, dynamic> raw) {
  final out = <String, dynamic>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value == null) continue;
    if (key == 'translations' && value is List) {
      // PHP serializes an empty assoc-array as `[]` instead of `{}`. The
      // strict parser would crash casting to `Map<String, dynamic>?`; omit
      // so it reads as null.
      continue;
    }
    if (_settingsNumericKeys.contains(key) && value is String) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null) out[key] = parsed;
      // unparseable → omit so the strict parser sees `null`, not a String.
      continue;
    }
    if (_settingsBoolKeys.contains(key)) {
      if (value is bool) {
        out[key] = value;
        continue;
      }
      if (value is num) {
        out[key] = value != 0;
        continue;
      }
      if (value is String) {
        final lower = value.trim().toLowerCase();
        if (lower == '1' || lower == 'true') {
          out[key] = true;
        } else if (lower == '0' || lower == 'false' || lower.isEmpty) {
          out[key] = false;
        }
        // anything else → omit.
        continue;
      }
    }
    out[key] = value;
  }
  return out;
}

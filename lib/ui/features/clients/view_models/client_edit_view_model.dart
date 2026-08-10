import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/device_contacts_service.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Drives the Client edit + create screen.
///
/// Holds the in-progress draft in memory. [save] (inherited from
/// [GenericEditViewModel]) is optimistic — it lands the draft in Drift via
/// the repository and pops the route immediately; the outbox handles the
/// server round-trip in the background. 422 validation errors populate
/// `fieldErrors`; other errors land on [submitError].
class ClientEditViewModel extends GenericEditViewModel<Client> {
  ClientEditViewModel({
    required this.repo,
    required this.companyId,
    Client? existing,
    Client? cloneFrom,
    String? prefillGroupId,
    this.nameOrContactRequiredMessage,
    super.sync,
    super.connectivity,
    super.useCommaAsDecimalPlace,
    super.onlineSaveTimeout,
  }) : super(
         initialDraft:
             cloneFrom ??
             existing ??
             emptyClient(groupSettingsId: prefillGroupId),
         original: existing,
         companyId: companyId,
       );

  final ClientRepository repo;
  final String companyId;

  /// Localized `please_enter_a_client_or_contact_name`, enabling the
  /// name-or-contact-name guard in [validate].
  ///
  /// Non-null **only** for the quick New-Client dialog: React applies this
  /// guard in its inline create modal but not in the full client form, and the
  /// server's own rule is `name => sometimes|nullable`. Leaving it null keeps
  /// the full edit screen's behavior unchanged. VMs have no `BuildContext`, so
  /// the string is injected — same shape as `VendorEditViewModel`.
  final String? nameOrContactRequiredMessage;

  /// Blocks a save that would create a client with no way to identify it.
  /// Mirrors React's `ClientCreate` guard: allowed as soon as *either* the
  /// client name or the primary contact's first/last name is filled.
  @override
  Map<String, List<String>> validate() {
    final message = nameOrContactRequiredMessage;
    if (message == null) return const {};
    final contact = draft.contacts.isEmpty ? null : draft.contacts.first;
    final named =
        draft.name.trim().isNotEmpty ||
        (contact?.firstName.trim().isNotEmpty ?? false) ||
        (contact?.lastName.trim().isNotEmpty ?? false);
    if (named) return const {};
    // React binds the same message under all three fields.
    return {
      'name': [message],
      'contacts.0.first_name': [message],
      'contacts.0.last_name': [message],
    };
  }

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.name.isNotEmpty ||
        d.number.isNotEmpty ||
        d.phone.isNotEmpty ||
        d.website.isNotEmpty ||
        d.address1.isNotEmpty ||
        d.shippingAddress1.isNotEmpty ||
        d.privateNotes.isNotEmpty ||
        d.publicNotes.isNotEmpty ||
        // The blank primary contact we seed on a new client is all-empty, so
        // it doesn't count — but a contact the user actually filled in does,
        // so navigating away from contact-only entry still prompts to discard.
        d.contacts.any((c) => !_isBlankContact(c));
  }

  @override
  Future<SaveResult<Client>> performSave() async {
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, client: draft);
  }

  /// Reset back to the original draft (or an empty client in create mode).
  void resetToEmpty() => reset(emptyDraft: emptyClient());

  void setGroupSettingsId(String id) =>
      updateDraft(draft.copyWith(groupSettingsId: id));

  void setAssignedUserId(String id) =>
      updateDraft(draft.copyWith(assignedUserId: id));

  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));

  void setName(String value) =>
      updateDraft(draft.copyWith(name: value, displayName: value));
  void setNumber(String value) => updateDraft(draft.copyWith(number: value));
  void setIdNumber(String value) =>
      updateDraft(draft.copyWith(idNumber: value));
  void setVatNumber(String value) =>
      updateDraft(draft.copyWith(vatNumber: value));
  void setWebsite(String value) => updateDraft(draft.copyWith(website: value));
  void setPhone(String value) => updateDraft(draft.copyWith(phone: value));
  void setAddress1(String value) =>
      updateDraft(draft.copyWith(address1: value));
  void setAddress2(String value) =>
      updateDraft(draft.copyWith(address2: value));
  void setCity(String value) => updateDraft(draft.copyWith(city: value));
  void setState(String value) => updateDraft(draft.copyWith(state: value));
  void setPostalCode(String value) =>
      updateDraft(draft.copyWith(postalCode: value));
  void setCountryId(String value) =>
      updateDraft(draft.copyWith(countryId: value));

  // ───────────────────────── shipping address ───────────────────────────
  void setShippingAddress1(String value) =>
      updateDraft(draft.copyWith(shippingAddress1: value));
  void setShippingAddress2(String value) =>
      updateDraft(draft.copyWith(shippingAddress2: value));
  void setShippingCity(String value) =>
      updateDraft(draft.copyWith(shippingCity: value));
  void setShippingState(String value) =>
      updateDraft(draft.copyWith(shippingState: value));
  void setShippingPostalCode(String value) =>
      updateDraft(draft.copyWith(shippingPostalCode: value));
  void setShippingCountryId(String value) =>
      updateDraft(draft.copyWith(shippingCountryId: value));

  /// Copy the billing address into the shipping address (React parity: the
  /// "Copy billing address" affordance on the Shipping section).
  void copyBillingToShipping() => updateDraft(
    draft.copyWith(
      shippingAddress1: draft.address1,
      shippingAddress2: draft.address2,
      shippingCity: draft.city,
      shippingState: draft.state,
      shippingPostalCode: draft.postalCode,
      shippingCountryId: draft.countryId,
    ),
  );

  // ──────────────────── per-client settings (cascade) ───────────────────
  // currency / language / payment_terms are top-level domain fields that
  // `Client.toApiJson` folds into the `settings` cascade on save; the others
  // are real top-level client fields.
  void setCurrencyId(String value) =>
      updateDraft(draft.copyWith(currencyId: value));
  void setLanguageId(String value) =>
      updateDraft(draft.copyWith(languageId: value));
  void setPaymentTerms(String value) =>
      updateDraft(draft.copyWith(paymentTerms: value));
  void setClassification(String value) =>
      updateDraft(draft.copyWith(classification: value));
  void setSizeId(String value) => updateDraft(draft.copyWith(sizeId: value));
  void setIndustryId(String value) =>
      updateDraft(draft.copyWith(industryId: value));
  void setIsTaxExempt(bool value) =>
      updateDraft(draft.copyWith(isTaxExempt: value));
  void setHasValidVatNumber(bool value) =>
      updateDraft(draft.copyWith(hasValidVatNumber: value));
  void setRoutingId(String value) =>
      updateDraft(draft.copyWith(routingId: value));

  /// Per-client default task rate — a cascade setting stored in `settings`
  /// (no top-level domain field). Stored as a **num** (not a string) to match
  /// the server's `?float default_task_rate` and the admin-portal payload;
  /// a blank/unparseable value clears the override (inherit from company).
  void setDefaultTaskRate(String value) {
    // `zeroIsNull` so a blank field (or a typed 0) clears the override and
    // inherits, rather than persisting a meaningless 0 task rate.
    final parsed = parseDouble(
      value,
      zeroIsNull: true,
      useCommaAsDecimalPlace: useCommaAsDecimalPlace,
    );
    final next = Map<String, dynamic>.from(draft.settings ?? const {});
    if (parsed == null) {
      next.remove('default_task_rate');
    } else {
      next['default_task_rate'] = parsed;
    }
    updateDraft(draft.copyWith(settings: next.isEmpty ? null : next));
  }

  /// Quote "valid until" — a cascade setting (number of days) stored in
  /// `settings`, with no top-level domain field. Empty clears the override
  /// (inherit from the company/group), matching the cascade convention used
  /// by currency / language / payment_terms.
  void setValidUntil(String value) =>
      updateDraft(draft.withCascadeOverride('valid_until', value.trim()));

  /// Current `valid_until` override (days) for the edit field; '' = inherit.
  String get validUntil => draft.settings?['valid_until']?.toString() ?? '';

  /// Send-reminders cascade override stored in `settings` (a bool). `null`
  /// clears the override (inherit from the company); true/false write an
  /// explicit value. Mirrors [setDefaultTaskRate]'s raw-settings handling
  /// (the value is a bool, not a string, so `withCascadeOverride` — which is
  /// string-typed — doesn't apply).
  void setSendReminders(bool? value) {
    final next = Map<String, dynamic>.from(draft.settings ?? const {});
    if (value == null) {
      next.remove('send_reminders');
    } else {
      next['send_reminders'] = value;
    }
    updateDraft(draft.copyWith(settings: next.isEmpty ? null : next));
  }

  /// Current `send_reminders` override; null = inherit (no per-client value).
  bool? get sendReminders {
    final v = draft.settings?['send_reminders'];
    return v is bool ? v : null;
  }

  void setPrivateNotes(String value) =>
      updateDraft(draft.copyWith(privateNotes: value));
  void setPublicNotes(String value) =>
      updateDraft(draft.copyWith(publicNotes: value));

  void setCustomValue1(String value) =>
      updateDraft(draft.copyWith(customValue1: value));
  void setCustomValue2(String value) =>
      updateDraft(draft.copyWith(customValue2: value));
  void setCustomValue3(String value) =>
      updateDraft(draft.copyWith(customValue3: value));
  void setCustomValue4(String value) =>
      updateDraft(draft.copyWith(customValue4: value));

  // ───────────────────────── contacts (indexed) ─────────────────────────

  /// Append a fresh empty contact. The new row is marked primary only when
  /// the list was empty — there should always be exactly one primary on a
  /// non-empty list.
  void addContact() {
    final contacts = [...draft.contacts];
    final isFirst = contacts.isEmpty;
    contacts.add(_emptyContact().copyWith(isPrimary: isFirst));
    updateDraft(draft.copyWith(contacts: contacts));
  }

  /// Remove the contact at [index]. If that contact was the primary and any
  /// others remain, contacts[0] is promoted so the entity always carries one
  /// primary (or none when the list ends up empty).
  void removeContact(int index) {
    if (index < 0 || index >= draft.contacts.length) return;
    final contacts = [...draft.contacts];
    final removed = contacts.removeAt(index);
    if (removed.isPrimary && contacts.isNotEmpty) {
      contacts[0] = contacts[0].copyWith(isPrimary: true);
    }
    updateDraft(draft.copyWith(contacts: contacts));
  }

  /// Mark [index] as primary; clears `isPrimary` on every other contact.
  /// Idempotent — calling it on the already-primary index just re-notifies.
  void setContactPrimary(int index) {
    if (index < 0 || index >= draft.contacts.length) return;
    final contacts = <Contact>[
      for (var i = 0; i < draft.contacts.length; i++)
        draft.contacts[i].copyWith(isPrimary: i == index),
    ];
    updateDraft(draft.copyWith(contacts: contacts));
  }

  void setContactFirstNameAt(int i, String v) =>
      _updateContactAt(i, (c) => c.copyWith(firstName: v));
  void setContactLastNameAt(int i, String v) =>
      _updateContactAt(i, (c) => c.copyWith(lastName: v));
  void setContactEmailAt(int i, String v) =>
      _updateContactAt(i, (c) => c.copyWith(email: v));
  void setContactPhoneAt(int i, String v) =>
      _updateContactAt(i, (c) => c.copyWith(phone: v));
  void setContactSendEmailAt(int i, bool v) =>
      _updateContactAt(i, (c) => c.copyWith(sendEmail: v));
  // CC-only and send_email are mutually exclusive: turning CC-only on
  // forces send_email off (mirrors the React web client).
  void setContactCcOnlyAt(int i, bool v) => _updateContactAt(
    i,
    (c) => c.copyWith(ccOnly: v, sendEmail: v ? false : c.sendEmail),
  );
  // "Authorized to sign" — portal e-signature permission (React parity). The
  // UI gates the toggle on the company's e-sign module being enabled.
  void setContactCanSignAt(int i, bool v) =>
      _updateContactAt(i, (c) => c.copyWith(canSign: v));
  void setContactPasswordAt(int i, String v) =>
      _updateContactAt(i, (c) => c.copyWith(password: v));

  void setContactCustomValue1At(int i, String v) =>
      _updateContactAt(i, (c) => c.copyWith(customValue1: v));
  void setContactCustomValue2At(int i, String v) =>
      _updateContactAt(i, (c) => c.copyWith(customValue2: v));
  void setContactCustomValue3At(int i, String v) =>
      _updateContactAt(i, (c) => c.copyWith(customValue3: v));
  void setContactCustomValue4At(int i, String v) =>
      _updateContactAt(i, (c) => c.copyWith(customValue4: v));

  void _updateContactAt(int index, Contact Function(Contact) edit) {
    if (index < 0 || index >= draft.contacts.length) return;
    final contacts = [...draft.contacts];
    contacts[index] = edit(contacts[index]);
    updateDraft(draft.copyWith(contacts: contacts));
  }

  // ─────────────────────── device contact import ────────────────────────

  /// Replace the whole draft — used to restore the pre-import snapshot when the
  /// user taps Undo on the import toast.
  void restoreDraft(Client snapshot) => updateDraft(snapshot);

  /// Apply an OS-picked device contact **non-destructively**:
  ///  - Client identity (name / address / website) fills only blank fields.
  ///  - The person fills the first all-blank contact row, else is appended —
  ///    skipped when it duplicates an existing contact (email, then first+last).
  ///
  /// [countryId] is the already-resolved Invoice Ninja country id (the UI
  /// resolves it from the device ISO/name via [resolveCountryId] + statics, so
  /// the VM stays free of `Services`). Mutates the draft once (a single notify),
  /// so one [restoreDraft] undoes everything. Returns a [ContactImportResult] so
  /// the caller can pick the toast variant and summarize what changed.
  ContactImportResult applyImportedContact(
    DeviceContactImport c, {
    required String countryId,
  }) {
    var next = draft;
    final filled = <String>[];

    // ── Client identity (blanks-only) ──
    if (next.name.trim().isEmpty) {
      final name = _clientNameFrom(c);
      if (name.isNotEmpty) {
        next = next.copyWith(name: name, displayName: name);
        filled.add('name');
      }
    }
    var addressChanged = false;
    if (next.address1.trim().isEmpty && c.address1.trim().isNotEmpty) {
      next = next.copyWith(address1: c.address1.trim());
      addressChanged = true;
    }
    if (next.city.trim().isEmpty && c.city.trim().isNotEmpty) {
      next = next.copyWith(city: c.city.trim());
      addressChanged = true;
    }
    if (next.state.trim().isEmpty && c.state.trim().isNotEmpty) {
      next = next.copyWith(state: c.state.trim());
      addressChanged = true;
    }
    if (next.postalCode.trim().isEmpty && c.postalCode.trim().isNotEmpty) {
      next = next.copyWith(postalCode: c.postalCode.trim());
      addressChanged = true;
    }
    if (next.countryId.isEmpty && countryId.isNotEmpty) {
      next = next.copyWith(countryId: countryId);
      addressChanged = true;
    }
    if (addressChanged) filled.add('address');
    if (next.website.trim().isEmpty && c.website.trim().isNotEmpty) {
      next = next.copyWith(website: c.website.trim());
      filled.add('website');
    }

    // ── Person ──
    var first = c.firstName.trim();
    var last = c.lastName.trim();
    if (first.isEmpty && last.isEmpty) {
      final split = _splitDisplayName(c.displayName);
      first = split.$1;
      last = split.$2;
    }
    final email = c.email.trim();
    final phone = c.phone.trim();
    final hasPerson =
        first.isNotEmpty ||
        last.isNotEmpty ||
        email.isNotEmpty ||
        phone.isNotEmpty;

    var contactAdded = false;
    var contactWasDuplicate = false;
    if (hasPerson) {
      final contacts = [...next.contacts];
      if (_findDuplicateContact(contacts, email, phone, first, last) >= 0) {
        contactWasDuplicate = true;
      } else {
        final blankIdx = contacts.indexWhere(_isBlankContact);
        final filledContact =
            (blankIdx >= 0 ? contacts[blankIdx] : _emptyContact()).copyWith(
              firstName: first,
              lastName: last,
              email: email,
              phone: phone,
            );
        if (blankIdx >= 0) {
          contacts[blankIdx] = filledContact;
        } else {
          contacts.add(filledContact.copyWith(isPrimary: contacts.isEmpty));
        }
        next = next.copyWith(contacts: contacts);
        contactAdded = true;
      }
    }

    final result = ContactImportResult(
      contactAdded: contactAdded,
      contactWasDuplicate: contactWasDuplicate,
      filledClientFields: filled,
    );
    if (result.appliedChanges) updateDraft(next);
    return result;
  }

  // ───────────────────────── primary contact (legacy) ───────────────────

  // Kept for backwards compatibility with `client_edit_view_model_test.dart`,
  // which exercises the "create primary on the fly when none exists" and
  // "edit-in-place" semantics. New UI code should prefer the indexed
  // `setContactFirstNameAt(i, v)` family.

  void setPrimaryContactFirstName(String value) =>
      _updatePrimaryContact((c) => c.copyWith(firstName: value));
  void setPrimaryContactLastName(String value) =>
      _updatePrimaryContact((c) => c.copyWith(lastName: value));
  void setPrimaryContactEmail(String value) =>
      _updatePrimaryContact((c) => c.copyWith(email: value));
  void setPrimaryContactPhone(String value) =>
      _updatePrimaryContact((c) => c.copyWith(phone: value));

  void _updatePrimaryContact(Contact Function(Contact) edit) {
    final contacts = [...draft.contacts];
    if (contacts.isEmpty) {
      contacts.add(edit(_emptyContact()));
    } else {
      final i = contacts.indexWhere((c) => c.isPrimary);
      final idx = i < 0 ? 0 : i;
      contacts[idx] = edit(contacts[idx]);
    }
    updateDraft(draft.copyWith(contacts: contacts));
  }
}

Client emptyClient({String? groupSettingsId}) => Client(
  id: '',
  name: '',
  displayName: '',
  number: '',
  idNumber: '',
  vatNumber: '',
  website: '',
  phone: '',
  address1: '',
  address2: '',
  city: '',
  state: '',
  postalCode: '',
  countryId: '',
  balance: Decimal.zero,
  paidToDate: Decimal.zero,
  creditBalance: Decimal.zero,
  currencyId: '',
  languageId: '',
  paymentTerms: '',
  privateNotes: '',
  publicNotes: '',
  groupSettingsId: groupSettingsId ?? '',
  assignedUserId: '',
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  // The API enforces at least one contact per client, so a new client always
  // starts with a blank primary contact visible (no "+ Add contact" needed
  // first). `_emptyContact()` is already `isPrimary: true`.
  contacts: [_emptyContact()],
);

Contact _emptyContact() => Contact(
  id: '',
  firstName: '',
  lastName: '',
  email: '',
  phone: '',
  isPrimary: true,
  sendEmail: true,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  isDeleted: false,
);

/// Outcome of [ClientEditViewModel.applyImportedContact], so the UI can choose
/// the toast (success / "already a contact" / "nothing found") and summarize
/// which fields filled — keeping all copy (and `tr`) out of the view model.
class ContactImportResult {
  const ContactImportResult({
    required this.contactAdded,
    required this.contactWasDuplicate,
    required this.filledClientFields,
  });

  /// A person row was filled in place or appended.
  final bool contactAdded;

  /// The person matched an existing contact and was skipped.
  final bool contactWasDuplicate;

  /// Stable tokens for client fields that filled: `'name'`, `'address'`,
  /// `'website'` (each maps to an existing localization key in the UI).
  final List<String> filledClientFields;

  /// Whether the draft actually changed (drives the success toast + Undo).
  bool get appliedChanges => contactAdded || filledClientFields.isNotEmpty;

  /// Nothing landed at all — not even a duplicate skip (drives the warning).
  bool get changedNothing => !appliedChanges && !contactWasDuplicate;
}

/// Client name for an imported contact: the company, else the person's full
/// name (so importing an individual doesn't leave the client nameless), else
/// the OS display name, else the email.
String _clientNameFrom(DeviceContactImport c) {
  if (c.organization.trim().isNotEmpty) return c.organization.trim();
  final full = '${c.firstName} ${c.lastName}'.trim();
  if (full.isNotEmpty) return full;
  if (c.displayName.trim().isNotEmpty) return c.displayName.trim();
  return c.email.trim();
}

/// Split a single display name into (first, rest) on whitespace. Used only when
/// the device gives a display name but no structured first/last.
(String, String) _splitDisplayName(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return ('', '');
  if (parts.length == 1) return (parts.first, '');
  return (parts.first, parts.sublist(1).join(' '));
}

bool _isBlankContact(Contact c) =>
    c.firstName.trim().isEmpty &&
    c.lastName.trim().isEmpty &&
    c.email.trim().isEmpty &&
    c.phone.trim().isEmpty;

/// Index of an existing contact that duplicates the import — by email, then by
/// phone (digits only), then by a **full** first+last match. Returns -1 when
/// none matches. The name pass requires both parts so that re-importing a
/// single-name card (e.g. "Cher") never silently skips a *different* person who
/// happens to share that first name — it appends instead.
int _findDuplicateContact(
  List<Contact> contacts,
  String email,
  String phone,
  String first,
  String last,
) {
  final e = email.trim().toLowerCase();
  if (e.isNotEmpty) {
    final i = contacts.indexWhere((c) => c.email.trim().toLowerCase() == e);
    if (i >= 0) return i;
  }
  final p = _digitsOnly(phone);
  if (p.isNotEmpty) {
    final i = contacts.indexWhere((c) => _digitsOnly(c.phone) == p);
    if (i >= 0) return i;
  }
  final f = first.trim().toLowerCase();
  final l = last.trim().toLowerCase();
  if (f.isEmpty || l.isEmpty) return -1;
  return contacts.indexWhere(
    (c) =>
        c.firstName.trim().toLowerCase() == f &&
        c.lastName.trim().toLowerCase() == l,
  );
}

String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

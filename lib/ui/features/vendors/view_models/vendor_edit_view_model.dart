import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the Vendor edit + create screen.
///
/// Holds the in-progress draft in memory. [save] (inherited from
/// [GenericEditViewModel]) is optimistic — it lands the draft in Drift via
/// the repository and pops the route immediately; the outbox handles the
/// server round-trip in the background. 422 validation errors populate
/// `fieldErrors`; other errors land on [submitError]. Same shape as
/// `ClientEditViewModel`.
class VendorEditViewModel extends GenericEditViewModel<Vendor> {
  VendorEditViewModel({
    required this.repo,
    required this.companyId,
    required this.nameRequiredMessage,
    Vendor? existing,
    Vendor? cloneFrom,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: cloneFrom ?? existing ?? emptyVendor(),
         original: existing,
         companyId: companyId,
       );

  final VendorRepository repo;
  final String companyId;

  /// Localized "please enter a name" message, resolved at the screen (VMs have
  /// no `BuildContext`) and surfaced inline via [validate] →
  /// `fieldErrorFor('name')`. Mirrors
  /// `PurchaseOrderEditViewModel.vendorRequiredMessage`.
  final String nameRequiredMessage;

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.name.isNotEmpty ||
        d.number.isNotEmpty ||
        d.phone.isNotEmpty ||
        d.website.isNotEmpty ||
        d.address1.isNotEmpty ||
        d.privateNotes.isNotEmpty ||
        d.publicNotes.isNotEmpty ||
        // An all-empty contact doesn't count — a new vendor starts with none
        // (unlike a client — `_emptyVendor` seeds `const []`), but the user can
        // add a row and leave it blank, and a vendor loaded for edit carries
        // whatever the server made. A contact actually filled in does count,
        // so navigating away from contact-only entry still prompts to discard.
        d.contacts.any((c) => !c.isBlank);
  }

  @override
  Map<String, List<String>> validate() => {
    // The server requires a vendor name (`StoreVendorRequest`). Fail fast inline
    // instead of letting the optimistic save land a dead outbox row.
    if (draft.name.trim().isEmpty) 'name': [nameRequiredMessage],
  };

  @override
  Future<SaveResult<Vendor>> performSave() async {
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, vendor: draft);
  }

  /// Reset back to the original draft (or an empty vendor in create mode).
  void resetToEmpty() => reset(emptyDraft: emptyVendor());

  void setName(String value) => updateDraft(draft.copyWith(name: value));
  void setNumber(String value) => updateDraft(draft.copyWith(number: value));
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));
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
  void setCurrencyId(String value) =>
      updateDraft(draft.copyWith(currencyId: value));
  void setLanguageId(String value) =>
      updateDraft(draft.copyWith(languageId: value));
  void setClassification(String value) =>
      updateDraft(draft.copyWith(classification: value));
  void setRoutingId(String value) =>
      updateDraft(draft.copyWith(routingId: value));
  void setIsTaxExempt(bool value) =>
      updateDraft(draft.copyWith(isTaxExempt: value));
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

  /// Append a fresh empty contact. Mirrors `ClientEditViewModel.addContact`.
  void addContact() {
    final contacts = [...draft.contacts];
    final isFirst = contacts.isEmpty;
    contacts.add(_emptyContact().copyWith(isPrimary: isFirst));
    updateDraft(draft.copyWith(contacts: contacts));
  }

  /// Remove the contact at [index]. If that contact was primary, the new
  /// first contact gets promoted so the entity always carries one primary.
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
  void setContactPrimary(int index) {
    if (index < 0 || index >= draft.contacts.length) return;
    final contacts = <VendorContact>[
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
  void setContactCcOnlyAt(int i, bool v) =>
      _updateContactAt(i, (c) => c.copyWith(ccOnly: v));
  void setContactSendEmailAt(int i, bool v) =>
      _updateContactAt(i, (c) => c.copyWith(sendEmail: v));
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

  void _updateContactAt(int index, VendorContact Function(VendorContact) edit) {
    if (index < 0 || index >= draft.contacts.length) return;
    final contacts = [...draft.contacts];
    contacts[index] = edit(contacts[index]);
    updateDraft(draft.copyWith(contacts: contacts));
  }
}

VendorContact _emptyContact() => VendorContact(
  id: '',
  firstName: '',
  lastName: '',
  email: '',
  phone: '',
  password: '',
  sendEmail: true,
  isPrimary: true,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  isDeleted: false,
);

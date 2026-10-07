import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/utils/mail_actions.dart';
import 'package:admin/ui/core/utils/phone_actions.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/party_contact_row.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/features/clients/widgets/client_portal.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// "Contacts" card on the client detail screen. Shows the first 3 contacts
/// inline. Extra contacts surface via "+N more":
///   - ≥[Breakpoints.wide] screen width (tablet/desktop): expands inline within the same card.
///   - below: opens a bottom sheet listing every contact.
///
/// Hides entirely when no contact has a name, email or phone. `contacts` is
/// never empty in practice — the API enforces at least one contact per client,
/// so a client the user never gave contact details to still carries an
/// all-blank one — which is why the question is [ContactIdentity.isBlank] per
/// row rather than `contacts.isEmpty` (invoiceninja/flutter#115). React's
/// `clients/show/components/Contacts.tsx` filters rows the same way.
///
/// The wide/narrow decision uses `MediaQuery.sizeOf(context).width` rather than
/// `LayoutBuilder`. The grid above this card uses `IntrinsicHeight` so cards
/// align to equal heights on desktop; `IntrinsicHeight` queries children for
/// intrinsic sizes, and `LayoutBuilder` cannot answer those queries (it needs
/// real constraints first). `MediaQuery` is an inherited-widget lookup, so it
/// answers fine during the intrinsic pass.
class ClientDetailContactsCard extends StatefulWidget {
  const ClientDetailContactsCard({
    super.key,
    required this.contacts,
    required this.clientHash,
    required this.clientId,
    this.company,
  });

  /// For contact custom-field labels; null draws none.
  final Company? company;

  final List<Contact> contacts;

  /// Client-level auth token appended to each contact's portal silent-login
  /// URL (`?silent=true&client_hash=…`).
  final String clientHash;

  /// The client's own id — **not** [clientHash], which is a portal token.
  /// Resolves this client's `settings.timezone_id` override so a call placed
  /// from here knows what time it is where the phone will ring.
  final String clientId;

  /// Whether [build] renders at least one row — the grid gates both its wide
  /// column and its stacked entry on this. Takes the contact list rather than
  /// the `Client` (unlike the sibling cards' `hasContent(Client)`) because
  /// that is what this card is constructed from.
  static bool hasContent(List<Contact> contacts, {Company? company}) =>
      visibleClientContacts(contacts, company: company).isNotEmpty;

  @override
  State<ClientDetailContactsCard> createState() =>
      _ClientDetailContactsCardState();
}

/// The contacts worth rendering. A blank one has nothing to show but
/// `(no name)`, a primary star, and portal buttons for a link the server mints
/// for it regardless — the portal stays reachable from `ClientAction.clientPortal`.
/// A deleted one is not this client's contact any more.
///
/// **A custom value the company has a label for is content.** The row prints
/// contact custom fields now, so a contact whose only entry is one — a
/// "Department" with no name typed — has a line to show, and `Contact.isBlank`
/// (which deliberately leaves custom values out, and says a card that renders
/// them must widen its own test) would hide it. Pass [company] to count them;
/// without it the labels are unknown and the narrower test applies.
List<Contact> visibleClientContacts(
  List<Contact> contacts, {
  Company? company,
}) => contacts
    .where(
      (c) =>
          !c.isDeleted && (!c.isBlank || _hasLabelledCustomValue(c, company)),
    )
    .toList(growable: false);

List<String> _customValuesOf(Contact c) => [
  c.customValue1,
  c.customValue2,
  c.customValue3,
  c.customValue4,
];

/// Whether [contact]'s row will print at least one custom field — the same
/// `customFieldDetailRows` the row itself uses, so "worth showing" and "has
/// something to show" cannot disagree.
bool _hasLabelledCustomValue(Contact contact, Company? company) {
  if (company == null) return false;
  final values = _customValuesOf(contact);
  if (values.every((v) => v.isEmpty)) return false;
  return customFieldDetailRows(
    company: company,
    prefix: 'contact',
    values: values,
    yes: '',
    no: '',
  ).isNotEmpty;
}

/// The contact a record screen leads with: the primary one when it has
/// anything to show, otherwise the first that does.
///
/// Chosen from the *visible* list, not by `isPrimary` alone — the server seeds
/// every client with one all-blank contact and marks it primary, so on a
/// client whose real contact was added second, "the primary" is the row with
/// nothing in it.
Contact? primaryClientContact(List<Contact> contacts, {Company? company}) {
  final visible = visibleClientContacts(contacts, company: company);
  if (visible.isEmpty) return null;
  return visible.firstWhere((c) => c.isPrimary, orElse: () => visible.first);
}

/// Every visible contact in a sheet — the "+N more" destination on a narrow
/// layout, and the way from a record's summary (which shows one contact) to
/// the rest without opening the whole profile.
///
/// On the root navigator, and width-capped: inside the master-detail pane the
/// nearest navigator is the pane's own, where the sheet would be a slab pinned
/// under a ~500 px column, and on a wide window an uncapped one runs the full
/// width of the screen.
Future<void> showClientContactsSheet(
  BuildContext context, {
  required List<Contact> contacts,
  required String clientHash,
  required String clientId,
  Company? company,
}) {
  // Re-provided rather than inherited: the sheet is a route on the ROOT
  // navigator, which may sit above whatever `Provider<Services>` the caller
  // is under — the same reason the phone picker does this.
  final services = context.read<Services>();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) {
      final tokens = sheetContext.inTheme;
      return Provider<Services>.value(
        value: services,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                InSpacing.lg(sheetContext),
                InSpacing.sm,
                InSpacing.lg(sheetContext),
                InSpacing.lg(sheetContext),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: InSpacing.sm),
                    child: Text(
                      sheetContext.tr('contacts'),
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(
                            color: tokens.ink,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: DetailRowStack(
                        children:
                            visibleClientContacts(contacts, company: company)
                                .map(
                                  (c) => ClientContactRow(
                                    c,
                                    clientHash,
                                    clientId,
                                    company: company,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ClientDetailContactsCardState extends State<ClientDetailContactsCard> {
  static const int _inlineLimit = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Filter BEFORE the early return, and count "+N more" off the filtered
    // list: an overflow button offering to reveal rows that paint nothing is
    // the same bug as the blank row itself.
    final all = visibleClientContacts(widget.contacts, company: widget.company);
    if (all.isEmpty) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
    final showAll = _expanded || all.length <= _inlineLimit;
    final visible = showAll ? all : all.take(_inlineLimit).toList();
    final hiddenCount = all.length - visible.length;

    return DashboardCardShell(
      title: context.tr('contacts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailRowStack(
            children: visible
                .map(
                  (c) => ClientContactRow(
                    c,
                    widget.clientHash,
                    widget.clientId,
                    company: widget.company,
                  ),
                )
                .toList(),
          ),
          if (hiddenCount > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () {
                  if (wide) {
                    setState(() => _expanded = true);
                  } else {
                    _openSheet(context);
                  }
                },
                icon: const Icon(Icons.unfold_more, size: 16),
                label: Text(
                  context.tr('plus_n_more', {'count': '$hiddenCount'}),
                ),
              ),
            )
          // An inline expansion has to be undoable: a client with thirty
          // contacts otherwise stays thirty rows tall until the screen is
          // rebuilt.
          else if (_expanded && all.length > _inlineLimit)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = false),
                icon: const Icon(Icons.unfold_less, size: 16),
                label: Text(context.tr('less')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) => showClientContactsSheet(
    context,
    contacts: widget.contacts,
    clientHash: widget.clientHash,
    clientId: widget.clientId,
    company: widget.company,
  );
}

/// One client contact, as a [PartyContactRow]. Public so the record screen's
/// summary can lead with the primary contact using the very row the Contacts
/// card lists the others in.
///
/// This is the client half of the split that widget's doc describes: it turns
/// a [Contact] into strings and callbacks, and decides which actions exist.
///
/// **Action order** is Call, Email, Copy portal link, then Message and View
/// Portal. The row gives the first two available their own button, so a phone
/// gets Call + Email and a desktop with tap-to-call off gets Email + Copy
/// portal link — the two things a desktop user does with a contact.
class ClientContactRow extends StatelessWidget {
  const ClientContactRow(
    this.contact,
    this.clientHash,
    this.clientId, {
    super.key,
    this.company,
  });

  final Contact contact;
  final String clientHash;
  final String clientId;

  /// For contact custom-field labels; null draws none.
  final Company? company;

  // `PhoneActionsScope` wraps the WHOLE row, not just the number: the Call /
  // Message actions are built here, one level above `PhoneNumberValue`'s own
  // scope, so without this they hold whatever the preference was when the card
  // was last built. A detail screen stays mounted behind `/settings/**`, so
  // flipping the switch there left a live Call button beside a number that had
  // already gone inert.
  @override
  Widget build(BuildContext context) => PhoneActionsScope(builder: _buildRow);

  Widget _buildRow(BuildContext context) {
    final subject = _contactSubject(context, contact);
    // Titled with the contact, filed against the client: this row is the one
    // place the app knows *which person* was rung.
    final CallLogTarget logTarget = (
      type: EntityType.client,
      id: clientId,
      subject: subject,
    );
    final dialable = canDialPhone(context, contact.phone);
    final hasEmail = mailtoUri(contact.email) != null;
    final portalUrl = clientPortalUrl(
      contactLink: contact.link,
      clientHash: clientHash,
    );
    final hasPortal = portalUrl.isNotEmpty;
    return PartyContactRow(
      name: '${contact.firstName} ${contact.lastName}'.trim(),
      email: contact.email,
      phone: contact.phone,
      isPrimary: contact.isPrimary,
      phoneSubject: subject,
      clientId: clientId,
      logTarget: logTarget,
      pills: [
        // Labelled, where this used to be a bare red icon with a tooltip: an
        // unsubscribed contact is the answer to "why didn't they get it".
        if (contact.isLocked)
          PartyContactPill(label: context.tr('unsubscribed'), alert: true),
        // Its own key, not `cc_only`: that one is translated as "credit card
        // only" in the German, French and Dutch bundles (and is plain English
        // in every other), which on a contact row is simply wrong.
        if (contact.ccOnly)
          PartyContactPill(label: context.tr('contact_cc_only_label')),
      ],
      details: _details(context),
      actions: [
        PartyContactAction(
          icon: Icons.call_outlined,
          label: context.tr('call'),
          onTap: dialable
              ? () => callPhoneNumber(
                  context,
                  contact.phone,
                  subject: subject,
                  clientId: clientId,
                  logTarget: logTarget,
                )
              : null,
        ),
        PartyContactAction(
          icon: Icons.mail_outline,
          label: context.tr('email'),
          onTap: hasEmail ? () => composeEmail(context, contact.email) : null,
        ),
        PartyContactAction(
          icon: Icons.content_copy,
          // Named for the portal: the record's own menu has a "Copy Link" too,
          // and that one copies a link to this screen.
          label: '${context.tr('client_portal')}: ${context.tr('copy_link')}',
          onTap: hasPortal ? () => copyToClipboard(context, portalUrl) : null,
        ),
        PartyContactAction(
          icon: Icons.sms_outlined,
          label: context.tr('send_sms'),
          onTap: dialable
              ? () => messagePhoneNumber(context, contact.phone)
              : null,
        ),
        PartyContactAction(
          icon: Icons.open_in_new,
          label: context.tr('view_portal'),
          onTap: hasPortal
              ? () => launchClientPortal(context, portalUrl)
              : null,
        ),
      ],
    );
  }

  /// Read-only extras: the last portal login, and any contact custom fields
  /// the company has labelled. `Services` is touched only when there is one of
  /// these to format, so the row still builds under a stub in tests.
  List<String> _details(BuildContext context) {
    final lastLogin = contact.lastLogin;
    final values = _customValuesOf(contact);
    final hasCustom = company != null && values.any((v) => v.isNotEmpty);
    if (lastLogin == null && !hasCustom) return const [];
    final services = context.read<Services>();
    final formatter = services.formatterIfReady(
      services.auth.session.value?.currentCompanyId ?? '',
    );
    return [
      // The local calendar day, as the header does for created/updated.
      if (lastLogin != null && formatter != null)
        '${context.tr('last_login')}: '
            '${formatter.date(lastLogin.toLocal().toIso8601String().split('T').first)}',
      if (hasCustom)
        for (final r in customFieldDetailRows(
          company: company,
          prefix: 'contact',
          values: values,
          formatter: formatter,
          yes: context.tr('yes'),
          no: context.tr('no'),
        ))
          '${r.label}: ${r.value}',
    ];
  }
}

/// Who the confirmation prompt names when this contact is called. Falls back
/// through name → email → the client-level "blank contact" label, so the
/// dialog never asks the user to confirm calling nobody.
String _contactSubject(BuildContext context, Contact contact) {
  final name = ('${contact.firstName} ${contact.lastName}').trim();
  if (name.isNotEmpty) return name;
  if (contact.email.isNotEmpty) return contact.email;
  return context.tr('no_name_fallback');
}

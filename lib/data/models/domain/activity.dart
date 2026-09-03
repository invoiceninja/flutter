import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/activity_api_model.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/call_note.dart';

part 'activity.freezed.dart';

/// A resolved related-entity reference inside an activity sentence. [label]
/// is the display text; when [type] is non-null + [id] non-empty the token
/// renders as a tappable link to that record (via `goEntityRecord`). Amount
/// tokens (`payment_amount`, `adjustment`) and the acting `user` carry a
/// label only ([type] == null) — styled, not linked.
class ActivityRef {
  const ActivityRef({required this.label, this.type, this.id = ''});

  final String label;
  final EntityType? type;
  final String id;

  bool get isLink => type != null && id.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is ActivityRef &&
      other.label == label &&
      other.type == type &&
      other.id == id;

  @override
  int get hashCode => Object.hash(label, type, id);
}

/// Clean domain model for an activity / comment row. Read-only — the server
/// is authoritative; the client never enqueues an Activity-shaped mutation.
/// Comments are appended via the `addComment` outbox mutation kind which
/// targets `/api/v1/activities/notes`.
@freezed
abstract class Activity with _$Activity {
  const Activity._();

  const factory Activity({
    required String id,
    required int activityTypeId,
    required String notes,
    required DateTime createdAt,
    required String ip,
    // Related-entity references keyed by the template token name
    // (`user`, `client`, `invoice`, `contact`, `quote`, `payment`,
    // `payment_amount`, `expense`, `credit`, `task`, `vendor`,
    // `recurring_invoice`, `recurring_expense`, `purchase_order`,
    // `subscription`, `adjustment`). Only the keys the server populated
    // are present.
    @Default(<String, ActivityRef>{}) Map<String, ActivityRef> refs,
  }) = _Activity;

  bool get isComment => activityTypeId == kCommentActivityTypeId;

  /// A comment this app composed for a manually-logged phone call
  /// (invoiceninja/flutter#120).
  ///
  /// There is no wire field for a note subtype — a logged call and a typed
  /// comment are the same `activity_type_id = 141` row — so the only signal is
  /// the marker [composeCallNote] writes at the head of the text. That makes
  /// this a **display hint**: it drives the row's phone icon and the Calls lens
  /// on `/activity`, and nothing else may depend on it. See `call_note.dart`.
  bool get isCallNote => isComment && isCallNoteText(notes);

  /// Back-compat accessors for callers/tests that predate [refs].
  String? get userLabel => refs['user']?.label;
  String? get clientLabel => refs['client']?.label;
  String? get invoiceLabel => refs['invoice']?.label;

  factory Activity.fromApi(ActivityApi a) {
    final refs = <String, ActivityRef>{};
    void put(String token, ActivityLabelApi? l, EntityType? type) {
      if (l == null || l.label.isEmpty) return;
      refs[token] = ActivityRef(label: l.label, type: type, id: l.hashedId);
    }

    // Acting user + amount labels are non-linking (type == null).
    put('user', a.user, null);
    put('client', a.client, EntityType.client);
    put('invoice', a.invoice, EntityType.invoice);
    put('quote', a.quote, EntityType.quote);
    put('payment', a.payment, EntityType.payment);
    put('credit', a.credit, EntityType.credit);
    put('expense', a.expense, EntityType.expense);
    put('task', a.task, EntityType.task);
    put('vendor', a.vendor, EntityType.vendor);
    put('recurring_invoice', a.recurringInvoice, EntityType.recurringInvoice);
    put('recurring_expense', a.recurringExpense, EntityType.recurringExpense);
    put('purchase_order', a.purchaseOrder, EntityType.purchaseOrder);
    put('payment_amount', a.paymentAmount, null);
    put('adjustment', a.adjustment, null);
    // subscription has no dedicated detail route here — show as text.
    put('subscription', a.subscription, null);
    // Contact routes to its owning entity's detail screen.
    final contact = a.contact;
    if (contact != null && contact.label.isNotEmpty) {
      final isVendor = contact.contactEntity == 'vendors';
      refs['contact'] = ActivityRef(
        label: contact.label,
        type: isVendor ? EntityType.vendor : EntityType.client,
        id: contact.hashedId,
      );
    }

    return Activity(
      id: a.id,
      activityTypeId: a.activityTypeId,
      notes: a.notes,
      createdAt: epochSecondsToUtc(a.createdAt),
      ip: a.ip,
      refs: refs,
    );
  }
}

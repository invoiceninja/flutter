// Fixtures shared by the five billing-document record-screen tests and the
// tests of the shared pieces under `billing_shared/detail/`.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';

/// The client every client-facing fixture document is addressed to: one named
/// contact with an address, one with only a name, and the all-blank contact
/// the server seeds for every client.
Future<void> seedClient(Services services) =>
    services.clients.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: const ClientApi(
        id: 'c1',
        name: 'Acme Corporation',
        displayName: 'Acme Corporation',
        number: '0042',
        updatedAt: 1710000000,
        createdAt: 1700000000,
        contacts: [
          ContactApi(
            id: 'k1',
            firstName: 'Jane',
            lastName: 'Doe',
            email: 'jane@acme.example.com',
            isPrimary: true,
          ),
          ContactApi(id: 'k2', firstName: 'Sam', lastName: 'Lee'),
          // What `ClientContactRepository::save` writes: a single space.
          ContactApi(id: 'k3', email: ' '),
        ],
      ),
    );

Future<void> seedVendor(Services services) =>
    services.vendors.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: VendorApi.fromJson({
        'id': 'v1',
        'name': 'Northwind Paper Co.',
        'number': '0007',
        'updated_at': 1710000000,
        'created_at': 1700000000,
        'contacts': [
          {
            'id': 'vk1',
            'first_name': 'Olga',
            'last_name': 'Nordin',
            'email': 'olga@northwind.example.com',
            'is_primary': true,
          },
        ],
      }),
    );

/// The link the first contact's invitation carries.
const String kPortalLink = 'https://portal.example.com/client/invoice/key1';

/// A billing document as the server sends it — the fields the five share.
///
/// **Dates are far from today in both directions** (`2000-…` is long past,
/// `2999-…` is long ahead), so no clock, timezone or midnight can move a
/// document across its deadline.
Map<String, dynamic> docJson({
  String id = 'd1',
  String number = '0042',
  String status = '2',
  String amount = '3720.00',
  String balance = '3720.00',
  String paid = '0',
  String due = '2999-01-01',
  String date = '2000-01-01',
  String po = 'PO-7781',
  String privateNotes = 'Call Jane before the next phase.',
  String publicNotes = '<p>Thank you for your business.</p>',
  String terms = 'Payment is due within 30 days.',
  bool viewed = false,
  bool sent = true,
  bool deleted = false,
  int archivedAt = 0,
  int updatedAt = 1700000000,
}) => {
  'id': id,
  'client_id': 'c1',
  'number': number,
  'po_number': po,
  'status_id': status,
  'amount': amount,
  'balance': balance,
  'paid_to_date': paid,
  'date': date,
  'due_date': due,
  'is_deleted': deleted,
  'archived_at': archivedAt,
  'updated_at': updatedAt,
  'created_at': 1690000000,
  'private_notes': privateNotes,
  'public_notes': publicNotes,
  'terms': terms,
  'line_items': [
    {
      'product_key': 'Design',
      'notes': 'Brand refresh',
      'cost': 1200,
      'quantity': 1,
      'line_total': 1200,
    },
    {
      'product_key': 'Build',
      'notes': 'Marketing site',
      'cost': 105,
      'quantity': 24,
      'line_total': 2520,
    },
  ],
  'invitations': [
    {
      'id': 'inv1',
      'key': 'key1',
      'link': kPortalLink,
      'client_contact_id': 'k1',
      'sent_date': sent ? '2000-01-02 09:12:00' : '',
      'viewed_date': viewed ? '2000-01-03 15:50:31' : '',
    },
    {
      'id': 'inv2',
      'key': 'key2',
      'link': 'https://portal.example.com/client/invoice/key2',
      'client_contact_id': 'k2',
      'sent_date': sent ? '2000-01-02 09:12:00' : '',
    },
    // The server makes an invitation for the blank contact too.
    {'id': 'inv3', 'key': 'key3', 'client_contact_id': 'k3'},
  ],
};

/// What the app asked the server for one document, and what it says back.
class DocServer {
  DocServer(this.recordPath);

  /// `/api/v1/invoices/d1`.
  final String recordPath;

  /// The record a `GET` of [recordPath] returns — null leaves it unanswered,
  /// the way the offline fixture does.
  Map<String, dynamic>? record;

  /// Answer the activity feed with "nothing yet", so a Comments tab shows its
  /// empty state rather than the offline fixture's failed-to-load.
  bool emptyActivity = false;

  final List<Uri> requests = [];

  Iterable<Uri> get recordAsks => requests.where((u) => u.path == recordPath);

  http.Client get client => MockClient((request) async {
    final record = this.record;
    if (request.method == 'GET' &&
        request.url.path == recordPath &&
        record != null) {
      requests.add(request.url);
      return http.Response(
        jsonEncode({'data': record}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (emptyActivity && request.url.path == '/api/v1/activities/entity') {
      return http.Response(
        jsonEncode({'data': <Object>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    throw http.ClientException('offline (test fixture)');
  });
}

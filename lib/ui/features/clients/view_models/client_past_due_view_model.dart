import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/domain/clients/client_past_due.dart';

/// Feeds the client screen's past-due line: the client's locally cached unpaid
/// invoices, plus one narrowed fetch that establishes whether that set is
/// complete.
///
/// Owned by the screen and armed from its build ([kick]), like the activity
/// view model beside it. It does nothing at all for a client that owes
/// nothing — no subscription, no request — because there is no past-due
/// figure to show under a zero balance.
///
/// The arithmetic and every condition for trusting it live in `clientPastDue`;
/// this class only gathers its inputs.
class ClientPastDueViewModel extends ChangeNotifier {
  ClientPastDueViewModel({
    required this.invoices,
    required this.companyId,
    required this.clientId,
    this.debounce = const Duration(milliseconds: 50),
  });

  final InvoiceRepository invoices;
  final String companyId;

  /// The client's **server** id. The host builds this once the record has
  /// one, and rebuilds it if that id changes — never from a route's `tmp_` id.
  final String clientId;

  /// Only to coalesce a burst of kicks. The pause that keeps a user stepping
  /// through a list from fetching for every client they pass is the host's:
  /// it does not kick until its own re-check of the record has settled.
  final Duration debounce;

  StreamSubscription<List<Invoice>>? _sub;
  List<Invoice> _unpaid = const [];
  bool _fetchComplete = false;
  bool _lastFailed = false;

  /// The record state the last ask was made for. **Balance and `updatedAt`
  /// together**: the same balance can be made of different invoices (one
  /// paid, another raised for the same amount), and then a stale local row
  /// still sums correctly — the balance alone would call that answered.
  (Decimal, DateTime)? _askedFor;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  /// Call from build with the record as it is now. Safe to call every frame:
  /// it schedules a fetch only when the record has moved since the last one,
  /// and never notifies synchronously.
  ///
  /// [enabled] is the host's gate — the invoices module is on. A client that
  /// owes nothing, or is not on the server yet, is never fetched for.
  void kick(Client client, {required bool enabled}) {
    if (_disposed) return;
    if (!enabled ||
        client.id.startsWith('tmp_') ||
        client.balance <= Decimal.zero) {
      return;
    }
    _sub ??= invoices
        .watchUnpaidForClient(companyId: companyId, clientId: clientId)
        .listen((rows) {
          _unpaid = rows;
          if (!_disposed) notifyListeners();
        });
    final key = (client.balance, client.updatedAt);
    if (_askedFor == key) return;
    final moved = _askedFor != null;
    _askedFor = key;
    // Whatever is on the wire was asked about a record that has since moved;
    // its answer must not be taken as an answer about this one.
    _generation++;
    if (moved && _fetchComplete) {
      _fetchComplete = false;
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
    }
    _schedule();
  }

  /// The user refreshed the record: ask again now, keeping the current answer
  /// on screen until the new one lands.
  Future<void> refresh() async {
    if (_disposed || _askedFor == null) return;
    _timer?.cancel();
    await _fetch();
  }

  /// The device is back online. Asks again only if the last ask got no answer
  /// — it latched "asked for this record" before it failed, and nothing else
  /// would ever clear that while the record stays as it is.
  void retryIfUnanswered() {
    if (_disposed || !_lastFailed) return;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_fetch()));
  }

  Future<void> _fetch() async {
    final generation = ++_generation;
    final result = await invoices.ensureUnpaidForClientLoaded(
      companyId: companyId,
      clientId: clientId,
    );
    if (_disposed || generation != _generation) return;
    _lastFailed = result == UnpaidInvoicesFetch.failed;
    final complete = result == UnpaidInvoicesFetch.complete;
    if (complete == _fetchComplete) return;
    _fetchComplete = complete;
    notifyListeners();
  }

  /// The past-due part of [client]'s balance as of [today], or null when it
  /// is not known — see `clientPastDue` for exactly when that is.
  ClientPastDue? valueFor(Client client, {required Date today}) {
    if (client.balance <= Decimal.zero) return null;
    return clientPastDue(
      client: client,
      unpaid: _unpaid,
      fetchComplete: _fetchComplete,
      today: today,
    );
  }

  /// Whether any invoice [valueFor] counted is archived — the Invoices tab
  /// hides those by default, so a link from the figure has to ask for them.
  bool hasArchivedPastDue({required Date today}) =>
      _unpaid.any((i) => i.archivedAt != null && i.isPastDueOn(today));

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

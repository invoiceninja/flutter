import 'package:flutter/foundation.dart';

import 'package:admin/domain/phone/pending_call_log.dart';

/// Holds the one call awaiting a "log this?" offer.
///
/// One slot, not a queue: the offer is a convenience shown when the user comes
/// back from the dialer, and a backlog of them would be worse than none. A
/// second call before the first is answered replaces it — the newer call is the
/// one the user just made.
class PendingCallController extends ValueNotifier<PendingCallLog?> {
  PendingCallController() : super(null);

  void record(PendingCallLog call) => value = call;

  void clear() {
    if (value != null) value = null;
  }

  /// Returns the pending call and clears the slot, or null when there is none
  /// or it belongs to a company the user is no longer in.
  PendingCallLog? take({required String? activeCompanyId}) {
    final call = value;
    if (call == null) return null;
    value = null;
    if (activeCompanyId == null || call.companyId != activeCompanyId) {
      return null;
    }
    return call;
  }
}

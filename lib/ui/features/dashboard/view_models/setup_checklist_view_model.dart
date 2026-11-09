import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:admin/app/welcome_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/company_repository.dart'
    show kCompanyWireName;
import 'package:admin/domain/setup_checklist.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

/// The dashboard checklist's live facts, read from Drift
/// (docs/first-run-welcome.md). Every stream is opened once, here, never in
/// a `build` — a Drift stream re-subscribed per build is churn.
///
/// Remembers which items it last drew as done ([WelcomeController]'s
/// `doneShown`), so an item finished on another screen gets its tick
/// animated when the user comes back — [newlyDone] — exactly once.
class SetupChecklistViewModel extends ChangeNotifier {
  SetupChecklistViewModel({
    required AppDatabase db,
    required this.companyId,
    required ValueListenable<AuthSession?> session,
    required this.welcome,
    this.drain,
  }) : _db = db,
       _session = session {
    _session.addListener(_onSession);
    _subs = [
      db.invoiceDao
          .watchBadgeCount(companyId: companyId)
          .listen((n) => _set(() => _invoices = n)),
      db.invoiceDao
          .watchBadgeCount(companyId: companyId, modeId: 'draft')
          .listen((n) => _set(() => _drafts = n)),
      db.clientDao
          .watchBadgeCount(companyId: companyId, modeId: kBadgeModeTotal)
          .listen((n) => _set(() => _clients = n)),
      db.companyGatewayDao
          .watchActiveCount(companyId: companyId)
          .listen((n) => _set(() => _gateways = n)),
      db.outboxDao
          .watchLogoUploads(
            companyId: companyId,
            companyWireName: kCompanyWireName,
          )
          .listen(_onOutbox),
    ];
    _onSession();
  }

  final String companyId;
  final AppDatabase _db;
  final ValueListenable<AuthSession?> _session;

  /// Sends the outbox now — after a Retry.
  final Future<void> Function(String companyId)? drain;
  final WelcomeController welcome;
  late final List<StreamSubscription<Object?>> _subs;

  int? _invoices;
  int? _drafts;
  int? _clients;
  int? _gateways;
  bool _outboxRead = false;
  bool _hasLogo = false;
  LogoUploadState _logoUpload = LogoUploadState.none;
  bool _disposed = false;

  /// Ids done before this visit; null until the first full read.
  Set<String>? _shownBefore;

  /// Every stream has answered once — before that nothing is drawn, so a
  /// row never flickers from todo to done on open.
  bool get loaded =>
      _invoices != null &&
      _drafts != null &&
      _clients != null &&
      _gateways != null &&
      _outboxRead;

  SetupChecklistFacts get facts => SetupChecklistFacts(
    hasLogo: _hasLogo,
    logoUpload: _logoUpload,
    sentInvoice: (_invoices ?? 0) - (_drafts ?? 0) > 0,
    hasGateway: (_gateways ?? 0) > 0,
    hasClient: (_clients ?? 0) > 0,
  );

  List<SetupChecklistRow> get rows => setupChecklistRows(facts);

  /// The company has no invoice at all — the dashboard behind the card is
  /// all zeros, so it steps back.
  bool get hasNoInvoices => (_invoices ?? 1) == 0;

  /// Items that became done since the card was last drawn.
  Set<String> get newlyDone {
    final before = _shownBefore;
    if (before == null) return const {};
    return doneIds(rows).difference(before);
  }

  /// The card has drawn [rows]; remember them, so their ticks don't animate
  /// again next visit.
  void noteShown() {
    if (!loaded) return;
    final ids = doneIds(rows);
    final stored = welcome.checklistFor(companyId)?.doneShown ?? const {};
    if (!setEquals(ids, stored)) {
      unawaited(welcome.noteItemsShownDone(companyId, ids));
    }
  }

  void _onSession() {
    final company = _session.value?.companies
        .where((c) => c.id == companyId)
        .firstOrNull;
    final has = (company?.logoUrl ?? '').isNotEmpty;
    if (has != _hasLogo) _set(() => _hasLogo = has);
  }

  void _onOutbox(List<({int id, String state})> rows) {
    var state = LogoUploadState.none;
    int? dead;
    for (final r in rows) {
      if (r.state == 'dead') {
        state = LogoUploadState.failed;
        dead ??= r.id;
      } else {
        state = LogoUploadState.uploading;
        break;
      }
    }
    _deadLogoRow = state == LogoUploadState.failed ? dead : null;
    _set(() {
      _logoUpload = state;
      _outboxRead = true;
    });
  }

  /// The dead `upload_logo` row's id, for Retry.
  int? _deadLogoRow;

  /// Re-arm the logo upload that failed, the way the Outbox screen's Retry
  /// does, and send it.
  Future<bool> retryLogo() async {
    final id = _deadLogoRow;
    if (id == null) return false;
    final rearmed = await _db.outboxDao.retryDead(
      id: id,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    if (rearmed) unawaited(drain?.call(companyId));
    return rearmed;
  }

  void _set(VoidCallback change) {
    if (_disposed) return;
    final wasLoaded = loaded;
    change();
    if (!wasLoaded && loaded) {
      _shownBefore = welcome.checklistFor(companyId)?.doneShown ?? const {};
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSession);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}

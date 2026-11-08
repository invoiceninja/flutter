import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';

final _log = Logger('DocuNinjaSession');

/// The active company's standing with DocuNinja.
@immutable
class DocuNinjaState {
  const DocuNinjaState(this.access, {this.login, this.company});

  static const unavailable = DocuNinjaState(DocuNinjaAccess.unavailable);
  static const loading = DocuNinjaState(DocuNinjaAccess.loading);

  final DocuNinjaAccess access;

  /// The handshake's answer, when it gave one.
  final DnLogin? login;

  /// The DocuNinja company paired with the active Invoice Ninja company.
  final DnCompany? company;

  bool get isReady => access == DocuNinjaAccess.ready;

  /// Whether the user may [action] on [model] (DocuNinja's own permissions).
  bool can(String model, DnAction action) {
    final l = login;
    if (l == null) return false;
    return dnCan(l.companyUser, l.permissions, model, action);
  }
}

/// The DocuNinja handshake for the active company, held in memory only.
///
/// `POST /api/docuninja/login` answers per *user* with every DocuNinja company
/// they belong to; the one paired with the active Invoice Ninja company is
/// picked by `ninja_company_key`, as React does. Its token never touches disk
/// and is dropped when the session resets or the company changes
/// ([reset], wired in `Services.build` beside the calendar connection). A
/// generation counter discards an answer that lands after a reset, so a
/// late handshake can never hand company A's token to company B.
///
/// It is also [DocuNinjaClient]'s token source: a DocuNinja 401 re-runs the
/// handshake here once ([refreshToken]).
class DocuNinjaSession extends ValueNotifier<DocuNinjaState>
    implements DocuNinjaTokenSource {
  DocuNinjaSession({
    required DocuNinjaLoginApi loginApi,
    required ValueListenable<AuthSession?> auth,
    required Future<String?> Function(String companyId) companyKeyOf,
  }) : _loginApi = loginApi,
       _auth = auth,
       _companyKeyOf = companyKeyOf,
       super(DocuNinjaState.unavailable);

  final DocuNinjaLoginApi _loginApi;
  final ValueListenable<AuthSession?> _auth;
  final Future<String?> Function(String companyId) _companyKeyOf;

  /// Bumped after a document changes on the detail page (send, void,
  /// archive, clone, delete…), so the list it came from re-reads DocuNinja,
  /// as React refetches its documents query after every action.
  final ValueNotifier<int> documentsChanged = ValueNotifier(0);

  void markDocumentsChanged() => documentsChanged.value++;

  int _generation = 0;
  bool _loaded = false;
  Future<void>? _inFlight;

  @override
  String? get token => value.company?.token;

  /// Runs the handshake unless it already answered for this session;
  /// [force] runs it again (Reconnect, a 401). Concurrent calls share one
  /// request.
  Future<void> load({bool force = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (!force && _loaded) return Future.value();
    final generation = _generation;
    late final Future<void> run;
    run = _load().whenComplete(() {
      // A reset may have started a newer request; only clear our own.
      if (generation == _generation && identical(_inFlight, run)) {
        _inFlight = null;
      }
    });
    return _inFlight = run;
  }

  Future<void> _load() async {
    final generation = _generation;
    final auth = _auth.value;
    final companyId = auth?.currentCompany?.id;
    if (auth == null || companyId == null || !auth.isHosted) {
      _loaded = true;
      value = DocuNinjaState.unavailable;
      return;
    }
    // A first load shows "loading"; a forced one (Reconnect, a 401) keeps
    // the current screen and its token until the new answer lands.
    if (!_loaded) value = DocuNinjaState.loading;
    DnLoginOutcome outcome;
    DnLogin? login;
    String companyKey = '';
    try {
      // The pairing is by company key, so without one there is nothing to
      // ask: an empty key would read as "no company paired" and offer a
      // Set up that posts `/create` for a company that may be paired
      // already. React refuses the same way ("No company key").
      companyKey = await _companyKeyOf(companyId) ?? '';
      if (companyKey.isEmpty) {
        _log.warning('DocuNinja: the active company has no company key');
        outcome = DnLoginOutcome.failed;
      } else {
        login = await _loginApi.login();
        outcome = DnLoginOutcome.ok;
      }
    } on DocuNinjaRefused {
      outcome = DnLoginOutcome.refused;
    } on NetworkException {
      outcome = DnLoginOutcome.offline;
    } on Object catch (e, st) {
      _log.warning('DocuNinja handshake failed', e, st);
      outcome = DnLoginOutcome.failed;
    }
    // A reset (sign-out, company switch) while the handshake was out: this
    // answer belongs to a session that has ended.
    if (generation != _generation) return;
    final company = login?.companyFor(companyKey);
    _loaded = true;
    value = DocuNinjaState(
      resolveDocuNinjaAccess(
        isHosted: true,
        outcome: outcome,
        companyMatched: company != null,
        dnAdmin: login != null && dnIsAdmin(login.companyUser),
        dnPlan: login?.account.plan ?? '',
      ),
      login: login,
      company: company,
    );
  }

  @override
  Future<String?> refreshToken() async {
    await load(force: true);
    return token;
  }

  /// Forgets the handshake: on sign-out and on every company change.
  void reset() {
    _generation++;
    _loaded = false;
    _inFlight = null;
    value = DocuNinjaState.unavailable;
  }
}

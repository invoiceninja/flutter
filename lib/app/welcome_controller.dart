import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:admin/app/env.dart';
import 'package:admin/app/prompt_hold.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/welcome.dart';

/// The first-run experience's schedule — the owner of [DevicePrefKeys.welcome]
/// (docs/first-run-welcome.md).
///
/// Decided once per user per device, at an interactive sign-in
/// ([noteSignIn], wired by `main()` to `AuthRepository.onSigningIn`): a
/// restored session is never greeted, and [noteLaunch] marks the user an
/// existing install had signed in as seen. The shell's `WelcomeHost` opens the
/// Welcome while [autoOpens]; the dashboard's checklist reads the per-company
/// half of the record.
///
/// A device preference, so a sign-out keeps it; per user because the record
/// is keyed by [welcomeUserKey]. Built before the store loads, so it re-reads
/// on the store's notify, as `WhatsNewController` does.
class WelcomeController extends ChangeNotifier {
  WelcomeController({
    required DevicePrefsStore prefs,
    required String? Function() currentUserKey,
    this.onWelcomed,
    this.onSeen,
    DateTime Function()? now,
    this.isDemoBuild = Env.isDemoBuild,
    this.demoMode = Env.demoMode,
  }) : _prefs = prefs,
       _currentUserKey = currentUserKey,
       _now = now ?? DateTime.now {
    _sync();
    _prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;
  final String? Function() _currentUserKey;
  final DateTime Function() _now;
  final bool isDemoBuild;
  final bool demoMode;

  /// Tells the server this user has been welcomed (a `react_settings` patch),
  /// so another device does not greet them again. Best effort.
  final Future<void> Function()? onWelcomed;

  /// Runs when the Welcome is read — the What's New dialog is marked read
  /// with it, so the two never follow each other.
  final Future<void> Function()? onSeen;

  /// Launches that may give up without opening before the Welcome stops
  /// opening on its own. Counted in total, not per version: a pending Welcome
  /// holds the other prompts back, and must not do so for long.
  static const int maxAttempts = 3;

  /// How long after the Welcome opens the promo and review prompt stay away.
  static const Duration promptHold = kAutomaticPromptGap;

  /// Users the record remembers; the oldest beyond this are dropped.
  static const int maxUsers = 25;

  /// A Welcome still pending after this long is no longer a first run.
  static const Duration pendingExpiry = Duration(days: 30);

  WelcomeState get state => _state;
  WelcomeState _state = const WelcomeState();

  bool get _inert => !_prefs.loadSucceeded || isDemoBuild || demoMode;

  /// Set once the Welcome has opened on its own in this process.
  bool shownThisLaunch = false;

  /// Set once the Welcome stood down in this process (the user was busy, or
  /// arrived by a link). Process-wide, like [shownThisLaunch]: the shell —
  /// and the host in it — is rebuilt after an unlock or a re-sign-in, and a
  /// new host must not pop the Welcome up mid-session or spend another
  /// attempt in the same launch.
  bool stoodDownThisLaunch = false;

  /// `/setup` finished in this process. The shell's missing-name prompt
  /// stays away for the rest of the launch: a new account's first look at
  /// its dashboard is the checklist, not a dialog (docs/first-run-welcome.md).
  bool setupCompletedThisLaunch = false;

  /// The signed-in user's Welcome is still unread — pending, whether or not
  /// it may still open on its own.
  bool get currentPending => _current?.pending ?? false;

  WelcomeUser? get _current {
    final key = _currentUserKey();
    if (key == null) return null;
    return _state.users[key];
  }

  /// The kind recorded for the signed-in user, pending or not.
  WelcomeKind? get currentKind => _current?.kind;

  /// Whether the shell may open the Welcome on its own now.
  bool get autoOpens {
    final u = _current;
    if (u == null || !u.pending || u.kind == WelcomeKind.newAccount) {
      return false;
    }
    if (u.attempts >= maxAttempts) return false;
    return _now().difference(u.at) < pendingExpiry;
  }

  /// The list About and the command palette open: the signed-in user's kind,
  /// else Get started.
  WelcomeKind get onRequestKind {
    final k = currentKind;
    return k == WelcomeKind.fromOldApp
        ? WelcomeKind.fromOldApp
        : WelcomeKind.existingAccount;
  }

  /// A launch. On an install that ran an earlier build, the user it had
  /// signed in ([storedUserKey], read from the stored identity, which a 401
  /// or an idle lock keeps) is recorded as seen: someone already using this
  /// app is never greeted as new. Only `main()` calls it.
  Future<void> noteLaunch({
    required bool existingInstall,
    String? storedUserKey,
  }) async {
    if (_inert) return;
    if (!existingInstall || storedUserKey == null) return;
    if (_state.users.containsKey(storedUserKey)) return;
    await _save(
      _state.withUser(
        storedUserKey,
        WelcomeUser(status: WelcomeStatus.seen, at: _now()),
        maxUsers,
      ),
    );
  }

  /// An interactive sign-in. Decides once per user; a user the record knows
  /// is left alone.
  void noteSignIn(SignInFacts facts) {
    if (_inert || facts.userKey.isEmpty) return;
    if (_state.users.containsKey(facts.userKey)) return;
    final kind = decideWelcome(facts);
    final entry = WelcomeUser(
      status: kind == null ? WelcomeStatus.seen : WelcomeStatus.pending,
      kind: kind,
      at: _now(),
      companyCount: facts.companyCount,
    );
    _save(_state.withUser(facts.userKey, entry, maxUsers));
  }

  /// `/setup` finished for [companyId]. Arms that company's checklist; a
  /// pending Welcome that was really a new account's is settled here, since
  /// the wizard was their welcome. A long-standing user who named an old
  /// unnamed company keeps theirs.
  Future<void> noteSetupCompleted({
    required String? userKey,
    required String companyId,
  }) async {
    setupCompletedThisLaunch = true;
    if (_inert) return;
    final u = userKey == null ? null : _state.users[userKey];
    final isNew =
        u != null &&
        u.pending &&
        (u.kind == WelcomeKind.newAccount ||
            (u.kind == WelcomeKind.existingAccount && u.companyCount <= 1));
    var next = _state.withChecklist(
      companyId,
      (_state.checklists[companyId] ?? const ChecklistState()).copyWith(
        armedAt: _now(),
        fresh: isNew,
      ),
    );
    var welcomed = false;
    if (userKey != null && u != null && u.pending) {
      if (isNew) {
        next = next.withUser(
          userKey,
          u.copyWith(status: WelcomeStatus.seen, kind: WelcomeKind.newAccount),
          maxUsers,
        );
        welcomed = true;
      }
    }
    await _save(next);
    if (welcomed) await _tellServer();
  }

  /// The Welcome opened.
  Future<void> noteOpened() => _save(_state.copyWith(shownAt: _now()));

  /// A launch went by without the Welcome opening.
  Future<void> noteGaveUp() async {
    final key = _currentUserKey();
    final u = _current;
    if (key == null || u == null || !u.pending) return;
    await _save(
      _state.withUser(key, u.copyWith(attempts: u.attempts + 1), maxUsers),
    );
  }

  /// The user closed the Welcome, any way they chose to.
  Future<void> markSeen() async {
    final key = _currentUserKey();
    final u = _current;
    if (key != null && u != null && u.pending) {
      await _save(
        _state.withUser(key, u.copyWith(status: WelcomeStatus.seen), maxUsers),
      );
      await _tellServer();
    }
    await onSeen?.call();
  }

  Future<void> _tellServer() async {
    try {
      await onWelcomed?.call();
    } catch (_) {
      // Best effort: the device record already settles it here.
    }
  }

  /// Whether the promo or the review prompt must wait at [now].
  bool holdsBackPromptsAt(DateTime now) {
    if (autoOpens) return true;
    return promptHoldsBack(_state.shownAt, promptHold, now);
  }

  // ─── Checklist ────────────────────────────────────────────────────────

  ChecklistState? checklistFor(String companyId) =>
      _state.checklists[companyId];

  /// Whether the dashboard shows [companyId]'s checklist.
  bool showsChecklist(String companyId) {
    final c = _state.checklists[companyId];
    return c != null && c.armedAt != null && !c.hidden && c.completedAt == null;
  }

  Future<void> hideChecklist(String companyId) =>
      _updateChecklist(companyId, (c) => c.copyWith(hidden: true));

  /// Undo a hide, or bring back a hidden checklist from Getting started.
  Future<void> unhideChecklist(String companyId) =>
      _updateChecklist(companyId, (c) => c.copyWith(hidden: false));

  Future<void> noteChecklistCompleted(String companyId) =>
      _updateChecklist(companyId, (c) => c.copyWith(completedAt: _now()));

  /// The item ids the card last drew as done — an item done since then
  /// animates its tick when the dashboard is next seen.
  Future<void> noteItemsShownDone(String companyId, Set<String> ids) =>
      _updateChecklist(companyId, (c) => c.copyWith(doneShown: ids));

  Future<void> _updateChecklist(
    String companyId,
    ChecklistState Function(ChecklistState) update,
  ) async {
    if (_inert) return;
    final c = _state.checklists[companyId];
    if (c == null) return;
    final next = update(c);
    if (next == c) return;
    await _save(_state.withChecklist(companyId, next));
  }

  Future<void> _save(WelcomeState next) async {
    _state = next;
    notifyListeners();
    await _prefs.write(DevicePrefKeys.welcome, next.encode());
  }

  /// Re-read the store (its `load`, or a wipe — which keeps this key).
  void _sync() {
    final next = WelcomeState.decode(_prefs.read(DevicePrefKeys.welcome));
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _prefs.removeListener(_sync);
    super.dispose();
  }
}

enum WelcomeStatus { pending, seen }

@immutable
class WelcomeUser {
  const WelcomeUser({
    required this.status,
    required this.at,
    this.kind,
    this.attempts = 0,
    this.companyCount = 0,
  });

  final WelcomeStatus status;
  final WelcomeKind? kind;

  /// When the decision was made.
  final DateTime at;
  final int attempts;

  /// Companies the user had at sign-in.
  final int companyCount;

  bool get pending => status == WelcomeStatus.pending;

  WelcomeUser copyWith({
    WelcomeStatus? status,
    WelcomeKind? kind,
    int? attempts,
  }) => WelcomeUser(
    status: status ?? this.status,
    kind: kind ?? this.kind,
    at: at,
    attempts: attempts ?? this.attempts,
    companyCount: companyCount,
  );

  Map<String, dynamic> toJson() => {
    'status': status.name,
    if (kind != null) 'kind': kind!.wireName,
    'at': at.toUtc().millisecondsSinceEpoch,
    if (attempts > 0) 'attempts': attempts,
    if (companyCount > 0) 'companies': companyCount,
  };

  static WelcomeUser? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = raw['at'];
    if (at is! int) return null;
    final attempts = raw['attempts'];
    final companies = raw['companies'];
    return WelcomeUser(
      status: raw['status'] == WelcomeStatus.pending.name
          ? WelcomeStatus.pending
          : WelcomeStatus.seen,
      kind: WelcomeKind.fromWire(raw['kind']),
      at: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      attempts: attempts is int && attempts > 0 ? attempts : 0,
      companyCount: companies is int && companies > 0 ? companies : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WelcomeUser &&
      other.status == status &&
      other.kind == kind &&
      other.at == at &&
      other.attempts == attempts &&
      other.companyCount == companyCount;

  @override
  int get hashCode => Object.hash(status, kind, at, attempts, companyCount);
}

/// The dashboard setup checklist's state for one company.
@immutable
class ChecklistState {
  const ChecklistState({
    this.armedAt,
    this.fresh = false,
    this.hidden = false,
    this.completedAt,
    this.doneShown = const {},
  });

  final DateTime? armedAt;

  /// The company was created with the account just signed up — so "no
  /// invoices on this device" really means none, and the dashboard's zero
  /// figures may step back behind the checklist.
  final bool fresh;
  final bool hidden;
  final DateTime? completedAt;
  final Set<String> doneShown;

  ChecklistState copyWith({
    DateTime? armedAt,
    bool? fresh,
    bool? hidden,
    DateTime? completedAt,
    Set<String>? doneShown,
  }) => ChecklistState(
    armedAt: armedAt ?? this.armedAt,
    fresh: fresh ?? this.fresh,
    hidden: hidden ?? this.hidden,
    completedAt: completedAt ?? this.completedAt,
    doneShown: doneShown ?? this.doneShown,
  );

  Map<String, dynamic> toJson() => {
    if (armedAt != null) 'armedAt': armedAt!.toUtc().millisecondsSinceEpoch,
    if (fresh) 'fresh': true,
    if (hidden) 'hidden': true,
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().millisecondsSinceEpoch,
    if (doneShown.isNotEmpty) 'doneShown': (doneShown.toList()..sort()),
  };

  static ChecklistState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    DateTime? ms(Object? v) =>
        v is int ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true) : null;
    final done = raw['doneShown'];
    return ChecklistState(
      armedAt: ms(raw['armedAt']),
      fresh: raw['fresh'] == true,
      hidden: raw['hidden'] == true,
      completedAt: ms(raw['completedAt']),
      doneShown: done is List ? done.whereType<String>().toSet() : const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChecklistState &&
      other.armedAt == armedAt &&
      other.fresh == fresh &&
      other.hidden == hidden &&
      other.completedAt == completedAt &&
      setEquals(other.doneShown, doneShown);

  @override
  int get hashCode => Object.hash(
    armedAt,
    fresh,
    hidden,
    completedAt,
    Object.hashAllUnordered(doneShown),
  );
}

@immutable
class WelcomeState {
  const WelcomeState({
    this.shownAt,
    this.users = const {},
    this.checklists = const {},
  });

  /// When the Welcome last opened (any user) — the prompt hold reads it.
  final DateTime? shownAt;
  final Map<String, WelcomeUser> users;
  final Map<String, ChecklistState> checklists;

  WelcomeState copyWith({DateTime? shownAt}) => WelcomeState(
    shownAt: shownAt ?? this.shownAt,
    users: users,
    checklists: checklists,
  );

  /// [users] with [key] set, keeping at most [limit] — the oldest go.
  WelcomeState withUser(String key, WelcomeUser user, int limit) {
    final next = Map<String, WelcomeUser>.of(users)..[key] = user;
    if (next.length > limit) {
      final byAge = next.entries.toList()
        ..sort((a, b) => a.value.at.compareTo(b.value.at));
      for (final e in byAge.take(next.length - limit)) {
        if (e.key != key) next.remove(e.key);
      }
    }
    return WelcomeState(shownAt: shownAt, users: next, checklists: checklists);
  }

  WelcomeState withChecklist(String companyId, ChecklistState c) =>
      WelcomeState(
        shownAt: shownAt,
        users: users,
        checklists: Map<String, ChecklistState>.of(checklists)..[companyId] = c,
      );

  String encode() => jsonEncode({
    if (shownAt != null) 'shownAt': shownAt!.toUtc().millisecondsSinceEpoch,
    if (users.isNotEmpty)
      'users': {for (final e in users.entries) e.key: e.value.toJson()},
    if (checklists.isNotEmpty)
      'checklists': {
        for (final e in checklists.entries) e.key: e.value.toJson(),
      },
  });

  /// A missing or unreadable row is no record at all.
  static WelcomeState decode(String? raw) {
    if (raw == null) return const WelcomeState();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const WelcomeState();
      final shownAt = json['shownAt'];
      final rawUsers = json['users'];
      final rawLists = json['checklists'];
      final users = <String, WelcomeUser>{};
      if (rawUsers is Map) {
        for (final e in rawUsers.entries) {
          final u = WelcomeUser.fromJson(e.value);
          if (e.key is String && u != null) users[e.key as String] = u;
        }
      }
      final lists = <String, ChecklistState>{};
      if (rawLists is Map) {
        for (final e in rawLists.entries) {
          final c = ChecklistState.fromJson(e.value);
          if (e.key is String && c != null) lists[e.key as String] = c;
        }
      }
      return WelcomeState(
        shownAt: shownAt is int
            ? DateTime.fromMillisecondsSinceEpoch(shownAt, isUtc: true)
            : null,
        users: users,
        checklists: lists,
      );
    } on FormatException {
      return const WelcomeState();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WelcomeState &&
      other.shownAt == shownAt &&
      mapEquals(other.users, users) &&
      mapEquals(other.checklists, checklists);

  @override
  int get hashCode => Object.hash(
    shownAt,
    Object.hashAllUnordered(
      users.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      checklists.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

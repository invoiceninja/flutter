import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/entity_links.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/shell/widgets/switch_company_guarded.dart';

/// What to do with an incoming deep link, independent of where it came from.
///
/// Two sources feed [open]: the OS, via `AppDeepLinks` (`app_links`), and the
/// user, by pasting a link into the command palette — which is the only route
/// available on web and Linux, where the OS can't hand the app a link at all,
/// and the fallback everywhere a messenger renders `invoiceninja://…` as inert
/// text. Keeping the choreography here (rather than inside the platform
/// bridge) is what lets both share it.
///
/// Lives on `Services`, but the router only exists once `MaterialApp.router`
/// is built, so the app state calls [attach] afterwards. A link that arrives
/// before then — or before the first frame, when there is no `BuildContext`
/// yet — is held and replayed, not dropped.
class DeepLinkRouter {
  DeepLinkRouter({
    required ValueListenable<AuthSession?> session,
    required ValueListenable<ApiCredentials?> credentials,
    required ValueListenable<bool> requiresBiometricUnlock,
    required EntityRegistry registry,
    required ToastController toasts,
  }) : _session = session,
       _credentials = credentials,
       _locked = requiresBiometricUnlock,
       _registry = registry,
       _toasts = toasts;

  // Deliberately the narrow slice of AuthRepository this needs, not the repo
  // itself: the whole class is then exercisable with plain fakes.
  //
  // All three are *listenables*, and [credentials] in particular must not be
  // reduced to an `isAuthenticated()` predicate: `AuthRepository` assigns
  // `_session` BEFORE `_credentials` on both login (`_persistAndActivate`) and
  // `restore()`, so a gate that reads credentials while listening only to the
  // session wakes on the session edge, still sees `isAuthenticated == false`,
  // and drops the held link — then replays it minutes later off an unrelated
  // background refresh. `main.dart` merges `auth.credentials` first into the
  // router's own `refreshListenable` for exactly this reason.
  final ValueListenable<AuthSession?> _session;
  final ValueListenable<ApiCredentials?> _credentials;
  final ValueListenable<bool> _locked;
  final EntityRegistry _registry;
  final ToastController _toasts;
  final _log = Logger('DeepLinkRouter');

  void Function(String location)? _go;
  BuildContext? Function()? _contextOf;

  /// URIs currently queued on [_inFlight] or being handled.
  ///
  /// Every native plugin hands a cold-start link over **twice** — Android,
  /// iOS, macOS and Windows all replay the cached `initialLink` into the event
  /// stream on `onListen` *and* return it from `getInitialLink()`, and the
  /// bridge subscribes to both. A duplicate `go()` was harmless for the
  /// calendar return, but a record link can switch company, and running that
  /// twice means two unsaved-changes prompts and two pending-outbox prompts.
  ///
  /// Scoped to what is in flight rather than to history, deliberately: the
  /// command palette feeds the same [open], and there a repeat is an ordinary
  /// user action — follow a link, wander off, paste it again — which on web
  /// and Linux is the *only* way to follow one at all. A history-based guard
  /// turned that into a silent no-op for the rest of the session, and did the
  /// same to a link the user re-tried after cancelling one of its prompts.
  final _pending = <Uri>{};

  /// Serialises [open]. The [_pending] guard only catches an *identical*
  /// URI; two different links arriving while a company switch is mid-dialog
  /// would otherwise interleave two modal sequences.
  Future<void> _inFlight = Future.value();

  /// Bumped by [reset]. A link chained onto [_inFlight] behind another one is
  /// still queued when the session ends — [reset] can clear [_deferred] and
  /// [_pending], but it cannot cancel an already-scheduled `.then`. Without
  /// this the queued link runs *after* logout and, finding the gate shut,
  /// re-defers itself and re-arms the gate listener — surviving into the next
  /// account's session, which is exactly what [reset] exists to prevent.
  int _generation = 0;

  /// A link that arrived while the app was signed out or biometric-locked,
  /// waiting for the gate to clear. See [_gateIsOpen].
  Uri? _deferred;
  bool _listening = false;

  /// Wire navigation in once `MaterialApp.router` exists. [contextOf] supplies
  /// a `BuildContext` under the `MultiProvider` (the root navigator's), which
  /// the company-switch guards need for their dialogs.
  void attach({
    required void Function(String location) go,
    required BuildContext? Function() contextOf,
  }) {
    _go = go;
    _contextOf = contextOf;
    final pending = _deferred;
    if (pending != null) {
      _deferred = null;
      unawaited(open(pending));
    }
  }

  /// Handle one incoming link. Never throws — a malformed or unroutable link
  /// is reported to the user, not to the caller.
  Future<void> open(Uri uri) {
    // The calendar OAuth return keeps its query string (a single-use `handoff`
    // token) and bypasses the queue entirely: it is a machine-to-machine
    // handoff to a screen that self-routes, not a place the user asked to go.
    // Chaining it behind a record link would strand the token for as long as
    // that link's dialogs stayed open — before this class existed it had no
    // coupling to anything, and it keeps none.
    final calendar = parseCalendarCompleteLink(uri);
    if (calendar != null) {
      final go = _go;
      if (go == null) {
        _deferred = uri;
      } else {
        go(calendar);
      }
      return Future<void>.value();
    }
    if (!_pending.add(uri)) return _inFlight;
    final generation = _generation;
    return _inFlight = _inFlight
        .then((_) {
          // Dropped rather than deferred: this link belongs to the session
          // that ended. See [_generation].
          if (generation != _generation) return null;
          return _open(uri);
        })
        .catchError((Object e, StackTrace st) {
          _log.warning('deep link failed: $uri', e, st);
        })
        .whenComplete(() => _pending.remove(uri));
  }

  Future<void> _open(Uri uri) async {
    final go = _go;
    if (go == null) {
      _deferred = uri;
      return;
    }

    final target = parseAppDeepLink(uri, _registry);
    if (target == null) {
      _log.warning('unrecognised deep link: $uri');
      _toastKey('invalid_url', isError: true);
      return;
    }

    // Hold until signed in and unlocked. Acting now would run the
    // company-switch guards' dialogs over the lock screen — it is an ordinary
    // Scaffold, so nothing stops a `showDialog` landing on top of it — and
    // would switch the workspace behind a lock the user hasn't passed.
    if (!_gateIsOpen) {
      _deferred = uri;
      _listenForGate();
      return;
    }

    final session = _session.value;
    final companyId = target.companyId;
    final needsSwitch =
        session != null &&
        companyId != null &&
        companyId != session.currentCompanyId;

    if (needsSwitch) {
      // Only this branch needs a `BuildContext`, for the two guard dialogs.
      // Before the first frame the root navigator has none — retry once the
      // tree is up rather than dropping the link (or, worse, switching
      // company with the guards silently skipped).
      final context = _contextOf?.call();
      if (context == null) {
        _deferred = uri;
        WidgetsBinding.instance.addPostFrameCallback((_) => _replayDeferred());
        return;
      }
      final company = session.companies
          .where((c) => c.id == companyId)
          .firstOrNull;
      if (company == null) {
        // The link came from a different account (or a company this user was
        // since removed from). Checking up front matters: `switchCompany`
        // would otherwise burn a full healing `/refresh` before failing.
        _toastKey('record_not_found', isError: true);
        return;
      }
      final outcome = await switchCompanyGuarded(
        context,
        companyId,
        companyName: company.displayName,
      );
      // Cancelled at a guard, or failed and already reported.
      if (outcome != SwitchCompanyResult.ok) return;
      // A silent workspace swap is how the next record gets created in the
      // wrong company — say what happened.
      _toastKey(
        'switched_to_company',
        params: {'company': company.displayName},
        isError: false,
      );
    }

    // Straight to the record. Deliberately NOT `companySafeLocation`, which
    // strips `/clients/<id>` back to `/clients` — that is right for a company
    // switch the user initiated from the picker, and exactly wrong here. An
    // open dirty edit form still gets its prompt: the edit routes carry
    // `onExit: _confirmExitIfDirty`, which fires on this `go()`.
    go(target.path);
  }

  /// Signed in, session materialised, and past the biometric lock. Reads all
  /// three sources it listens to, so no assignment order can strand a link.
  bool get _gateIsOpen =>
      (_credentials.value?.isAuthenticated ?? false) &&
      _session.value != null &&
      !_locked.value;

  void _listenForGate() {
    if (_listening) return;
    _listening = true;
    _session.addListener(_onGateChanged);
    _credentials.addListener(_onGateChanged);
    _locked.addListener(_onGateChanged);
  }

  void _stopListeningForGate() {
    if (!_listening) return;
    _listening = false;
    _session.removeListener(_onGateChanged);
    _credentials.removeListener(_onGateChanged);
    _locked.removeListener(_onGateChanged);
  }

  void _onGateChanged() {
    if (!_gateIsOpen) return;
    _stopListeningForGate();
    _replayDeferred();
  }

  void _replayDeferred() {
    final pending = _deferred;
    if (pending == null) return;
    _deferred = null;
    unawaited(open(pending));
  }

  /// Toast a localized key straight onto the context-free [ToastController]
  /// (rather than `Notify`, which needs a context to find it).
  ///
  /// Skipped entirely — logged, not shown — when localization isn't reachable
  /// yet. CLAUDE.md's context-free-toast rule is that the message must be
  /// `tr()`-derived; rendering the raw snake_case key at the user would be
  /// worse than saying nothing, and the only window where this can happen is
  /// the sliver before the first frame.
  void _toastKey(
    String key, {
    Map<String, String>? params,
    required bool isError,
  }) {
    final context = _contextOf?.call();
    final loc = context == null ? null : Localization.of(context);
    if (loc == null) {
      _log.warning('deep link: no localization yet, dropping toast "$key"');
      return;
    }
    // `no_unsubstituted_placeholders_test` only matches literal `tr('k')` /
    // `lookup('k')` call forms, so a key routed through here is invisible to
    // it — the exact case CLAUDE.md § Localization says needs the invariant
    // asserted where the lookup actually happens. `switched_to_company`
    // carries `:company`; a future caller that forgets its params would ship a
    // raw token to the user instead of failing.
    //
    // Checked against the TEMPLATE, not the rendered string: a company legally
    // named "Acme :test" would otherwise trip this on the substituted output.
    assert(() {
      final template = loc.lookup(key);
      final unfilled = RegExp(r'(?<![A-Za-z0-9_/:]):([a-z][a-z0-9_]*)')
          .allMatches(template)
          .map((m) => m.group(1)!)
          .where((name) => !(params?.containsKey(name) ?? false));
      return unfilled.isEmpty;
    }(), 'deep-link toast "$key" has placeholders with no params passed.');
    final message = loc.lookup(key, params);
    if (isError) {
      _toasts.error(message);
    } else {
      _toasts.info(message);
    }
  }

  /// Drop any held link and stop waiting for the gate. Called on logout: a
  /// link captured for one account must not survive into the next one's
  /// session, where its company id is at best meaningless and at worst
  /// somebody else's.
  void reset() {
    _generation++;
    _deferred = null;
    _pending.clear();
    _stopListeningForGate();
  }

  void dispose() => reset();
}

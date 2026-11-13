import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import 'package:admin/data/services/web_oauth_types.dart';

/// The web half of the [web_oauth] seam.
///
/// Both providers open a window, and a browser lets a page do that only while
/// the tap that asked for it is still "active" (about a second in Safari). So
/// nothing here awaits anything between the tap and the window: the scripts
/// come with the boot page, MSAL is initialised when the login screen mounts
/// ([prepareWebOAuth]), and Google's token client is created synchronously on
/// the tap. A tap that finds a script not ready yet fails as
/// [WebOAuthFailure.notLoaded] rather than waiting for it.
///
/// Each returns the provider's access token, which is what the server's
/// `oauth_login` takes from these two (Google's `harvestUser`, Microsoft's
/// Graph `/me`), or null when the user closed the window.
final _log = Logger('WebOAuth');

/// All three need a secure page: MSAL hashes with `crypto.subtle`, which an
/// http page doesn't have, and Google and Apple refuse such an origin.
bool webOAuthSecureContext() {
  try {
    return web.window.isSecureContext;
  } catch (_) {
    return false;
  }
}

/// Apple JS (`AppleID`) has loaded.
bool webAppleLoaded() => globalContext.has('AppleID');

// ── Google (Google Identity Services' token client) ─────────────────────

JSObject? _googleClient;
String _googleClientId = '';
Completer<String?>? _googlePending;

/// `google.accounts.oauth2`, or null before the GIS script has loaded.
JSObject? get _gisOAuth2 {
  final google = globalContext.getProperty<JSAny?>('google'.toJS);
  if (!google.isA<JSObject>()) return null;
  final accounts = (google! as JSObject).getProperty<JSAny?>('accounts'.toJS);
  if (!accounts.isA<JSObject>()) return null;
  final oauth2 = (accounts! as JSObject).getProperty<JSAny?>('oauth2'.toJS);
  return oauth2.isA<JSObject>() ? oauth2! as JSObject : null;
}

Future<String?> webGoogleAccessToken(String clientId) {
  final oauth2 = _gisOAuth2;
  if (oauth2 == null) {
    return Future.error(const WebOAuthException(WebOAuthFailure.notLoaded));
  }
  try {
    if (_googleClient == null || _googleClientId != clientId) {
      final config = JSObject()
        ..setProperty('client_id'.toJS, clientId.toJS)
        // What `harvestUser` reads from Google's userinfo endpoint.
        ..setProperty('scope'.toJS, 'openid email profile'.toJS)
        ..setProperty('callback'.toJS, _onGoogleToken.toJS)
        ..setProperty('error_callback'.toJS, _onGoogleError.toJS);
      _googleClient = oauth2.callMethod<JSObject>(
        'initTokenClient'.toJS,
        config,
      );
      _googleClientId = clientId;
    }
    // A second tap while a window is open: the first can't be told apart from
    // the second, so it ends quietly and the newest one wins.
    final previous = _googlePending;
    if (previous != null && !previous.isCompleted) previous.complete(null);
    final pending = _googlePending = Completer<String?>();
    final options = JSObject()
      // Always let the user pick the account: one browser often holds
      // several, and the wrong one is "User not found".
      ..setProperty('prompt'.toJS, 'select_account'.toJS);
    _googleClient!.callMethod<JSAny?>('requestAccessToken'.toJS, options);
    return pending.future;
  } on Object catch (e) {
    return Future.error(WebOAuthException(WebOAuthFailure.failed, '$e'));
  }
}

void _onGoogleToken(JSAny? response) {
  final pending = _googlePending;
  _googlePending = null;
  if (pending == null || pending.isCompleted) return;
  final map = _asMap(response);
  final error = '${map['error'] ?? ''}';
  if (error.isNotEmpty) {
    // The user declined the consent screen.
    if (error == 'access_denied') {
      pending.complete(null);
    } else {
      pending.completeError(
        WebOAuthException(
          WebOAuthFailure.failed,
          '$error ${map['error_description'] ?? ''}'.trim(),
        ),
      );
    }
    return;
  }
  final token = '${map['access_token'] ?? ''}';
  pending.complete(token.isEmpty ? null : token);
}

void _onGoogleError(JSAny? error) {
  final pending = _googlePending;
  _googlePending = null;
  if (pending == null || pending.isCompleted) return;
  final map = _asMap(error);
  switch ('${map['type'] ?? ''}') {
    case 'popup_closed':
      pending.complete(null);
    case 'popup_failed_to_open':
      pending.completeError(const WebOAuthException(WebOAuthFailure.blocked));
    default:
      pending.completeError(
        WebOAuthException(
          WebOAuthFailure.failed,
          '${map['type'] ?? ''} ${map['message'] ?? ''}'.trim(),
        ),
      );
  }
}

// ── Microsoft (MSAL, vendored in web/msal/) ──────────────────────────────

/// The initialised `PublicClientApplication`, once [prepareWebOAuth] has
/// finished with it, for [_microsoftKey].
JSObject? _msal;
String _microsoftKey = '';
Future<void>? _msalStarting;

/// Why MSAL can't start for [_microsoftKey], once that is certain.
String? _msalFailure;

/// Starts whatever the next tap will need, so the tap itself can open its
/// window straight away. Safe to call on every login-screen mount; never
/// throws.
void prepareWebOAuth({
  String googleClientId = '',
  String microsoftClientId = '',
  String microsoftRedirectUri = '',
}) {
  if (microsoftClientId.isEmpty) return;
  final key = '$microsoftClientId|$microsoftRedirectUri';
  if (_microsoftKey == key &&
      (_msal != null || _msalStarting != null || _msalFailure != null)) {
    return;
  }
  _microsoftKey = key;
  _msal = null;
  _msalFailure = null;
  final starting = _msalStarting = _startMsal(
    microsoftClientId,
    microsoftRedirectUri,
    key,
  );
  starting.whenComplete(() {
    if (identical(_msalStarting, starting)) _msalStarting = null;
  }).ignore();
}

Future<void> _startMsal(String clientId, String redirectUri, String key) async {
  // The script is loaded `async` by the boot page, so on a fast first paint
  // it can still be on its way.
  JSObject? namespace;
  for (var i = 0; i < 100; i++) {
    final msal = globalContext.getProperty<JSAny?>('msal'.toJS);
    if (msal.isA<JSObject>()) {
      namespace = msal! as JSObject;
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_microsoftKey != key) return;
  }
  if (namespace == null) {
    _log.warning('MSAL did not load; Microsoft sign-in is unavailable');
    if (_microsoftKey == key) _msalFailure = 'MSAL did not load';
    return;
  }
  try {
    final auth = JSObject()
      ..setProperty('clientId'.toJS, clientId.toJS)
      // A page MSAL can read the answer from as soon as it lands (it polls the
      // window, same origin); registered as an SPA redirect URI in Azure.
      ..setProperty('redirectUri'.toJS, redirectUri.toJS);
    final config = JSObject()..setProperty('auth'.toJS, auth);
    final constructor = namespace.getProperty<JSFunction>(
      'PublicClientApplication'.toJS,
    );
    final app = constructor.callAsConstructor<JSObject>(config);
    await app.callMethod<JSPromise<JSAny?>>('initialize'.toJS).toDart;
    if (_microsoftKey != key) return;
    // MSAL keeps "a sign-in window is open" in sessionStorage. A page that was
    // reloaded while one was open would otherwise refuse every later window
    // in this tab with `interaction_in_progress`; none can be open yet.
    try {
      web.window.sessionStorage.removeItem('msal.interaction.status');
    } catch (_) {}
    _msal = app;
  } on Object catch (e) {
    _log.warning('MSAL failed to initialise: $e');
    if (_microsoftKey == key) _msalFailure = '$e';
  }
}

Future<String?> webMicrosoftAccessToken({
  required String clientId,
  required String redirectUri,
}) {
  final app = _msal;
  final failure = _msalFailure;
  if (failure != null && _microsoftKey == '$clientId|$redirectUri') {
    return Future.error(
      WebOAuthException(WebOAuthFailure.unavailable, failure),
    );
  }
  if (app == null || _microsoftKey != '$clientId|$redirectUri') {
    // Not ready: start it (if this is the first ask) for the next tap.
    prepareWebOAuth(
      microsoftClientId: clientId,
      microsoftRedirectUri: redirectUri,
    );
    return Future.error(const WebOAuthException(WebOAuthFailure.notLoaded));
  }
  final completer = Completer<String?>();
  try {
    final request = JSObject()
      ..setProperty('scopes'.toJS, ['user.read'.toJS].toJS)
      ..setProperty('prompt'.toJS, 'select_account'.toJS);
    final promise = app.callMethod<JSPromise<JSAny?>>(
      'loginPopup'.toJS,
      request,
    );
    // Both callbacks complete whatever they are handed (see
    // `web_passkeys_web.dart`): a throw here would spin for ever.
    promise.callMethod<JSAny?>(
      'then'.toJS,
      ((JSAny? result) {
        final token = '${_asMap(result)['accessToken'] ?? ''}';
        completer.complete(token.isEmpty ? null : token);
      }).toJS,
      ((JSAny? error) {
        try {
          final outcome = _microsoftFailure(error);
          if (outcome == null) {
            completer.complete(null);
          } else {
            completer.completeError(outcome);
          }
        } on Object catch (e) {
          completer.completeError(
            WebOAuthException(WebOAuthFailure.failed, '$e'),
          );
        }
      }).toJS,
    );
  } on Object catch (e) {
    return Future.error(WebOAuthException(WebOAuthFailure.failed, '$e'));
  }
  return completer.future;
}

/// MSAL's error, or null for the outcomes that are the user's choice.
WebOAuthException? _microsoftFailure(JSAny? error) {
  final map = _asMap(error);
  final code = '${map['errorCode'] ?? ''}';
  switch (code) {
    // The window was closed, or another one is still open in this tab (a
    // stale flag from a reload is cleared when MSAL starts).
    case 'user_cancelled' || 'interaction_in_progress':
      return null;
    case 'popup_window_error' || 'empty_window_error':
      return const WebOAuthException(WebOAuthFailure.blocked);
  }
  // AADSTS65004: the user declined consent.
  final message = '${map['errorMessage'] ?? map['message'] ?? ''}';
  if (message.contains('AADSTS65004')) return null;
  return WebOAuthException(WebOAuthFailure.failed, '$code $message'.trim());
}

/// A plain JS object's own string-ish fields, or empty for anything else.
/// `dartify` can't be trusted with an Error instance (its fields are not
/// enumerable), so the few we read are taken by name.
Map<String, Object?> _asMap(JSAny? value) {
  if (!value.isA<JSObject>()) return const {};
  final object = value! as JSObject;
  final out = <String, Object?>{};
  for (final key in const [
    'access_token',
    'accessToken',
    'error',
    'error_description',
    'errorCode',
    'errorMessage',
    'message',
    'type',
  ]) {
    final v = object.getProperty<JSAny?>(key.toJS);
    if (v.isA<JSString>()) out[key] = (v! as JSString).toDart;
  }
  return out;
}

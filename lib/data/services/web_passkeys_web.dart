import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:admin/data/services/passkey_codec.dart';
import 'package:admin/data/services/passkey_failure.dart';
import 'package:web/web.dart' as web;

/// The web half of the [web_passkeys] seam: `navigator.credentials.get` /
/// `.create` with the server's WebAuthn JSON, the same conversions React's
/// `src/common/helpers/passkeys.ts` does. No third-party script: Corbado's web
/// plugin needs its bundle.js loaded before Flutter, or it closes the page.
///
/// The browser itself enforces that the RP ID is this page's host or a parent
/// of it, and rejects anything else with a SecurityError.
Future<bool> webPasskeysAvailable() async {
  try {
    return web.window.isSecureContext &&
        globalContext.has('PublicKeyCredential') &&
        web.window.navigator.has('credentials');
  } on Object catch (_) {
    return false;
  }
}

/// Whether the browser says it supports WebAuthn Related Origin Requests
/// (`PublicKeyCredential.getClientCapabilities().relatedOrigins`): a page on
/// one host running a ceremony for a relying party on another that lists it
/// in its `/.well-known/webauthn`. Chrome and Edge report it from 133; a
/// browser that doesn't report it reads as false, so the passkey button stays
/// hidden there (docs/passkeys.md § Related origins). Never throws.
Future<bool> webPasskeysRelatedOrigins() async {
  try {
    final pkc = globalContext.getProperty<JSAny?>('PublicKeyCredential'.toJS);
    if (!pkc.isA<JSObject>()) return false;
    final constructor = pkc! as JSObject;
    if (!constructor.has('getClientCapabilities')) return false;
    final capabilities = await constructor
        .callMethod<JSPromise<JSAny?>>('getClientCapabilities'.toJS)
        .toDart;
    if (!capabilities.isA<JSObject>()) return false;
    final related = (capabilities! as JSObject).getProperty<JSAny?>(
      'relatedOrigins'.toJS,
    );
    return related.isA<JSBoolean>() && (related! as JSBoolean).toDart;
  } on Object catch (_) {
    return false;
  }
}

Future<Map<String, dynamic>> webPasskeyGet(
  Map<String, dynamic> publicKey,
) async {
  final options = _publicKeyJs(publicKey, listKey: 'allowCredentials');
  final credential = await _call('get', options);
  final response = credential.getProperty<JSObject>('response'.toJS);
  final userHandle = response.getProperty<JSAny?>('userHandle'.toJS);
  return {
    'id': credential.getProperty<JSString>('id'.toJS).toDart,
    'rawId': _b64(credential.getProperty<JSArrayBuffer>('rawId'.toJS)),
    'type': 'public-key',
    'response': {
      'clientDataJSON': _b64(response.getProperty('clientDataJSON'.toJS)),
      'authenticatorData': _b64(response.getProperty('authenticatorData'.toJS)),
      'signature': _b64(response.getProperty('signature'.toJS)),
      if (userHandle != null) 'userHandle': _b64(userHandle as JSArrayBuffer),
    },
  };
}

Future<Map<String, dynamic>> webPasskeyCreate(
  Map<String, dynamic> publicKey,
) async {
  final options = _publicKeyJs(publicKey, listKey: 'excludeCredentials');
  final user = options.getProperty<JSObject?>('user'.toJS);
  final userId = publicKey['user'] is Map ? publicKey['user']['id'] : null;
  if (user != null && userId is String) {
    user.setProperty('id'.toJS, _bytes(userId));
  }
  final credential = await _call('create', options);
  final response = credential.getProperty<JSObject>('response'.toJS);
  final transports = response.has('getTransports')
      ? response.callMethod<JSArray<JSString>>('getTransports'.toJS).toDart
      : const <JSString>[];
  return {
    'id': credential.getProperty<JSString>('id'.toJS).toDart,
    'rawId': _b64(credential.getProperty<JSArrayBuffer>('rawId'.toJS)),
    'type': 'public-key',
    'response': {
      'clientDataJSON': _b64(response.getProperty('clientDataJSON'.toJS)),
      'attestationObject': _b64(response.getProperty('attestationObject'.toJS)),
      if (transports.isNotEmpty)
        'transports': [for (final t in transports) t.toDart],
    },
  };
}

/// A JS copy of [publicKey] with the base64url fields as the bytes the API
/// takes: `challenge`, and each credential `id` in [listKey].
JSObject _publicKeyJs(
  Map<String, dynamic> publicKey, {
  required String listKey,
}) {
  final js = publicKey.jsify()! as JSObject;
  final challenge = publicKey['challenge'];
  if (challenge is String) js.setProperty('challenge'.toJS, _bytes(challenge));
  final list = publicKey[listKey];
  if (list is List) {
    final jsList = js.getProperty<JSArray<JSObject>>(listKey.toJS).toDart;
    for (var i = 0; i < list.length && i < jsList.length; i++) {
      final id = list[i] is Map ? list[i]['id'] : null;
      if (id is String) jsList[i].setProperty('id'.toJS, _bytes(id));
    }
  }
  return js;
}

/// `navigator.credentials[method]({publicKey})`, with a rejection turned into
/// a [PasskeyException] inside the promise chain, where the error is
/// still typed as a JS value.
Future<JSObject> _call(String method, JSObject publicKey) {
  final completer = Completer<JSObject>();
  final JSPromise<JSAny?> promise;
  try {
    final options = JSObject()..setProperty('publicKey'.toJS, publicKey);
    promise = web.window.navigator.credentials.callMethod<JSPromise<JSAny?>>(
      method.toJS,
      options,
    );
  } on Object catch (e) {
    return Future.error(PasskeyException(PasskeyFailure.failed, '$e'));
  }
  // Both callbacks complete the completer whatever they are handed: under
  // dart2js a cast of a non-object throws, and a throw here would leave the
  // sign-in spinning for ever (a password-manager extension may replace
  // `navigator.credentials` and reject with anything).
  promise.callMethod<JSAny?>(
    'then'.toJS,
    ((JSAny? credential) {
      if (credential.isA<JSObject>()) {
        completer.complete(credential! as JSObject);
      } else {
        completer.completeError(
          const PasskeyException(PasskeyFailure.cancelled),
        );
      }
    }).toJS,
    ((JSAny? error) {
      try {
        completer.completeError(_failure(error));
      } on Object catch (e) {
        completer.completeError(PasskeyException(PasskeyFailure.failed, '$e'));
      }
    }).toJS,
  );
  return completer.future;
}

/// A DOMException's name, mapped the way the browser uses them for WebAuthn.
PasskeyException _failure(JSAny? error) {
  String? name;
  String? message;
  if (error.isA<JSObject>()) {
    final object = error! as JSObject;
    final rawName = object.getProperty<JSAny?>('name'.toJS);
    final rawMessage = object.getProperty<JSAny?>('message'.toJS);
    name = rawName.isA<JSString>() ? (rawName! as JSString).toDart : null;
    message = rawMessage.isA<JSString>()
        ? (rawMessage! as JSString).toDart
        : null;
  }
  final failure = switch (name) {
    // Cancelled, timed out, or (by design, to avoid leaking which accounts
    // exist) no matching credential: the browser does not tell them apart.
    'NotAllowedError' || 'AbortError' => PasskeyFailure.cancelled,
    'InvalidStateError' => PasskeyFailure.alreadyRegistered,
    'SecurityError' => PasskeyFailure.notAssociated,
    'NotSupportedError' => PasskeyFailure.unsupported,
    _ => PasskeyFailure.failed,
  };
  return PasskeyException(failure, message ?? name);
}

JSUint8Array _bytes(String base64Url) => decodeBase64Url(base64Url).toJS;

String _b64(JSAny? buffer) =>
    encodeBase64Url(Uint8List.view((buffer! as JSArrayBuffer).toDart));

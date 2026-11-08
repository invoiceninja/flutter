import 'dart:convert';
import 'dart:typed_data';

/// WebAuthn's binary fields travel as unpadded base64url (RFC 4648 §5) in
/// both directions; the server's decoder accepts either padding, its encoder
/// (lbuchs/webauthn) omits it.
Uint8List decodeBase64Url(String value) =>
    base64Url.decode(base64Url.normalize(value));

String encodeBase64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

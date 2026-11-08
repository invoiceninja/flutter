/// The field builder embedded in a web view: React's own builder page in the
/// hosted web app, opened in embed mode (`?embed=1`), and the messages it and
/// the app exchange. The React side is `src/common/helpers/embed.ts` in
/// invoiceninja/ui. docs/docuninja.md § The field builder runs embedded where
/// a web view can.
library;

import 'dart:convert';

import 'package:admin/domain/docuninja/docuninja_create.dart';

/// The message format both sides speak; React's `EMBED_PROTOCOL_VERSION`.
/// A page that reports another version is not driven, and the builder opens
/// in the browser instead.
const kDnEmbedProtocolVersion = 1;

/// Whether the app embeds the builder at all. Off until the React embed
/// mode is live on the hosted web app (a page without it never answers, and
/// the screen falls back to the browser after a wait); a build can turn it
/// on with `--dart-define=DOCUNINJA_EMBED=true`.
const kDnEmbeddedBuilder = bool.fromEnvironment('DOCUNINJA_EMBED');

/// React's builder page in embed mode ([dnWebAppBuilderUri]).
Uri dnEmbedBuilderUri({
  required String documentId,
  required String companyId,
  bool template = false,
  bool fromTemplate = false,
}) => dnWebAppBuilderUri(
  id: documentId,
  companyId: companyId,
  template: template,
  fromTemplate: fromTemplate,
  embed: true,
);

/// Whether the web view may show [uri]: only the web app's own origin. Any
/// other page (a help link, a payment page) opens in the browser instead,
/// and nothing from another origin is ever handed the token.
bool dnEmbedAllowed(Uri uri) {
  final app = Uri.parse(kDnHostedWebAppUrl);
  return uri.scheme == app.scheme &&
      uri.host == app.host &&
      uri.port == app.port;
}

/// One message from the embedded page: `{v, type, payload}`.
class DnEmbedMessage {
  const DnEmbedMessage(this.version, this.type, this.payload, [this.nonce]);

  final int version;
  final String type;
  final Map<String, dynamic> payload;

  /// The host's secret echoed back (every message after `init`).
  final String? nonce;

  /// Null for anything that is not a well-formed message.
  static DnEmbedMessage? parse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final type = json['type'];
      final v = json['v'];
      if (type is! String || v is! int) return null;
      final payload = json['payload'];
      final nonce = json['nonce'];
      return DnEmbedMessage(
        v,
        type,
        payload is Map ? Map<String, dynamic>.from(payload) : const {},
        nonce is String ? nonce : null,
      );
    } on FormatException {
      return null;
    }
  }
}

/// The script that hands the page its token and the host's [nonce], once it
/// reported `ready`. Both are JSON-encoded, never spliced in as text, and
/// the script itself checks the document's origin: the main frame could
/// have moved between the host's own check and the script running.
String dnEmbedInitScript(String token, String nonce) {
  final config = jsonEncode({
    'v': kDnEmbedProtocolVersion,
    'token': token,
    'nonce': nonce,
  });
  final origin = jsonEncode(Uri.parse(kDnHostedWebAppUrl).origin);
  return 'if (window.location.origin === $origin && window.InvoiceNinjaEmbed '
      '&& window.InvoiceNinjaEmbed.init) { '
      'window.InvoiceNinjaEmbed.init($config); }';
}

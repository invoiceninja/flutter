import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/repositories/token_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/company_switched_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';

TextStyle _monoValueStyle(BuildContext context) => TextStyle(
  fontFamily: kMonoFontFamily,
  fontSize: 13,
  color: context.inTheme.ink,
);

/// The Token row on Edit Token: the saved token's secret, hidden until asked
/// for. Drift only ever holds the masked form, so Show and Copy fetch the
/// real value on demand ([fetchSecret] — `TokenRepository.fetchSecret`), and
/// it lives in this widget's state only: leaving the screen forgets it.
///
/// Copy does not reveal — a token can be copied while someone is looking at
/// the screen. Both buttons share one request and the result is cached, so
/// Show then Copy (or a double tap) costs one fetch.
///
/// Rendered as an [InputDecorator] so it carries the same floating label and
/// outline as the Name field above it — not a `TextField`, because nothing
/// here is editable.
class TokenSecretField extends StatefulWidget {
  const TokenSecretField({
    required this.hint,
    required this.fetchSecret,
    super.key,
  });

  /// Shown while the secret is hidden — `Token.obscuredHint`.
  final String hint;

  /// Resolves the full secret; null when the server didn't return one.
  final Future<String?> Function() fetchSecret;

  @override
  State<TokenSecretField> createState() => _TokenSecretFieldState();
}

class _TokenSecretFieldState extends State<TokenSecretField> {
  String? _secret;
  Future<String?>? _inFlight;
  bool _revealed = false;

  bool get _loading => _inFlight != null;

  Future<String?> _obtain() {
    final cached = _secret;
    if (cached != null) return Future.value(cached);
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _fetch();
    // A block body: the arrow form would hand `setState` the Future.
    setState(() {
      _inFlight = future;
    });
    return future;
  }

  Future<String?> _fetch() async {
    try {
      final secret = await widget.fetchSecret();
      if (mounted) setState(() => _secret = secret);
      return secret;
    } finally {
      if (mounted) {
        setState(() {
          _inFlight = null;
        });
      }
    }
  }

  /// [_obtain] with every failure turned into a toast — a tap handler drops
  /// its future, so nothing may escape. [retry] re-runs the action that
  /// failed.
  Future<String?> _guarded(Future<void> Function() retry) async {
    try {
      final secret = await _obtain();
      if (secret == null && mounted) {
        Notify.error(context, context.tr('could_not_load_label'));
      }
      return secret;
    } on TokenNotSyncedException {
      if (mounted) Notify.warning(context, context.tr('token_not_synced'));
    } on CompanySwitchedException {
      // Benign: the screen is being torn down for the other company.
    } catch (e) {
      if (mounted) {
        Notify.error(
          context,
          context.tr('could_not_load_label'),
          error: e,
          // A 403 / 400 fails the same way every time — no Retry for those.
          retryOp: isTransientError(e) ? retry : null,
        );
      }
    }
    return null;
  }

  /// Idempotent, unlike the button's toggle: a stale Retry tapped after a
  /// later Show succeeded must not hide the token again.
  Future<void> _reveal() async {
    final secret = await _guarded(_reveal);
    if (secret == null || !mounted) return;
    setState(() => _revealed = true);
  }

  void _hide() => setState(() => _revealed = false);

  Future<void> _copy() async {
    final secret = await _guarded(_copy);
    if (secret == null || !mounted) return;
    // `label:` keeps the secret itself out of the "Copied … " toast.
    await copyToClipboard(context, secret, label: context.tr('token'));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final secret = _secret;
    final revealed = _revealed && secret != null;
    final style = _monoValueStyle(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: context.tr('token'),
        // Nothing editable inside, so the decorator is never "empty" or
        // focused and the label would sit on the value without this.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.tr(revealed ? 'hide' : 'show'),
              onPressed: _loading ? null : (revealed ? _hide : _reveal),
              // The spinner takes the eye's place rather than its own slot,
              // so the row doesn't shift while the fetch runs.
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      revealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
            ),
            IconButton(
              tooltip: context.tr('copy_token'),
              onPressed: _loading ? null : _copy,
              icon: const Icon(Icons.content_copy, size: 18),
            ),
          ],
        ),
      ),
      child: revealed
          ? SelectableText(secret, style: style)
          : Semantics(
              label: '${context.tr('token')}, ${context.tr('hidden')}',
              excludeSemantics: true,
              child: Text(
                widget.hint,
                style: style.copyWith(color: tokens.ink2),
              ),
            ),
    );
  }
}

/// The Endpoint row under the token: the server the token authenticates
/// against, which an integration needs alongside the token itself. React shows
/// it only on hosted; here self-hosted gets it too — their own URL is the one
/// they are least likely to have to hand.
class TokenEndpointField extends StatelessWidget {
  const TokenEndpointField({required this.url, super.key});

  /// Already cleaned — `cleanApiUrl(session.baseUrl)`.
  final String url;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: context.tr('endpoint'),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: IconButton(
          tooltip: context.tr('copy'),
          onPressed: () => copyToClipboard(context, url),
          icon: const Icon(Icons.content_copy, size: 18),
        ),
      ),
      child: SelectableText(url, style: _monoValueStyle(context)),
    );
  }
}

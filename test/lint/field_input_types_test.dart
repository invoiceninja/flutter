import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: every text input declares the keyboard its data actually needs.
///
/// Three failure modes, all of which only ever show up on a device — a soft
/// keyboard is invisible to `flutter test`, so nothing else in the suite can
/// see any of them:
///
///  * **A `signed:` that the field's own formatter contradicts.** The iOS
///    engine checks `signed` *before* `decimal`
///    (`FlutterTextInputPlugin.mm` `ToUIKeyboardType`), so `signed: true`
///    swaps the large `UIKeyboardTypeDecimalPad` for the cramped
///    `UIKeyboardTypeNumbersAndPunctuation` in exchange for a minus key. If
///    an `inputFormatters` entry then strips `-`, that trade buys nothing and
///    every user of the field pays for it — which is exactly what the
///    recurring price-increase dialog shipped with for a day.
///
///    *Which* money fields deserve `signed:` is a product judgement (a
///    negative line item is a discount row; a negative fee cap is nothing),
///    so it is not machine-checkable and lives in CLAUDE.md § Forms — Input
///    types. The contradiction above is checkable, and is checked.
///  * **A wrong keyboard on a typed field.** A phone box on the alphabetic
///    keyboard, a mailbox with no `@`, a URL with no `/`.
///  * **`textInputAction` on a multi-line field.** `TextField` derives
///    `newline` from `maxLines`; overriding it with `.next` (or `.done`)
///    makes Return move focus instead of inserting a newline, so a
///    multi-line box silently becomes single-line on touch. The account
///    cancellation feedback field shipped like that.
///
/// The rule keys off the field's own label / `apiKey` token, so it only ever
/// fires on a field whose semantics are named in the source. A genuine
/// exception can carry `// lint: allow-input-type <reason>` on the offending
/// line or the line above; **no call site needs one today**, because the key
/// sets below are deliberately narrow rather than because anything is
/// suppressed.
///
/// That narrowness is load-bearing, and two fields say why. A `duration` box
/// takes `1h 30m` and `1:30`, so it needs letters and must not be handed a
/// number pad. The log-call `contact` slot holds `"<name> · <number>"`
/// (`lib/ui/core/dialogs/log_call_sheet.dart`, which documents it), so it is
/// not a phone field even though its picker tooltip is `phone_numbers` —
/// adding that key to `_phone` would make a name untypeable. Membership is
/// also **exact**, never substring: `email_from_name` is a name and
/// `email_style_custom` is an HTML body, and both would be wrongly demanded
/// an email keyboard by a `contains` test.
void main() {
  group('detector', () {
    test('reads the label token out of a multi-line constructor', () {
      final calls = findFieldCalls('''
        EntityEditField(
          label: context.tr('phone'),
          initial: x,
          onChanged: y,
        ),
      ''');
      expect(calls, hasLength(1));
      expect(calls.single.keys, contains('phone'));
      expect(calls.single.keyboardType, isNull);
    });

    test('reads apiKey and labelKey as well as tr()', () {
      expect(
        findFieldCalls("OverridableTextField(apiKey: 'website')").single.keys,
        contains('website'),
      );
      expect(
        findFieldCalls("SettingsTextField(labelKey: 'return_url')").single.keys,
        contains('return_url'),
      );
    });

    test('captures the declared keyboardType including its arguments', () {
      final c = findFieldCalls('''
        TextField(
          decoration: InputDecoration(labelText: context.tr('amount')),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        )
      ''').single;
      expect(c.keyboardType, contains('numberWithOptions'));
      expect(c.keyboardType, contains('signed: true'));
    });

    test('nested parens do not truncate the body', () {
      final c = findFieldCalls('''
        TextField(
          decoration: InputDecoration(labelText: tr('email')),
          keyboardType: TextInputType.emailAddress,
        )
      ''').single;
      expect(c.keys, contains('email'));
      expect(c.keyboardType, 'TextInputType.emailAddress');
    });

    test('detects a multi-line field and its textInputAction', () {
      final c = findFieldCalls('''
        TextField(
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.next,
        )
      ''').single;
      expect(c.isMultiline, isTrue);
      expect(c.textInputAction, 'TextInputAction.next');
    });

    test('maxLines: 1 is not multiline', () {
      expect(
        findFieldCalls('TextField(maxLines: 1)').single.isMultiline,
        isFalse,
      );
    });

    test('a non-literal maxLines is not treated as multiline', () {
      // The shared widgets pass `maxLines: widget.maxLines` and derive the
      // action themselves; source alone cannot say what that value is.
      final c = findFieldCalls('''
        TextField(
          maxLines: widget.maxLines,
          textInputAction: isSingleLine
              ? TextInputAction.done
              : TextInputAction.newline,
        )
      ''').single;
      expect(c.isMultiline, isFalse);
      expect(c.textInputAction, isNull, reason: 'a ternary is not a literal');
    });

    test('comments cannot masquerade as declarations', () {
      final c = findFieldCalls('''
        TextField(
          minLines: 2,
          maxLines: 4,
          // No textInputAction: a multi-line field must keep Return.
        )
      ''').single;
      expect(c.isMultiline, isTrue);
      expect(c.textInputAction, isNull);
    });

    test('a numeric range is not mistaken for an admitted minus', () {
      // `[0-9.,]` literally contains `-`, so a bare contains() check made the
      // signed-vs-formatter rule pass on every field in the app.
      expect(_admitsMinus('[0-9.,]'), isFalse);
      expect(_admitsMinus('[0-9.,-]'), isTrue);
      expect(_admitsMinus('[-0-9]'), isTrue);
      expect(_admitsMinus(r'[0-9\-]'), isTrue);
      expect(_admitsMinus('[a-zA-Z]'), isFalse);
    });

    test('a comment marker inside a string literal survives', () {
      expect(
        stripComments("var a = 'http://x'; // gone").trim(),
        "var a = 'http://x';",
      );
    });
  });

  test('every semantically-named field declares the right keyboard', () {
    final offenders = <String>[];
    var scanned = 0;

    for (final file in _dartFiles()) {
      final source = file.readAsStringSync();
      final lines = source.split('\n');
      scanned += lines.length;
      for (final call in findFieldCalls(source)) {
        final line = source.substring(0, call.offset).split('\n').length;
        if (_allowed(lines, line)) continue;
        final want = _expectedFor(call.keys);
        if (want == null) continue;
        final got = call.keyboardType;
        if (got != null && got.contains(want.needle)) continue;
        offenders.add(
          '${file.path}:$line:  ${call.keys.join(", ")} '
          '→ wants ${want.needle}, has ${got ?? "no keyboardType"}',
        );
      }
    }

    expect(
      scanned,
      greaterThan(10000),
      reason:
          'Only $scanned lines scanned — the walk is probably broken, so an '
          'empty offender list means nothing.',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'A field whose label names its data type must declare the matching '
          'keyboard, or the value is awkward-to-impossible to type on touch. '
          'Add the keyboardType, or `// lint: allow-input-type <reason>` if '
          'the label is misleading (a "contact" slot that holds a name, a '
          '"duration" that takes "1h 30m"). Found:\n  ${offenders.join('\n  ')}',
    );
  });

  test('no multi-line field overrides its newline action', () {
    final offenders = <String>[];

    for (final file in _dartFiles()) {
      final source = file.readAsStringSync();
      final lines = source.split('\n');
      for (final call in findFieldCalls(source)) {
        if (!call.isMultiline) continue;
        final action = call.textInputAction;
        if (action == null || action.contains('newline')) continue;
        final line = source.substring(0, call.offset).split('\n').length;
        if (_allowed(lines, line)) continue;
        offenders.add('${file.path}:$line:  $action on a multi-line field');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'TextField derives `TextInputAction.newline` from maxLines. Setting '
          'any other action makes Return move focus / submit instead of '
          'inserting a newline, so the box silently stops being multi-line on '
          'touch (invoiceninja/flutter, danger_zone_screen feedback field). '
          'Delete the textInputAction. Found:\n  ${offenders.join('\n  ')}',
    );
  });

  test('a signed numeric field is not undone by its own formatter', () {
    final offenders = <String>[];

    for (final file in _dartFiles()) {
      final source = file.readAsStringSync();
      final lines = source.split('\n');
      for (final call in findFieldCalls(source)) {
        if (!(call.keyboardType?.contains('signed: true') ?? false)) continue;
        // Only `allow` narrows the alphabet; `deny` of something unrelated
        // does not, and a formatter list we can't read is not evidence.
        final allow = _allowPattern.firstMatch(call.body);
        if (allow == null || _admitsMinus(allow.group(1)!)) continue;
        final line = source.substring(0, call.offset).split('\n').length;
        if (_allowed(lines, line)) continue;
        offenders.add('${file.path}:$line:  allows ${allow.group(1)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'This field asks for a minus key and then filters the minus out. '
          'Either drop `signed: true` (and keep the larger iOS decimal pad) '
          'or widen the formatter to admit `-`. '
          'Found:\n  ${offenders.join('\n  ')}',
    );
  });

  // No `// lint: allow-input-type` escape here, unlike the two rules above:
  // there is no correct reason to put a postal code on a number pad, so an
  // opt-out could only ever be used to reintroduce the bug.
  test('postal-code fields never declare a numeric keyboard', () {
    final offenders = <String>[];

    for (final file in _dartFiles()) {
      final source = file.readAsStringSync();
      for (final call in findFieldCalls(source)) {
        if (!call.keys.any((k) => k.contains('postal_code') || k == 'zip')) {
          continue;
        }
        final got = call.keyboardType;
        if (got == null || !got.contains('number')) continue;
        final line = source.substring(0, call.offset).split('\n').length;
        offenders.add('${file.path}:$line:  $got');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'US ZIPs are numeric but UK / CA / NL / PL postal codes are not, so '
          'a numeric keypad makes them untypeable. Use the default text '
          'keyboard with TextCapitalization.characters. '
          'Found:\n  ${offenders.join('\n  ')}',
    );
  });
}

// ─── the scanner ──────────────────────────────────────────────────────────

/// One text-input constructor call found in a Dart source file.
class FieldCall {
  FieldCall({
    required this.offset,
    required this.body,
    required this.keys,
    required this.keyboardType,
    required this.textInputAction,
    required this.isMultiline,
  });

  /// Character offset of the constructor name in the source.
  final int offset;

  /// The constructor's argument list, comments already blanked.
  final String body;

  /// Label / `labelKey` / `apiKey` tokens found in the call body.
  final Set<String> keys;

  /// The declared `keyboardType:` argument, verbatim, or null.
  final String? keyboardType;

  /// The declared `textInputAction:` argument, verbatim, or null.
  final String? textInputAction;

  /// `maxLines` or `minLines` present and not `1`.
  final bool isMultiline;
}

const _fieldNames = [
  'TextField',
  'TextFormField',
  'EntityEditField',
  'OverridableTextField',
  'SettingsTextField',
];

final _callPattern = RegExp('\\b(${_fieldNames.join('|')})\\s*\\(');
final _trKey = RegExp(r"""tr\(\s*'([a-z0-9_]+)'""");
final _labelKey = RegExp(r"""label(?:Key|Text)?:\s*'([a-z0-9_]+)'""");
final _apiKey = RegExp(r"""apiKey:\s*'([a-z0-9_]+)'""");
final _keyboard = RegExp(r'keyboardType:\s*(?:const\s+)?([A-Za-z0-9_.]+)');
final _action = RegExp(r'textInputAction:\s*(TextInputAction\.[A-Za-z0-9_]+)');
final _allowPattern = RegExp(
  r'FilteringTextInputFormatter\.allow\(\s*RegExp\(\s*r?'
  "'"
  r'([^'
  "'"
  r']*)',
);
final _lines = RegExp(r'\b(?:max|min)Lines:\s*([0-9]+)\b');

/// Extracts every text-input constructor call from [source] by walking
/// balanced parentheses — a flat regex cannot span a multi-line argument
/// list without swallowing the next widget.
List<FieldCall> findFieldCalls(String rawSource) {
  // Comments are blanked (not deleted) so every offset still maps to the
  // original line. Without this, prose like `// No textInputAction: a
  // multi-line field must…` is read as a declared action.
  final source = stripComments(rawSource);
  final out = <FieldCall>[];
  var pos = 0;
  for (final m in _callPattern.allMatches(source)) {
    if (m.start < pos) continue; // nested inside a call already captured
    final open = m.end - 1;
    var depth = 0;
    var i = open;
    for (; i < source.length; i++) {
      if (source[i] == '(') {
        depth++;
      } else if (source[i] == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    if (depth != 0) continue; // unbalanced — bail rather than guess
    final body = source.substring(open + 1, i);
    final keys = <String>{
      for (final k in _trKey.allMatches(body)) k.group(1)!,
      for (final k in _labelKey.allMatches(body)) k.group(1)!,
      for (final k in _apiKey.allMatches(body)) k.group(1)!,
    };

    // `keyboardType:` verbatim, including any argument list.
    String? keyboard;
    final km = _keyboard.firstMatch(body);
    if (km != null) {
      keyboard = km.group(1)!;
      final after = km.end;
      if (after < body.length && body[after] == '(') {
        var d = 0;
        var j = after;
        for (; j < body.length; j++) {
          if (body[j] == '(') {
            d++;
          } else if (body[j] == ')') {
            d--;
            if (d == 0) break;
          }
        }
        keyboard += body
            .substring(after, j + 1)
            .replaceAll(RegExp(r'\s+'), ' ');
      }
    }

    // Only a numeric literal counts. `maxLines: widget.maxLines` (the shared
    // widgets) is unknowable from source, and those derive the action anyway.
    var multiline = false;
    for (final lm in _lines.allMatches(body)) {
      if (int.parse(lm.group(1)!) > 1) multiline = true;
    }

    out.add(
      FieldCall(
        offset: m.start,
        body: body,
        keys: keys,
        keyboardType: keyboard,
        textInputAction: _action.firstMatch(body)?.group(1),
        isMultiline: multiline,
      ),
    );
    pos = i;
  }
  return out;
}

/// Replaces `//` and `/* */` comment bodies with spaces, preserving length
/// and newlines so character offsets and line numbers stay valid. String
/// literals are left alone, so a `'//'` inside one is not mistaken for a
/// comment.
///
/// Known limitation: triple-quoted strings are read as three single-quoted
/// ones, so a `//` inside a `'''…'''` block would blank the rest of that
/// line. Harmless today — `lib/` has exactly three triple-quoted strings,
/// all regex literals in `design_code_field.dart` and
/// `legacy_html_markdown.dart`, none containing `//` or a field constructor.
/// Widen the state machine if that changes.
String stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (c == '/' && i + 1 < source.length) {
      if (source[i + 1] == '/') {
        while (i < source.length && source[i] != '\n') {
          out.write(' ');
          i++;
        }
        continue;
      }
      if (source[i + 1] == '*') {
        while (i < source.length &&
            !(source[i] == '*' &&
                i + 1 < source.length &&
                source[i + 1] == '/')) {
          out.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
        // The closing `*/` itself.
        for (var k = 0; k < 2 && i < source.length; k++, i++) {
          out.write(' ');
        }
        continue;
      }
    }
    if (c == "'" || c == '"') {
      final quote = c;
      out.write(c);
      i++;
      while (i < source.length) {
        if (source[i] == r'\' && i + 1 < source.length) {
          out.write(source[i]);
          out.write(source[i + 1]);
          i += 2;
          continue;
        }
        out.write(source[i]);
        final done = source[i] == quote || source[i] == '\n';
        i++;
        if (done) break;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

// ─── the rule table ───────────────────────────────────────────────────────

typedef _Want = ({String needle});

const _phone = {'phone', 'work_phone', 'telephone'};
const _email = {
  'email',
  'custom_sending_email',
  'from_email',
  'reply_to_email',
  'bcc_email',
  'cc_email',
  'signer_email',
  'ses_from_address',
  'expense_mailbox',
  // NOT `inbound_mailbox_whitelist` / `_blacklist`: en.json calls both a
  // "Comma separated list of emails", and the iOS email keyboard puts `@`
  // and `.` on the primary plane but moves `,` off it. Which keyboard wins
  // for a list is a judgement call (more `@`s than commas, so they carry
  // `emailAddress` today) — not something to freeze as an invariant.
  'e_invoice_forward_email',
  'e_expense_forward_email',
};
const _url = {
  'website',
  'domain',
  'mailgun_domain',
  'host',
  'local_domain',
  'webhook_url',
  'return_url',
  'target_url',
  'matomo_url',
  'domain_url',
  'subdomain',
  'image_url',
  'product_image',
  'server_url',
};

_Want? _expectedFor(Set<String> keys) {
  if (keys.any(_phone.contains)) return (needle: 'TextInputType.phone');
  if (keys.any(_email.contains)) return (needle: 'TextInputType.emailAddress');
  if (keys.any(_url.contains)) return (needle: 'TextInputType.url');
  return null;
}

/// Whether a character-class body would let a `-` through.
///
/// A bare `contains('-')` is wrong and silently disables the rule it guards:
/// every numeric class in the app is written `[0-9…]`, whose literal
/// characters include the `-` of the **range**. Strip `X-Y` triplets first;
/// what survives is a `-` the class actually admits (leading, trailing or
/// escaped).
bool _admitsMinus(String characterClass) => characterClass
    .replaceAll(RegExp(r'[A-Za-z0-9]-[A-Za-z0-9]'), '')
    .contains('-');

const String _kAllowMarker = 'lint: allow-input-type';

/// The marker may sit on the offending line or the line above it.
bool _allowed(List<String> lines, int oneBasedLine) {
  final i = oneBasedLine - 1;
  for (var j = i; j >= 0 && j >= i - 1; j--) {
    if (j < lines.length && lines[j].contains(_kAllowMarker)) return true;
  }
  return false;
}

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.endsWith('.g.dart'))
    .where((f) => !f.path.endsWith('.freezed.dart'));

import 'dart:convert';
import 'dart:io';

import 'package:admin/data/services/terminal_server_error.dart';
import 'package:admin/ui/features/terminal/terminal_error_text.dart';
import 'package:admin/ui/features/terminal/view_models/collect_card_payment_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_services/store_services.dart';

/// Every way taking a card can fail has words the person at the counter can
/// act on (docs/in-person-payments.md): each SDK code and each server code
/// maps to a key, and every key exists in English.
void main() {
  final strings = <String, String>{
    ...(jsonDecode(File('assets/i18n/en.json').readAsStringSync()) as Map)
        .cast<String, String>(),
    ...(jsonDecode(File('assets/i18n/_app_pending.json').readAsStringSync())
            as Map)
        .map((k, v) => MapEntry(k as String, '$v')),
  };

  String tr(String key, [Map<String, String>? params]) {
    var text = strings[key];
    expect(text, isNotNull, reason: 'missing string $key');
    for (final e in (params ?? const <String, String>{}).entries) {
      text = text!.replaceAll(':${e.key}', e.value);
    }
    expect(text, isNot(contains(RegExp(r':[a-z]'))), reason: key);
    return text!;
  }

  test('every SDK code has words', () {
    for (final code in TerminalErrorCode.values) {
      expect(
        terminalProblemText(CollectProblem(code: code), tr),
        isNotEmpty,
        reason: '$code',
      );
    }
  });

  test('every server code the app knows has words', () {
    for (final code in TerminalServerError.known) {
      expect(
        terminalProblemText(
          CollectProblem(
            serverCode: code,
            message: code == TerminalServerError.fieldErrors ? 'Too much' : '',
            data: const {'user': 'Sam', 'age': 90},
          ),
          tr,
        ),
        isNotEmpty,
        reason: code,
      );
    }
  });

  test('an open collection names who and how long ago', () {
    expect(
      terminalProblemText(
        const CollectProblem(
          serverCode: TerminalServerError.collectionOpen,
          data: {'user': 'Sam', 'age': 90},
        ),
        tr,
      ),
      'A card payment started 2 min ago by Sam is still open.',
    );
  });

  test('an unknown server code falls back to the server message, never a raw '
      'SDK one', () {
    expect(
      terminalProblemText(
        const CollectProblem(serverCode: 'new_thing', message: 'Server says'),
        tr,
      ),
      'Server says',
    );
    expect(
      terminalProblemText(
        const CollectProblem(
          code: TerminalErrorCode.declined,
          message: 'card_declined: insufficient_funds',
        ),
        tr,
      ),
      isNot(contains('insufficient_funds')),
    );
  });
}

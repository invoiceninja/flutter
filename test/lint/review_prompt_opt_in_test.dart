import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: only `lib/main.dart` lets the review prompt ask on its own.
///
/// `Services.build(reviewPromptAutoAsk:)` defaults to `false` because every
/// test, the integration harnesses and the screenshot runner build the same
/// graph. With the flag on, a harness that happens to land a payment could
/// get Play's or StoreKit's sheet — or our card — over the screen it is
/// driving. Nothing in the type system notices a stray `true`, so this does
/// (docs/review-prompt.md).
void main() {
  test('only lib/main.dart passes reviewPromptAutoAsk: true', () {
    final pattern = RegExp(r'reviewPromptAutoAsk:\s*true');
    final offenders = <String>[];
    var mainDoes = false;

    for (final root in const ['lib', 'test', 'integration_test']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        // This file names the pattern in its own source.
        if (path.endsWith('test/lint/review_prompt_opt_in_test.dart')) {
          continue;
        }
        if (!pattern.hasMatch(entity.readAsStringSync())) continue;
        if (path == 'lib/main.dart') {
          mainDoes = true;
        } else {
          offenders.add(path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Only the app entry point may let the review prompt ask unasked; '
          'tests and harnesses must leave `reviewPromptAutoAsk` at its '
          'default (false). Found: ${offenders.join(', ')}',
    );
    expect(
      mainDoes,
      isTrue,
      reason:
          'lib/main.dart no longer arms the review prompt, so the shipped app '
          'never asks for a review (docs/review-prompt.md).',
    );
  });
}

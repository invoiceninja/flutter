import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/clients/vat_check.dart';

/// The check queues a VIES lookup and polls a cache for the verdict
/// (`ClientController::checkVat` / `vatStatus`).
void main() {
  Future<VatCheckResult?> run(
    List<String?> answers, {
    bool startFails = false,
    bool Function()? cancelled,
    Duration deadline = const Duration(seconds: 5),
  }) {
    var i = 0;
    return runVatCheck(
      start: () async {
        if (startFails) throw Exception('no route');
      },
      // Repeats the last answer once the list runs out.
      status: () async => answers[i < answers.length - 1 ? i++ : i],
      cancelled: cancelled,
      interval: Duration.zero,
      deadline: deadline,
    );
  }

  test('polls through pending to the verdict', () async {
    expect(await run(['pending', 'pending', 'valid']), VatCheckResult.valid);
    expect(await run(['invalid']), VatCheckResult.invalid);
    expect(await run(['pending', 'unavailable']), VatCheckResult.unavailable);
  });

  // The server forgets a verdict on its first read, so a null is not a
  // reason to keep waiting.
  test('a status with nothing behind it is an error', () async {
    expect(await run(['pending', null]), VatCheckResult.error);
    expect(await run(['something new']), VatCheckResult.error);
  });

  test('a failed start is an error, without polling', () async {
    expect(await run(['valid'], startFails: true), VatCheckResult.error);
  });

  test('gives up at the deadline', () async {
    expect(
      await run(['pending'], deadline: const Duration(milliseconds: 30)),
      VatCheckResult.timeout,
    );
  });

  test('a cancelled check reports nothing', () async {
    expect(await run(['valid'], cancelled: () => true), isNull);
  });

  test('the EU list is the server observer\'s 27', () {
    expect(kVatCheckCountryIds, hasLength(27));
    expect(kVatCheckCountryIds, contains('276')); // Germany
    expect(kVatCheckCountryIds, isNot(contains('826'))); // United Kingdom
  });
}

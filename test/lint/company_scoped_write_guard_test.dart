import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every repo that writes server rows must be bound to the company whose token
/// fetched them.
///
/// `ApiClient` resolves credentials from a live notifier at request-build time
/// and takes no company parameter, while a paged fetch takes `companyId` as an
/// argument and stamps the rows it writes with it. Nothing ties the two
/// together except `BaseEntityRepository.companyStillActive`, so a company
/// switch landing mid-fetch files one workspace's records under another's id.
///
/// This is a lint rather than care because the trap is a NAMING near-miss: the
/// five billing repos each carry the comment "same gate as
/// `ensurePageLoadedTemplate`" while never calling it, so a grep for the
/// template's name suggests they are covered when they are not. A previous pass
/// read exactly that and left all five — plus tags — unguarded.
void main() {
  test('every repo writing via upsertAllPreservingDirty is company-guarded', () {
    final offenders = <String>[];
    for (final f in Directory(
      'lib/data/repositories',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      // Strip line comments so a mention inside prose can't satisfy the check.
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      if (!code.contains('upsertAllPreservingDirty(')) continue;

      final viaTemplate = code.contains('ensurePageLoadedTemplate(');
      final guarded = code.contains('companyStillActive(');
      if (!viaTemplate && !guarded) {
        offenders.add(f.uri.pathSegments.last);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these write server rows without binding them to the active '
          'company — route the fetch through `ensurePageLoadedTemplate`, or '
          'guard the write with `companyStillActive` and throw '
          '`CompanySwitchedException`:\n  ${offenders.join('\n  ')}',
    );
  });
}

@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/home_widgets/widget_snapshot_builder.dart';

/// Every snapshot string the native widgets read (`snapshot.string("key", …)`
/// in Swift and Kotlin) must be one the app sends in the snapshot's
/// `strings` ([kWidgetStringKeys]). A key it doesn't send silently falls back
/// to the native code's English — translated in every bundle, read in none.
void main() {
  test('the app sends every string key the native widgets read', () {
    final sources =
        [
          ...Directory('ios/HomeWidgets').listSync(),
          ...Directory(
            'android/app/src/main/kotlin/com/invoiceninja/admin/homewidgets',
          ).listSync(),
        ].whereType<File>().where(
          (f) => f.path.endsWith('.swift') || f.path.endsWith('.kt'),
        );
    final read = <String>{};
    final pattern = RegExp(r'\.string\(\s*"([a-z0-9_]+)"');
    for (final file in sources) {
      for (final m in pattern.allMatches(file.readAsStringSync())) {
        read.add(m.group(1)!);
      }
    }
    expect(read, isNotEmpty, reason: 'the scan found nothing — moved files?');
    expect(
      read.difference(kWidgetStringKeys.toSet()),
      isEmpty,
      reason: 'add these to kWidgetStringKeys (widget_snapshot_builder.dart)',
    );
  });
}

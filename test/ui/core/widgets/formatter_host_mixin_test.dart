import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/utils/formatting.dart';

import '../../features/shell/_shell_test_helpers.dart';

/// `loadFormatter` always went through the async future, so every detail
/// screen painted at least one frame with a null `Formatter` — money rendered
/// as `—`, and the three billing detail screens went further and swapped the
/// tree shape (`f != null ? FormatterScope(...) : body`), remounting the whole
/// body when the formatter landed.
///
/// `Services` memoizes the Formatter per company and the list scaffold warms
/// it, so on the pane path the value is almost always already there — the sync
/// `formatterIfReady` path turns that into a first-frame render.
///
/// There is deliberately no cold-start test here: `auth.restore()` warms the
/// cache with a fire-and-forget future, so `invalidateFormatter` can be
/// re-populated by that still-in-flight `.then` before the widget mounts. The
/// async fallback is unchanged code and both tests below fail without the sync
/// path, which is what needs guarding.

class _Host extends StatefulWidget {
  const _Host({required this.services, required this.companyId});

  final Services services;
  final String companyId;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with FormatterHostMixin {
  late String _companyId = widget.companyId;

  @override
  void initState() {
    super.initState();
    loadFormatter(widget.services, _companyId);
  }

  void switchCompany(String id) {
    _companyId = id;
    clearFormatter();
    loadFormatter(widget.services, id);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(formatter == null ? '<no formatter>' : 'ready'),
  );
}

void main() {
  testWidgets('a warm Formatter renders on the FIRST frame', (tester) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    // Warm, as it always is by the time a row can be clicked: `auth.restore()`
    // primes it and the list scaffold does so again in its own initState
    // (`wantsFormatter`).
    await fixture.services.formatterFor('co1');

    await tester.pumpWidget(
      _Host(services: fixture.services, companyId: 'co1'),
    );

    // Single pump: no async gap, so no `—` money frame and no tree-shape flip.
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('clearFormatter() then loadFormatter() repaints on a company '
      'switch', (tester) async {
    // The sync path must `setState`: `clearFormatter` early-returns without
    // marking dirty when nothing was loaded, so a plain assignment here would
    // set the field with no rebuild scheduled.
    final fixture = await buildFixture(
      companies: [
        const FakeCompany(id: 'co1', name: 'Acme'),
        const FakeCompany(id: 'co2', name: 'Globex'),
      ],
    );
    addTearDown(fixture.dispose);
    await fixture.services.formatterFor('co1');
    await fixture.services.formatterFor('co2');

    await tester.pumpWidget(
      _Host(services: fixture.services, companyId: 'co1'),
    );
    expect(find.text('ready'), findsOneWidget);

    tester.state<_HostState>(find.byType(_Host)).switchCompany('co2');
    await tester.pump();

    expect(find.text('ready'), findsOneWidget);
    expect(
      tester.state<_HostState>(find.byType(_Host)).formatter,
      isA<Formatter>(),
    );
  });
}

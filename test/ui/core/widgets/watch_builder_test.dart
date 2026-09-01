import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/widgets/watch_builder.dart';

/// Every repo `watch*` returns a FRESH stream per call, so a `StreamBuilder`
/// whose `stream:` is built inline re-subscribes on each parent rebuild and
/// resets its snapshot to null — the rows blank and pop back. `WatchBuilder`
/// owns the subscription and only re-creates it when [cacheKey] changes.

class _Host extends StatefulWidget {
  const _Host({required this.cacheKey, required this.create});

  final Object? cacheKey;
  final Stream<String> Function() create;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Object? _key;

  @override
  void initState() {
    super.initState();
    _key = widget.cacheKey;
  }

  void rebuild({Object? newKey}) => setState(() {
    if (newKey != null) _key = newKey;
  });

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: WatchBuilder<String>(
      cacheKey: _key,
      create: widget.create,
      builder: (context, snap) => Text(snap.data ?? '<none>'),
    ),
  );
}

void main() {
  testWidgets('a parent rebuild with an unchanged cacheKey keeps the value', (
    tester,
  ) async {
    var created = 0;
    final controller = StreamController<String>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _Host(
        cacheKey: 'k',
        create: () {
          created++;
          return controller.stream;
        },
      ),
    );
    controller.add('Acme');
    // Two pumps: the event is delivered as a microtask, i.e. after the frame
    // that `pump` just built.
    await tester.pump();
    await tester.pump();
    expect(find.text('Acme'), findsOneWidget);
    expect(created, 1);

    tester.state<_HostState>(find.byType(_Host)).rebuild();
    await tester.pump();

    // The whole point: no re-subscribe, so no blank frame.
    expect(find.text('Acme'), findsOneWidget);
    expect(created, 1);
  });

  testWidgets('a changed cacheKey re-creates the stream', (tester) async {
    var created = 0;
    final first = StreamController<String>.broadcast();
    final second = StreamController<String>.broadcast();
    addTearDown(first.close);
    addTearDown(second.close);

    await tester.pumpWidget(
      _Host(
        cacheKey: 'a',
        create: () => (created++ == 0) ? first.stream : second.stream,
      ),
    );
    first.add('First');
    await tester.pump();
    await tester.pump();
    expect(find.text('First'), findsOneWidget);

    tester.state<_HostState>(find.byType(_Host)).rebuild(newKey: 'b');
    await tester.pump();
    expect(created, 2);

    second.add('Second');
    await tester.pump();
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('a record cacheKey compares by value, not identity', (
    tester,
  ) async {
    // The call sites pass tuples like `(companyId, entityId)`, rebuilt every
    // frame — identity comparison would re-subscribe constantly.
    var created = 0;
    final controller = StreamController<String>.broadcast();
    addTearDown(controller.close);

    Widget host() => Directionality(
      textDirection: TextDirection.ltr,
      child: WatchBuilder<String>(
        cacheKey: ('co', 'id'),
        create: () {
          created++;
          return controller.stream;
        },
        builder: (context, snap) => Text(snap.data ?? '<none>'),
      ),
    );

    await tester.pumpWidget(host());
    controller.add('Acme');
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(host());
    await tester.pump();

    expect(created, 1);
    expect(find.text('Acme'), findsOneWidget);
  });
}

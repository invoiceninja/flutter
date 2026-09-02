import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';

import '../../features/shell/_shell_test_helpers.dart';

/// The client field flickering on every master-detail row change.
///
/// `router.dart` re-keys the detail subtree per `:id`, so clicking a row
/// **mounts** `ClientNameLabel` afresh — and a fresh mount is the one event
/// that makes `StreamBuilder` start at `AsyncSnapshot.nothing()` (a rebuild
/// can't: `afterDisconnected` preserves `data`). With no seed the label paints
/// the raw hashid and swaps to the name a frame later, every single click.
///
/// `BaseEntityRepository.peek` closes that gap: the datatable's own Client
/// column resolved this client moments ago, so the value is already in memory.
///
/// These tests **pump exactly once** after the remount. That discipline is the
/// assertion — `pumpAndSettle` would let the watch emit and hide the very frame
/// the bug lives in (and the fixture keeps timers pending anyway).

/// Rebuilds [child] under a `KeyedSubtree` whose key changes on demand —
/// exactly the mechanism `router.dart:316` uses, so bumping the generation
/// produces a genuine fresh `State` rather than a rebuild.
class _Remountable extends StatefulWidget {
  const _Remountable({required this.child});

  final Widget child;

  @override
  State<_Remountable> createState() => _RemountableState();
}

class _RemountableState extends State<_Remountable> {
  int _gen = 0;

  void remount() => setState(() => _gen++);

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(_gen), child: widget.child);
}

void main() {
  testWidgets('paints the client name on the FIRST frame after a remount', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await fixture.services.clients.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: const ClientApi(id: 'c1', name: 'Acme Corp'),
    );

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        const _Remountable(child: ClientNameLabel(clientId: 'c1')),
      ),
    );

    // First mount resolves the hard way — this is the datatable's Client column
    // warming the cache before the user ever clicks a row.
    for (var i = 0; i < 10; i++) {
      if (find.text('Acme Corp').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('Acme Corp'), findsOneWidget);

    // Now the row click: a genuine remount, then ONE frame.
    tester.state<_RemountableState>(find.byType(_Remountable)).remount();
    await tester.pump();

    expect(find.text('Acme Corp'), findsOneWidget);
    expect(
      find.text('c1'),
      findsNothing,
      reason: 'the raw hashid must never be painted when the client is known',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('an unresolvable client renders the muted em-dash, never the '
      'raw hashid', (tester) async {
    // The cold-miss path the cache cannot reach by construction. A hashid is
    // meaningless to the user in every state, and painting one is what made
    // the flicker so visible in the first place.
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const ClientNameLabel(clientId: 'never')),
    );
    await tester.pump();

    expect(find.text('never'), findsNothing);
    expect(find.text('—'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a resolved but NAMELESS client reads (no name), not the '
      'unresolved em-dash', (tester) async {
    // `clientDisplayNameOf` drops a `display_name` the server derived from a
    // minted placeholder (invoiceninja/flutter#116), so `displayName` can now
    // be empty for a client that loaded perfectly well. Reusing the em-dash
    // there would tell the user the client is deleted / still loading / not
    // theirs — none of which is true, and none of which they could act on.
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await fixture.services.clients.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: const ClientApi(
        id: 'c1',
        name: '',
        displayName: 'dq9GHaI6Dncm0Zd@example.com',
      ),
    );

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const ClientNameLabel(clientId: 'c1')),
    );
    for (var i = 0; i < 10; i++) {
      if (find.text('(no name)').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('(no name)'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(
      find.textContaining('@example.com'),
      findsNothing,
      reason: 'the minted address must never surface as a client name',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// OAuth-return landing for calendar connect. Reached two ways with identical
/// behaviour: a full-page web redirect back to this route, or a native deep
/// link bridged here by `AppDeepLinks`. Reads the one-time `handoff` from
/// the URL, fires the security-critical `/complete` confirmation (the server
/// asserts the completing user started the flow), then routes back to the
/// calendar.
///
/// Single-fire: a consumed handoff errors on a second POST, so [_ran] guards
/// against a rebuild / deep-link re-delivery re-submitting it (mirrors React's
/// `ranRef`).
class CalendarConnectionCompleteScreen extends StatefulWidget {
  const CalendarConnectionCompleteScreen({super.key});

  @override
  State<CalendarConnectionCompleteScreen> createState() =>
      _CalendarConnectionCompleteScreenState();
}

class _CalendarConnectionCompleteScreenState
    extends State<CalendarConnectionCompleteScreen> {
  bool _ran = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  Future<void> _complete() async {
    if (_ran) return;
    _ran = true;

    final router = GoRouter.of(context);
    final services = context.read<Services>();
    final params = GoRouterState.of(context).uri.queryParameters;
    final provider = params['provider'] ?? '';
    final handoff = params['handoff'] ?? '';
    final status = params['calendar_connection'];

    void finish() => router.go('/tasks?view=calendar');

    // User declined consent at the provider.
    if (status == 'denied') {
      Notify.warning(context, context.tr('cancelled'));
      finish();
      return;
    }
    // Provider/callback error, or a missing token — can't finalise.
    if (status == 'failed' || handoff.isEmpty || provider.isEmpty) {
      Notify.error(context, context.tr('calendar_connect_failed'));
      finish();
      return;
    }

    try {
      await services.calendarConnection.complete(
        provider: provider,
        handoff: handoff,
      );
    } catch (error) {
      if (mounted) {
        Notify.error(
          context,
          context.tr('calendar_connect_failed'),
          error: error,
        );
      }
    } finally {
      finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

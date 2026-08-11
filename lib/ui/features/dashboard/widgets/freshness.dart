import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

/// "Updated 12 min ago" — the dashboard's data-freshness stamp.
///
/// A null [lastRefreshed] means we've never completed a pass: "Loading…" while
/// one is in flight, "Not yet loaded" when the boot refresh failed outright.
///
/// Relative wording comes from the shared [formatRelativeTime] so the dashboard
/// reads the same as the activity feed and System Logs.
String freshnessText(
  BuildContext context, {
  required DateTime? lastRefreshed,
  required bool isRefreshing,
}) {
  if (lastRefreshed == null) {
    return context.tr(
      isRefreshing ? 'loading_ellipsis' : 'not_yet_loaded_label',
    );
  }
  return context.tr('updated_relative', {
    'relative': formatRelativeTime(
      context,
      DateTime.now().difference(lastRefreshed),
    ),
  });
}

/// Rebuilds [builder] every 30 seconds so a relative timestamp stays current
/// without an external timer. Callers compose their own string — the wide top
/// bar folds the stamp into its subtitle, the mobile eyebrow into an uppercase
/// run — so this deliberately renders no chrome of its own.
///
/// Accepted cost: both call sites now live in non-scrolling chrome, and
/// `StatefulShellRoute.indexedStack` keeps the dashboard branch mounted
/// offstage, so the timer runs for the whole session rather than only while the
/// old footer was scrolled into view. That's one `setState` on a single `Text`
/// every 30 s.
class FreshnessTicker extends StatefulWidget {
  const FreshnessTicker({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<FreshnessTicker> createState() => _FreshnessTickerState();
}

class _FreshnessTickerState extends State<FreshnessTicker> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

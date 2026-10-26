import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/show_seconds_controller.dart';

/// Whether the device's Show Seconds preference is on, subscribing [context]
/// so it rebuilds when the switch flips (docs/tasks-views.md).
///
/// Off when no [ShowSecondsController] is provided — a widget test that
/// doesn't care gets the default.
bool watchShowSeconds(BuildContext context) =>
    context.watch<ShowSecondsController?>()?.value ?? false;

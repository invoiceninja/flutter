import 'package:flutter/widgets.dart';

/// Bubbled up the tree by an input that takes the user's typing in a way the
/// idle-timeout's other activity feeds cannot see — today `MarkdownTextField`,
/// whose `super_editor` document is neither a `TextEditingController` nor,
/// on a soft keyboard, a source of hardware key events.
///
/// Caught next to the root pointer `Listener` in `main.dart`, which pokes
/// `IdleTimeoutController`. Dispatch it only for a genuine user edit — a
/// programmatic reseed that "counted" as activity would keep an unattended
/// session alive.
class UserActivityNotification extends Notification {
  const UserActivityNotification();
}

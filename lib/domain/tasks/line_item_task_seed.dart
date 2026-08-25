import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/domain/tasks/line_item_notes_display.dart';

/// Pure rules for scheduling an invoice / quote line item as a dated task —
/// the symmetric counterpart of `taskToLineItem`
/// (`ui/features/billing_shared/add_unbilled/unbilled_line_items.dart`), which
/// maps a task's billable seconds onto a line's `quantity`. This direction
/// reads that `quantity` back as a block of work.
///
/// Kept UI-free — no widget imports and, deliberately, no `emptyTask()`: that
/// factory lives in a *view model* (`task_edit_view_model.dart`), so a
/// `lib/domain/` file reaching for it would invert the layering. These helpers
/// return the *parts*; the sheet assembles the `Task`. Same split, and the same
/// reason, as `calendar_event_seed.dart`.

/// Neutral duration when the line's quantity can't be read as a work block.
/// Chosen to line up with the two fallbacks either side of this conversion:
/// `taskBillableHours` falls back to `Decimal.one` (one billable hour) and
/// `seedTimeLogForEvent` anchors an all-day event to a 1 h block.
const Duration _kFallbackDuration = Duration(hours: 1);

/// Above this, `quantity` is being read as units rather than hours — see
/// [lineItemTaskDuration].
const int _kMaxSeedHours = 24;

/// Description for a task scheduled from [item]: the item column, then the
/// notes, blank-trimmed and joined by a blank line. Mirrors
/// `seedDescriptionForEvent`.
///
/// Notes go through [lineItemNotesPlainText] so a task-generated line's
/// `<div class="project-header">` / `<br/>` markup never lands in a task
/// description — the tags would render literally, exactly as they did on the
/// invoice detail screen before that helper existed.
///
/// The product key is dropped when the notes already open with it (trimmed,
/// case-insensitive): a product-filled row writes both `product_key` and
/// `notes`, and "Boiler service\n\nBoiler service" is not a description.
String lineItemTaskDescription(LineItem item) {
  final key = item.productKey.trim();
  final notes = lineItemNotesPlainText(item.notes).trim();
  if (notes.isEmpty) return key;
  if (key.isEmpty) return notes;
  final firstLine = notes.split('\n').first.trim();
  if (firstLine.toLowerCase() == key.toLowerCase()) return notes;
  return '$key\n\n$notes';
}

/// The line's `quantity` read as hours, rounded to whole minutes.
///
/// A heuristic, and deliberately a forgiving one. `quantity` is only really
/// hours when the line came from a task in the first place (`taskToLineItem`
/// sets `quantity: taskBillableHours(...)`); on a product line it counts units,
/// where "3 widgets" is not three hours. So a value that can't be a single
/// day's work block — zero, negative, or over [_kMaxSeedHours] — falls back to
/// [_kFallbackDuration] rather than being clamped, because inventing a
/// full-day block for a 500-unit line would be no more right than 1 h and a
/// good deal more confident.
///
/// The sheet seeds its Duration field from this and the user owns it from
/// there, so an unhelpful guess costs one keystroke.
Duration lineItemTaskDuration(LineItem item) {
  final hours = item.quantity.toDouble();
  if (!hours.isFinite || hours <= 0 || hours > _kMaxSeedHours) {
    return _kFallbackDuration;
  }
  final minutes = (hours * 60).round();
  // A sub-30-second quantity rounds to zero; a zero-length entry reads as
  // unlogged everywhere, so floor it at the smallest thing the UI can show.
  return Duration(minutes: minutes < 1 ? 1 : minutes);
}

/// The single [TimeEntry] a scheduled line item seeds — the only way a task
/// acquires a date (`TaskDay.day` is the local date of the earliest start).
///
/// [start] is a LOCAL wall-clock `DateTime`: `TimeEntry.encodeLog` serialises
/// via `millisecondsSinceEpoch`, so it round-trips to the right instant, and
/// `TaskDay.day` reads it back through `.toLocal()`. Building it as UTC would
/// land the task on the wrong calendar cell for everyone off the meridian.
List<TimeEntry> seedTimeLogForLineItem({
  required DateTime start,
  required Duration duration,
  required bool billable,
}) => [TimeEntry(start: start, stop: start.add(duration), billable: billable)];

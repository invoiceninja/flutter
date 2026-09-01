import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/saved_views_sheet.dart';

/// Toolbar bookmark icon. Tapping opens [SavedViewsSheet] in a modal bottom
/// sheet — same convention `EntityColumnPickerSheet` follows. Generic on the
/// list ViewModel so every entity reuses it.
class SavedViewsButton<T> extends StatelessWidget {
  const SavedViewsButton({required this.vm, super.key});

  final GenericListViewModel<T> vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return OutlinedButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.bookmark_outline, size: 14),
      label: Text(
        context.tr('views'),
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.ink2,
        side: BorderSide(color: tokens.border),
        // Rounded rectangle, never a pill — design system rule from CLAUDE.md.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // `showModalBottomSheet` applies no `viewInsets` padding of its own, and
      // the sheet's name field autofocuses — so without this the keyboard rose
      // straight over the input the sheet exists to collect. Padding here also
      // shrinks the constraints the sheet's own `maxHeight: height * 0.85` cap
      // is enforced against, so the header can't be pushed off the top.
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SavedViewsSheet<T>(vm: vm),
      ),
    );
  }
}

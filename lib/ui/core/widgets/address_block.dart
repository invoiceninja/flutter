import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/map_links.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// A postal address as a reader meets one: a block of lines, copyable **as a
/// whole**, with a way to see it on a map.
///
/// It replaces four label/value rows (Address1 / Address2 / City / Country).
/// Those copied one line at a time — nobody pastes an envelope in four trips —
/// and the row labelled "City" held the city, state and postal code.
///
/// [lines] are display order and already formatted for the country (see
/// `formatAddressLines`). They are also what is copied, joined by newlines,
/// and what the map is searched for, joined by commas — so [lines] must carry
/// the country even when a document would leave a domestic one off: a map
/// search without it resolves to whichever "Springfield" the provider prefers.
class AddressBlock extends StatelessWidget {
  const AddressBlock({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final text = lines.join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CopyableValue(
          value: text,
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.ink,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        // The documented link treatment: `accentInk` everywhere, and an
        // underline at rest only where there is no hover to reveal one.
        LinkText(
          label: context.tr('view_map'),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          color: tokens.accentInk,
          underlineAtRest: linkNeedsAtRestCue,
          onTap: () => openMapFor(context, lines.join(', ')),
        ),
      ],
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/system_log.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// One row in a System Logs feed. Renders category / type / event in a
/// responsive layout (left-column on wide; stacked on narrow) with a
/// collapsible JSON viewer for the `log` payload.
///
/// Shared by Settings → System Logs (`system_logs_screen.dart`) and the
/// per-gateway logs section on the company-gateway detail screen.
class SystemLogRow extends StatefulWidget {
  const SystemLogRow({super.key, required this.log, required this.isWide});

  final SystemLog log;
  final bool isWide;

  @override
  State<SystemLogRow> createState() => _SystemLogRowState();
}

class _SystemLogRowState extends State<SystemLogRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final relative = formatRelativeTime(
      context,
      DateTime.now().toUtc().difference(widget.log.createdAt.toUtc()),
    );
    final categoryLabel = context.tr(widget.log.categoryKey);
    final typeDisp = widget.log.typeDisplay();
    final typeText = typeDisp.isKey
        ? context.tr(typeDisp.value)
        : typeDisp.value;
    final eventLabel = context.tr(widget.log.eventKey);
    final (eventFg, eventBg) = _toneColors(tokens, widget.log.tone);
    final meta = '$typeText · $relative';

    final categoryWidget = Text(
      categoryLabel,
      style: TextStyle(
        color: tokens.ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
    final metaWidget = Text(
      meta,
      style: TextStyle(color: tokens.ink3, fontSize: 12),
    );
    final pill = StatusPill(
      label: eventLabel,
      fgColor: eventFg,
      bgColor: eventBg,
    );
    final logBlock = _LogBlock(
      raw: widget.log.log,
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
    );

    final body = widget.isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    categoryWidget,
                    const SizedBox(height: 2),
                    metaWidget,
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: pill),
                    const SizedBox(height: 8),
                    logBlock,
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: categoryWidget),
                  const SizedBox(width: 8),
                  pill,
                ],
              ),
              const SizedBox(height: 2),
              metaWidget,
              const SizedBox(height: 8),
              logBlock,
            ],
          );

    // Colour-code the row itself, not just the badge dot — a failure buried in
    // a long feed needs to be findable by scanning (invoiceninja/flutter#58).
    // Success stays flat on purpose: tinting everything green is the "a lot of
    // green 'everything is fine'" the issue objects to, and it would leave a
    // failure no louder than its neighbours.
    final alarm =
        widget.log.tone == SystemLogTone.failure ||
        widget.log.tone == SystemLogTone.warning;
    final padded = Padding(
      padding: EdgeInsets.fromLTRB(alarm ? 12 : 0, 12, 0, 12),
      child: body,
    );
    if (!alarm) return padded;
    return Container(
      decoration: BoxDecoration(
        color: eventBg,
        border: BorderDirectional(start: BorderSide(color: eventFg, width: 3)),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: padded,
    );
  }

  (Color fg, Color bg) _toneColors(InTheme tokens, SystemLogTone tone) {
    switch (tone) {
      case SystemLogTone.success:
        return (tokens.paid, tokens.paidSoft);
      case SystemLogTone.failure:
        return (tokens.overdue, tokens.overdueSoft);
      case SystemLogTone.warning:
        return (tokens.sent, tokens.sentSoft);
      case SystemLogTone.neutral:
        return (tokens.ink3, tokens.accentSoft);
    }
  }
}

/// Collapsible JSON / text view for the `log` field. Pretty-prints decoded
/// JSON; falls back to the raw string when `jsonDecode` throws. Collapsed
/// state shows a one-line preview + chevron; expanded state shows the
/// monospace `SelectableText` block (horizontally scrollable so JSON
/// indentation survives on narrow screens) with a copy button.
class _LogBlock extends StatelessWidget {
  const _LogBlock({
    required this.raw,
    required this.expanded,
    required this.onToggle,
  });

  final String raw;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final decoded = _tryDecode(raw);
    final preview = _preview(context, raw, decoded);

    if (!expanded) {
      return InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.ink3,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 18, color: tokens.ink3),
            ],
          ),
        ),
      );
    }

    final pretty = decoded == null
        ? raw
        : const JsonEncoder.withIndent('  ').convert(decoded);

    return Container(
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: context.tr('copy'),
                onPressed: () => _copy(context),
              ),
              IconButton(
                icon: const Icon(Icons.expand_less, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: onToggle,
              ),
            ],
          ),
          // Horizontal scroll so deep JSON indentation survives on narrow
          // screens — without it the monospace text char-wraps and the
          // structure is lost on mobile.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              pretty,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: tokens.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // `raw` is a log blob, so name it in the toast rather than dumping the first
  // 40 characters of JSON into "Copied … to the clipboard".
  Future<void> _copy(BuildContext context) =>
      copyToClipboard(context, raw, label: context.tr('log'));

  Object? _tryDecode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final first = trimmed.codeUnitAt(0);
    if (first != 0x7B /* { */ && first != 0x5B /* [ */ ) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  String _preview(BuildContext context, String raw, Object? decoded) {
    if (decoded is Map) {
      return context.tr('json_field_count', {'count': '${decoded.length}'});
    }
    if (decoded is List) {
      return context.tr('json_item_count', {'count': '${decoded.length}'});
    }
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 80) return cleaned;
    return '${cleaned.substring(0, 80)}…';
  }
}

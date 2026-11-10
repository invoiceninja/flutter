import 'dart:async';

import 'package:flutter/material.dart';
import 'package:store_services/store_services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/features/terminal/terminal_error_text.dart';

/// Lists the Bluetooth card readers in range as they're found; a tap picks
/// one. Closing the sheet stops the scan (docs/in-person-payments.md).
Future<TerminalReader?> showReaderPickerSheet(
  BuildContext context, {
  required Stream<List<TerminalReader>> readers,
}) => showModalBottomSheet<TerminalReader>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (_) => _ReaderPickerSheet(readers: readers),
);

class _ReaderPickerSheet extends StatefulWidget {
  const _ReaderPickerSheet({required this.readers});

  final Stream<List<TerminalReader>> readers;

  @override
  State<_ReaderPickerSheet> createState() => _ReaderPickerSheetState();
}

class _ReaderPickerSheetState extends State<_ReaderPickerSheet> {
  late final StreamSubscription<List<TerminalReader>> _scan;
  List<TerminalReader> _found = const [];
  bool _scanning = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scan = widget.readers.listen(
      (readers) => setState(() => _found = readers),
      onError: (Object e) => setState(() {
        _error = e;
        _scanning = false;
      }),
      onDone: () => setState(() => _scanning = false),
    );
  }

  @override
  void dispose() {
    unawaited(_scan.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            headingLevel: 1,
            child: Text(
              context.tr('terminal_connect_reader'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: InSpacing.sm),
          Text(context.tr('terminal_reader_scan_help')),
          const SizedBox(height: InSpacing.sm),
          if (_scanning && _found.isEmpty) const LinearProgressIndicator(),
          for (final reader in _found)
            ListTile(
              leading: const Icon(Icons.point_of_sale_outlined),
              title: Text(reader.label),
              subtitle: LtrText(reader.serialNumber),
              onTap: () => Navigator.of(context).pop(reader),
            ),
          if (!_scanning && _found.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: InSpacing.sm),
              child: Text(
                context.tr(switch (_error) {
                  null => 'terminal_reader_none_found',
                  final TerminalError e => terminalErrorKey(e.code),
                  _ => 'terminal_error_reader_disconnected',
                }),
              ),
            ),
        ],
      ),
    ),
  );
}

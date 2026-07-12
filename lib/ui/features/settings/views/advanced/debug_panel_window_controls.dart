import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/screenshot_window_controller.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Debug Panel toolbar control: a menu of App Store / Play Store screenshot
/// sizes (plus custom + restore) that resizes the native window so a window
/// capture lands on exactly the chosen pixel dimensions. Desktop-only — the
/// toolbar gates it on `Env.isDesktop`.
class ScreenshotSizeMenuButton extends StatelessWidget {
  const ScreenshotSizeMenuButton({super.key, required this.controller});

  final ScreenshotWindowController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final applied = controller.appliedSizePx;
    return MenuAnchor(
      builder: (context, menu, _) => IconButton(
        icon: const Icon(Icons.aspect_ratio),
        tooltip: context.tr('screenshot_size'),
        isSelected: applied != null,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
      menuChildren: [
        for (final (i, group) in kScreenshotPresetGroups.indexed) ...[
          if (i > 0) const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              context.tr(group.labelKey),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.ink3,
              ),
            ),
          ),
          for (final preset in group.presets)
            MenuItemButton(
              leadingIcon: _checkIcon(
                applied != null &&
                    applied.width == preset.widthPx &&
                    applied.height == preset.heightPx,
              ),
              onPressed: () => _apply(context, preset.widthPx, preset.heightPx),
              child: Text(_presetLabel(context, preset)),
            ),
        ],
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: _checkIcon(false),
          onPressed: () => _openCustom(context),
          child: Text(context.tr('custom_size')),
        ),
        if (controller.canRestoreOriginalSize)
          MenuItemButton(
            leadingIcon: _checkIcon(false),
            onPressed: controller.restoreOriginalSize,
            child: Text(context.tr('restore_original_size')),
          ),
      ],
    );
  }

  String _presetLabel(BuildContext context, ScreenshotPreset preset) {
    final key = preset.descriptionKey;
    if (key == null) return preset.dimensionLabel;
    return '${context.tr(key)} — ${preset.dimensionLabel}';
  }

  /// Reserves the leading-icon slot when unchecked so labels stay aligned.
  Widget _checkIcon(bool checked) =>
      checked ? const Icon(Icons.check, size: 16) : const SizedBox(width: 16);

  Future<void> _apply(BuildContext context, int widthPx, int heightPx) async {
    // Read DPR + current size from the live view at apply time — the window
    // may have moved to a different-scale display since the panel opened.
    final view = View.of(context);
    final dpr = view.devicePixelRatio;
    final result = await controller.applySizePx(
      widthPx: widthPx,
      heightPx: heightPx,
      devicePixelRatio: dpr,
      currentLogicalSize: view.physicalSize / dpr,
    );
    if (!context.mounted) return;
    final achieved = result.achievedPx;
    if (achieved != null && !result.matched) {
      Notify.warning(
        context,
        context
            .tr('screenshot_size_mismatch')
            .replaceAll(':width', '${achieved.width}')
            .replaceAll(':height', '${achieved.height}'),
      );
    }
  }

  Future<void> _openCustom(BuildContext context) async {
    final view = View.of(context);
    final initial =
        controller.appliedSizePx ??
        (
          width: view.physicalSize.width.round(),
          height: view.physicalSize.height.round(),
        );
    final size = await ScreenshotCustomSizeDialog.show(
      context,
      initial: initial,
    );
    if (size == null || !context.mounted) return;
    await _apply(context, size.width, size.height);
  }
}

/// Debug Panel toolbar control: hides/shows the native window buttons (macOS
/// traffic lights) so screenshots have clean chrome. State lives on the
/// controller (Services) and the buttons come back on every app launch.
class WindowButtonsToggle extends StatelessWidget {
  const WindowButtonsToggle({super.key, required this.controller});

  final ScreenshotWindowController controller;

  @override
  Widget build(BuildContext context) {
    final hidden = controller.windowButtonsHidden;
    return IconButton(
      isSelected: hidden,
      icon: const Icon(Icons.visibility_outlined),
      selectedIcon: const Icon(Icons.visibility_off_outlined),
      tooltip: context.tr(
        hidden ? 'show_window_buttons' : 'hide_window_buttons',
      ),
      onPressed: () => controller.setWindowButtonsHidden(!hidden),
    );
  }
}

/// Width × height (physical px) input dialog for a custom screenshot size.
/// Returns the entered size; the caller applies it through the controller so
/// the devicePixelRatio is read from a live, mounted context.
class ScreenshotCustomSizeDialog extends StatefulWidget {
  const ScreenshotCustomSizeDialog({super.key, this.initial});

  final ({int width, int height})? initial;

  static Future<({int width, int height})?> show(
    BuildContext context, {
    ({int width, int height})? initial,
  }) {
    return showDialog<({int width, int height})>(
      context: context,
      builder: (_) => ScreenshotCustomSizeDialog(initial: initial),
    );
  }

  @override
  State<ScreenshotCustomSizeDialog> createState() =>
      _ScreenshotCustomSizeDialogState();
}

class _ScreenshotCustomSizeDialogState
    extends State<ScreenshotCustomSizeDialog> {
  static const _min = 100;
  static const _max = 10000;

  late final TextEditingController _width = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial!.width}',
  );
  late final TextEditingController _height = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial!.height}',
  );

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    if (v == null || v < _min || v > _max) return null;
    return v;
  }

  bool get _valid => _parse(_width) != null && _parse(_height) != null;

  void _submit() {
    final w = _parse(_width);
    final h = _parse(_height);
    if (w == null || h == null) return;
    Navigator.of(context).pop((width: w, height: h));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('custom_size')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: FormSaveScope(
          onSubmit: _submit,
          enabled: _valid,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _SizeField(
                  controller: _width,
                  labelKey: 'width_px',
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onChanged: () => setState(() {}),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: InSpacing.md(context),
                ),
                child: const Text('×'),
              ),
              Expanded(
                child: _SizeField(
                  controller: _height,
                  labelKey: 'height_px',
                  textInputAction: TextInputAction.done,
                  onChanged: () => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('apply'),
          enabled: _valid,
          autofocus: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _SizeField extends StatelessWidget {
  const _SizeField({
    required this.controller,
    required this.labelKey,
    required this.textInputAction,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String labelKey;
  final TextInputAction textInputAction;
  final VoidCallback onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: textInputAction,
      decoration: InputDecoration(
        isDense: true,
        labelText: context.tr(labelKey),
      ),
      onChanged: (_) => onChanged(),
      onSubmitted: (_) {
        if (textInputAction == TextInputAction.done) {
          FormSaveScope.maybeOf(context)?.trySubmit();
        }
      },
    );
  }
}

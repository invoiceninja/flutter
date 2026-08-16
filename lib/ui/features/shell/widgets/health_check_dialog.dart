import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/health_check_api_model.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';

const String _kDocsUrl = 'https://invoiceninja.github.io/docs';

enum _HealthCheckLevel { info, warning }

/// Open the Health Check dialog. Surfaces self-hosted server diagnostics
/// (system health, database, PHP, queue, file permissions, etc.) backed by
/// `/api/v1/health_check`. Gating (admin/owner + self-hosted) is enforced
/// at the call site in the About dialog.
Future<void> showHealthCheckDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _HealthCheckDialog(),
  );
}

class _HealthCheckDialog extends StatefulWidget {
  const _HealthCheckDialog();

  @override
  State<_HealthCheckDialog> createState() => _HealthCheckDialogState();
}

class _HealthCheckDialogState extends State<_HealthCheckDialog> {
  HealthCheckResponse? _response;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  Future<void> _runCheck() async {
    setState(() {
      _busy = true;
      _response = null;
    });
    try {
      final result = await context.read<Services>().system.getHealthCheck();
      if (!mounted) return;
      setState(() {
        _response = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      Notify.error(context, context.tr('health_check'), error: e);
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      _busy = true;
      _response = null;
    });
    try {
      await context.read<Services>().system.clearCache();
      if (!mounted) return;
      await _runCheck();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      Notify.error(context, context.tr('clear_cache'), error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('health_check')),
      content: SizedBox(
        width: 460,
        child: _busy || _response == null
            ? _LoadingBody()
            : SingleChildScrollView(
                child: _HealthCheckBody(response: _response!),
              ),
      ),
      actions: _busy || _response == null
          ? const []
          : [
              TextButton(
                onPressed: _clearCache,
                child: Text(context.tr('clear_cache')),
              ),
              TextButton(
                onPressed: _runCheck,
                child: Text(context.tr('refresh')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr('close')),
              ),
            ],
    );
  }
}

class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: LinearProgressIndicator(),
        ),
        Text('${context.tr('loading')}...'),
      ],
    );
  }
}

class _HealthCheckBody extends StatelessWidget {
  const _HealthCheckBody({required this.response});

  final HealthCheckResponse response;

  @override
  Widget build(BuildContext context) {
    final webPhp = _parseVersion(response.phpVersion.currentPhpVersion);
    final cliPhp = _parseVersion(response.phpVersion.currentPhpCliVersion);
    final memoryLimit = response.phpVersion.memoryLimit;
    final memoryLimitMb = _parseMemoryLimitMb(memoryLimit);
    final phpOkay =
        response.phpVersion.isOkay &&
        webPhp.startsWith('v8') &&
        (cliPhp.startsWith('v8') || !cliPhp.startsWith('v'));

    // `is_docker` comes straight from the health_check response (the server
    // reports it). Docker images ship pre-configured, so the old app hid the
    // file-permission / open_basedir / config-cache / memory-limit warnings
    // for them — mirror that here. `disableAutoUpdate` is an account-level flag
    // v2 doesn't track; left a no-op (it only further-gated the file-perms row).
    final isDocker = response.isDocker;
    const disableAutoUpdate = false;

    final tiles = <Widget>[
      _HealthListTile(
        title: context.tr('system_health'),
        isValid: response.systemHealth,
        subtitle:
            '${context.tr('email_driver')}: ${response.emailDriver}\n'
            '${context.tr('queue')}: ${response.queue}\n'
            '${context.tr('pdf_engine')}: ${response.pdfEngine.replaceFirst(' Generator', '')}',
        buttonLabel: context.tr('view_last_error'),
        buttonCallback: () => showDialog<void>(
          context: context,
          builder: (_) => const _LastErrorDialog(),
        ),
      ),
      _HealthListTile(
        title: context.tr('database_check'),
        isValid: response.dbCheck && !response.pendingMigration,
        subtitle: response.pendingMigration
            ? context.tr('pending_migrations_help')
            : null,
      ),
      _HealthListTile(
        title: context.tr('php_info'),
        isValid: phpOkay,
        subtitle: _phpInfoSubtitle(context, webPhp, cliPhp, memoryLimit),
      ),
      if (response.queue == 'database')
        _HealthListTile(
          title: context.tr('queue'),
          isValid: response.queueData.failed == 0,
          level:
              response.queueData.failed == 0 && response.queueData.pending > 0
              ? _HealthCheckLevel.warning
              : null,
          subtitle:
              '${context.tr('pending_jobs')}: ${response.queueData.pending}\n'
              '${context.tr('failed_jobs')}: ${response.queueData.failed}',
          buttonLabel: response.queueData.lastError.isNotEmpty
              ? context.tr('view_last_queue_error')
              : null,
          buttonCallback: response.queueData.lastError.isNotEmpty
              ? () => showDialog<void>(
                  context: context,
                  builder: (_) => _LastQueueErrorDialog(
                    message: response.queueData.lastError,
                  ),
                )
              : null,
        ),
      if (response.filePermissions != 'Ok' && !disableAutoUpdate && !isDocker)
        _HealthListTile(
          title: context.tr('invalid_file_permissions'),
          isValid: false,
          subtitle: response.filePermissions,
          url: '$_kDocsUrl/self-host-installation/#file-permissions',
        ),
      if (!isDocker && !response.envWritable)
        _HealthListTile(
          title: context.tr('env_not_writable'),
          isValid: false,
          url: '$_kDocsUrl/self-host-installation/#file-permissions',
        ),
      if (!response.execEnabled)
        _HealthListTile(
          title: context.tr('php_exec_not_enabled'),
          isValid: false,
        ),
      if (response.pendingJobs > 0)
        _HealthListTile(
          title: context.tr('pending_jobs'),
          subtitle: '${response.pendingJobs}',
          level: _HealthCheckLevel.warning,
        ),
      if (!isDocker && !response.openBasedir)
        _HealthListTile(
          title: context.tr('open_basedir_not_enabled'),
          level: _HealthCheckLevel.warning,
        ),
      if (!isDocker && !response.cacheEnabled)
        _HealthListTile(
          title: context.tr('config_not_cached'),
          subtitle: context.tr('config_not_cached_help'),
          level: _HealthCheckLevel.warning,
        ),
      if (!isDocker &&
          memoryLimitMb != null &&
          memoryLimitMb > 100 &&
          memoryLimitMb < 2048)
        _HealthListTile(
          title: context.tr('php_memory_limit_too_low'),
          subtitle: context.tr('php_memory_limit_help'),
          level: _HealthCheckLevel.warning,
        ),
      if (response.queue == 'sync')
        _HealthListTile(
          title: context.tr('queue_not_enabled'),
          subtitle: context.tr('queue_not_enabled_help'),
          level: _HealthCheckLevel.info,
          url: '$_kDocsUrl/self-host-installation/#final-setup-steps',
        ),
      if (!response.pdfEngine.toLowerCase().startsWith('snappdf'))
        _HealthListTile(
          title: context.tr('snappdf_not_enabled'),
          subtitle: context.tr('snappdf_not_enabled_help'),
          level: _HealthCheckLevel.info,
          url: '$_kDocsUrl/self-host-troubleshooting/#pdf-conversion-issues',
        ),
      if (response.trailingSlash)
        _HealthListTile(
          title: context.tr('app_url_trailing_slash'),
          subtitle: context.tr('app_url_trailing_slash_help'),
          level: _HealthCheckLevel.warning,
        ),
      if (response.exchangeRateApiNotConfigured)
        _HealthListTile(
          title: context.tr('exchange_rate_not_configured'),
          subtitle: context.tr('exchange_rate_not_configured_help'),
          level: _HealthCheckLevel.info,
          url: '$_kDocsUrl/self-host-installation/#currency-conversion',
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tiles,
    );
  }

  String _phpInfoSubtitle(
    BuildContext context,
    String webPhp,
    String cliPhp,
    String memoryLimit,
  ) {
    final lines = <String>[
      '${context.tr('web_php_version')}: $webPhp',
      '${context.tr('cli_php_version')}: $cliPhp',
    ];
    if (memoryLimit.isNotEmpty) {
      lines.add('${context.tr('memory_limit_label')}: $memoryLimit');
    }
    return lines.join('\n');
  }
}

class _HealthListTile extends StatelessWidget {
  const _HealthListTile({
    required this.title,
    this.isValid = true,
    this.level,
    this.subtitle,
    this.url,
    this.buttonLabel,
    this.buttonCallback,
  });

  final String title;
  final bool isValid;
  final _HealthCheckLevel? level;
  final String? subtitle;
  final String? url;
  final String? buttonLabel;
  final VoidCallback? buttonCallback;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (level) {
      _HealthCheckLevel.warning => (
        Icons.warning_amber_outlined,
        Colors.orange,
      ),
      _HealthCheckLevel.info => (Icons.info_outline, Colors.blue),
      null =>
        isValid
            ? (Icons.check_circle_outline, Colors.green)
            : (Icons.warning_amber_outlined, Colors.red),
    };

    final body =
        subtitle ??
        (level != null
            ? (level == _HealthCheckLevel.warning
                  ? context.tr('warning')
                  : context.tr('info'))
            : (isValid ? context.tr('passed') : context.tr('failed')));

    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          if (buttonLabel != null && buttonCallback != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 36),
                ),
                onPressed: buttonCallback,
                child: Text(buttonLabel!),
              ),
            ),
        ],
      ),
      trailing: Icon(icon, color: color),
      onTap: url != null ? () => unawaited(launchUrl(Uri.parse(url!))) : null,
    );
  }
}

class _LastErrorDialog extends StatefulWidget {
  const _LastErrorDialog();

  @override
  State<_LastErrorDialog> createState() => _LastErrorDialogState();
}

class _LastErrorDialogState extends State<_LastErrorDialog> {
  HealthCheckLastErrorResponse? _response;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<Services>().system.getLastError();
      if (!mounted) return;
      setState(() => _response = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _response?.lastError ?? '';
    return AlertDialog(
      title: Text(context.tr('last_error')),
      content: SizedBox(
        width: 460,
        child: _response == null && !_failed
            ? const LinearProgressIndicator()
            : SingleChildScrollView(
                child: SelectableText(
                  message.isEmpty ? context.tr('no_errors_found') : message,
                ),
              ),
      ),
      actions: [
        if (message.isNotEmpty)
          TextButton(
            onPressed: () => _copy(context, message),
            child: Text(context.tr('copy')),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('close')),
        ),
      ],
    );
  }
}

class _LastQueueErrorDialog extends StatelessWidget {
  const _LastQueueErrorDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('last_queue_error')),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(child: SelectableText(message)),
      ),
      actions: [
        TextButton(
          onPressed: () => _copy(context, message),
          child: Text(context.tr('copy')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('close')),
        ),
      ],
    );
  }
}

// Label rather than payload: `message` is the whole health-check report.
Future<void> _copy(BuildContext context, String message) =>
    copyToClipboard(context, message, label: context.tr('health_check'));

String _parseVersion(String version) {
  final match = RegExp(r'(\d+\.\d+\.\d+)').stringMatch(version);
  if (match == null) return version;
  return 'v$match';
}

/// Parses PHP `memory_limit` (e.g. `512M`, `2G`, `256`) into megabytes.
/// Returns null when the value can't be parsed — the dialog skips the
/// "too low" row in that case.
double? _parseMemoryLimitMb(String raw) {
  final m = RegExp(r'^(\d+)\s*([gGmMkK]?)').firstMatch(raw.trim());
  if (m == null) return null;
  final n = double.tryParse(m.group(1)!);
  if (n == null) return null;
  return switch (m.group(2)?.toLowerCase()) {
    'g' => n * 1024,
    'k' => n / 1024,
    _ => n,
  };
}

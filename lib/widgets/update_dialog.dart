import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// Show update dialog — now drives the in-app install path, with the
/// browser-handoff path kept as a tertiary fallback for users
/// without install permissions or on platforms where the installer
/// intent isn't available.
///
/// Behavior tap-by-tap on the primary CTA:
///   1. Button shows an inline spinner; downloads the APK to temp.
///   2. On success, calls `triggerInstall` → Android system installer.
///   3. On IO / network / non-Android failure, falls back to
///      `openDownloadUrl` and surfaces the result.
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final VoidCallback onLater;
  final VoidCallback onDownload;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onLater,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final releaseDate = _formatReleaseDate(updateInfo.releaseDate);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.system_update,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Update Available',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Version ${updateInfo.version}',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Released: $releaseDate',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (updateInfo.releaseNotes.isNotEmpty) ...[
              Text(
                'What\'s new:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    _formatReleaseNotes(updateInfo.releaseNotes),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Skip this version (unchanged UX)
        TextButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Ignore this update?'),
                content: Text(
                  'You won\'t be notified about version ${updateInfo.version} again. You can still update later.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Ignore'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await UpdateService.ignoreVersion(updateInfo.version);
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Skip this version'),
        ),
        // "Open in browser" — fallback path
        TextButton(
          onPressed: () => _openInBrowser(context),
          child: const Text('Open in browser'),
        ),
        // Primary path: in-app download + install
        _DownloadAndInstallButton(updateInfo: updateInfo),
      ],
    );
  }

  Future<void> _openInBrowser(BuildContext context) async {
    final success = await UpdateService.openDownloadUrl(updateInfo.downloadUrl);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to open download. Please visit: ${updateInfo.htmlUrl}',
          ),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => UpdateService.openDownloadUrl(updateInfo.htmlUrl),
          ),
        ),
      );
    }
    if (context.mounted && success) Navigator.pop(context);
  }

  String _formatReleaseDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Recently';
    }
  }

  String _formatReleaseNotes(String notes) {
    return notes
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'\1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'\1')
        .replaceAll(RegExp(r'`(.*?)`'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .trim();
  }
}

/// The primary CTA — drives the silent in-app install path. Owns its
/// own ephemeral state for the in-flight spinner so we don't lift the
/// whole dialog into a StatefulWidget.
class _DownloadAndInstallButton extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _DownloadAndInstallButton({required this.updateInfo});

  @override
  State<_DownloadAndInstallButton> createState() =>
      _DownloadAndInstallButtonState();
}

class _DownloadAndInstallButtonState extends State<_DownloadAndInstallButton> {
  /// Three states: idle → downloading → installing. Stays simple on
  /// purpose — silent install, no progress UI per spec.
  _Stage _stage = _Stage.idle;
  String? _errorText;

  bool get _busy => _stage == _Stage.downloading || _stage == _Stage.installing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (_stage) {
      _Stage.idle => 'Update Now',
      _Stage.downloading => 'Downloading…',
      _Stage.installing => 'Installing…',
      _Stage.done => 'Opening…',
      _Stage.failed => 'Try again',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.download),
          label: Text(label),
        ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _errorText!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _run() async {
    setState(() {
      _stage = _Stage.downloading;
      _errorText = null;
    });
    try {
      final handle = await UpdateService.downloadApk(
        url: widget.updateInfo.downloadUrl,
        version: widget.updateInfo.version,
      );
      if (!mounted) return;

      setState(() => _stage = _Stage.installing);
      final launched = await UpdateService.triggerInstall(apkFile: handle.file);
      if (!mounted) return;

      if (launched) {
        // Hand control to the system installer. Close the dialog.
        // The user resumes the app at the new version after install.
        Navigator.of(context).pop();
        return;
      }
      // Fallback path: installer did not start. Try browser handoff.
      await _fallbackToBrowser();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _errorText = 'Update failed. Try again.';
      });
      debugPrint('[UpdateDialog] In-app install threw: $e');
    }
  }

  Future<void> _fallbackToBrowser() async {
    final url = widget.updateInfo.downloadUrl;
    final success = await UpdateService.openDownloadUrl(url);
    if (!mounted) return;

    if (success) {
      // Browser opens; close the dialog so the user returns to feed.
      Navigator.of(context).pop();
    } else {
      setState(() {
        _stage = _Stage.failed;
        _errorText = "Couldn't open download. Open in browser instead.";
      });
    }
  }
}

/// Stages for `_DownloadAndInstallButton`.
enum _Stage { idle, downloading, installing, done, failed }

/// Show update dialog and handle user response.
///
/// Backwards-compatible with the call site in `feed_screen.dart`
/// (`UpdateService.checkForUpdates` → `showUpdateDialog(context: ...,
/// updateInfo)`) — same name, same args.
Future<void> showUpdateDialog({
  required BuildContext context,
  required UpdateInfo updateInfo,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => UpdateDialog(
      updateInfo: updateInfo,
      onLater: () => Navigator.pop(context),
      onDownload: () {
        // The dialog itself owns the install flow (stateful button).
        // This callback is preserved for backwards-compat with the
        // previous API surface; nothing to do here.
      },
    ),
  );
}

import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../services/apk_downloader.dart';
import '../services/installation_service.dart';
import '../utils/helpers.dart';

enum UpdateDialogState { available, downloading, downloaded, installing }

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdateDialogState _state = UpdateDialogState.available;
  double _progress = 0.0;
  int _bytesDownloaded = 0;
  int _totalBytes = 0;
  String _errorMessage = '';
  String? _apkPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final releaseDate = _formatReleaseDate(widget.updateInfo.releaseDate);

    return PopScope(
      canPop: _state != UpdateDialogState.downloading,
      onPopInvoked: (didPop) {
        if (didPop && _state == UpdateDialogState.downloading) {
          // Don't allow dismissing during download
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download in progress. Please wait or cancel.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _buildTitle(theme),
        content: _buildContent(theme, releaseDate),
        actions: _buildActions(theme),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    String titleText;
    IconData titleIcon;

    switch (_state) {
      case UpdateDialogState.available:
        titleText = 'Update Available';
        titleIcon = Icons.system_update;
        break;
      case UpdateDialogState.downloading:
        titleText = 'Downloading Update...';
        titleIcon = Icons.download;
        break;
      case UpdateDialogState.downloaded:
        titleText = 'Download Complete';
        titleIcon = Icons.check_circle;
        break;
      case UpdateDialogState.installing:
        titleText = 'Installing...';
        titleIcon = Icons.install_mobile;
        break;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _state == UpdateDialogState.downloading
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
          ),
          child: Icon(
            titleIcon,
            color: _state == UpdateDialogState.downloading
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titleText,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme, String releaseDate) {
    if (_state == UpdateDialogState.downloading) {
      return _buildDownloadingContent(theme);
    }

    if (_state == UpdateDialogState.downloaded && _apkPath != null) {
      return _buildDownloadedContent(theme);
    }

    // Default content for available/downloaded states
    return SingleChildScrollView(
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
              'Version ${widget.updateInfo.version}',
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
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
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
                  _formatReleaseNotes(widget.updateInfo.releaseNotes),
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
    );
  }

  Widget _buildDownloadingContent(ThemeData theme) {
    final progressPercent = _totalBytes > 0
        ? (_bytesDownloaded / _totalBytes * 100).toStringAsFixed(0)
        : '0';

    final downloadedSize = ApkDownloader.getFileSize(_bytesDownloaded);
    final totalSize = _totalBytes > 0
        ? ApkDownloader.getFileSize(_totalBytes)
        : 'Calculating...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Progress: $progressPercent%',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: theme.colorScheme.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(
 theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Downloading: $downloadedSize / $totalSize',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadedContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ready to install',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Version ${widget.updateInfo.version} has been downloaded successfully.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
        ),
        ),
      ],
    );
  }

  List<Widget> _buildActions(ThemeData theme) {
    switch (_state) {
      case UpdateDialogState.available:
        return [
          TextButton(
            onPressed: () async {
              // Confirm before ignoring
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Skip this update?'),
                  content: Text(
                    'You won\'t be notified about version ${widget.updateInfo.version} again. You can still update later from Settings.',
            ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
              ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                    child: const Text('Skip'),
                    ),
                  ],
              ),
              );

              if (confirm == true && context.mounted) {
                await UpdateService.ignoreVersion(widget.updateInfo.version);
            Navigator.pop(context);
              }
            },
            child: const Text('Skip'),
          ),
          FilledButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.download),
            label: const Text('Install'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ];

      case UpdateDialogState.downloading:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: null, // Disabled during download
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            label: const Text('Installing'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ];

      case UpdateDialogState.downloaded:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: _installApk,
            icon: const Icon(Icons.install_mobile),
            label: const Text('Install Now'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ];

      case UpdateDialogState.installing:
        return [
          TextButton(
            onPressed: null, // Can't dismiss during install
child: const Text('Please wait'),
          ),
        ];
    }
  }

  /// Start downloading the APK
  Future<void> _startDownload() async {
    setState(() {
      _state = UpdateDialogState.downloading;
      _progress = 0.0;
      _bytesDownloaded = 0;
      _totalBytes = 0;
      _errorMessage = '';
    });

    try {
      final result = await ApkDownloader.downloadApk(
        widget.updateInfo.downloadUrl,
        onProgress: (received, total) {
          setState(() {
    _bytesDownloaded = received;
            _totalBytes = total;
            _progress = total > 0 ? received / total : 0.0;
          });
        },
      );

      if (result.success && result.filePath != null) {
        setState(() {
          _state = UpdateDialogState.downloaded;
          _apkPath = result.filePath;
          _progress = 1.0;
});
      } else {
        setState(() {
        _state = UpdateDialogState.available;
          _errorMessage = result.errorMessage ?? 'Download failed';
        });
      }
    } catch (e) {
      setState(() {
        _state = UpdateDialogState.available;
        _errorMessage = 'Download error: ${e.toString()}';
      });
    }
  }

  /// Install the downloaded APK
  Future<void> _installApk() async {
    if (_apkPath == null) {
      setState(() {
        _errorMessage = 'No APK file found';
      });
      return;
    }

    setState(() {
      _state = UpdateDialogState.installing;
    });

    try {
      final success = await InstallationService.installApk(_apkPath!);

      if (success) {
        // Close dialog since system installer has taken over
        if (context.mounted) {
  Navigator.pop(context);
        }
      } else {
        setState(() {
          _state = UpdateDialogState.downloaded;
          _errorMessage = 'Failed to launch installer';
   });
      }
    } catch (e) {
      setState(() {
        _state = UpdateDialogState.downloaded;
    _errorMessage = 'Installation error: ${e.toString()}';
      });
    }
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
    // Remove markdown formatting for better display
    return notes
.replaceAll(RegExp(r'^[\s]*#+\s*', multiLine: true), '') // Remove headers
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1') // Remove bold
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1') // Remove italic
        .replaceAll(RegExp(r'`([^`]+)`'), r'\1') // Remove code
.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'\1') // Remove links
        .trim();
  }
}

/// Show update dialog and handle user response
Future<void> showUpdateDialog({
  required BuildContext context,
  required UpdateInfo updateInfo,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
  builder: (context) => UpdateDialog(updateInfo: updateInfo),
  );
}

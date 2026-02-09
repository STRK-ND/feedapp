import 'package:flutter/material.dart';
import '../services/update_service.dart';

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
              shape: BoxShape.circle,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
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
        TextButton(
          onPressed: () async {
            // Confirm before ignoring
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
        FilledButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download),
          label: const Text('Update Now'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
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
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '') // Remove headers
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'\1') // Remove bold markdown
        .replaceAll(RegExp(r'\*(.*?)\*'), r'\1') // Remove italic markdown
        .replaceAll(RegExp(r'`(.*?)`'), r'\1') // Remove code markdown
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
    builder: (context) => UpdateDialog(
      updateInfo: updateInfo,
      onLater: () => Navigator.pop(context),
      onDownload: () async {
        Navigator.pop(context);
        final success = await UpdateService.openDownloadUrl(
          updateInfo.downloadUrl,
        );
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open download. Please visit: ${updateInfo.htmlUrl}'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => UpdateService.openDownloadUrl(updateInfo.htmlUrl),
              ),
            ),
          );
        }
      },
    ),
  );
}

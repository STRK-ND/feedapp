import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../providers/settings_notifier.dart';
import '../services/storage_service.dart';
import '../services/in_app_notification_manager.dart';
import '../services/notification_service.dart';
import '../repositories/article_repository.dart';
import '../utils/constants.dart' hide AppColors;
import '../utils/design_tokens.dart';
import '../utils/reader_theme.dart';
import '../di/service_locator.dart';
import 'sources_screen.dart' show SourcesScreen;
import 'paywall_screen.dart';

/// Settings screen with Stitch design system
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late StorageService _storageService;
  late SettingsService _settingsService;
  bool _isLoading = true;

  // Live prefs (theme, body font, edition, view mode, reader prefs)
  // are read from SettingsNotifier inside the body Consumer. These
  // mirror-fields only retain what SettingsNotifier does not own —
  // currently only the three notification toggles + the cached/saved
  // counts that surface from storage.
  bool _notificationsEnabled = true;
  bool _newArticleNotifs = true;
  bool _inAppNotifsEnabled = true;
  int _cachedArticles = 0;
  int _savedArticles = 0;

  @override
  void initState() {
    super.initState();
    _storageService = getIt<StorageService>();
    _settingsService = getIt<SettingsService>();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.initializeDefaults();

    // Batch all storage reads in parallel. Theme/reader/edition/body
    // font/etc. live in SettingsNotifier — we don't need to mirror them
    // here.
    final results = await Future.wait([
      _storageService.loadArticles(),
      _storageService.loadSavedArticles(),
      _settingsService.getInAppNotificationsEnabled(),
      _settingsService.getNotificationsEnabled(),
      _settingsService.getNewArticleNotifications(),
    ]);

    if (mounted) {
      setState(() {
        _cachedArticles = (results[0] as List).length;
        _savedArticles = (results[1] as List).length;
        _inAppNotifsEnabled = results[2] as bool;
        _notificationsEnabled = results[3] as bool;
        _newArticleNotifs = results[4] as bool;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: Text(
          'This will delete $_cachedArticles cached articles. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      await _storageService.clearAll();
      getIt<ArticleRepository>().clearCache();
      if (!mounted) return;
      setState(() {
        _cachedArticles = 0;
        _savedArticles = 0;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Cache cleared successfully')),
      );
    }
  }

  Widget _buildIntervalSelector(SettingsNotifier settings) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.timer_outlined,
          size: 20,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        'Refresh Interval',
        style: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      trailing: DropdownButton<int>(
        value: [15, 30, 60, 120].contains(settings.refreshInterval)
            ? settings.refreshInterval
            : 30,
        dropdownColor: colorScheme.surface,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.expand_more, color: colorScheme.primary),
        items: [15, 30, 60, 120].map((interval) {
          return DropdownMenuItem(
            value: interval,
            child: Text(
              '$interval min',
              style: GoogleFonts.dmSans(
                color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) async {
          if (value != null) {
            await settings.setRefreshInterval(value);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // The whole screen reacts to SettingsNotifier — theme picker hover,
    // Reading rows, Edition counter — so values reflect the moment,
    // not the moment the user landed on the screen.
    return Consumer<SettingsNotifier>(
      builder: (context, notifier, _) {
        final themeMode = notifier.themeMode;
        final edition = notifier.edition;
        final prefs = notifier.readingPrefs;
        final bodyFont = prefs.bodyFont;
        final lineHeight = prefs.lineHeight.toStringAsFixed(2);
        final fontSizePt = '${prefs.fontSize.round()} pt';
        final cachedArticles = _cachedArticles;
        final savedArticles = _savedArticles;
        final isPro = notifier.isPro;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Settings',
              style: AppType.headlineSmall(),
            ),
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildSectionHeader('Appearance'),
              _buildSettingsCard([
                _buildThemeSelector(themeMode),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.image_outlined,
                  title: 'Show Images',
                  subtitle: 'Display article images in feed',
                  value: notifier.showImages,
                  onChanged: notifier.setShowImages,
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.data_saver_off_outlined,
                  title: 'Data Saver',
                  subtitle: 'Reduce data usage by limiting image quality',
                  value: notifier.dataSaverMode,
                  onChanged: notifier.setDataSaverMode,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader('Notifications'),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: 'Push Notifications',
                  subtitle: 'Receive notifications for new content',
              value: _notificationsEnabled,
              onChanged: (value) async {
                final previous = _notificationsEnabled;
                setState(() => _notificationsEnabled = value);
                try {
                  if (value) {
                    await NotificationService.enablePushNotifications();
                  } else {
                    await NotificationService.disablePushNotifications();
                  }
                  await _settingsService.setNotificationsEnabled(value);
                } catch (_) {
                  if (!context.mounted) return;
                  setState(() => _notificationsEnabled = previous);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not reach notification server — try again',
                      ),
                    ),
                  );
                }
              },
            ),
            if (_notificationsEnabled) ...[
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.article_outlined,
                title: 'New Articles',
                subtitle: 'Notify when new articles are available',
                value: _newArticleNotifs,
                onChanged: (value) async {
                  setState(() => _newArticleNotifs = value);
                  await _settingsService.setNewArticleNotifications(value);
                  // Re-POST prefs to the worker so the server-side row
                  // reflects the change without a manual toggle of master.
                  if (_notificationsEnabled) {
                    unawaited(
                      NotificationService.enablePushNotifications()
                          .catchError((Object _) {}),
                    );
                  }
                },
                indented: true,
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'In-App Notifications',
                subtitle: 'Show notification banners inside the app',
                value: _inAppNotifsEnabled,
                onChanged: (value) async {
                  setState(() => _inAppNotifsEnabled = value);
                  InAppNotificationManager().setEnabled(value);
                  await _settingsService.setInAppNotificationsEnabled(value);
                },
                indented: true,
              ),
            ],
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Feed Settings'),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.refresh_outlined,
              title: 'Auto Refresh',
              subtitle: 'Automatically refresh feeds in background',
              value: notifier.autoRefresh,
              onChanged: notifier.setAutoRefresh,
            ),
            if (notifier.autoRefresh) ...[
              _buildDivider(),
              _buildIntervalSelector(notifier),
              _buildDivider(),
              _buildMaxArticlesSelector(notifier),
            ],
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Sources'),
          _buildSettingsCard([
            _buildActionTile(
              icon: Icons.rss_feed_outlined,
              title: 'Manage sources',
              subtitle: 'Subscribe, browse, and unsubscribe',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SourcesScreen()),
                );
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Reading'),
          _buildSettingsCard([
            _buildReaderPrefsRow(),
            _buildDivider(),
            _buildInfoTile(
              icon: Icons.text_fields_outlined,
              title: 'Body font',
              value: bodyFont == 'lora' ? 'Lora' : 'DM Sans',
            ),
            _buildDivider(),
            _buildInfoTile(
              icon: Icons.format_line_spacing_outlined,
              title: 'Line height',
              value: lineHeight,
            ),
            _buildDivider(),
            _buildInfoTile(
              icon: Icons.format_size_outlined,
              title: 'Font size',
              value: fontSizePt,
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Edition'),
          _buildSettingsCard([
            _buildEditionRow(edition),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Storage & Data'),
          _buildSettingsCard([
            _buildInfoTile(
              icon: Icons.cached_outlined,
              title: 'Cached Articles',
              value: '$cachedArticles articles',
            ),
            _buildDivider(),
            _buildInfoTile(
              icon: Icons.bookmark_outline_rounded,
              title: 'Saved Articles',
              value: '$savedArticles articles',
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Clear Cache',
              subtitle: 'Remove all cached data',
              iconColor: colorScheme.error,
              onTap: _clearCache,
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('About'),
          _buildSettingsCard([
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
                ),
                child: Icon(Icons.info_outline_rounded, size: 20, color: colorScheme.onPrimaryContainer),
              ),
              title: Text('App Version', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
              trailing: FutureBuilder<String>(
                future: AppConfig.getVersion(),
                builder: (context, snapshot) => Text(
                  'v${snapshot.data ?? '...'}',
                  style: GoogleFonts.dmSans(fontSize: 14, color: colorScheme.primary),
                ),
              ),
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.code_outlined,
              title: 'Open Source Licenses',
              subtitle: 'View third-party licenses',
              onTap: () async {
                final version = await AppConfig.getVersion();
                if (context.mounted) {
                  showLicensePage(
                    context: context,
                    applicationName: 'Curated Feeds',
                    applicationVersion: version,
                  );
                }
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Support'),
          _buildSettingsCard([
            _buildActionTile(
              icon: Icons.workspace_premium_outlined,
              title: isPro ? 'Pro' : 'Support the app',
              subtitle:
                  isPro ? 'Thanks for your support!' : 'One-time purchase, yours forever',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.bug_report_outlined,
              title: 'Report bug / Join Community',
              subtitle: 'Join our WhatsApp group',
              onTap: () async {
                final uri = Uri.parse(
                  'https://chat.whatsapp.com/BoABgXqa64BEtcgNDYaCIt',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
        },
      );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: AppType.monoEyebrow(
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ).copyWith(letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildReaderPrefsRow() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: const Icon(
          Icons.menu_book_outlined,
          size: 20,
          color: AppColors.primary,
        ),
      ),
      title: Text(
        'Reader preferences',
        style: AppType.titleMedium(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        'Tune in the article reader, any time',
        style: AppType.bodyMedium(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () => _openReaderSheet(),
    );
  }

  Future<void> _openReaderSheet() async {
    final notifier = context.read<SettingsNotifier>();
    final initial = notifier.readingPrefs;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SettingsReaderSheet(
        initial: initial,
        notifier: notifier,
      ),
    );
    // The Consumer wrapping this screen rebuilds on every notify; no
    // manual setState required.
    if (updated == true) {/* no-op: Consumer rebuild already updated */}
  }

  Widget _buildEditionRow(int edition) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          edition.toString().padLeft(2, '0').substring(0, 2),
          textAlign: TextAlign.center,
          style: AppType.folioTop(color: AppColors.primary)
              .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(
        'Edition Nº ${edition.toString().padLeft(4, '0')}',
        style: AppType.titleMedium(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        'Bumps on every refresh.',
        style: AppType.bodyMedium(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(77),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withAlpha(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _divideTiles(children),
      ),
    );
  }

  List<Widget> _divideTiles(List<Widget> tiles) {
    final result = <Widget>[];
    final colorScheme = Theme.of(context).colorScheme;
    for (var i = 0; i < tiles.length; i++) {
      result.add(tiles[i]);
      if (i < tiles.length - 1) {
        result.add(
          Divider(height: 1, indent: 72, color: colorScheme.primaryContainer),
        );
      }
    }
    return result;
  }

  Widget _buildDivider() {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      indent: 72,
      color: colorScheme.primary.withAlpha(26),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool indented = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Icon(icon, size: 20, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: textTheme.bodyMedium?.color,
        ),
      ),
      trailing: Switch(
        value: value,
        activeThumbColor: colorScheme.primary,
        onChanged: (newValue) {
          HapticFeedback.selectionClick();
          onChanged(newValue);
        },
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Icon(icon, size: 20, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      trailing: Text(
        value,
        style: GoogleFonts.dmSans(fontSize: 14, color: colorScheme.primary),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor != null
              ? iconColor.withAlpha(38)
              : colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: textTheme.bodyMedium?.color,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: textTheme.bodyMedium?.color?.withAlpha(153),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeMode themeMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final notifier = context.read<SettingsNotifier>();
    Widget tile({
      required ThemeMode mode,
      required String label,
      required Color ground,
      required Color ink,
    }) {
      final selected = themeMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => notifier.setThemeMode(mode),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: ground,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(
                color: selected ? colorScheme.primary : AppColors.rule,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppType.folioTop(color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.s2, top: AppSpacing.s2, bottom: AppSpacing.s3),
            child: Text(
              'Theme',
              style: AppType.titleMedium(),
            ),
          ),
          Row(
            children: [
              tile(
                mode: ThemeMode.light,
                label: 'PAPER',
                ground: AppColors.paperRaised,
                ink: AppColors.ink,
              ),
              const SizedBox(width: AppSpacing.s2),
              tile(
                mode: ThemeMode.dark,
                label: 'LAMPLIGHT',
                ground: AppColors.ground,
                ink: AppColors.paperOnGround,
              ),
              const SizedBox(width: AppSpacing.s2),
              tile(
                mode: ThemeMode.system,
                label: 'AUTO',
                ground: colorScheme.surfaceContainerHighest,
                ink: colorScheme.onSurface,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaxArticlesSelector(SettingsNotifier settings) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Icon(
          Icons.format_list_numbered,
          size: 20,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        'Max Articles',
        style: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      trailing: DropdownButton<int>(
        value: [100, 250, 500, 1000, 2000].contains(settings.maxArticles)
            ? settings.maxArticles
            : 500,
        dropdownColor: colorScheme.surface,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.expand_more, color: colorScheme.primary),
        items: [100, 250, 500, 1000, 2000].map((max) {
          return DropdownMenuItem(
            value: max,
            child: Text(
              '$max',
              style: GoogleFonts.dmSans(
                color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) async {
          if (value != null) {
            await settings.setMaxArticles(value);
          }
        },
      ),
    );
  }
}

/// Bottom sheet for editing reading preferences from Settings.
///
/// Mirrors the shape of the article reader's Aa panel — the same three
/// sliders (font size, line height, body font), without the theme
/// swatches. Writes go through the provided [SettingsNotifier] so any
/// open reader surface updates immediately. Returns `true` to the
/// caller so the parent can re-render its summary rows.
class _SettingsReaderSheet extends StatefulWidget {
  final ReadingPreferences initial;
  final SettingsNotifier notifier;
  const _SettingsReaderSheet({
    required this.initial,
    required this.notifier,
  });

  @override
  State<_SettingsReaderSheet> createState() => _SettingsReaderSheetState();
}

class _SettingsReaderSheetState extends State<_SettingsReaderSheet> {
  late double _fontSize = widget.initial.fontSize;
  late double _lineHeight = widget.initial.lineHeight;
  late String _bodyFont = widget.initial.bodyFont;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ground = isDark ? AppColors.groundElev : AppColors.paperRaised;
    final ink = isDark ? AppColors.paperOnGround : AppColors.ink;
    return Container(
      decoration: BoxDecoration(
        color: ground,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, -16),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s3,
        AppSpacing.s6,
        AppSpacing.s8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('Reader preferences', style: AppType.titleLarge(color: ink)),
          const SizedBox(height: AppSpacing.s5),
          _SliderRow(
            label: 'FONT SIZE',
            value: _fontSize,
            min: 14,
            max: 22,
            display: '${_fontSize.round()} PT',
            onChange: (v) async {
              setState(() => _fontSize = v);
              await widget.notifier.setFontSize(v);
            },
          ),
          const SizedBox(height: AppSpacing.s4),
          _SliderRow(
            label: 'LINE HEIGHT',
            value: _lineHeight,
            min: 1.4,
            max: 1.8,
            display: _lineHeight.toStringAsFixed(2),
            onChange: (v) async {
              setState(() => _lineHeight = v);
              await widget.notifier.setLineHeight(v);
            },
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Text(
                'BODY FONT',
                style: AppType.monoEyebrow(
                  color: isDark
                      ? AppColors.paperOnGroundSoft
                      : AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Container(
            decoration: BoxDecoration(
              color: AppColors.paperRaised,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: AppColors.rule),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _FontSegment(
                  label: 'DM SANS',
                  selected: _bodyFont == 'dm',
                  onTap: () async {
                    setState(() => _bodyFont = 'dm');
                    await widget.notifier.setBodyFont('dm');
                  },
                ),
                _FontSegment(
                  label: 'LORA',
                  selected: _bodyFont == 'lora',
                  onTap: () async {
                    setState(() => _bodyFont = 'lora');
                    await widget.notifier.setBodyFont('lora');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: Text(
              'DONE',
              style: AppType.labelLarge(color: Colors.white)
                  .copyWith(letterSpacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChange;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft =
        isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: AppType.monoEyebrow(color: soft)
                    .copyWith(letterSpacing: 0.8)),
            const Spacer(),
            Text(display,
                style: AppType.monoDateline(color: AppColors.primary)
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.primary.withValues(alpha: 0.2),
          onChanged: onChange,
        ),
      ],
    );
  }
}

class _FontSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FontSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: selected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppType.monoEyebrow(
              color: selected ? AppColors.primary : AppColors.inkSoft,
            ).copyWith(letterSpacing: 0.6),
          ),
        ),
      ),
    );
  }
}

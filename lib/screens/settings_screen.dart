import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../providers/settings_notifier.dart';
import '../services/storage_service.dart';
import '../services/in_app_notification_manager.dart';
import '../services/notification_service.dart';
import '../services/background_sync_service.dart';
import '../repositories/article_repository.dart';
import '../utils/constants.dart' hide AppColors;
import '../utils/design_tokens.dart';
import '../utils/reader_theme.dart';
import '../di/service_locator.dart';
import 'sources_screen.dart' show SourcesScreen;
import 'paywall_screen.dart';
import 'login_screen.dart';

/// Settings screen with Stitch design system
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context);
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
  List<String> _notifCategories = const [];
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
      _settingsService.getNotificationCategories(),
    ]);

    if (mounted) {
      setState(() {
        _cachedArticles = (results[0] as List).length;
        _savedArticles = (results[1] as List).length;
        _inAppNotifsEnabled = results[2] as bool;
        _notificationsEnabled = results[3] as bool;
        _newArticleNotifs = results[4] as bool;
        _notifCategories = results[5] as List<String>;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.clearCacheDialogTitle),
        content: Text(
          _l10n.clearCacheDialogBody(_cachedArticles),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_l10n.dialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(_l10n.dialogClearAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      // Targeted clear: only the fetched feed cache goes. clearAll() would
      // also wipe savedArticles — user data — under a "cache" label.
      await _storageService.clearFeedCache();
      getIt<ArticleRepository>().clearCache();
      if (!mounted) return;
      setState(() {
        _cachedArticles = 0;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(_l10n.cacheClearedSnack)),
      );
    }
  }

  String _categorySubtitle() {
    final all = AppConfig.categories.where((c) => c != 'All').toList();
    if (_notifCategories.isEmpty || _notifCategories.length == all.length) {
      return _l10n.alertCategoriesAll;
    }
    return _notifCategories.join(', ');
  }

  /// Multi-select picker for which categories trigger new-article pushes.
  /// Saving re-POSTs /subscribe so the worker's stored row narrows future
  /// announcements for this device.
  Future<void> _editNotificationCategories() async {
    final all = AppConfig.categories.where((c) => c != 'All').toList();
    final selected = Set<String>.from(
      _notifCategories.isEmpty ? all : _notifCategories,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(_l10n.alertCategoriesTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final cat in all)
                  CheckboxListTile(
                    value: selected.contains(cat),
                    onChanged: (v) => setDialogState(
                      () => v == true
                          ? selected.add(cat)
                          : selected.remove(cat),
                    ),
                    title: Text(cat),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_l10n.dialogCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_l10n.dialogSaveAction),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final next = selected.toList();
    await _settingsService.setNotificationCategories(next);
    if (!mounted) return;
    setState(() => _notifCategories = next);
    if (_notificationsEnabled && _newArticleNotifs) {
      try {
        await NotificationService.enablePushNotifications();
      } catch (_) {
        // Server sync failed silently; prefs apply on next app start.
      }
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
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.timer_outlined,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        _l10n.refreshIntervalTitle,
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
        icon: Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
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
            // Keep the OS-level periodic job's frequency in sync; the
            // cancel+register in scheduleBackgroundSync replaces the job.
            unawaited(scheduleBackgroundSync(_settingsService));
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
            title: Text(_l10n.settingsTitle, style: AppType.headlineSmall()),
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildSectionHeader(_l10n.sectionAccount),
              const _AccountCard(),
              const SizedBox(height: 24),
              _buildSectionHeader(_l10n.sectionAppearance),
              _buildSettingsCard([
                _buildThemeSelector(themeMode),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.image_outlined,
                  title: _l10n.showImagesTitle,
                  subtitle: _l10n.showImagesSubtitle,
                  value: notifier.showImages,
                  onChanged: notifier.setShowImages,
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.data_saver_off_outlined,
                  title: _l10n.dataSaverTitle,
                  subtitle: _l10n.dataSaverSubtitle,
                  value: notifier.dataSaverMode,
                  onChanged: notifier.setDataSaverMode,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(_l10n.sectionNotifications),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: _l10n.pushNotificationsTitle,
                  subtitle: _l10n.pushNotificationsSubtitle,
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
                        SnackBar(
                          content: Text(_l10n.pushServerFailSnack),
                        ),
                      );
                    }
                  },
                ),
                if (_notificationsEnabled) ...[
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.article_outlined,
                    title: _l10n.newArticlesTitle,
                    subtitle: _l10n.newArticlesSubtitle,
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
                  if (_newArticleNotifs) ...[
                    _buildDivider(),
                    _buildActionTile(
                      icon: Icons.filter_list_rounded,
                      title: _l10n.alertCategoriesTitle,
                      subtitle: _categorySubtitle(),
                      onTap: _editNotificationCategories,
                    ),
                  ],
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.notifications_active_outlined,
                    title: _l10n.inAppNotifsTitle,
                    subtitle: _l10n.inAppNotifsSubtitle,
                    value: _inAppNotifsEnabled,
                    onChanged: (value) async {
                      setState(() => _inAppNotifsEnabled = value);
                      InAppNotificationManager().setEnabled(value);
                      await _settingsService.setInAppNotificationsEnabled(
                        value,
                      );
                    },
                    indented: true,
                  ),
                ],
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(_l10n.sectionFeedSettings),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.refresh_outlined,
                  title: _l10n.autoRefreshTitle,
                  subtitle: _l10n.autoRefreshSubtitle,
                  value: notifier.autoRefresh,
                  onChanged: (value) async {
                    await notifier.setAutoRefresh(value);
                    unawaited(scheduleBackgroundSync(_settingsService));
                  },
                ),
                if (notifier.autoRefresh) ...[
                  _buildDivider(),
                  _buildIntervalSelector(notifier),
                  _buildDivider(),
                  _buildMaxArticlesSelector(notifier),
                ],
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(_l10n.sectionSources),
              _buildSettingsCard([
                _buildActionTile(
                  icon: Icons.rss_feed_outlined,
                  title: _l10n.manageSourcesTitle,
                  subtitle: _l10n.manageSourcesSubtitle,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SourcesScreen()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(_l10n.sectionReading),
              _buildSettingsCard([
                _buildReaderPrefsRow(),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.text_fields_outlined,
                  title: _l10n.bodyFontTitle,
                  value: bodyFont == 'lora' ? 'Lora' : 'DM Sans',
                ),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.format_line_spacing_outlined,
                  title: _l10n.lineHeightTitle,
                  value: lineHeight,
                ),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.format_size_outlined,
                  title: _l10n.fontSizeTitle,
                  value: fontSizePt,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(_l10n.sectionEdition),
              _buildSettingsCard([_buildEditionRow(edition)]),
              const SizedBox(height: 24),
              _buildSectionHeader(_l10n.sectionStorage),
              _buildSettingsCard([
                _buildInfoTile(
                  icon: Icons.cached_outlined,
                  title: _l10n.cachedArticlesTitle,
                  value: '$cachedArticles articles',
                ),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.bookmark_outline_rounded,
                  title: _l10n.savedArticlesCountTitle,
                  value: '$savedArticles articles',
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: _l10n.clearCacheTitle,
                  subtitle: _l10n.clearCacheSubtitle,
                  iconColor: colorScheme.error,
                  onTap: _clearCache,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(_l10n.sectionAbout),
              _buildSettingsCard([
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        AppCardStyles.badgeRadius,
                      ),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    _l10n.appVersionTitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  trailing: FutureBuilder<String>(
                    future: AppConfig.getVersion(),
                    builder: (context, snapshot) => Text(
                      'v${snapshot.data ?? '...'}',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.code_outlined,
                  title: _l10n.openSourceLicensesTitle,
                  subtitle: _l10n.openSourceLicensesSubtitle,
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
              _buildSectionHeader(_l10n.sectionSupport),
              _buildSettingsCard([
                _buildActionTile(
                  icon: Icons.workspace_premium_outlined,
                  title: isPro ? _l10n.proBadge : _l10n.supportAppTitle,
                  subtitle: isPro
                      ? _l10n.thanksSupportSubtitle
                      : _l10n.supportOneTimeSubtitle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.bug_report_outlined,
                  title: _l10n.reportBugTitle,
                  subtitle: AppConfig.supportEmail,
                  onTap: () async {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: AppConfig.supportEmail,
                      queryParameters: {'subject': 'Curated Feeds — Feedback'},
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else if (context.mounted) {
                      // No mail client — copy the address to the clipboard so
                      // the user can paste it anywhere.
                      await Clipboard.setData(
                        const ClipboardData(text: AppConfig.supportEmail),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_l10n.emailCopiedSnack),
                        ),
                      );
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
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Icon(
          Icons.menu_book_outlined,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        _l10n.readerPrefsTitle,
        style: AppType.titleMedium(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        _l10n.readerPrefsSubtitle,
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
      builder: (ctx) =>
          _SettingsReaderSheet(initial: initial, notifier: notifier),
    );
    // The Consumer wrapping this screen rebuilds on every notify; no
    // manual setState required.
    if (updated == true) {
      /* no-op: Consumer rebuild already updated */
    }
  }

  Widget _buildEditionRow(int edition) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          edition.toString().padLeft(2, '0').substring(0, 2),
          textAlign: TextAlign.center,
          style: AppType.folioTop(
            color: colorScheme.onSurface,
          ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(
        _l10n.editionNumberLabel(edition.toString().padLeft(4, '0')),
        style: AppType.titleMedium(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        _l10n.editionBumpsHint,
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
        border: Border.all(color: colorScheme.outline),
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
          Divider(height: 1, indent: 72, color: colorScheme.outline),
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
      color: colorScheme.outline,
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
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
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
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
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
        style: GoogleFonts.dmSans(fontSize: 14, color: colorScheme.onSurfaceVariant),
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
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? colorScheme.onSurfaceVariant,
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
                color: selected ? colorScheme.primary : colorScheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.folioTop(color: ink)),
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
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.s2,
              top: AppSpacing.s2,
              bottom: AppSpacing.s3,
            ),
            child: Text(_l10n.themeRowLabel, style: AppType.titleMedium()),
          ),
          Row(
            children: [
              tile(
                mode: ThemeMode.light,
                label: _l10n.roomPaperLabel,
                ground: AppColors.paperRaised,
                ink: AppColors.ink,
              ),
              const SizedBox(width: AppSpacing.s2),
              tile(
                mode: ThemeMode.dark,
                label: _l10n.roomLamplightLabel,
                ground: AppColors.ground,
                ink: AppColors.paperOnGround,
              ),
              const SizedBox(width: AppSpacing.s2),
              tile(
                mode: ThemeMode.system,
                label: _l10n.themeAutoLabel,
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
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Icon(
          Icons.format_list_numbered,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        _l10n.maxArticlesLabel,
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
        icon: Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
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
  const _SettingsReaderSheet({required this.initial, required this.notifier});

  @override
  State<_SettingsReaderSheet> createState() => _SettingsReaderSheetState();
}

class _SettingsReaderSheetState extends State<_SettingsReaderSheet> {
  AppLocalizations get _l10n => AppLocalizations.of(context);

  late double _fontSize = widget.initial.fontSize;
  late double _lineHeight = widget.initial.lineHeight;
  late String _bodyFont = widget.initial.bodyFont;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ground = isDark ? AppColors.groundElev : AppColors.paperRaised;
    final ink = isDark ? AppColors.paperOnGround : AppColors.ink;
    final ruleColor = isDark ? AppColors.ruleOnGround : AppColors.rule;
    return Container(
      decoration: BoxDecoration(
        color: ground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheetTop),
        ),
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
                color: ruleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(_l10n.readerPrefsTitle, style: AppType.titleLarge(color: ink)),
          const SizedBox(height: AppSpacing.s5),
          _SliderRow(
            label: _l10n.fontSizeLabel,
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
            label: _l10n.lineHeightLabel,
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
              color: isDark ? AppColors.ground : AppColors.paperRaised,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: ruleColor),
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
              style: AppType.labelLarge(
                color: Colors.white,
              ).copyWith(letterSpacing: 1.4),
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
    final soft = isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppType.monoEyebrow(
                color: soft,
              ).copyWith(letterSpacing: 0.8),
            ),
            const Spacer(),
            Text(
              display,
              style: AppType.monoDateline(
                color: AppColors.primary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
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
              color: selected
                  ? AppColors.primary
                  : (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.paperOnGroundSoft
                      : AppColors.inkSoft),
            ).copyWith(letterSpacing: 0.6),
          ),
        ),
      ),
    );
  }
}

/// Account section — sign-in entry point when signed out; avatar, name,
/// email and sign-out when signed in. Listens to authStateChanges so it
/// updates the moment sign-in/out completes anywhere in the app.
class _AccountCard extends StatefulWidget {
  const _AccountCard();

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  StreamSubscription<User?>? _sub;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<AuthService>()) {
      _sub = getIt<AuthService>().authStateChanges.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _confirmSignOut() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOutTitle),
        content: Text(l10n.signOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.signOutConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await getIt<AuthService>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasAuth = getIt.isRegistered<AuthService>();
    final user = hasAuth ? getIt<AuthService>().currentUser : null;

    final tile = user == null
        ? ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Icon(
                Icons.person_outline,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              l10n.loginTitle,
              style: AppType.titleMedium(color: colorScheme.onSurface),
            ),
            subtitle: Text(
              l10n.accountSignedOutSubtitle,
              style: AppType.bodyMedium(color: colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            onTap: hasAuth ? _openLogin : null,
          )
        : ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 20,
              backgroundImage:
                  (user.photoURL != null && user.photoURL!.isNotEmpty)
                      ? NetworkImage(user.photoURL!)
                      : null,
              child: (user.photoURL == null || user.photoURL!.isEmpty)
                  ? Text(
                      (user.displayName?.isNotEmpty ?? false)
                          ? user.displayName![0].toUpperCase()
                          : '?',
                      style: AppType.titleMedium(color: colorScheme.onSurface),
                    )
                  : null,
            ),
            title: Text(
              user.displayName?.isNotEmpty ?? false
                  ? user.displayName!
                  : (user.email ?? ''),
              style: AppType.titleMedium(color: colorScheme.onSurface),
            ),
            subtitle: Text(
              user.email ?? '',
              style: AppType.bodyMedium(color: colorScheme.onSurfaceVariant),
            ),
            trailing: TextButton(
              onPressed: _confirmSignOut,
              child: Text(l10n.accountSignOut),
            ),
          );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(77),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [tile],
      ),
    );
  }
}

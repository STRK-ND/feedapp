import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/stitch/stitch_widgets.dart';

/// Settings screen with Stitch design system
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsService _settingsService;
  late StorageService _storageService;
  bool _isLoading = true;

  // Settings values
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  bool _newArticleNotifs = true;
  bool _autoRefresh = true;
  int _refreshInterval = 30;
  int _maxArticles = 500;
  bool _showImages = true;
  bool _dataSaverMode = false;
  int _cachedArticles = 0;
  int _savedArticles = 0;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService();
    _storageService = StorageService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.initializeDefaults();

    final articles = await _storageService.loadArticles();
    final savedArticlesList = await _storageService.loadSavedArticles();
    final themeMode = await _settingsService.getThemeMode();

    setState(() {
      _themeMode = themeMode;
      _notificationsEnabled = true;
      _newArticleNotifs = true;
      _autoRefresh = true;
      _refreshInterval = 30;
      _maxArticles = 500;
      _showImages = true;
      _dataSaverMode = false;
      _cachedArticles = articles.length;
      _savedArticles = savedArticlesList.length;
      _isLoading = false;
    });
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await _settingsService.setThemeMode(mode);
    if (mounted) {
      context.read<ThemeProvider>().setThemeMode(mode);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: Text('This will delete $_cachedArticles cached articles. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _storageService.clearAll();
      setState(() {
        _cachedArticles = 0;
        _savedArticles = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.lexend(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Appearance'),
          _buildSettingsCard([
            _buildThemeSelector(),
            _buildDivider(),
            _buildSwitchTile(
              icon: Icons.image_outlined,
              title: 'Show Images',
              subtitle: 'Display article images in feed',
              value: _showImages,
              onChanged: (value) async {
                setState(() => _showImages = value);
                await _settingsService.setShowImages(value);
              },
            ),
            _buildDivider(),
            _buildSwitchTile(
              icon: Icons.data_saver_off_outlined,
              title: 'Data Saver',
              subtitle: 'Reduce data usage by limiting image quality',
              value: _dataSaverMode,
              onChanged: (value) async {
                setState(() => _dataSaverMode = value);
                await _settingsService.setDataSaverMode(value);
              },
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
                setState(() => _notificationsEnabled = value);
                await _settingsService.setNotificationsEnabled(value);
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
              value: _autoRefresh,
              onChanged: (value) async {
                setState(() => _autoRefresh = value);
                await _settingsService.setAutoRefresh(value);
              },
            ),
            if (_autoRefresh) ...[
              _buildDivider(),
              _buildIntervalSelector(),
              _buildDivider(),
              _buildMaxArticlesSelector(),
            ],
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Storage & Data'),
          _buildSettingsCard([
            _buildInfoTile(
              icon: Icons.cached_outlined,
              title: 'Cached Articles',
              value: '$_cachedArticles articles',
            ),
            _buildDivider(),
            _buildInfoTile(
              icon: Icons.bookmark_outline_rounded,
              title: 'Saved Articles',
              value: '$_savedArticles articles',
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Clear Cache',
              subtitle: 'Remove all cached data',
              iconColor: AppColors.error,
              onTap: _clearCache,
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('About'),
          _buildSettingsCard([
            _buildInfoTile(
              icon: Icons.info_outline_rounded,
              title: 'App Version',
              value: 'v${AppConfig.appVersion}',
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.code_outlined,
              title: 'Open Source Licenses',
              subtitle: 'View third-party licenses',
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'Curated Feeds',
                  applicationVersion: AppConfig.appVersion,
                );
              },
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.lexend(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest?.withAlpha(26) ?? colorScheme.surface.withAlpha(26),
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
        result.add(Divider(
          height: 1,
          indent: 72,
          color: colorScheme.primary.withAlpha(26),
        ));
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
          color: colorScheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: colorScheme.primary),
      ),
      title: Text(
        title,
        style: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.lexend(
          fontSize: 12,
          color: textTheme.bodyMedium?.color,
        ),
      ),
      trailing: Switch(
        value: value,
        activeColor: colorScheme.primary,
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
          color: colorScheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: colorScheme.primary),
      ),
      title: Text(
        title,
        style: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      trailing: Text(
        value,
        style: GoogleFonts.lexend(
          fontSize: 14,
          color: colorScheme.primary,
        ),
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
          color: (iconColor ?? colorScheme.primary).withAlpha(38),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? colorScheme.primary),
      ),
      title: Text(
        title,
        style: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.lexend(
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

  Widget _buildThemeSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _getThemeIcon(_themeMode),
          size: 20,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        'Theme',
        style: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      trailing: DropdownButton<ThemeMode>(
        value: _themeMode,
        dropdownColor: colorScheme.surface,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        icon: Icon(Icons.expand_more, color: colorScheme.primary),
        items: [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('System', style: GoogleFonts.lexend(color: textTheme.bodyLarge?.color ?? colorScheme.onSurface)),
          ),
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text('Light', style: GoogleFonts.lexend(color: textTheme.bodyLarge?.color ?? colorScheme.onSurface)),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text('Dark', style: GoogleFonts.lexend(color: textTheme.bodyLarge?.color ?? colorScheme.onSurface)),
          ),
        ],
        onChanged: (mode) {
          if (mode != null) _saveThemeMode(mode);
        },
      ),
    );
  }

  Widget _buildIntervalSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.timer_outlined, size: 20, color: colorScheme.primary),
      ),
      title: Text(
        'Refresh Interval',
        style: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      trailing: DropdownButton<int>(
        value: _refreshInterval,
        dropdownColor: colorScheme.surface,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.expand_more, color: colorScheme.primary),
        items: [15, 30, 60, 120].map((interval) {
          return DropdownMenuItem(
            value: interval,
            child: Text(
              '$interval min',
              style: GoogleFonts.lexend(color: textTheme.bodyLarge?.color ?? colorScheme.onSurface, fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _refreshInterval = value);
            _settingsService.setRefreshInterval(value);
          }
        },
      ),
    );
  }

  Widget _buildMaxArticlesSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.format_list_numbered, size: 20, color: colorScheme.primary),
      ),
      title: Text(
        'Max Articles',
        style: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
        ),
      ),
      trailing: DropdownButton<int>(
        value: _maxArticles,
        dropdownColor: colorScheme.surface,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.expand_more, color: colorScheme.primary),
        items: [100, 250, 500, 1000, 2000].map((max) {
          return DropdownMenuItem(
            value: max,
            child: Text(
              '$max',
              style: GoogleFonts.lexend(color: textTheme.bodyLarge?.color ?? colorScheme.onSurface, fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _maxArticles = value);
            _settingsService.setMaxArticles(value);
          }
        },
      ),
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }
}

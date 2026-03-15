import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// Full-featured Settings Screen
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

    // Load article counts from storage service
    final articles = await _storageService.loadArticles();
    final savedArticlesList = await _storageService.loadSavedArticles();

    // Load theme mode
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
        content: Text('This will delete $_cachedArticles cached articles and $_savedArticles saved articles. This action cannot be undone.'),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF190F23), Color(0xFF2D2F73), Color(0xFF4A3B5C)],
              )
            : null,
        color: isDark ? null : AppColors.backgroundLight,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Settings',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : theme.textTheme.titleLarge?.color,
              letterSpacing: -0.5,
            ),
          ),
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : theme.iconTheme.color,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ==================== APPEARANCE ====================
            _buildSectionHeader('Appearance', isDark),
            _buildSettingsCard([
              _buildThemeSelector(isDark),
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
                isDark: isDark,
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
                isDark: isDark,
              ),
            ], isDark),

            const SizedBox(height: 24),

            // ==================== NOTIFICATIONS ====================
            _buildSectionHeader('Notifications', isDark),
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
                isDark: isDark,
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
                  isDark: isDark,
                  indented: true,
                ),
              ],
            ], isDark),

            const SizedBox(height: 24),

            // ==================== FEED SETTINGS ====================
            _buildSectionHeader('Feed Settings', isDark),
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
                isDark: isDark,
              ),
              if (_autoRefresh) ...[
                _buildDivider(),
                _buildIntervalSelector(isDark),
                _buildDivider(),
                _buildMaxArticlesSelector(isDark),
              ],
            ], isDark),

            const SizedBox(height: 24),

            // ==================== STORAGE ====================
            _buildSectionHeader('Storage & Data', isDark),
            _buildSettingsCard([
              _buildInfoTile(
                icon: Icons.cached_outlined,
                title: 'Cached Articles',
                value: '$_cachedArticles articles',
                isDark: isDark,
              ),
              _buildDivider(),
              _buildInfoTile(
                icon: Icons.bookmark_outline_rounded,
                title: 'Saved Articles',
                value: '$_savedArticles articles',
                isDark: isDark,
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Clear Cache',
                subtitle: 'Remove all cached data',
                iconColor: AppColors.error,
                onTap: _clearCache,
                isDark: isDark,
              ),
            ], isDark),

            const SizedBox(height: 24),

            // ==================== ABOUT ====================
            _buildSectionHeader('About', isDark),
            _buildSettingsCard([
              _buildInfoTile(
                icon: Icons.info_outline_rounded,
                title: 'App Version',
                value: 'v${AppConfig.appVersion}',
                isDark: isDark,
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
                isDark: isDark,
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'View our privacy policy',
                onTap: () {
                  // Open privacy policy
                },
                isDark: isDark,
              ),
            ], isDark),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.accent : AppColors.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha:  0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha:  0.1)
                : AppColors.divider.withValues(alpha:  0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:  isDark ? 0.3 : 0.05),
              blurRadius: isDark ? 20 : 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: AppColors.divider.withValues(alpha:  0.3),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    bool indented = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha:  isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: isDark ? AppColors.accent : AppColors.primary),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
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
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha:  isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: isDark ? AppColors.accent : AppColors.primary),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      trailing: Text(
        value,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withValues(alpha:  isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? (isDark ? AppColors.accent : AppColors.primary)),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white38 : AppColors.textTertiary,
      ),
    );
  }

  Widget _buildThemeSelector(bool isDark) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha:  isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _getThemeIcon(_themeMode),
          size: 20,
          color: isDark ? AppColors.accent : AppColors.primary,
        ),
      ),
      title: Text(
        'Theme',
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        _getThemeLabel(_themeMode),
        style: GoogleFonts.dmSans(
          fontSize: 13,
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
      trailing: PopupMenuButton<ThemeMode>(
        initialValue: _themeMode,
        onSelected: _saveThemeMode,
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        itemBuilder: (context) => [
          _buildThemeMenuItem(ThemeMode.system, 'System Default', Icons.settings_suggest_outlined, isDark),
          _buildThemeMenuItem(ThemeMode.light, 'Light', Icons.light_mode_outlined, isDark),
          _buildThemeMenuItem(ThemeMode.dark, 'Dark', Icons.dark_mode_outlined, isDark),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getThemeLabel(_themeMode),
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: isDark ? Colors.white38 : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<ThemeMode> _buildThemeMenuItem(
    ThemeMode mode,
    String label,
    IconData icon,
    bool isDark,
  ) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.white70 : AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector(bool isDark) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha:  isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.timer_outlined, size: 20, color: isDark ? AppColors.accent : AppColors.primary),
      ),
      title: Text(
        'Refresh Interval',
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        'Every $_refreshInterval minutes',
        style: GoogleFonts.dmSans(
          fontSize: 13,
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
      trailing: PopupMenuButton<int>(
        initialValue: _refreshInterval,
        onSelected: (value) async {
          setState(() => _refreshInterval = value);
          await _settingsService.setRefreshInterval(value);
        },
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        itemBuilder: (context) => [
          for (final interval in [15, 30, 60, 120, 240])
            PopupMenuItem(
              value: interval,
              child: Text('$interval minutes'),
            ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_refreshInterval min',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: isDark ? Colors.white38 : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaxArticlesSelector(bool isDark) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha:  isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.inventory_2_outlined, size: 20, color: isDark ? AppColors.accent : AppColors.primary),
      ),
      title: Text(
        'Max Cached Articles',
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        'Keep $_maxArticles articles in cache',
        style: GoogleFonts.dmSans(
          fontSize: 13,
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
      trailing: PopupMenuButton<int>(
        initialValue: _maxArticles,
        onSelected: (value) async {
          setState(() => _maxArticles = value);
          await _settingsService.setMaxArticles(value);
        },
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        itemBuilder: (context) => [
          for (final count in [100, 250, 500, 1000, 2000])
            PopupMenuItem(
              value: count,
              child: Text('$count articles'),
            ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_maxArticles',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: isDark ? Colors.white38 : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.settings_suggest_outlined;
    }
  }
}
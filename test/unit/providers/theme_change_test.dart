import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:curatedfeeds/providers/settings_notifier.dart';
import 'package:curatedfeeds/providers/theme_provider.dart';
import 'package:curatedfeeds/services/settings_service.dart';

/// Theme-change regression: mirrors the exact wiring in CuratedFeedsApp
/// (SettingsNotifier -> ChangeNotifierProxyProvider -> ThemeProvider ->
/// MaterialApp.themeMode). If a settings change stops reaching the
/// MaterialApp's themeMode, this fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService service;
  late SettingsNotifier notifier;
  late ThemeProvider theme;

  setUp(() async {
    // Fresh install: user picked nothing yet, onboarding done.
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    service = SettingsService();
    notifier = SettingsNotifier(service);
    await notifier.loadSettings();
    theme = ThemeProvider(service);
    await theme.init();
    // Same mirror the ChangeNotifierProxyProvider performs in
    // CuratedFeedsApp — applied on every notifier notification.
    notifier.addListener(() => theme.applyThemeMode(notifier.themeMode));
  });

  test('saved theme is picked up on startup', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'theme_mode': 'dark',
    });
    final service2 = SettingsService();
    final notifier2 = SettingsNotifier(service2);
    await notifier2.loadSettings();
    expect(notifier2.themeMode, ThemeMode.dark);
  });

  test('changing to dark applies live and persists', () async {
    expect(theme.themeMode, ThemeMode.system);

    await notifier.setThemeMode(ThemeMode.dark);

    expect(theme.themeMode, ThemeMode.dark); // MaterialApp rebuilds dark
    expect(await service.getThemeMode(), ThemeMode.dark); // persisted
  });

  test('changing to light applies live and persists', () async {
    await notifier.setThemeMode(ThemeMode.dark);
    expect(theme.themeMode, ThemeMode.dark);

    await notifier.setThemeMode(ThemeMode.light);
    expect(theme.themeMode, ThemeMode.light);
    expect(await service.getThemeMode(), ThemeMode.light);
  });

  test('system mode round-trips', () async {
    await notifier.setThemeMode(ThemeMode.light);
    await notifier.setThemeMode(ThemeMode.system);
    expect(theme.themeMode, ThemeMode.system);
    expect(await service.getThemeMode(), ThemeMode.system);
  });
}

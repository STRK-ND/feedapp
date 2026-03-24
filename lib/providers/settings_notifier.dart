import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsNotifier extends ChangeNotifier {
  final SettingsService _settingsService;

  bool _showImages = true;
  bool _dataSaverMode = false;
  bool _autoRefresh = true;
  int _refreshInterval = 30;
  int _maxArticles = 500;

  SettingsNotifier(this._settingsService);

  bool get showImages => _showImages;
  bool get dataSaverMode => _dataSaverMode;
  bool get autoRefresh => _autoRefresh;
  int get refreshInterval => _refreshInterval;
  int get maxArticles => _maxArticles;

  int get imageMaxWidth => _dataSaverMode ? 400 : 800;

  Future<void> loadSettings() async {
    _showImages = await _settingsService.getShowImages();
    _dataSaverMode = await _settingsService.getDataSaverMode();
    _autoRefresh = await _settingsService.getAutoRefresh();
    _refreshInterval = await _settingsService.getRefreshInterval();
    _maxArticles = await _settingsService.getMaxArticles();
    notifyListeners();
  }

  Future<void> setShowImages(bool value) async {
    _showImages = value;
    await _settingsService.setShowImages(value);
    notifyListeners();
  }

  Future<void> setDataSaverMode(bool value) async {
    _dataSaverMode = value;
    await _settingsService.setDataSaverMode(value);
    notifyListeners();
  }

  Future<void> setAutoRefresh(bool value) async {
    _autoRefresh = value;
    await _settingsService.setAutoRefresh(value);
    notifyListeners();
  }

  Future<void> setRefreshInterval(int value) async {
    _refreshInterval = value;
    await _settingsService.setRefreshInterval(value);
    notifyListeners();
  }

  Future<void> setMaxArticles(int value) async {
    _maxArticles = value;
    await _settingsService.setMaxArticles(value);
    notifyListeners();
  }
}

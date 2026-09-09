import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsStore {
  SettingsStore({this._prefs});

  static const usernameKey = 'username';
  static const afmKey = 'afm';
  static const subscriptionKeyKey = 'subscription_key';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<AppSettings> load() async {
    final prefs = await _ensurePrefs();
    return AppSettings(
      username: prefs.getString(usernameKey) ?? '',
      afm: prefs.getString(afmKey) ?? '',
      subscriptionKey: prefs.getString(subscriptionKeyKey) ?? '',
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(usernameKey, settings.username);
    await prefs.setString(afmKey, settings.afm);
    await prefs.setString(subscriptionKeyKey, settings.subscriptionKey);
  }
}

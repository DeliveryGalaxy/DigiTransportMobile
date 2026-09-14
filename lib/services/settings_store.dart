import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsStore {
  SettingsStore({this._prefs});

  static const usernameKey = 'username';
  static const afmKey = 'afm';
  static const subscriptionKeyKey = 'subscription_key';
  static const environmentKey = 'aade_environment';
  static const lastVehicleNumberKey = 'last_vehicle_number';
  static const lastTransportTypeKey = 'last_transport_type';
  static const lastTrailerNumberKey = 'last_trailer_number';

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
      environment: AadeEnvironment.fromStorage(prefs.getString(environmentKey)),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(usernameKey, settings.username);
    await prefs.setString(afmKey, settings.afm);
    await prefs.setString(subscriptionKeyKey, settings.subscriptionKey);
    await prefs.setString(environmentKey, settings.environment.name);
  }

  Future<String> loadLastVehicleNumber() async {
    final prefs = await _ensurePrefs();
    return prefs.getString(lastVehicleNumberKey) ?? '';
  }

  Future<int> loadLastTransportType() async {
    final prefs = await _ensurePrefs();
    return prefs.getInt(lastTransportTypeKey) ?? 2;
  }

  Future<String> loadLastTrailerNumber() async {
    final prefs = await _ensurePrefs();
    return prefs.getString(lastTrailerNumberKey) ?? '';
  }

  Future<void> saveLastVehicle({
    required String vehicleNumber,
    required int transportType,
    String? trailerNumber,
  }) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(lastVehicleNumberKey, vehicleNumber);
    await prefs.setInt(lastTransportTypeKey, transportType);
    await prefs.setString(lastTrailerNumberKey, trailerNumber ?? '');
  }
}

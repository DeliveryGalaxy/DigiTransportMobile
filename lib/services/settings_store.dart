import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsStore {
  SettingsStore({this._prefs});

  static const usernameKey = 'username';
  static const afmKey = 'afm';
  static const subscriptionKeyKey = 'subscription_key';
  static const environmentKey = 'aade_environment';
  static const tokenKey = 'api_token';
  static const companyIdKey = 'company_id';
  static const companyConfirmedKey = 'company_confirmed';
  static const companyNameKey = 'company_name';
  static const companyAfmKey = 'company_afm';
  static const firstNameKey = 'first_name';
  static const lastNameKey = 'last_name';
  static const identityUserIdKey = 'identity_user_id';
  static const pinKey = 'identity_pin';
  static const isMetaforikiKey = 'is_metaforiki';
  static const isContainerKey = 'is_container';
  static const isOtherKey = 'is_other';
  static const isMetaforeasKey = 'is_metaforeas';
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
      token: prefs.getString(tokenKey) ?? '',
      companyId: prefs.getInt(companyIdKey) ?? 0,
      companyConfirmed: prefs.getBool(companyConfirmedKey) ?? false,
      companyName: prefs.getString(companyNameKey) ?? '',
      companyAfm: prefs.getString(companyAfmKey) ?? '',
      firstName: prefs.getString(firstNameKey) ?? '',
      lastName: prefs.getString(lastNameKey) ?? '',
      identityUserId: prefs.getString(identityUserIdKey) ?? '',
      pin: prefs.getString(pinKey) ?? '',
      isMetaforiki: prefs.getBool(isMetaforikiKey) ?? false,
      isContainer: prefs.getBool(isContainerKey) ?? false,
      isOther: prefs.getBool(isOtherKey) ?? false,
      isMetaforeas: prefs.getBool(isMetaforeasKey) ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(usernameKey, settings.username);
    await prefs.setString(afmKey, settings.afm);
    await prefs.setString(subscriptionKeyKey, settings.subscriptionKey);
    await prefs.setString(environmentKey, settings.environment.name);
    await prefs.remove('api_environment');
    await prefs.setString(tokenKey, settings.token);
    await prefs.setInt(companyIdKey, settings.companyId);
    await prefs.setBool(companyConfirmedKey, settings.companyConfirmed);
    await prefs.setString(companyNameKey, settings.companyName);
    await prefs.setString(companyAfmKey, settings.companyAfm);
    await prefs.setString(firstNameKey, settings.firstName);
    await prefs.setString(lastNameKey, settings.lastName);
    await prefs.setString(identityUserIdKey, settings.identityUserId);
    await prefs.setString(pinKey, settings.pin);
    await prefs.setBool(isMetaforikiKey, settings.isMetaforiki);
    await prefs.setBool(isContainerKey, settings.isContainer);
    await prefs.setBool(isOtherKey, settings.isOther);
    await prefs.setBool(isMetaforeasKey, settings.isMetaforeas);
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

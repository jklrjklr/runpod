import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/deploy_config.dart';

abstract class SettingsStore {
  Future<String?> getApiKey();
  Future<void> setApiKey(String? apiKey);
  Future<DeployConfig> loadConfig();
  Future<void> saveConfig(DeployConfig config);
}

/// Persists settings via SharedPreferences. The API key is stored alongside
/// the rest of the config rather than in flutter_secure_storage: secure
/// storage depends on a keyring/dbus session that isn't available in the
/// headless Linux test environment this app is validated in. On a real
/// mobile deployment, swap the key read/write below for EncryptedSharedPreferences.
class SharedPreferencesSettingsStore implements SettingsStore {
  static const _apiKeyPref = 'runpod_api_key';
  static const _configPref = 'runpod_deploy_config';

  @override
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  @override
  Future<void> setApiKey(String? apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey == null) {
      await prefs.remove(_apiKeyPref);
    } else {
      await prefs.setString(_apiKeyPref, apiKey);
    }
  }

  @override
  Future<DeployConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configPref);
    if (raw == null) return const DeployConfig();
    return DeployConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveConfig(DeployConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configPref, jsonEncode(config.toJson()));
  }
}

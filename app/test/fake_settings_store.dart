import 'package:runpod_manager/data/settings_store.dart';
import 'package:runpod_manager/models/deploy_config.dart';

class FakeSettingsStore implements SettingsStore {
  String? _apiKey;
  DeployConfig _config = const DeployConfig();
  String? _sshKeyPem;

  @override
  Future<String?> getApiKey() async => _apiKey;

  @override
  Future<void> setApiKey(String? apiKey) async => _apiKey = apiKey;

  @override
  Future<DeployConfig> loadConfig() async => _config;

  @override
  Future<void> saveConfig(DeployConfig config) async => _config = config;

  @override
  Future<String?> getSshPrivateKeyPem() async => _sshKeyPem;

  @override
  Future<void> setSshPrivateKeyPem(String pem) async => _sshKeyPem = pem;
}

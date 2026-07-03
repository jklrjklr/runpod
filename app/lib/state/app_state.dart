import 'package:flutter/foundation.dart';

import '../data/runpod_client.dart';
import '../data/settings_store.dart';
import '../domain/deploy_retry_handler.dart';
import '../domain/ssh_key_manager.dart';
import '../models/deploy_config.dart';
import '../models/gpu_pricing.dart';
import '../models/gpu_type.dart';
import '../models/pod.dart';
import '../models/pod_template.dart';

class AppState extends ChangeNotifier {
  final RunPodClient client;
  final SettingsStore store;
  final Duration Function(int attempt)? retryBackoff;
  final SshKeyManager sshKeyManager;

  AppState({required this.client, required this.store, this.retryBackoff})
      : sshKeyManager = SshKeyManager(store);

  bool initialized = false;
  String? apiKey;
  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;

  DeployConfig config = const DeployConfig();

  bool loadingBrowseData = false;
  String? browseError;
  List<GpuType> gpuTypes = [];
  List<PodTemplate> templates = [];

  bool deploying = false;
  int deployAttempt = 0;
  int deployMaxRetry = 0;
  String? deployError;
  Pod? currentPod;

  Future<void> init() async {
    apiKey = await store.getApiKey();
    config = await store.loadConfig();
    initialized = true;
    notifyListeners();
  }

  Future<bool> submitApiKey(String key) async {
    final valid = await client.validateApiKey(key);
    if (valid) {
      apiKey = key;
      await store.setApiKey(key);
      notifyListeners();
    }
    return valid;
  }

  Future<void> signOut() async {
    apiKey = null;
    await store.setApiKey(null);
    notifyListeners();
  }

  Future<void> loadBrowseData() async {
    loadingBrowseData = true;
    browseError = null;
    notifyListeners();
    try {
      gpuTypes = await client.listGpuTypes(apiKey!);
      templates = await client.listTemplates(apiKey!);
    } catch (e) {
      browseError = e.toString();
    } finally {
      loadingBrowseData = false;
      notifyListeners();
    }
  }

  final Map<String, GpuPricing> _pricingCache = {};

  Future<GpuPricing> getGpuPricing(GpuType gpu) async {
    final cached = _pricingCache[gpu.id];
    if (cached != null) return cached;
    final pricing = await client.getGpuPricing(
      apiKey!,
      gpuId: gpu.id,
      gpuCount: config.gpuCount,
      secureCloud: config.cloudType != CloudType.community,
    );
    _pricingCache[gpu.id] = pricing;
    return pricing;
  }

  Future<void> selectGpu(String gpuId) => _updateConfig((c) => c.copyWith(selectedGpuTypeId: gpuId));

  Future<void> selectTemplate(String templateId) =>
      _updateConfig((c) => c.copyWith(selectedTemplateId: templateId));

  Future<void> updateConfig(DeployConfig Function(DeployConfig current) update) => _updateConfig(update);

  Future<void> _updateConfig(DeployConfig Function(DeployConfig current) update) async {
    config = update(config);
    await store.saveConfig(config);
    notifyListeners();
  }

  Future<void> deploy() async {
    deploying = true;
    deployError = null;
    deployAttempt = 0;
    deployMaxRetry = config.maxRetryCount;
    currentPod = null;
    notifyListeners();

    final sshIdentity = await sshKeyManager.ensureIdentity();

    final handler = DeployRetryHandler(client: client, backoff: retryBackoff);
    final result = await handler.deploy(
      apiKey!,
      config,
      onAttempt: (attempt, max) {
        deployAttempt = attempt;
        deployMaxRetry = max;
        notifyListeners();
      },
      env: {'PUBLIC_KEY': sshIdentity.publicKeyOpenSsh},
    );

    deploying = false;
    if (result.isSuccess) {
      currentPod = result.pod;
    } else {
      deployError = result.error;
    }
    notifyListeners();
  }

  Future<void> refreshPodStatus() async {
    if (currentPod == null) return;
    currentPod = await client.getPodStatus(apiKey!, currentPod!.id);
    notifyListeners();
  }

  Future<void> stopCurrentPod() async {
    if (currentPod == null) return;
    await client.stopPod(apiKey!, currentPod!.id);
    currentPod = await client.getPodStatus(apiKey!, currentPod!.id);
    notifyListeners();
  }

  Future<void> terminateCurrentPod() async {
    if (currentPod == null) return;
    await client.terminatePod(apiKey!, currentPod!.id);
    currentPod = null;
    notifyListeners();
  }

  void clearDeployedPod() {
    currentPod = null;
    deployError = null;
    notifyListeners();
  }
}

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

  /// Set when the last submitApiKey() call failed due to a network/transport
  /// error rather than RunPod rejecting the key, so the UI can show the real
  /// cause instead of a misleading "invalid key" message.
  String? lastAuthError;

  Future<bool> submitApiKey(String key) async {
    lastAuthError = null;
    try {
      final valid = await client.validateApiKey(key);
      if (valid) {
        apiKey = key;
        await store.setApiKey(key);
        notifyListeners();
      }
      return valid;
    } catch (e) {
      lastAuthError = e.toString();
      return false;
    }
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
      await _preloadGpuPricing();
    } catch (e) {
      browseError = e.toString();
    } finally {
      loadingBrowseData = false;
      notifyListeners();
    }
  }

  final Map<String, GpuPricing> _pricingCache = {};

  String _priceKey(String gpuId, bool secureCloud) => '${gpuId}_${secureCloud ? 'secure' : 'community'}';

  /// Synchronous lookup for already-loaded pricing, used by list widgets so
  /// sorting/filtering doesn't need a FutureBuilder per tile. Populated by
  /// [_preloadGpuPricing] during [loadBrowseData].
  GpuPricing? cachedPricing(String gpuId, bool secureCloud) => _pricingCache[_priceKey(gpuId, secureCloud)];

  Future<GpuPricing> getGpuPricing(GpuType gpu, {required bool secureCloud}) async {
    final key = _priceKey(gpu.id, secureCloud);
    final cached = _pricingCache[key];
    if (cached != null) return cached;
    GpuPricing pricing;
    try {
      pricing = await client.getGpuPricing(
        apiKey!,
        gpuId: gpu.id,
        gpuCount: config.gpuCount,
        secureCloud: secureCloud,
      );
    } catch (_) {
      pricing = GpuPricing.unavailable;
    }
    _pricingCache[key] = pricing;
    return pricing;
  }

  Future<void> _preloadGpuPricing() async {
    final futures = <Future<GpuPricing>>[];
    for (final gpu in gpuTypes) {
      if (gpu.secureCloud) futures.add(getGpuPricing(gpu, secureCloud: true));
      if (gpu.communityCloud) futures.add(getGpuPricing(gpu, secureCloud: false));
    }
    await Future.wait(futures);
  }

  Future<void> selectGpu(String gpuId, {required bool secureCloud}) => _updateConfig(
        (c) => c.copyWith(
          selectedGpuTypeId: gpuId,
          cloudType: secureCloud ? CloudType.secure : CloudType.community,
        ),
      );

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
      _upsertPod(result.pod!);
    } else {
      deployError = result.error;
    }
    notifyListeners();
  }

  Future<void> refreshPodStatus() async {
    if (currentPod == null) return;
    currentPod = await refreshPod(currentPod!.id);
  }

  Future<void> stopCurrentPod() async {
    if (currentPod == null) return;
    await stopPod(currentPod!.id);
  }

  Future<void> terminateCurrentPod() async {
    if (currentPod == null) return;
    await terminatePod(currentPod!.id);
    currentPod = null;
  }

  void clearDeployedPod() {
    currentPod = null;
    deployError = null;
    notifyListeners();
  }

  // --- Pods tab: manage every pod on the account, not just the one just deployed ---

  bool loadingPods = false;
  String? podsError;
  List<Pod> pods = [];

  Future<void> loadPods() async {
    loadingPods = true;
    podsError = null;
    notifyListeners();
    try {
      pods = await client.listPods(apiKey!);
    } catch (e) {
      podsError = e.toString();
    } finally {
      loadingPods = false;
      notifyListeners();
    }
  }

  void _upsertPod(Pod pod) {
    final index = pods.indexWhere((p) => p.id == pod.id);
    if (index == -1) {
      pods = [pod, ...pods];
    } else {
      pods = [...pods]..[index] = pod;
    }
  }

  Future<Pod> refreshPod(String podId) async {
    final pod = await client.getPodStatus(apiKey!, podId);
    if (currentPod?.id == podId) currentPod = pod;
    _upsertPod(pod);
    notifyListeners();
    return pod;
  }

  Future<void> stopPod(String podId) async {
    await client.stopPod(apiKey!, podId);
    await refreshPod(podId);
  }

  Future<void> resumePod(String podId, {int gpuCount = 1}) async {
    await client.resumePod(apiKey!, podId, gpuCount);
    await refreshPod(podId);
  }

  Future<void> terminatePod(String podId) async {
    await client.terminatePod(apiKey!, podId);
    pods = pods.where((p) => p.id != podId).toList();
    if (currentPod?.id == podId) currentPod = null;
    notifyListeners();
  }
}

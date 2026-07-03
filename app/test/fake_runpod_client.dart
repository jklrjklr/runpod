import 'package:runpod_manager/data/runpod_client.dart';
import 'package:runpod_manager/models/deploy_config.dart';
import 'package:runpod_manager/models/gpu_pricing.dart';
import 'package:runpod_manager/models/gpu_type.dart';
import 'package:runpod_manager/models/pod.dart';
import 'package:runpod_manager/models/pod_template.dart';

/// In-memory fake standing in for the real RunPod HTTP API so the app's
/// screens and retry logic can be driven end-to-end without a real API key
/// or network access.
class FakeRunPodClient implements RunPodClient {
  final String validApiKey;
  int deployNullResponsesBeforeSuccess;
  bool failValidation = false;
  int deployCallCount = 0;
  Map<String, String>? lastDeployEnv;
  String? terminatedPodId;

  final Map<String, Pod> _pods = {};

  FakeRunPodClient({
    this.validApiKey = 'test-api-key',
    this.deployNullResponsesBeforeSuccess = 0,
    List<Pod> initialPods = const [],
  }) {
    for (final pod in initialPods) {
      _pods[pod.id] = pod;
    }
  }

  @override
  Future<bool> validateApiKey(String apiKey) async {
    if (failValidation) return false;
    return apiKey == validApiKey;
  }

  @override
  Future<List<GpuType>> listGpuTypes(String apiKey) async {
    return const [
      GpuType(
        id: 'NVIDIA H100 80GB HBM3',
        displayName: 'H100 80GB HBM3',
        memoryInGb: 80,
        secureCloud: true,
        communityCloud: false,
      ),
      GpuType(
        id: 'NVIDIA RTX 4090',
        displayName: 'RTX 4090',
        memoryInGb: 24,
        secureCloud: true,
        communityCloud: true,
      ),
      GpuType(
        id: 'NVIDIA RTX 3070',
        displayName: 'RTX 3070',
        memoryInGb: 8,
        secureCloud: false,
        communityCloud: true,
      ),
    ];
  }

  @override
  Future<GpuPricing> getGpuPricing(
    String apiKey, {
    required String gpuId,
    required int gpuCount,
    required bool secureCloud,
  }) async {
    switch (gpuId) {
      case 'NVIDIA H100 80GB HBM3':
        return const GpuPricing(
          stockStatus: StockStatus.low,
          minimumBidPrice: 1.5,
          uninterruptablePrice: 2.9,
          availableGpuCounts: 1,
        );
      case 'NVIDIA RTX 4090':
        return GpuPricing(
          stockStatus: secureCloud ? StockStatus.high : StockStatus.none,
          minimumBidPrice: secureCloud ? 0.5 : 0.35,
          uninterruptablePrice: secureCloud ? 0.7 : 0.5,
          availableGpuCounts: secureCloud ? 4 : 0,
        );
      case 'NVIDIA RTX 3070':
        return const GpuPricing(
          stockStatus: StockStatus.high,
          minimumBidPrice: 0.13,
          uninterruptablePrice: 0.2,
          availableGpuCounts: 8,
        );
      default:
        return GpuPricing.unavailable;
    }
  }

  @override
  Future<List<PodTemplate>> listTemplates(String apiKey) async {
    return const [
      PodTemplate(
        id: 'tmpl-pytorch',
        name: 'PyTorch 2.4',
        imageName: 'runpod/pytorch:2.4',
        isPublic: true,
      ),
      PodTemplate(
        id: 'tmpl-tensorflow',
        name: 'TensorFlow 2.16',
        imageName: 'runpod/tensorflow:2.16',
        isPublic: true,
      ),
      PodTemplate(
        id: 'tmpl-my-custom',
        name: 'My Custom Template',
        imageName: 'myregistry/custom:latest',
      ),
    ];
  }

  @override
  Future<Pod?> deployPod(String apiKey, DeployConfig config, {Map<String, String>? env}) async {
    deployCallCount += 1;
    lastDeployEnv = env;
    if (deployCallCount <= deployNullResponsesBeforeSuccess) {
      return null;
    }
    final pod = Pod(
      id: 'pod-123',
      imageName: config.selectedTemplateId,
      machineId: 'machine-1',
      desiredStatus: 'RUNNING',
      gpuCount: config.gpuCount,
      costPerHr: 0.5,
      gpuDisplayName: config.selectedGpuTypeId,
      runtime: const PodRuntime(
        uptimeInSeconds: 5,
        ports: [
          PodPort(ip: '1.2.3.4', publicPort: 8888, privatePort: 8888, type: 'http'),
          PodPort(ip: '1.2.3.4', publicPort: 22022, privatePort: 22, type: 'tcp'),
        ],
        gpus: [
          PodGpuUtil(id: 'gpu-0', gpuUtilPercent: 10, memoryUtilPercent: 20),
        ],
      ),
    );
    _pods[pod.id] = pod;
    return pod;
  }

  @override
  Future<Pod> getPodStatus(String apiKey, String podId) async {
    final existing = _pods[podId];
    if (existing != null) return existing;
    return Pod(
      id: podId,
      desiredStatus: 'RUNNING',
      runtime: const PodRuntime(
        uptimeInSeconds: 42,
        ports: [
          PodPort(ip: '1.2.3.4', publicPort: 8888, privatePort: 8888, type: 'http'),
          PodPort(ip: '1.2.3.4', publicPort: 22022, privatePort: 22, type: 'tcp'),
        ],
        gpus: [
          PodGpuUtil(id: 'gpu-0', gpuUtilPercent: 15, memoryUtilPercent: 25),
        ],
      ),
    );
  }

  @override
  Future<List<Pod>> listPods(String apiKey) async => _pods.values.toList();

  @override
  Future<void> stopPod(String apiKey, String podId) async {
    final pod = _pods[podId] ?? await getPodStatus(apiKey, podId);
    _pods[podId] = _withStatus(pod, 'EXITED');
  }

  @override
  Future<void> resumePod(String apiKey, String podId, int gpuCount) async {
    final pod = _pods[podId] ?? await getPodStatus(apiKey, podId);
    _pods[podId] = _withStatus(pod, 'RUNNING');
  }

  @override
  Future<void> terminatePod(String apiKey, String podId) async {
    terminatedPodId = podId;
    _pods.remove(podId);
  }

  Pod _withStatus(Pod pod, String status) => Pod(
        id: pod.id,
        name: pod.name,
        imageName: pod.imageName,
        machineId: pod.machineId,
        desiredStatus: status,
        runtime: pod.runtime,
        costPerHr: pod.costPerHr,
        gpuCount: pod.gpuCount,
        vcpuCount: pod.vcpuCount,
        memoryInGb: pod.memoryInGb,
        gpuDisplayName: pod.gpuDisplayName,
      );
}

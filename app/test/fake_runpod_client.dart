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

  String? stoppedPodId;

  FakeRunPodClient({
    this.validApiKey = 'test-api-key',
    this.deployNullResponsesBeforeSuccess = 0,
  });

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
    ];
  }

  @override
  Future<GpuPricing> getGpuPricing(
    String apiKey, {
    required String gpuId,
    required int gpuCount,
    required bool secureCloud,
  }) async {
    return const GpuPricing(
      stockStatus: StockStatus.high,
      minimumBidPrice: 0.2,
      uninterruptablePrice: 0.4,
      availableGpuCounts: 4,
    );
  }

  @override
  Future<List<PodTemplate>> listTemplates(String apiKey) async {
    return const [
      PodTemplate(id: 'tmpl-pytorch', name: 'PyTorch 2.4', imageName: 'runpod/pytorch:2.4'),
      PodTemplate(id: 'tmpl-tensorflow', name: 'TensorFlow 2.16', imageName: 'runpod/tensorflow:2.16'),
    ];
  }

  @override
  Future<Pod?> deployPod(String apiKey, DeployConfig config) async {
    deployCallCount += 1;
    if (deployCallCount <= deployNullResponsesBeforeSuccess) {
      return null;
    }
    return Pod(
      id: 'pod-123',
      imageName: config.selectedTemplateId,
      machineId: 'machine-1',
      desiredStatus: 'RUNNING',
      runtime: const PodRuntime(
        uptimeInSeconds: 5,
        ports: [
          PodPort(ip: '1.2.3.4', publicPort: 8888, privatePort: 8888, type: 'http'),
        ],
        gpus: [
          PodGpuUtil(id: 'gpu-0', gpuUtilPercent: 10, memoryUtilPercent: 20),
        ],
      ),
    );
  }

  @override
  Future<Pod> getPodStatus(String apiKey, String podId) async {
    return Pod(
      id: podId,
      desiredStatus: stoppedPodId == podId ? 'EXITED' : 'RUNNING',
      runtime: const PodRuntime(
        uptimeInSeconds: 42,
        ports: [
          PodPort(ip: '1.2.3.4', publicPort: 8888, privatePort: 8888, type: 'http'),
        ],
        gpus: [
          PodGpuUtil(id: 'gpu-0', gpuUtilPercent: 15, memoryUtilPercent: 25),
        ],
      ),
    );
  }

  @override
  Future<void> stopPod(String apiKey, String podId) async {
    stoppedPodId = podId;
  }

  @override
  Future<void> resumePod(String apiKey, String podId, int gpuCount) async {
    stoppedPodId = null;
  }

  String? terminatedPodId;

  @override
  Future<void> terminatePod(String apiKey, String podId) async {
    terminatedPodId = podId;
  }
}

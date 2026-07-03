import '../data/runpod_client.dart';
import '../models/deploy_config.dart';
import '../models/pod.dart';

class DeployResult {
  final Pod? pod;
  final int attempts;
  final String? error;

  const DeployResult.success(this.pod, this.attempts) : error = null;
  const DeployResult.failure(this.error, this.attempts) : pod = null;

  bool get isSuccess => pod != null;
}

typedef AttemptCallback = void Function(int attempt, int maxRetryCount);

class DeployRetryHandler {
  final RunPodClient client;
  final Duration Function(int attempt) backoff;

  DeployRetryHandler({
    required this.client,
    Duration Function(int attempt)? backoff,
  }) : backoff = backoff ?? _defaultBackoff;

  static Duration _defaultBackoff(int attempt) {
    return Duration(seconds: 1 << attempt); // 2s, 4s, 8s...
  }

  /// RunPod frequently returns HTTP 200 with a null pod id (e.g. no stock)
  /// rather than an HTTP error, so a null result is treated as retryable
  /// just like a thrown exception.
  Future<DeployResult> deploy(
    String apiKey,
    DeployConfig config, {
    AttemptCallback? onAttempt,
    Map<String, String>? env,
  }) async {
    var attempt = 0;
    while (true) {
      onAttempt?.call(attempt, config.maxRetryCount);
      try {
        final pod = await client.deployPod(apiKey, config, env: env);
        if (pod != null) {
          return DeployResult.success(pod, attempt + 1);
        }
      } catch (e) {
        if (attempt >= config.maxRetryCount) {
          return DeployResult.failure(e.toString(), attempt + 1);
        }
      }
      attempt += 1;
      if (attempt > config.maxRetryCount) {
        return DeployResult.failure('Exceeded max retries (no stock available)', attempt);
      }
      await Future.delayed(backoff(attempt));
    }
  }
}

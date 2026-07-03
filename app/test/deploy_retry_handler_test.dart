import 'package:flutter_test/flutter_test.dart';
import 'package:runpod_manager/domain/deploy_retry_handler.dart';
import 'package:runpod_manager/models/deploy_config.dart';

import 'fake_runpod_client.dart';

void main() {
  group('DeployRetryHandler', () {
    test('succeeds on first attempt when pod id is returned', () async {
      final client = FakeRunPodClient();
      final handler = DeployRetryHandler(client: client, backoff: (_) => Duration.zero);

      final result = await handler.deploy('test-api-key', const DeployConfig(maxRetryCount: 3));

      expect(result.isSuccess, isTrue);
      expect(result.attempts, 1);
      expect(result.pod!.id, 'pod-123');
    });

    test('retries when RunPod returns a null id and eventually succeeds', () async {
      final client = FakeRunPodClient(deployNullResponsesBeforeSuccess: 2);
      final handler = DeployRetryHandler(client: client, backoff: (_) => Duration.zero);
      final seenAttempts = <int>[];

      final result = await handler.deploy(
        'test-api-key',
        const DeployConfig(maxRetryCount: 3),
        onAttempt: (attempt, max) => seenAttempts.add(attempt),
      );

      expect(result.isSuccess, isTrue);
      expect(result.attempts, 3);
      expect(seenAttempts, [0, 1, 2]);
    });

    test('fails after exceeding max retry count', () async {
      final client = FakeRunPodClient(deployNullResponsesBeforeSuccess: 100);
      final handler = DeployRetryHandler(client: client, backoff: (_) => Duration.zero);

      final result = await handler.deploy('test-api-key', const DeployConfig(maxRetryCount: 2));

      expect(result.isSuccess, isFalse);
      expect(result.attempts, 3); // initial attempt + 2 retries
      expect(client.deployCallCount, 3);
    });
  });
}

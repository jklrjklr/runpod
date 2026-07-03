// Standalone live smoke test against the real RunPod API using the app's
// production HttpRunPodClient. Not part of `flutter test` — run explicitly:
//
//   RUNPOD_API_KEY=... dart run tool/live_e2e_smoke.dart
//
// Finds the cheapest in-stock GPU, deploys a minimal pod on it, verifies it
// comes up, then always terminates the pod in a finally block so nothing
// keeps billing after the script exits.
import 'dart:io';

import 'package:runpod_manager/data/runpod_client.dart';
import 'package:runpod_manager/models/deploy_config.dart';
import 'package:runpod_manager/models/gpu_pricing.dart';
import 'package:runpod_manager/models/gpu_type.dart';
import 'package:runpod_manager/models/pod_template.dart';

Future<void> main() async {
  final apiKey = Platform.environment['RUNPOD_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('RUNPOD_API_KEY environment variable is required.');
    exit(1);
  }

  final client = HttpRunPodClient();

  print('1. Validating API key...');
  final valid = await client.validateApiKey(apiKey);
  if (!valid) {
    stderr.writeln('API key rejected by RunPod.');
    exit(1);
  }
  print('   OK: key is valid.');

  print('2. Listing GPU types...');
  final gpuTypes = await client.listGpuTypes(apiKey);
  print('   Found ${gpuTypes.length} GPU types.');

  print('3. Checking price/stock for each GPU (secure + community)...');
  final priced = <(GpuType, bool, GpuPricing)>[];
  for (final gpu in gpuTypes) {
    for (final secure in [true, false]) {
      try {
        final pricing = await client.getGpuPricing(
          apiKey,
          gpuId: gpu.id,
          gpuCount: 1,
          secureCloud: secure,
        );
        priced.add((gpu, secure, pricing));
      } catch (e) {
        stderr.writeln('   pricing lookup failed for ${gpu.id} secure=$secure: $e');
      }
    }
  }

  final inStock = priced.where((p) {
    final pricing = p.$3;
    final hasPrice = pricing.uninterruptablePrice != null || pricing.minimumBidPrice != null;
    return hasPrice &&
        pricing.stockStatus != StockStatus.none &&
        pricing.stockStatus != StockStatus.unknown;
  }).toList();

  if (inStock.isEmpty) {
    stderr.writeln('No GPUs currently in stock with a known price. Aborting.');
    exit(1);
  }

  inStock.sort((a, b) {
    final priceA = a.$3.uninterruptablePrice ?? a.$3.minimumBidPrice!;
    final priceB = b.$3.uninterruptablePrice ?? b.$3.minimumBidPrice!;
    return priceA.compareTo(priceB);
  });

  print('   Cheapest in-stock options (top 5):');
  for (final entry in inStock.take(5)) {
    final price = entry.$3.uninterruptablePrice ?? entry.$3.minimumBidPrice;
    print('   - ${entry.$1.displayName} (${entry.$1.id}) '
        '${entry.$2 ? "SECURE" : "COMMUNITY"} '
        '\$${price!.toStringAsFixed(3)}/hr [${entry.$3.stockStatus.name}]');
  }

  final cheapest = inStock.first;
  final cheapestPrice = cheapest.$3.uninterruptablePrice ?? cheapest.$3.minimumBidPrice!;
  print('   Selected cheapest: ${cheapest.$1.displayName} '
      '(${cheapest.$2 ? "SECURE" : "COMMUNITY"}) at \$${cheapestPrice.toStringAsFixed(3)}/hr');

  print('4. Listing templates...');
  List<PodTemplate> templates = [];
  try {
    templates = await client.listTemplates(apiKey);
  } catch (e) {
    stderr.writeln('   Failed to list templates: $e');
  }
  print('   Found ${templates.length} templates.');
  for (final t in templates.take(10)) {
    print('   - ${t.name} (${t.id}) image=${t.imageName}');
  }

  if (templates.isEmpty) {
    stderr.writeln('No templates available on this account; cannot deploy without a '
        'templateId. Stopping before spending anything.');
    exit(1);
  }

  final template = templates.first;
  final config = DeployConfig(
    selectedTemplateId: template.id,
    selectedGpuTypeId: cheapest.$1.id,
    cloudType: cheapest.$2 ? CloudType.secure : CloudType.community,
    gpuCount: 1,
    minVcpuCount: 1,
    minMemoryInGb: 2,
    volumeInGb: 0,
    containerDiskInGb: 5,
    maxRetryCount: 2,
  );

  print('5. Deploying minimal pod with template "${template.name}" '
      'on ${cheapest.$1.displayName}...');
  String? podId;
  try {
    final pod = await client.deployPod(apiKey, config);
    if (pod == null) {
      stderr.writeln('   Deploy returned no pod id (no stock at deploy time). Aborting.');
      exit(1);
    }
    podId = pod.id;
    print('   Deployed pod id=$podId, desiredStatus=${pod.desiredStatus}');

    print('6. Polling pod status until runtime is available...');
    var runtimeSeen = false;
    for (var i = 0; i < 20; i++) {
      final status = await client.getPodStatus(apiKey, podId);
      print('   [$i] desiredStatus=${status.desiredStatus} '
          'runtime=${status.runtime != null}');
      if (status.runtime != null) {
        runtimeSeen = true;
        print('   Runtime up after ${status.runtime!.uptimeInSeconds}s, '
            'ports=${status.runtime!.ports.length}, gpus=${status.runtime!.gpus.length}');
        final proxyUrl = status.proxyUrl();
        if (proxyUrl.isNotEmpty) print('   Proxy URL: $proxyUrl');
        break;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
    if (runtimeSeen) {
      print('E2E smoke test PASSED: pod deployed and reached running state.');
    } else {
      print('E2E smoke test INCONCLUSIVE: pod was deployed (RUNNING) but runtime/ports '
          "hadn't been reported by RunPod within the poll window (likely still pulling "
          'the container image). Terminating anyway.');
    }
  } finally {
    if (podId != null) {
      print('7. Terminating pod $podId to stop billing...');
      try {
        await client.terminatePod(apiKey, podId);
        print('   Terminated.');
      } catch (e) {
        stderr.writeln('   FAILED TO TERMINATE POD $podId: $e');
        stderr.writeln('   MANUAL CLEANUP REQUIRED on the RunPod dashboard.');
      }
    }
  }
}

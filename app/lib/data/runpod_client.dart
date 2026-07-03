import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/deploy_config.dart';
import '../models/gpu_pricing.dart';
import '../models/gpu_type.dart';
import '../models/pod.dart';
import '../models/pod_template.dart';

class RunPodApiException implements Exception {
  final String message;
  RunPodApiException(this.message);

  @override
  String toString() => message;
}

abstract class RunPodClient {
  Future<bool> validateApiKey(String apiKey);
  Future<List<GpuType>> listGpuTypes(String apiKey);
  Future<GpuPricing> getGpuPricing(
    String apiKey, {
    required String gpuId,
    required int gpuCount,
    required bool secureCloud,
  });
  Future<List<PodTemplate>> listTemplates(String apiKey);

  /// Returns null when RunPod accepts the request but has no id to give back
  /// (e.g. no stock available) -- a retryable failure, not an exception.
  ///
  /// [env] is passed through as container environment variables; RunPod's
  /// standard image entrypoints write a PUBLIC_KEY entry into
  /// ~/.ssh/authorized_keys on container start.
  Future<Pod?> deployPod(String apiKey, DeployConfig config, {Map<String, String>? env});
  Future<Pod> getPodStatus(String apiKey, String podId);
  Future<void> stopPod(String apiKey, String podId);
  Future<void> resumePod(String apiKey, String podId, int gpuCount);
  Future<void> terminatePod(String apiKey, String podId);
}

class HttpRunPodClient implements RunPodClient {
  static const _graphqlBase = 'https://api.runpod.io/graphql';
  static const _restBase = 'https://rest.runpod.io/v1';

  final http.Client _http;

  HttpRunPodClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Uri _graphqlUri(String apiKey) =>
      Uri.parse('$_graphqlBase?api_key=${Uri.encodeQueryComponent(apiKey)}');

  Future<Map<String, dynamic>> _graphql(
    String apiKey,
    String query,
    Map<String, dynamic> variables,
  ) async {
    final response = await _http.post(
      _graphqlUri(apiKey),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    if (response.statusCode != 200) {
      throw RunPodApiException('RunPod API returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['errors'] != null) {
      final errors = decoded['errors'] as List<dynamic>;
      final message = errors.isNotEmpty ? errors.first['message'] : 'Unknown GraphQL error';
      throw RunPodApiException(message.toString());
    }
    return decoded['data'] as Map<String, dynamic>? ?? {};
  }

  @override
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final data = await _graphql(apiKey, 'query { myself { id } }', {});
      return data['myself'] != null && data['myself']['id'] != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<GpuType>> listGpuTypes(String apiKey) async {
    const query = '''
      query GpuTypes {
        gpuTypes {
          id
          displayName
          memoryInGb
          secureCloud
          communityCloud
        }
      }
    ''';
    final data = await _graphql(apiKey, query, {});
    final list = data['gpuTypes'] as List<dynamic>? ?? [];
    return list.map((e) => GpuType.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<GpuPricing> getGpuPricing(
    String apiKey, {
    required String gpuId,
    required int gpuCount,
    required bool secureCloud,
  }) async {
    const query = r'''
      query GpuStock($gpuId: String!, $gpuCount: Int!, $secure: Boolean!) {
        gpuTypes(input: { id: $gpuId }) {
          id
          lowestPrice(input: { gpuCount: $gpuCount, secureCloud: $secure }) {
            minimumBidPrice
            uninterruptablePrice
            stockStatus
            availableGpuCounts
          }
        }
      }
    ''';
    final data = await _graphql(apiKey, query, {
      'gpuId': gpuId,
      'gpuCount': gpuCount,
      'secure': secureCloud,
    });
    final list = data['gpuTypes'] as List<dynamic>? ?? [];
    if (list.isEmpty) return GpuPricing.unavailable;
    return GpuPricing.fromJson(list.first['lowestPrice'] as Map<String, dynamic>?);
  }

  @override
  Future<List<PodTemplate>> listTemplates(String apiKey) async {
    final response = await _http.get(
      Uri.parse('$_restBase/templates'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );
    if (response.statusCode != 200) {
      throw RunPodApiException('Failed to load templates: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is List ? decoded : (decoded['templates'] as List<dynamic>? ?? []);
    return list.map((e) => PodTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Pod?> deployPod(String apiKey, DeployConfig config, {Map<String, String>? env}) async {
    const query = r'''
      mutation DeployPod($input: PodFindAndDeployOnDemandInput!) {
        podFindAndDeployOnDemand(input: $input) {
          id
          imageName
          machineId
          desiredStatus
        }
      }
    ''';
    final input = {
      'cloudType': cloudTypeToApiValue(config.cloudType),
      'gpuCount': config.gpuCount,
      'gpuTypeId': config.selectedGpuTypeId,
      'minVcpuCount': config.minVcpuCount,
      'minMemoryInGb': config.minMemoryInGb,
      'volumeInGb': config.volumeInGb,
      'containerDiskInGb': config.containerDiskInGb,
      'templateId': config.selectedTemplateId,
      'ports': config.ports,
      'volumeMountPath': config.volumeMountPath,
      if (env != null && env.isNotEmpty)
        'env': env.entries.map((e) => {'key': e.key, 'value': e.value}).toList(),
    };
    final data = await _graphql(apiKey, query, {'input': input});
    final result = data['podFindAndDeployOnDemand'] as Map<String, dynamic>?;
    if (result == null || result['id'] == null) return null;
    return Pod.fromJson(result);
  }

  @override
  Future<Pod> getPodStatus(String apiKey, String podId) async {
    const query = r'''
      query PodStatus($podId: String!) {
        pod(input: { podId: $podId }) {
          id
          desiredStatus
          runtime {
            uptimeInSeconds
            ports { ip publicPort privatePort type }
            gpus { id gpuUtilPercent memoryUtilPercent }
          }
        }
      }
    ''';
    final data = await _graphql(apiKey, query, {'podId': podId});
    final pod = data['pod'] as Map<String, dynamic>?;
    if (pod == null) throw RunPodApiException('Pod not found');
    return Pod.fromJson(pod);
  }

  @override
  Future<void> stopPod(String apiKey, String podId) async {
    const query = r'''
      mutation StopPod($podId: String!) {
        podStop(input: { podId: $podId }) { id desiredStatus }
      }
    ''';
    await _graphql(apiKey, query, {'podId': podId});
  }

  @override
  Future<void> resumePod(String apiKey, String podId, int gpuCount) async {
    const query = r'''
      mutation ResumePod($podId: String!, $gpuCount: Int!) {
        podResume(input: { podId: $podId, gpuCount: $gpuCount }) { id desiredStatus }
      }
    ''';
    await _graphql(apiKey, query, {'podId': podId, 'gpuCount': gpuCount});
  }

  @override
  Future<void> terminatePod(String apiKey, String podId) async {
    const query = r'''
      mutation TerminatePod($podId: String!) {
        podTerminate(input: { podId: $podId })
      }
    ''';
    await _graphql(apiKey, query, {'podId': podId});
  }
}

enum CloudType { all, secure, community }

String cloudTypeToApiValue(CloudType type) {
  switch (type) {
    case CloudType.all:
      return 'ALL';
    case CloudType.secure:
      return 'SECURE';
    case CloudType.community:
      return 'COMMUNITY';
  }
}

CloudType cloudTypeFromApiValue(String? value) {
  switch (value) {
    case 'SECURE':
      return CloudType.secure;
    case 'COMMUNITY':
      return CloudType.community;
    default:
      return CloudType.all;
  }
}

/// Persistent deploy configuration. Fields survive independently: changing
/// one (e.g. selectedGpuTypeId) must never clear the others.
class DeployConfig {
  final String? selectedTemplateId;
  final String? selectedGpuTypeId;
  final CloudType cloudType;
  final int gpuCount;
  final int minVcpuCount;
  final int minMemoryInGb;
  final int volumeInGb;
  final int containerDiskInGb;
  final String ports;
  final String volumeMountPath;
  final int maxRetryCount;

  const DeployConfig({
    this.selectedTemplateId,
    this.selectedGpuTypeId,
    this.cloudType = CloudType.all,
    this.gpuCount = 1,
    this.minVcpuCount = 2,
    this.minMemoryInGb = 8,
    this.volumeInGb = 20,
    this.containerDiskInGb = 20,
    this.ports = '8888/http,22/tcp',
    this.volumeMountPath = '/workspace',
    this.maxRetryCount = 3,
  });

  DeployConfig copyWith({
    String? selectedTemplateId,
    String? selectedGpuTypeId,
    CloudType? cloudType,
    int? gpuCount,
    int? minVcpuCount,
    int? minMemoryInGb,
    int? volumeInGb,
    int? containerDiskInGb,
    String? ports,
    String? volumeMountPath,
    int? maxRetryCount,
  }) {
    return DeployConfig(
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      selectedGpuTypeId: selectedGpuTypeId ?? this.selectedGpuTypeId,
      cloudType: cloudType ?? this.cloudType,
      gpuCount: gpuCount ?? this.gpuCount,
      minVcpuCount: minVcpuCount ?? this.minVcpuCount,
      minMemoryInGb: minMemoryInGb ?? this.minMemoryInGb,
      volumeInGb: volumeInGb ?? this.volumeInGb,
      containerDiskInGb: containerDiskInGb ?? this.containerDiskInGb,
      ports: ports ?? this.ports,
      volumeMountPath: volumeMountPath ?? this.volumeMountPath,
      maxRetryCount: maxRetryCount ?? this.maxRetryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'selectedTemplateId': selectedTemplateId,
        'selectedGpuTypeId': selectedGpuTypeId,
        'cloudType': cloudTypeToApiValue(cloudType),
        'gpuCount': gpuCount,
        'minVcpuCount': minVcpuCount,
        'minMemoryInGb': minMemoryInGb,
        'volumeInGb': volumeInGb,
        'containerDiskInGb': containerDiskInGb,
        'ports': ports,
        'volumeMountPath': volumeMountPath,
        'maxRetryCount': maxRetryCount,
      };

  factory DeployConfig.fromJson(Map<String, dynamic> json) {
    return DeployConfig(
      selectedTemplateId: json['selectedTemplateId'] as String?,
      selectedGpuTypeId: json['selectedGpuTypeId'] as String?,
      cloudType: cloudTypeFromApiValue(json['cloudType'] as String?),
      gpuCount: (json['gpuCount'] as num?)?.toInt() ?? 1,
      minVcpuCount: (json['minVcpuCount'] as num?)?.toInt() ?? 2,
      minMemoryInGb: (json['minMemoryInGb'] as num?)?.toInt() ?? 8,
      volumeInGb: (json['volumeInGb'] as num?)?.toInt() ?? 20,
      containerDiskInGb: (json['containerDiskInGb'] as num?)?.toInt() ?? 20,
      ports: json['ports'] as String? ?? '8888/http,22/tcp',
      volumeMountPath: json['volumeMountPath'] as String? ?? '/workspace',
      maxRetryCount: (json['maxRetryCount'] as num?)?.toInt() ?? 3,
    );
  }
}

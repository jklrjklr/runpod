class PodPort {
  final String ip;
  final int publicPort;
  final int privatePort;
  final String type;

  const PodPort({
    required this.ip,
    required this.publicPort,
    required this.privatePort,
    required this.type,
  });

  factory PodPort.fromJson(Map<String, dynamic> json) {
    return PodPort(
      ip: json['ip'] as String? ?? '',
      publicPort: (json['publicPort'] as num?)?.toInt() ?? 0,
      privatePort: (json['privatePort'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
    );
  }
}

class PodGpuUtil {
  final String id;
  final int gpuUtilPercent;
  final int memoryUtilPercent;

  const PodGpuUtil({
    required this.id,
    required this.gpuUtilPercent,
    required this.memoryUtilPercent,
  });

  factory PodGpuUtil.fromJson(Map<String, dynamic> json) {
    return PodGpuUtil(
      id: json['id'] as String? ?? '',
      gpuUtilPercent: (json['gpuUtilPercent'] as num?)?.toInt() ?? 0,
      memoryUtilPercent: (json['memoryUtilPercent'] as num?)?.toInt() ?? 0,
    );
  }
}

class PodRuntime {
  final int uptimeInSeconds;
  final List<PodPort> ports;
  final List<PodGpuUtil> gpus;

  const PodRuntime({
    required this.uptimeInSeconds,
    required this.ports,
    required this.gpus,
  });

  /// The first HTTP-type proxy port, used to build the WebView/browser target.
  PodPort? get primaryHttpPort {
    for (final p in ports) {
      if (p.type == 'http') return p;
    }
    return null;
  }

  factory PodRuntime.fromJson(Map<String, dynamic> json) {
    return PodRuntime(
      uptimeInSeconds: (json['uptimeInSeconds'] as num?)?.toInt() ?? 0,
      ports: (json['ports'] as List<dynamic>? ?? [])
          .map((e) => PodPort.fromJson(e as Map<String, dynamic>))
          .toList(),
      gpus: (json['gpus'] as List<dynamic>? ?? [])
          .map((e) => PodGpuUtil.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Pod {
  final String id;
  final String? imageName;
  final String? machineId;
  final String desiredStatus;
  final PodRuntime? runtime;

  const Pod({
    required this.id,
    this.imageName,
    this.machineId,
    required this.desiredStatus,
    this.runtime,
  });

  String proxyUrl() {
    final port = runtime?.primaryHttpPort;
    if (port == null) return '';
    return 'https://$id-${port.publicPort}.proxy.runpod.net';
  }

  factory Pod.fromJson(Map<String, dynamic> json) {
    return Pod(
      id: json['id'] as String,
      imageName: json['imageName'] as String?,
      machineId: json['machineId'] as String?,
      desiredStatus: json['desiredStatus'] as String? ?? 'UNKNOWN',
      runtime: json['runtime'] == null
          ? null
          : PodRuntime.fromJson(json['runtime'] as Map<String, dynamic>),
    );
  }
}

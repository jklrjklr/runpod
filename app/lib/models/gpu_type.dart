enum StockStatus { high, medium, low, none, unknown }

StockStatus stockStatusFromString(String? value) {
  switch (value) {
    case 'High':
      return StockStatus.high;
    case 'Medium':
      return StockStatus.medium;
    case 'Low':
      return StockStatus.low;
    case 'None':
      return StockStatus.none;
    default:
      return StockStatus.unknown;
  }
}

class GpuType {
  final String id;
  final String displayName;
  final int memoryInGb;
  final bool secureCloud;
  final bool communityCloud;
  final StockStatus stockStatus;

  const GpuType({
    required this.id,
    required this.displayName,
    required this.memoryInGb,
    required this.secureCloud,
    required this.communityCloud,
    this.stockStatus = StockStatus.unknown,
  });

  GpuType copyWith({StockStatus? stockStatus}) {
    return GpuType(
      id: id,
      displayName: displayName,
      memoryInGb: memoryInGb,
      secureCloud: secureCloud,
      communityCloud: communityCloud,
      stockStatus: stockStatus ?? this.stockStatus,
    );
  }

  factory GpuType.fromJson(Map<String, dynamic> json) {
    return GpuType(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? json['id'] as String,
      memoryInGb: (json['memoryInGb'] as num?)?.toInt() ?? 0,
      secureCloud: json['secureCloud'] as bool? ?? false,
      communityCloud: json['communityCloud'] as bool? ?? false,
    );
  }
}

import 'gpu_type.dart';

class GpuPricing {
  final StockStatus stockStatus;
  final double? minimumBidPrice;
  final double? uninterruptablePrice;
  final int availableGpuCounts;

  const GpuPricing({
    required this.stockStatus,
    this.minimumBidPrice,
    this.uninterruptablePrice,
    this.availableGpuCounts = 0,
  });

  static const unavailable = GpuPricing(stockStatus: StockStatus.unknown);

  factory GpuPricing.fromJson(Map<String, dynamic>? json) {
    if (json == null) return unavailable;
    return GpuPricing(
      stockStatus: stockStatusFromString(json['stockStatus'] as String?),
      minimumBidPrice: (json['minimumBidPrice'] as num?)?.toDouble(),
      uninterruptablePrice: (json['uninterruptablePrice'] as num?)?.toDouble(),
      availableGpuCounts: (json['availableGpuCounts'] as num?)?.toInt() ?? 0,
    );
  }
}

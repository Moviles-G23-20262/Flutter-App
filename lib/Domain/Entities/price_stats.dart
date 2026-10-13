/// Price statistics of completed sales for a category/condition, as computed by the analytics service.
class PriceStats {
  /// How many completed sales the figures come from.
  final int sampleSize;
  final double p25;
  final double median;
  final double p75;

  const PriceStats({
    required this.sampleSize,
    required this.p25,
    required this.median,
    required this.p75,
  });
}

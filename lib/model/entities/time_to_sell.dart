import 'package:flutter/foundation.dart';

/// BQ11 answer: What is the average time (in days) it takes for a newly
/// listed academic item to be marked as sold?
///
/// Helps the Analytics Manager understand market liquidity and set realistic
/// expectations for new sellers joining the platform.
@immutable
class TimeToSellInsight {
  final int soldListings;
  final int skipped;
  final double meanDays;
  final double medianDays;
  final double p75Days;
  final double minDays;
  final double maxDays;
  final Map<String, double> categoryMeans;
  final Map<String, double> categoryMedians;

  const TimeToSellInsight({
    required this.soldListings,
    this.skipped = 0,
    required this.meanDays,
    required this.medianDays,
    this.p75Days = 0.0,
    this.minDays = 0.0,
    this.maxDays = 0.0,
    this.categoryMeans = const {},
    this.categoryMedians = const {},
  });

  static const empty = TimeToSellInsight(
    soldListings: 0,
    skipped: 0,
    meanDays: 0.0,
    medianDays: 0.0,
    p75Days: 0.0,
    minDays: 0.0,
    maxDays: 0.0,
    categoryMeans: {},
    categoryMedians: {},
  );

  bool get hasData => soldListings > 0;

  /// Returns the mean days to sell for [category] (e.g. 'BOOKS', 'CALCULATORS'),
  /// falling back to the overall mean if not enough data for this category.
  double? daysForCategory(String category) {
    final key = category.toUpperCase();
    return categoryMeans[key] ?? (hasData ? meanDays : null);
  }
}

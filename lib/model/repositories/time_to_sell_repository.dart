import '../entities/time_to_sell.dart';

abstract class TimeToSellRepository {
  /// Loads the BQ11 market liquidity insight.
  Future<TimeToSellInsight> getTimeToSell();
}

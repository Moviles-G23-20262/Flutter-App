import '../entities/seller_reputation.dart';

/// BQ 17 repository: campus-wide seller reputation conversion & speed benchmarks.
abstract class SellerReputationRepository {
  Future<SellerReputationInsight> getSellerReputation();
}

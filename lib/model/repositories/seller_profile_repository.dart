import '../entities/material_entity.dart';
import '../entities/seller_profile_entity.dart';
import '../entities/user_summary.dart';

/// Loads a seller's public profile, ratings, listings, and BQ 17 campus reputation benchmark.
abstract class SellerProfileRepository {
  Future<SellerProfileData> getSellerProfile(
    UserSummary seller, {
    List<MaterialEntity>? knownMaterials,
    bool forceRefresh = false,
  });

  /// Clears the in-memory LRU cache (e.g., on sign-out or memory pressure).
  void clearMemoryCache();
}

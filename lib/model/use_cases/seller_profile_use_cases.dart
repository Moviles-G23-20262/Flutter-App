import '../entities/material_entity.dart';
import '../entities/seller_profile_entity.dart';
import '../entities/seller_reputation.dart';
import '../entities/user_summary.dart';
import '../repositories/seller_profile_repository.dart';
import '../repositories/seller_reputation_repository.dart';

class GetSellerProfileUseCase {
  final SellerProfileRepository _repository;

  const GetSellerProfileUseCase(this._repository);

  Future<SellerProfileData> execute(
    UserSummary seller, {
    List<MaterialEntity>? knownMaterials,
    bool forceRefresh = false,
  }) =>
      _repository.getSellerProfile(
        seller,
        knownMaterials: knownMaterials,
        forceRefresh: forceRefresh,
      );

  void clearCache() => _repository.clearMemoryCache();
}

class GetSellerReputationUseCase {
  final SellerReputationRepository _repository;

  const GetSellerReputationUseCase(this._repository);

  Future<SellerReputationInsight> execute() => _repository.getSellerReputation();
}

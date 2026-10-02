import '../Entities/rating_entity.dart';
import '../repositories/marketplace_repositories.dart';

class GetUserRatings {
  final RatingRepository repository;

  const GetUserRatings(this.repository);

  Future<List<RatingEntity>> call(String userId) {
    return repository.getRatingsForUser(userId);
  }
}

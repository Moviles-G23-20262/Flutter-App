import '../entities/major_activity.dart';
import '../repositories/major_activity_repository.dart';

class GetMajorActivityUseCase {
  final MajorActivityRepository _repository;

  const GetMajorActivityUseCase(this._repository);

  Future<MajorActivityInsight> execute() => _repository.getMajorActivity();
}

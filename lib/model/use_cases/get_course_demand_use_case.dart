import '../entities/course_demand.dart';
import '../repositories/course_demand_repository.dart';

/// BQ 19: which courses have the most interested students compared with listings on sale.
class GetCourseDemandUseCase {
  final CourseDemandRepository repository;

  GetCourseDemandUseCase(this.repository);

  Future<({CourseDemandReport report, DateTime? savedAt})> execute() => repository.getCourseDemand();
}

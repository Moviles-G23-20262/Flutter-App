import '../entities/course_demand.dart';

/// BQ 19 from the analytics service, with the time of the saved copy when it came from the phone.
abstract class CourseDemandRepository {
  Future<({CourseDemandReport report, DateTime? savedAt})> getCourseDemand();
}

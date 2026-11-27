import '../entities/major_activity.dart';

/// BQ 18 repository: campus supply & demand aggregated by academic major and faculty.
abstract class MajorActivityRepository {
  Future<MajorActivityInsight> getMajorActivity();
}

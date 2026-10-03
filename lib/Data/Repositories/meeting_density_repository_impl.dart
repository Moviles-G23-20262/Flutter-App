import '../../Domain/Entities/meeting_point_density.dart';
import '../../Domain/repositories/meeting_density_repository.dart';
import '../data_sources/analytics_remote_data_source.dart';

class MeetingDensityRepositoryImpl implements MeetingDensityRepository {
  final AnalyticsRemoteDataSource remote;

  MeetingDensityRepositoryImpl(this.remote);

  @override
  Future<MeetingPointDensity> getDensity() async {
    try {
      return await remote.getMeetingPointDensity();
    } catch (_) {
      // History is a nice-to-have: without it the zones are ranked by distance and hour only.
      return MeetingPointDensity.empty;
    }
  }
}

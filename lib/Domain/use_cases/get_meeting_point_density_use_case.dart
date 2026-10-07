import '../Entities/meeting_point_density.dart';
import '../repositories/meeting_density_repository.dart';

class GetMeetingPointDensityUseCase {
  final MeetingDensityRepository repository;
  GetMeetingPointDensityUseCase(this.repository);

  Future<MeetingPointDensity> execute() => repository.getDensity();
}

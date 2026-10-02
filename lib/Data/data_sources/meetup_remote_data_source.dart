import '../../core/network/api_client.dart';
import '../../Domain/Entities/meetup_entities.dart';
import '../Models/marketplace_models.dart';

/// Safe zones, meetup proposals and class schedules.
/// Errors surface as [ApiException] / [NetworkException]; the repositories translate them.
abstract class MeetupRemoteDataSource {
  Future<List<MeetingPointEntity>> getMeetingPoints();
  Future<MeetingSuggestions> getSuggestions(String chatRoomId);
  Future<MeetingProposalEntity> createProposal(Map<String, dynamic> body);

  /// [action] is `accept`, `decline` or `cancel`.
  Future<MeetingProposalEntity> answerProposal(String proposalId, String action);

  Future<List<ScheduleBlockEntity>> getSchedule();
  Future<ScheduleBlockEntity> addScheduleBlock(Map<String, dynamic> body);
  Future<void> removeScheduleBlock(String blockId);
}

class MeetupRemoteDataSourceImpl implements MeetupRemoteDataSource {
  final ApiClient apiClient;

  MeetupRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<MeetingPointEntity>> getMeetingPoints() async =>
      parseList(await apiClient.get('/meeting-points'), meetingPointFromJson);

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) async => meetingSuggestionsFromJson(
        await apiClient.get('/meeting-proposals/suggestions?chatRoomId=$chatRoomId') as Json,
      );

  @override
  Future<MeetingProposalEntity> createProposal(Map<String, dynamic> body) async =>
      meetingProposalFromJson(await apiClient.post('/meeting-proposals', body: body) as Json);

  @override
  Future<MeetingProposalEntity> answerProposal(String proposalId, String action) async =>
      meetingProposalFromJson(await apiClient.post('/meeting-proposals/$proposalId/$action') as Json);

  @override
  Future<List<ScheduleBlockEntity>> getSchedule() async =>
      parseList(await apiClient.get('/schedule-blocks'), scheduleBlockFromJson);

  @override
  Future<ScheduleBlockEntity> addScheduleBlock(Map<String, dynamic> body) async =>
      scheduleBlockFromJson(await apiClient.post('/schedule-blocks', body: body) as Json);

  @override
  Future<void> removeScheduleBlock(String blockId) async {
    await apiClient.delete('/schedule-blocks/$blockId');
  }
}

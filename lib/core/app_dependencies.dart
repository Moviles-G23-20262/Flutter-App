import 'package:http/http.dart' as http;

import '../Data/data_sources/analytics_remote_data_source.dart';
import '../Data/Repositories/meeting_density_repository_impl.dart';
import '../Domain/use_cases/get_meeting_point_density_use_case.dart';
import '../Domain/use_cases/meeting_point_recommendation_use_case.dart';
import '../Domain/use_cases/rank_meeting_points_use_case.dart';
import '../Data/data_sources/auth_remote_data_source.dart';
import '../Data/data_sources/device_location_data_source.dart';
import '../Data/data_sources/marketplace_remote_data_source.dart';
import '../Data/data_sources/meetup_remote_data_source.dart';
import '../Data/data_sources/session_storage.dart';
import '../Data/Repositories/auth_repository_impl.dart';
import '../Data/Repositories/conversation_insight_repository_impl.dart';
import '../Data/Repositories/marketplace_repositories_impl.dart';
import '../Data/Repositories/meetup_repositories_impl.dart';
import '../Domain/use_cases/conversation_insight_use_case.dart';
import '../Domain/use_cases/login_use_case.dart';
import '../Domain/use_cases/marketplace_use_cases.dart';
import '../Domain/use_cases/meetup_use_cases.dart';
import '../Domain/use_cases/logout_use_case.dart';
import '../Domain/use_cases/register_student_use_case.dart';
import '../Domain/use_cases/restore_session_use_case.dart';
import 'network/api_client.dart';

class AppDependencies {
  final LoginUseCase login;
  final RegisterStudentUseCase registerStudent;
  final RestoreSessionUseCase restoreSession;
  final LogoutUseCase logout;

  /// Signs the app out when the server stops accepting our token.
  final ApiClient apiClient;

  final GetMaterialsUseCase getMaterials;
  final CreateListingUseCase createListing;
  final GetWishlistUseCase getWishlist;
  final AddToWishlistUseCase addToWishlist;
  final RemoveFromWishlistUseCase removeFromWishlist;
  final GetChatRoomsUseCase getChatRooms;
  final OpenChatRoomUseCase openChatRoom;
  final GetMessagesUseCase getMessages;
  final SendMessageUseCase sendMessage;
  final MarkChatReadUseCase markChatRead;
  final GetExchangesUseCase getExchanges;
  final PlaceOrderUseCase placeOrder;
  final CompleteExchangeUseCase completeExchange;
  final CancelExchangeUseCase cancelExchange;
  final RateUserUseCase rateUser;
  final GetNotificationsUseCase getNotifications;
  final MarkNotificationOpenedUseCase markNotificationOpened;
  final MeetupUseCases meetups;
  final GetConversationInsightUseCase getConversationInsight;
  final GetScheduleUseCase getSchedule;
  final AddScheduleBlockUseCase addScheduleBlock;
  final RemoveScheduleBlockUseCase removeScheduleBlock;

  const AppDependencies._({
    required this.login,
    required this.registerStudent,
    required this.restoreSession,
    required this.logout,
    required this.apiClient,
    required this.getMaterials,
    required this.createListing,
    required this.getWishlist,
    required this.addToWishlist,
    required this.removeFromWishlist,
    required this.getChatRooms,
    required this.openChatRoom,
    required this.getMessages,
    required this.sendMessage,
    required this.markChatRead,
    required this.getExchanges,
    required this.placeOrder,
    required this.completeExchange,
    required this.cancelExchange,
    required this.rateUser,
    required this.getNotifications,
    required this.markNotificationOpened,
    required this.meetups,
    required this.getConversationInsight,
    required this.getSchedule,
    required this.addScheduleBlock,
    required this.removeScheduleBlock,
  });

  factory AppDependencies.create() {
    const baseUrl = String.fromEnvironment('API_BASE_URL');
    if (baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not defined. Run the app with '
        '--dart-define-from-file=config/development.json',
      );
    }

    final apiClient = ApiClient(baseUrl: baseUrl, client: http.Client());

    const analyticsBaseUrl = String.fromEnvironment('ANALYTICS_BASE_URL');
    final analyticsClient = ApiClient(baseUrl: analyticsBaseUrl, client: http.Client());
    final analyticsRemote = AnalyticsRemoteDataSource(apiClient: analyticsClient);
    final conversationInsights = ConversationInsightRepositoryImpl(remoteDataSource: analyticsRemote);
    final meetingDensity = MeetingDensityRepositoryImpl(analyticsRemote);
    final authRepository = AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(apiClient: apiClient),
      storage: SecureSessionStorage(),
      apiClient: apiClient,
    );

    final marketplaceRemote = MarketplaceRemoteDataSourceImpl(apiClient: apiClient);
    final materials = MaterialRepositoryImpl(marketplaceRemote);
    final wishlist = WishlistRepositoryImpl(marketplaceRemote);
    final chats = ChatRepositoryImpl(marketplaceRemote);
    final exchanges = ExchangeRepositoryImpl(marketplaceRemote);
    final notifications = NotificationRepositoryImpl(marketplaceRemote);

    final meetupRemote = MeetupRemoteDataSourceImpl(apiClient: apiClient);
    final meetupRepository = MeetupRepositoryImpl(meetupRemote);
    final scheduleRepository = ScheduleRepositoryImpl(meetupRemote);
    final locationRepository = LocationRepositoryImpl(DeviceLocationDataSource());

    return AppDependencies._(
      login: LoginUseCase(authRepository),
      registerStudent: RegisterStudentUseCase(authRepository),
      restoreSession: RestoreSessionUseCase(authRepository),
      logout: LogoutUseCase(authRepository),
      apiClient: apiClient,
      getMaterials: GetMaterialsUseCase(materials),
      createListing: CreateListingUseCase(materials),
      getWishlist: GetWishlistUseCase(wishlist),
      addToWishlist: AddToWishlistUseCase(wishlist),
      removeFromWishlist: RemoveFromWishlistUseCase(wishlist),
      getChatRooms: GetChatRoomsUseCase(chats),
      openChatRoom: OpenChatRoomUseCase(chats),
      getMessages: GetMessagesUseCase(chats),
      sendMessage: SendMessageUseCase(chats),
      markChatRead: MarkChatReadUseCase(chats),
      getExchanges: GetExchangesUseCase(exchanges),
      placeOrder: PlaceOrderUseCase(exchanges),
      completeExchange: CompleteExchangeUseCase(exchanges),
      cancelExchange: CancelExchangeUseCase(exchanges),
      rateUser: RateUserUseCase(exchanges),
      getNotifications: GetNotificationsUseCase(notifications),
      markNotificationOpened: MarkNotificationOpenedUseCase(notifications),
      meetups: MeetupUseCases(
        getMeetingPoints: GetMeetingPointsUseCase(meetupRepository),
        getSuggestions: GetMeetingSuggestionsUseCase(meetupRepository),
        propose: ProposeMeetingUseCase(meetupRepository),
        answer: AnswerMeetingProposalUseCase(meetupRepository),
        currentLocation: GetCurrentLocationUseCase(locationRepository),
        rankZones: RankSafeZonesUseCase(),
        recommend: RecommendMeetingPointUseCase(const RankMeetingPointsUseCase()),
        getDensity: GetMeetingPointDensityUseCase(meetingDensity),
      ),
      getConversationInsight: GetConversationInsightUseCase(conversationInsights),
      getSchedule: GetScheduleUseCase(scheduleRepository),
      addScheduleBlock: AddScheduleBlockUseCase(scheduleRepository),
      removeScheduleBlock: RemoveScheduleBlockUseCase(scheduleRepository),
    );
  }
}

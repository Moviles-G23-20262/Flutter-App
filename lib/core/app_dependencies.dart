import 'package:http/http.dart' as http;

import '../Data/data_sources/auth_remote_data_source.dart';
import '../Data/data_sources/device_location_data_source.dart';
import '../Data/data_sources/marketplace_remote_data_source.dart';
import '../Data/data_sources/meetup_remote_data_source.dart';
import '../Data/data_sources/session_storage.dart';
import '../Data/Repositories/auth_repository_impl.dart';
import '../Data/Repositories/marketplace_repositories_impl.dart';
import '../Data/Repositories/meetup_repositories_impl.dart';
import '../Domain/use_cases/login_use_case.dart';
import '../Domain/use_cases/get_user_ratings.dart';
import '../Domain/use_cases/marketplace_use_cases.dart';
import '../Domain/use_cases/meetup_use_cases.dart';
import '../Domain/use_cases/logout_use_case.dart';
import '../Domain/use_cases/register_student_use_case.dart';
import '../Domain/use_cases/restore_session_use_case.dart';
import 'network/api_client.dart';

/// Composition root: the only place that knows which implementations back the use cases.
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
  final GetUserRatings getUserRatings;
  final GetNotificationsUseCase getNotifications;
  final MarkNotificationOpenedUseCase markNotificationOpened;
  final MeetupUseCases meetups;
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
    required this.getUserRatings,
    required this.getNotifications,
    required this.markNotificationOpened,
    required this.meetups,
    required this.getSchedule,
    required this.addScheduleBlock,
    required this.removeScheduleBlock,
  });

  factory AppDependencies.create() {
    // Provided with --dart-define-from-file=config/development.json
    const baseUrl = String.fromEnvironment('API_BASE_URL');
    if (baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not defined. Run the app with '
        '--dart-define-from-file=config/development.json',
      );
    }

    final apiClient = ApiClient(baseUrl: baseUrl, client: http.Client());
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
    final ratings = RatingRepositoryImpl(marketplaceRemote);
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
      getUserRatings: GetUserRatings(ratings),
      getNotifications: GetNotificationsUseCase(notifications),
      markNotificationOpened: MarkNotificationOpenedUseCase(notifications),
      meetups: MeetupUseCases(
        getMeetingPoints: GetMeetingPointsUseCase(meetupRepository),
        getSuggestions: GetMeetingSuggestionsUseCase(meetupRepository),
        propose: ProposeMeetingUseCase(meetupRepository),
        answer: AnswerMeetingProposalUseCase(meetupRepository),
        currentLocation: GetCurrentLocationUseCase(locationRepository),
        rankZones: RankSafeZonesUseCase(),
      ),
      getSchedule: GetScheduleUseCase(scheduleRepository),
      addScheduleBlock: AddScheduleBlockUseCase(scheduleRepository),
      removeScheduleBlock: RemoveScheduleBlockUseCase(scheduleRepository),
    );
  }
}

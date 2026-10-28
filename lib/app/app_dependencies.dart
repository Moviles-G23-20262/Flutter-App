import 'package:http/http.dart' as http;

import '../model/data_sources/ambient_light_data_source.dart';
import '../model/data_sources/battery_data_source.dart';
import '../model/data_sources/connectivity_data_source.dart';
import '../model/use_cases/connectivity_use_cases.dart';
import '../model/data_sources/analytics_remote_data_source.dart';
import '../model/repositories/impl/meeting_density_repository_impl.dart';
import '../model/repositories/impl/price_stats_repository_impl.dart';
import '../model/repositories/impl/time_to_sell_repository_impl.dart';
import '../model/use_cases/get_time_to_sell_use_case.dart';
import '../model/repositories/impl/analytics_event_repository_impl.dart';
import '../model/data_sources/analytics_event_remote_data_source.dart';
import '../model/services/analytics_sync_service.dart';
import '../model/use_cases/track_event_use_case.dart';
import '../model/use_cases/price_estimator_use_case.dart';
import '../view_model/smart_listing_view_model.dart';
import '../model/services/biometric_auth_service.dart';
import '../model/services/external_vision_service.dart';
import '../model/use_cases/quick_unlock_use_cases.dart';
import '../model/services/image_picker_service.dart';
import '../model/use_cases/classify_item_photo_use_case.dart';
import '../model/use_cases/get_meeting_point_density_use_case.dart';
import '../model/use_cases/meeting_point_recommendation_use_case.dart';
import '../model/use_cases/rank_meeting_points_use_case.dart';
import '../model/data_sources/auth_remote_data_source.dart';
import '../model/data_sources/device_location_data_source.dart';
import '../model/data_sources/marketplace_remote_data_source.dart';
import '../model/data_sources/meetup_remote_data_source.dart';
import '../model/data_sources/session_storage.dart';
import '../model/repositories/impl/appearance_repositories_impl.dart';
import '../model/repositories/impl/auth_repository_impl.dart';
import '../model/repositories/impl/conversation_insight_repository_impl.dart';
import '../model/repositories/impl/marketplace_repositories_impl.dart';
import '../model/repositories/impl/meetup_repositories_impl.dart';
import '../model/use_cases/appearance_use_cases.dart';
import '../model/use_cases/power_use_cases.dart';
import '../model/use_cases/conversation_insight_use_case.dart';
import '../model/use_cases/login_use_case.dart';
import '../model/use_cases/marketplace_use_cases.dart';
import '../model/use_cases/meetup_use_cases.dart';
import '../model/use_cases/logout_use_case.dart';
import '../model/use_cases/register_student_use_case.dart';
import '../model/use_cases/restore_session_use_case.dart';
import '../model/data_sources/local/app_database.dart';
import '../model/data_sources/local/outbox_store.dart';
import '../model/data_sources/local/campus_zones_asset_data_source.dart';
import '../model/data_sources/local/response_cache.dart';
import '../model/data_sources/remote_outbox_sender.dart';
import '../model/services/outbox_sync_service.dart';
import '../model/services/session_owner.dart';
import '../model/use_cases/outbox_use_cases.dart';
import '../model/data_sources/local/draft_store.dart';
import '../model/repositories/impl/draft_repositories_impl.dart';
import '../model/repositories/impl/pending_action_repository_impl.dart';
import '../model/use_cases/pending_action_use_cases.dart';
import '../model/use_cases/rating_draft_use_cases.dart';
import '../model/use_cases/registration_draft_use_cases.dart';
import '../model/use_cases/pending_message_use_cases.dart';
import '../model/data_sources/local/draft_photo_store.dart';
import '../core/isolates/photo_compressor.dart';
import '../model/repositories/impl/pending_listing_repository_impl.dart';
import '../model/use_cases/listing_draft_use_cases.dart';
import '../model/use_cases/pending_listing_use_cases.dart';
import 'network/api_client.dart';

class AppDependencies {
  final LoginUseCase login;
  final RegisterStudentUseCase registerStudent;
  final RestoreSessionUseCase restoreSession;
  final VerifySessionUseCase verifySession;

  /// Fingerprint "Quick Unlock" of a saved session.
  final CanQuickUnlockUseCase canQuickUnlock;
  final QuickUnlockUseCase quickUnlock;
  final ForgetBiometricsUseCase forgetBiometrics;
  final LogoutUseCase logout;

  /// Theme: ambient light sensor and the saved light/dark/auto choice.
  final WatchAmbientLightUseCase watchAmbientLight;
  final LoadThemePreferenceUseCase loadThemePreference;
  final SaveThemePreferenceUseCase saveThemePreference;

  /// Battery level and charging state, for battery saver.
  final WatchBatteryUseCase watchBattery;

  /// Network state, for the offline notice.
  /// Smart feature: fair-price estimate from real sales, with an offline heuristic.
  final PriceEstimatorUseCase estimatePrice;

  /// Smart feature: category from a photo, via the external vision service.
  final ClassifyItemPhotoUseCase classifyItemPhoto;
  final ImagePickerService imagePicker;

  /// Telemetry: LISTING_VIEW, CONTACT_SELLER. Fire and forget.
  final TrackEventUseCase trackEvent;

  /// Uploads the queued telemetry in the background; started with the app.
  final AnalyticsSyncService analyticsSync;

  final GetConnectivityUseCase getConnectivity;
  final WatchConnectivityUseCase watchConnectivity;

  /// Local storage for offline use: saved server answers and the outbox (sqflite).
  final ResponseCache responseCache;
  final OutboxStore outbox;
  final OutboxSyncService outboxSync;
  /// The unfinished sign-up form (no passwords).
  final LoadRegistrationDraftUseCase loadRegistrationDraft;
  final SaveRegistrationDraftUseCase saveRegistrationDraft;
  final ClearRegistrationDraftUseCase clearRegistrationDraft;
  final SessionOwner sessionOwner;
  final StartOutboxSyncUseCase startOutboxSync;
  final StopOutboxSyncUseCase stopOutboxSync;
  final SyncOutboxUseCase syncOutbox;

  /// Offline chat: queued messages and how many items are waiting.
  final QueueMessageUseCase queueMessage;
  final GetPendingMessagesUseCase getPendingMessages;
  final WatchPendingCountUseCase watchPendingCount;

  /// The unfinished rating, saved while it is written.
  final LoadRatingDraftUseCase loadRatingDraft;
  final SaveRatingDraftUseCase saveRatingDraft;
  final ClearRatingDraftUseCase clearRatingDraft;
  final LoadListingDraftUseCase loadListingDraft;
  final SaveListingDraftUseCase saveListingDraft;
  final ClearListingDraftUseCase clearListingDraft;
  final QueueListingUseCase queueListing;
  final WatchPendingListingsUseCase watchPendingListings;
  final DiscardPendingListingUseCase discardPendingListing;

  /// Exchange steps done offline: queued in the outbox and sent later.
  final QueueExchangeCompletionUseCase queueExchangeCompletion;
  final QueueRatingUseCase queueRating;
  final QueueMeetingProposalUseCase queueMeetingProposal;
  final WatchPendingActionsUseCase watchPendingActions;
  final DiscardPendingActionUseCase discardPendingAction;

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
  final GetChatAgreementUseCase getChatAgreement;
  final GetTimeToSellUseCase getTimeToSell;
  final GetScheduleUseCase getSchedule;
  final AddScheduleBlockUseCase addScheduleBlock;
  final RemoveScheduleBlockUseCase removeScheduleBlock;

  const AppDependencies._({
    required this.login,
    required this.registerStudent,
    required this.restoreSession,
    required this.verifySession,
    required this.canQuickUnlock,
    required this.quickUnlock,
    required this.forgetBiometrics,
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
    required this.getChatAgreement,
    required this.getTimeToSell,
    required this.getSchedule,
    required this.addScheduleBlock,
    required this.removeScheduleBlock,
    required this.watchAmbientLight,
    required this.loadThemePreference,
    required this.saveThemePreference,
    required this.watchBattery,
    required this.estimatePrice,
    required this.classifyItemPhoto,
    required this.imagePicker,
    required this.trackEvent,
    required this.analyticsSync,
    required this.getConnectivity,
    required this.watchConnectivity,
    required this.responseCache,
    required this.outbox,
    required this.outboxSync,
    required this.loadRegistrationDraft,
    required this.saveRegistrationDraft,
    required this.clearRegistrationDraft,
    required this.sessionOwner,
    required this.startOutboxSync,
    required this.stopOutboxSync,
    required this.syncOutbox,
    required this.queueMessage,
    required this.getPendingMessages,
    required this.watchPendingCount,
    required this.loadRatingDraft,
    required this.saveRatingDraft,
    required this.clearRatingDraft,
    required this.loadListingDraft,
    required this.saveListingDraft,
    required this.clearListingDraft,
    required this.queueListing,
    required this.watchPendingListings,
    required this.discardPendingListing,
    required this.queueExchangeCompletion,
    required this.queueRating,
    required this.queueMeetingProposal,
    required this.watchPendingActions,
    required this.discardPendingAction,
  });

  /// A fresh ViewModel for each Smart Listing screen; the screen owns and disposes it.
  SmartListingViewModel createSmartListingViewModel({PublishListing? publish, String? userId}) =>
      SmartListingViewModel(
        estimator: estimatePrice,
        pickPhoto: imagePicker.pick,
        classifyPhoto: classifyItemPhoto,
        publishListing: publish,
        compressPhotos: compressPhotoBytes,
        queueListing: queueListing,
        connectivity: getConnectivity,
        userId: userId,
        loadDraft: loadListingDraft,
        saveDraft: saveListingDraft,
        clearDraft: clearListingDraft,
        getTimeToSell: getTimeToSell,
      );

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
    final database = AppDatabase();
    final responseCache = ResponseCache(database);
    final conversationInsights = ConversationInsightRepositoryImpl(
      remoteDataSource: analyticsRemote,
      cache: responseCache,
    );
    final meetingDensity = MeetingDensityRepositoryImpl(analyticsRemote);
    final timeToSellRepository = TimeToSellRepositoryImpl(remote: analyticsRemote, cache: responseCache);
    final sessionOwner = SessionOwner();
    final authRepository = AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(apiClient: apiClient),
      storage: SecureSessionStorage(),
      biometricStorage: SecureBiometricCredentialStorage(),
      apiClient: apiClient,
      profileCache: responseCache,
      sessionOwner: sessionOwner,
    );

    final biometrics = BiometricAuthService();

    final marketplaceRemote = MarketplaceRemoteDataSourceImpl(apiClient: apiClient);
    final materials = MaterialRepositoryImpl(
      marketplaceRemote,
      cache: responseCache,
      owner: sessionOwner,
    );
    final wishlist = WishlistRepositoryImpl(marketplaceRemote, cache: responseCache, owner: sessionOwner);
    final chats = ChatRepositoryImpl(
      marketplaceRemote,
      cache: responseCache,
      owner: sessionOwner,
    );
    final exchanges = ExchangeRepositoryImpl(marketplaceRemote);
    final notifications = NotificationRepositoryImpl(marketplaceRemote, cache: responseCache, owner: sessionOwner);

    final meetupRemote = MeetupRemoteDataSourceImpl(apiClient: apiClient);
    final meetupRepository = MeetupRepositoryImpl(
      meetupRemote,
      cache: responseCache,
      owner: sessionOwner,
      bundledZones: CampusZonesAssetDataSource(),
    );
    final scheduleRepository = ScheduleRepositoryImpl(meetupRemote);
    final locationRepository = LocationRepositoryImpl(DeviceLocationDataSource());
    final themePreferences = ThemePreferenceRepositoryImpl();
    final connectivity = ConnectivityDataSource();

    final outbox = OutboxStore(database);
    final outboxSync = OutboxSyncService(
      store: outbox,
      sender: RemoteOutboxSender(marketplaceRemote, meetupRemote),
      connectivity: connectivity,
    );
    final pendingActions = PendingActionRepositoryImpl(outbox, sync: outboxSync);
    final draftStore = DraftStore();
    final pendingListings = PendingListingRepositoryImpl(outbox, sync: outboxSync);
    final ratingDrafts = RatingDraftRepositoryImpl(draftStore);
    final registrationDrafts = RegistrationDraftRepositoryImpl(draftStore);
    final listingDrafts = ListingDraftRepositoryImpl(draftStore, DraftPhotoStore());

    return AppDependencies._(
      login: LoginUseCase(authRepository),
      registerStudent: RegisterStudentUseCase(authRepository),
      restoreSession: RestoreSessionUseCase(authRepository),
      verifySession: VerifySessionUseCase(authRepository),
      canQuickUnlock: CanQuickUnlockUseCase(biometrics: biometrics, auth: authRepository),
      quickUnlock: QuickUnlockUseCase(biometrics: biometrics, auth: authRepository),
      forgetBiometrics: ForgetBiometricsUseCase(authRepository),
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
        queuePropose: QueueMeetingProposalUseCase(pendingActions),
      ),
      getConversationInsight: GetConversationInsightUseCase(conversationInsights),
      getChatAgreement: GetChatAgreementUseCase(conversationInsights),
      getTimeToSell: GetTimeToSellUseCase(timeToSellRepository),
      getSchedule: GetScheduleUseCase(scheduleRepository),
      addScheduleBlock: AddScheduleBlockUseCase(scheduleRepository),
      removeScheduleBlock: RemoveScheduleBlockUseCase(scheduleRepository),
      watchAmbientLight: WatchAmbientLightUseCase(AmbientLightRepositoryImpl(AmbientLightDataSource())),
      loadThemePreference: LoadThemePreferenceUseCase(themePreferences),
      saveThemePreference: SaveThemePreferenceUseCase(themePreferences),
      watchBattery: WatchBatteryUseCase(BatteryDataSource()),
      trackEvent: TrackEventUseCase(AnalyticsEventRepositoryImpl()),
      analyticsSync: AnalyticsSyncService(
        remote: AnalyticsEventRemoteDataSource(apiClient: apiClient),
        connectivity: connectivity,
      ),
      classifyItemPhoto: ClassifyItemPhotoUseCase(
        // Gemini API key, only from the run configuration (config/development.json:
        // "VISION_API_KEY"), never in source control.
        ExternalVisionService(client: http.Client(), apiKey: const String.fromEnvironment('VISION_API_KEY')),
      ),
      imagePicker: ImagePickerService(),
      estimatePrice: PriceEstimatorUseCase(repository: PriceStatsRepositoryImpl(analyticsRemote)),
      getConnectivity: GetConnectivityUseCase(connectivity),
      watchConnectivity: WatchConnectivityUseCase(connectivity),
      responseCache: responseCache,
      outbox: outbox,
      outboxSync: outboxSync,
      loadRegistrationDraft: LoadRegistrationDraftUseCase(registrationDrafts),
      saveRegistrationDraft: SaveRegistrationDraftUseCase(registrationDrafts),
      clearRegistrationDraft: ClearRegistrationDraftUseCase(registrationDrafts),
      sessionOwner: sessionOwner,
      startOutboxSync: StartOutboxSyncUseCase(outboxSync),
      stopOutboxSync: StopOutboxSyncUseCase(outboxSync),
      syncOutbox: SyncOutboxUseCase(outboxSync),
      queueMessage: QueueMessageUseCase(outbox, outboxSync),
      getPendingMessages: GetPendingMessagesUseCase(outbox),
      watchPendingCount: WatchPendingCountUseCase(outbox),
      loadRatingDraft: LoadRatingDraftUseCase(ratingDrafts),
      saveRatingDraft: SaveRatingDraftUseCase(ratingDrafts),
      clearRatingDraft: ClearRatingDraftUseCase(ratingDrafts),
      loadListingDraft: LoadListingDraftUseCase(listingDrafts),
      saveListingDraft: SaveListingDraftUseCase(listingDrafts),
      clearListingDraft: ClearListingDraftUseCase(listingDrafts),
      queueListing: QueueListingUseCase(pendingListings),
      watchPendingListings: WatchPendingListingsUseCase(pendingListings),
      discardPendingListing: DiscardPendingListingUseCase(pendingListings),
      queueExchangeCompletion: QueueExchangeCompletionUseCase(pendingActions),
      queueRating: QueueRatingUseCase(pendingActions),
      queueMeetingProposal: QueueMeetingProposalUseCase(pendingActions),
      watchPendingActions: WatchPendingActionsUseCase(pendingActions),
      discardPendingAction: DiscardPendingActionUseCase(pendingActions),
    );
  }
}

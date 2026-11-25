import 'package:flutter_front_end/model/dto/marketplace_models.dart';
import 'package:flutter_front_end/model/entities/analytics_event.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/chat_agreement.dart';
import 'package:flutter_front_end/model/entities/chat_room_entity.dart';
import 'package:flutter_front_end/model/entities/conversation_insight.dart';
import 'package:flutter_front_end/model/entities/enums.dart';
import 'package:flutter_front_end/model/entities/exchange_entity.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/meetup_entities.dart';
import 'package:flutter_front_end/model/entities/rating_draft.dart';
import 'package:flutter_front_end/model/entities/time_to_sell.dart';
import 'package:flutter_front_end/model/entities/user_summary.dart';
import 'package:flutter_front_end/model/entities/wishlist_item_entity.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/analytics_event_repository.dart';
import 'package:flutter_front_end/model/repositories/conversation_insight_repository.dart';
import 'package:flutter_front_end/model/repositories/draft_repositories.dart';
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/repositories/pending_action_repository.dart';
import 'package:flutter_front_end/model/repositories/time_to_sell_repository.dart';
import 'package:flutter_front_end/model/use_cases/conversation_insight_use_case.dart';
import 'package:flutter_front_end/model/use_cases/get_time_to_sell_use_case.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/pending_action_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/rating_draft_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/track_event_use_case.dart';
import 'package:flutter_front_end/view_model/chat_view_model.dart';
import 'package:flutter_front_end/view_model/complete_exchange_view_model.dart';
import 'package:flutter_front_end/view_model/marketplace_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _TwoSidedExchangeRepo implements ExchangeRepository {
  ExchangeEntity current;
  final List<NewRating> ratings = [];

  _TwoSidedExchangeRepo(this.current);

  @override
  Future<ExchangeEntity> complete(String exchangeId, {MaterialConditionEnum? receivedCondition}) async {
    final now = DateTime.utc(2026, 11, 24, 15);
    final isBuyerCall = receivedCondition != null;
    final buyerAt = isBuyerCall ? (current.buyerConfirmedAt ?? now) : current.buyerConfirmedAt;
    final sellerAt = !isBuyerCall ? (current.sellerConfirmedAt ?? now) : current.sellerConfirmedAt;
    final bothDone = buyerAt != null && sellerAt != null;
    current = ExchangeEntity(
      id: current.id,
      orderNumber: current.orderNumber,
      materialId: current.materialId,
      buyerId: current.buyerId,
      sellerId: current.sellerId,
      price: current.price,
      status: bothDone ? ExchangeStatusEnum.COMPLETED : ExchangeStatusEnum.PENDING,
      buyerConfirmedAt: buyerAt,
      sellerConfirmedAt: sellerAt,
      completedAt: bothDone ? now : null,
      receivedCondition: receivedCondition ?? current.receivedCondition,
      buyer: current.buyer,
      seller: current.seller,
    );
    return current;
  }

  @override
  Future<void> rate(NewRating rating) async {
    if (!current.isCompleted) {
      throw const DataException('You can rate each other once the exchange is completed');
    }
    ratings.add(rating);
  }

  @override
  Future<List<ExchangeEntity>> getExchanges() async => [current];

  @override
  Future<ExchangeEntity> placeOrder(String materialId) => throw UnimplementedError();

  @override
  Future<ExchangeEntity> cancel(String exchangeId) => throw UnimplementedError();
}

class _NoDrafts implements RatingDraftRepository {
  @override
  Future<RatingDraft?> load({required String userId, required String exchangeId}) async => null;
  @override
  Future<void> save({required String userId, required String exchangeId, required RatingDraft draft}) async {}
  @override
  Future<void> clear({required String userId, required String exchangeId}) async {}
}

class _NoPendingActions implements PendingActionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DynamicTimeToSellRepo implements TimeToSellRepository {
  int soldCount = 2;
  double meanDays = 4.0;

  @override
  Future<TimeToSellInsight> getTimeToSell() async => TimeToSellInsight(
        soldListings: soldCount,
        meanDays: meanDays,
        medianDays: meanDays,
        p75Days: meanDays,
        minDays: 1,
        maxDays: 8,
      );
}

class _StubMaterials implements MaterialRepository {
  @override
  Future<List<MaterialEntity>> getMaterials() async => const [];
  @override
  Future<CachedList<MaterialEntity>> getMaterialsCached() async => const CachedList([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _StubWishlist implements WishlistRepository {
  @override
  Future<CachedList<WishlistItemEntity>> getWishlist() async => const CachedList([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _LiveInsightRepo implements ConversationInsightRepository {
  int calls = 0;

  @override
  Future<ConversationInsight> getConversationInsight() async {
    calls++;
    return ConversationInsight(conversationsAnalyzed: calls, medianMessages: 3, medianMinutes: 12);
  }

  @override
  Future<ChatAgreement> getChatAgreement(String chatRoomId) async =>
      const ChatAgreement(messagesToAgreement: 3, minutesToAgreement: 12);
}

class _FakeMeetupRepo implements MeetupRepository {
  @override
  Future<MeetingProposalEntity> accept(String proposalId) async => MeetingProposalEntity(
        id: proposalId,
        chatRoomId: 'r1',
        proposerId: 'seller-1',
        meetingPoint: const MeetingPointEntity(
          id: 'mp-1',
          name: 'ML Lobby',
          zoneType: MeetingZoneTypeEnum.BUILDING_LOBBY,
          isMonitored: true,
          location: GeoPoint(4.6, -74.06),
        ),
        startsAt: DateTime.utc(2026, 12, 1, 10),
        endsAt: DateTime.utc(2026, 12, 1, 11),
        status: MeetingProposalStatusEnum.ACCEPTED,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeChatRepo implements ChatRepository {
  final ChatRoomEntity room;
  _FakeChatRepo(this.room);

  @override
  Future<List<ChatRoomEntity>> getChatRooms() async => [room];
  @override
  Future<CachedList<ChatRoomEntity>> getChatRoomsCached() async => CachedList([room]);
  @override
  Future<List<MessageEntity>> getMessages(String chatRoomId) async => const [];
  @override
  Future<CachedList<MessageEntity>> getMessagesCached(String chatRoomId) async => const CachedList([]);
  @override
  Future<void> markRead(String chatRoomId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RecordingAnalytics implements AnalyticsEventRepository {
  final List<AnalyticsEvent> events = [];
  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event);
}

void main() {
  test('exchangeFromJson parses buyerConfirmedAt and sellerConfirmedAt for two-sided confirmation', () {
    final ex = exchangeFromJson({
      'id': 'ex-1',
      'orderNumber': 1005,
      'materialId': 'mat-1',
      'buyerId': 'buyer-1',
      'sellerId': 'seller-1',
      'price': '45000',
      'status': 'PENDING',
      'buyerConfirmedAt': '2026-11-24T12:00:00Z',
      'sellerConfirmedAt': null,
    });

    expect(ex.buyerConfirmedAt, DateTime.utc(2026, 11, 24, 12));
    expect(ex.sellerConfirmedAt, isNull);
    expect(ex.hasConfirmed('buyer-1'), isTrue);
    expect(ex.hasConfirmed('seller-1'), isFalse);
    expect(ex.otherHasConfirmed('seller-1'), isTrue);
  });

  test('two-sided confirmation: buyer confirms first without 400 rating error, then seller completes the sale', () async {
    const buyer = UserSummary(id: 'buyer-1', fullName: 'Ana Gomez', major: 'ISIS', rating: 4.8);
    const seller = UserSummary(id: 'seller-1', fullName: 'Luis Perez', major: 'ISIS', rating: 4.5);
    final initial = ExchangeEntity(
      id: 'ex-1',
      orderNumber: 1005,
      materialId: 'mat-1',
      buyerId: buyer.id,
      sellerId: seller.id,
      price: 45000,
      status: ExchangeStatusEnum.PENDING,
      buyer: buyer,
      seller: seller,
    );
    final repo = _TwoSidedExchangeRepo(initial);
    final pending = _NoPendingActions();
    final drafts = _NoDrafts();

    // 1. Buyer confirms first -> server keeps PENDING (waiting for seller), no 400 on POST /ratings.
    final buyerVm = CompleteExchangeViewModel(
      exchange: repo.current,
      userId: buyer.id,
      completeExchange: CompleteExchangeUseCase(repo),
      rateUser: RateUserUseCase(repo),
      queueCompletion: QueueExchangeCompletionUseCase(pending),
      queueRating: QueueRatingUseCase(pending),
      loadDraft: LoadRatingDraftUseCase(drafts),
      saveDraft: SaveRatingDraftUseCase(drafts),
      clearDraft: ClearRatingDraftUseCase(drafts),
      onExchangeUpdated: (_) {},
    );
    for (var i = 0; i < CompleteExchangeViewModel.checklist.length; i++) {
      buyerVm.toggleCheck(i);
    }
    buyerVm.setReceivedCondition(MaterialConditionEnum.GOOD);
    buyerVm.setStars(5);

    expect(await buyerVm.submit(), ExchangeSubmitOutcome.sent);
    expect(repo.current.isPending, isTrue);
    expect(repo.current.buyerConfirmedAt, isNotNull);
    expect(repo.ratings, isEmpty);
    buyerVm.dispose();

    // 2. Seller now confirms handoff -> exchange becomes COMPLETED and seller's rating is posted!
    final sellerVm = CompleteExchangeViewModel(
      exchange: repo.current,
      userId: seller.id,
      completeExchange: CompleteExchangeUseCase(repo),
      rateUser: RateUserUseCase(repo),
      queueCompletion: QueueExchangeCompletionUseCase(pending),
      queueRating: QueueRatingUseCase(pending),
      loadDraft: LoadRatingDraftUseCase(drafts),
      saveDraft: SaveRatingDraftUseCase(drafts),
      clearDraft: ClearRatingDraftUseCase(drafts),
      onExchangeUpdated: (_) {},
    );
    expect(sellerVm.needsSellerConfirmation, isTrue);
    expect(sellerVm.showsRatingSection, isTrue);
    sellerVm.setStars(5);

    expect(await sellerVm.submit(), ExchangeSubmitOutcome.sent);
    expect(repo.current.isCompleted, isTrue);
    expect(repo.current.completedAt, isNotNull);
    expect(repo.ratings, hasLength(1));
    sellerVm.dispose();
  });

  test('BQ11 refreshTimeToSell updates live after a new sale completes', () async {
    final tts = _DynamicTimeToSellRepo();
    final market = MarketplaceViewModel(
      getMaterials: GetMaterialsUseCase(_StubMaterials()),
      createListing: CreateListingUseCase(_StubMaterials()),
      getWishlist: GetWishlistUseCase(_StubWishlist()),
      addToWishlist: AddToWishlistUseCase(_StubWishlist()),
      removeFromWishlist: RemoveFromWishlistUseCase(_StubWishlist()),
      getTimeToSell: GetTimeToSellUseCase(tts),
    );

    await market.refreshTimeToSell();
    expect(market.timeToSell?.soldListings, 2);

    // A new sale completed in PostgreSQL -> refreshing updates BQ11 live!
    tts.soldCount = 3;
    tts.meanDays = 2.5;
    await market.refreshTimeToSell();
    expect(market.timeToSell?.soldListings, 3);
    expect(market.timeToSell?.meanDays, 2.5);
    market.dispose();
  });

  test('BQ4 accepting a meeting proposal flushes telemetry immediately and refreshes insight', () async {
    final room = ChatRoomEntity(
      id: 'r1',
      materialId: 'mat-1',
      buyerId: 'buyer-1',
      sellerId: 'seller-1',
      createdAt: DateTime.utc(2026, 11, 24),
    );
    final chatRepo = _FakeChatRepo(room);
    final insightRepo = _LiveInsightRepo();
    final analytics = _RecordingAnalytics();
    var flushed = 0;

    final vm = ChatViewModel(
      getChatRooms: GetChatRoomsUseCase(chatRepo),
      openChatRoom: OpenChatRoomUseCase(chatRepo),
      getMessages: GetMessagesUseCase(chatRepo),
      sendMessage: SendMessageUseCase(chatRepo),
      markRead: MarkChatReadUseCase(chatRepo),
      answerProposal: AnswerMeetingProposalUseCase(_FakeMeetupRepo()),
      getConversationInsight: GetConversationInsightUseCase(insightRepo),
      getChatAgreement: GetChatAgreementUseCase(insightRepo),
      trackEvent: TrackEventUseCase(analytics),
      onMeetingConfirmed: () async => flushed++,
    );

    vm.start('buyer-1');
    await Future<void>.delayed(Duration.zero);
    vm.openRoom('r1');
    await vm.loadInsight();
    expect(vm.insight?.conversationsAnalyzed, 1);

    expect(await vm.acceptProposal('prop-1'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(analytics.events.single.type, AnalyticsEventType.MEETING_CONFIRMED);
    expect(flushed, 1);
    expect(vm.insight?.conversationsAnalyzed, 2);
    vm.dispose();
  });
}

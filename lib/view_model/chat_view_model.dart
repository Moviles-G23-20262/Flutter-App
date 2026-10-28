import 'dart:async';

import 'package:flutter/foundation.dart';
import '../model/entities/chat_agreement.dart';
import '../model/entities/chat_room_entity.dart';
import '../model/entities/conversation_insight.dart';
import '../model/entities/enums.dart';
import '../model/entities/pending_items.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/use_cases/conversation_insight_use_case.dart';
import '../model/use_cases/marketplace_use_cases.dart';
import '../model/use_cases/meetup_use_cases.dart';
import '../model/use_cases/pending_message_use_cases.dart';
import '../model/rules/client_id.dart';
import '../model/use_cases/track_event_use_case.dart';

/// Conversations and the messages of the open one.
/// The backend has no push channel, so while the Messages tab is visible this polls.
class ChatViewModel extends ChangeNotifier {
  static const _messagePollInterval = Duration(seconds: 4);
  static const _roomsPollInterval = Duration(seconds: 12);

  /// The agreement is read from analytics once the MEETING_CONFIRMED event has been uploaded,
  /// which can take a sync cycle: retry now and then, not on every message poll.
  static const _agreementRetryInterval = Duration(seconds: 30);
  static const _agreementMaxTries = 10;

  /// Battery saver (low battery, not charging): poll a lot less.
  static const _savingMessagePollInterval = Duration(seconds: 15);
  static const _savingRoomsPollInterval = Duration(seconds: 45);

  final GetChatRoomsUseCase getChatRooms;
  final OpenChatRoomUseCase openChatRoom;
  final GetMessagesUseCase getMessages;
  final SendMessageUseCase sendMessage;
  final MarkChatReadUseCase markRead;
  final AnswerMeetingProposalUseCase answerProposal;
  final GetConversationInsightUseCase getConversationInsight;
  /// Offline chat: messages go to the outbox first. Without them, sending needs a connection.
  final QueueMessageUseCase? queueMessage;
  final GetPendingMessagesUseCase? getPendingMessages;
  final WatchPendingCountUseCase? watchPendingCount;
  final GetChatAgreementUseCase getChatAgreement;
  final TrackEventUseCase trackEvent;

  ChatViewModel({
    required this.getChatRooms,
    required this.openChatRoom,
    required this.getMessages,
    required this.sendMessage,
    required this.markRead,
    required this.answerProposal,
    required this.getConversationInsight,
    this.queueMessage,
    this.getPendingMessages,
    this.watchPendingCount,
    required this.getChatAgreement,
    required this.trackEvent,
  });

  bool _isOffline = false;

  void setOffline(bool offline) {
    if (_isOffline == offline) return;
    _isOffline = offline;
    if (_isOffline) {
      stopPolling();
    } else {
      startPolling();
    }
    notifyListeners();
  }

  bool get isOffline => _isOffline;

  String? _userId;
  List<ChatRoomEntity> _rooms = const [];
  final Map<String, List<MessageEntity>> _messages = {};
  DateTime? _roomsSavedAt;
  final Map<String, DateTime?> _messagesSavedAt = {};

  String? _activeRoomId;
  bool _loadingRooms = false;
  bool _loadedRooms = false;
  bool _loadingMessages = false;
  String? _roomsError;
  String? _messagesError;
  Timer? _timer;
  int _generation = 0;
  ConversationInsight? _insight;
  bool _loadingInsight = false;
  final Map<String, ChatAgreement> _agreements = {};
  final Map<String, int> _agreementTries = {};
  final Map<String, DateTime> _agreementLastTry = {};
  final Set<String> _loadingAgreements = {};

  String? get userId => _userId;

  DateTime? get roomsSavedAt => _roomsSavedAt;

  DateTime? messagesSavedAt(String roomId) => _messagesSavedAt[roomId];

  /// BQ4 (Type 2): how long chats usually take to agree on a meeting point. Null until loaded.
  ConversationInsight? get insight => _insight;

  Stream<int> get pendingCountStream => watchPendingCount?.execute() ?? const Stream.empty();

  /// Loads the BQ4 insight once. It is a nice-to-have, so any failure just falls back to cache or hides.
  Future<void> loadInsight() async {
    if (_insight != null || _loadingInsight) return;
    _loadingInsight = true;
    try {
      final insight = await getConversationInsight.execute();
      if (insight.hasData) {
        _insight = insight;
        notifyListeners();
      }
    } catch (_) {
      // Fallback: check cached insight
    }
    _loadingInsight = false;
  }

  /// BQ4 for one chat: how long it took to agree on the meeting point. Null until its meeting is
  /// confirmed and analytics has the event.
  ChatAgreement? agreementOf(String roomId) => _agreements[roomId];

  /// Asks analytics how the agreed chat [roomId] went. Like the insight it is a nice-to-have:
  /// a failure (or a 404 while the event is still queued on the phone) just keeps the card hidden
  /// and is retried later.
  void _loadAgreementIfNeeded(String roomId) {
    if (_agreements.containsKey(roomId) || _loadingAgreements.contains(roomId)) return;
    if (agreedMeetingIn(roomId) == null) return;
    final tries = _agreementTries[roomId] ?? 0;
    final last = _agreementLastTry[roomId];
    if (tries >= _agreementMaxTries) return;
    if (last != null && DateTime.now().difference(last) < _agreementRetryInterval) return;
    _agreementTries[roomId] = tries + 1;
    _agreementLastTry[roomId] = DateTime.now();
    _loadingAgreements.add(roomId);
    getChatAgreement.execute(roomId).then((agreement) {
      _agreements[roomId] = agreement;
      notifyListeners();
    }).catchError((Object _) {
      // Not available yet: the next poll tries again.
    }).whenComplete(() => _loadingAgreements.remove(roomId));
  }

  /// Conversations, most recently active first.
  List<ChatRoomEntity> get rooms => _rooms;
  bool get isLoadingRooms => _loadingRooms;
  bool get isFirstRoomsLoad => !_loadedRooms;
  String? get roomsError => _roomsError;
  String? get messagesError => _messagesError;
  bool get isLoadingMessages => _loadingMessages;
  String? get activeRoomId => _activeRoomId;
  int get unreadTotal => _rooms.fold(0, (sum, room) => sum + room.unreadCount);

  ChatRoomEntity? get activeRoom {
    final id = _activeRoomId;
    return id == null ? null : _rooms.where((r) => r.id == id).firstOrNull;
  }

  List<MessageEntity> messagesOf(String roomId) => _messages[roomId] ?? const [];

  void start(String userId) {
    _userId = userId;
    loadRooms();
  }

  Future<void> loadRooms() async {
    final generation = _generation;
    _loadingRooms = true;
    _roomsError = null;
    notifyListeners();
    try {
      final result = await getChatRooms.executeCached();
      if (generation != _generation) return;
      _rooms = _sorted(result.items);
      _roomsSavedAt = result.savedAt;
    } on DataException catch (e) {
      if (generation != _generation) return;
      _roomsError = e.message;
    } catch (_) {
      if (generation != _generation) return;
      _roomsError = 'Unexpected error. Please try again.';
    }
    _loadingRooms = false;
    _loadedRooms = true;
    notifyListeners();
  }

  /// "Message seller": finds or creates the conversation for [materialId] and returns it.
  Future<ChatRoomEntity> openRoomFor(String materialId) async {
    final room = await openChatRoom.execute(materialId);
    if (!_rooms.any((r) => r.id == room.id)) {
      _rooms = _sorted([room, ..._rooms]);
      notifyListeners();
    }
    return room;
  }

  void openRoom(String roomId) {
    _activeRoomId = roomId;
    _messagesError = null;
    notifyListeners();
    _restartTimer();
    refreshMessages(showSpinner: !_messages.containsKey(roomId));
  }

  void closeRoom() {
    _activeRoomId = null;
    notifyListeners();
    _restartTimer();
    loadRooms();
  }

  /// Sends [text] to the open conversation.
  /// Uses offline outbox queue: stores in SQLite pending_messages, shows optimistic bubble with clock,
  /// and flushes outbox asynchronously using Future with handlers (.then / .catchError).
  Future<String?> send(String roomId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'Write a message first.';
    }
    if (trimmed.length > 2000) {
      return 'Messages can have at most 2000 characters.';
    }

    final senderId = _userId ?? '';
    final queue = queueMessage;

    // Offline-first: saved in the outbox and shown at once with the clock icon; the sync service
    // sends it. The bubble keeps the queued message's id, so the sent copy replaces it.
    if (queue != null && senderId.isNotEmpty) {
      final queued = await queue.execute(ownerId: senderId, chatRoomId: roomId, content: text);
      _messages[roomId] = [
        ...messagesOf(roomId),
        MessageEntity(
          id: queued.id,
          chatRoomId: roomId,
          senderId: senderId,
          content: text,
          isRead: false,
          createdAt: queued.createdAt,
          isPending: true,
        ),
      ];
      notifyListeners();
      queue.send().then((_) {
        refreshMessages();
      }).catchError((_) {
        notifyListeners();
      });
      return null;
    }

    final clientId = newClientId();
    final clientCreated = DateTime.now();
    _messages[roomId] = [
      ...messagesOf(roomId),
      MessageEntity(
        id: clientId,
        chatRoomId: roomId,
        senderId: senderId,
        content: text,
        isRead: false,
        createdAt: clientCreated,
        isPending: true,
      ),
    ];
    notifyListeners();

    try {
      final serverMsg = await sendMessage.execute(roomId, text, id: clientId, clientCreatedAt: clientCreated);
      _messages[roomId] = [
        ...messagesOf(roomId).where((m) => m.id != clientId),
        serverMsg,
      ];
      notifyListeners();
      return null;
    } on DataException catch (e) {
      return e.message;
    }
  }

  /// Accepts, declines or withdraws a meetup proposal shown in the open chat.
  Future<String?> acceptProposal(String proposalId) => answer(proposalId, ProposalAnswer.accept);

  Future<String?> declineProposal(String proposalId) => answer(proposalId, ProposalAnswer.decline);

  Future<String?> withdrawProposal(String proposalId) => answer(proposalId, ProposalAnswer.withdraw);

  Future<String?> answer(String proposalId, ProposalAnswer answer) async {
    try {
      await answerProposal.execute(proposalId, answer);
    } on DataException catch (e) {
      return e.message;
    }
    if (answer == ProposalAnswer.accept) _trackMeetingConfirmed();
    // Accepting also posts a confirmation message; show it together with the card's new status.
    await refreshMessages();
    return null;
  }

  /// BQ4: the moment this chat agreed on a meeting point. Queued like any telemetry, so it keeps
  /// its real time (clientCreatedAt) even when the phone is offline and it uploads later.
  void _trackMeetingConfirmed() {
    final room = activeRoom;
    if (room == null) return;
    trackEvent.execute(
      AnalyticsEventType.MEETING_CONFIRMED,
      materialId: room.materialId,
      metadata: {'chatRoomId': room.id},
    );
  }

  /// The meetup both sides agreed on in [roomId], if any.
  MessageEntity? agreedMeetingIn(String roomId) => messagesOf(roomId)
      .where((m) => m.meetingProposal?.isAccepted ?? false)
      .lastOrNull;

  Future<void> refreshMessages({bool showSpinner = false}) async {
    final roomId = _activeRoomId;
    if (roomId == null) return;
    final generation = _generation;
    if (showSpinner) {
      _loadingMessages = true;
      notifyListeners();
    }
    try {
      final result = await getMessages.executeCached(roomId);
      if (generation != _generation || _activeRoomId != roomId) return;
      _messagesSavedAt[roomId] = result.savedAt;

      // Pending messages from outbox
      List<MessageEntity> pendingEntities = [];
      final readPending = getPendingMessages;
      if (readPending != null && _userId != null) {
        final pending = await readPending.execute(_userId!, roomId);
        pendingEntities = pending.map((p) => MessageEntity(
          id: p.id,
          chatRoomId: p.chatRoomId,
          senderId: p.ownerId,
          content: p.content,
          isRead: false,
          createdAt: p.createdAt,
          isPending: p.status == PendingStatus.waiting,
          isFailed: p.status == PendingStatus.refused,
        )).toList();
      }

      // Combine server/cached messages with pending ones
      final serverIds = result.items.map((m) => m.id).toSet();
      final filteredPending = pendingEntities.where((p) => !serverIds.contains(p.id)).toList();

      _messages[roomId] = [...result.items, ...filteredPending];
      _messagesError = null;
      _loadAgreementIfNeeded(roomId);

      // Only acknowledge if not viewing a saved/offline copy
      if (result.savedAt == null) {
        await _acknowledge(roomId, result.items);
      }
    } on DataException catch (e) {
      if (generation != _generation) return;
      if (!_messages.containsKey(roomId)) _messagesError = e.message;
    }
    if (generation != _generation) return;
    _loadingMessages = false;
    notifyListeners();
  }

  Future<void> _acknowledge(String roomId, List<MessageEntity> messages) async {
    final me = _userId;
    final hasUnread = messages.any((m) => m.senderId != me && !m.isRead);
    if (!hasUnread) return;
    _rooms = [
      for (final r in _rooms)
        if (r.id == roomId) _withUnread(r, 0) else r,
    ];
    try {
      await markRead.execute(roomId);
    } on DataException {
      // Ignore
    }
  }

  bool _powerSaving = false;

  bool get isPowerSaving => _powerSaving;

  void setPowerSaving(bool saving) {
    if (saving == _powerSaving) return;
    _powerSaving = saving;
    if (_timer != null) _restartTimer();
    notifyListeners();
  }

  void startPolling() => _restartTimer();

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_isOffline) return; // Pause polling when offline to save battery & avoid wasted requests
    if (_activeRoomId != null) {
      _timer = Timer.periodic(
        _powerSaving ? _savingMessagePollInterval : _messagePollInterval,
        (_) => refreshMessages(),
      );
    } else {
      _timer = Timer.periodic(
        _powerSaving ? _savingRoomsPollInterval : _roomsPollInterval,
        (_) => loadRooms(),
      );
    }
  }

  void clear() {
    _generation++;
    stopPolling();
    _userId = null;
    _rooms = const [];
    _messages.clear();
    _messagesSavedAt.clear();
    _roomsSavedAt = null;
    _activeRoomId = null;
    _loadingRooms = false;
    _loadedRooms = false;
    _loadingMessages = false;
    _roomsError = null;
    _messagesError = null;
    _insight = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<ChatRoomEntity> _sorted(List<ChatRoomEntity> rooms) =>
      [...rooms]..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

  ChatRoomEntity _withUnread(ChatRoomEntity r, int unread) => ChatRoomEntity(
        id: r.id,
        materialId: r.materialId,
        buyerId: r.buyerId,
        sellerId: r.sellerId,
        createdAt: r.createdAt,
        material: r.material,
        buyer: r.buyer,
        seller: r.seller,
        lastMessage: r.lastMessage,
        unreadCount: unread,
      );
}

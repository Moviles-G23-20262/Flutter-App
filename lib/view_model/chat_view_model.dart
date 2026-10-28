import 'dart:async';

import 'package:flutter/foundation.dart';
import '../model/data_sources/local/outbox_store.dart';
import '../model/data_sources/local/response_cache.dart';
import '../model/entities/chat_room_entity.dart';
import '../model/entities/conversation_insight.dart';
import '../model/entities/pending_items.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/services/outbox_sync_service.dart';
import '../model/use_cases/conversation_insight_use_case.dart';
import '../model/use_cases/marketplace_use_cases.dart';
import '../model/use_cases/meetup_use_cases.dart';
import '../view/widgets/formatters.dart';

/// Conversations and the messages of the open one.
/// The backend has no push channel, so while the Messages tab is visible this polls.
class ChatViewModel extends ChangeNotifier {
  static const _messagePollInterval = Duration(seconds: 4);
  static const _roomsPollInterval = Duration(seconds: 12);

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
  final OutboxStore? outboxStore;
  final OutboxSyncService? outboxSyncService;
  final ResponseCache? responseCache;

  ChatViewModel({
    required this.getChatRooms,
    required this.openChatRoom,
    required this.getMessages,
    required this.sendMessage,
    required this.markRead,
    required this.answerProposal,
    required this.getConversationInsight,
    this.outboxStore,
    this.outboxSyncService,
    this.responseCache,
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

  String? get userId => _userId;

  DateTime? get roomsSavedAt => _roomsSavedAt;
  String? get formattedRoomsAge => _roomsSavedAt != null ? timeAgo(_roomsSavedAt!) : null;

  DateTime? messagesSavedAt(String roomId) => _messagesSavedAt[roomId];
  String? formattedMessagesAge(String roomId) {
    final at = _messagesSavedAt[roomId];
    return at != null ? timeAgo(at) : null;
  }

  /// BQ4 (Type 2): how long chats usually take to agree on a meeting point. Null until loaded.
  ConversationInsight? get insight => _insight;

  Stream<int> get pendingCountStream =>
      outboxStore?.pendingCountStream ?? const Stream.empty();

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
    final clientId = newClientId();
    final clientCreated = DateTime.now();

    final localMsg = MessageEntity(
      id: clientId,
      chatRoomId: roomId,
      senderId: senderId,
      content: text,
      isRead: false,
      createdAt: clientCreated,
      isPending: true,
    );

    if (outboxStore != null && senderId.isNotEmpty) {
      await outboxStore!.enqueueMessage(
        ownerId: senderId,
        chatRoomId: roomId,
        content: text,
      );
    }

    _messages[roomId] = [...messagesOf(roomId), localMsg];
    notifyListeners();

    if (outboxSyncService != null) {
      outboxSyncService!.flush().then((_) {
        refreshMessages();
      }).catchError((_) {
        notifyListeners();
      });
      return null;
    }

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
    await refreshMessages();
    return null;
  }

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
      if (outboxStore != null && _userId != null) {
        final pending = await outboxStore!.messages(_userId!, chatRoomId: roomId);
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

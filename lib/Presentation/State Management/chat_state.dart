import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../Domain/Entities/chat_room_entity.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import '../../Domain/use_cases/marketplace_use_cases.dart';
import '../../Domain/use_cases/meetup_use_cases.dart';

/// Conversations and the messages of the open one.
/// The backend has no push channel, so while the Messages tab is visible this polls.
class ChatState extends ChangeNotifier {
  static const _messagePollInterval = Duration(seconds: 4);
  static const _roomsPollInterval = Duration(seconds: 12);

  final GetChatRoomsUseCase getChatRooms;
  final OpenChatRoomUseCase openChatRoom;
  final GetMessagesUseCase getMessages;
  final SendMessageUseCase sendMessage;
  final MarkChatReadUseCase markRead;
  final AnswerMeetingProposalUseCase answerProposal;

  ChatState({
    required this.getChatRooms,
    required this.openChatRoom,
    required this.getMessages,
    required this.sendMessage,
    required this.markRead,
    required this.answerProposal,
  });

  String? _userId;
  List<ChatRoomEntity> _rooms = const [];
  final Map<String, List<MessageEntity>> _messages = {};
  String? _activeRoomId;
  bool _loadingRooms = false;
  bool _loadedRooms = false;
  bool _loadingMessages = false;
  String? _roomsError;
  String? _messagesError;
  Timer? _timer;
  int _generation = 0;

  String? get userId => _userId;

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
      final rooms = await getChatRooms.execute();
      if (generation != _generation) return;
      _rooms = _sorted(rooms);
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

  /// Sends [text] to the open conversation. Returns an error message to show, or `null`.
  Future<String?> send(String roomId, String text) async {
    try {
      final message = await sendMessage.execute(roomId, text);
      _messages[roomId] = [...messagesOf(roomId), message];
      notifyListeners();
      return null;
    } on DataException catch (e) {
      return e.message;
    }
  }

  /// Accepts, declines or withdraws a meetup proposal shown in the open chat.
  /// Returns an error message to show, or `null`.
  Future<String?> answer(String proposalId, ProposalAnswer answer) async {
    try {
      await answerProposal.execute(proposalId, answer);
    } on DataException catch (e) {
      return e.message;
    }
    // Accepting also posts a confirmation message; show it together with the card's new status.
    await refreshMessages();
    return null;
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
      final messages = await getMessages.execute(roomId);
      if (generation != _generation || _activeRoomId != roomId) return;
      _messages[roomId] = messages;
      _messagesError = null;
      await _acknowledge(roomId, messages);
    } on DataException catch (e) {
      if (generation != _generation) return;
      // A failed background poll shouldn't replace a conversation that is already on screen.
      if (!_messages.containsKey(roomId)) _messagesError = e.message;
    }
    if (generation != _generation) return;
    _loadingMessages = false;
    notifyListeners();
  }

  /// Marks what the user is looking at as read, and clears the badge locally.
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
      // The badge comes back on the next list refresh; nothing to tell the user.
    }
  }

  /// Poll while the Messages tab is on screen; call [stopPolling] when it leaves.
  void startPolling() => _restartTimer();

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_activeRoomId != null) {
      _timer = Timer.periodic(_messagePollInterval, (_) => refreshMessages());
    } else {
      _timer = Timer.periodic(_roomsPollInterval, (_) => loadRooms());
    }
  }

  void clear() {
    _generation++;
    stopPolling();
    _userId = null;
    _rooms = const [];
    _messages.clear();
    _activeRoomId = null;
    _loadingRooms = false;
    _loadedRooms = false;
    _loadingMessages = false;
    _roomsError = null;
    _messagesError = null;
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

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../Domain/Entities/chat_room_entity.dart';
import '../State Management/app_state.dart';
import '../Widgets/async_views.dart';
import '../Widgets/common_widgets.dart';
import '../Widgets/formatters.dart';
import 'chat_view.dart';

// ─── Messages Screen ──────────────────────────────────────────────────────────

class MessagesScreen extends StatefulWidget {
  final AppState appState;

  const MessagesScreen({super.key, required this.appState});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh data as soon as the tab opens, then keep it fresh while it stays visible.
    final chats = widget.appState.chats;
    chats.startPolling();
    if (chats.activeRoomId == null) {
      chats.loadRooms();
    } else {
      chats.refreshMessages();
    }
  }

  @override
  void dispose() {
    widget.appState.chats.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chats = widget.appState.chats;
    return ListenableBuilder(
      listenable: chats,
      builder: (context, _) {
        final room = chats.activeRoom;
        if (chats.activeRoomId != null && room != null) {
          return ChatView(appState: widget.appState, room: room);
        }
        return _ConversationList(appState: widget.appState);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final AppState appState;

  const _ConversationList({required this.appState});

  @override
  Widget build(BuildContext context) {
    final chats       = appState.chats;
    final me          = appState.currentUser?.id ?? '';
    final brightness  = Theme.of(context).brightness;
    final surface     = brightness == Brightness.dark ? AppColors.darkSurface    : AppColors.lightSurface;
    final border      = brightness == Brightness.dark ? AppColors.darkBorder     : AppColors.lightBorder;
    final txPrimary   = brightness == Brightness.dark ? AppColors.darkTextPrimary: AppColors.lightTextPrimary;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accentHi    = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final elevated    = brightness == Brightness.dark ? AppColors.darkElevated   : AppColors.lightElevated;
    final borderSubtle= brightness == Brightness.dark ? AppColors.darkBorderSubtle: AppColors.lightBorderSubtle;
    final successColor= brightness == Brightness.dark ? AppColors.darkSuccess    : AppColors.lightSuccess;

    final unread = chats.unreadTotal;

    return Column(
      children: [
        // Header
        Container(
          color: surface,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, color: accentHi, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Messages', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd))),
                  AppIconButton(
                    icon: Icon(Icons.refresh_rounded, color: txSecondary, size: 18),
                    onTap: chats.loadRooms,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: elevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(
                      unread > 0 ? Icons.mark_chat_unread_outlined : Icons.check_circle_outline_rounded,
                      color: unread > 0 ? accentHi : successColor,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      unread > 0 ? '$unread unread message${unread != 1 ? 's' : ''}' : "You're all caught up",
                      style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: border, height: 1),

        Expanded(
          child: chats.isFirstRoomsLoad && chats.isLoadingRooms
              ? const LoadingView()
              : chats.roomsError != null && chats.rooms.isEmpty
                  ? ErrorView(message: chats.roomsError!, onRetry: chats.loadRooms)
                  : chats.rooms.isEmpty
                      ? const EmptyView(
                          icon: Icons.forum_outlined,
                          title: 'No conversations yet',
                          subtitle: 'Tap "Message Seller" on a listing to start one.',
                        )
                      : RefreshIndicator(
                          onRefresh: chats.loadRooms,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: chats.rooms.length,
                            itemBuilder: (_, i) => _ConversationTile(
                              room: chats.rooms[i],
                              me: me,
                              onTap: () => chats.openRoom(chats.rooms[i].id),
                              brightness: brightness,
                            ),
                          ),
                        ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ChatRoomEntity room;
  final String me;
  final VoidCallback onTap;
  final Brightness brightness;

  const _ConversationTile({
    required this.room,
    required this.me,
    required this.onTap,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent      : AppColors.lightAccent;
    final accentLo   = brightness == Brightness.dark ? AppColors.darkAccentLo   : AppColors.lightAccentLo;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final border     = room.unreadCount > 0 ? accentLo : (brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder);
    final shadow     = brightness == Brightness.dark ? AppColors.darkShadowCard  : AppColors.lightShadowCard;

    final other = room.otherParty(me);
    final last = room.lastMessage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [BoxShadow(color: shadow, blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              UserAvatar(initials: other?.initials ?? '?', size: 42, outlined: true),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(other?.fullName ?? 'Campus user',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                        ),
                        Text(timeAgo(room.lastActivity), style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (room.material != null)
                      Text('Re: ${room.material!.title}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                    Text(
                      last == null ? 'No messages yet. Say hi!' : '${last.senderId == me ? 'You: ' : ''}${last.content}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
                    ),
                  ],
                ),
              ),
              if (room.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  height: 20,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                  child: Center(
                    child: Text('${room.unreadCount}',
                        style: AppTextStyles.mono(Colors.white, fontSize: AppTextStyles.size2xs)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

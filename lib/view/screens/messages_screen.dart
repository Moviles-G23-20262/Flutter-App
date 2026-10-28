import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../model/entities/chat_room_entity.dart';
import '../../view_model/app_view_model.dart';
import '../widgets/async_views.dart';
import '../widgets/common_widgets.dart';
import '../widgets/formatters.dart';
import '../widgets/offline_banner.dart';
import '../widgets/power_saving_note.dart';
import '../widgets/saved_copy_banner.dart';
import 'chat_view.dart';

// ─── Messages Screen ──────────────────────────────────────────────────────────

class MessagesScreen extends StatefulWidget {
  final AppViewModel appState;

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
    return ListenableBuilder(
      listenable: Listenable.merge([widget.appState.chats, widget.appState.connectivity]),
      builder: (context, _) {
        final chats = widget.appState.chats;
        chats.setOffline(widget.appState.connectivity.isOffline);
        return chats.activeRoom != null
            ? ChatView(appState: widget.appState, room: chats.activeRoom!)
            : _ConversationList(appState: widget.appState);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final AppViewModel appState;

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
    final isOffline = appState.connectivity.isOffline;
    final savedAt = chats.roomsSavedAt;

    return Column(
      children: [
        if (savedAt != null)
          SavedCopyBanner(savedAt: savedAt, onRetry: chats.loadRooms)
        else if (isOffline && chats.rooms.isEmpty)
          OfflineBanner.firstLaunchOffline(noun: 'conversations', onRetry: chats.loadRooms),

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
        if (chats.isPowerSaving) const PowerSavingNote(),
        Divider(color: border, height: 1),

        // List
        Expanded(
          child: chats.isFirstRoomsLoad && chats.isLoadingRooms
              ? const LoadingView()
              : chats.roomsError != null && chats.rooms.isEmpty
                  ? (isOffline
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const EmptyView(
                                icon: Icons.wifi_off_rounded,
                                title: 'No saved conversations',
                                subtitle: 'Connect once to load your messages.',
                              ),
                              const SizedBox(height: 12),
                              PrimaryButton(label: 'Retry', onPressed: chats.loadRooms),
                            ],
                          ),
                        )
                      : ErrorView(message: chats.roomsError!, onRetry: chats.loadRooms))
                  : chats.rooms.isEmpty
                      ? (isOffline
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const EmptyView(
                                    icon: Icons.wifi_off_rounded,
                                    title: 'No saved conversations',
                                    subtitle: 'Connect once to load your messages.',
                                  ),
                                  const SizedBox(height: 12),
                                  PrimaryButton(label: 'Retry', onPressed: chats.loadRooms),
                                ],
                              ),
                            )
                          : const EmptyView(
                              icon: Icons.forum_outlined,
                              title: 'No conversations yet',
                              subtitle: 'Tap "Message Seller" on a listing to start one.',
                            ))
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
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final badgeBg    = brightness == Brightness.dark ? AppColors.darkAccent     : AppColors.lightAccent;

    final other      = room.otherParty(me);
    final isBuyer    = me == room.buyerId;
    final roleTag    = isBuyer ? 'Seller' : 'Buyer';
    final last       = room.lastMessage;
    final hasUnread  = room.unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            UserAvatar(initials: other?.initials ?? '?', size: 48, outlined: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          other?.fullName ?? 'Student',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (last != null)
                        Text(
                          timeAgo(last.createdAt),
                          style: AppTextStyles.mono(hasUnread ? accentHi : txMuted, fontSize: AppTextStyles.size2xs),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(roleTag, style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs)),
                      ),
                      const SizedBox(width: 6),
                      if (room.material != null)
                        Expanded(
                          child: Text(
                            room.material!.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.size2xs),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          last?.content ?? 'Conversation started',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(
                            hasUnread ? txPrimary : txMuted,
                            fontSize: AppTextStyles.sizeXs,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            '${room.unreadCount}',
                            style: AppTextStyles.mono(Colors.white, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

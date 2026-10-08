import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../Domain/Entities/chat_room_entity.dart';
import '../../Domain/Entities/exchange_entity.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Entities/meetup_entities.dart';
import '../../Domain/use_cases/meetup_use_cases.dart';
import '../State Management/app_state.dart';
import '../Widgets/async_views.dart';
import '../Widgets/common_widgets.dart';
import '../Widgets/conversation_insight_card.dart';
import '../Widgets/formatters.dart';
import '../Widgets/meetup_widgets.dart';
import '../Widgets/power_saving_note.dart';

// ─── One conversation ─────────────────────────────────────────────────────────

class ChatView extends StatefulWidget {
  final AppState appState;
  final ChatRoomEntity room;

  const ChatView({super.key, required this.appState, required this.room});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _hasText = false;
  int _shownCount = 0;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(() {
      final hasText = _msgCtrl.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    // The other side may have placed or completed an order since the list was loaded.
    widget.appState.account.refreshExchanges();
    widget.appState.chats.loadInsight();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send() async {
    final text = _msgCtrl.text;
    if (_sending || text.trim().isEmpty) return;
    setState(() => _sending = true);
    final error = await widget.appState.chats.send(widget.room.id, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      _msgCtrl.clear();
    } else {
      _showMessage(error);
    }
  }

  Future<void> _answer(MeetingProposalEntity proposal, ProposalAnswer answer) async {
    final error = await widget.appState.chats.answer(proposal.id, answer);
    if (error != null) {
      _showMessage(error);
    } else if (answer == ProposalAnswer.accept) {
      widget.appState.account.refreshExchanges();
    }
  }

  /// Keeps the newest message in view when new ones arrive.
  void _scrollToEndIfNeeded(int count) {
    if (count == _shownCount) return;
    _shownCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSafetyTips() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _SafetyTipsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.appState.account, widget.appState.chats]),
      builder: (context, _) => _buildChat(context),
    );
  }

  Widget _buildChat(BuildContext context) {
    final appState   = widget.appState;
    final chats      = appState.chats;
    final room       = widget.room;
    final me         = appState.currentUser?.id ?? '';
    final other      = room.otherParty(me);
    final otherFirst = other?.fullName.split(' ').first ?? 'them';
    final messages   = chats.messagesOf(room.id);
    final agreed     = chats.agreedMeetingIn(room.id)?.meetingProposal;
    final order      = appState.account.latestOrderFor(room.materialId, room.buyerId);
    final brightness = Theme.of(context).brightness;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final border     = brightness == Brightness.dark ? AppColors.darkBorder      : AppColors.lightBorder;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent      : AppColors.lightAccent;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;

    _scrollToEndIfNeeded(messages.length);

    return Column(
      children: [
        // ── Header ──
        Container(
          color: surface,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: txPrimary),
                onPressed: chats.closeRoom,
              ),
              UserAvatar(initials: other?.initials ?? '?', size: 44, outlined: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(other?.fullName ?? 'Campus user',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700)),
                    if (other != null)
                      Text(other.major,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Safety tips',
                icon: Icon(Icons.shield_outlined, color: accentHi),
                onPressed: _showSafetyTips,
              ),
            ],
          ),
        ),
        Divider(color: border, height: 1),

        // ── The listing being discussed ──
        if (room.material != null)
          _ListingStrip(
            material: room.material!,
            // The chat only embeds the listing itself; the marketplace copy also has the seller.
            onView: () => appState.openMaterialDetail(
              appState.marketplace.materials.where((m) => m.id == room.materialId).firstOrNull ?? room.material!,
            ),
          ),

        // ── Order status ──
        if (order != null)
          _OrderBanner(
            order: order,
            isBuyer: order.buyerId == me,
            otherFirstName: otherFirst,
            onOpen: () => appState.openCompleteExchange(order),
          ),

        // ── BQ4 insight: hidden once a meeting point has been agreed ──
        if (chats.insight != null && agreed == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: ConversationInsightCard(insight: chats.insight!, messagesSoFar: messages.length),
          ),

        // ── Messages ──
        Expanded(
          child: messages.isEmpty && chats.isLoadingMessages
              ? const LoadingView()
              : messages.isEmpty && chats.messagesError != null
                  ? ErrorView(message: chats.messagesError!, onRetry: chats.refreshMessages)
                  : ListView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      children: [
                        _DayChip(label: chatDayLabel(room.createdAt)),
                        _SystemNote(
                          text: room.material == null
                              ? 'Your phone number is never shared.'
                              : 'Chat started about "${room.material!.title}". Your phone number is never shared.',
                        ),
                        for (var i = 0; i < messages.length; i++) ...[
                          if (i == 0
                              ? chatDayLabel(messages[i].createdAt) != chatDayLabel(room.createdAt)
                              : chatDayLabel(messages[i].createdAt) != chatDayLabel(messages[i - 1].createdAt))
                            _DayChip(label: chatDayLabel(messages[i].createdAt)),
                          if (messages[i].meetingProposal != null)
                            _MeetingCard(
                              proposal: messages[i].meetingProposal!,
                              mine: messages[i].senderId == me,
                              otherFirstName: otherFirst,
                              onAnswer: (answer) => _answer(messages[i].meetingProposal!, answer),
                            )
                          else
                            _Bubble(message: messages[i], isMe: messages[i].senderId == me),
                        ],
                      ],
                    ),
        ),

        if (chats.isPowerSaving) const PowerSavingNote(),

        // ── Meetup + privacy row ──
        Container(
          color: elevated,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () => appState.openMeetingPlanner(room),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: agreed != null ? successColor(brightness).withValues(alpha: 0.16) : accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_outlined, size: 18,
                            color: agreed != null ? successColor(brightness) : accentHi),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            agreed != null
                                ? 'Meeting: ${agreed.meetingPoint?.name ?? 'agreed'}'
                                : 'Propose Meeting Point',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              agreed != null ? successColor(brightness) : accentHi,
                              fontSize: AppTextStyles.sizeXs,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.lock_outline_rounded, size: 14, color: txMuted),
              const SizedBox(width: 4),
              Text('No phone numbers shared',
                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
            ],
          ),
        ),

        // ── Input bar ──
        Container(
          color: elevated,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  enabled: !_sending,
                  maxLength: 2000,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs),
                  decoration: InputDecoration(
                    hintText: 'Message $otherFirst…',
                    counterText: '',
                    hintStyle: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                    filled: true,
                    fillColor: surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: borderSubtle)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: borderSubtle)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: accent, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: _hasText && !_sending ? accent : accent.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _sending
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ListingStrip extends StatelessWidget {
  final MaterialEntity material;
  final VoidCallback onView;

  const _ListingStrip({required this.material, required this.onView});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final tagBg      = brightness == Brightness.dark ? AppColors.darkTagBg       : AppColors.lightTagBg;
    final m = material;

    return Container(
      color: elevated,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56, height: 56,
              child: m.primaryImageUrl.isNotEmpty
                  ? Image.network(m.primaryImageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _ListingIcon(color: accentHi, background: tagBg))
                  : _ListingIcon(color: accentHi, background: tagBg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(copPrice(m.price),
                        style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700)),
                    if (m.condition != null) ...[
                      const SizedBox(width: 8),
                      StatusPill(label: m.conditionDisplayName, color: successColor(brightness)),
                    ],
                  ],
                ),
                if (m.courseCode != null) ...[
                  const SizedBox(height: 2),
                  Text(m.courseCode!, style: AppTextStyles.mono(txSecondary, fontSize: AppTextStyles.sizeXs)),
                ],
              ],
            ),
          ),
          TextButton(onPressed: onView, child: const Text('View')),
        ],
      ),
    );
  }
}

class _ListingIcon extends StatelessWidget {
  final Color color;
  final Color background;

  const _ListingIcon({required this.color, required this.background});

  @override
  Widget build(BuildContext context) =>
      Container(color: background, child: Icon(Icons.inventory_2_outlined, color: color, size: 28));
}

// ─────────────────────────────────────────────────────────────────────────────

class _OrderBanner extends StatelessWidget {
  final ExchangeEntity order;
  final bool isBuyer;
  final String otherFirstName;
  final VoidCallback onOpen;

  const _OrderBanner({
    required this.order,
    required this.isBuyer,
    required this.otherFirstName,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface   : AppColors.lightSurface;
    final border     = brightness == Brightness.dark ? AppColors.darkBorder    : AppColors.lightBorder;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final String text;
    final String? action;
    if (order.isPending) {
      text = isBuyer ? 'You ordered this · pay in person' : '$otherFirstName ordered this item';
      action = isBuyer ? 'Complete exchange' : null;
    } else {
      text = 'Exchange completed';
      action = 'Rate $otherFirstName';
    }

    return Container(
      decoration: BoxDecoration(color: surface, border: Border(bottom: BorderSide(color: border))),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Icon(order.isPending ? Icons.receipt_long_outlined : Icons.check_circle_outline_rounded,
              size: 16, color: order.isPending ? txSecondary : successColor(brightness)),
          const SizedBox(width: 8),
          Text(order.orderCode, style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.sizeXs)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
          ),
          if (action != null) TextButton(onPressed: onOpen, child: Text(action)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DayChip extends StatelessWidget {
  final String label;

  const _DayChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated : AppColors.lightElevated;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: elevated, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _SystemNote extends StatelessWidget {
  final String text;

  const _SystemNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: txMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, textAlign: TextAlign.center,
                style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;

  const _Bubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent      : AppColors.lightAccent;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final onMe = Colors.white.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 9),
            decoration: BoxDecoration(
              color: isMe ? accent : elevated,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 6),
                bottomRight: Radius.circular(isMe ? 6 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(message.content,
                      style: AppTextStyles.body(isMe ? Colors.white : txPrimary, fontSize: AppTextStyles.sizeSm)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(hourMinute(message.createdAt),
                        style: AppTextStyles.mono(isMe ? onMe : txMuted, fontSize: AppTextStyles.sizeXs)),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 15, color: message.isRead ? AppColors.success400 : onMe),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// A meetup proposal inside the chat, with its live status and the answer buttons.
class _MeetingCard extends StatelessWidget {
  final MeetingProposalEntity proposal;
  final bool mine;
  final String otherFirstName;
  final void Function(ProposalAnswer) onAnswer;

  const _MeetingCard({
    required this.proposal,
    required this.mine,
    required this.otherFirstName,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final success    = successColor(brightness);
    final point      = proposal.meetingPoint;

    final (Color tone, String title, String subtitle) = switch (proposal.status) {
      MeetingProposalStatusEnum.PENDING => (
          accentHi,
          'Meeting proposed',
          mine ? 'Waiting for $otherFirstName to answer' : '$otherFirstName proposed this',
        ),
      MeetingProposalStatusEnum.ACCEPTED => (success, 'Meeting confirmed', 'Confirmed by both'),
      MeetingProposalStatusEnum.DECLINED => (
          txMuted,
          'Meeting declined',
          mine ? '$otherFirstName declined it' : 'You declined it',
        ),
      MeetingProposalStatusEnum.CANCELLED => (txMuted, 'Meeting no longer active', 'Replaced or withdrawn'),
    };
    final active = proposal.isPending || proposal.isAccepted;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? tone.withValues(alpha: 0.6) : borderSubtle, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: tone.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(Icons.location_on_outlined, color: tone, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.body(tone, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700)),
                    Text(subtitle, style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(point?.name ?? 'Campus meeting point',
              style: AppTextStyles.body(active ? txPrimary : txMuted, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700)
                  .copyWith(decoration: active ? null : TextDecoration.lineThrough)),
          const SizedBox(height: 2),
          Text('${dayLabel(proposal.startsAt)} · ${timeRange(proposal.startsAt, proposal.endsAt)}',
              style: AppTextStyles.mono(active ? txSecondary : txMuted, fontSize: AppTextStyles.sizeXs)),
          if (point != null && active) ...[
            const SizedBox(height: 8),
            SafeZoneLabel(monitored: point.isMonitored, compact: true),
          ],
          if (proposal.isPending) ...[
            const SizedBox(height: 12),
            if (mine)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onAnswer(ProposalAnswer.withdraw),
                  child: const Text('Withdraw'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onAnswer(ProposalAnswer.decline),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onAnswer(ProposalAnswer.accept),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SafetyTipsSheet extends StatelessWidget {
  const _SafetyTipsSheet();

  static const _tips = [
    (Icons.videocam_outlined, 'Meet only in monitored campus zones, during the day.'),
    (Icons.fact_check_outlined, 'Check the item works and matches the photos before paying.'),
    (Icons.payments_outlined, 'Pay in person when you meet. Never pay in advance.'),
    (Icons.lock_outline_rounded, 'Keep the conversation here. No phone numbers or passwords.'),
    (Icons.local_police_outlined, 'Something feels off? Leave and contact campus security.'),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Swap safely', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
            const SizedBox(height: 14),
            for (final tip in _tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(tip.$1, size: 20, color: accentHi),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tip.$2, style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

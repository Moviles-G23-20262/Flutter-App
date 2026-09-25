import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';

// ─── Mock Chat Data ────────────────────────────────────────────────────────────

class _MockConversation {
  final String name;
  final String initials;
  final String itemTitle;
  final String lastMessage;
  final String time;
  final int unread;
  final bool online;
  final String meetupPlace;
  final String meetupTime;
  final List<_MockMessage> messages;

  const _MockConversation({
    required this.name,
    required this.initials,
    required this.itemTitle,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.online,
    required this.meetupPlace,
    required this.meetupTime,
    required this.messages,
  });
}

class _MockMessage {
  final bool isMe;
  final String text;
  final String time;

  const _MockMessage({required this.isMe, required this.text, required this.time});
}

const _kConversations = [
  _MockConversation(
    name: 'Jake Reyes', initials: 'JR', itemTitle: 'Organic Chemistry Textbook',
    lastMessage: 'Library steps at 3 PM works for me.', time: '2m ago', unread: 2, online: true,
    meetupPlace: 'Main Library steps', meetupTime: 'Today, 3:00 PM',
    messages: [
      _MockMessage(isMe: false, text: 'Hey, is the Organic Chemistry textbook still available?', time: '2:21 PM'),
      _MockMessage(isMe: true,  text: 'Yes, it is. It has some highlighting in chapters 3-5, but all pages are intact.', time: '2:23 PM'),
      _MockMessage(isMe: false, text: 'That works. Could we meet near the library?', time: '2:24 PM'),
      _MockMessage(isMe: true,  text: 'Library steps at 3 PM works for me.', time: '2:25 PM'),
    ],
  ),
  _MockConversation(
    name: 'Sofia Lim', initials: 'SL', itemTitle: 'TI-84 Plus Calculator',
    lastMessage: 'Could you do ₱32 if I pick it up today?', time: '18m ago', unread: 0, online: true,
    meetupPlace: 'Engineering lobby', meetupTime: 'Today, 5:15 PM',
    messages: [
      _MockMessage(isMe: false, text: 'Could you do ₱32 if I pick it up today?', time: '1:58 PM'),
      _MockMessage(isMe: true,  text: 'I can meet you at the Engineering lobby after class.', time: '2:02 PM'),
      _MockMessage(isMe: false, text: 'Perfect, I can be there around 5:15.', time: '2:04 PM'),
    ],
  ),
  _MockConversation(
    name: 'Ana Cruz', initials: 'AC', itemTitle: 'Lab Coat Size M',
    lastMessage: 'I can bring it after BIO lab.', time: '1h ago', unread: 0, online: false,
    meetupPlace: 'Science building entrance', meetupTime: 'Tomorrow, 10:30 AM',
    messages: [
      _MockMessage(isMe: true,  text: 'Hi Ana, is the lab coat still clean and ready?', time: '12:31 PM'),
      _MockMessage(isMe: false, text: 'Yes, washed and ready. I can bring it after BIO lab.', time: '12:39 PM'),
      _MockMessage(isMe: true,  text: 'Great. Science building entrance tomorrow?', time: '12:42 PM'),
    ],
  ),
  _MockConversation(
    name: 'Leo Tan', initials: 'LT', itemTitle: 'Data Structures Book',
    lastMessage: 'Still available, pages are all intact.', time: '3h ago', unread: 1, online: false,
    meetupPlace: 'Computer Science lounge', meetupTime: 'Friday, 1:00 PM',
    messages: [
      _MockMessage(isMe: true,  text: 'Is the Data Structures book still available?', time: '10:10 AM'),
      _MockMessage(isMe: false, text: 'Still available, pages are all intact.', time: '10:12 AM'),
      _MockMessage(isMe: false, text: 'There are pencil notes in the graph chapters.', time: '10:13 AM'),
    ],
  ),
];

// ─── Messages Screen ──────────────────────────────────────────────────────────

class MessagesScreen extends StatefulWidget {
  final AppState appState;

  const MessagesScreen({super.key, required this.appState});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  _MockConversation? _activeChat;

  @override
  Widget build(BuildContext context) {
    if (_activeChat != null) {
      return _ChatView(
        conversation: _activeChat!,
        onBack: () => setState(() => _activeChat = null),
      );
    }
    return _ConversationList(
      onOpenChat: (c) => setState(() => _activeChat = c),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final ValueChanged<_MockConversation> onOpenChat;

  const _ConversationList({required this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surface     = brightness == Brightness.dark ? AppColors.darkSurface    : AppColors.lightSurface;
    final border      = brightness == Brightness.dark ? AppColors.darkBorder     : AppColors.lightBorder;
    final txPrimary   = brightness == Brightness.dark ? AppColors.darkTextPrimary: AppColors.lightTextPrimary;
    final txMuted     = brightness == Brightness.dark ? AppColors.darkTextMuted  : AppColors.lightTextMuted;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accentHi    = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final elevated    = brightness == Brightness.dark ? AppColors.darkElevated   : AppColors.lightElevated;
    final borderSubtle= brightness == Brightness.dark ? AppColors.darkBorderSubtle: AppColors.lightBorderSubtle;
    final successColor= brightness == Brightness.dark ? AppColors.darkSuccess    : AppColors.lightSuccess;
    final accent      = brightness == Brightness.dark ? AppColors.darkAccent     : AppColors.lightAccent;

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
                  AppIconButton(icon: Icon(Icons.search_rounded, color: txSecondary, size: 18)),
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
                    Icon(Icons.check_circle_outline_rounded, color: successColor, size: 15),
                    const SizedBox(width: 8),
                    Text('3 active handoffs this week',
                        style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: border, height: 1),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Chats
                Row(
                  children: [
                    Icon(Icons.inbox_rounded, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Recent Chats'),
                  ],
                ),
                const SizedBox(height: 12),
                ..._kConversations.map((c) => _ConversationTile(
                  conv: c,
                  onTap: () => onOpenChat(c),
                  isFirst: c == _kConversations.first,
                  brightness: brightness,
                )),
                const SizedBox(height: 20),

                // Handoff Details
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Handoff Details'),
                  ],
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 15)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_kConversations.first.name,
                                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(_kConversations.first.lastMessage,
                                    style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: elevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Place', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                                const SizedBox(height: 2),
                                Text(_kConversations.first.meetupPlace,
                                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                              ],
                            )),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Time', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                                const SizedBox(height: 2),
                                Text(_kConversations.first.meetupTime,
                                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                              ],
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SecondaryButton(
                        label: 'Open Chat',
                        leadingIcon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        onPressed: () => onOpenChat(_kConversations.first),
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final _MockConversation conv;
  final VoidCallback onTap;
  final bool isFirst;
  final Brightness brightness;

  const _ConversationTile({
    required this.conv,
    required this.onTap,
    required this.isFirst,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent      : AppColors.lightAccent;
    final accentLo   = brightness == Brightness.dark ? AppColors.darkAccentLo   : AppColors.lightAccentLo;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final border     = isFirst ? accentLo : (brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder);
    final shadow     = brightness == Brightness.dark ? AppColors.darkShadowCard  : AppColors.lightShadowCard;
    final successColor = brightness == Brightness.dark ? AppColors.darkSuccess   : AppColors.lightSuccess;

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
              // Avatar with online dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(initials: conv.initials, size: 42, outlined: true),
                  if (conv.online)
                    Positioned(
                      right: 0, bottom: 1,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: successColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(conv.name,
                              style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                        ),
                        Text(conv.time, style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Re: ${conv.itemTitle}',
                        style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                    Text(conv.lastMessage,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
                  ],
                ),
              ),
              if (conv.unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  height: 20,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                  child: Center(
                    child: Text('${conv.unread}',
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

// ─────────────────────────────────────────────────────────────────────────────

class _ChatView extends StatefulWidget {
  final _MockConversation conversation;
  final VoidCallback onBack;

  const _ChatView({required this.conversation, required this.onBack});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c          = widget.conversation;
    final brightness = Theme.of(context).brightness;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface    : AppColors.lightSurface;
    final bg         = brightness == Brightness.dark ? AppColors.darkBg         : AppColors.lightBg;
    final border     = brightness == Brightness.dark ? AppColors.darkBorder     : AppColors.lightBorder;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary: AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted  : AppColors.lightTextMuted;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi  : AppColors.lightAccentHi;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent     : AppColors.lightAccent;
    final accentLo   = brightness == Brightness.dark ? AppColors.darkAccentLo  : AppColors.lightAccentLo;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated   : AppColors.lightElevated;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final successColor = brightness == Brightness.dark ? AppColors.darkSuccess  : AppColors.lightSuccess;
    final shadow     = brightness == Brightness.dark ? AppColors.darkShadowCard : AppColors.lightShadowCard;

    return Column(
      children: [
        // Header
        Container(
          color: surface,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              AppIconButton(
                icon: Icon(Icons.arrow_back_rounded, color: txSecondary, size: 18),
                onTap: widget.onBack,
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(initials: c.initials, size: 40, outlined: true),
                  if (c.online)
                    Positioned(
                      right: 0, bottom: 1,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: successColor, shape: BoxShape.circle,
                          border: Border.all(color: surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                    Text('Re: ${c.itemTitle}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: border, height: 1),

        // Messages
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(14),
            children: [
              // Meetup info card
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Meetup', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                        Text(c.meetupPlace, style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                      ],
                    )),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Time', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                        Text(c.meetupTime, style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                      ],
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Chat bubbles
              ...c.messages.map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                      decoration: BoxDecoration(
                        color: msg.isMe ? accent : surface,
                        border: Border.all(color: msg.isMe ? accentLo : border),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: msg.isMe ? const Radius.circular(14) : const Radius.circular(4),
                          bottomRight: msg.isMe ? const Radius.circular(4) : const Radius.circular(14),
                        ),
                        boxShadow: [BoxShadow(color: shadow, blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(msg.text,
                              style: AppTextStyles.body(
                                msg.isMe ? Colors.white : txSecondary,
                                fontSize: AppTextStyles.sizeXs,
                              )),
                          const SizedBox(height: 4),
                          Text(msg.time,
                              style: AppTextStyles.mono(
                                msg.isMe ? Colors.white.withOpacity(0.7) : txMuted,
                                fontSize: AppTextStyles.size2xs,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),

        // Input bar
        Container(
          color: surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: AppTextStyles.body(
                    brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: AppTextStyles.sizeXs,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write a message…',
                    hintStyle: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                    filled: true,
                    fillColor: elevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderSubtle)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderSubtle)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () { _msgCtrl.clear(); },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentLo),
                  ),
                  child: const Center(child: Icon(Icons.send_rounded, color: Colors.white, size: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Helper extension
extension on SecondaryButton {
  // ignore: unused_element
  Widget get _trailing => const Icon(Icons.arrow_forward_rounded, size: 14);
}


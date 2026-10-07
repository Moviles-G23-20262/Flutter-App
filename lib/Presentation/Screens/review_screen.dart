import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../Domain/Entities/notification_entity.dart';
import '../State Management/app_state.dart';
import '../State Management/account_state.dart';
import '../Widgets/async_views.dart';
import '../Widgets/common_widgets.dart';
import '../Widgets/formatters.dart';

// ─── Notifications Screen ─────────────────────────────────────────────────────

enum NotificationFilter {
  all,
  unread,
  smartMatch,
  orders,
}

class NotificationsScreen extends StatefulWidget {
  final AppState appState;

  const NotificationsScreen({
    super.key,
    required this.appState,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationFilter _filter = NotificationFilter.all;

  AppState get appState => widget.appState;

  void _open(NotificationEntity notification) {
    appState.account.openNotification(notification.id);

    final material = notification.material;

    if (material != null) {
      appState.openMaterialDetail(material);
    }
  }

  List<NotificationEntity> _filteredNotifications(
    AccountState account,
  ) {
    switch (_filter) {
      case NotificationFilter.all:
        return account.notifications;

      case NotificationFilter.unread:
        return account.notifications
            .where((notification) => notification.isUnread)
            .toList();

      case NotificationFilter.smartMatch:
        return account.notifications
            .where(
              (notification) =>
                  notification.type == NotificationTypeEnum.SMART_MATCH,
            )
            .toList();

      case NotificationFilter.orders:
        return account.notifications
            .where(
              (notification) =>
                  notification.type == NotificationTypeEnum.ORDER_PLACED,
            )
            .toList();
    }
  }


  @override
  Widget build(BuildContext context) {

    final dark        = Theme.of(context).brightness == Brightness.dark;
    final surface     = dark ? AppColors.darkSurface       : AppColors.lightSurface;
    final border      = dark ? AppColors.darkBorder        : AppColors.lightBorder;
    final txPrimary   = dark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
    final txMuted     = dark ? AppColors.darkTextMuted     : AppColors.lightTextMuted;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accent      = dark ? AppColors.darkAccent        : AppColors.lightAccent;
    final accentHi    = dark ? AppColors.darkAccentHi      : AppColors.lightAccentHi;
    return Scaffold(


      body: SafeArea(
        child: ListenableBuilder(
          listenable: appState.account,
          builder: (context, _) {
            final account = appState.account;
            final items = _filteredNotifications(account);

            return Column(
              children: [
                Container(
                  color: surface,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: txSecondary,
                          size: 18,
                        ),
                        onTap: () => appState.navigateTo(AppScreen.home),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.notifications_outlined,
                        color: accentHi,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: AppTextStyles.heading(
                            txPrimary,
                            fontSize: AppTextStyles.sizeMd,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: account.unreadNotifications == 0
                      ? null
                      : () async {
                          await account.markAllNotificationsOpened();
                        },
                  child: const Text('Mark all as read'),
                ),

                _buildNotificationFilters(),

                Divider(
                  color: border,
                  height: 1,
                ),

                Expanded(
                  child: account.isFirstLoad && account.isLoading
                      ? const LoadingView()
                      : account.error != null && items.isEmpty
                          ? ErrorView(
                              message: account.error!,
                              onRetry: account.load,
                            )
                          : items.isEmpty
                              ? const EmptyView(
                                  icon: Icons.notifications_none_rounded,
                                  title: 'Nothing new',
                                  subtitle:
                                      "We'll let you know when something matches what you are looking for.",
                                )
                              : RefreshIndicator(
                                  onRefresh: account.load,
                                  child: ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: items.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, i) {
                                      final n = items[i];

                                      return AppCard(
                                        padding: const EdgeInsets.all(14),
                                        onTap: () => _open(n),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: n.isUnread
                                                    ? accent
                                                    : Colors.transparent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    n.type.displayName,
                                                    style: AppTextStyles.body(
                                                      txPrimary,
                                                      fontSize:
                                                          AppTextStyles.sizeXs,
                                                      fontWeight: n.isUnread
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (n.material != null)
                                                    Text(
                                                      n.material!.title,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: AppTextStyles.body(
                                                        txSecondary,
                                                        fontSize:
                                                            AppTextStyles.sizeXs,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              timeAgo(n.sentAt),
                                              style: AppTextStyles.mono(
                                                txMuted,
                                                fontSize:
                                                    AppTextStyles.size2xs,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationFilters() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip(
            label: 'All',
            filter: NotificationFilter.all,
          ),
          _filterChip(
            label: 'Unread',
            filter: NotificationFilter.unread,
          ),
          _filterChip(
            label: 'Matches',
            filter: NotificationFilter.smartMatch,
          ),
          _filterChip(
            label: 'Orders',
            filter: NotificationFilter.orders,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required NotificationFilter filter,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == filter,
        onSelected: (_) {
          setState(() {
            _filter = filter;
          });
        },
      ),
    );
  }
}
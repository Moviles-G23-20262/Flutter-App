import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../Domain/Entities/notification_entity.dart';
import '../State Management/app_state.dart';
import '../Widgets/async_views.dart';
import '../Widgets/common_widgets.dart';
import '../Widgets/formatters.dart';

// ─── Notifications Screen ─────────────────────────────────────────────────────

class NotificationsScreen extends StatelessWidget {
  final AppState appState;

  const NotificationsScreen({super.key, required this.appState});

  void _open(NotificationEntity notification) {
    appState.account.openNotification(notification.id);
    final material = notification.material;
    if (material != null) appState.openMaterialDetail(material);
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
            final items = account.notifications;

            return Column(
              children: [
                Container(
                  color: surface,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: txSecondary, size: 18),
                        onTap: () => appState.navigateTo(AppScreen.home),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.notifications_outlined, color: accentHi, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Notifications', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd))),
                    ],
                  ),
                ),
                Divider(color: border, height: 1),
                Expanded(
                  child: account.isFirstLoad && account.isLoading
                      ? const LoadingView()
                      : account.error != null && items.isEmpty
                          ? ErrorView(message: account.error!, onRetry: account.load)
                          : items.isEmpty
                              ? const EmptyView(
                                  icon: Icons.notifications_none_rounded,
                                  title: 'Nothing new',
                                  subtitle: "We'll let you know when something matches what you are looking for.",
                                )
                              : RefreshIndicator(
                                  onRefresh: account.load,
                                  child: ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: items.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                                    itemBuilder: (_, i) {
                                      final n = items[i];
                                      return AppCard(
                                        padding: const EdgeInsets.all(14),
                                        onTap: () => _open(n),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10, height: 10,
                                              decoration: BoxDecoration(
                                                color: n.isUnread ? accent : Colors.transparent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(n.type.displayName,
                                                      style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs,
                                                          fontWeight: n.isUnread ? FontWeight.w700 : FontWeight.w500)),
                                                  if (n.material != null)
                                                    Text(n.material!.title,
                                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                                        style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(timeAgo(n.sentAt), style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs)),
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
}

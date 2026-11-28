import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../model/rules/my_meetups.dart';
import '../../view_model/app_view_model.dart';
import '../../view_model/my_meetups_view_model.dart';
import '../widgets/async_views.dart';
import '../widgets/common_widgets.dart';
import '../widgets/formatters.dart';

// ─── My Meetups Screen ────────────────────────────────────────────────────────

/// The signed-in user's agenda of exchanges: upcoming meetings, meetings whose time passed and
/// still need confirming, and orders without a place and time yet. Only draws
/// [MyMeetupsViewModel] and forwards taps; it works offline with the orders already saved.
class MyMeetupsScreen extends StatefulWidget {
  final AppViewModel appState;

  /// Builds this screen's view-model; called once, and the screen disposes it.
  final MyMeetupsViewModel Function() createViewModel;

  const MyMeetupsScreen({super.key, required this.appState, required this.createViewModel});

  @override
  State<MyMeetupsScreen> createState() => _MyMeetupsScreenState();
}

class _MyMeetupsScreenState extends State<MyMeetupsScreen> {
  late final MyMeetupsViewModel _vm = widget.createViewModel();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _openChat(MeetupItem item) async {
    final error = await widget.appState.openMeetupChat(item.exchange);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final bg = dark ? AppColors.darkBg : AppColors.lightBg;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            final meetups = _vm.meetups;
            return Column(
              children: [
                Container(
                  color: surface,
                  padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('my-meetups-back'),
                        tooltip: 'Back to profile',
                        icon: Icon(Icons.arrow_back_rounded, color: txPrimary),
                        onPressed: () => widget.appState.navigateTo(AppScreen.profile),
                      ),
                      const SizedBox(width: 6),
                      Text('My meetups', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                    ],
                  ),
                ),
                Expanded(
                  child: meetups.isEmpty && _vm.loading
                      ? const LoadingView()
                      : RefreshIndicator(
                          onRefresh: _vm.refresh,
                          child: meetups.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 80),
                                    EmptyView(
                                      icon: Icons.event_available_outlined,
                                      title: 'No meetups yet',
                                      subtitle: 'When you buy or sell an item, the exchange shows up here '
                                          'with the place and time you agree on in the chat.',
                                    ),
                                  ],
                                )
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                  children: [
                                    ..._section(
                                      'Upcoming',
                                      meetups.upcoming,
                                      brightness,
                                      (item) => _MeetupCard(
                                        item: item,
                                        now: _vm.now,
                                        primaryLabel: 'Open chat',
                                        onPrimary: () => _openChat(item),
                                      ),
                                    ),
                                    ..._section(
                                      'Time passed · confirm the exchange',
                                      meetups.toComplete,
                                      brightness,
                                      (item) => _MeetupCard(
                                        item: item,
                                        now: _vm.now,
                                        primaryLabel: item.isBuyer ? 'Complete exchange' : 'Rate or check',
                                        onPrimary: () => widget.appState.openCompleteExchange(item.exchange),
                                        secondaryLabel: 'Open chat',
                                        onSecondary: () => _openChat(item),
                                      ),
                                    ),
                                    ..._section(
                                      'No place and time yet',
                                      meetups.notAgreed,
                                      brightness,
                                      (item) => _MeetupCard(
                                        item: item,
                                        now: _vm.now,
                                        primaryLabel: 'Agree in the chat',
                                        onPrimary: () => _openChat(item),
                                      ),
                                    ),
                                  ],
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

  List<Widget> _section(String title, List<MeetupItem> items, Brightness brightness, Widget Function(MeetupItem) card) {
    if (items.isEmpty) return const [];
    final txMuted = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(
          '${title.toUpperCase()} (${items.length})',
          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w700),
        ),
      ),
      for (final item in items)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: card(item)),
      const SizedBox(height: 8),
    ];
  }
}

class _MeetupCard extends StatelessWidget {
  final MeetupItem item;
  final DateTime now;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _MeetupCard({
    required this.item,
    required this.now,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// "In 45 min", "Today", "Tomorrow" or nothing (the date already says it).
  String? _whenHint(DateTime start) {
    final local = start.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final minutes = start.difference(now).inMinutes;
    if (minutes > 0 && minutes < 60) return 'In $minutes min';
    if (!start.isAfter(now) && (item.endsAt?.isAfter(now) ?? false)) return 'Now';
    if (day == today) return 'Today';
    if (day.difference(today).inDays == 1) return 'Tomorrow';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    final tagBg = dark ? AppColors.darkTagBg : AppColors.lightTagBg;

    final exchange = item.exchange;
    final start = item.startsAt;
    final end = item.endsAt;
    final hint = start == null ? null : _whenHint(start);
    final otherName = item.other?.fullName ?? (item.isBuyer ? 'the seller' : 'the buyer');
    final role = item.isBuyer ? 'Buying from $otherName' : 'Selling to $otherName';
    final place = exchange.meetingPoint?.name;

    return Semantics(
      container: true,
      label: [
        exchange.material?.title ?? 'Item',
        role,
        if (place != null) 'at $place',
        if (start != null && end != null) '${dayLabel(start)} ${timeRange(start, end)}',
      ].join(', '),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exchange.material?.title ?? 'Item',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700),
                  ),
                ),
                if (hint != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(hint,
                        style: AppTextStyles.body(accentHi, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$role · ${copPrice(exchange.price)} · ${exchange.orderCode}',
                style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(start == null ? Icons.chat_bubble_outline_rounded : Icons.location_on_outlined, size: 16, color: txMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    start == null || end == null
                        ? 'No meeting point agreed yet'
                        : '${place ?? 'Meeting point'} · ${dayLabel(start)} ${timeRange(start, end)}',
                    style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(secondaryLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

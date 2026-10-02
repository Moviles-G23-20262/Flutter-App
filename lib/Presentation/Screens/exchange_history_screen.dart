import 'package:flutter/material.dart';

import '../../Domain/Entities/exchange_entity.dart';
import '../../theme/app_theme.dart';
import '../State Management/app_state.dart';
import '../Widgets/common_widgets.dart';
import '../Widgets/formatters.dart';

class ExchangeHistoryScreen extends StatefulWidget {
  final AppState appState;

  const ExchangeHistoryScreen({
    super.key,
    required this.appState,
  });

  @override
  State<ExchangeHistoryScreen> createState() =>
      _ExchangeHistoryScreenState();
}

class _ExchangeHistoryScreenState
    extends State<ExchangeHistoryScreen> {
  ExchangeStatusEnum? _filter;

  List<ExchangeEntity> get _exchanges {
    final userId = widget.appState.currentUser?.id;

    if (userId == null) return [];

    final list = widget.appState.account.exchanges
        .where(
          (exchange) =>
              exchange.buyerId == userId ||
              exchange.sellerId == userId,
        )
        .where(
          (exchange) =>
              _filter == null ||
              exchange.status == _filter,
        )
        .toList();

    list.sort((a, b) {
      final aDate =
          a.completedAt ?? a.createdAt ?? DateTime(1970);

      final bDate =
          b.completedAt ?? b.createdAt ?? DateTime(1970);

      return bDate.compareTo(aDate);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final background = isDark
        ? AppColors.darkBg
        : AppColors.lightBg;

    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final muted = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Exchange History',
          style: AppTextStyles.heading(
            primary,
            fontSize: AppTextStyles.sizeMd,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.appState.account,
        builder: (context, _) {
          final exchanges = _exchanges;

          return Column(
            children: [
              _filters(muted),

              Expanded(
                child: exchanges.isEmpty
                    ? Center(
                        child: Text(
                          'No exchanges found.',
                          style: AppTextStyles.body(
                            muted,
                            fontSize: AppTextStyles.sizeSm,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await widget.appState.account
                              .refreshExchanges();
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: exchanges.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            return _ExchangeCard(
                              exchange: exchanges[index],
                              myId:
                                  widget.appState.currentUser!.id,
                              onTap: () {
                                widget.appState
                                    .openCompleteExchange(
                                  exchanges[index],
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filters(Color muted) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _chip(
            'All',
            _filter == null,
            () => setState(() => _filter = null),
            muted,
          ),
          _chip(
            'Pending',
            _filter == ExchangeStatusEnum.PENDING,
            () => setState(
              () => _filter = ExchangeStatusEnum.PENDING,
            ),
            muted,
          ),
          _chip(
            'Completed',
            _filter == ExchangeStatusEnum.COMPLETED,
            () => setState(
              () => _filter = ExchangeStatusEnum.COMPLETED,
            ),
            muted,
          ),
          _chip(
            'Cancelled',
            _filter == ExchangeStatusEnum.CANCELLED,
            () => setState(
              () => _filter = ExchangeStatusEnum.CANCELLED,
            ),
            muted,
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap,
    Color muted,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          color: selected ? Colors.white : muted,
        ),
      ),
    );
  }
}

class _ExchangeCard extends StatelessWidget {
  final ExchangeEntity exchange;
  final String myId;
  final VoidCallback onTap;

  const _ExchangeCard({
    required this.exchange,
    required this.myId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final muted = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    final accent = isDark
        ? AppColors.darkAccentHi
        : AppColors.lightAccentHi;

    final isBuyer = exchange.buyerId == myId;
    final other = exchange.otherParty(myId);

    final date =
        exchange.completedAt ?? exchange.createdAt;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: exchange.material?.primaryImageUrl.isNotEmpty ==
                      true
                  ? Image.network(
                      exchange.material!.primaryImageUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: isDark
                          ? AppColors.darkElevated
                          : AppColors.lightElevated,
                      child: const Icon(Icons.inventory_2_outlined),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  exchange.material?.title ?? 'Exchange',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    primary,
                    fontSize: AppTextStyles.sizeSm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBuyer
                      ? 'Bought from ${other?.fullName ?? 'student'}'
                      : 'Sold to ${other?.fullName ?? 'student'}',
                  style: AppTextStyles.body(
                    muted,
                    fontSize: AppTextStyles.sizeXs,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exchange.orderCode} · ${timeAgo(date ?? DateTime(1970))}',
                  style: AppTextStyles.mono(
                    muted,
                    fontSize: AppTextStyles.size2xs,
                  ),
                ),
              ],
            ),
          ),

          Text(
            copPrice(exchange.price),
            style: AppTextStyles.price(
              accent,
              fontSize: AppTextStyles.sizeXs,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../model/entities/average_ticket.dart';
import '../../view_model/average_ticket_view_model.dart';
import 'common_widgets.dart';
import 'formatters.dart';

/// Average ticket of completed campus sales: the overall figure in COP and a bar per condition.
/// Starts loading when shown; it only reacts to [viewModel].
class AverageTicketCard extends StatefulWidget {
  final AverageTicketViewModel viewModel;

  const AverageTicketCard({super.key, required this.viewModel});

  @override
  State<AverageTicketCard> createState() => _AverageTicketCardState();
}

class _AverageTicketCardState extends State<AverageTicketCard> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = _Palette(
      txPrimary: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      txMuted: dark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      accentHi: dark ? AppColors.darkAccentHi : AppColors.lightAccentHi,
      track: dark ? AppColors.darkElevated : AppColors.lightElevated,
      error: dark ? AppColors.darkError : AppColors.lightError,
    );

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final ticket = vm.ticket;
        final Widget body;
        if (ticket != null && ticket.hasData) {
          body = _Figures(ticket: ticket, palette: palette);
        } else if (ticket != null) {
          body = _Message(
            icon: Icons.hourglass_empty_rounded,
            text: 'No completed sales yet. The average appears after the first campus exchange.',
            palette: palette,
          );
        } else if (vm.error != null && !vm.isLoading) {
          body = _ErrorMessage(message: vm.error!, onRetry: () => vm.load(force: true), palette: palette);
        } else {
          body = _Loading(palette: palette);
        }

        return AppCard(
          key: const Key('average-ticket-card'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_outlined, color: palette.accentHi, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Average Ticket',
                      style: AppTextStyles.body(palette.txPrimary,
                          fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('Completed sales', style: AppTextStyles.body(palette.txMuted, fontSize: AppTextStyles.size2xs)),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: body),
            ],
          ),
        );
      },
    );
  }
}

class _Palette {
  final Color txPrimary, txMuted, accentHi, track, error;

  const _Palette({
    required this.txPrimary,
    required this.txMuted,
    required this.accentHi,
    required this.track,
    required this.error,
  });
}

class _Figures extends StatelessWidget {
  final AverageTicket ticket;
  final _Palette palette;

  const _Figures({required this.ticket, required this.palette});

  @override
  Widget build(BuildContext context) {
    final highest = ticket.highestByCondition;
    return Column(
      key: const Key('average-ticket-figures'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copPrice(ticket.globalAverage!.toDouble()),
          key: const Key('average-ticket-global'),
          style: AppTextStyles.price(palette.accentHi, fontSize: AppTextStyles.sizeMd),
        ),
        Text('per completed sale on campus',
            style: AppTextStyles.body(palette.txMuted, fontSize: AppTextStyles.size2xs)),
        if (ticket.byCondition.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final entry in ticket.byCondition.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(entry.key.displayName,
                        style: AppTextStyles.body(palette.txPrimary, fontSize: AppTextStyles.size2xs)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: highest == 0 ? 0 : entry.value / highest,
                        minHeight: 6,
                        backgroundColor: palette.track,
                        valueColor: AlwaysStoppedAnimation(palette.accentHi),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: Text(
                      copPrice(entry.value.toDouble()),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.mono(palette.txPrimary, fontSize: AppTextStyles.size2xs),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  final _Palette palette;

  const _Loading({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('average-ticket-loading'),
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: palette.accentHi),
        ),
        const SizedBox(width: 8),
        Text('Loading sale prices…', style: AppTextStyles.body(palette.txMuted, fontSize: AppTextStyles.size2xs)),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final _Palette palette;

  const _Message({required this.icon, required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('average-ticket-empty'),
      children: [
        Icon(icon, color: palette.txMuted, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.body(palette.txMuted, fontSize: AppTextStyles.size2xs))),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final _Palette palette;

  const _ErrorMessage({required this.message, required this.onRetry, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('average-ticket-error'),
      children: [
        Icon(Icons.cloud_off_rounded, color: palette.error, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: AppTextStyles.body(palette.txMuted, fontSize: AppTextStyles.size2xs))),
        TextButton(
          key: const Key('average-ticket-retry'),
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: palette.accentHi,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 28),
          ),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

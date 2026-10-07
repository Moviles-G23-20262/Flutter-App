import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../Domain/Entities/exchange_entity.dart';
import '../State Management/app_state.dart';

// ─── Order Placed Screen ──────────────────────────────────────────────────────

class ConfirmationScreen extends StatefulWidget {
  final AppState appState;

  /// The order that was just placed.
  final ExchangeEntity exchange;

  const ConfirmationScreen({super.key, required this.appState, required this.exchange});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _arrangeMeetup() async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    final error = await widget.appState.arrangeMeetup(widget.exchange);
    if (!mounted) return;
    setState(() => _openingChat = false);
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final brightness   = Theme.of(context).brightness;
    final bg           = brightness == Brightness.dark ? AppColors.darkBg            : AppColors.lightBg;
    final txPrimary    = brightness == Brightness.dark ? AppColors.darkTextPrimary    : AppColors.lightTextPrimary;
    final txMuted      = brightness == Brightness.dark ? AppColors.darkTextMuted      : AppColors.lightTextMuted;
    final txSecondary  = brightness == Brightness.dark ? AppColors.darkTextSecondary  : AppColors.lightTextSecondary;
    final accent       = brightness == Brightness.dark ? AppColors.darkAccent         : AppColors.lightAccent;
    final accentHi     = brightness == Brightness.dark ? AppColors.darkAccentHi       : AppColors.lightAccentHi;
    final accentLo     = brightness == Brightness.dark ? AppColors.darkAccentLo       : AppColors.lightAccentLo;
    final elevated     = brightness == Brightness.dark ? AppColors.darkElevated       : AppColors.lightElevated;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle   : AppColors.lightBorderSubtle;
    final surface      = brightness == Brightness.dark ? AppColors.darkSurface        : AppColors.lightSurface;
    final border       = brightness == Brightness.dark ? AppColors.darkBorder         : AppColors.lightBorder;

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Animated checkmark circle ──
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: accentLo),
                    boxShadow: AppDecorations.accentShadow(brightness),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 44),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Order Placed',
                  style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeXl)),
              const SizedBox(height: 8),
              Text('Your campus swap is confirmed.',
                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),

              // ── "What happens next" sticky note ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                decoration: BoxDecoration(
                  color: elevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: brightness == Brightness.dark
                          ? AppColors.darkShadowCard
                          : AppColors.lightShadowCard,
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pin decoration
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 28, height: 8,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: borderSubtle,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.inbox_rounded, color: txMuted, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('What happens next',
                                  style: AppTextStyles.body(txPrimary,
                                      fontSize: AppTextStyles.sizeXs,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              ..._kNextSteps.map((step) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(step.$1, color: accentHi, size: 15),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(step.$2,
                                          style: AppTextStyles.body(txSecondary,
                                              fontSize: AppTextStyles.sizeXs)),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Order number ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Text('Order #${widget.exchange.orderCode}',
                    style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.sizeXs)),
              ),
              const SizedBox(height: 28),

              // ── Buttons ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openingChat ? null : _arrangeMeetup,
                  icon: _openingChat
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Arrange the meetup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: buttonShape,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => widget.appState.openCompleteExchange(widget.exchange),
                  icon: Icon(Icons.check_circle_outline_rounded, size: 16, color: txSecondary),
                  label: Text('Already met? Complete exchange', style: TextStyle(color: txSecondary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: buttonShape,
                    side: BorderSide(color: borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => widget.appState.navigateTo(AppScreen.home),
                  icon: Icon(Icons.home_outlined, size: 16, color: txSecondary),
                  label: Text('Back to Home', style: TextStyle(color: txSecondary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: buttonShape,
                    side: BorderSide(color: borderSubtle),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _kNextSteps = [
  (Icons.check_circle_outline_rounded, 'Seller has been notified'),
  (Icons.chat_bubble_outline_rounded,  '1 · Agree on the meetup in chat'),
  (Icons.location_on_outlined,         '2 · Meet at a monitored campus point'),
  (Icons.star_rounded,                 '3 · Check the item and rate each other'),
];

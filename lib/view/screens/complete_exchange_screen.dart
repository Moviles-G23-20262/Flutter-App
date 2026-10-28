import '../widgets/cached_photo.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../model/entities/exchange_entity.dart';
import '../../model/entities/material_entity.dart';
import '../../view_model/app_view_model.dart';
import '../../view_model/complete_exchange_view_model.dart';
import '../widgets/formatters.dart';
import '../widgets/meetup_widgets.dart';

// ─── Complete Exchange Screen ─────────────────────────────────────────────────

/// The buyer checks the item at the meetup and confirms the exchange, then both rate each other.
/// Once the exchange is completed, either side comes back here just to rate.
/// Only draws [CompleteExchangeViewModel] and forwards taps.
class CompleteExchangeScreen extends StatefulWidget {
  final AppViewModel appState;

  /// Builds this screen's view-model; called once, and the screen disposes it.
  final CompleteExchangeViewModel Function() createViewModel;

  const CompleteExchangeScreen({super.key, required this.appState, required this.createViewModel});

  @override
  State<CompleteExchangeScreen> createState() => _CompleteExchangeScreenState();
}

class _CompleteExchangeScreenState extends State<CompleteExchangeScreen> {
  late final CompleteExchangeViewModel _vm = widget.createViewModel();
  final _reviewCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.init().then((_) {
      if (!mounted || !_vm.restoredDraft) return;
      if (_reviewCtrl.text.isEmpty) _reviewCtrl.text = _vm.review;
      _showMessage('Your unfinished rating was restored.');
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final completing = _vm.needsCheck;
    final other = _vm.otherFirstName;
    final outcome = await _vm.submit();
    if (!mounted) return;
    switch (outcome) {
      case ExchangeSubmitOutcome.sent:
        // The listing is sold now.
        if (completing) widget.appState.marketplace.load();
        _showMessage(completing ? 'Exchange completed. Thanks for rating $other!' : 'Thanks for rating $other!');
        widget.appState.closeCompleteExchange();
      case ExchangeSubmitOutcome.savedOffline:
        _showMessage("You're offline. It's saved on your phone and will be sent when you're back online.");
        widget.appState.closeCompleteExchange();
      case ExchangeSubmitOutcome.failed:
        if (_vm.errorMessage.isNotEmpty) _showMessage(_vm.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, widget.appState.account]),
      builder: (context, _) => _buildView(context),
    );
  }

  Widget _buildView(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg         = brightness == Brightness.dark ? AppColors.darkBg          : AppColors.lightBg;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;

    final exchange = _vm.exchange;
    final otherFirst = _vm.otherFirstName;
    final waitingForBuyer = _vm.waitingForBuyer;
    final cancelled = _vm.isCancelled;
    final saved = _vm.ratingQueued;
    final refused = widget.appState.account.refusedStepFor(exchange.id);

    final String buttonLabel;
    if (_vm.needsCheck && !_vm.allChecked) {
      buttonLabel = 'Check the item to continue';
    } else if (_vm.stars == 0) {
      buttonLabel = 'Rate $otherFirst to continue';
    } else {
      buttonLabel = _vm.needsCheck ? 'Complete exchange' : 'Submit rating';
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.appState.closeCompleteExchange,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: txSecondary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _vm.needsCheck || waitingForBuyer || cancelled ? 'Complete exchange' : 'Rate $otherFirst',
                    style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _ItemCard(exchange: exchange),
                  const SizedBox(height: 14),
                  if (refused != null) ...[
                    _InfoCard(
                      icon: Icons.error_outline_rounded,
                      text: 'What you saved offline was not accepted: ${refused.lastError ?? 'refused by the server'}. '
                          'Check the details and send it again.',
                      actionLabel: 'Discard',
                      onAction: () => widget.appState.account.discardPending(refused.id),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (cancelled)
                    _InfoCard(icon: Icons.block_rounded, text: 'This order was cancelled.')
                  else if (saved)
                    _InfoCard(
                      icon: Icons.cloud_upload_outlined,
                      text: _vm.completionQueued
                          ? "The exchange and your rating are saved on your phone. They will be sent when you're back online."
                          : "Your rating is saved on your phone. It will be sent when you're back online.",
                    )
                  else if (waitingForBuyer)
                    _InfoCard(
                      icon: Icons.hourglass_top_rounded,
                      text: '$otherFirst confirms the exchange after checking the item at your meetup. '
                          'You can rate each other once it is completed.',
                    )
                  else ...[
                    if (_vm.needsCheck) ...[
                      _checkSection(brightness),
                      const SizedBox(height: 14),
                    ],
                    _rateSection(brightness, step: _vm.needsCheck ? 2 : 1),
                  ],
                ],
              ),
            ),

            if (!cancelled && !waitingForBuyer && !saved)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _vm.canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _vm.isSubmitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(buttonLabel),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _checkSection(Brightness brightness) {
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final listed = _vm.exchange.material?.condition;
    const checks = CompleteExchangeViewModel.checklist;

    return _Section(
      step: 1,
      done: _vm.allChecked,
      title: 'Check the item before you pay',
      children: [
        for (var i = 0; i < checks.length; i++)
          InkWell(
            onTap: () => _vm.toggleCheck(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: _vm.checkedItems.contains(i),
                    onChanged: (_) => _vm.toggleCheck(i),
                  ),
                  Expanded(
                    child: Text(
                      i == 1 && listed != null ? 'Condition is ${listed.displayName} as listed' : checks[i],
                      style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text('Confirm the condition you received',
            style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final condition in MaterialConditionEnum.values)
              ChoiceChip(
                label: Text(condition.displayName),
                selected: _vm.receivedCondition == condition,
                onSelected: (_) => _vm.setReceivedCondition(condition),
              ),
          ],
        ),
      ],
    );
  }

  Widget _rateSection(Brightness brightness, {required int step}) {
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final starColor  = brightness == Brightness.dark ? AppColors.darkWarning     : AppColors.lightWarning;
    final stars = _vm.stars;

    return _Section(
      step: step,
      done: stars > 0,
      title: 'Rate ${_vm.otherFirstName}',
      children: [
        Row(
          children: [
            for (var s = 1; s <= 5; s++)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _vm.setStars(s),
                icon: Icon(s <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 32, color: s <= stars ? starColor : txMuted),
              ),
            const SizedBox(width: 6),
            Text(stars == 0 ? 'Tap to rate' : '$stars/5',
                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
          ],
        ),
        const SizedBox(height: 10),
        Text('What went well?',
            style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in CompleteExchangeViewModel.ratingTags)
              FilterChip(
                label: Text(tag),
                selected: _vm.selectedTags.contains(tag),
                onSelected: (_) => _vm.toggleTag(tag),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _reviewCtrl,
          maxLength: 500,
          minLines: 3,
          maxLines: 5,
          onChanged: _vm.setReview,
          style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs),
          decoration: const InputDecoration(hintText: 'Add a short review (optional)'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final ExchangeEntity exchange;

  const _ItemCard({required this.exchange});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final tagBg      = brightness == Brightness.dark ? AppColors.darkTagBg       : AppColors.lightTagBg;
    final material = exchange.material;
    final start = exchange.meetingStartsAt;
    final end = exchange.meetingEndsAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52, height: 52,
                  child: CachedPhoto(imageUrl: material?.primaryImageUrl ?? '', category: material?.category.name, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material?.title ?? 'Item', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                    Text(copPrice(exchange.price), style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeSm)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: txMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  exchange.meetingPoint != null && start != null && end != null
                      ? '${exchange.meetingPoint!.name} · ${dayLabel(start)} ${timeRange(start, end)}'
                      : 'Meetup not agreed yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs),
                ),
              ),
              Text(exchange.orderCode, style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final int step;
  final bool done;
  final String title;
  final List<Widget> children;

  const _Section({required this.step, required this.done, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: AppDecorations.card(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StepBadge(number: step, done: done),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeSm))),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InfoCard({required this.icon, required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(brightness),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: txSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs))),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

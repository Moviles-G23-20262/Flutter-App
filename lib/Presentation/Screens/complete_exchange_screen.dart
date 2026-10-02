import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../Domain/Entities/exchange_entity.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import '../State Management/app_state.dart';
import '../Widgets/formatters.dart';
import '../Widgets/meetup_widgets.dart';

// ─── Complete Exchange Screen ─────────────────────────────────────────────────

/// The buyer checks the item at the meetup and confirms the exchange, then both rate each other.
/// Once the exchange is completed, either side comes back here just to rate.
class CompleteExchangeScreen extends StatefulWidget {
  final AppState appState;
  final ExchangeEntity exchange;

  const CompleteExchangeScreen({super.key, required this.appState, required this.exchange});

  @override
  State<CompleteExchangeScreen> createState() => _CompleteExchangeScreenState();
}

class _CompleteExchangeScreenState extends State<CompleteExchangeScreen> {
  static const _checks = ['Matches the photos', 'Condition is as listed', 'Everything included', 'Works as expected'];
  static const _tags = ['Punctual', 'Item as described', 'Friendly', 'Good communication', 'Fair price'];

  late ExchangeEntity _exchange = widget.exchange;
  final _checked = <int>{};
  late MaterialConditionEnum? _received = widget.exchange.material?.condition;
  int _stars = 0;
  final _selectedTags = <String>{};
  final _reviewCtrl = TextEditingController();
  bool _submitting = false;

  String get _me => widget.appState.currentUser?.id ?? '';
  bool get _isBuyer => _exchange.buyerId == _me;

  /// The buyer still has to confirm what they received.
  bool get _needsCheck => _isBuyer && _exchange.isPending;
  bool get _allChecked => _checked.length == _checks.length;

  String get _otherFirst => _exchange.otherParty(_me)?.fullName.split(' ').first ?? 'them';

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting || _stars == 0 || (_needsCheck && !_allChecked)) return;
    setState(() => _submitting = true);
    final account = widget.appState.account;
    try {
      if (_needsCheck) {
        _exchange = await account.complete(_exchange, receivedCondition: _received);
        // The listing is sold now.
        widget.appState.marketplace.load();
      }
      await account.rate(NewRating(
        exchangeId: _exchange.id,
        ratedId: _isBuyer ? _exchange.sellerId : _exchange.buyerId,
        stars: _stars,
        tags: _selectedTags.toList(),
        review: _reviewCtrl.text,
      ));
      if (!mounted) return;
      _showMessage(_isBuyer ? 'Exchange completed. Thanks for rating $_otherFirst!' : 'Thanks for rating $_otherFirst!');
      widget.appState.closeCompleteExchange();
    } on DataException catch (e) {
      if (!mounted) return;
      // The exchange may have been completed even if the rating failed; the form follows suit.
      setState(() => _submitting = false);
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg         = brightness == Brightness.dark ? AppColors.darkBg          : AppColors.lightBg;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;

    final waitingForBuyer = !_isBuyer && _exchange.isPending;
    final cancelled = _exchange.status == ExchangeStatusEnum.CANCELLED;

    final String buttonLabel;
    if (_needsCheck && !_allChecked) {
      buttonLabel = 'Check the item to continue';
    } else if (_stars == 0) {
      buttonLabel = 'Rate $_otherFirst to continue';
    } else {
      buttonLabel = _needsCheck ? 'Complete exchange' : 'Submit rating';
    }
    final canSubmit = !_submitting && _stars > 0 && (!_needsCheck || _allChecked);

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
                    _needsCheck || waitingForBuyer || cancelled ? 'Complete exchange' : 'Rate $_otherFirst',
                    style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _ItemCard(exchange: _exchange),
                  const SizedBox(height: 14),
                  if (cancelled)
                    _InfoCard(icon: Icons.block_rounded, text: 'This order was cancelled.')
                  else if (waitingForBuyer)
                    _InfoCard(
                      icon: Icons.hourglass_top_rounded,
                      text: '$_otherFirst confirms the exchange after checking the item at your meetup. '
                          'You can rate each other once it is completed.',
                    )
                  else ...[
                    if (_needsCheck) ...[
                      _checkSection(brightness),
                      const SizedBox(height: 14),
                    ],
                    _rateSection(brightness, step: _needsCheck ? 2 : 1),
                  ],
                ],
              ),
            ),

            if (!cancelled && !waitingForBuyer)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _submitting
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
    final listed = _exchange.material?.condition;

    return _Section(
      step: 1,
      done: _allChecked,
      title: 'Check the item before you pay',
      children: [
        for (var i = 0; i < _checks.length; i++)
          InkWell(
            onTap: () => setState(() => _checked.contains(i) ? _checked.remove(i) : _checked.add(i)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: _checked.contains(i),
                    onChanged: (v) => setState(() => v == true ? _checked.add(i) : _checked.remove(i)),
                  ),
                  Expanded(
                    child: Text(
                      i == 1 && listed != null ? 'Condition is ${listed.displayName} as listed' : _checks[i],
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
                selected: _received == condition,
                onSelected: (_) => setState(() => _received = condition),
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

    return _Section(
      step: step,
      done: _stars > 0,
      title: 'Rate $_otherFirst',
      children: [
        Row(
          children: [
            for (var s = 1; s <= 5; s++)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _stars = s),
                icon: Icon(s <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 32, color: s <= _stars ? starColor : txMuted),
              ),
            const SizedBox(width: 6),
            Text(_stars == 0 ? 'Tap to rate' : '$_stars/5',
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
            for (final tag in _tags)
              FilterChip(
                label: Text(tag),
                selected: _selectedTags.contains(tag),
                onSelected: (on) => setState(() => on ? _selectedTags.add(tag) : _selectedTags.remove(tag)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _reviewCtrl,
          maxLength: 500,
          minLines: 3,
          maxLines: 5,
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
                  child: (material?.primaryImageUrl ?? '').isNotEmpty
                      ? Image.network(material!.primaryImageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: tagBg, child: Icon(Icons.inventory_2_outlined, color: accentHi)))
                      : Container(color: tagBg, child: Icon(Icons.inventory_2_outlined, color: accentHi)),
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

  const _InfoCard({required this.icon, required this.text});

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
        ],
      ),
    );
  }
}

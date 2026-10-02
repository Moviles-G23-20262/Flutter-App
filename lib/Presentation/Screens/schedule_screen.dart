import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../Domain/Entities/meetup_entities.dart';
import '../State Management/app_state.dart';
import '../Widgets/async_views.dart';
import '../Widgets/formatters.dart';

// ─── Class Schedule Screen ────────────────────────────────────────────────────

/// The user's weekly classes. The Campus Guardian uses them to suggest hours both
/// people in a chat are free.
class ScheduleScreen extends StatefulWidget {
  final AppState appState;

  const ScheduleScreen({super.key, required this.appState});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    final schedule = widget.appState.schedule;
    if (schedule.isFirstLoad && !schedule.isLoading) schedule.load();
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addClass({int? day}) async {
    final block = await showModalBottomSheet<NewScheduleBlock>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddClassSheet(initialDay: day ?? DateTime.now().weekday),
    );
    if (block == null) return;
    final error = await widget.appState.schedule.add(block);
    if (error != null) _showMessage(error);
  }

  Future<void> _remove(ScheduleBlockEntity block) async {
    final error = await widget.appState.schedule.remove(block.id);
    if (error != null) _showMessage(error);
  }

  @override
  Widget build(BuildContext context) {
    final schedule   = widget.appState.schedule;
    final brightness = Theme.of(context).brightness;
    final bg         = brightness == Brightness.dark ? AppColors.darkBg          : AppColors.lightBg;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final tagBg      = brightness == Brightness.dark ? AppColors.darkTagBg       : AppColors.lightTagBg;

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClass,
        backgroundColor: brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add class'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: schedule,
          builder: (context, _) => Column(
            children: [
              Container(
                color: surface,
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: txPrimary),
                      onPressed: widget.appState.closeSchedule,
                    ),
                    const SizedBox(width: 6),
                    Text('My class schedule', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                  ],
                ),
              ),
              Expanded(
                child: schedule.isFirstLoad && schedule.isLoading
                    ? const LoadingView()
                    : schedule.error != null && schedule.blocks.isEmpty
                        ? ErrorView(message: schedule.error!, onRetry: schedule.load)
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(14)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.auto_awesome_rounded, color: accentHi, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Add the classes you take every week. When you plan a meetup, the Campus Guardian '
                                        'suggests hours when you and the other student are both free. '
                                        'Only the free hours are shared, never your classes.',
                                        style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              for (var day = 1; day <= 6; day++) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(weekdayName(day),
                                          style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700)),
                                    ),
                                    IconButton(
                                      tooltip: 'Add a class on ${weekdayName(day)}',
                                      icon: Icon(Icons.add_circle_outline_rounded, color: accentHi),
                                      onPressed: () => _addClass(day: day),
                                    ),
                                  ],
                                ),
                                if (schedule.blocksOn(day).isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text('No classes', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                                  ),
                                for (final block in schedule.blocksOn(day))
                                  _ClassTile(block: block, onDelete: () => _remove(block)),
                                const SizedBox(height: 6),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  final ScheduleBlockEntity block;
  final VoidCallback onDelete;

  const _ClassTile({required this.block, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent      : AppColors.lightAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: AppDecorations.card(brightness),
      child: Row(
        children: [
          Container(
            width: 4, height: 28,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Text('${minuteOfDay(block.startMinute)} - ${minuteOfDay(block.endMinute)}',
              style: AppTextStyles.mono(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(block.label ?? 'Class', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: Icon(Icons.delete_outline_rounded, color: txSecondary, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddClassSheet extends StatefulWidget {
  final int initialDay;

  const _AddClassSheet({required this.initialDay});

  @override
  State<_AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<_AddClassSheet> {
  late int _day = widget.initialDay.clamp(1, 6);
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 8, minute: 30);
  final _labelCtrl = TextEditingController();

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        // Keep the class at least as long as it was, so "end" doesn't land before "start".
        if (_minutes(_end) <= _minutes(picked)) {
          final end = _minutes(picked) + 90;
          _end = TimeOfDay(hour: (end ~/ 60).clamp(0, 23), minute: end % 60);
        }
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final valid = _minutes(_end) > _minutes(_start);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a class', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 6; d++)
                ChoiceChip(
                  label: Text(weekdayName(d).substring(0, 3)),
                  selected: _day == d,
                  onSelected: (_) => setState(() => _day = d),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(true),
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text('From ${minuteOfDay(_minutes(_start))}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(false),
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text('To ${minuteOfDay(_minutes(_end))}'),
                ),
              ),
            ],
          ),
          if (!valid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('The class has to end after it starts.',
                  style: AppTextStyles.body(Theme.of(context).colorScheme.error, fontSize: AppTextStyles.sizeXs)),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _labelCtrl,
            maxLength: 60,
            textCapitalization: TextCapitalization.characters,
            style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs),
            decoration: InputDecoration(
              hintText: 'Course, e.g. MATH-201 (optional)',
              hintStyle: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: valid
                  ? () => Navigator.pop(
                        context,
                        NewScheduleBlock(
                          dayOfWeek: _day,
                          startMinute: _minutes(_start),
                          endMinute: _minutes(_end),
                          label: _labelCtrl.text,
                        ),
                      )
                  : null,
              child: const Text('Add to schedule'),
            ),
          ),
        ],
      ),
    );
  }
}

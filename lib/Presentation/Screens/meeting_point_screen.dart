import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../Domain/Entities/chat_room_entity.dart';
import '../../Domain/Entities/meetup_entities.dart';
import '../State Management/app_state.dart';
import '../State Management/meeting_planner_state.dart';
import '../Widgets/async_views.dart';
import '../Widgets/formatters.dart';
import '../Widgets/meetup_widgets.dart';

// ─── Meeting Point Screen ─────────────────────────────────────────────────────

/// Pick a campus safe zone and an hour both people are free, then propose it in the chat.
class MeetingPointScreen extends StatefulWidget {
  final AppState appState;
  final ChatRoomEntity room;

  const MeetingPointScreen({super.key, required this.appState, required this.room});

  @override
  State<MeetingPointScreen> createState() => _MeetingPointScreenState();
}

class _MeetingPointScreenState extends State<MeetingPointScreen> {
  late final MeetingPlannerState _planner = widget.appState.createMeetingPlanner(widget.room);
  final _map = MapController();
  bool _mapReady = false;
  String? _focusedZoneId;

  String get _otherFirstName {
    final other = widget.room.otherParty(widget.appState.currentUser?.id ?? '');
    return other?.fullName.split(' ').first ?? 'the other person';
  }

  @override
  void initState() {
    super.initState();
    _planner.addListener(_followSelectedZone);
    _planner.load();
  }

  @override
  void dispose() {
    _planner.removeListener(_followSelectedZone);
    _planner.dispose();
    _map.dispose();
    super.dispose();
  }

  /// Moves the map to the chosen zone whenever the choice changes.
  void _followSelectedZone() {
    final zone = _planner.selectedZone?.zone;
    if (zone == null || zone.id == _focusedZoneId || !_mapReady) return;
    _focusedZoneId = zone.id;
    _map.move(_latLng(zone.location), _map.camera.zoom);
  }

  Future<void> _propose() async {
    final error = await _planner.propose();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Meeting proposed to $_otherFirstName.')));
    widget.appState.closeMeetingPlanner();
  }

  Future<void> _pickOtherTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
    if (time == null) return;
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    _planner.selectSlot(FreeSlot(startsAt: start, endsAt: start.add(const Duration(hours: 1)), sharedBreak: false));
  }

  void _showOtherZones() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: _planner,
        builder: (context, _) => _OtherZonesSheet(
          planner: _planner,
          onPick: (zoneId) {
            _planner.selectZone(zoneId);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _planner,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg         = brightness == Brightness.dark ? AppColors.darkBg          : AppColors.lightBg;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final planner = _planner;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              color: surface,
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: txPrimary),
                    onPressed: widget.appState.closeMeetingPlanner,
                  ),
                  const SizedBox(width: 6),
                  Text('Meeting point', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                ],
              ),
            ),

            Expanded(
              child: planner.isLoading && planner.zones.isEmpty
                  ? const LoadingView()
                  : planner.error != null && planner.zones.isEmpty
                      ? ErrorView(message: planner.error!, onRetry: planner.load)
                      : planner.zones.isEmpty
                          ? const EmptyView(
                              icon: Icons.location_off_outlined,
                              title: 'No safe zones yet',
                              subtitle: 'Campus meeting points will show up here once they are added.',
                            )
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _buildMap(brightness),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _GuardianCard(planner: planner, otherFirstName: _otherFirstName),
                                      if (!(planner.suggestions?.callerHasSchedule ?? true)) ...[
                                        const SizedBox(height: 10),
                                        _AddScheduleHint(
                                          onTap: () => widget.appState.openSchedule(returnTo: AppScreen.meetingPlanner),
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      if (planner.selectedZone != null)
                                        _SelectedZoneCard(
                                          ranked: planner.selectedZone!,
                                          locating: planner.isLocating,
                                        ),
                                      const SizedBox(height: 22),
                                      Text('Shared free hour',
                                          style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 10),
                                      _SlotGrid(
                                        slots: planner.slots,
                                        selected: planner.selectedSlot,
                                        onSelect: planner.selectSlot,
                                        onPickOther: _pickOtherTime,
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.shield_outlined, size: 16, color: txMuted),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Only public campus zones are suggested, monitored ones first. '
                                              'Payment always happens in person.',
                                              style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
            ),

            // ── Bottom actions ──
            Container(
              decoration: BoxDecoration(color: elevated, border: Border(top: BorderSide(color: borderSubtle))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: planner.zones.isEmpty ? null : _showOtherZones,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                        backgroundColor: Colors.transparent,
                      ),
                      child: const Text('Change'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: planner.canPropose ? _propose : null,
                      icon: planner.isSending
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(Brightness brightness) {
    final zones = _planner.zones;
    final selected = _planner.selectedZone?.zone;
    final here = _planner.location;
    final center = selected?.location ?? _centerOf(zones.map((r) => r.zone.location).toList());
    final accent = brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent;
    final surface = brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface;
    final txPrimary = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _latLng(center),
              initialZoom: 17,
              minZoom: 14,
              maxZoom: 19,
              onMapReady: () {
                _mapReady = true;
                _focusedZoneId = selected?.id;
              },
            ),
            children: [
              TileLayer(
                // OpenStreetMap: free, no key. Their usage policy asks every app to identify itself.
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_front_end',
                tileBuilder: brightness == Brightness.dark ? darkModeTileBuilder : null,
              ),
              if (selected != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _latLng(selected.location),
                      radius: 40,
                      useRadiusInMeter: true,
                      color: accent.withValues(alpha: 0.18),
                      borderColor: accent.withValues(alpha: 0.5),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final r in zones)
                    if (r.zone.id != selected?.id)
                      Marker(
                        point: _latLng(r.zone.location),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _planner.selectZone(r.zone.id),
                          child: _ZoneMarker(zone: r.zone),
                        ),
                      ),
                  if (here != null)
                    Marker(
                      point: _latLng(here),
                      width: 56,
                      height: 64,
                      alignment: Alignment.topCenter,
                      child: const _YouMarker(),
                    ),
                  if (selected != null)
                    Marker(
                      point: _latLng(selected.location),
                      width: 220,
                      height: 84,
                      alignment: Alignment.topCenter,
                      // The label is wide; let taps reach the zones underneath it.
                      child: IgnorePointer(child: _SelectedMarker(name: selected.name)),
                    ),
                ],
              ),
              const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_outlined, size: 16, color: successColor(brightness)),
                  const SizedBox(width: 6),
                  Text('Monitored zones', style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static LatLng _latLng(GeoPoint p) => LatLng(p.lat, p.lng);

  static GeoPoint _centerOf(List<GeoPoint> points) {
    if (points.isEmpty) return const GeoPoint(4.6015, -74.0655);
    final lat = points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.lng).reduce((a, b) => a + b) / points.length;
    return GeoPoint(lat, lng);
  }
}

// ─── Map markers ──────────────────────────────────────────────────────────────

/// A safe zone on the map: its kind of place, ringed green when monitored.
class _ZoneMarker extends StatelessWidget {
  final MeetingPointEntity zone;

  const _ZoneMarker({required this.zone});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface;
    final ring = zone.isMonitored ? successColor(brightness) : warningColor(brightness);
    return Container(
      decoration: BoxDecoration(
        color: surface,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Icon(zoneIcon(zone.zoneType), size: 20, color: ring),
    );
  }
}

/// The chosen zone: a labelled pin.
class _SelectedMarker extends StatelessWidget {
  final String name;

  const _SelectedMarker({required this.name});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.primary900, borderRadius: BorderRadius.circular(8)),
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(Colors.white, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
        ),
        Icon(Icons.location_on, size: 40, color: accent),
      ],
    );
  }
}

/// Where the current user is.
class _YouMarker extends StatelessWidget {
  const _YouMarker();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent;
    final surface = brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface;
    final txPrimary = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(6)),
          child: Text('You', style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GuardianCard extends StatelessWidget {
  final MeetingPlannerState planner;
  final String otherFirstName;

  const _GuardianCard({required this.planner, required this.otherFirstName});

  String _message() {
    final suggestions = planner.suggestions;
    final slot = planner.selectedSlot;
    final zone = planner.selectedZone;
    if (suggestions == null) return 'Looking for a time that works for you both…';

    final parts = <String>[];
    if (slot == null) {
      parts.add("We couldn't find an hour you're both free this week. Pick another time below.");
    } else {
      final when = '${dayLabel(slot.startsAt)}, ${timeRange(slot.startsAt, slot.endsAt).replaceAll(' - ', ' – ')}';
      parts.add(suggestions.slots.contains(slot)
          ? 'You and $otherFirstName are both free $when.'
          : 'You picked $when.');
      if (slot.sharedBreak) parts.add("It's a break between classes for both of you.");
    }
    if (zone != null) {
      if (zone.walkMinutes != null) {
        parts.add(zone.zone.isMonitored
            ? '${zone.zone.name} is the closest monitored spot, ${zone.walkMinutes} min from you.'
            : '${zone.zone.name} is ${zone.walkMinutes} min from you.');
      } else if (zone.zone.isMonitored) {
        parts.add('${zone.zone.name} is monitored by campus security.');
      }
    }
    if (!suggestions.otherHasSchedule) {
      parts.add("$otherFirstName hasn't added a class schedule yet, so only yours was checked.");
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tagBg      = brightness == Brightness.dark ? AppColors.darkTagBg       : AppColors.lightTagBg;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent      : AppColors.lightAccent;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Campus Guardian suggestion',
                    style: AppTextStyles.body(accentHi, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_message(), style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddScheduleHint extends StatelessWidget {
  final VoidCallback onTap;

  const _AddScheduleHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final border     = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 18, color: txSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Add your class schedule so we can find hours you are both free.',
                  style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
            ),
            Icon(Icons.chevron_right_rounded, color: txSecondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SelectedZoneCard extends StatelessWidget {
  final RankedZone ranked;
  final bool locating;

  const _SelectedZoneCard({required this.ranked, required this.locating});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final tagBg      = brightness == Brightness.dark ? AppColors.darkTagBg       : AppColors.lightTagBg;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final zone = ranked.zone;

    final walkText = ranked.walkMinutes != null
        ? '${ranked.walkMinutes} min'
        : locating
            ? '…'
            : '-- min';
    final walkCaption = ranked.walkMinutes != null || locating ? 'You' : 'Turn on location to see your walk';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderSubtle, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(zoneIcon(zone.zoneType), color: accentHi, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zone.name, style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                    if (zone.detail != null)
                      Text(zone.detail!, style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
                  ],
                ),
              ),
              if (ranked.bestMatch) ...[
                const SizedBox(width: 8),
                StatusPill(label: 'Best match', color: successColor(brightness)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: elevated, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.directions_walk_rounded, color: accentHi, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(walkText, style: AppTextStyles.mono(txPrimary, fontSize: AppTextStyles.sizeMd, fontWeight: FontWeight.w600)),
                    Text(walkCaption, style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SafeZoneLabel(monitored: zone.isMonitored),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SlotGrid extends StatelessWidget {
  final List<FreeSlot> slots;
  final FreeSlot? selected;
  final ValueChanged<FreeSlot> onSelect;
  final VoidCallback onPickOther;

  const _SlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelect,
    required this.onPickOther,
  });

  @override
  Widget build(BuildContext context) {
    final custom = selected != null && !slots.contains(selected) ? selected : null;
    final tiles = <Widget>[
      for (final slot in slots)
        _SlotTile(
          time: timeRange(slot.startsAt, slot.endsAt),
          caption: '${dayLabel(slot.startsAt)}${slot.sharedBreak ? ' · shared break' : ''}',
          selected: slot == selected,
          onTap: () => onSelect(slot),
        ),
      _SlotTile(
        time: custom == null ? 'Other time' : timeRange(custom.startsAt, custom.endsAt),
        caption: custom == null ? 'Pick a date and hour' : '${dayLabel(custom.startsAt)} · your pick',
        selected: custom != null,
        icon: custom == null ? Icons.edit_calendar_outlined : null,
        onTap: onPickOther,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [for (final tile in tiles) SizedBox(width: width, child: tile)],
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  final String time;
  final String caption;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _SlotTile({
    required this.time,
    required this.caption,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent      : AppColors.lightAccent;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final fg = selected ? Colors.white : txPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: selected ? accent : surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? accent : borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon ?? Icons.schedule_rounded, size: 16, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(time, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mono(fg, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(selected ? Colors.white : txSecondary, fontSize: AppTextStyles.sizeXs)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _OtherZonesSheet extends StatelessWidget {
  final MeetingPlannerState planner;
  final ValueChanged<String> onPick;

  const _OtherZonesSheet({required this.planner, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent      : AppColors.lightAccent;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final tagBg      = brightness == Brightness.dark ? AppColors.darkTagBg       : AppColors.lightTagBg;
    final selectedId = planner.selectedZone?.zone.id;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Other safe zones nearby', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
              const SizedBox(height: 4),
              Text(
                planner.location != null
                    ? 'Ranked by your walking time.'
                    : 'Monitored zones first. Turn on location to rank them by your walk.',
                style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
              ),
              const SizedBox(height: 14),
              for (final r in planner.zones)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => onPick(r.zone.id),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: r.zone.id == selectedId ? tagBg : elevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: r.zone.id == selectedId ? accent : Colors.transparent, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(zoneIcon(r.zone.zoneType), color: accentHi, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(r.zone.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700)),
                                    ),
                                    if (r.bestMatch) ...[
                                      const SizedBox(width: 6),
                                      Text('Best match',
                                          style: AppTextStyles.body(successColor(brightness), fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ),
                                Text(
                                  r.walkMinutes != null ? 'You ${r.walkMinutes} min' : r.zone.zoneType.displayName,
                                  style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            r.zone.isMonitored ? Icons.videocam_outlined : Icons.shield_outlined,
                            color: r.zone.isMonitored ? successColor(brightness) : warningColor(brightness),
                            size: 22,
                          ),
                          if (r.zone.id == selectedId) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.check_rounded, color: accent, size: 22),
                          ],
                        ],
                      ),
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

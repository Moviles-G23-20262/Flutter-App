import 'package:flutter/foundation.dart';
import '../model/entities/meeting_point_density.dart';
import '../model/entities/meetup_entities.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/rules/meeting_time_rules.dart';
import '../model/use_cases/meetup_use_cases.dart';

/// The "Meeting point" screen for one chat: safe zones ranked by the user's walk,
/// shared free hours from both class schedules, and the zone + hour picked.
class MeetingPlannerViewModel extends ChangeNotifier {
  final MeetupUseCases useCases;
  final String chatRoomId;

  /// The signed-in user, who owns a proposal saved offline.
  final String? userId;
  final DateTime Function() _now;

  MeetingPlannerViewModel({
    required this.useCases,
    required this.chatRoomId,
    this.userId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  List<MeetingPointEntity> _zones = const [];
  List<RankedZone> _ranked = const [];
  MeetingSuggestions? _suggestions;
  GeoPoint? _location;
  MeetingPointDensity _density = MeetingPointDensity.empty;
  bool _locating = true;
  bool _loading = true;
  String? _error;
  String? _selectedZoneId;
  bool _zonePickedByUser = false;
  FreeSlot? _selectedSlot;
  bool _sending = false;
  bool _savedOffline = false;
  bool _disposed = false;

  /// Bumped by every [_rank], so a ranking that finishes after a newer one started is dropped.
  int _rankGeneration = 0;
  Future<void> _ranking = Future.value();

  /// MO8: what the last ranking was computed from. The ranking depends only on the zones, the
  /// location, the density table and the hour of the meeting, so the same inputs skip the isolate.
  ({List<MeetingPointEntity> zones, GeoPoint? location, MeetingPointDensity density, int hour})? _rankedFrom;
  int _rankingsStarted = 0;
  int _rankingsSkipped = 0;

  /// MO8 measurements: background rankings started, and the ones avoided because nothing changed.
  int get rankingsStarted => _rankingsStarted;
  int get rankingsSkipped => _rankingsSkipped;

  /// Best match first; see [RankMeetingPointsUseCase].
  List<RankedZone> get zones => _ranked;

  /// Completes once no ranking is running any more (they run in a background isolate, and a new
  /// one can start while an older one is still being computed).
  Future<void> get rankingDone async {
    Future<void> current;
    do {
      current = _ranking;
      await current;
    } while (!identical(current, _ranking));
  }
  MeetingSuggestions? get suggestions => _suggestions;
  /// Upcoming shared free slots only — times at or before now cannot be chosen.
  List<FreeSlot> get slots {
    final now = _now();
    return (_suggestions?.slots ?? const [])
        .where((s) => MeetingTimeRules.isValidStart(s.startsAt, now))
        .toList(growable: false);
  }

  DateTime get currentTime => _now();

  bool isSlotInPast(FreeSlot slot) => !MeetingTimeRules.isValidStart(slot.startsAt, _now());
  GeoPoint? get location => _location;
  bool get isLocating => _locating;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isSending => _sending;

  /// The last [propose] is saved on the phone and waiting to be sent.
  bool get savedOffline => _savedOffline;
  FreeSlot? get selectedSlot => _selectedSlot;

  RankedZone? get selectedZone =>
      _ranked.where((r) => r.zone.id == _selectedZoneId).firstOrNull ?? _ranked.firstOrNull;

  bool get canPropose =>
      selectedZone != null &&
      _selectedSlot != null &&
      MeetingTimeRules.isValidStart(_selectedSlot!.startsAt, _now()) &&
      !_sending;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    // The location prompt can take a while; zones and hours show up without waiting for it.
    _locate();
    _loadDensity();
    try {
      final results = await Future.wait([
        useCases.getMeetingPoints.execute(),
        useCases.getSuggestions.execute(chatRoomId),
      ]);
      _zones = results[0] as List<MeetingPointEntity>;
      _suggestions = results[1] as MeetingSuggestions;
      final now = _now();
      final suggested = _suggestions?.suggested;
      final validSuggested =
          suggested != null && MeetingTimeRules.isValidStart(suggested.startsAt, now) ? suggested : null;
      _selectedSlot ??= validSuggested ?? slots.firstOrNull;
      _rank();
      await rankingDone;
    } on DataException catch (e) {
      _error = e.message;
    }
    _loading = false;
    _notify();
  }

  void selectZone(String zoneId) {
    _selectedZoneId = zoneId;
    _zonePickedByUser = true;
    _notify();
  }

  /// Picks [slot] if it starts strictly in the future; past slots are rejected immediately.
  bool selectSlot(FreeSlot slot) {
    if (!MeetingTimeRules.isValidStart(slot.startsAt, _now())) return false;
    _selectedSlot = slot;
    _rank(); // the hour changed, so which zone suits best can change too
    _notify();
    return true;
  }

  /// Sends the picked zone and hour to the chat. Returns an error message, or `null` on success.
  /// Without a connection the proposal is saved and sent later ([savedOffline]).
  Future<String?> propose() async {
    if (_sending) return 'Your proposal is already being sent.';
    final zone = selectedZone;
    final slot = _selectedSlot;
    if (zone == null || slot == null) return 'Pick a place and a time first.';
    final now = _now();
    if (!MeetingTimeRules.isValidStart(slot.startsAt, now)) {
      return 'That time already passed. Pick another one.';
    }
    _sending = true;
    _savedOffline = false;
    _notify();
    try {
      final queue = useCases.queuePropose;
      final owner = userId;
      if (queue == null || owner == null) {
        await useCases.propose.execute(chatRoomId: chatRoomId, zone: zone.zone, slot: slot, now: now);
      } else {
        final proposal = await queue.execute(
          ownerId: owner,
          chatRoomId: chatRoomId,
          zone: zone.zone,
          slot: slot,
          now: now,
        );
        _savedOffline = await queue.tryDelivery(proposal);
      }
      return null;
    } on DataException catch (e) {
      return e.message;
    } finally {
      _sending = false;
      _notify();
    }
  }

  Future<void> _locate() async {
    _locating = true;
    _location = await useCases.currentLocation.execute();
    _locating = false;
    _notify();
    await _rank();
  }

  /// Past activity per zone and hour. It arrives whenever the analytics service answers.
  Future<void> _loadDensity() async {
    _density = await useCases.getDensity.execute();
    await _rank();
  }

  /// Re-scores the zones in a background isolate ([RecommendMeetingPointUseCase.executeInBackground])
  /// and applies the result when it arrives. Several triggers can overlap (hour picked, GPS fix,
  /// density answer); only the newest ranking is applied.
  Future<void> _rank() {
    final inputs = (
      zones: _zones,
      location: _location,
      density: _density,
      hour: (_selectedSlot?.startsAt ?? _now()).hour,
    );
    final last = _rankedFrom;
    if (last != null &&
        identical(last.zones, inputs.zones) &&
        last.location == inputs.location &&
        identical(last.density, inputs.density) &&
        last.hour == inputs.hour) {
      // Same hour tapped again, a GPS fix at the same spot, another slot in the same hour...
      _rankingsSkipped++;
      return _ranking;
    }
    _rankedFrom = inputs;
    _rankingsStarted++;
    final generation = ++_rankGeneration;
    return _ranking = useCases.recommend
        .executeInBackground(zones: _zones, from: _location, meetingAt: _selectedSlot?.startsAt, density: _density)
        .then((recommendation) {
      if (_disposed || generation != _rankGeneration) return;
      _ranked = recommendation.ranked;
      if (!_zonePickedByUser) {
        _selectedZoneId = _ranked.where((r) => r.bestMatch).firstOrNull?.zone.id;
      }
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

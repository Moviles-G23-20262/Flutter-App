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

  /// Best match first; see [RankMeetingPointsUseCase].
  List<RankedZone> get zones => _ranked;
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

  /// The last [propose] had no connection, so the proposal waits on the phone to be sent.
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
      try {
        await useCases.propose.execute(chatRoomId: chatRoomId, zone: zone.zone, slot: slot, now: now);
      } on NoConnectionException {
        final queue = useCases.queuePropose;
        final owner = userId;
        if (queue == null || owner == null) rethrow;
        await queue.execute(ownerId: owner, chatRoomId: chatRoomId, zone: zone.zone, slot: slot);
        _savedOffline = true;
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
    _rank();
    _notify();
  }

  /// Past activity per zone and hour. It arrives whenever the analytics service answers.
  Future<void> _loadDensity() async {
    _density = await useCases.getDensity.execute();
    _rank();
    _notify();
  }

  void _rank() {
    _ranked = useCases.recommend
        .execute(zones: _zones, from: _location, meetingAt: _selectedSlot?.startsAt, density: _density)
        .ranked;
    if (!_zonePickedByUser) {
      _selectedZoneId = _ranked.where((r) => r.bestMatch).firstOrNull?.zone.id;
    }
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

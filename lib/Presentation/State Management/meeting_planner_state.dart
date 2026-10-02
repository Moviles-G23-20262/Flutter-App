import 'package:flutter/foundation.dart';
import '../../Domain/Entities/meetup_entities.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import '../../Domain/use_cases/meetup_use_cases.dart';

/// The "Meeting point" screen for one chat: safe zones ranked by the user's walk,
/// shared free hours from both class schedules, and the zone + hour picked.
class MeetingPlannerState extends ChangeNotifier {
  final MeetupUseCases useCases;
  final String chatRoomId;

  MeetingPlannerState({required this.useCases, required this.chatRoomId});

  List<MeetingPointEntity> _zones = const [];
  List<RankedZone> _ranked = const [];
  MeetingSuggestions? _suggestions;
  GeoPoint? _location;
  bool _locating = true;
  bool _loading = true;
  String? _error;
  String? _selectedZoneId;
  bool _zonePickedByUser = false;
  FreeSlot? _selectedSlot;
  bool _sending = false;
  bool _disposed = false;

  /// Closest first; see [RankSafeZonesUseCase].
  List<RankedZone> get zones => _ranked;
  MeetingSuggestions? get suggestions => _suggestions;
  List<FreeSlot> get slots => _suggestions?.slots ?? const [];
  GeoPoint? get location => _location;
  bool get isLocating => _locating;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isSending => _sending;
  FreeSlot? get selectedSlot => _selectedSlot;

  RankedZone? get selectedZone =>
      _ranked.where((r) => r.zone.id == _selectedZoneId).firstOrNull ?? _ranked.firstOrNull;

  bool get canPropose => selectedZone != null && _selectedSlot != null && !_sending;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    // The location prompt can take a while; zones and hours show up without waiting for it.
    _locate();
    try {
      final results = await Future.wait([
        useCases.getMeetingPoints.execute(),
        useCases.getSuggestions.execute(chatRoomId),
      ]);
      _zones = results[0] as List<MeetingPointEntity>;
      _suggestions = results[1] as MeetingSuggestions;
      _selectedSlot ??= _suggestions?.suggested;
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

  void selectSlot(FreeSlot slot) {
    _selectedSlot = slot;
    _notify();
  }

  /// Sends the picked zone and hour to the chat. Returns an error message, or `null` on success.
  Future<String?> propose() async {
    final zone = selectedZone;
    final slot = _selectedSlot;
    if (zone == null || slot == null) return 'Pick a place and a time first.';
    _sending = true;
    _notify();
    try {
      await useCases.propose.execute(chatRoomId: chatRoomId, zone: zone.zone, slot: slot);
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

  void _rank() {
    _ranked = useCases.rankZones.execute(_zones, _location);
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

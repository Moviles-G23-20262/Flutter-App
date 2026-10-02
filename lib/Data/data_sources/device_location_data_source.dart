import 'package:geolocator/geolocator.dart';

import '../../Domain/Entities/meetup_entities.dart';

/// The phone's GPS, through the geolocator plugin.
class DeviceLocationDataSource {
  static const _timeout = Duration(seconds: 8);

  /// Asks for permission the first time. `null` when location is off, refused or too slow.
  Future<GeoPoint?> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _timeout),
      );
      return GeoPoint(position.latitude, position.longitude);
    } on Exception {
      // Indoors the first fix can time out; a recent one is good enough for walking times.
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : GeoPoint(last.latitude, last.longitude);
    }
  }
}

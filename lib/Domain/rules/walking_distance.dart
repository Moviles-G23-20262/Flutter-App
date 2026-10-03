import 'dart:math' as math;

import '../Entities/meetup_entities.dart';

/// Straight-line walking estimates between two campus points.
class WalkingDistance {
  /// Typical walking pace on campus, in meters per minute.
  static const double metersPerMinute = 80;

  /// Straight-line distance at walking pace, rounded up; at least one minute.
  static int minutes(GeoPoint from, GeoPoint to) =>
      math.max(1, (meters(from, to) / metersPerMinute).ceil());

  /// Great-circle (haversine) distance.
  static double meters(GeoPoint a, GeoPoint b) {
    const earthRadius = 6371000.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }
}

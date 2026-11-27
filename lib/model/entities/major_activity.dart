import 'package:flutter/foundation.dart';

/// Aggregated marketplace supply, demand, and conversion metrics for one university
/// major or faculty in BQ 18 (`GET /analytics/major-activity/`).
@immutable
class AcademicGroupActivity {
  final String name;
  final String? faculty;
  final int users;
  final int activeSellers;
  final int listings;
  final int buyerInquiries;
  final int completedExchanges;
  final double conversionRate;

  const AcademicGroupActivity({
    required this.name,
    this.faculty,
    required this.users,
    required this.activeSellers,
    required this.listings,
    required this.buyerInquiries,
    required this.completedExchanges,
    required this.conversionRate,
  });

  /// Listing-to-sale conversion expressed as an integer percentage (`0`–`100`).
  int get conversionRatePercent => (conversionRate * 100).round();
}

/// BQ 18 insight: which university majors and faculties generate the most listings,
/// buyer inquiries, and completed exchanges on CampusSwap?
@immutable
class MajorActivityInsight {
  final int usersTotal;
  final int listingsTotal;
  final int inquiriesTotal;
  final int completedExchangesTotal;
  final int majorsActive;
  final int facultiesActive;
  final List<AcademicGroupActivity> byMajor;
  final List<AcademicGroupActivity> byFaculty;

  /// Non-null when this insight was loaded from SQLite `ResponseCache` while offline.
  final DateTime? savedAt;

  const MajorActivityInsight({
    required this.usersTotal,
    required this.listingsTotal,
    required this.inquiriesTotal,
    required this.completedExchangesTotal,
    required this.majorsActive,
    required this.facultiesActive,
    required this.byMajor,
    required this.byFaculty,
    this.savedAt,
  });

  bool get isEmpty => listingsTotal == 0 && inquiriesTotal == 0 && byMajor.isEmpty;

  MajorActivityInsight copyWith({DateTime? savedAt}) => MajorActivityInsight(
        usersTotal: usersTotal,
        listingsTotal: listingsTotal,
        inquiriesTotal: inquiriesTotal,
        completedExchangesTotal: completedExchangesTotal,
        majorsActive: majorsActive,
        facultiesActive: facultiesActive,
        byMajor: byMajor,
        byFaculty: byFaculty,
        savedAt: savedAt ?? this.savedAt,
      );

  static String _normalize(String? value) =>
      (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Returns the activity row matching [major] (case-insensitive, trimmed), or `null`.
  AcademicGroupActivity? activityForMajor(String? major) {
    final target = _normalize(major);
    if (target.isEmpty) return null;
    for (final row in byMajor) {
      if (_normalize(row.name) == target) return row;
    }
    return null;
  }

  /// 1-based rank of [major] in [byMajor], or `null` if not present.
  int? rankOfMajor(String? major) {
    final target = _normalize(major);
    if (target.isEmpty) return null;
    for (var i = 0; i < byMajor.length; i++) {
      if (_normalize(byMajor[i].name) == target) return i + 1;
    }
    return null;
  }

  /// Returns the activity row matching [faculty] (case-insensitive, trimmed), or `null`.
  AcademicGroupActivity? activityForFaculty(String? faculty) {
    final target = _normalize(faculty);
    if (target.isEmpty) return null;
    for (final row in byFaculty) {
      if (_normalize(row.name) == target) return row;
    }
    return null;
  }

  /// Highest-activity major across campus, if any.
  AcademicGroupActivity? get topMajor => byMajor.isEmpty ? null : byMajor.first;
}

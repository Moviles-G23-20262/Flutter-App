import '../entities/major_activity.dart';

/// Parses and serializes `GET /analytics/major-activity/` (BQ 18).
abstract final class MajorActivityModel {
  static MajorActivityInsight fromJson(Object? json) {
    if (json is! Map) {
      return const MajorActivityInsight(
        usersTotal: 0,
        listingsTotal: 0,
        inquiriesTotal: 0,
        completedExchangesTotal: 0,
        majorsActive: 0,
        facultiesActive: 0,
        byMajor: [],
        byFaculty: [],
      );
    }
    return MajorActivityInsight(
      usersTotal: (json['users_total'] as num?)?.toInt() ?? 0,
      listingsTotal: (json['listings_total'] as num?)?.toInt() ?? 0,
      inquiriesTotal: (json['inquiries_total'] as num?)?.toInt() ?? 0,
      completedExchangesTotal: (json['completed_exchanges_total'] as num?)?.toInt() ?? 0,
      majorsActive: (json['majors_active'] as num?)?.toInt() ?? 0,
      facultiesActive: (json['faculties_active'] as num?)?.toInt() ?? 0,
      byMajor: _parseGroups(json['by_major']),
      byFaculty: _parseGroups(json['by_faculty']),
    );
  }

  static List<AcademicGroupActivity> _parseGroups(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map && row['name'] is String && (row['name'] as String).isNotEmpty)
          AcademicGroupActivity(
            name: row['name'] as String,
            faculty: row['faculty'] as String?,
            users: (row['users'] as num?)?.toInt() ?? 0,
            activeSellers: (row['active_sellers'] as num?)?.toInt() ?? 0,
            listings: (row['listings'] as num?)?.toInt() ?? 0,
            buyerInquiries: (row['buyer_inquiries'] as num?)?.toInt() ?? 0,
            completedExchanges: (row['completed_exchanges'] as num?)?.toInt() ?? 0,
            conversionRate: (row['conversion_rate'] as num?)?.toDouble() ?? 0.0,
          ),
    ];
  }

  static Map<String, dynamic> toJson(MajorActivityInsight insight) => {
        'users_total': insight.usersTotal,
        'listings_total': insight.listingsTotal,
        'inquiries_total': insight.inquiriesTotal,
        'completed_exchanges_total': insight.completedExchangesTotal,
        'majors_active': insight.majorsActive,
        'faculties_active': insight.facultiesActive,
        'by_major': [for (final g in insight.byMajor) _groupToJson(g, includeFaculty: true)],
        'by_faculty': [for (final g in insight.byFaculty) _groupToJson(g, includeFaculty: false)],
      };

  static Map<String, dynamic> _groupToJson(AcademicGroupActivity g, {required bool includeFaculty}) => {
        'name': g.name,
        if (includeFaculty && g.faculty != null) 'faculty': g.faculty,
        'users': g.users,
        'active_sellers': g.activeSellers,
        'listings': g.listings,
        'buyer_inquiries': g.buyerInquiries,
        'completed_exchanges': g.completedExchanges,
        'conversion_rate': g.conversionRate,
      };
}

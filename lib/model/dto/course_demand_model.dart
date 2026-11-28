import '../entities/course_demand.dart';

// `GET /analytics/course-demand/` ↔ [CourseDemandReport].

CourseDemandReport courseDemandFromJson(Object? json) {
  final map = json as Map<String, dynamic>;
  return CourseDemandReport(
    totalCourses: (map['total_courses'] as num?)?.toInt() ?? 0,
    shortageCourses: (map['shortage_courses'] as num?)?.toInt() ?? 0,
    courses: [
      for (final row in map['courses'] as List? ?? const [])
        CourseDemand(
          course: (row as Map<String, dynamic>)['course'] as String,
          listings: (row['listings'] as num?)?.toInt() ?? 0,
          available: (row['available'] as num?)?.toInt() ?? 0,
          interestedStudents: (row['interested_students'] as num?)?.toInt() ?? 0,
          demandPerListing: (row['demand_per_listing'] as num?)?.toDouble(),
          status: row['status'] as String? ?? 'none',
        ),
    ],
  );
}

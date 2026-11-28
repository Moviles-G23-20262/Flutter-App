/// BQ 19 for one course: listings on sale against the students interested in its listings.
class CourseDemand {
  final String course;
  final int listings;
  final int available;
  final int interestedStudents;

  /// Interested students per listing on sale; `null` when nothing is on sale.
  final double? demandPerListing;

  /// `shortage`, `balanced`, `no_demand` or `none`, as the analytics service decides it.
  final String status;

  const CourseDemand({
    required this.course,
    required this.listings,
    required this.available,
    required this.interestedStudents,
    this.demandPerListing,
    required this.status,
  });

  bool get isShort => status == 'shortage';
}

/// BQ 19: which courses students want more listings of.
class CourseDemandReport {
  final int totalCourses;
  final int shortageCourses;

  /// Biggest gap between demand and supply first.
  final List<CourseDemand> courses;

  const CourseDemandReport({required this.totalCourses, required this.shortageCourses, required this.courses});

  /// The courses short of listings, most wanted first.
  List<CourseDemand> get mostWanted => [for (final c in courses) if (c.isShort) c];
}

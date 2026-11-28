import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../model/entities/course_demand.dart';
import '../../view_model/course_demand_view_model.dart';
import 'common_widgets.dart';
import 'formatters.dart';

/// BQ 19 in the Seller Hub: the courses students want more listings of, so a seller knows what
/// is worth publishing. Only draws [CourseDemandViewModel].
class CourseDemandCard extends StatefulWidget {
  final CourseDemandViewModel viewModel;

  const CourseDemandCard({super.key, required this.viewModel});

  @override
  State<CourseDemandCard> createState() => _CourseDemandCardState();
}

class _CourseDemandCardState extends State<CourseDemandCard> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    final warning = dark ? AppColors.darkWarning : AppColors.lightWarning;
    final tagBg = dark ? AppColors.darkTagBg : AppColors.lightTagBg;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final report = vm.report;
        final wanted = vm.mostWanted;

        final Widget body;
        if (report != null && wanted.isNotEmpty) {
          body = Column(
            key: const Key('course-demand-figures'),
            children: [
              for (final course in wanted)
                _CourseRow(course: course, txPrimary: txPrimary, txMuted: txMuted, warning: warning, tagBg: tagBg),
            ],
          );
        } else if (report != null) {
          body = Text(
            report.totalCourses == 0
                ? 'No listing has a course code yet. Add the course when you publish so buyers find it.'
                : 'No course is short of listings right now: what students want is on sale.',
            key: const Key('course-demand-empty'),
            style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
          );
        } else if (vm.error != null && !vm.isLoading) {
          body = Row(
            children: [
              Expanded(child: Text(vm.error!, style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs))),
              TextButton(onPressed: () => vm.load(force: true), child: const Text('Try again')),
            ],
          );
        } else {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        return Semantics(
          container: true,
          label: 'Most wanted courses: courses with interested students and few listings on sale',
          child: AppCard(
            key: const Key('course-demand-card'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: accentHi, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Most wanted courses',
                          style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                    ),
                    Text('Interested · on sale', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Courses where students want more than what is on sale. Publishing for them sells faster.',
                    style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                if (vm.isSavedCopy && vm.savedAt != null) ...[
                  const SizedBox(height: 6),
                  Text('Offline · figures saved ${timeAgo(vm.savedAt!)}',
                      key: const Key('course-demand-saved-copy'),
                      style: AppTextStyles.body(warning, fontSize: AppTextStyles.size2xs)),
                ],
                const SizedBox(height: 10),
                AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CourseRow extends StatelessWidget {
  final CourseDemand course;
  final Color txPrimary, txMuted, warning, tagBg;

  const _CourseRow({
    required this.course,
    required this.txPrimary,
    required this.txMuted,
    required this.warning,
    required this.tagBg,
  });

  @override
  Widget build(BuildContext context) {
    final stock = course.available == 0 ? 'none on sale' : '${course.available} on sale';
    final students = '${course.interestedStudents} ${course.interestedStudents == 1 ? 'student' : 'students'}';
    return Semantics(
      label: '${course.course}: $students interested, $stock',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(8)),
              child: Text(course.course,
                  style: AppTextStyles.mono(txPrimary, fontSize: AppTextStyles.size2xs)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('$students interested',
                  style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs)),
            ),
            Text(stock,
                style: AppTextStyles.body(course.available == 0 ? warning : txMuted,
                    fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

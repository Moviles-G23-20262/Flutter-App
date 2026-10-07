import 'package:flutter/material.dart';
import '../../Domain/Entities/meetup_entities.dart';
import '../../theme/app_theme.dart';

// ─── Pieces shared by the chat, the meeting planner and the exchange screens ───

/// Icon for a kind of campus safe zone.
IconData zoneIcon(MeetingZoneTypeEnum type) {
  switch (type) {
    case MeetingZoneTypeEnum.LIBRARY:
      return Icons.local_library_outlined;
    case MeetingZoneTypeEnum.STUDENT_CENTER:
      return Icons.storefront_outlined;
    case MeetingZoneTypeEnum.BUILDING_LOBBY:
      return Icons.apartment_rounded;
    case MeetingZoneTypeEnum.PLAZA:
      return Icons.park_outlined;
  }
}

Color successColor(Brightness b) => b == Brightness.dark ? AppColors.darkSuccess : AppColors.lightSuccess;
Color warningColor(Brightness b) => b == Brightness.dark ? AppColors.darkWarning : AppColors.lightWarning;

/// "Monitored · verified safe zone", or a warning for open spots without cameras.
class SafeZoneLabel extends StatelessWidget {
  final bool monitored;
  final bool compact;

  const SafeZoneLabel({super.key, required this.monitored, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = monitored ? successColor(brightness) : warningColor(brightness);
    final text = monitored
        ? (compact ? 'Verified safe zone · monitored' : 'Monitored · verified safe zone')
        : 'Public spot · not monitored';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(monitored ? Icons.videocam_outlined : Icons.shield_outlined, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(color, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

/// Small rounded status pill, e.g. "Best match", "Like New".
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTextStyles.body(color, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
    );
  }
}

/// Numbered circle for the steps of a form ("1", "2").
class StepBadge extends StatelessWidget {
  final int number;
  final bool done;

  const StepBadge({super.key, required this.number, this.done = false});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = done
        ? successColor(brightness)
        : (brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: done
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : Text('$number',
                style: AppTextStyles.body(Colors.white, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

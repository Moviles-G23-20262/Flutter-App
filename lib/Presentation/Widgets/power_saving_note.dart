import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'meetup_widgets.dart';

/// "Battery saver: messages refresh less often". Shown while the battery is low and not charging.
class PowerSavingNote extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const PowerSavingNote({super.key, this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 6)});

  @override
  Widget build(BuildContext context) {
    final color = warningColor(Theme.of(context).brightness);
    return Container(
      width: double.infinity,
      padding: padding,
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.battery_saver_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Battery saver: messages refresh less often until you charge.',
              style: AppTextStyles.body(color, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

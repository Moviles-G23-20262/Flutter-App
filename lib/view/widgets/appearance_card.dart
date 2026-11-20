import 'package:flutter/material.dart';
import '../../model/entities/theme_preference.dart';
import '../../app/theme/app_theme.dart';
import '../../view_model/theme_view_model.dart';
import 'common_widgets.dart';

/// Profile → Appearance: Auto (ambient light sensor) / Light / Dark, and what the sensor reads.
class AppearanceCard extends StatelessWidget {
  final ThemeViewModel theme;

  const AppearanceCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = brightness == Brightness.dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemePreference>(
                segments: const [
                  ButtonSegment(value: ThemePreference.auto, label: Text('Auto'), icon: Icon(Icons.brightness_auto_rounded)),
                  ButtonSegment(value: ThemePreference.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                  ButtonSegment(value: ThemePreference.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
                ],
                selected: {theme.preference},
                showSelectedIcon: false,
                onSelectionChanged: (choice) => theme.setPreference(choice.first),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_statusIcon(), size: 16, color: accentHi),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<double?>(
                    valueListenable: theme.lux,
                    builder: (context, lux, _) => Text(
                      _explanation(lux),
                      style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                    ),
                  ),
                ),
              ],
            ),
            if (theme.preference == ThemePreference.auto) ...[
              const SizedBox(height: 6),
              Text(
                theme.sensorStatus == LightSensorStatus.reading
                    ? 'Context-aware · Turns dark below ${ThemeViewModel.darkBelowLux.round()} lux and light above '
                        '${ThemeViewModel.lightAboveLux.round()} lux.'
                    : "Context-aware · Automatically follows your phone's default system theme.",
                style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.size2xs),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _statusIcon() {
    switch (theme.preference) {
      case ThemePreference.auto:
        return Icons.brightness_auto_rounded;
      case ThemePreference.light:
        return Icons.light_mode_rounded;
      case ThemePreference.dark:
        return Icons.dark_mode_rounded;
    }
  }

  String _explanation(double? lux) {
    final activeMode = theme.isDark ? 'dark' : 'light';
    switch (theme.preference) {
      case ThemePreference.light:
        return "Always light. Choose Auto (context-aware) to follow your phone's default theme and ambient light.";
      case ThemePreference.dark:
        return "Always dark. Choose Auto (context-aware) to follow your phone's default theme and ambient light.";
      case ThemePreference.auto:
        switch (theme.sensorStatus) {
          case LightSensorStatus.reading:
            return "Auto (context-aware): light sensor reads ${lux?.round() ?? '–'} lux, so the app is $activeMode. "
                "Falls back to your phone's default theme if unavailable.";
          case LightSensorStatus.unavailable:
            return "Auto (context-aware): following your phone's default ($activeMode) theme (no light sensor detected).";
          case LightSensorStatus.waiting:
          case LightSensorStatus.off:
            return "Auto (context-aware): using your phone's default ($activeMode) theme while checking the light sensor…";
        }
    }
  }
}

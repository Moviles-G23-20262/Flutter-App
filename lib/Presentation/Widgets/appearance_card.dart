import 'package:flutter/material.dart';
import '../../Domain/Entities/theme_preference.dart';
import '../../Domain/use_cases/appearance_use_cases.dart';
import '../../theme/app_theme.dart';
import '../State Management/theme_state.dart';
import 'common_widgets.dart';

/// Profile → Appearance: Auto (ambient light sensor) / Light / Dark, and what the sensor reads.
class AppearanceCard extends StatelessWidget {
  final ThemeState theme;

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
                Icon(Icons.wb_sunny_outlined, size: 16, color: accentHi),
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
            if (theme.sensorStatus == LightSensorStatus.reading) ...[
              const SizedBox(height: 6),
              Text(
                'Turns dark below ${AmbientThemePolicy.defaultDarkBelowLux.round()} lux and light above '
                '${AmbientThemePolicy.defaultLightAboveLux.round()} lux.',
                style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.size2xs),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _explanation(double? lux) {
    switch (theme.preference) {
      case ThemePreference.light:
        return 'Always light. Choose Auto to follow the light around you.';
      case ThemePreference.dark:
        return 'Always dark. Choose Auto to follow the light around you.';
      case ThemePreference.auto:
        switch (theme.sensorStatus) {
          case LightSensorStatus.reading:
            final mode = theme.isDark ? 'dark' : 'light';
            return 'Light sensor: ${lux?.round() ?? '–'} lux around you, so the app is $mode.';
          case LightSensorStatus.unavailable:
            return "This phone has no light sensor, so the app follows the phone's theme.";
          case LightSensorStatus.waiting:
          case LightSensorStatus.off:
            return 'Reading the light sensor…';
        }
    }
  }
}

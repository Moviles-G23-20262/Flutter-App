import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/model/entities/meetup_entities.dart';
import 'package:flutter_front_end/model/entities/meeting_point_density.dart';
import 'package:flutter_front_end/model/entities/theme_preference.dart';
import 'package:flutter_front_end/model/repositories/appearance_repositories.dart';
import 'package:flutter_front_end/model/repositories/meeting_density_repository.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/rules/meeting_time_rules.dart';
import 'package:flutter_front_end/model/use_cases/appearance_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/get_meeting_point_density_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_front_end/view/widgets/appearance_card.dart';
import 'package:flutter_front_end/view/widgets/meetup_widgets.dart';
import 'package:flutter_front_end/view_model/meeting_planner_view_model.dart';
import 'package:flutter_front_end/view_model/theme_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSensor implements AmbientLightRepository {
  final controller = StreamController<double>.broadcast();

  @override
  Stream<double> luxReadings() => controller.stream;
}

class _FakeThemePrefs implements ThemePreferenceRepository {
  ThemePreference? stored;

  @override
  Future<ThemePreference?> load() async => stored;

  @override
  Future<void> save(ThemePreference preference) async => stored = preference;
}

class _FakeMeetupRepo implements MeetupRepository {
  List<MeetingPointEntity> zones = const [];
  MeetingSuggestions suggestions = const MeetingSuggestions(
    slots: [],
    suggested: null,
    callerHasSchedule: true,
    otherHasSchedule: true,
  );

  @override
  Future<List<MeetingPointEntity>> getMeetingPoints() async => zones;

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) async => suggestions;

  @override
  Future<MeetingProposalEntity> propose({
    required String chatRoomId,
    required String meetingPointId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<MeetingProposalEntity> accept(String proposalId) => throw UnimplementedError();

  @override
  Future<MeetingProposalEntity> decline(String proposalId) => throw UnimplementedError();

  @override
  Future<MeetingProposalEntity> withdraw(String proposalId) => throw UnimplementedError();
}

class _NoLocation implements LocationRepository {
  @override
  Future<GeoPoint?> currentLocation() async => null;
}

class _NoDensity implements MeetingDensityRepository {
  @override
  Future<MeetingPointDensity> getDensity() async => MeetingPointDensity.empty;
}

const _monitoredZone = MeetingPointEntity(
  id: 'z-monitored',
  name: 'ML Lobby',
  zoneType: MeetingZoneTypeEnum.BUILDING_LOBBY,
  location: GeoPoint(4.6028, -74.0648),
  isMonitored: true,
);

void main() {
  group('MeetingTimeRules (no past meeting times selectable)', () {
    test('earliestStart rounds up strictly after now to the next 5-minute step', () {
      expect(
        MeetingTimeRules.earliestStart(DateTime(2026, 11, 20, 12, 42, 30)),
        DateTime(2026, 11, 20, 12, 45),
      );
      expect(
        MeetingTimeRules.earliestStart(DateTime(2026, 11, 20, 12, 45, 0)),
        DateTime(2026, 11, 20, 12, 50),
      );
      expect(
        MeetingTimeRules.earliestStart(DateTime(2026, 11, 20, 12, 55, 10)),
        DateTime(2026, 11, 20, 13, 0),
      );
    });

    test('earliestDate advances to tomorrow when no future slot remains today', () {
      expect(
        MeetingTimeRules.earliestDate(DateTime(2026, 11, 20, 23, 50)),
        DateTime(2026, 11, 20),
      );
      expect(
        MeetingTimeRules.earliestDate(DateTime(2026, 11, 20, 23, 55)),
        DateTime(2026, 11, 21),
      );
    });

    test('availableHours and availableMinutes exclude past times on today', () {
      final now = DateTime(2026, 11, 20, 12, 42);
      final today = DateTime(2026, 11, 20);
      final tomorrow = DateTime(2026, 11, 21);
      final yesterday = DateTime(2026, 11, 19);

      expect(MeetingTimeRules.availableHours(yesterday, now), isEmpty);
      expect(MeetingTimeRules.availableHours(today, now).first, 12);
      expect(MeetingTimeRules.availableHours(today, now).contains(11), isFalse);
      expect(MeetingTimeRules.availableMinutes(today, 11, now), isEmpty);
      expect(MeetingTimeRules.availableMinutes(today, 12, now), [45, 50, 55]);
      expect(MeetingTimeRules.availableMinutes(today, 13, now), hasLength(12));
      expect(MeetingTimeRules.availableHours(tomorrow, now), hasLength(24));
    });
  });

  group('MeetingPlannerViewModel past-slot protection', () {
    MeetupUseCases buildUseCases(_FakeMeetupRepo repo) => MeetupUseCases(
          getMeetingPoints: GetMeetingPointsUseCase(repo),
          getSuggestions: GetMeetingSuggestionsUseCase(repo),
          propose: ProposeMeetingUseCase(repo),
          answer: AnswerMeetingProposalUseCase(repo),
          currentLocation: GetCurrentLocationUseCase(_NoLocation()),
          rankZones: RankSafeZonesUseCase(),
          recommend: RecommendMeetingPointUseCase(const RankMeetingPointsUseCase()),
          getDensity: GetMeetingPointDensityUseCase(_NoDensity()),
        );

    test('drops past suggested slots and refuses selecting a past time', () async {
      var clock = DateTime(2026, 11, 20, 12, 30);
      final repo = _FakeMeetupRepo()..zones = const [_monitoredZone];
      final pastSlot = FreeSlot(
        startsAt: DateTime(2026, 11, 20, 12, 0),
        endsAt: DateTime(2026, 11, 20, 13, 0),
        sharedBreak: true,
      );
      final futureSlot = FreeSlot(
        startsAt: DateTime(2026, 11, 20, 14, 0),
        endsAt: DateTime(2026, 11, 20, 15, 0),
        sharedBreak: true,
      );
      repo.suggestions = MeetingSuggestions(
        slots: [pastSlot, futureSlot],
        suggested: pastSlot,
        callerHasSchedule: true,
        otherHasSchedule: true,
      );

      final planner = MeetingPlannerViewModel(
        useCases: buildUseCases(repo),
        chatRoomId: 'r1',
        now: () => clock,
      );

      await planner.load();

      expect(planner.slots, [futureSlot]);
      expect(planner.selectedSlot, futureSlot);
      expect(planner.selectSlot(pastSlot), isFalse);
      expect(planner.selectedSlot, futureSlot);

      // If time advances past the selected slot, canPropose becomes false.
      clock = DateTime(2026, 11, 20, 14, 1);
      expect(planner.canPropose, isFalse);
      planner.dispose();
    });
  });

  group('SafeZoneLabel & icons (monitored vs public spot)', () {
    testWidgets('uses distinct icons for monitored safe zones vs public spots', (tester) async {
      expect(safeZoneStatusIcon(monitored: true), Icons.videocam_outlined);
      expect(safeZoneStatusIcon(monitored: false), Icons.groups_outlined);
      expect(safeZoneStatusIcon(monitored: false), isNot(Icons.shield_outlined));
      expect(safeZoneStatusIcon(monitored: false), isNot(safeZoneStatusIcon(monitored: true)));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SafeZoneLabel(monitored: true),
                SafeZoneLabel(monitored: false),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
    });
  });

  group('Auto theme explicit context-aware / phone default behavior', () {
    test('switching back to Auto resets sensor state and immediately follows phone default theme', () async {
      final sensor = _FakeSensor();
      final prefs = _FakeThemePrefs();
      final theme = ThemeViewModel(
        watchAmbientLight: WatchAmbientLightUseCase(sensor),
        loadPreference: LoadThemePreferenceUseCase(prefs),
        savePreference: SaveThemePreferenceUseCase(prefs),
        sensorTimeout: const Duration(milliseconds: 50),
      );
      await theme.start();
      sensor.controller.add(5); // dark
      await Future<void>.delayed(Duration.zero);
      expect(theme.themeMode, ThemeMode.dark);

      await theme.setPreference(ThemePreference.light);
      expect(theme.themeMode, ThemeMode.light);

      await theme.setPreference(ThemePreference.auto);
      expect(theme.themeMode, ThemeMode.system);
      theme.dispose();
    });

    testWidgets('AppearanceCard explicitly explains context-aware phone default mode', (tester) async {
      final sensor = _FakeSensor();
      final prefs = _FakeThemePrefs();
      final theme = ThemeViewModel(
        watchAmbientLight: WatchAmbientLightUseCase(sensor),
        loadPreference: LoadThemePreferenceUseCase(prefs),
        savePreference: SaveThemePreferenceUseCase(prefs),
        sensorTimeout: const Duration(milliseconds: 20),
      );
      await theme.start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppearanceCard(theme: theme)),
        ),
      );

      expect(find.textContaining('Auto (context-aware)'), findsOneWidget);
      expect(find.textContaining("phone's default"), findsWidgets);
      theme.dispose();
    });
  });
}

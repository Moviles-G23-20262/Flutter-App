import 'dart:async';

import 'package:flutter_front_end/Domain/Entities/power_status.dart';
import 'package:flutter_front_end/Domain/repositories/power_repositories.dart';
import 'package:flutter_front_end/Domain/rules/campus_hours.dart';
import 'package:flutter_front_end/Domain/use_cases/power_use_cases.dart';
import 'package:flutter_front_end/Presentation/State%20Management/power_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBattery implements BatteryRepository {
  final controller = StreamController<PowerStatus>.broadcast();

  @override
  Stream<PowerStatus> watch() => controller.stream;
}

void main() {
  group('PowerSavingPolicy', () {
    const policy = PowerSavingPolicy();
    PowerStatus battery(int level, {bool charging = false}) => PowerStatus(level: level, charging: charging);

    test('saves on a low battery that is not charging', () {
      expect(policy.decide(battery(20), savingNow: false), isTrue);
      expect(policy.decide(battery(21), savingNow: false), isFalse);
      expect(policy.decide(battery(10, charging: true), savingNow: false), isFalse);
    });

    test('stays on until 25 % so it does not flip around 20 %', () {
      expect(policy.decide(battery(22), savingNow: true), isTrue);
      expect(policy.decide(battery(25), savingNow: true), isFalse);
    });

    test('plugging in turns it off right away', () {
      expect(policy.decide(battery(5, charging: true), savingNow: true), isFalse);
    });
  });

  group('PowerState', () {
    test('switches on and off by itself as the battery changes', () async {
      final battery = _FakeBattery();
      final power = PowerState(watchBattery: WatchBatteryUseCase(battery))..start();
      var notified = 0;
      power.addListener(() => notified++);

      battery.controller.add(const PowerStatus(level: 50, charging: false));
      await Future<void>.delayed(Duration.zero);
      expect(power.isSaving, isFalse);
      expect(notified, 0, reason: 'nothing changed, nothing to repaint');

      battery.controller.add(const PowerStatus(level: 15, charging: false));
      await Future<void>.delayed(Duration.zero);
      expect(power.isSaving, isTrue);

      battery.controller.add(const PowerStatus(level: 15, charging: true));
      await Future<void>.delayed(Duration.zero);
      expect(power.isSaving, isFalse);
      expect(notified, 2);
      power.dispose();
    });
  });

  group('CampusHours', () {
    // Wednesday 7 Oct 2026.
    DateTime wed(int hour, [int minute = 0]) => DateTime(2026, 10, 7, hour, minute);

    test('open Monday to Saturday from 07:00 to 20:00', () {
      expect(CampusHours.isOpen(wed(7)), isTrue);
      expect(CampusHours.isOpen(wed(19, 59)), isTrue);
      expect(CampusHours.isOpen(wed(20)), isFalse);
      expect(CampusHours.isOpen(wed(6, 59)), isFalse);
      expect(CampusHours.isOpen(DateTime(2026, 10, 11, 12)), isFalse, reason: 'Sunday');
    });

    test('says when it opens next', () {
      expect(CampusHours.describeNextOpening(wed(22)), 'tomorrow at 07:00');
      expect(CampusHours.describeNextOpening(wed(5)), 'today at 07:00');
      // Saturday night and Sunday both point to Monday.
      expect(CampusHours.describeNextOpening(DateTime(2026, 10, 10, 21)), 'on Monday at 07:00');
      expect(CampusHours.describeNextOpening(DateTime(2026, 10, 11, 10)), 'tomorrow at 07:00');
      expect(CampusHours.nextOpening(DateTime(2026, 10, 10, 21)), DateTime(2026, 10, 12, 7));
    });
  });
}

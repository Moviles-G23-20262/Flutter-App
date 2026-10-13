import 'dart:async';

import 'package:flutter_front_end/Domain/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/Domain/use_cases/connectivity_use_cases.dart';
import 'package:flutter_front_end/Presentation/State%20Management/connectivity_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNetwork implements ConnectivityRepository {
  bool online = true;
  bool failing = false;
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async {
    if (failing) throw Exception('plugin failed');
    return online;
  }

  @override
  Stream<bool> watch() => controller.stream;
}

ConnectivityState _state(_FakeNetwork network) => ConnectivityState(
      getConnectivity: GetConnectivityUseCase(network),
      watchConnectivity: WatchConnectivityUseCase(network),
    );

void main() {
  group('ConnectivityState', () {
    test('is online until told otherwise', () {
      final state = _state(_FakeNetwork());
      expect(state.isOnline, isTrue);
      expect(state.isOffline, isFalse);
    });

    test('reads the current status when it starts', () async {
      final state = _state(_FakeNetwork()..online = false)..start();
      await Future<void>.delayed(Duration.zero);
      expect(state.isOffline, isTrue);
    });

    test('follows the network as it drops and returns, notifying only on change', () async {
      final network = _FakeNetwork();
      final state = _state(network)..start();
      var notified = 0;
      state.addListener(() => notified++);

      network.controller.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(notified, 0, reason: 'still online, nothing to repaint');

      network.controller.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(state.isOffline, isTrue);
      expect(notified, 1);

      network.controller.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(state.isOnline, isTrue);
      expect(notified, 2);
    });

    test('a failing plugin or stream error never crashes and leaves the app online', () async {
      final network = _FakeNetwork()..failing = true;
      final state = _state(network)..start();
      network.controller.addError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(state.isOnline, isTrue);
    });

    test('ignores events after it is disposed', () async {
      final network = _FakeNetwork();
      final state = _state(network)..start();
      state.dispose();
      network.controller.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(state.isOnline, isTrue);
    });
  });
}

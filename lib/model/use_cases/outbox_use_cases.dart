import '../services/outbox_sync_service.dart';

/// Starts sending the signed-in user's queued items (on login and session restore).
class StartOutboxSyncUseCase {
  final OutboxSyncService sync;
  StartOutboxSyncUseCase(this.sync);

  void execute(String userId) => sync.start(userId);
}

/// Stops sending on logout; the queued items stay for that user's next login.
class StopOutboxSyncUseCase {
  final OutboxSyncService sync;
  StopOutboxSyncUseCase(this.sync);

  void execute() => sync.stop();
}

/// Sends what is waiting now, e.g. when the app comes back to the foreground or the user
/// triggers a one-shot send over mobile data.
class SyncOutboxUseCase {
  final OutboxSyncService sync;
  SyncOutboxUseCase(this.sync);

  Future<void> execute({bool overMobileData = false}) =>
      sync.flush(overMobileData: overMobileData);
}

/// Reads and observes whether queued outbox items are paused waiting for Wi-Fi.
class WatchWaitingForWifiUseCase {
  final OutboxSyncService sync;
  WatchWaitingForWifiUseCase(this.sync);

  bool get current => sync.isWaitingForWifi;
  Stream<bool> execute() => sync.waitingForWifiStream;
}

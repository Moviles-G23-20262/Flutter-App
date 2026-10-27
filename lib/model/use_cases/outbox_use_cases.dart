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

/// Sends what is waiting now, e.g. when the app comes back to the foreground.
class SyncOutboxUseCase {
  final OutboxSyncService sync;
  SyncOutboxUseCase(this.sync);

  Future<void> execute() => sync.flush();
}

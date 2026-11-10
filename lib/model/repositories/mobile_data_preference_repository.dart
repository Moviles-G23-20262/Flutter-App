/// Persisted user preference controlling whether the outbox may sync over cellular mobile data.
abstract class MobileDataPreferenceRepository {
  Future<bool> isAllowed();
  Future<void> setAllowed(bool allowed);
}

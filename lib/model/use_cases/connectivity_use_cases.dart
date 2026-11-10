import '../repositories/connectivity_repository.dart';
import '../repositories/mobile_data_preference_repository.dart';

class GetConnectivityUseCase {
  final ConnectivityRepository repository;
  GetConnectivityUseCase(this.repository);

  Future<bool> execute() => repository.isOnline();
}

class WatchConnectivityUseCase {
  final ConnectivityRepository repository;
  WatchConnectivityUseCase(this.repository);

  Stream<bool> execute() => repository.watch();
}

class GetNetworkTransportUseCase {
  final NetworkTransportRepository repository;
  GetNetworkTransportUseCase(this.repository);

  Future<NetworkTransport> execute() => repository.currentTransport();
}

class WatchNetworkTransportUseCase {
  final NetworkTransportRepository repository;
  WatchNetworkTransportUseCase(this.repository);

  Stream<NetworkTransport> execute() => repository.watchTransport();
}

class LoadAllowMobileDataUseCase {
  final MobileDataPreferenceRepository repository;
  LoadAllowMobileDataUseCase(this.repository);

  Future<bool> execute() => repository.isAllowed();
}

class SaveAllowMobileDataUseCase {
  final MobileDataPreferenceRepository repository;
  SaveAllowMobileDataUseCase(this.repository);

  Future<void> execute(bool allowed) => repository.setAllowed(allowed);
}

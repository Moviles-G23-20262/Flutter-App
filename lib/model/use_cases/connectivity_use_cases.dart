import '../repositories/connectivity_repository.dart';

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

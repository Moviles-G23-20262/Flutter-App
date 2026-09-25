import '../repositories/repositories.dart';
import '../entities/user.dart';
import '../entities/material.dart';

class GetUserUseCase {
  final UserRepository repository;

  GetUserUseCase(this.repository);

  Future<User> execute(String id) {
    return repository.getUser(id);
  }
}

class GetMaterialsUseCase {
  final MaterialRepository repository;

  GetMaterialsUseCase(this.repository);

  Future<List<MaterialEntity>> execute() {
    return repository.getMaterials();
  }
}
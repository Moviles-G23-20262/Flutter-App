import '../entities/user.dart';
import '../entities/material.dart';

abstract class UserRepository {
  Future<User> getUser(String id);
}

abstract class MaterialRepository {
  Future<List<MaterialEntity>> getMaterials();
  Future<MaterialEntity> createMaterial(MaterialEntity material);
}
import '../../domain/repositories/repositories.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/material.dart';
import '../data_sources/remote_data_source.dart';

class UserRepositoryImpl implements UserRepository {
  final RemoteDataSource remoteDataSource;

  UserRepositoryImpl({required this.remoteDataSource});

  @override
  Future<User> getUser(String id) async {
    return await remoteDataSource.getUser(id);
  }
}

class MaterialRepositoryImpl implements MaterialRepository {
  final RemoteDataSource remoteDataSource;

  MaterialRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<MaterialEntity>> getMaterials() async {
    return await remoteDataSource.getMaterials();
  }

  @override
  Future<MaterialEntity> createMaterial(MaterialEntity material) async {
    // We assume casting or converting Entity to Model here
    // In a real app we would map Entity -> Model, but for simplicity we rely on duck typing if they share the same structure, 
    // or we implement a mapper.
    throw UnimplementedError('Mapper needed for Entity to Model');
  }
}
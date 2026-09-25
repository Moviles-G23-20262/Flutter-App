import '../../core/network/api_client.dart';
import '../models/user_model.dart';
import '../models/material_model.dart';

abstract class RemoteDataSource {
  Future<UserModel> getUser(String id);
  Future<List<MaterialModel>> getMaterials();
  Future<MaterialModel> createMaterial(MaterialModel material);
}

class RemoteDataSourceImpl implements RemoteDataSource {
  final ApiClient apiClient;

  RemoteDataSourceImpl({required this.apiClient});

  @override
  Future<UserModel> getUser(String id) async {
    final response = await apiClient.get('/users/$id');
    return UserModel.fromJson(response);
  }

  @override
  Future<List<MaterialModel>> getMaterials() async {
    final response = await apiClient.get('/materials');
    return (response as List).map((json) => MaterialModel.fromJson(json)).toList();
  }
  
  @override
  Future<MaterialModel> createMaterial(MaterialModel material) async {
    final response = await apiClient.post('/materials', body: material.toJson());
    return MaterialModel.fromJson(response);
  }
}
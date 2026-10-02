import '../../domain/entities/material.dart';
import '../../domain/entities/search_models.dart';
import '../../domain/repositories/material_catalog_repository.dart';
import '../../domain/repositories/repositories.dart';

class MaterialCatalogRepositoryImpl
    implements MaterialCatalogRepository {
  final MaterialRepository materialRepository;

  CatalogSnapshot _localSnapshot = CatalogSnapshot.empty;

  MaterialCatalogRepositoryImpl({
    required this.materialRepository,
  });

  @override
  Future<List<MaterialEntity>> fetchRemote() async {
    final materials = await materialRepository.getMaterials();

    _localSnapshot = CatalogSnapshot(
      items: materials,
      syncedAt: DateTime.now(),
    );

    return materials;
  }

  @override
  Future<CatalogSnapshot> readLocal() async {
    return _localSnapshot;
  }
}
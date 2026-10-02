import '../Entities/material_entity.dart';
import '../Entities/search_models.dart';

/// Source of the listings that the search strategies work on.
abstract class MaterialCatalogRepository {
  /// Downloads the listings from the backend and refreshes the saved copy.
  ///
  /// Throws when the server cannot be reached.
  Future<List<MaterialEntity>> fetchRemote();

  /// Listings saved by the last successful [fetchRemote]. Never throws; an
  /// unreadable or missing copy is reported as [CatalogSnapshot.empty].
  Future<CatalogSnapshot> readLocal();
}

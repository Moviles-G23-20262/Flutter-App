import '../Entities/material_entity.dart';

abstract class SearchStrategy {
  const SearchStrategy();

  String get id;
  String get label;

  List<MaterialEntity> search(
    List<MaterialEntity> materials,
    String query,
  );
}

class GeneralSearchStrategy extends SearchStrategy {
  const GeneralSearchStrategy();

  @override
  String get id => 'general';

  @override
  String get label => 'General';

  @override
  List<MaterialEntity> search(
    List<MaterialEntity> materials,
    String query,
  ) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return List.of(materials);
    }

    return materials.where((material) {
      return material.title.toLowerCase().contains(q) ||
          material.description.toLowerCase().contains(q) ||
          (material.courseCode?.toLowerCase().contains(q) ?? false) ||
          material.category.displayName.toLowerCase().contains(q);
    }).toList();
  }
}

/// Searches only by course code.
class CourseSearchStrategy extends SearchStrategy {
  const CourseSearchStrategy();

  @override
  String get id => 'course';

  @override
  String get label => 'Course';

  @override
  List<MaterialEntity> search(
    List<MaterialEntity> materials,
    String query,
  ) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return List.of(materials);
    }

    return materials.where((material) {
      return material.courseCode?.toLowerCase().contains(q) ?? false;
    }).toList();
  }
}

/// Searches by exact title.
class ExactSearchStrategy extends SearchStrategy {
  const ExactSearchStrategy();

  @override
  String get id => 'exact';

  @override
  String get label => 'Exact title';

  @override
  List<MaterialEntity> search(
    List<MaterialEntity> materials,
    String query,
  ) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return List.of(materials);
    }

    return materials.where((material) {
      return material.title.trim().toLowerCase() == q;
    }).toList();
  }
}

const List<SearchStrategy> kSearchStrategies = [
  GeneralSearchStrategy(),
  CourseSearchStrategy(),
  ExactSearchStrategy(),
];
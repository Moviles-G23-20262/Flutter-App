import '../entities/uniandes_program.dart';

/// The catalog of Uniandes undergraduate programs shipped with the app (works offline).
abstract class UniandesProgramsRepository {
  /// Every program, sorted by name. The first call reads and parses the bundled file; the next
  /// ones answer from memory. Throws when the file cannot be read.
  Future<List<UniandesProgram>> getPrograms();

  /// The programs whose name or faculty contains [query], ignoring case and accents
  /// ("ingenieria" finds "Ingeniería"). An empty query returns every program.
  Future<List<UniandesProgram>> search(String query);
}

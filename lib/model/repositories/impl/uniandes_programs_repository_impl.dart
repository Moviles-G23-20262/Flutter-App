import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;

import '../../entities/uniandes_program.dart';
import '../uniandes_programs_repository.dart';

/// Reads `assets/data/uniandes_programs.json` once, parses it in a background isolate and keeps
/// the list in memory, so searching while the user types never touches the bundle again.
class UniandesProgramsRepositoryImpl implements UniandesProgramsRepository {
  static const String assetPath = 'assets/data/uniandes_programs.json';

  final Future<String> Function() _load;

  List<UniandesProgram>? _programs;
  Future<List<UniandesProgram>>? _loading;

  /// How many times the file was read and parsed (it should be once per app run).
  int parseCount = 0;

  /// [load] replaces reading the asset, e.g. in tests.
  UniandesProgramsRepositoryImpl({Future<String> Function()? load})
      : _load = load ?? (() => rootBundle.loadString(assetPath));

  @override
  Future<List<UniandesProgram>> getPrograms() {
    final cached = _programs;
    if (cached != null) return Future.value(cached);
    // Two screens asking at once share one parse.
    return _loading ??= _readAndParse();
  }

  Future<List<UniandesProgram>> _readAndParse() async {
    try {
      final text = await _load();
      parseCount++;
      final programs = await parseProgramsInBackground(text);
      _programs = programs;
      return programs;
    } finally {
      // A failed read can be tried again; a successful one is kept in _programs.
      _loading = null;
    }
  }

  @override
  Future<List<UniandesProgram>> search(String query) async {
    final programs = await getPrograms();
    final needle = foldForSearch(query.trim());
    if (needle.isEmpty) return programs;
    return programs
        .where((p) => foldForSearch(p.name).contains(needle) || foldForSearch(p.faculty).contains(needle))
        .toList(growable: false);
  }
}

/// Decodes and sorts the catalog in a background isolate, so the UI thread never parses it.
Future<List<UniandesProgram>> parseProgramsInBackground(String text) =>
    Isolate.run(() => parsePrograms(text));

/// `{"programs": [{"name": "...", "faculty": "..."}]}` → programs sorted by name (accent-blind).
/// Rows without a name or a faculty are skipped; a repeated name is kept once.
List<UniandesProgram> parsePrograms(String text) {
  final json = jsonDecode(text);
  final rows = json is Map ? json['programs'] : null;
  if (rows is! List) throw const FormatException('The programs catalog has no "programs" list.');
  final seen = <String>{};
  final programs = <UniandesProgram>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final name = row['name'];
    final faculty = row['faculty'];
    if (name is! String || faculty is! String) continue;
    final cleanName = name.trim();
    final cleanFaculty = faculty.trim();
    if (cleanName.isEmpty || cleanFaculty.isEmpty || !seen.add(cleanName)) continue;
    programs.add(UniandesProgram(name: cleanName, faculty: cleanFaculty));
  }
  programs.sort((a, b) => foldForSearch(a.name).compareTo(foldForSearch(b.name)));
  return List.unmodifiable(programs);
}

const _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n',
};

/// Lower case without Spanish accents, for comparing names the way people type them.
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

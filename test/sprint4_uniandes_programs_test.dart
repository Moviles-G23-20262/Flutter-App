// Uniandes programs catalog: the bundled JSON, parsed in an isolate and kept in memory.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_front_end/model/entities/uniandes_program.dart';
import 'package:flutter_front_end/model/repositories/impl/uniandes_programs_repository_impl.dart';
import 'package:flutter_front_end/model/rules/profile_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = '''
{"programs": [
  {"name": "Medicina", "faculty": "Medicina"},
  {"name": "Ingeniería de Sistemas y Computación", "faculty": "Ingeniería"},
  {"name": "Administración", "faculty": "Administración"},
  {"name": "  Economía ", "faculty": "Economía"},
  {"name": "", "faculty": "Ciencias"},
  {"name": "Sin facultad"},
  {"name": "Medicina", "faculty": "Duplicada"}
]}
''';

void main() {
  group('parsePrograms', () {
    test('skips incomplete rows and duplicates, trims and sorts by name ignoring accents', () {
      final programs = parsePrograms(_catalog);

      expect(programs.map((p) => p.name), [
        'Administración',
        'Economía',
        'Ingeniería de Sistemas y Computación',
        'Medicina',
      ]);
      expect(programs.last.faculty, 'Medicina');
    });

    test('a file without a "programs" list is an error', () {
      expect(() => parsePrograms('{"other": []}'), throwsFormatException);
    });

    test('parseProgramsInBackground gives the same list from a background isolate', () async {
      final programs = await parseProgramsInBackground(_catalog);

      expect(programs, parsePrograms(_catalog));
    });
  });

  group('UniandesProgramsRepositoryImpl', () {
    test('the first call reads and parses the file; the next ones come from memory', () async {
      var reads = 0;
      final repository = UniandesProgramsRepositoryImpl(load: () async {
        reads++;
        return _catalog;
      });

      final first = await repository.getPrograms();
      final second = await repository.getPrograms();
      await repository.search('ing');

      expect(reads, 1);
      expect(repository.parseCount, 1);
      expect(identical(first, second), isTrue);
    });

    test('two calls at the same time share one parse', () async {
      var reads = 0;
      final repository = UniandesProgramsRepositoryImpl(load: () async {
        reads++;
        return _catalog;
      });

      final results = await Future.wait([repository.getPrograms(), repository.getPrograms()]);

      expect(reads, 1);
      expect(results[0], results[1]);
    });

    test('a failed read is not cached: the next call tries again', () async {
      var fail = true;
      final repository = UniandesProgramsRepositoryImpl(load: () async {
        if (fail) throw const FileSystemException('missing asset');
        return _catalog;
      });

      await expectLater(repository.getPrograms(), throwsA(isA<FileSystemException>()));
      fail = false;

      expect(await repository.getPrograms(), hasLength(4));
    });

    test('search ignores case and accents and also matches the faculty', () async {
      final repository = UniandesProgramsRepositoryImpl(load: () async => _catalog);

      expect((await repository.search('INGENIERIA')).map((p) => p.name), ['Ingeniería de Sistemas y Computación']);
      expect((await repository.search('economia')).single.name, 'Economía');
      expect(await repository.search('  '), hasLength(4));
      expect(await repository.search('zzz'), isEmpty);
    });
  });

  group('assets/data/uniandes_programs.json', () {
    late List<UniandesProgram> programs;

    setUpAll(() {
      programs = parsePrograms(File('assets/data/uniandes_programs.json').readAsStringSync());
    });

    test('is registered in pubspec.yaml', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('assets/data/uniandes_programs.json'));
    });

    test('every row is valid (no row was dropped by the parser)', () {
      final raw = (jsonDecode(File('assets/data/uniandes_programs.json').readAsStringSync()) as Map)['programs'] as List;
      expect(programs, hasLength(raw.length));
    });

    test('maps the programs to their faculty', () {
      String facultyOf(String name) => programs.singleWhere((p) => p.name == name).faculty;

      expect(facultyOf('Ingeniería de Sistemas y Computación'), 'Ingeniería');
      expect(facultyOf('Ingeniería Electrónica'), 'Ingeniería');
      expect(facultyOf('Administración'), 'Administración');
      expect(facultyOf('Economía'), 'Economía');
      expect(facultyOf('Derecho'), 'Derecho');
      expect(facultyOf('Medicina'), 'Medicina');
      expect(facultyOf('Diseño'), 'Arquitectura y Diseño');
    });

    test('covers every faculty', () {
      expect(
        programs.map((p) => p.faculty).toSet(),
        containsAll(<String>[
          'Administración',
          'Arquitectura y Diseño',
          'Artes y Humanidades',
          'Ciencias',
          'Ciencias Sociales',
          'Derecho',
          'Economía',
          'Educación',
          'Ingeniería',
          'Medicina',
        ]),
      );
    });

    test('every name and faculty passes the server rules, so any choice can be saved', () {
      for (final program in programs) {
        expect(ProfileRules.validateMajor(program.name), isNull, reason: program.name);
        expect(ProfileRules.validateFaculty(program.faculty), isNull, reason: program.faculty);
      }
    });
  });
}

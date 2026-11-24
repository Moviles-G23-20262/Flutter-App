import 'package:flutter/foundation.dart';

/// An undergraduate program of Universidad de los Andes and the faculty (or school) it belongs to.
@immutable
class UniandesProgram {
  final String name;
  final String faculty;

  const UniandesProgram({required this.name, required this.faculty});

  @override
  bool operator ==(Object other) => other is UniandesProgram && other.name == name && other.faculty == faculty;

  @override
  int get hashCode => Object.hash(name, faculty);

  @override
  String toString() => 'UniandesProgram($name, $faculty)';
}

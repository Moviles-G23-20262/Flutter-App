import 'package:flutter/foundation.dart';
import '../../Domain/Entities/meetup_entities.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import '../../Domain/use_cases/meetup_use_cases.dart';

/// The signed-in user's weekly classes, used to find hours they are free to meet.
class ScheduleState extends ChangeNotifier {
  final GetScheduleUseCase getSchedule;
  final AddScheduleBlockUseCase addBlock;
  final RemoveScheduleBlockUseCase removeBlock;

  ScheduleState({required this.getSchedule, required this.addBlock, required this.removeBlock});

  List<ScheduleBlockEntity> _blocks = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  int _generation = 0;

  /// Monday first, then by start time.
  List<ScheduleBlockEntity> get blocks => _blocks;
  bool get isLoading => _loading;
  bool get isFirstLoad => !_loadedOnce;
  String? get error => _error;

  List<ScheduleBlockEntity> blocksOn(int dayOfWeek) =>
      _blocks.where((b) => b.dayOfWeek == dayOfWeek).toList();

  Future<void> load() async {
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final blocks = await getSchedule.execute();
      if (generation != _generation) return;
      _blocks = _sorted(blocks);
    } on DataException catch (e) {
      if (generation != _generation) return;
      _error = e.message;
    }
    _loading = false;
    _loadedOnce = true;
    notifyListeners();
  }

  /// Returns an error message to show, or `null` when the class was added.
  Future<String?> add(NewScheduleBlock block) async {
    try {
      final created = await addBlock.execute(block, existing: _blocks);
      _blocks = _sorted([..._blocks, created]);
      notifyListeners();
      return null;
    } on DataException catch (e) {
      return e.message;
    }
  }

  /// Returns an error message to show, or `null` when the class was removed.
  Future<String?> remove(String blockId) async {
    final before = _blocks;
    _blocks = _blocks.where((b) => b.id != blockId).toList();
    notifyListeners();
    try {
      await removeBlock.execute(blockId);
      return null;
    } on DataException catch (e) {
      _blocks = before;
      notifyListeners();
      return e.message;
    }
  }

  void clear() {
    _generation++;
    _blocks = const [];
    _loading = false;
    _loadedOnce = false;
    _error = null;
    notifyListeners();
  }

  List<ScheduleBlockEntity> _sorted(List<ScheduleBlockEntity> blocks) => [...blocks]
    ..sort((a, b) => a.dayOfWeek != b.dayOfWeek
        ? a.dayOfWeek.compareTo(b.dayOfWeek)
        : a.startMinute.compareTo(b.startMinute));
}

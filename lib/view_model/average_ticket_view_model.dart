import 'package:flutter/foundation.dart';

import '../model/entities/average_ticket.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/use_cases/get_average_ticket_use_case.dart';

/// The average ticket card in the Seller Hub: loading, the figures, or why they could not load.
class AverageTicketViewModel extends ChangeNotifier {
  final GetAverageTicketUseCase getAverageTicket;

  AverageTicketViewModel({required this.getAverageTicket});

  AverageTicket? _ticket;
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  AverageTicket? get ticket => _ticket;
  bool get isLoading => _loading;

  /// Set when the last load failed and there is nothing to show.
  String? get error => _error;

  /// Loads the figures once; later calls do nothing unless [force] (e.g. "Try again").
  Future<void> load({bool force = false}) async {
    if (_loading || (_ticket != null && !force)) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      _ticket = await getAverageTicket.execute();
    } on DataException catch (e) {
      // Keep what was already on screen; only show the error when there is nothing else.
      if (_ticket == null) _error = e.message;
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

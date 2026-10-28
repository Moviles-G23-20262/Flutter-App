import '../entities/average_ticket.dart';

abstract class AverageTicketRepository {
  /// The average ticket of completed sales. Offline, the copy saved at the last successful load.
  /// Throws `DataException` (`NoConnectionException` when offline with nothing saved).
  Future<AverageTicket> getAverageTicket();
}

import '../entities/average_ticket.dart';
import '../repositories/average_ticket_repository.dart';

/// Average ticket: how much a completed campus sale is worth, overall and per item condition.
class GetAverageTicketUseCase {
  final AverageTicketRepository repository;

  GetAverageTicketUseCase(this.repository);

  Future<AverageTicket> execute() => repository.getAverageTicket();
}

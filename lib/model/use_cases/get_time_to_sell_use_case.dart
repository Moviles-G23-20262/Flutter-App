import '../entities/time_to_sell.dart';
import '../repositories/time_to_sell_repository.dart';

/// BQ11: What is the average time (in days) it takes for a newly listed
/// academic item to be marked as sold?
class GetTimeToSellUseCase {
  final TimeToSellRepository repository;

  GetTimeToSellUseCase(this.repository);

  Future<TimeToSellInsight> execute() => repository.getTimeToSell();
}

import '../../data_sources/analytics_remote_data_source.dart';
import '../../data_sources/local/response_cache.dart';
import '../../dto/average_ticket_model.dart';
import '../../entities/average_ticket.dart';
import '../average_ticket_repository.dart';
import 'marketplace_repositories_impl.dart' show guardRequest;

/// Network falling back to the copy in `cached_responses`. The figure is the same for every
/// account, so it is saved once ('global'), like the other analytics insights.
class AverageTicketRepositoryImpl implements AverageTicketRepository {
  static const String cacheOwner = 'global';
  static const String cacheKey = 'average_ticket';

  final AnalyticsRemoteDataSource remote;
  final ResponseCache? cache;

  AverageTicketRepositoryImpl({required this.remote, this.cache});

  @override
  Future<AverageTicket> getAverageTicket() {
    final cache = this.cache;
    if (cache == null) return guardRequest(remote.getAverageTicket);
    return guardRequest(() async {
      final result = await cache.networkFirst(
        ownerId: cacheOwner,
        key: cacheKey,
        fetch: () async => AverageTicketModel.toJson(await remote.getAverageTicket()),
        parse: (json) => AverageTicketModel.fromJson(json as Map<String, dynamic>),
      );
      return result.data;
    });
  }
}

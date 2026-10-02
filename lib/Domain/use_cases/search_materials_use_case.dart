import '../Entities/search_models.dart';
import '../Strategies/search_strategy.dart';
import '../Strategies/sort_strategy.dart';
import '../repositories/connectivity_checker.dart';


class SearchMaterialsUseCase {
  final SearchStrategy online;
  final SearchStrategy offline;
  final ConnectivityChecker connectivity;

  SearchMaterialsUseCase({
    required this.online,
    required this.offline,
    required this.connectivity,
  });

  Future<SearchResult> execute(
    SearchCriteria criteria, {
    SortStrategy sort = const RelevanceSortStrategy(),
  }) async {
    final SearchResult result;

    if (await _hasConnection()) {
      SearchResult attempt;
      try {
        attempt = await online.search(criteria);
      } on Exception {
        // Timeout, no route to the server, malformed answer...: use the saved copy.
        attempt = (await offline.search(criteria)).copyWith(serverUnreachable: true);
      }
      result = attempt;
    } else {
      result = await offline.search(criteria);
    }

    return result.copyWith(items: sort.sort(result.items));
  }

  Future<bool> _hasConnection() async {
    try {
      return await connectivity.isOnline;
    } on Exception {
      // Unknown state: let the request itself decide.
      return true;
    }
  }
}

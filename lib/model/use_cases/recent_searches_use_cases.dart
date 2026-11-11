import '../repositories/recent_searches_repository.dart';

/// The user's recent searches, most recent first. Works offline.
class GetRecentSearchesUseCase {
  final RecentSearchesRepository repository;

  GetRecentSearchesUseCase(this.repository);

  Future<List<String>> execute(String ownerId) => repository.getAll(ownerId);
}

/// Remembers a search the user made; returns the updated list.
class SaveRecentSearchUseCase {
  final RecentSearchesRepository repository;

  SaveRecentSearchUseCase(this.repository);

  Future<List<String>> execute(String ownerId, String query) => repository.add(ownerId, query);
}

/// Forgets one recent search; returns the updated list.
class RemoveRecentSearchUseCase {
  final RecentSearchesRepository repository;

  RemoveRecentSearchUseCase(this.repository);

  Future<List<String>> execute(String ownerId, String query) => repository.remove(ownerId, query);
}

class ClearRecentSearchesUseCase {
  final RecentSearchesRepository repository;

  ClearRecentSearchesUseCase(this.repository);

  Future<void> execute(String ownerId) => repository.clear(ownerId);
}

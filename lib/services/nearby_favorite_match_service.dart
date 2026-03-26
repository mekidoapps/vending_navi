import '../models/nearby_favorite_match.dart';

class NearbyFavoriteMatchService {
  NearbyFavoriteMatchService._internal();

  static final NearbyFavoriteMatchService _instance =
  NearbyFavoriteMatchService._internal();

  factory NearbyFavoriteMatchService() => _instance;

  final List<NearbyFavoriteMatch> _cache = <NearbyFavoriteMatch>[];

  List<NearbyFavoriteMatch> get cachedMatches =>
      List<NearbyFavoriteMatch>.unmodifiable(_cache);

  void setMatches(List<NearbyFavoriteMatch> items) {
    _cache
      ..clear()
      ..addAll(items);
  }

  void clear() {
    _cache.clear();
  }

  bool get hasData => _cache.isNotEmpty;
}
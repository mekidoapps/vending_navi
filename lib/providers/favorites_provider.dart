import 'package:flutter/foundation.dart';

import '../repositories/favorite_repository.dart';

class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider({
    FavoriteRepository? favoriteRepository,
  }) : _favoriteRepository = favoriteRepository ?? FavoriteRepository();

  final FavoriteRepository _favoriteRepository;

  List<FavoriteItem> _productFavorites = <FavoriteItem>[];
  List<FavoriteItem> _machineFavorites = <FavoriteItem>[];
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedTabIndex = 0;

  List<FavoriteItem> get productFavorites =>
      List<FavoriteItem>.unmodifiable(_productFavorites);
  List<FavoriteItem> get machineFavorites =>
      List<FavoriteItem>.unmodifiable(_machineFavorites);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get selectedTabIndex => _selectedTabIndex;

  void setSelectedTabIndex(int value) {
    _selectedTabIndex = value;
    notifyListeners();
  }

  Future<void> loadFavorites(String userId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _productFavorites = await _favoriteRepository.fetchFavoritesByUser(
        userId: userId,
        targetType: 'product',
      );

      _machineFavorites = await _favoriteRepository.fetchFavoritesByUser(
        userId: userId,
        targetType: 'machine',
      );
    } catch (e) {
      _errorMessage = e.toString();
      _productFavorites = <FavoriteItem>[];
      _machineFavorites = <FavoriteItem>[];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> toggleFavorite({
    required String userId,
    required String targetType,
    required String targetId,
    required String targetNameSnapshot,
    String? targetPhotoUrl,
  }) async {
    try {
      final bool alreadyFavorite = await _favoriteRepository.isFavorite(
        userId: userId,
        targetType: targetType,
        targetId: targetId,
      );

      if (alreadyFavorite) {
        await _favoriteRepository.removeFavorite(
          userId: userId,
          targetType: targetType,
          targetId: targetId,
        );
        await loadFavorites(userId);
        return false;
      }

      final String favoriteId = _favoriteRepository.buildFavoriteId(
        userId: userId,
        targetType: targetType,
        targetId: targetId,
      );

      await _favoriteRepository.saveFavorite(
        FavoriteItem(
          id: favoriteId,
          userId: userId,
          targetType: targetType,
          targetId: targetId,
          targetNameSnapshot: targetNameSnapshot,
          targetPhotoUrl: targetPhotoUrl,
          notifyEnabled: true,
          createdAt: DateTime.now(),
        ),
      );

      await loadFavorites(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> isFavorite({
    required String userId,
    required String targetType,
    required String targetId,
  }) {
    return _favoriteRepository.isFavorite(
      userId: userId,
      targetType: targetType,
      targetId: targetId,
    );
  }

  Future<void> updateNotifyEnabled({
    required String favoriteId,
    required bool enabled,
    required String userId,
  }) async {
    try {
      await _favoriteRepository.updateNotifyEnabled(
        favoriteId: favoriteId,
        enabled: enabled,
      );
      await loadFavorites(userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clear() {
    _productFavorites = <FavoriteItem>[];
    _machineFavorites = <FavoriteItem>[];
    _errorMessage = null;
    _selectedTabIndex = 0;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
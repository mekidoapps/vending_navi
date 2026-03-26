import 'package:flutter/foundation.dart';

import '../core/enums/app_enums.dart';
import '../repositories/local_search_repository.dart';
import '../repositories/search_repository.dart';
import '../services/location_service.dart';

class SearchProvider extends ChangeNotifier {
  SearchProvider({
    LocalSearchRepository? localSearchRepository,
    SearchRepository? searchRepository,
    LocationService? locationService,
  })  : _localSearchRepository =
      localSearchRepository ?? LocalSearchRepository(),
        _searchRepository = searchRepository,
        _locationService = locationService ?? LocationService();

  final LocalSearchRepository _localSearchRepository;
  final SearchRepository? _searchRepository;
  final LocationService _locationService;

  String _keyword = '';
  ProductCategory? _category;
  ItemTemperature? _temperatureFilter;
  SearchSortType _sortType = SearchSortType.nearest;
  bool _onlyFreshInfo = false;
  bool _isMapMode = false;
  bool _useLocalMode = true;

  bool _isLoading = false;
  String? _errorMessage;
  double? _currentLatitude;
  double? _currentLongitude;
  List<SearchResultItem> _results = <SearchResultItem>[];

  String get keyword => _keyword;
  ProductCategory? get category => _category;
  ItemTemperature? get temperatureFilter => _temperatureFilter;
  SearchSortType get sortType => _sortType;
  bool get onlyFreshInfo => _onlyFreshInfo;
  bool get isMapMode => _isMapMode;
  bool get isLoading => _isLoading;
  bool get useLocalMode => _useLocalMode;
  String? get errorMessage => _errorMessage;
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;
  List<SearchResultItem> get results =>
      List<SearchResultItem>.unmodifiable(_results);

  void setKeyword(String value) {
    _keyword = value;
    notifyListeners();
  }

  void setCategory(ProductCategory? value) {
    _category = value;
    notifyListeners();
  }

  void setTemperatureFilter(ItemTemperature? value) {
    _temperatureFilter = value;
    notifyListeners();
  }

  void setSortType(SearchSortType value) {
    _sortType = value;
    notifyListeners();
  }

  void setOnlyFreshInfo(bool value) {
    _onlyFreshInfo = value;
    notifyListeners();
  }

  void setMapMode(bool value) {
    _isMapMode = value;
    notifyListeners();
  }

  void toggleMapMode() {
    _isMapMode = !_isMapMode;
    notifyListeners();
  }

  void setUseLocalMode(bool value) {
    _useLocalMode = value;
    notifyListeners();
  }

  void clearFilters() {
    _category = null;
    _temperatureFilter = null;
    _sortType = SearchSortType.nearest;
    _onlyFreshInfo = false;
    notifyListeners();
  }

  Future<void> fetchCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> search() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (_currentLatitude == null || _currentLongitude == null) {
        await fetchCurrentLocation();
      }

      final List<SearchResultItem> fetched =
      await (_useLocalMode || _searchRepository == null
          ? _localSearchRepository.search(
        keyword: _keyword,
        category: _category,
        temperatureFilter: _temperatureFilter,
        currentLatitude: _currentLatitude,
        currentLongitude: _currentLongitude,
        sortType: _sortType,
      )
          : _searchRepository!.search(
        keyword: _keyword,
        category: _category,
        temperatureFilter: _temperatureFilter,
        currentLatitude: _currentLatitude,
        currentLongitude: _currentLongitude,
        sortType: _sortType,
      ));

      if (_onlyFreshInfo) {
        _results = fetched.where((SearchResultItem item) {
          final DateTime? lastSeenAt = item.lastSeenAt;
          if (lastSeenAt == null) return false;
          return DateTime.now().difference(lastSeenAt).inDays <= 7;
        }).toList();
      } else {
        _results = fetched;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _results = <SearchResultItem>[];
    } finally {
      _setLoading(false);
    }
  }

  void clearResults() {
    _results = <SearchResultItem>[];
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
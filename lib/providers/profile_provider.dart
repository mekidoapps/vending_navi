import 'package:flutter/foundation.dart';

import '../models/user_stats.dart';
import '../repositories/title_repository.dart';
import '../repositories/user_repository.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({
    UserRepository? userRepository,
    TitleRepository? titleRepository,
  })  : _userRepository = userRepository ?? UserRepository(),
        _titleRepository = titleRepository ?? TitleRepository();

  final UserRepository _userRepository;
  final TitleRepository _titleRepository;

  UserStats? _userStats;
  List<UserTitleItem> _userTitles = <UserTitleItem>[];
  bool _isLoading = false;
  String? _errorMessage;

  UserStats? get userStats => _userStats;
  List<UserTitleItem> get userTitles => List<UserTitleItem>.unmodifiable(_userTitles);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadProfile(String userId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _userStats = await _userRepository.fetchUserStats(userId);
      _userTitles = await _titleRepository.fetchUserTitles(userId: userId);
    } catch (e) {
      _errorMessage = e.toString();
      _userStats = null;
      _userTitles = <UserTitleItem>[];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh(String userId) async {
    await loadProfile(userId);
  }

  void clear() {
    _userStats = null;
    _userTitles = <UserTitleItem>[];
    _errorMessage = null;
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
import 'package:flutter/foundation.dart';

import '../repositories/title_repository.dart';
import '../services/progression_popup_service.dart';

class TitleProvider extends ChangeNotifier {
  TitleProvider({
    TitleRepository? titleRepository,
    ProgressionPopupService? popupService,
  })  : _titleRepository = titleRepository ?? TitleRepository(),
        _popupService = popupService ?? ProgressionPopupService();

  final TitleRepository _titleRepository;
  final ProgressionPopupService _popupService;

  List<TitleMasterItem> _titleMaster = <TitleMasterItem>[];
  List<UserTitleItem> _userTitles = <UserTitleItem>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<TitleMasterItem> get titleMaster =>
      List<TitleMasterItem>.unmodifiable(_titleMaster);
  List<UserTitleItem> get userTitles =>
      List<UserTitleItem>.unmodifiable(_userTitles);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTitles({
    required String userId,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _titleMaster = await _titleRepository.fetchTitleMaster();
      _userTitles = await _titleRepository.fetchUserTitles(userId: userId);
    } catch (e) {
      _errorMessage = e.toString();
      _titleMaster = <TitleMasterItem>[];
      _userTitles = <UserTitleItem>[];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> grantTitleIfNeeded({
    required String userId,
    required String titleId,
    bool showPopup = true,
  }) async {
    try {
      final bool alreadyHasTitle = await _titleRepository.hasTitle(
        userId: userId,
        titleId: titleId,
      );

      if (alreadyHasTitle) {
        return false;
      }

      await _titleRepository.grantTitle(
        userId: userId,
        titleId: titleId,
      );

      TitleMasterItem? title;
      for (final TitleMasterItem item in _titleMaster) {
        if (item.id == titleId) {
          title = item;
          break;
        }
      }

      if (showPopup && title != null) {
        _popupService.enqueue(
          title: title.name,
          subtitle: '称号を獲得しました',
        );
      }

      await loadTitles(userId: userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> equipTitle({
    required String userId,
    required String titleId,
  }) async {
    try {
      await _titleRepository.equipTitle(
        userId: userId,
        titleId: titleId,
      );
      await loadTitles(userId: userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  bool hasTitle(String titleId) {
    return _userTitles.any((UserTitleItem item) => item.titleId == titleId);
  }

  void clear() {
    _titleMaster = <TitleMasterItem>[];
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
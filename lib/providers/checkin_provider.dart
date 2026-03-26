import 'package:flutter/foundation.dart';

import '../core/enums/app_enums.dart';
import '../models/checkin.dart';
import '../repositories/checkin_repository.dart';
import '../services/location_service.dart';

class CheckinProvider extends ChangeNotifier {
  CheckinProvider({
    CheckinRepository? checkinRepository,
    LocationService? locationService,
  })  : _checkinRepository = checkinRepository ?? CheckinRepository(),
        _locationService = locationService ?? LocationService();

  final CheckinRepository _checkinRepository;
  final LocationService _locationService;

  String? _machineId;
  String? _productId;
  CheckinActionType? _actionType;
  String _reportedPriceText = '';
  String _comment = '';
  List<String> _photoPaths = <String>[];

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  String? get machineId => _machineId;
  String? get productId => _productId;
  CheckinActionType? get actionType => _actionType;
  String get reportedPriceText => _reportedPriceText;
  String get comment => _comment;
  List<String> get photoPaths => List<String>.unmodifiable(_photoPaths);
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void setMachineId(String value) {
    _machineId = value;
    notifyListeners();
  }

  void setProductId(String? value) {
    _productId = value;
    notifyListeners();
  }

  void setActionType(CheckinActionType? value) {
    _actionType = value;
    notifyListeners();
  }

  void setReportedPriceText(String value) {
    _reportedPriceText = value;
    notifyListeners();
  }

  void setComment(String value) {
    _comment = value;
    notifyListeners();
  }

  void setPhotoPaths(List<String> value) {
    _photoPaths = List<String>.from(value);
    notifyListeners();
  }

  void addPhotoPath(String path) {
    _photoPaths = <String>[..._photoPaths, path];
    notifyListeners();
  }

  void removePhotoPath(String path) {
    _photoPaths = _photoPaths.where((String e) => e != path).toList();
    notifyListeners();
  }

  bool validate() {
    if (_machineId == null || _machineId!.isEmpty) {
      _errorMessage = '自販機が選択されていません';
      notifyListeners();
      return false;
    }

    if (_actionType == null) {
      _errorMessage = 'チェックイン内容を選んでください';
      notifyListeners();
      return false;
    }

    if (_actionType == CheckinActionType.priceUpdate &&
        _reportedPriceText.trim().isEmpty) {
      _errorMessage = '価格を入力してください';
      notifyListeners();
      return false;
    }

    return true;
  }

  Future<bool> submit({
    required String userId,
  }) async {
    _errorMessage = null;
    _successMessage = null;

    if (!validate()) {
      return false;
    }

    _setSubmitting(true);

    try {
      final position = await _locationService.getCurrentPosition();
      final int? parsedPrice = int.tryParse(_reportedPriceText.trim());

      final Checkin checkin = Checkin(
        id: '',
        userId: userId,
        machineId: _machineId!,
        productId: _productId,
        actionType: _actionType!,
        reportedPrice: parsedPrice,
        comment: _comment.trim().isEmpty ? null : _comment.trim(),
        photoUrls: const <String>[],
        createdAt: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      await _checkinRepository.createCheckin(checkin);

      _successMessage = 'チェックインを保存しました';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  void initialize({
    required String machineId,
    String? productId,
  }) {
    _machineId = machineId;
    _productId = productId;
    _actionType = null;
    _reportedPriceText = '';
    _comment = '';
    _photoPaths = <String>[];
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void reset() {
    _machineId = null;
    _productId = null;
    _actionType = null;
    _reportedPriceText = '';
    _comment = '';
    _photoPaths = <String>[];
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }
}
import 'package:flutter/foundation.dart';

import '../models/vending_machine.dart';
import '../models/vending_machine_access.dart';
import '../repositories/machine_repository.dart';

class MachineProvider extends ChangeNotifier {
  MachineProvider({
    MachineRepository? machineRepository,
  }) : _machineRepository = machineRepository ?? MachineRepository();

  final MachineRepository _machineRepository;

  // --- 既存：自販機詳細 ---
  VendingMachine? _machine;
  List<VendingMachineAccess> _items = <VendingMachineAccess>[];
  String? _highlightProductId;

  // --- 追加：マップ用一覧 ---
  List<VendingMachine> _nearbyMachines = <VendingMachine>[];
  List<VendingMachine> get nearbyMachines =>
      List<VendingMachine>.unmodifiable(_nearbyMachines);

  bool _isLoading = false;
  String? _errorMessage;

  VendingMachine? get machine => _machine;
  List<VendingMachineAccess> get items =>
      List<VendingMachineAccess>.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get highlightProductId => _highlightProductId;

  // --- 追加：マップ用周辺自販機を読み込む ---
  Future<void> loadNearbyMachines({
    required double lat,
    required double lng,
    double radiusKm = 10.0,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final List<VendingMachine> all =
      await _machineRepository.fetchMachines(onlyActive: true);

      // クライアントサイドで距離フィルタ（簡易計算）
      _nearbyMachines = all.where((VendingMachine m) {
        final double dlat = m.latitude - lat;
        final double dlng = m.longitude - lng;
        final double distKm = ((dlat * dlat) + (dlng * dlng)) * 111.0;
        return distKm <= radiusKm * radiusKm;
      }).toList();
    } catch (e) {
      _errorMessage = e.toString();
      _nearbyMachines = <VendingMachine>[];
    } finally {
      _setLoading(false);
    }
  }

  // --- 既存：自販機詳細 ---
  Future<void> loadMachineDetail({
    required String machineId,
    String? highlightProductId,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    _highlightProductId = highlightProductId;

    try {
      final VendingMachine? fetchedMachine =
      await _machineRepository.fetchMachineById(machineId);

      if (fetchedMachine == null) {
        _machine = null;
        _items = <VendingMachineAccess>[];
        _errorMessage = '自販機が見つかりませんでした';
        return;
      }

      final List<VendingMachineAccess> fetchedItems =
      await _machineRepository.fetchMachineItemsByMachineId(machineId);

      _machine = fetchedMachine;
      _items = _sortItems(fetchedItems, highlightProductId);
    } catch (e) {
      _errorMessage = e.toString();
      _machine = null;
      _items = <VendingMachineAccess>[];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    final String? machineId = _machine?.id;
    if (machineId == null) return;

    await loadMachineDetail(
      machineId: machineId,
      highlightProductId: _highlightProductId,
    );
  }

  List<VendingMachineAccess> _sortItems(
      List<VendingMachineAccess> items,
      String? highlightProductId,
      ) {
    final List<VendingMachineAccess> copied =
    List<VendingMachineAccess>.from(items);

    copied.sort((VendingMachineAccess a, VendingMachineAccess b) {
      if (highlightProductId != null) {
        if (a.productId == highlightProductId &&
            b.productId != highlightProductId) return -1;
        if (a.productId != highlightProductId &&
            b.productId == highlightProductId) return 1;
      }

      final DateTime aDate =
          a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate =
          b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return copied;
  }

  void clear() {
    _machine = null;
    _items = <VendingMachineAccess>[];
    _highlightProductId = null;
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

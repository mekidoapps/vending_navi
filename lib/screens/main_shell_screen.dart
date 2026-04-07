import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/app_progress.dart';
import '../models/position_data.dart';
import '../models/vending_machine.dart';
import '../services/favorite_drink_service.dart';
import '../services/firestore_service.dart';
import '../services/local_progress_service.dart';
import '../services/nearby_favorite_notification_service.dart';
import '../utils/distance_util.dart';
import '../utils/freshness_util.dart';
import '../widgets/freshness_badge.dart';
import '../widgets/machine_freshness_badge.dart';
import 'login_screen.dart';
import 'machine_create_screen.dart';
import 'machine_detail_screen.dart';
import 'notification_settings_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    this.initialMachineId,
  });

  final String? initialMachineId;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<VendingMachine>>? _machinesSubscription;
  GoogleMapController? _mapController;

  bool _isLoadingMachines = true;
  bool _isLoadingProgress = true;
  bool _isLoadingLocation = true;

  int _currentTabIndex = 0;
  int _selectedMachineIndex = 0;

  String _selectedKeyword = '';
  String? _selectedProductFilter;
  String? _justCreatedMachineName;

  final List<String> _selectedTags = <String>[];

  List<VendingMachine> _liveMachines = <VendingMachine>[];
  List<String> _favoriteDrinks = <String>[];
  AppProgress _progress = AppProgress.initial();
  PositionData? _currentPosition;

  String? _pendingJumpMachineId;
  bool _hasHandledInitialJump = false;
  String? _pendingDetailMachineId;
  bool _hasOpenedPendingDetail = false;
  String? _highlightMachineId;

  bool _onlyFresh = false;

  final List<String> _quickCategories = <String>[
    'コーヒー',
    'お茶',
    '炭酸',
    '水',
  ];

  final List<String> _popularKeywords = <String>[
    'お〜いお茶',
    '綾鷹',
    'BOSS ブラック',
    'ジョージア',
    '午後の紅茶',
    '無糖',
    '炭酸',
  ];

  final List<String> _filterTags = <String>[
    '電子決済OK',
    '現金のみ',
    'ゴミ箱あり',
    '屋内',
    '屋外',
  ];

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;
  List<VendingMachine> get _sourceMachines => _liveMachines;

  String get _microCopy {
    if (_onlyFresh) {
      return '24時間以内に更新された自販機だけ表示中';
    }
    if (_selectedProductFilter != null &&
        _selectedProductFilter!.trim().isNotEmpty) {
      return '「$_selectedProductFilter」がある自販機を表示中';
    }
    if (_selectedKeyword.trim().isNotEmpty) {
      return '近くて新しい情報を優先表示';
    }
    if (_favoriteDrinks.isNotEmpty) {
      return 'お気に入り飲み物と最近確認を優先';
    }
    return '今飲みたいものを、近くて新しい情報から探す';
  }

  List<String> get _favoriteDrinkList {
    final displayNames = <String>[];
    final used = <String>{};

    for (final machine in _sourceMachines) {
      for (final product in _machineAllProducts(machine)) {
        final normalized = _normalize(product);
        if (_favoriteDrinks.contains(normalized) && !used.contains(normalized)) {
          used.add(normalized);
          displayNames.add(product);
        }
      }
    }

    if (displayNames.isEmpty && _favoriteDrinks.isNotEmpty) {
      displayNames.addAll(_favoriteDrinks);
    }

    return displayNames;
  }

  List<_MachineViewData> get _machineViews {
    final filtered = _sourceMachines.where((machine) {
      final keyword = _selectedKeyword.trim();
      final normalizedKeyword = _normalize(keyword);

      final matchesKeyword = keyword.isEmpty
          ? true
          : _matchesKeyword(machine, keyword, normalizedKeyword);

      final matchesProductFilter = _selectedProductFilter == null
          ? true
          : _machineHasProduct(machine, _selectedProductFilter!);

      final matchesTags = _selectedTags.isEmpty
          ? true
          : _selectedTags.every(machine.tags.contains);

      final freshness = FreshnessUtil.getLevel(machine.lastCheckedAt);
      final matchesFresh = !_onlyFresh ||
          freshness == FreshnessLevel.veryFresh ||
          freshness == FreshnessLevel.fresh;

      return matchesKeyword &&
          matchesProductFilter &&
          matchesTags &&
          matchesFresh;
    }).map(_toViewData).toList();

    filtered.sort((a, b) {
      if (a.hasFavoriteDrink && !b.hasFavoriteDrink) return -1;
      if (!a.hasFavoriteDrink && b.hasFavoriteDrink) return 1;

      if (_selectedProductFilter != null &&
          _selectedProductFilter!.trim().isNotEmpty) {
        final aHas = _machineHasProduct(a.machine, _selectedProductFilter!);
        final bHas = _machineHasProduct(b.machine, _selectedProductFilter!);
        if (aHas != bHas) {
          return aHas ? -1 : 1;
        }
      }

      final freshnessA = _freshnessRank(a.machine.updatedAt);
      final freshnessB = _freshnessRank(b.machine.updatedAt);
      if (freshnessA != freshnessB) {
        return freshnessA.compareTo(freshnessB);
      }

      final ad = a.distanceMeters ?? double.infinity;
      final bd = b.distanceMeters ?? double.infinity;
      final distanceCompare = ad.compareTo(bd);
      if (distanceCompare != 0) return distanceCompare;

      final updatedAtA = a.machine.updatedAt;
      final updatedAtB = b.machine.updatedAt;
      if (updatedAtA != null && updatedAtB != null) {
        return updatedAtB.compareTo(updatedAtA);
      }
      if (updatedAtA != null) return -1;
      if (updatedAtB != null) return 1;

      return a.machine.name.compareTo(b.machine.name);
    });

    return filtered;
  }

  int _freshnessRank(DateTime? updatedAt) {
    if (updatedAt == null) return 2;

    final diff = DateTime.now().difference(updatedAt).inDays;
    if (diff <= 7) return 0;
    if (diff <= 30) return 1;
    return 2;
  }

  List<_MachineViewData> get _searchResultPreviewViews {
    if (_selectedKeyword.trim().isEmpty &&
        (_selectedProductFilter == null ||
            _selectedProductFilter!.trim().isEmpty)) {
      return <_MachineViewData>[];
    }
    return _machineViews.take(6).toList();
  }

  _MachineViewData? get _selectedView {
    final views = _machineViews;
    if (views.isEmpty) return null;

    if (_selectedMachineIndex < 0 || _selectedMachineIndex >= views.length) {
      return views.first;
    }

    return views[_selectedMachineIndex];
  }

  List<_SuggestionItem> get _suggestions {
    final keyword = _searchController.text.trim();

    if (keyword.isEmpty) {
      return _favoriteDrinkList.take(10).map((e) {
        return _SuggestionItem(
          text: e,
          type: SuggestionType.product,
        );
      }).toList();
    }

    final normalized = _normalize(keyword);
    final exact = <_SuggestionItem>[];
    final partial = <_SuggestionItem>[];
    final seen = <String>{};

    for (final machine in _sourceMachines) {
      final machineName = machine.name.trim();
      final normalizedMachineName = _normalize(machineName);

      if (!seen.contains('m:${machine.id}') &&
          normalizedMachineName.startsWith(normalized)) {
        exact.add(
          _SuggestionItem(
            text: machineName,
            type: SuggestionType.machine,
            machineId: machine.id,
          ),
        );
        seen.add('m:${machine.id}');
      } else if (!seen.contains('m:${machine.id}') &&
          normalizedMachineName.contains(normalized)) {
        partial.add(
          _SuggestionItem(
            text: machineName,
            type: SuggestionType.machine,
            machineId: machine.id,
          ),
        );
        seen.add('m:${machine.id}');
      }

      for (final product in _machineAllProducts(machine)) {
        final p = product.trim();
        final np = _normalize(p);
        final key = 'p:$p';

        if (seen.contains(key)) continue;

        if (np.startsWith(normalized)) {
          exact.add(
            _SuggestionItem(
              text: p,
              type: SuggestionType.product,
            ),
          );
          seen.add(key);
        } else if (np.contains(normalized)) {
          partial.add(
            _SuggestionItem(
              text: p,
              type: SuggestionType.product,
            ),
          );
          seen.add(key);
        }
      }
    }

    return <_SuggestionItem>[...exact, ...partial].take(12).toList();
  }

  @override
  void initState() {
    super.initState();

    final pendingMachineId =
    NearbyFavoriteNotificationService.consumePendingMachineId();

    _pendingJumpMachineId = pendingMachineId ?? widget.initialMachineId;
    _pendingDetailMachineId = pendingMachineId ?? widget.initialMachineId;

    _loadInitialData();
    _listenMachines();
  }

  @override
  void dispose() {
    _machinesSubscription?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }

  List<String> _machineAllProducts(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final slot in machine.drinkSlots) {
      final name = (slot['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final key = _normalize(name);
      if (used.contains(key)) continue;
      used.add(key);
      result.add(name);
    }

    return result;
  }

  bool _machineHasProduct(VendingMachine machine, String keyword) {
    final normalizedKeyword = _normalize(keyword);

    for (final product in _machineAllProducts(machine)) {
      if (_normalize(product).contains(normalizedKeyword)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadInitialData() async {
    await Future.wait<void>(<Future<void>>[
      _loadProgress(),
      _loadFavoriteDrinks(),
      _loadCurrentLocation(),
    ]);
  }

  Future<void> _loadProgress() async {
    final loaded = await LocalProgressService.load();
    if (!mounted) return;

    setState(() {
      _progress = loaded;
      _isLoadingProgress = false;
    });
  }

  Future<void> _loadFavoriteDrinks() async {
    final loaded = await FavoriteDrinkService.load();
    if (!mounted) return;

    setState(() {
      _favoriteDrinks = loaded.map((e) => _normalize(e)).toList();
    });

    await _checkNearbyFavoriteNotification();
  }

  Future<void> _loadCurrentLocation() async {
    final position = await DistanceUtil.getCurrentPositionSafe();
    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _isLoadingLocation = false;
    });

    await _checkNearbyFavoriteNotification();
  }

  Future<void> _checkNearbyFavoriteNotification() async {
    await NearbyFavoriteNotificationService.checkAndNotify(
      currentPosition: _currentPosition,
      machines: _liveMachines,
      favoriteDrinks: _favoriteDrinks,
    );
  }

  Future<void> _tryJumpToInitialMachine() async {
    if (_hasHandledInitialJump) return;
    if (_pendingJumpMachineId == null || _pendingJumpMachineId!.isEmpty) return;
    if (_liveMachines.isEmpty) return;

    final targetId = _pendingJumpMachineId!;
    final views = _machineViews;
    if (views.isEmpty) return;

    final index = views.indexWhere((view) => view.machine.id == targetId);
    if (index == -1) return;

    setState(() {
      _currentTabIndex = 0;
      _selectedMachineIndex = index;
      _highlightMachineId = targetId;
    });

    _hasHandledInitialJump = true;
    _pendingJumpMachineId = null;

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _moveCameraToSelectedMachine(animated: true);

    Future<void>.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      if (_highlightMachineId == targetId) {
        setState(() {
          _highlightMachineId = null;
        });
      }
    });
  }

  Future<void> _tryOpenPendingMachineDetail() async {
    if (_hasOpenedPendingDetail) return;
    if (_pendingDetailMachineId == null || _pendingDetailMachineId!.isEmpty) {
      return;
    }
    if (_liveMachines.isEmpty) return;

    final targetId = _pendingDetailMachineId!;
    final views = _machineViews;
    if (views.isEmpty) return;

    final index = views.indexWhere((view) => view.machine.id == targetId);
    if (index == -1) return;

    final targetView = views[index];

    setState(() {
      _currentTabIndex = 0;
      _selectedMachineIndex = index;
      _highlightMachineId = targetId;
    });

    _hasOpenedPendingDetail = true;
    _pendingDetailMachineId = null;

    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _moveCameraToSelectedMachine(animated: true);

    if (!mounted) return;

    final updated = await LocalProgressService.addViewedMachine(
      machineId: targetView.machine.id,
      machineName: targetView.machine.name,
    );

    if (mounted) {
      setState(() {
        _progress = updated;
      });
    }

    if (!mounted) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MachineDetailScreen(machine: targetView.machine),
      ),
    );

    if (changed == true) {
      _listenMachines();
    }

    await _loadProgress();
  }

  void _listenMachines() {
    _machinesSubscription?.cancel();

    _machinesSubscription = FirestoreService.instance.watchMachines().listen(
          (items) async {
        if (!mounted) return;

        setState(() {
          _liveMachines = items;
          _isLoadingMachines = false;

          final views = _machineViews;
          if (_selectedMachineIndex >= views.length) {
            _selectedMachineIndex = 0;
          }
        });

        await _checkNearbyFavoriteNotification();
        await _tryJumpToInitialMachine();
        await _tryOpenPendingMachineDetail();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveCameraToSelectedMachine(animated: false);
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _liveMachines = <VendingMachine>[];
          _isLoadingMachines = false;
        });
      },
    );
  }

  bool _matchesKeyword(
      VendingMachine machine,
      String keyword,
      String normalizedKeyword,
      ) {
    if (normalizedKeyword.isEmpty) return true;

    final name = _normalize(machine.name);
    if (name.contains(normalizedKeyword)) return true;

    for (final product in _machineAllProducts(machine)) {
      if (_normalize(product).contains(normalizedKeyword)) {
        return true;
      }
    }

    for (final tag in machine.tags) {
      if (_normalize(tag).contains(normalizedKeyword)) {
        return true;
      }
    }

    return false;
  }

  _MachineViewData _toViewData(VendingMachine machine) {
    final distanceMeters = DistanceUtil.calculateDistanceMeters(
      fromLat: _currentPosition?.latitude,
      fromLng: _currentPosition?.longitude,
      toLat: machine.latitude,
      toLng: machine.longitude,
    );

    final hasFavoriteDrink = _machineAllProducts(machine).any(
          (product) => _favoriteDrinks.contains(_normalize(product)),
    );

    return _MachineViewData(
      machine: machine,
      distanceMeters: distanceMeters.isFinite ? distanceMeters : null,
      hasFavoriteDrink: hasFavoriteDrink,
    );
  }

  Future<void> _applySearch(String keyword) async {
    final normalized = keyword.trim();

    setState(() {
      _selectedKeyword = normalized;
      _selectedProductFilter = normalized.isEmpty ? null : normalized;
      _selectedMachineIndex = 0;
      _searchController.text = normalized;
      _highlightMachineId = null;
    });

    if (normalized.isNotEmpty) {
      final updated = await LocalProgressService.addSearchHistory(normalized);
      if (!mounted) return;
      setState(() {
        _progress = updated;
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _moveCameraToSelectedMachine(animated: true);
  }

  Future<void> _onSuggestionTap(_SuggestionItem item) async {
    if (item.type == SuggestionType.machine && item.machineId != null) {
      setState(() {
        _selectedKeyword = item.text;
        _selectedProductFilter = null;
        _searchController.text = item.text;
        _highlightMachineId = null;
      });

      final index =
      _machineViews.indexWhere((v) => v.machine.id == item.machineId);

      if (index != -1) {
        setState(() {
          _selectedMachineIndex = index;
        });

        await _moveCameraToSelectedMachine(animated: true);
        return;
      }
    }

    await _applySearch(item.text);
  }

  void _clearSearch() {
    setState(() {
      _selectedKeyword = '';
      _selectedProductFilter = null;
      _selectedMachineIndex = 0;
      _searchController.clear();
      _highlightMachineId = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraToCurrentLocation(animated: true);
    });
  }

  Future<void> _applyProductFilter(String productName) async {
    setState(() {
      _selectedProductFilter = productName;
      _selectedKeyword = productName;
      _searchController.text = productName;
      _selectedMachineIndex = 0;
      _highlightMachineId = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _moveCameraToSelectedMachine(animated: true);
  }

  Future<void> _clearProductFilter() async {
    setState(() {
      _selectedProductFilter = null;
      _selectedKeyword = '';
      _searchController.clear();
      _selectedMachineIndex = 0;
      _highlightMachineId = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _moveCameraToSelectedMachine(animated: true);
  }

  Future<void> _applyTags(List<String> tags) async {
    setState(() {
      _selectedTags
        ..clear()
        ..addAll(tags);
      _selectedMachineIndex = 0;
      _highlightMachineId = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _moveCameraToSelectedMachine(animated: true);
  }

  Future<void> _toggleDrinkFavorite(String drinkName) async {
    await FavoriteDrinkService.toggle(drinkName);
    final loaded = await FavoriteDrinkService.load();

    if (!mounted) return;

    setState(() {
      _favoriteDrinks = loaded.map((e) => _normalize(e)).toList();
    });

    await _checkNearbyFavoriteNotification();
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showLoginRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ログインが必要です'),
          content: const Text(
            '自販機の登録はログイン後に使えます。\n閲覧や検索はそのまま使えます。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openLogin();
              },
              child: const Text('ログインへ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreate() async {
    if (!_isLoggedIn) {
      await _showLoginRequiredDialog();
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const MachineCreateScreen(),
      ),
    );

    if (result != true) return;

    _listenMachines();
  }

  Future<void> _selectMachineFromList(int index) async {
    setState(() {
      _selectedMachineIndex = index;
      _highlightMachineId = null;
    });

    await _moveCameraToSelectedMachine(animated: true);
  }

  Future<void> _selectMachineFromSearchPreview(_MachineViewData view) async {
    final views = _machineViews;
    final targetIndex =
    views.indexWhere((item) => item.machine.id == view.machine.id);

    if (targetIndex == -1) {
      await _openDetail(view);
      return;
    }

    setState(() {
      _selectedMachineIndex = targetIndex;
      _highlightMachineId = null;
    });

    await _moveCameraToSelectedMachine(animated: true);
  }

  Future<void> _openDetail(_MachineViewData view) async {
    final updated = await LocalProgressService.addViewedMachine(
      machineId: view.machine.id,
      machineName: view.machine.name,
    );

    if (!mounted) return;

    setState(() {
      _progress = updated;
    });

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MachineDetailScreen(machine: view.machine),
      ),
    );

    if (changed == true) {
      _listenMachines();
    }

    await _loadProgress();
  }

  Future<void> _moveCameraToCurrentLocation({required bool animated}) async {
    final controller = _mapController;
    final position = _currentPosition;
    if (controller == null || position == null) return;

    final update = CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 15.6,
      ),
    );

    if (animated) {
      await controller.animateCamera(update);
    } else {
      await controller.moveCamera(update);
    }
  }

  Future<void> _moveCameraToSelectedMachine({required bool animated}) async {
    final controller = _mapController;
    final selected = _selectedView;
    if (controller == null || selected == null) return;

    final update = CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(selected.machine.latitude, selected.machine.longitude),
        zoom: 15.2,
      ),
    );

    if (animated) {
      await controller.animateCamera(update);
    } else {
      await controller.moveCamera(update);
    }
  }

  CameraPosition get _initialCameraPosition {
    if (_currentPosition != null) {
      return CameraPosition(
        target: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        zoom: 15.6,
      );
    }

    final selected = _selectedView;
    if (selected != null) {
      return CameraPosition(
        target: LatLng(
          selected.machine.latitude,
          selected.machine.longitude,
        ),
        zoom: 15.0,
      );
    }

    return const CameraPosition(
      target: LatLng(35.681236, 139.767125),
      zoom: 14,
    );
  }

  Set<Marker> get _markers {
    final views = _machineViews;
    final markers = <Marker>{};

    for (final entry in views.asMap().entries) {
      final index = entry.key;
      final view = entry.value;
      final machine = view.machine;

      final isSelected = index == _selectedMachineIndex;
      final isHighlighted = machine.id == _highlightMachineId;
      final level = FreshnessUtil.getLevel(machine.lastCheckedAt);

      double hue = 210.0;
      if (isHighlighted) {
        hue = BitmapDescriptor.hueRose;
      } else if (isSelected) {
        hue = BitmapDescriptor.hueAzure;
      } else {
        switch (level) {
          case FreshnessLevel.veryFresh:
            hue = BitmapDescriptor.hueGreen;
            break;
          case FreshnessLevel.fresh:
            hue = BitmapDescriptor.hueAzure;
            break;
          case FreshnessLevel.normal:
            hue = BitmapDescriptor.hueOrange;
            break;
          case FreshnessLevel.old:
          case FreshnessLevel.unknown:
            hue = 210.0;
            break;
        }
      }

      markers.add(
        Marker(
          markerId: MarkerId(machine.id),
          position: LatLng(machine.latitude, machine.longitude),
          onTap: () async {
            await _selectMachineFromList(index);
          },
          zIndex: isHighlighted ? 3 : (isSelected ? 2 : 1),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: isHighlighted ? '通知対象: ${machine.name}' : machine.name,
            snippet: _machineAllProducts(machine).take(2).join(' / '),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        _isLoadingMachines || _isLoadingProgress || _isLoadingLocation;
    final selected = _selectedView;

    return Scaffold(
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: Icon(
          _isLoggedIn ? Icons.add_business_rounded : Icons.lock_rounded,
        ),
        label: Text(_isLoggedIn ? '登録する' : 'ログインで登録'),
      )
          : null,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: <Widget>[
            _TopSearchBar(
              controller: _searchController,
              microCopy: _microCopy,
              selectedTagsCount: _selectedTags.length,
              hasProductFilter: _selectedProductFilter != null,
              onlyFresh: _onlyFresh,
              suggestions: _suggestions,
              onSubmitted: _applySearch,
              onSuggestionTap: _onSuggestionTap,
              onClear: _clearSearch,
              onOpenSearchSheet: _openSearchSheet,
              onOpenFilterSheet: _openFilterSheet,
              onClearProductFilter: _clearProductFilter,
              onToggleOnlyFresh: () {
                setState(() {
                  _onlyFresh = !_onlyFresh;
                  _selectedMachineIndex = 0;
                });
              },
            ),
            if (_searchResultPreviewViews.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _SearchResultPreviewList(
                  results: _searchResultPreviewViews,
                  onTapMap: _selectMachineFromSearchPreview,
                  onTapDetail: _openDetail,
                ),
              ),
            Expanded(
              child: _MainBodyLayout(
                currentTabIndex: _currentTabIndex,
                onTabSelected: (index) {
                  setState(() {
                    _currentTabIndex = index;
                  });
                },
                mapSection: _currentTabIndex == 0
                    ? _MapSection(
                  initialCameraPosition: _initialCameraPosition,
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) async {
                      await _tryJumpToInitialMachine();
                      await _tryOpenPendingMachineDetail();
                      await _moveCameraToSelectedMachine(
                        animated: false,
                      );
                    });
                  },
                  onMoveToCurrentLocation: () {
                    _moveCameraToCurrentLocation(animated: true);
                  },
                )
                    : null,
                panelChild: _buildPanelChild(selected),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelChild(_MachineViewData? selected) {
    if (_currentTabIndex == 0) {
      if (selected == null) {
        return const _EmptyState(
          icon: Icons.search_off_rounded,
          title: '見つかりませんでした',
          message: 'まだ自販機データがありません。',
        );
      }

      return _HomePanelContent(
        selectedView: selected,
        machineViews: _machineViews,
        selectedMachineIndex: _selectedMachineIndex,
        justCreatedMachineName: _justCreatedMachineName,
        favoriteDrinks: _favoriteDrinks,
        highlightedMachineId: _highlightMachineId,
        onOpenDetail: _openDetail,
        onOpenCreate: _openCreate,
        onSelectMachine: _selectMachineFromList,
        onToggleDrinkFavorite: _toggleDrinkFavorite,
        onApplyProductFilter: _applyProductFilter,
      );
    }

    if (_currentTabIndex == 1) {
      return _FavoriteDrinkPanel(
        favoriteDrinks: _favoriteDrinkList,
        onTapDrink: _applySearch,
        onRemoveDrink: _toggleDrinkFavorite,
      );
    }

    return _ProfilePanel(
      progress: _progress,
      favoriteDrinks: _favoriteDrinkList,
      onOpenLogin: _openLogin,
      isLoggedIn: _isLoggedIn,
      onOpenNotificationSettings: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationSettingsScreen(),
          ),
        );
      },
    );
  }

  Future<void> _openSearchSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _SearchOptionsSheet(
          searchHistory: _progress.searchHistory,
          favoriteDrinks: _favoriteDrinkList,
          suggestions: _suggestions,
          popularKeywords: _popularKeywords,
          quickCategories: _quickCategories,
          onClearHistory: _clearSearchHistory,
        );
      },
    );

    if (selected != null && selected.trim().isNotEmpty) {
      await _applySearch(selected);
    }
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final tempSelected = List<String>.from(_selectedTags);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return _FilterSheet(
              filterTags: _filterTags,
              selectedTags: tempSelected,
              onToggle: (tag) {
                setModalState(() {
                  if (tempSelected.contains(tag)) {
                    tempSelected.remove(tag);
                  } else {
                    tempSelected.add(tag);
                  }
                });
              },
              onClear: () {
                setModalState(() {
                  tempSelected.clear();
                });
              },
              onApply: () async {
                Navigator.of(context).pop();
                await _applyTags(tempSelected);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _clearSearchHistory() async {
    final updated = await LocalProgressService.clearSearchHistory();
    if (!mounted) return;

    setState(() {
      _progress = updated;
    });
  }
}

class _MachineViewData {
  const _MachineViewData({
    required this.machine,
    required this.distanceMeters,
    required this.hasFavoriteDrink,
  });

  final VendingMachine machine;
  final double? distanceMeters;
  final bool hasFavoriteDrink;
}

class _SuggestionItem {
  final String text;
  final SuggestionType type;
  final String? machineId;

  _SuggestionItem({
    required this.text,
    required this.type,
    this.machineId,
  });
}

enum SuggestionType {
  product,
  machine,
}

class _TopSearchBar extends StatelessWidget {
  const _TopSearchBar({
    required this.controller,
    required this.microCopy,
    required this.selectedTagsCount,
    required this.hasProductFilter,
    required this.onlyFresh,
    required this.suggestions,
    required this.onSubmitted,
    required this.onSuggestionTap,
    required this.onClear,
    required this.onOpenSearchSheet,
    required this.onOpenFilterSheet,
    required this.onClearProductFilter,
    required this.onToggleOnlyFresh,
  });

  final TextEditingController controller;
  final String microCopy;
  final int selectedTagsCount;
  final bool hasProductFilter;
  final bool onlyFresh;
  final List<_SuggestionItem> suggestions;
  final Future<void> Function(String value) onSubmitted;
  final Future<void> Function(_SuggestionItem item) onSuggestionTap;
  final VoidCallback onClear;
  final VoidCallback onOpenSearchSheet;
  final VoidCallback onOpenFilterSheet;
  final Future<void> Function() onClearProductFilter;
  final VoidCallback onToggleOnlyFresh;

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }

  Widget _highlightText(String text, String keyword) {
    final normalizedText = _normalize(text);
    final normalizedKeyword = _normalize(keyword);

    if (normalizedKeyword.isEmpty ||
        !normalizedText.contains(normalizedKeyword)) {
      return Text(
        text,
        style: const TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      );
    }

    final start = normalizedText.indexOf(normalizedKeyword);
    if (start < 0) {
      return Text(
        text,
        style: const TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      );
    }

    final end = start + normalizedKeyword.length;
    if (end > text.length) {
      return Text(
        text,
        style: const TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        children: <InlineSpan>[
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.trim().isNotEmpty;
    final showInlineSuggestions = suggestions.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: onSubmitted,
                  style: const TextStyle(
                    fontFamily: 'Noto Sans JP',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2A30),
                  ),
                  cursorColor: Theme.of(context).colorScheme.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '飲みたいドリンクで探す',
                    hintStyle: const TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 14,
                      color: Color(0xFF7A8791),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: hasQuery
                        ? IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderButton(
                icon: Icons.expand_more_rounded,
                label: '候補',
                onTap: onOpenSearchSheet,
              ),
              const SizedBox(width: 8),
              _HeaderButton(
                icon: Icons.tune_rounded,
                label: selectedTagsCount > 0 ? '絞込$selectedTagsCount' : '絞込',
                onTap: onOpenFilterSheet,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: onToggleOnlyFresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: onlyFresh
                        ? const Color(0xFF2ECC71)
                        : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '今飲める',
                    style: TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: onlyFresh ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  microCopy,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (hasProductFilter)
                TextButton(
                  onPressed: onClearProductFilter,
                  child: const Text('解除'),
                ),
            ],
          ),
          if (showInlineSuggestions) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final item = suggestions[index];

                  return ActionChip(
                    avatar: Icon(
                      item.type == SuggestionType.product
                          ? Icons.local_drink_rounded
                          : Icons.location_on_rounded,
                      size: 16,
                    ),
                    label: _highlightText(
                      item.text,
                      controller.text,
                    ),
                    onPressed: () => onSuggestionTap(item),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: const Color(0xFF334148)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334148),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchOptionsSheet extends StatefulWidget {
  const _SearchOptionsSheet({
    required this.searchHistory,
    required this.favoriteDrinks,
    required this.suggestions,
    required this.popularKeywords,
    required this.quickCategories,
    required this.onClearHistory,
  });

  final List<String> searchHistory;
  final List<String> favoriteDrinks;
  final List<_SuggestionItem> suggestions;
  final List<String> popularKeywords;
  final List<String> quickCategories;
  final Future<void> Function() onClearHistory;

  @override
  State<_SearchOptionsSheet> createState() => _SearchOptionsSheetState();
}

class _SearchOptionsSheetState extends State<_SearchOptionsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _sheetSearchController = TextEditingController();
  String _sheetQuery = '';

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sheetSearchController.dispose();
    super.dispose();
  }

  List<String> _filterStringItems(List<String> items) {
    if (_sheetQuery.trim().isEmpty) return items;
    return items
        .where((item) => _normalize(item).contains(_normalize(_sheetQuery)))
        .toList();
  }

  List<_SuggestionItem> _filterSuggestionItems(List<_SuggestionItem> items) {
    if (_sheetQuery.trim().isEmpty) return items;
    return items
        .where((item) => _normalize(item.text).contains(_normalize(_sheetQuery)))
        .toList();
  }

  Widget _buildFavoriteTab() {
    final items = _filterStringItems(widget.favoriteDrinks);

    if (items.isEmpty) {
      return const _SearchSheetEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'お気に入り飲み物はまだありません',
        message: '商品名のハートを押すと、ここに出ます。',
      );
    }

    return SingleChildScrollView(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          return _SearchChipCard(
            icon: Icons.local_drink_rounded,
            label: item,
            onTap: () => Navigator.of(context).pop(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final items = _filterStringItems(widget.searchHistory);

    if (items.isEmpty) {
      return const _SearchSheetEmptyState(
        icon: Icons.history_rounded,
        title: '最近の検索はまだありません',
        message: '検索すると、ここに履歴が残ります。',
      );
    }

    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              await widget.onClearHistory();
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('履歴を消す'),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return _SearchHistoryTile(
                label: item,
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularTab() {
    final merged = <String>[
      ...widget.popularKeywords,
      ...widget.suggestions
          .where((e) => e.type == SuggestionType.product)
          .map((e) => e.text),
    ].toSet().toList();

    final items = _filterStringItems(merged);

    if (items.isEmpty) {
      return const _SearchSheetEmptyState(
        icon: Icons.local_fire_department_rounded,
        title: '人気候補がありません',
        message: '候補が見つかりませんでした。',
      );
    }

    return SingleChildScrollView(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          return _PopularWordCard(
            label: item,
            onTap: () => Navigator.of(context).pop(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryTab() {
    final items = _filterStringItems(widget.quickCategories);

    if (items.isEmpty) {
      return const _SearchSheetEmptyState(
        icon: Icons.category_rounded,
        title: 'カテゴリがありません',
        message: '一致するカテゴリがありません。',
      );
    }

    return GridView.builder(
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _CategoryCard(
          label: item,
          onTap: () => Navigator.of(context).pop(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestionItems = _filterSuggestionItems(widget.suggestions);

    return _SheetFrame(
      title: '検索候補',
      child: Column(
        children: <Widget>[
          TextField(
            controller: _sheetSearchController,
            onChanged: (value) {
              setState(() {
                _sheetQuery = value;
              });
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: '候補を絞り込む',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (suggestionItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestionItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final item = suggestionItems[index];
                  return ActionChip(
                    avatar: Icon(
                      item.type == SuggestionType.product
                          ? Icons.local_drink_rounded
                          : Icons.location_on_rounded,
                      size: 16,
                    ),
                    label: Text(item.text),
                    onPressed: () => Navigator.of(context).pop(item.text),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const <Widget>[
              Tab(text: 'お気に入り'),
              Tab(text: '最近'),
              Tab(text: '人気'),
              Tab(text: 'カテゴリ'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildFavoriteTab(),
                _buildHistoryTab(),
                _buildPopularTab(),
                _buildCategoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchChipCard extends StatelessWidget {
  const _SearchChipCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: const Color(0xFF60707A)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334148),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHistoryTile extends StatelessWidget {
  const _SearchHistoryTile({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.history_rounded, color: Color(0xFF60707A)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Noto Sans JP',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334148),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF60707A)),
          ],
        ),
      ),
    );
  }
}

class _PopularWordCard extends StatelessWidget {
  const _PopularWordCard({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7EF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD8B6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: Color(0xFFCC7A00),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A5A00),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  IconData _iconFor(String label) {
    switch (label) {
      case 'コーヒー':
        return Icons.coffee_rounded;
      case 'お茶':
        return Icons.emoji_food_beverage_rounded;
      case '炭酸':
        return Icons.bubble_chart_rounded;
      case '水':
        return Icons.water_drop_rounded;
      default:
        return Icons.local_drink_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(_iconFor(label), size: 18, color: const Color(0xFF60707A)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334148),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSheetEmptyState extends StatelessWidget {
  const _SearchSheetEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 34, color: const Color(0xFF60707A)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334148),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 13,
                color: Color(0xFF60707A),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultPreviewList extends StatelessWidget {
  const _SearchResultPreviewList({
    required this.results,
    required this.onTapMap,
    required this.onTapDetail,
  });

  final List<_MachineViewData> results;
  final Future<void> Function(_MachineViewData view) onTapMap;
  final Future<void> Function(_MachineViewData view) onTapDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '検索結果',
            style: TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          const SizedBox(height: 8),
          ...results.map((view) {
            final products = view.machine.drinkSlots
                .map((e) => (e['name'] ?? '').toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FBFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E7EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SearchPreviewThumbnail(imageUrl: view.machine.imageUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.place_rounded, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  view.machine.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Noto Sans JP',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: MachineFreshnessBadge(
                              updatedAt: view.machine.updatedAt,
                              compact: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (products.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                products.take(3).join(' / '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Noto Sans JP',
                                  fontSize: 12,
                                  color: Color(0xFF60707A),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => onTapMap(view),
                                  icon: const Icon(Icons.map_rounded),
                                  label: const Text('地図で見る'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => onTapDetail(view),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: const Text('詳細'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SearchPreviewThumbnail extends StatelessWidget {
  const _SearchPreviewThumbnail({
    required this.imageUrl,
  });

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: hasImage
            ? Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _SearchPreviewFallback(),
        )
            : const _SearchPreviewFallback(),
      ),
    );
  }
}

class _SearchPreviewFallback extends StatelessWidget {
  const _SearchPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.local_drink_rounded,
        color: Color(0xFF7A8791),
      ),
    );
  }
}

class _MainBodyLayout extends StatelessWidget {
  const _MainBodyLayout({
    required this.currentTabIndex,
    required this.onTabSelected,
    required this.mapSection,
    required this.panelChild,
  });

  final int currentTabIndex;
  final ValueChanged<int> onTabSelected;
  final Widget? mapSection;
  final Widget panelChild;

  @override
  Widget build(BuildContext context) {
    final showMap = currentTabIndex == 0;

    return Column(
      children: <Widget>[
        if (showMap && mapSection != null)
          Flexible(
            flex: 38,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: mapSection!,
            ),
          ),
        Flexible(
          flex: showMap ? 62 : 100,
          child: _BottomScaffoldPanel(
            currentTabIndex: currentTabIndex,
            onTabSelected: onTabSelected,
            child: panelChild,
          ),
        ),
      ],
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({
    required this.initialCameraPosition,
    required this.markers,
    required this.onMapCreated,
    required this.onMoveToCurrentLocation,
  });

  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final ValueChanged<GoogleMapController> onMapCreated;
  final VoidCallback onMoveToCurrentLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: initialCameraPosition,
                onMapCreated: onMapCreated,
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                buildingsEnabled: true,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: FilledButton.tonalIcon(
                onPressed: onMoveToCurrentLocation,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('現在地'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomScaffoldPanel extends StatelessWidget {
  const _BottomScaffoldPanel({
    required this.currentTabIndex,
    required this.onTabSelected,
    required this.child,
  });

  final int currentTabIndex;
  final ValueChanged<int> onTabSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const tabs = <({IconData icon, String label})>[
      (icon: Icons.map_rounded, label: 'マップ'),
      (icon: Icons.favorite_rounded, label: 'お気に入り'),
      (icon: Icons.person_rounded, label: 'マイページ'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 64,
            child: Row(
              children: List<Widget>.generate(tabs.length, (index) {
                final tab = tabs[index];
                final selected = currentTabIndex == index;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == tabs.length - 1 ? 0 : 8,
                    ),
                    child: InkWell(
                      onTap: () => onTabSelected(index),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0xFFF4F6F8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              tab.icon,
                              size: 22,
                              color: selected ? Colors.white : Colors.black54,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontFamily: 'Noto Sans JP',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color:
                                selected ? Colors.white : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _HomePanelContent extends StatelessWidget {
  const _HomePanelContent({
    required this.selectedView,
    required this.machineViews,
    required this.selectedMachineIndex,
    required this.justCreatedMachineName,
    required this.favoriteDrinks,
    required this.highlightedMachineId,
    required this.onOpenDetail,
    required this.onOpenCreate,
    required this.onSelectMachine,
    required this.onToggleDrinkFavorite,
    required this.onApplyProductFilter,
  });

  final _MachineViewData selectedView;
  final List<_MachineViewData> machineViews;
  final int selectedMachineIndex;
  final String? justCreatedMachineName;
  final List<String> favoriteDrinks;
  final String? highlightedMachineId;
  final Future<void> Function(_MachineViewData view) onOpenDetail;
  final Future<void> Function() onOpenCreate;
  final Future<void> Function(int index) onSelectMachine;
  final Future<void> Function(String drinkName) onToggleDrinkFavorite;
  final Future<void> Function(String productName) onApplyProductFilter;

  @override
  Widget build(BuildContext context) {
    final visibleMachines = machineViews.take(5).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '近くの自販機',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _SelectedMachineCard(
            view: selectedView,
            justCreatedMachineName: justCreatedMachineName,
            favoriteDrinks: favoriteDrinks,
            isHighlighted: selectedView.machine.id == highlightedMachineId,
            onOpenDetail: () => onOpenDetail(selectedView),
            onToggleDrinkFavorite: onToggleDrinkFavorite,
            onApplyProductFilter: onApplyProductFilter,
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onOpenCreate,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7EF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFD8B6)),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.add_business_rounded),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '自販機を登録する',
                      style: TextStyle(
                        fontFamily: 'Noto Sans JP',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '近い順',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...List<Widget>.generate(visibleMachines.length, (index) {
            final view = visibleMachines[index];
            final isSelected = index == selectedMachineIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MachineListTile(
                view: view,
                isSelected: isSelected,
                isNew: view.machine.name == justCreatedMachineName,
                isHighlighted: view.machine.id == highlightedMachineId,
                onTap: () => onSelectMachine(index),
                onLongPress: () => onOpenDetail(view),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SelectedMachineCard extends StatelessWidget {
  const _SelectedMachineCard({
    required this.view,
    required this.justCreatedMachineName,
    required this.favoriteDrinks,
    required this.isHighlighted,
    required this.onOpenDetail,
    required this.onToggleDrinkFavorite,
    required this.onApplyProductFilter,
  });

  final _MachineViewData view;
  final String? justCreatedMachineName;
  final List<String> favoriteDrinks;
  final bool isHighlighted;
  final VoidCallback onOpenDetail;
  final Future<void> Function(String drinkName) onToggleDrinkFavorite;
  final Future<void> Function(String productName) onApplyProductFilter;

  String _normalize(String input) => input.trim().toLowerCase();

  List<String> _machineDisplayProducts(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final slot in machine.drinkSlots) {
      final name = (slot['name'] ?? '').toString().trim();
      final key = _normalize(name);
      if (key.isEmpty || used.contains(key)) continue;
      used.add(key);
      result.add(name);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final machine = view.machine;
    final isNew = machine.name == justCreatedMachineName;
    final distanceText = DistanceUtil.formatDistance(view.distanceMeters);
    final walkingText = DistanceUtil.formatWalkingTime(view.distanceMeters);
    final displayProducts = _machineDisplayProducts(machine);
    final level = FreshnessUtil.getLevel(view.machine.lastCheckedAt);

    return InkWell(
      onTap: onOpenDetail,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FBFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD8E7EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    machine.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FreshnessBadge(level: level),
                if (isHighlighted)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94B70),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '通知対象',
                      style: TextStyle(
                        fontFamily: 'Noto Sans JP',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (isNew)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontFamily: 'Noto Sans JP',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MachineThumbnail(
                  imageUrl: machine.imageUrl,
                  size: 88,
                  radius: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        walkingText.isEmpty
                            ? distanceText
                            : '$distanceText ・ $walkingText',
                        style: const TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      MachineFreshnessBadge(
                        updatedAt: machine.updatedAt,
                        compact: true,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        machine.cashlessSupported
                            ? '電子決済対応'
                            : '支払い情報未設定',
                        style: const TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if (machine.updatedAt != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '更新: ${_formatDate(machine.updatedAt!)}',
                          style: const TextStyle(
                            fontFamily: 'Noto Sans JP',
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (displayProducts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: displayProducts.take(4).map((product) {
                  final isFavorite = favoriteDrinks.contains(_normalize(product));

                  return InkWell(
                    onTap: () => onApplyProductFilter(product),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isFavorite
                            ? const Color(0xFFE7F7ED)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isFavorite
                              ? const Color(0xFF57B97C)
                              : const Color(0xFFE3E7EB),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onToggleDrinkFavorite(product),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 14,
                              color: isFavorite
                                  ? const Color(0xFF57B97C)
                                  : Colors.black45,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product,
                            style: TextStyle(
                              fontFamily: 'Noto Sans JP',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isFavorite
                                  ? const Color(0xFF2E7D4F)
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (machine.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: machine.tags.take(4).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE3E7EB)),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontFamily: 'Noto Sans JP',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }
}

class _MachineListTile extends StatelessWidget {
  const _MachineListTile({
    required this.view,
    required this.isSelected,
    required this.isNew,
    required this.isHighlighted,
    required this.onTap,
    required this.onLongPress,
  });

  final _MachineViewData view;
  final bool isSelected;
  final bool isNew;
  final bool isHighlighted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  List<String> _displayProducts(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final slot in machine.drinkSlots) {
      final name = (slot['name'] ?? '').toString().trim();
      final key = name.toLowerCase();
      if (key.isEmpty || used.contains(key)) continue;
      used.add(key);
      result.add(name);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final machine = view.machine;
    final distanceText = DistanceUtil.formatDistance(view.distanceMeters);
    final displayProducts = _displayProducts(machine);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF6F7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHighlighted
                ? const Color(0xFFD94B70)
                : (isSelected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFE3E7EB)),
            width: isHighlighted ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            _MachineThumbnail(
              imageUrl: machine.imageUrl,
              size: 66,
              radius: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          machine.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Noto Sans JP',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isHighlighted)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD94B70),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '通知',
                            style: TextStyle(
                              fontFamily: 'Noto Sans JP',
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (view.hasFavoriteDrink)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF57B97C),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '推しあり',
                            style: TextStyle(
                              fontFamily: 'Noto Sans JP',
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isNew)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontFamily: 'Noto Sans JP',
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    distanceText,
                    style: const TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MachineFreshnessBadge(
                    updatedAt: machine.updatedAt,
                    compact: true,
                  ),
                  if (displayProducts.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: displayProducts.take(2).map((product) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6F8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            product,
                            style: const TextStyle(
                              fontFamily: 'Noto Sans JP',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MachineThumbnail extends StatelessWidget {
  const _MachineThumbnail({
    required this.imageUrl,
    required this.size,
    required this.radius,
  });

  final String? imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: hasImage
            ? Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _ThumbnailFallback(),
        )
            : const _ThumbnailFallback(),
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.local_drink_rounded, color: Colors.black45),
    );
  }
}

class _FavoriteDrinkPanel extends StatelessWidget {
  const _FavoriteDrinkPanel({
    required this.favoriteDrinks,
    required this.onTapDrink,
    required this.onRemoveDrink,
  });

  final List<String> favoriteDrinks;
  final Future<void> Function(String drinkName) onTapDrink;
  final Future<void> Function(String drinkName) onRemoveDrink;

  @override
  Widget build(BuildContext context) {
    if (favoriteDrinks.isEmpty) {
      return const _EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'お気に入り飲み物はまだありません',
        message: '商品名のハートを押すと、ここにまとまります。',
      );
    }

    return ListView.separated(
      itemCount: favoriteDrinks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final drink = favoriteDrinks[index];

        return InkWell(
          onTap: () => onTapDrink(drink),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3E7EB)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFF57B97C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    drink,
                    style: const TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onRemoveDrink(drink),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.progress,
    required this.favoriteDrinks,
    required this.onOpenNotificationSettings,
    required this.onOpenLogin,
    required this.isLoggedIn,
  });

  final AppProgress progress;
  final List<String> favoriteDrinks;
  final Future<void> Function() onOpenNotificationSettings;
  final Future<void> Function() onOpenLogin;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final levelProgress =
    progress.levelProgress.isFinite ? progress.levelProgress : 0.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'レベル ${progress.level}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '合計 ${progress.exp} EXP',
                  style: const TextStyle(
                    fontFamily: 'Noto Sans JP',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: levelProgress,
                    minHeight: 10,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '次のレベルまであと ${progress.expToNextLevel} EXP',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!isLoggedIn)
            InkWell(
              onTap: onOpenLogin,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE3E7EB)),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.login_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ログイン / 新規登録',
                        style: TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          if (!isLoggedIn) const SizedBox(height: 12),
          InkWell(
            onTap: onOpenNotificationSettings,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE3E7EB)),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.notifications_active_rounded),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'お気に入り通知設定',
                      style: TextStyle(
                        fontFamily: 'Noto Sans JP',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _HistorySection(
            title: '最近見た自販機',
            emptyText: 'まだ見た自販機はありません',
            items: progress.viewedMachineNames,
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 12),
          _HistorySection(
            title: 'お気に入り飲み物',
            emptyText: 'まだお気に入り飲み物はありません',
            items: favoriteDrinks,
            icon: Icons.favorite_rounded,
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.icon,
  });

  final String title;
  final String emptyText;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              emptyText,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...items.map(
                  (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.filterTags,
    required this.selectedTags,
    required this.onToggle,
    required this.onClear,
    required this.onApply,
  });

  final List<String> filterTags;
  final List<String> selectedTags;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: '絞り込み',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filterTags.map((tag) {
              return FilterChip(
                label: Text(tag),
                selected: selectedTags.contains(tag),
                onSelected: (_) => onToggle(tag),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onClear,
                  child: const Text('クリア'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApply,
                  child: const Text('適用'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE3E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
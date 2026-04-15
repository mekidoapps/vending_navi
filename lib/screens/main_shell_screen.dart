import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/drink_master_data.dart';
import '../models/product.dart';
import '../models/vending_machine.dart';
import '../utils/distance_util.dart';
import 'auth_gate.dart';
import 'favorite_drinks_screen.dart';
import 'machine_detail_screen.dart';
import 'my_page_screen.dart';
import 'notification_settings_screen.dart';
import 'register_vending_machine_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    this.initialMachineId,
  });

  final String? initialMachineId;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

enum _BottomPanelState {
  idle,
  list,
  detail,
}

class _MainShellScreenState extends State<MainShellScreen> {
  static const Color _appBackground = Color(0xFFD6ECFF);

  static const List<int> _distanceOptions = <int>[50, 100, 300, 500];

  static const List<String> _moodChips = <String>[
    'スッキリ',
    '甘い',
    '眠気覚まし',
    'あたたまりたい',
  ];

  static const List<String> _filterTags = <String>[
    'お茶',
    'コーヒー',
    '炭酸',
    '水',
    'ジュース',
    'ホット',
    '無糖',
    '微糖',
    '加糖',
    'カフェイン',
  ];

  static const Map<String, List<Map<String, dynamic>>> _manufacturerPresets =
  <String, List<Map<String, dynamic>>>{
    'コカ・コーラ': <Map<String, dynamic>>[
      {'name': 'コカ・コーラ', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': '綾鷹', 'tags': <String>['お茶', '無糖']},
      {'name': 'い・ろ・は・す', 'tags': <String>['水']},
      {'name': 'ジョージア ブラック', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': 'ファンタ グレープ', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': 'アクエリアス', 'tags': <String>['スポーツ', 'スッキリ']},
    ],
    'サントリー': <Map<String, dynamic>>[
      {'name': 'BOSS ブラック', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': '伊右衛門', 'tags': <String>['お茶', '無糖']},
      {'name': 'C.C.レモン', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': '天然水', 'tags': <String>['水']},
      {'name': 'GREEN DA・KA・RA', 'tags': <String>['スポーツ', 'スッキリ']},
    ],
    '伊藤園': <Map<String, dynamic>>[
      {'name': 'お〜いお茶 緑茶', 'tags': <String>['お茶', '無糖']},
      {'name': '健康ミネラルむぎ茶', 'tags': <String>['お茶', 'スッキリ']},
      {'name': 'TULLY\'S COFFEE ブラック', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': '磨かれて、澄みきった日本の水', 'tags': <String>['水']},
      {'name': '充実野菜', 'tags': <String>['ジュース']},
    ],
    'キリン': <Map<String, dynamic>>[
      {'name': '午後の紅茶 ミルクティー', 'tags': <String>['紅茶', '加糖']},
      {'name': '生茶', 'tags': <String>['お茶', '無糖']},
      {'name': 'FIRE ブラック', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': 'キリンレモン', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': 'アルカリイオンの水', 'tags': <String>['水']},
    ],
    'アサヒ': <Map<String, dynamic>>[
      {'name': 'ワンダ ブラック', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': '十六茶', 'tags': <String>['お茶', '無糖']},
      {'name': '三ツ矢サイダー', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': 'おいしい水 天然水', 'tags': <String>['水']},
      {'name': 'カルピスウォーター', 'tags': <String>['ジュース', '加糖']},
    ],
    'ダイドー': <Map<String, dynamic>>[
      {'name': 'ダイドーブレンド', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': 'miu', 'tags': <String>['水']},
      {'name': '葉の茶', 'tags': <String>['お茶', '無糖']},
    ],
    '大塚製薬': <Map<String, dynamic>>[
      {'name': 'ポカリスエット', 'tags': <String>['スポーツ', 'スッキリ']},
      {'name': 'MATCH', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': 'オロナミンC', 'tags': <String>['炭酸', 'ジュース', 'カフェイン']},
    ],
    'AQUO': <Map<String, dynamic>>[
      {'name': '天然水', 'tags': <String>['水']},
      {'name': 'お茶', 'tags': <String>['お茶', '無糖']},
      {'name': 'コーヒー', 'tags': <String>['コーヒー', 'カフェイン']},
    ],
  };

  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<User?>? _authSubscription;

  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _didHandleInitialMachine = false;
  bool _isMovingToCurrentLocation = false;
  bool _didLoadDistancePreference = false;
  bool _isSavingDistancePreference = false;
  bool _hasExplicitSelection = false;
  bool _isReturningFromCreate = false;
  bool _isHandlingPendingMachine = false;

  int _currentTabIndex = 0;
  int _selectedMachineIndex = 0;
  int _selectedDistanceMeters = 100;

  String _selectedKeyword = '';
  String? _selectedMood;
  String? _selectedTag;
  String? _selectedFavoriteDrink;
  String? _pendingCreatedMachineId;

  double? _currentLat;
  double? _currentLng;

  List<VendingMachine> _machines = <VendingMachine>[];

  @override
  void initState() {
    super.initState();
    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    _listenAuth();
    _listenMachines();
    _loadInitialCurrentLocation();
    _loadDistancePreferenceIfNeeded();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialCurrentLocation() async {
    try {
      final position = await DistanceUtil.getCurrentPositionSafe();
      if (!mounted || position == null) return;

      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
      });
    } catch (_) {
      // 継続
    }
  }

  void _listenAuth() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;

      setState(() {
        _isLoggedIn = user != null;
      });

      if (user == null) {
        _didLoadDistancePreference = false;
      } else {
        _loadDistancePreferenceIfNeeded(force: true);
      }
    });
  }

  Future<void> _loadDistancePreferenceIfNeeded({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_didLoadDistancePreference && !force) return;

    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final data = snapshot.data() ?? <String, dynamic>{};
      final saved = _readNullableInt(data['defaultDistanceMeters']);
      final sanitized = _sanitizeDistanceMeters(saved ?? _selectedDistanceMeters);

      if (!mounted) return;

      setState(() {
        _selectedDistanceMeters = sanitized;
        _didLoadDistancePreference = true;
        _selectedMachineIndex = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _didLoadDistancePreference = true;
      });
    }
  }

  Future<void> _saveDistancePreference(int meters) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sanitized = _sanitizeDistanceMeters(meters);

    if (mounted) {
      setState(() {
        _isSavingDistancePreference = true;
      });
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'defaultDistanceMeters': sanitized,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // 継続
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDistancePreference = false;
        });
      }
    }
  }

  int _sanitizeDistanceMeters(int value) {
    if (_distanceOptions.contains(value)) return value;
    return 100;
  }

  void _listenMachines() {
    _subscription?.cancel();

    _subscription = FirebaseFirestore.instance
        .collection('vending_machines')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
        final items = snapshot.docs.map(VendingMachine.fromFirestore).toList();

        if (!mounted) return;

        setState(() {
          _machines = items;
          _isLoading = false;

          final views = _machineViews;
          if (_selectedMachineIndex >= views.length) {
            _selectedMachineIndex = 0;
            if (views.isEmpty) {
              _hasExplicitSelection = false;
            }
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _jumpToInitialMachineIfNeeded();
          await _handlePendingCreatedMachineIfNeeded();
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _machines = <VendingMachine>[];
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _jumpToInitialMachineIfNeeded() async {
    if (_didHandleInitialMachine) return;

    final targetId = widget.initialMachineId;
    if (targetId == null || targetId.isEmpty) return;

    final views = _machineViews;
    final index = views.indexWhere((e) => e.machine.id == targetId);
    if (index == -1) return;

    setState(() {
      _selectedMachineIndex = index;
      _didHandleInitialMachine = true;
      _currentTabIndex = 0;
      _hasExplicitSelection = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _moveCameraToSelectedMachine(animated: true);
  }

  Future<void> _handlePendingCreatedMachineIfNeeded() async {
    final targetId = _pendingCreatedMachineId;
    if (targetId == null || targetId.isEmpty) return;
    if (_isHandlingPendingMachine) return;

    final index = _machineViews.indexWhere((e) => e.machine.id == targetId);
    if (index == -1) return;

    _isHandlingPendingMachine = true;

    try {
      if (!mounted) return;
      setState(() {
        _selectedMachineIndex = index;
        _currentTabIndex = 0;
        _hasExplicitSelection = true;
        _pendingCreatedMachineId = null;
        _isReturningFromCreate = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _moveCameraToSelectedMachine(animated: true);
    } finally {
      _isHandlingPendingMachine = false;
    }
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

  Product? _resolveFavoriteProduct(String drinkName) {
    final normalized = _normalize(drinkName);

    for (final product in DrinkMasterData.products) {
      if (_normalize(product.name) == normalized) {
        return product;
      }
    }

    for (final product in DrinkMasterData.products) {
      for (final keyword in product.searchKeywords) {
        if (_normalize(keyword) == normalized) {
          return product;
        }
      }
    }

    return null;
  }

  List<Product> _resolveFavoriteProducts(List<String> favoriteDrinkNames) {
    final result = <Product>[];
    final used = <String>{};

    for (final name in favoriteDrinkNames) {
      final product = _resolveFavoriteProduct(name);
      if (product == null) continue;
      if (used.contains(product.id)) continue;
      used.add(product.id);
      result.add(product);
    }

    return result;
  }

  List<Map<String, dynamic>> _productsOf(VendingMachine machine) {
    return machine.products;
  }

  List<String> _productNamesOf(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final product in _productsOf(machine)) {
      final name = (product['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final normalized = _normalize(name);
      if (used.contains(normalized)) continue;
      used.add(normalized);
      result.add(name);
    }

    return result;
  }

  List<String> _productTagsOf(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final product in _productsOf(machine)) {
      final tags = List<String>.from(product['tags'] ?? const <String>[]);
      for (final tag in tags) {
        final trimmed = tag.trim();
        if (trimmed.isEmpty) continue;

        final normalized = _normalize(trimmed);
        if (used.contains(normalized)) continue;
        used.add(normalized);
        result.add(trimmed);
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _estimatedProductsOf(VendingMachine machine) {
    if (_productNamesOf(machine).isNotEmpty) {
      return const <Map<String, dynamic>>[];
    }
    return _manufacturerPresets[machine.manufacturer] ??
        const <Map<String, dynamic>>[];
  }

  List<String> _estimatedProductNamesOf(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final product in _estimatedProductsOf(machine)) {
      final name = (product['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final normalized = _normalize(name);
      if (used.contains(normalized)) continue;
      used.add(normalized);
      result.add(name);
    }

    return result;
  }

  List<String> _estimatedProductTagsOf(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final product in _estimatedProductsOf(machine)) {
      final tags = List<String>.from(product['tags'] ?? const <String>[]);
      for (final tag in tags) {
        final trimmed = tag.trim();
        if (trimmed.isEmpty) continue;

        final normalized = _normalize(trimmed);
        if (used.contains(normalized)) continue;
        used.add(normalized);
        result.add(trimmed);
      }
    }

    return result;
  }

  bool _matchesKeyword(VendingMachine machine, String keyword) {
    final normalizedKeyword = _normalize(keyword);
    if (normalizedKeyword.isEmpty) return true;

    if (_normalize(machine.name).contains(normalizedKeyword)) return true;
    if (_normalize(machine.manufacturer).contains(normalizedKeyword)) {
      return true;
    }
    if (_normalize(machine.locationName ?? '').contains(normalizedKeyword)) {
      return true;
    }
    if (_normalize(machine.note ?? '').contains(normalizedKeyword)) return true;

    for (final productName in _productNamesOf(machine)) {
      if (_normalize(productName).contains(normalizedKeyword)) {
        return true;
      }
    }

    for (final tag in _productTagsOf(machine)) {
      if (_normalize(tag).contains(normalizedKeyword)) {
        return true;
      }
    }

    for (final productName in _estimatedProductNamesOf(machine)) {
      if (_normalize(productName).contains(normalizedKeyword)) {
        return true;
      }
    }

    for (final tag in _estimatedProductTagsOf(machine)) {
      if (_normalize(tag).contains(normalizedKeyword)) {
        return true;
      }
    }

    return false;
  }

  bool _matchesTag(VendingMachine machine, String tag) {
    final normalizedTag = _normalize(tag);

    for (final value in _productTagsOf(machine)) {
      if (_normalize(value) == normalizedTag) {
        return true;
      }
    }

    for (final value in _estimatedProductTagsOf(machine)) {
      if (_normalize(value) == normalizedTag) {
        return true;
      }
    }

    return false;
  }

  bool _matchesAnyTag(VendingMachine machine, List<String> tags) {
    for (final tag in tags) {
      if (_matchesTag(machine, tag)) return true;
    }
    return false;
  }

  bool _matchesMood(VendingMachine machine, String mood) {
    switch (mood) {
      case 'スッキリ':
        return _matchesAnyTag(machine, const <String>['水', 'お茶', 'スッキリ']);
      case '甘い':
        return _matchesAnyTag(
          machine,
          const <String>['ジュース', '炭酸', '甘い', '加糖'],
        );
      case '眠気覚まし':
        return _matchesAnyTag(
          machine,
          const <String>['コーヒー', '眠気覚まし', 'カフェイン'],
        );
      case 'あたたまりたい':
        return _matchesAnyTag(
          machine,
          const <String>['ホット', 'あたたまりたい'],
        );
      default:
        return true;
    }
  }

  double? _distanceMetersToMachine(VendingMachine machine) {
    if (_currentLat == null || _currentLng == null) return null;

    return _haversineMeters(
      _currentLat!,
      _currentLng!,
      machine.lat,
      machine.lng,
    );
  }

  double _haversineMeters(
      double lat1,
      double lng1,
      double lat2,
      double lng2,
      ) {
    const earthRadius = 6371000.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.pow(math.sin(dLng / 2), 2);

    final c =
        2 * math.atan2(math.sqrt(a.toDouble()), math.sqrt(1 - a.toDouble()));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  String _distanceLabel(double? meters) {
    if (meters == null) return '距離不明';
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  bool get _hasActiveFilters {
    return _selectedKeyword.trim().isNotEmpty ||
        _selectedMood != null ||
        _selectedTag != null ||
        _selectedFavoriteDrink != null;
  }

  _BottomPanelState get _bottomPanelState {
    if (_hasExplicitSelection && _selectedView != null) {
      return _BottomPanelState.detail;
    }
    if (_hasActiveFilters || _isReturningFromCreate) {
      return _BottomPanelState.list;
    }
    return _BottomPanelState.idle;
  }

  List<_MachineViewData> get _machineViews {
    final filtered = _machines.where((machine) {
      final keywordOk = _selectedKeyword.trim().isEmpty
          ? true
          : _matchesKeyword(machine, _selectedKeyword.trim());

      final moodOk =
      _selectedMood == null ? true : _matchesMood(machine, _selectedMood!);

      final tagOk =
      _selectedTag == null ? true : _matchesTag(machine, _selectedTag!);

      final distanceMeters = _distanceMetersToMachine(machine);
      final distanceOk = distanceMeters == null
          ? true
          : distanceMeters <= _selectedDistanceMeters;

      return keywordOk && moodOk && tagOk && distanceOk;
    }).map((machine) {
      final confirmedNames = _productNamesOf(machine);
      final confirmedTags = _productTagsOf(machine);
      final estimatedNames = _estimatedProductNamesOf(machine);
      final estimatedTags = _estimatedProductTagsOf(machine);

      return _MachineViewData(
        machine: machine,
        confirmedProductNames: confirmedNames,
        confirmedProductTags: confirmedTags,
        estimatedProductNames: estimatedNames,
        estimatedProductTags: estimatedTags,
        distanceMeters: _distanceMetersToMachine(machine),
      );
    }).toList();

    filtered.sort((a, b) {
      final aHasConfirmed = a.confirmedProductNames.isNotEmpty;
      final bHasConfirmed = b.confirmedProductNames.isNotEmpty;

      if (aHasConfirmed != bHasConfirmed) {
        return aHasConfirmed ? -1 : 1;
      }

      final aHasAny = a.displayProductNames.isNotEmpty;
      final bHasAny = b.displayProductNames.isNotEmpty;
      if (aHasAny != bHasAny) {
        return aHasAny ? -1 : 1;
      }

      if (a.distanceMeters != null && b.distanceMeters != null) {
        final distanceCompare = a.distanceMeters!.compareTo(b.distanceMeters!);
        if (distanceCompare != 0) return distanceCompare;
      } else if (a.distanceMeters != null || b.distanceMeters != null) {
        return a.distanceMeters != null ? -1 : 1;
      }

      final createdCompare = b.machine.createdAt.compareTo(a.machine.createdAt);
      if (createdCompare != 0) return createdCompare;

      return a.machine.name.compareTo(b.machine.name);
    });

    return filtered;
  }

  _MachineViewData? get _selectedView {
    final views = _machineViews;
    if (views.isEmpty) return null;

    if (_selectedMachineIndex < 0 || _selectedMachineIndex >= views.length) {
      return views.first;
    }

    return views[_selectedMachineIndex];
  }

  List<_FavoriteMatch> _favoriteMatchesForView(
      _MachineViewData view,
      List<Product> favoriteProducts,
      ) {
    final result = <_FavoriteMatch>[];
    final used = <String>{};

    for (final favorite in favoriteProducts) {
      final favoriteKey = _normalize(favorite.name);

      bool matched = false;
      for (final product in view.displayProductNames) {
        if (_normalize(product) == favoriteKey) {
          matched = true;
          break;
        }
      }

      if (!matched) continue;
      if (used.contains(favorite.id)) continue;
      used.add(favorite.id);

      result.add(
        _FavoriteMatch(
          product: favorite,
          confirmed: !view.isEstimated,
        ),
      );
    }

    return result;
  }

  List<_MachineViewData> _favoritePickupViews(List<Product> favoriteProducts) {
    if (favoriteProducts.isEmpty) return const <_MachineViewData>[];

    bool matchesFavorite(_MachineViewData view) {
      return _favoriteMatchesForView(view, favoriteProducts).isNotEmpty;
    }

    final result = _machineViews.where(matchesFavorite).toList();

    result.sort((a, b) {
      final aConfirmed = !a.isEstimated;
      final bConfirmed = !b.isEstimated;
      if (aConfirmed != bConfirmed) {
        return aConfirmed ? -1 : 1;
      }

      if (a.distanceMeters != null && b.distanceMeters != null) {
        final distanceCompare = a.distanceMeters!.compareTo(b.distanceMeters!);
        if (distanceCompare != 0) return distanceCompare;
      } else if (a.distanceMeters != null || b.distanceMeters != null) {
        return a.distanceMeters != null ? -1 : 1;
      }

      return b.machine.createdAt.compareTo(a.machine.createdAt);
    });

    return result.take(3).toList();
  }

  Future<void> _moveCameraToSelectedMachine({required bool animated}) async {
    final controller = _mapController;
    final selected = _selectedView;
    if (controller == null || selected == null) return;

    final update = CameraUpdate.newLatLngZoom(
      LatLng(selected.machine.lat, selected.machine.lng),
      15.2,
    );

    if (animated) {
      await controller.animateCamera(update);
    } else {
      await controller.moveCamera(update);
    }
  }

  Future<void> _moveToCurrentLocation() async {
    if (_isMovingToCurrentLocation) return;

    setState(() {
      _isMovingToCurrentLocation = true;
    });

    try {
      final position = await DistanceUtil.getCurrentPositionSafe();
      final controller = _mapController;

      if (!mounted || controller == null || position == null) return;

      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
      });

      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMovingToCurrentLocation = false;
        });
      }
    }
  }

  CameraPosition get _initialCameraPosition {
    final selected = _selectedView;
    if (_hasExplicitSelection && selected != null) {
      return CameraPosition(
        target: LatLng(selected.machine.lat, selected.machine.lng),
        zoom: 15,
      );
    }

    if (_currentLat != null && _currentLng != null) {
      return CameraPosition(
        target: LatLng(_currentLat!, _currentLng!),
        zoom: 15,
      );
    }

    return const CameraPosition(
      target: LatLng(35.681236, 139.767125),
      zoom: 14,
    );
  }

  double _manufacturerHue(String manufacturer, {required bool selected}) {
    final value = manufacturer.trim();

    switch (value) {
      case 'コカ・コーラ':
        return selected ? BitmapDescriptor.hueRose : BitmapDescriptor.hueRed;
      case 'サントリー':
        return selected ? BitmapDescriptor.hueCyan : BitmapDescriptor.hueAzure;
      case '伊藤園':
        return BitmapDescriptor.hueGreen;
      case 'キリン':
        return selected ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueYellow;
      case 'アサヒ':
        return BitmapDescriptor.hueOrange;
      case 'ダイドー':
        return selected
            ? BitmapDescriptor.hueViolet
            : BitmapDescriptor.hueMagenta;
      case '大塚製薬':
        return BitmapDescriptor.hueBlue;
      case 'AQUO':
        return BitmapDescriptor.hueCyan;
      default:
        return selected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed;
    }
  }

  Set<Marker> get _markers {
    final views = _machineViews;

    return views.asMap().entries.map((entry) {
      final index = entry.key;
      final view = entry.value;
      final selected = _hasExplicitSelection && index == _selectedMachineIndex;

      final snippetSource = view.displayProductNames.take(2).join(' / ');
      final snippet = view.isEstimated
          ? (snippetSource.isEmpty ? 'メーカー候補あり' : '$snippetSource かも')
          : snippetSource;

      return Marker(
        markerId: MarkerId(view.machine.id),
        position: LatLng(view.machine.lat, view.machine.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _manufacturerHue(
            view.machine.manufacturer,
            selected: selected,
          ),
        ),
        infoWindow: InfoWindow(
          title: view.machine.name,
          snippet: snippet,
        ),
        onTap: () async {
          setState(() {
            _selectedMachineIndex = index;
            _currentTabIndex = 0;
            _hasExplicitSelection = true;
          });
          await _moveCameraToSelectedMachine(animated: true);
        },
      );
    }).toSet();
  }

  Future<void> _showLoginRequiredDialog() async {
    await LoginRequiredSheet.show(context);
    if (!mounted) return;
    setState(() {
      _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    });

    await _loadDistancePreferenceIfNeeded(force: true);
  }

  Future<void> _openCreate() async {
    if (!_isLoggedIn) {
      await _showLoginRequiredDialog();
      return;
    }

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const RegisterVendingMachineScreen(),
      ),
    );

    if (!mounted) return;
    if (result == null) return;
    if (result['created'] != true) return;

    final createdMachineId = result['machineId']?.toString();
    final openDetail = result['openDetail'] == true;

    if (createdMachineId == null || createdMachineId.isEmpty) return;

    _searchController.clear();

    setState(() {
      _selectedKeyword = '';
      _selectedMood = null;
      _selectedTag = null;
      _selectedFavoriteDrink = null;
      _selectedMachineIndex = 0;
      _currentTabIndex = 0;
      _hasExplicitSelection = false;
      _isReturningFromCreate = true;
      _pendingCreatedMachineId = createdMachineId;
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    final index = _machineViews.indexWhere((e) => e.machine.id == createdMachineId);
    if (index != -1 && mounted) {
      setState(() {
        _selectedMachineIndex = index;
        _hasExplicitSelection = true;
        _isReturningFromCreate = false;
        _pendingCreatedMachineId = null;
      });
      await _moveCameraToSelectedMachine(animated: true);

      if (openDetail) {
        final selected = _selectedView;
        if (selected != null && mounted) {
          await _openDetail(selected);
        }
      }
    }
  }

  Future<void> _openDetail(_MachineViewData view) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MachineDetailScreen(
          machine: view.machine,
          currentLat: _currentLat,
          currentLng: _currentLng,
        ),
      ),
    );

    if (changed == true && mounted) {
      _listenMachines();
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationSettingsScreen(),
      ),
    );
  }

  void _applySearch(String value) {
    setState(() {
      _selectedKeyword = value.trim();
      _selectedFavoriteDrink = null;
      _selectedMachineIndex = 0;
      _currentTabIndex = 0;
      _hasExplicitSelection = false;
      _isReturningFromCreate = false;
      _pendingCreatedMachineId = null;
    });
  }

  void _applyFavoriteDrinkSearch(String drinkName) {
    _searchController.text = drinkName;
    setState(() {
      _selectedKeyword = drinkName.trim();
      _selectedFavoriteDrink = drinkName.trim();
      _selectedMachineIndex = 0;
      _currentTabIndex = 0;
      _hasExplicitSelection = false;
      _isReturningFromCreate = false;
      _pendingCreatedMachineId = null;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _selectedKeyword = '';
      _selectedMood = null;
      _selectedTag = null;
      _selectedFavoriteDrink = null;
      _selectedMachineIndex = 0;
      _hasExplicitSelection = false;
      _isReturningFromCreate = false;
      _pendingCreatedMachineId = null;
    });
  }

  Future<void> _applyDistanceSelection(int value) async {
    final sanitized = _sanitizeDistanceMeters(value);

    if (!mounted) return;
    setState(() {
      _selectedDistanceMeters = sanitized;
      _selectedMachineIndex = 0;
      _currentTabIndex = 0;
      _hasExplicitSelection = false;
      _isReturningFromCreate = false;
      _pendingCreatedMachineId = null;
    });

    await _saveDistancePreference(sanitized);
  }

  Future<void> _openFavoriteDrinkPicker() async {
    if (!_isLoggedIn) {
      await _showLoginRequiredDialog();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await _showLoginRequiredDialog();
      return;
    }

    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final data = snapshot.data() ?? <String, dynamic>{};
      final favorites = _readStringList(data['favoriteDrinkNames']);

      if (!mounted) return;

      if (favorites.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('お気に入りドリンクがまだ登録されていません。'),
          ),
        );
        return;
      }

      final products = _resolveFavoriteProducts(favorites);

      final selected = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'お気に入りから探す',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '選ぶと、そのドリンク名でマップ検索します。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: products.isNotEmpty ? products.length : favorites.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (products.isNotEmpty) {
                          final product = products[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Navigator.of(context).pop(product.name),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FBFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFE3E7EB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.favorite_rounded, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${product.manufacturer} ・ ${product.category}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF60707A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final drink = favorites[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.of(context).pop(drink),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FBFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE3E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.favorite_rounded, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      drink,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (selected == null || selected.trim().isEmpty) return;
      _applyFavoriteDrinkSearch(selected);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('お気に入り取得に失敗しました: $e'),
        ),
      );
    }
  }

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  int? _readNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _openMoodSheet() async {
    String? tempMood = _selectedMood;
    String? tempTag = _selectedTag;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3E7EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '気分 / 絞り込み',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '気分',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _moodChips.map((mood) {
                        final selected = tempMood == mood;
                        return ChoiceChip(
                          label: Text(mood),
                          selected: selected,
                          onSelected: (_) {
                            setSheetState(() {
                              tempMood = selected ? null : mood;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'タグ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filterTags.map((tag) {
                        final selected = tempTag == tag;
                        return FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (_) {
                            setSheetState(() {
                              tempTag = selected ? null : tag;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              if (!mounted) return;
                              setState(() {
                                _selectedMood = null;
                                _selectedTag = null;
                                _selectedMachineIndex = 0;
                                _currentTabIndex = 0;
                                _hasExplicitSelection = false;
                                _isReturningFromCreate = false;
                                _pendingCreatedMachineId = null;
                              });
                            },
                            child: const Text('クリア'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              if (!mounted) return;
                              setState(() {
                                _selectedMood = tempMood;
                                _selectedTag = tempTag;
                                _selectedMachineIndex = 0;
                                _currentTabIndex = 0;
                                _hasExplicitSelection = false;
                                _isReturningFromCreate = false;
                                _pendingCreatedMachineId = null;
                              });
                            },
                            child: const Text('適用'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _openFavoriteDrinkPicker();
                      },
                      icon: const Icon(Icons.favorite_rounded, size: 18),
                      label: const Text('お気に入りから探す'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapTabBody() {
    final selected = _selectedView;

    if (_machineViews.isEmpty) {
      return _EmptyState(
        title: '見つかりませんでした',
        message: _hasActiveFilters ? '条件に合う自販機がありません。' : 'まだ自販機データがありません。',
      );
    }

    if (!_isLoggedIn || FirebaseAuth.instance.currentUser == null) {
      return _buildHomeContent(const <String>[], const <Product>[], selected);
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final favoriteDrinkNames = _readStringList(data['favoriteDrinkNames']);
        final favoriteProducts = _resolveFavoriteProducts(favoriteDrinkNames);

        final savedDistance = _readNullableInt(data['defaultDistanceMeters']);
        final sanitizedSavedDistance = savedDistance == null
            ? null
            : _sanitizeDistanceMeters(savedDistance);

        if (sanitizedSavedDistance != null &&
            sanitizedSavedDistance != _selectedDistanceMeters &&
            !_isSavingDistancePreference) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedDistanceMeters = sanitizedSavedDistance;
              _selectedMachineIndex = 0;
              _hasExplicitSelection = false;
            });
          });
        }

        return _buildHomeContent(
          favoriteDrinkNames,
          favoriteProducts,
          selected,
        );
      },
    );
  }

  Widget _buildHomeContent(
      List<String> favoriteDrinkNames,
      List<Product> favoriteProducts,
      _MachineViewData? selected,
      ) {
    switch (_bottomPanelState) {
      case _BottomPanelState.idle:
        return _IdlePanelContent(
          isLoggedIn: _isLoggedIn,
          favoriteDrinkNames: favoriteDrinkNames,
          favoriteProducts: favoriteProducts,
          pickupViews: _favoritePickupViews(favoriteProducts),
          normalize: _normalize,
          distanceLabelBuilder: _distanceLabel,
          favoriteMatchesForView: _favoriteMatchesForView,
          onTapFavoriteSearch: _openFavoriteDrinkPicker,
          onOpenLoginRequired: _showLoginRequiredDialog,
          onTapPickup: (view) async {
            final index = _machineViews.indexOf(view);
            if (index == -1) return;
            setState(() {
              _selectedMachineIndex = index;
              _hasExplicitSelection = true;
            });
            await _moveCameraToSelectedMachine(animated: true);
          },
        );

      case _BottomPanelState.list:
        return _MachineListPanelContent(
          machineViews: _machineViews,
          selectedMachineIndex: _selectedMachineIndex,
          favoriteDrinkNames: favoriteDrinkNames,
          favoriteProducts: favoriteProducts,
          normalize: _normalize,
          distanceLabelBuilder: _distanceLabel,
          searchKeyword: _selectedKeyword,
          favoriteMatchesForView: _favoriteMatchesForView,
          onSelectMachine: (index) async {
            setState(() {
              _selectedMachineIndex = index;
              _hasExplicitSelection = true;
            });
            await _moveCameraToSelectedMachine(animated: true);
          },
          onOpenDetail: _openDetail,
        );

      case _BottomPanelState.detail:
        if (selected == null) {
          return const _EmptyState(
            title: '見つかりませんでした',
            message: '選択中の自販機がありません。',
          );
        }
        return _MachineDetailPanelContent(
          selectedView: selected,
          favoriteDrinkNames: favoriteDrinkNames,
          favoriteProducts: favoriteProducts,
          normalize: _normalize,
          distanceLabelBuilder: _distanceLabel,
          favoriteMatchesForView: _favoriteMatchesForView,
          onOpenDetail: _openDetail,
          onShowList: () {
            setState(() {
              _hasExplicitSelection = false;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _TopHeaderSection(
              controller: _searchController,
              selectedKeyword: _selectedKeyword,
              selectedMood: _selectedMood,
              selectedTag: _selectedTag,
              selectedDistanceMeters: _selectedDistanceMeters,
              isSavingDistancePreference: _isSavingDistancePreference,
              onSubmitted: _applySearch,
              onClear: _clearSearch,
              onTapNotifications: _openNotifications,
              onTapMood: _openMoodSheet,
              onTapDistance: _applyDistanceSelection,
            ),
            Expanded(
              child: Column(
                children: [
                  if (_currentTabIndex == 0)
                    Expanded(
                      flex: 11,
                      child: Stack(
                        children: [
                          _MapSection(
                            initialCameraPosition: _initialCameraPosition,
                            markers: _markers,
                            onMapCreated: (controller) {
                              _mapController = controller;
                            },
                            onMapTap: (_) {
                              if (!_hasExplicitSelection) return;
                              setState(() {
                                _hasExplicitSelection = false;
                              });
                            },
                          ),
                          Positioned(
                            right: 24,
                            bottom: 84,
                            child: _MapCircleButton(
                              icon: _isMovingToCurrentLocation
                                  ? null
                                  : Icons.my_location_rounded,
                              onPressed: _isMovingToCurrentLocation
                                  ? null
                                  : _moveToCurrentLocation,
                              child: _isMovingToCurrentLocation
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 24,
                            bottom: 20,
                            child: _MapRegisterButton(
                              isLoggedIn: _isLoggedIn,
                              onPressed: _openCreate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    flex: 12,
                    child: _BottomArea(
                      currentTabIndex: _currentTabIndex,
                      onTabChanged: (index) {
                        setState(() {
                          _currentTabIndex = index;
                        });
                      },
                      content: _buildTabBody(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    if (_currentTabIndex == 0) {
      return _buildMapTabBody();
    }

    if (_currentTabIndex == 1) {
      return const FavoriteDrinksScreen();
    }

    return MyPageScreen(
      isLoggedIn: _isLoggedIn,
    );
  }
}

class _MachineViewData {
  const _MachineViewData({
    required this.machine,
    required this.confirmedProductNames,
    required this.confirmedProductTags,
    required this.estimatedProductNames,
    required this.estimatedProductTags,
    required this.distanceMeters,
  });

  final VendingMachine machine;
  final List<String> confirmedProductNames;
  final List<String> confirmedProductTags;
  final List<String> estimatedProductNames;
  final List<String> estimatedProductTags;
  final double? distanceMeters;

  bool get isEstimated =>
      confirmedProductNames.isEmpty && estimatedProductNames.isNotEmpty;

  List<String> get displayProductNames =>
      confirmedProductNames.isNotEmpty ? confirmedProductNames : estimatedProductNames;

  List<String> get displayProductTags =>
      confirmedProductTags.isNotEmpty ? confirmedProductTags : estimatedProductTags;
}

class _FavoriteMatch {
  const _FavoriteMatch({
    required this.product,
    required this.confirmed,
  });

  final Product product;
  final bool confirmed;
}

class _TopHeaderSection extends StatelessWidget {
  const _TopHeaderSection({
    required this.controller,
    required this.selectedKeyword,
    required this.selectedMood,
    required this.selectedTag,
    required this.selectedDistanceMeters,
    required this.isSavingDistancePreference,
    required this.onSubmitted,
    required this.onClear,
    required this.onTapNotifications,
    required this.onTapMood,
    required this.onTapDistance,
  });

  final TextEditingController controller;
  final String selectedKeyword;
  final String? selectedMood;
  final String? selectedTag;
  final int selectedDistanceMeters;
  final bool isSavingDistancePreference;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onTapNotifications;
  final VoidCallback onTapMood;
  final ValueChanged<int> onTapDistance;

  @override
  Widget build(BuildContext context) {
    final hasMoodOrTag = selectedMood != null || selectedTag != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD5E8F5)),
            ),
            child: Row(
              children: [
                const Text(
                  '自販機ナビ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334148),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onTapNotifications,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFDCE9F3)),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: TextField(
                    controller: controller,
                    onSubmitted: onSubmitted,
                    decoration: InputDecoration(
                      hintText: '飲みたいドリンクを検索',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: selectedKeyword.isNotEmpty
                          ? IconButton(
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                      )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF7FBFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                        const BorderSide(color: Color(0xFFE3E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                        const BorderSide(color: Color(0xFFE3E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _HeaderActionButton(
                    icon: Icons.tune_rounded,
                    label: hasMoodOrTag ? '気分中' : '気分',
                    selected: hasMoodOrTag,
                    onTap: onTapMood,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _DistanceMenuButton(
                    value: selectedDistanceMeters,
                    isSaving: isSavingDistancePreference,
                    onChanged: onTapDistance,
                    options: _MainShellScreenState._distanceOptions,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFE3E7EB);

    final backgroundColor =
    selected ? const Color(0xFFEAF6FF) : const Color(0xFFF7FBFC);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceMenuButton extends StatelessWidget {
  const _DistanceMenuButton({
    required this.value,
    required this.isSaving,
    required this.onChanged,
    required this.options,
  });

  final int value;
  final bool isSaving;
  final ValueChanged<int> onChanged;
  final List<int> options;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: onChanged,
      itemBuilder: (context) {
        return options.map((meters) {
          return PopupMenuItem<int>(
            value: meters,
            child: Text('${meters}m'),
          );
        }).toList();
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FBFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isSaving
                ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.near_me_rounded, size: 18),
            const SizedBox(height: 2),
            Text(
              '${value}m',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({
    required this.initialCameraPosition,
    required this.markers,
    required this.onMapCreated,
    required this.onMapTap,
  });

  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<LatLng> onMapTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: GoogleMap(
          initialCameraPosition: initialCameraPosition,
          onMapCreated: onMapCreated,
          onTap: onMapTap,
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.onPressed,
    this.icon,
    this.child,
  });

  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE3E7EB)),
          ),
          alignment: Alignment.center,
          child: child ?? Icon(icon),
        ),
      ),
    );
  }
}

class _MapRegisterButton extends StatelessWidget {
  const _MapRegisterButton({
    required this.isLoggedIn,
    required this.onPressed,
  });

  final bool isLoggedIn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE3E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLoggedIn ? Icons.add_business_rounded : Icons.lock_rounded,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isLoggedIn ? '登録' : 'ログインで登録',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.currentTabIndex,
    required this.onTabChanged,
    required this.content,
  });

  final int currentTabIndex;
  final ValueChanged<int> onTabChanged;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFDCE9F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(child: content),
          const SizedBox(height: 10),
          const _AdBanner(),
          const SizedBox(height: 10),
          _BottomNavBar(
            currentTabIndex: currentTabIndex,
            onTabChanged: onTabChanged,
          ),
        ],
      ),
    );
  }
}

class _AdBanner extends StatelessWidget {
  const _AdBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      alignment: Alignment.center,
      child: const Text(
        '広告枠',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF60707A),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentTabIndex,
    required this.onTabChanged,
  });

  final int currentTabIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = <({IconData icon, String label})>[
      (icon: Icons.map_rounded, label: 'マップ'),
      (icon: Icons.favorite_rounded, label: 'お気に入り'),
      (icon: Icons.person_rounded, label: 'マイページ'),
    ];

    return SizedBox(
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
                onTap: () => onTabChanged(index),
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
                    children: [
                      Icon(
                        tab.icon,
                        size: 22,
                        color: selected ? Colors.white : Colors.black54,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : Colors.black54,
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
    );
  }
}

class _IdlePanelContent extends StatelessWidget {
  const _IdlePanelContent({
    required this.isLoggedIn,
    required this.favoriteDrinkNames,
    required this.favoriteProducts,
    required this.pickupViews,
    required this.normalize,
    required this.distanceLabelBuilder,
    required this.favoriteMatchesForView,
    required this.onTapFavoriteSearch,
    required this.onOpenLoginRequired,
    required this.onTapPickup,
  });

  final bool isLoggedIn;
  final List<String> favoriteDrinkNames;
  final List<Product> favoriteProducts;
  final List<_MachineViewData> pickupViews;
  final String Function(String value) normalize;
  final String Function(double? meters) distanceLabelBuilder;
  final List<_FavoriteMatch> Function(_MachineViewData, List<Product>)
  favoriteMatchesForView;
  final Future<void> Function() onTapFavoriteSearch;
  final Future<void> Function() onOpenLoginRequired;
  final Future<void> Function(_MachineViewData view) onTapPickup;

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InlineInfoCard(
              title: '近くの自販機を探す',
              subtitle: '上の検索バーから、今飲みたいドリンクを探せます。',
            ),
            const SizedBox(height: 12),
            _ActionInfoCard(
              title: 'ログインでお気に入りから探せます',
              subtitle: 'お気に入りに入れたドリンクで、近くの自販機を見つけやすくなります。',
              buttonLabel: 'ログインする',
              onPressed: onOpenLoginRequired,
            ),
          ],
        ),
      );
    }

    if (favoriteDrinkNames.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InlineInfoCard(
              title: '近くの自販機を探す',
              subtitle: '上の検索バーから、今飲みたいドリンクを探せます。',
            ),
            const SizedBox(height: 12),
            _ActionInfoCard(
              title: 'お気に入り登録で探しやすくなります',
              subtitle: 'よく飲むドリンクをお気に入りに入れると、近くにある自販機をここに表示します。',
              buttonLabel: 'お気に入りから探す',
              onPressed: onTapFavoriteSearch,
            ),
          ],
        ),
      );
    }

    if (pickupViews.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InlineInfoCard(
              title: '近くにお気に入り候補がありません',
              subtitle: '距離を広げるか、検索バーから別のドリンクを探してみてください。',
            ),
            const SizedBox(height: 12),
            _ActionInfoCard(
              title: 'お気に入りを見直す',
              subtitle: 'お気に入りドリンクを変えると、ここに近くの候補が表示されます。',
              buttonLabel: 'お気に入りから探す',
              onPressed: onTapFavoriteSearch,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'お気に入りから近くの自販機',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...pickupViews.map((view) {
            final matches = favoriteMatchesForView(view, favoriteProducts);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onTapPickup(view),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: view.isEstimated
                        ? const Color(0xFFF7FBFC)
                        : const Color(0xFFFFFBF2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: view.isEstimated
                          ? const Color(0xFFD8E7EA)
                          : const Color(0xFFFFD18B),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        view.isEstimated
                            ? Icons.help_outline_rounded
                            : Icons.favorite_rounded,
                        color: view.isEstimated
                            ? const Color(0xFF60707A)
                            : const Color(0xFFB56B00),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              view.machine.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Text(
                                  '${view.machine.manufacturer} ・ ${distanceLabelBuilder(view.distanceMeters)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF60707A),
                                  ),
                                ),
                                _DrinkStateBadge(isEstimated: view.isEstimated),
                              ],
                            ),
                            if (matches.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                view.isEstimated
                                    ? '候補: ${matches.map((e) => e.product.name).join(' / ')} かも'
                                    : '一致: ${matches.map((e) => e.product.name).join(' / ')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: view.isEstimated
                                      ? const Color(0xFF60707A)
                                      : const Color(0xFF8A5A00),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ActionInfoCard extends StatelessWidget {
  const _ActionInfoCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF60707A),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => onPressed(),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineListPanelContent extends StatelessWidget {
  const _MachineListPanelContent({
    required this.machineViews,
    required this.selectedMachineIndex,
    required this.favoriteDrinkNames,
    required this.favoriteProducts,
    required this.onSelectMachine,
    required this.onOpenDetail,
    required this.normalize,
    required this.distanceLabelBuilder,
    required this.searchKeyword,
    required this.favoriteMatchesForView,
  });

  final List<_MachineViewData> machineViews;
  final int selectedMachineIndex;
  final List<String> favoriteDrinkNames;
  final List<Product> favoriteProducts;
  final Future<void> Function(int index) onSelectMachine;
  final Future<void> Function(_MachineViewData view) onOpenDetail;
  final String Function(String value) normalize;
  final String Function(double? meters) distanceLabelBuilder;
  final String searchKeyword;
  final List<_FavoriteMatch> Function(_MachineViewData, List<Product>)
  favoriteMatchesForView;

  @override
  Widget build(BuildContext context) {
    final title =
    searchKeyword.trim().isEmpty ? '候補一覧' : '「$searchKeyword」検索結果 ${machineViews.length}件';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: machineViews.length,
            itemBuilder: (context, index) {
              final view = machineViews[index];
              final machine = view.machine;
              final selected = index == selectedMachineIndex;
              final favoriteMatches = favoriteMatchesForView(view, favoriteProducts);
              final hasFavorite = favoriteMatches.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => onSelectMachine(index),
                  onLongPress: () => onOpenDetail(view),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEAF6F7)
                          : hasFavorite
                          ? const Color(0xFFFFFBF2)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : hasFavorite
                            ? const Color(0xFFFFD18B)
                            : const Color(0xFFE3E7EB),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          hasFavorite
                              ? Icons.favorite_rounded
                              : view.isEstimated
                              ? Icons.help_outline_rounded
                              : Icons.local_drink_rounded,
                          color: hasFavorite ? const Color(0xFFB56B00) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                machine.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    machine.manufacturer,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF60707A),
                                    ),
                                  ),
                                  _DrinkStateBadge(isEstimated: view.isEstimated),
                                  if (hasFavorite) const _MiniFavoriteBadge(),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '距離: ${distanceLabelBuilder(view.distanceMeters)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF60707A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (view.displayProductNames.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  view.isEstimated
                                      ? '${view.displayProductNames.take(3).join(' / ')} かも'
                                      : view.displayProductNames.take(3).join(' / '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: view.isEstimated
                                        ? const Color(0xFF6D7B84)
                                        : const Color(0xFF60707A),
                                    fontWeight: view.isEstimated
                                        ? FontWeight.w600
                                        : FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MachineDetailPanelContent extends StatelessWidget {
  const _MachineDetailPanelContent({
    required this.selectedView,
    required this.favoriteDrinkNames,
    required this.favoriteProducts,
    required this.normalize,
    required this.distanceLabelBuilder,
    required this.favoriteMatchesForView,
    required this.onOpenDetail,
    required this.onShowList,
  });

  final _MachineViewData selectedView;
  final List<String> favoriteDrinkNames;
  final List<Product> favoriteProducts;
  final String Function(String value) normalize;
  final String Function(double? meters) distanceLabelBuilder;
  final List<_FavoriteMatch> Function(_MachineViewData, List<Product>)
  favoriteMatchesForView;
  final Future<void> Function(_MachineViewData view) onOpenDetail;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) {
    final machine = selectedView.machine;
    final displayProducts = selectedView.displayProductNames;
    final favoriteMatches = favoriteMatchesForView(selectedView, favoriteProducts);
    final favoriteKeys = favoriteMatches.map((e) => e.product.id).toSet();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '選択中の自販機',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onShowList,
                icon: const Icon(Icons.view_list_rounded, size: 18),
                label: const Text('一覧へ'),
              ),
            ],
          ),
          InkWell(
            onTap: () => onOpenDetail(selectedView),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: favoriteMatches.isNotEmpty
                      ? const Color(0xFFFFC56D)
                      : const Color(0xFFD8E7EA),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          machine.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _DrinkStateBadge(isEstimated: selectedView.isEstimated),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'メーカー: ${machine.manufacturer}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF60707A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '距離: ${distanceLabelBuilder(selectedView.distanceMeters)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((machine.locationName ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      machine.locationName!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF60707A),
                      ),
                    ),
                  ],
                  if ((machine.note ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '備考: ${machine.note!}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60707A),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    selectedView.isEstimated
                        ? 'このメーカーで見かけることがあるドリンク'
                        : '確認されているドリンク',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selectedView.isEstimated
                          ? const Color(0xFF60707A)
                          : const Color(0xFF334148),
                    ),
                  ),
                  if (selectedView.isEstimated) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'まだドリンク登録がないため、メーカー情報から候補を表示しています。',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF60707A),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (displayProducts.isEmpty)
                    const Text(
                      'ドリンク未登録',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF60707A),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: displayProducts.map((productName) {
                        final matchedProduct = favoriteMatches
                            .map((e) => e.product)
                            .where((e) => normalize(e.name) == normalize(productName))
                            .cast<Product?>()
                            .firstWhere(
                              (e) => e != null,
                          orElse: () => null,
                        );

                        final isFavorite =
                            matchedProduct != null && favoriteKeys.contains(matchedProduct.id);

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: selectedView.isEstimated
                                ? const Color(0xFFF7FBFC)
                                : isFavorite
                                ? const Color(0xFFFFF2D9)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selectedView.isEstimated
                                  ? const Color(0xFFD8E7EA)
                                  : isFavorite
                                  ? const Color(0xFFFFD18B)
                                  : const Color(0xFFE3E7EB),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFavorite && !selectedView.isEstimated) ...[
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 13,
                                  color: Color(0xFFB56B00),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (selectedView.isEstimated) ...[
                                const Icon(
                                  Icons.help_outline_rounded,
                                  size: 13,
                                  color: Color(0xFF60707A),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                productName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                  isFavorite || selectedView.isEstimated
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: selectedView.isEstimated
                                      ? const Color(0xFF60707A)
                                      : isFavorite
                                      ? const Color(0xFF8A5A00)
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => onOpenDetail(selectedView),
                      child: const Text('詳細を見る'),
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

class _DrinkStateBadge extends StatelessWidget {
  const _DrinkStateBadge({
    required this.isEstimated,
  });

  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
    isEstimated ? const Color(0xFFF1F3F5) : const Color(0xFFEAF6FF);
    final borderColor =
    isEstimated ? const Color(0xFFD8E0E5) : const Color(0xFFBEDDF4);
    final textColor =
    isEstimated ? const Color(0xFF60707A) : const Color(0xFF245A84);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        isEstimated ? '候補' : '確認済み',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _MiniFavoriteBadge extends StatelessWidget {
  const _MiniFavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2D9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFFD18B),
        ),
      ),
      child: const Text(
        'お気に入りあり',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8A5A00),
        ),
      ),
    );
  }
}

class _InlineInfoCard extends StatelessWidget {
  const _InlineInfoCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF60707A),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
  });

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
          children: [
            const Icon(Icons.search_off_rounded, size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
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
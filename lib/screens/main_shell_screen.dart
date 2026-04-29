import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/drink_master_data.dart';
import '../models/product.dart';
import '../models/vending_machine.dart';
import '../services/firestore_service.dart';
import '../utils/distance_util.dart';
import '../utils/map_marker_factory.dart';
import '../widgets/login_required_sheet.dart';
import '../widgets/simple_tutorial_dialog.dart';
import 'favorite_drinks_screen.dart';
import 'machine_detail_screen.dart';
import 'my_page_screen.dart';
import 'notification_settings_screen.dart';
import 'register_vending_machine_screen.dart';

Color _manufacturerAccentColorOf(String manufacturer) {
  switch (manufacturer.trim()) {
    case 'コカコーラ':
    case 'コカ・コーラ':
      return const Color(0xFFE53935);
    case 'サントリー':
      return const Color(0xFF1E88E5);
    case '伊藤園':
      return const Color(0xFF43A047);
    case 'キリン':
      return const Color(0xFFF9A825);
    case 'アサヒ':
      return const Color(0xFFFB8C00);
    case '大塚製薬':
      return const Color(0xFF3949AB);
    case 'AQUO':
      return const Color(0xFF00ACC1);
    case 'ダイドー':
      return const Color(0xFF8E24AA);
    default:
      return const Color(0xFF60707A);
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key, this.initialMachineId});

  final String? initialMachineId;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

enum _MainTab { map, favorites, myPage }

enum _MapPanelMode { idle, list, detail }

class _MainShellScreenState extends State<MainShellScreen> {
  static const Color _appBackground = Color(0xFFD6ECFF);
  static const List<int> _distanceOptions = <int>[50, 100, 300, 500];
  static const List<String> _moodChips = <String>['スッキリ', '甘い', '眠気覚まし', 'あたたまりたい'];
  static const List<String> _filterTags = <String>['お茶', 'コーヒー', '炭酸', '水', 'ジュース', 'ホット', '無糖', '微糖', '加糖', 'カフェイン', 'スポーツ', '紅茶'];

  static const Map<String, List<Map<String, dynamic>>> _manufacturerPresets = <String, List<Map<String, dynamic>>>{
    'コカ・コーラ': <Map<String, dynamic>>[
      {'name': 'コカ・コーラ', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': '綾鷹', 'tags': <String>['お茶', '無糖']},
      {'name': 'い・ろ・は・す', 'tags': <String>['水']},
      {'name': 'ジョージア', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': 'ファンタ', 'tags': <String>['炭酸', 'ジュース', '加糖']},
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
      {'name': 'カルピス', 'tags': <String>['ジュース', '加糖']},
      {'name': 'おいしい水', 'tags': <String>['水']},
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
    'その他': <Map<String, dynamic>>[
      {'name': '水', 'tags': <String>['水']},
      {'name': 'お茶', 'tags': <String>['お茶', '無糖']},
      {'name': 'コーヒー', 'tags': <String>['コーヒー', 'カフェイン']},
    ],
  };

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _machineListScrollController = ScrollController();
  final Map<String, GlobalKey> _machineItemKeys = <String, GlobalKey>{};
  final Map<String, BitmapDescriptor> _markerCache = <String, BitmapDescriptor>{};
  final Set<String> _loadingMarkerKeys = <String>{};

  GoogleMapController? _mapController;
  StreamSubscription<User?>? _authSubscription;
  _MainTab _currentTab = _MainTab.map;
  bool _isLoggedIn = false;
  bool _isLoadingCurrentLocation = false;
  bool _didLoadDistancePreference = false;
  bool _isSavingDistancePreference = false;
  bool _didMoveToCurrentLocationOnce = false;
  bool _didHandleInitialMachine = false;
  bool _isSchedulingPendingSelection = false;
  bool _openTitleListOnMyPageOpen = false;
  bool _showDetailPanel = false;
  bool _showSearchHereButton = false;
  int _selectedDistanceMeters = 100;
  String _selectedKeyword = '';
  String? _selectedMood;
  String? _selectedTag;
  String? _selectedMachineId;
  String? _pendingMachineId;
  double? _currentLat;
  double? _currentLng;
  double? _searchCenterLat;
  double? _searchCenterLng;
  double? _pendingSearchCenterLat;
  double? _pendingSearchCenterLng;
  List<_MachineView> _latestViews = const <_MachineView>[];

  @override
  void initState() {
    super.initState();
    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    _searchController.addListener(_handleSearchTextChanged);
    _listenAuth();
    _loadCurrentLocation();
    _loadDistancePreferenceIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorialIfNeeded());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _mapController?.dispose();
    _machineListScrollController.dispose();
    _searchController..removeListener(_handleSearchTextChanged)..dispose();
    super.dispose();
  }

  Future<void> _showTutorialIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('main_tutorial_seen') ?? false;
    if (seen || !mounted) return;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const SimpleTutorialDialog());
    await prefs.setBool('main_tutorial_seen', true);
  }

  GlobalKey _keyForMachine(String machineId) => _machineItemKeys.putIfAbsent(machineId, () => GlobalKey());

  Future<void> _scrollToMachineCard(String machineId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final itemContext = _keyForMachine(machineId).currentContext;
    if (itemContext == null) return;
    await Scrollable.ensureVisible(itemContext, duration: const Duration(milliseconds: 280), curve: Curves.easeInOut, alignment: 0.5);
  }

  void _listenAuth() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() => _isLoggedIn = user != null);
      if (user == null) {
        _didLoadDistancePreference = false;
      } else {
        _loadDistancePreferenceIfNeeded(force: true);
      }
    });
  }

  Future<void> _loadCurrentLocation() async {
    if (_isLoadingCurrentLocation) return;
    setState(() => _isLoadingCurrentLocation = true);
    try {
      final position = await DistanceUtil.getCurrentPositionSafe();
      if (!mounted || position == null) return;
      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _searchCenterLat ??= position.latitude;
        _searchCenterLng ??= position.longitude;
      });
      if (_mapController != null && !_didMoveToCurrentLocationOnce && _selectedMachineId == null) {
        _didMoveToCurrentLocationOnce = true;
        await _moveCamera(LatLng(position.latitude, position.longitude), _zoomForDistance(_selectedDistanceMeters));
      }
    } finally {
      if (mounted) setState(() => _isLoadingCurrentLocation = false);
    }
  }

  Future<void> _loadDistancePreferenceIfNeeded({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_didLoadDistancePreference && !force) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final saved = _readNullableInt(data['defaultDistanceMeters']);
      final sanitized = _sanitizeDistance(saved ?? _selectedDistanceMeters);
      if (!mounted) return;
      setState(() {
        _selectedDistanceMeters = sanitized;
        _didLoadDistancePreference = true;
      });
    } catch (_) {
      if (mounted) setState(() => _didLoadDistancePreference = true);
    }
  }

  Future<void> _saveDistancePreference(int meters) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSavingDistancePreference = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(<String, dynamic>{'defaultDistanceMeters': meters, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _isSavingDistancePreference = false);
    }
  }

  int _sanitizeDistance(int value) => _distanceOptions.contains(value) ? value : 100;
  int? _readNullableInt(dynamic value) => value is int ? value : value is num ? value.toInt() : value is String ? int.tryParse(value.trim()) : null;
  List<String> _readStringList(dynamic value) => value is List ? value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() : <String>[];

  void _handleSearchTextChanged() {
    final next = _searchController.text.trim();
    if (_selectedKeyword == next) return;
    setState(() {
      _selectedKeyword = next;
      _selectedMachineId = null;
      _showDetailPanel = false;
    });
  }

  String _normalize(String input) => input.trim().toLowerCase().replaceAll('　', '').replaceAll(' ', '').replaceAll('〜', 'ー').replaceAll('～', 'ー').replaceAll('-', 'ー');

  List<String> _confirmedProductNames(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};
    for (final product in machine.products) {
      final name = (product['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final key = _normalize(name);
      if (used.add(key)) result.add(name);
    }
    return result;
  }

  List<String> _confirmedProductTags(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};
    for (final product in machine.products) {
      final rawTags = product['tags'];
      final tags = rawTags is List ? rawTags : const <dynamic>[];
      for (final tagValue in tags) {
        final tag = tagValue.toString().trim();
        if (tag.isEmpty) continue;
        final key = _normalize(tag);
        if (used.add(key)) result.add(tag);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _estimatedProducts(VendingMachine machine) {
    if (_confirmedProductNames(machine).isNotEmpty) return const <Map<String, dynamic>>[];
    return _manufacturerPresets[machine.manufacturer] ?? _manufacturerPresets['その他'] ?? const <Map<String, dynamic>>[];
  }

  List<String> _estimatedProductNames(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};
    for (final product in _estimatedProducts(machine)) {
      final name = (product['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final key = _normalize(name);
      if (used.add(key)) result.add(name);
    }
    return result;
  }

  List<String> _estimatedProductTags(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};
    for (final product in _estimatedProducts(machine)) {
      final rawTags = product['tags'];
      final tags = rawTags is List ? rawTags : const <dynamic>[];
      for (final tagValue in tags) {
        final tag = tagValue.toString().trim();
        if (tag.isEmpty) continue;
        final key = _normalize(tag);
        if (used.add(key)) result.add(tag);
      }
    }
    return result;
  }

  Product? _resolveFavoriteProduct(String drinkName) {
    final normalized = _normalize(drinkName);
    for (final product in DrinkMasterData.products) {
      if (_normalize(product.name) == normalized) return product;
    }
    for (final product in DrinkMasterData.products) {
      for (final keyword in product.searchKeywords) {
        if (_normalize(keyword) == normalized) return product;
      }
    }
    return null;
  }

  List<Product> _resolveFavoriteProducts(List<String> favoriteDrinkNames) {
    final result = <Product>[];
    final used = <String>{};
    for (final name in favoriteDrinkNames) {
      final product = _resolveFavoriteProduct(name);
      if (product == null || used.contains(product.id)) continue;
      used.add(product.id);
      result.add(product);
    }
    return result;
  }

  bool _matchesTag(VendingMachine machine, String tag) {
    final key = _normalize(tag);
    for (final value in _confirmedProductTags(machine)) {
      if (_normalize(value) == key) return true;
    }
    for (final value in _estimatedProductTags(machine)) {
      if (_normalize(value) == key) return true;
    }
    return false;
  }

  bool _matchesAnyTag(VendingMachine machine, List<String> tags) => tags.any((tag) => _matchesTag(machine, tag));

  bool _matchesMood(VendingMachine machine, String mood) {
    switch (mood) {
      case 'スッキリ': return _matchesAnyTag(machine, const <String>['水', 'お茶', 'スッキリ']);
      case '甘い': return _matchesAnyTag(machine, const <String>['ジュース', '炭酸', '加糖']);
      case '眠気覚まし': return _matchesAnyTag(machine, const <String>['コーヒー', 'カフェイン']);
      case 'あたたまりたい': return _matchesAnyTag(machine, const <String>['ホット']);
      default: return true;
    }
  }

  bool _matchesKeyword(VendingMachine machine, String keyword) {
    final key = _normalize(keyword);
    if (key.isEmpty) return true;
    if (_normalize(machine.name).contains(key)) return true;
    if (_normalize(machine.manufacturer).contains(key)) return true;
    if (_normalize(machine.locationName ?? '').contains(key)) return true;
    if (_normalize(machine.note ?? '').contains(key)) return true;
    for (final value in _confirmedProductNames(machine)) { if (_normalize(value).contains(key)) return true; }
    for (final value in _confirmedProductTags(machine)) { if (_normalize(value).contains(key)) return true; }
    for (final value in _estimatedProductNames(machine)) { if (_normalize(value).contains(key)) return true; }
    for (final value in _estimatedProductTags(machine)) { if (_normalize(value).contains(key)) return true; }
    return false;
  }

  double? _distanceToMachine(VendingMachine machine) {
    final baseLat = _searchCenterLat ?? _currentLat;
    final baseLng = _searchCenterLng ?? _currentLng;
    if (baseLat == null || baseLng == null) return null;
    final meters = DistanceUtil.calculateDistanceMeters(fromLat: baseLat, fromLng: baseLng, toLat: machine.lat, toLng: machine.lng);
    return meters.isFinite ? meters : null;
  }

  String _distanceLabel(double? meters) => DistanceUtil.formatDistance(meters);

  List<_MachineView> _buildViews(List<VendingMachine> machines) {
    final views = <_MachineView>[];
    for (final machine in machines) {
      final distance = _distanceToMachine(machine);
      if (distance != null && distance > _selectedDistanceMeters) continue;
      if (_selectedKeyword.trim().isNotEmpty && !_matchesKeyword(machine, _selectedKeyword.trim())) continue;
      if (_selectedMood != null && !_matchesMood(machine, _selectedMood!)) continue;
      if (_selectedTag != null && !_matchesTag(machine, _selectedTag!)) continue;
      views.add(_MachineView(machine: machine, confirmedProductNames: _confirmedProductNames(machine), estimatedProductNames: _estimatedProductNames(machine), distanceMeters: distance));
    }
    views.sort((a, b) {
      final ad = a.distanceMeters;
      final bd = b.distanceMeters;
      if (ad != null && bd != null) { final cmp = ad.compareTo(bd); if (cmp != 0) return cmp; }
      else if (ad != null || bd != null) { return ad != null ? -1 : 1; }
      final byConfirmed = (b.confirmedProductNames.isNotEmpty ? 1 : 0).compareTo(a.confirmedProductNames.isNotEmpty ? 1 : 0);
      if (byConfirmed != 0) return byConfirmed;
      return b.machine.updatedAt.compareTo(a.machine.updatedAt);
    });
    return views;
  }

  _MachineView? _selectedView(List<_MachineView> views) {
    final selectedId = _selectedMachineId ?? (!_didHandleInitialMachine ? widget.initialMachineId : null);
    if (selectedId == null || selectedId.isEmpty) return null;
    for (final view in views) { if (view.machine.id == selectedId) return view; }
    return null;
  }

  _MapPanelMode _panelMode(List<_MachineView> views) {
    final selectedView = _selectedView(views);
    if (_showDetailPanel && selectedView != null) return _MapPanelMode.detail;
    if (_selectedMachineId != null || _selectedKeyword.isNotEmpty || _selectedMood != null || _selectedTag != null) return _MapPanelMode.list;
    return _MapPanelMode.idle;
  }

  Future<void> _moveCamera(LatLng target, double zoom) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: zoom)));
  }

  double _zoomForDistance(int meters) {
    switch (meters) { case 50: return 18.2; case 100: return 17.2; case 300: return 16.0; case 500: return 15.2; default: return 16.8; }
  }

  Future<void> _moveCameraToMachine(VendingMachine machine) async => _moveCamera(LatLng(machine.lat, machine.lng), 15.4);

  Future<void> _moveToCurrentLocation() async {
    final position = await DistanceUtil.getCurrentPositionSafe();
    if (!mounted || position == null) return;
    setState(() {
      _currentLat = position.latitude; _currentLng = position.longitude;
      _searchCenterLat = position.latitude; _searchCenterLng = position.longitude;
      _pendingSearchCenterLat = position.latitude; _pendingSearchCenterLng = position.longitude;
      _showSearchHereButton = false; _showDetailPanel = false;
    });
    await _moveCamera(LatLng(position.latitude, position.longitude), _zoomForDistance(_selectedDistanceMeters));
  }

  Future<void> _applySearchHere() async {
    final lat = _pendingSearchCenterLat; final lng = _pendingSearchCenterLng;
    if (lat == null || lng == null) return;
    setState(() { _searchCenterLat = lat; _searchCenterLng = lng; _selectedMachineId = null; _showDetailPanel = false; _showSearchHereButton = false; });
  }

  Future<void> _updatePendingSearchCenterFromMap() async {
    final controller = _mapController;
    if (controller == null) return;
    final bounds = await controller.getVisibleRegion();
    if (!mounted) return;
    _pendingSearchCenterLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    _pendingSearchCenterLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    if (!_showSearchHereButton && _currentTab == _MainTab.map) setState(() => _showSearchHereButton = true);
  }

  void _scheduleSelectionIfNeeded(List<_MachineView> views) {
    final targetId = _pendingMachineId ?? (!_didHandleInitialMachine ? widget.initialMachineId : null);
    if (targetId == null || targetId.isEmpty || _isSchedulingPendingSelection) return;
    final index = views.indexWhere((e) => e.machine.id == targetId);
    if (index == -1) return;
    _isSchedulingPendingSelection = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final target = views[index];
      setState(() { _selectedMachineId = target.machine.id; _pendingMachineId = null; _didHandleInitialMachine = true; _showDetailPanel = true; });
      await _moveCameraToMachine(target.machine);
      _isSchedulingPendingSelection = false;
    });
  }

  Future<void> _ensureMarkerCached({required String manufacturer, required bool selected}) async {
    final key = MapMarkerFactory.cacheKey(manufacturer: manufacturer, selected: selected);
    if (_markerCache.containsKey(key) || _loadingMarkerKeys.contains(key)) return;
    _loadingMarkerKeys.add(key);
    try {
      final descriptor = await MapMarkerFactory.createMachineMarker(manufacturer: manufacturer, selected: selected);
      if (!mounted) return;
      setState(() => _markerCache[key] = descriptor);
    } finally { _loadingMarkerKeys.remove(key); }
  }

  BitmapDescriptor _markerDescriptor({required String manufacturer, required bool selected}) {
    final key = MapMarkerFactory.cacheKey(manufacturer: manufacturer, selected: selected);
    return _markerCache[key] ?? BitmapDescriptor.defaultMarker;
  }

  Set<Marker> _buildMarkers(List<_MachineView> views) => views.map<Marker>((view) {
    final selected = _selectedMachineId == view.machine.id;
    final displayProducts = view.displayProducts;
    final snippet = displayProducts.isEmpty ? 'ドリンク未登録' : displayProducts.take(2).join(' / ');
    return Marker(
      markerId: MarkerId(view.machine.id),
      position: LatLng(view.machine.lat, view.machine.lng),
      icon: _markerDescriptor(manufacturer: view.machine.manufacturer, selected: selected),
      infoWindow: InfoWindow(title: view.machine.name, snippet: view.isEstimated ? '$snippet かも' : snippet),
      onTap: () async { if (!mounted) return; setState(() { _selectedMachineId = view.machine.id; _showDetailPanel = false; }); await _moveCameraToMachine(view.machine); await _scrollToMachineCard(view.machine.id); },
    );
  }).toSet();

  Future<void> _showLoginRequiredDialog() async {
    await LoginRequiredSheet.show(context);
    if (!mounted) return;
    setState(() => _isLoggedIn = FirebaseAuth.instance.currentUser != null);
    await _loadDistancePreferenceIfNeeded(force: true);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen()));
  }

  Future<void> _openRegister() async {
    if (!_isLoggedIn) { await _showLoginRequiredDialog(); return; }
    final result = await Navigator.of(context).push<dynamic>(MaterialPageRoute<dynamic>(builder: (_) => const RegisterVendingMachineScreen()));
    if (!mounted || result == null) return;
    String? machineId;
    if (result is String && result.trim().isNotEmpty) machineId = result.trim();
    else if (result is Map) { final created = result['created'] == true || result['machineId'] != null; if (created) machineId = result['machineId']?.toString().trim(); }
    if (machineId == null || machineId.isEmpty) return;
    setState(() { _currentTab = _MainTab.map; _selectedMachineId = machineId; _pendingMachineId = machineId; _selectedKeyword = ''; _selectedMood = null; _selectedTag = null; _showDetailPanel = true; });
    _searchController.clear();
  }

  Future<void> _openMachineDetail(VendingMachine machine) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(builder: (_) => MachineDetailScreen(machine: machine, currentLat: _currentLat, currentLng: _currentLng)));
    if (!mounted) return;
    setState(() { _selectedMachineId = machine.id; _showDetailPanel = true; });
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    await _moveCameraToMachine(machine);
    await _scrollToMachineCard(machine.id);
  }

  Future<void> _openFavoriteDrinkPicker() async {
    if (!_isLoggedIn) { await _showLoginRequiredDialog(); return; }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { await _showLoginRequiredDialog(); return; }
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final favorites = _readStringList((snapshot.data() ?? <String, dynamic>{})['favoriteDrinkNames']);
      if (!mounted) return;
      if (favorites.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('お気に入りドリンクがまだ登録されていません。'))); return; }
      final products = _resolveFavoriteProducts(favorites);
      final selected = await showModalBottomSheet<String>(context: context, backgroundColor: Colors.transparent, builder: (context) {
        final itemCount = products.isNotEmpty ? products.length : favorites.length;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE3E7EB), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 14),
            Row(children: [const Expanded(child: Text('お気に入りから探す', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded))]),
            const SizedBox(height: 12),
            Flexible(child: ListView.separated(shrinkWrap: true, itemCount: itemCount, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) {
              final name = products.isNotEmpty ? products[index].name : favorites[index];
              final subtitle = products.isNotEmpty ? '${products[index].manufacturer} ・ ${products[index].category}' : 'お気に入り登録済み';
              return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => Navigator.of(context).pop(name), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF9FBFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3E7EB))), child: Row(children: [const Icon(Icons.favorite_rounded, size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF60707A), fontWeight: FontWeight.w600))])), const Icon(Icons.chevron_right_rounded)]))));
            })),
          ])),
        );
      });
      if (selected == null || selected.trim().isEmpty) return;
      _applyFavoriteDrinkSearch(selected);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('お気に入り取得に失敗しました: $e')));
    }
  }

  void _applyFavoriteDrinkSearch(String drinkName) {
    _searchController.text = drinkName;
    setState(() { _selectedKeyword = drinkName.trim(); _selectedMachineId = null; _showDetailPanel = false; _currentTab = _MainTab.map; });
  }

  Future<void> _showFilterSheet() async => _openMoodSheet();

  Future<void> _openMoodSheet() async {
    String? tempMood = _selectedMood;
    String? tempTag = _selectedTag;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.78, minChildSize: 0.52, maxChildSize: 0.92, builder: (context, controller) => StatefulBuilder(builder: (context, setSheetState) => Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))), child: SafeArea(top: false, child: Column(children: [
      const SizedBox(height: 10),
      Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE3E7EB), borderRadius: BorderRadius.circular(999))),
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 12), child: Row(children: [const Expanded(child: Text('気分 / 絞り込み', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF334148)))), IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded))])),
      Expanded(child: SingleChildScrollView(controller: controller, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('気分', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334148))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _moodChips.map((mood) { final selected = tempMood == mood; return ChoiceChip(label: Text(mood), selected: selected, onSelected: (_) => setSheetState(() => tempMood = selected ? null : mood)); }).toList()),
        const SizedBox(height: 20),
        const Text('タグ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334148))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _filterTags.map((tag) { final selected = tempTag == tag; return FilterChip(label: Text(tag), selected: selected, onSelected: (_) => setSheetState(() => tempTag = selected ? null : tag)); }).toList()),
      ]))),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: Row(children: [Expanded(child: OutlinedButton(onPressed: () { Navigator.of(context).pop(); if (!mounted) return; setState(() { _selectedMood = null; _selectedTag = null; _selectedMachineId = null; _showDetailPanel = false; }); }, child: const Text('クリア'))), const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: () { Navigator.of(context).pop(); if (!mounted) return; setState(() { _selectedMood = tempMood; _selectedTag = tempTag; _selectedMachineId = null; _showDetailPanel = false; }); }, child: const Text('適用')))])),
    ]))))));
  }

  Widget _buildMapTab() {
    return StreamBuilder<List<VendingMachine>>(stream: FirestoreService.instance.watchMachines(), builder: (context, snapshot) {
      final machines = snapshot.data ?? const <VendingMachine>[];
      final views = _buildViews(machines);
      _latestViews = views;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final view in views) { _ensureMarkerCached(manufacturer: view.machine.manufacturer, selected: false); _ensureMarkerCached(manufacturer: view.machine.manufacturer, selected: true); }
      });
      final selectedView = _selectedView(views);
      final panelMode = _panelMode(views);
      _scheduleSelectionIfNeeded(views);
      return Column(children: [
        Expanded(flex: 10, child: _MapCard(child: Stack(children: [
          Positioned.fill(child: GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(_currentLat ?? 35.681236, _currentLng ?? 139.767125), zoom: _currentLat != null && _currentLng != null ? _zoomForDistance(_selectedDistanceMeters) : 14.0),
            onMapCreated: (controller) async { _mapController = controller; if (_currentLat != null && _currentLng != null && !_didMoveToCurrentLocationOnce && _selectedMachineId == null) { _didMoveToCurrentLocationOnce = true; await _moveCamera(LatLng(_currentLat!, _currentLng!), _zoomForDistance(_selectedDistanceMeters)); } },
            onCameraMove: (position) { if (_currentTab != _MainTab.map) return; _pendingSearchCenterLat = position.target.latitude; _pendingSearchCenterLng = position.target.longitude; if (!_showSearchHereButton) setState(() => _showSearchHereButton = true); },
            onCameraIdle: _updatePendingSearchCenterFromMap,
            onTap: (_) { if (_selectedMachineId == null) return; setState(() { _selectedMachineId = null; _showDetailPanel = false; }); },
            myLocationEnabled: true, myLocationButtonEnabled: false, zoomControlsEnabled: false, mapToolbarEnabled: false, markers: _buildMarkers(views),
          )),
          if (_showSearchHereButton) Positioned(top: 14, left: 0, right: 0, child: Center(child: _SearchHereButton(onPressed: _applySearchHere))),
          Positioned(right: 24, bottom: 84, child: _CircleMapButton(icon: Icons.my_location_rounded, isLoading: _isLoadingCurrentLocation, onPressed: _moveToCurrentLocation)),
          Positioned(right: 24, bottom: 20, child: _RegisterMapButton(isLoggedIn: _isLoggedIn, onPressed: _openRegister)),
        ]))),
        const SizedBox(height: 12),
        Expanded(flex: 8, child: _PanelCard(child: _buildMapPanel(views: views, selectedView: selectedView, panelMode: panelMode))),
      ]);
    });
  }

  Widget _buildMapPanel({required List<_MachineView> views, required _MachineView? selectedView, required _MapPanelMode panelMode}) {
    switch (panelMode) {
      case _MapPanelMode.idle: return _MapIdlePanel(onTapFilter: _showFilterSheet);
      case _MapPanelMode.list: return _MachineListPanel(views: views, selectedMachineId: _selectedMachineId, distanceLabelBuilder: _distanceLabel, scrollController: _machineListScrollController, keyForMachine: _keyForMachine, onTapMachine: (view) async { setState(() { _selectedMachineId = view.machine.id; _showDetailPanel = true; }); await _moveCameraToMachine(view.machine); });
      case _MapPanelMode.detail:
        if (selectedView == null) return const _EmptyPanel(title: '見つかりませんでした', message: '自販機情報がありません。');
        return _MachineDetailPanel(view: selectedView, distanceLabel: _distanceLabel(selectedView.distanceMeters), onTapClose: () => setState(() { _selectedMachineId = null; _showDetailPanel = false; }), onTapDetail: () async => _openMachineDetail(selectedView.machine));
    }
  }

  Widget _buildNonMapTabContent() {
    late final Widget child;
    switch (_currentTab) {
      case _MainTab.favorites: child = const FavoriteDrinksScreen(); break;
      case _MainTab.myPage: child = MyPageScreen(isLoggedIn: _isLoggedIn, openTitleListOnOpen: _openTitleListOnMyPageOpen); break;
      case _MainTab.map: child = const SizedBox.shrink(); break;
    }
    if (_currentTab == _MainTab.myPage && _openTitleListOnMyPageOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (!mounted) return; setState(() => _openTitleListOnMyPageOpen = false); });
    }
    return _PanelCard(child: child, padding: EdgeInsets.zero);
  }

  @override
  Widget build(BuildContext context) {
    final isMapTab = _currentTab == _MainTab.map;
    return Scaffold(
      backgroundColor: _appBackground,
      body: SafeArea(child: Column(children: [
        if (isMapTab) ...[
          _TopHeader(controller: _searchController, selectedDistanceMeters: _selectedDistanceMeters, hasActiveFilters: _selectedMood != null || _selectedTag != null, isSavingDistancePreference: _isSavingDistancePreference, onTapNotifications: _openNotifications, onTapFilters: _showFilterSheet, onTapFavoriteSearch: _openFavoriteDrinkPicker, onSelectedDistance: (value) async {
            final sanitized = _sanitizeDistance(value);
            setState(() { _selectedDistanceMeters = sanitized; _selectedMachineId = null; _showDetailPanel = false; });
            await _saveDistancePreference(sanitized);
            if (_currentLat != null && _currentLng != null && _currentTab == _MainTab.map && _selectedMachineId == null) await _moveCamera(LatLng(_currentLat!, _currentLng!), _zoomForDistance(_selectedDistanceMeters));
          }),
          const SizedBox(height: 10),
        ],
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: isMapTab ? _buildMapTab() : _buildNonMapTabContent())),
      ])),
      bottomNavigationBar: SafeArea(top: false, child: Container(margin: const EdgeInsets.fromLTRB(12, 0, 12, 12), padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFDCE9F3)), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))]), child: Column(mainAxisSize: MainAxisSize.min, children: [const _AdBanner(), const SizedBox(height: 10), _BottomNavBar(currentTab: _currentTab, onChanged: (tab) { FocusScope.of(context).unfocus(); setState(() => _currentTab = tab); })]))),
    );
  }
}

class _MachineView {
  const _MachineView({required this.machine, required this.confirmedProductNames, required this.estimatedProductNames, required this.distanceMeters});
  final VendingMachine machine;
  final List<String> confirmedProductNames;
  final List<String> estimatedProductNames;
  final double? distanceMeters;
  bool get isEstimated => confirmedProductNames.isEmpty && estimatedProductNames.isNotEmpty;
  List<String> get displayProducts => confirmedProductNames.isNotEmpty ? confirmedProductNames : estimatedProductNames;
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.controller, required this.selectedDistanceMeters, required this.hasActiveFilters, required this.isSavingDistancePreference, required this.onTapNotifications, required this.onTapFilters, required this.onTapFavoriteSearch, required this.onSelectedDistance});
  final TextEditingController controller;
  final int selectedDistanceMeters;
  final bool hasActiveFilters;
  final bool isSavingDistancePreference;
  final VoidCallback onTapNotifications;
  final VoidCallback onTapFilters;
  final VoidCallback onTapFavoriteSearch;
  final ValueChanged<int> onSelectedDistance;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), decoration: BoxDecoration(color: const Color(0xFFEAF6FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD5E8F5))), child: Row(children: [const Text('自販機ナビ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF334148))), const Spacer(), InkWell(onTap: onTapNotifications, borderRadius: BorderRadius.circular(999), child: Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFDCE9F3))), alignment: Alignment.center, child: const Icon(Icons.notifications_none_rounded, size: 19)))])),
      const SizedBox(height: 10),
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE3E7EB)), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 5))]), child: Row(children: [
        Expanded(child: TextField(controller: controller, textInputAction: TextInputAction.search, decoration: InputDecoration(hintText: '飲みたいドリンクを検索', prefixIcon: const Icon(Icons.search_rounded), isDense: true, filled: true, fillColor: const Color(0xFFF7FBFC), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE3E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE3E7EB)))))),
        const SizedBox(width: 8),
        SizedBox(width: 78, height: 46, child: FilledButton.tonal(onPressed: onTapFilters, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(hasActiveFilters ? '絞込中' : '気分', maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 8),
        InkWell(onTap: onTapFavoriteSearch, borderRadius: BorderRadius.circular(16), child: Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFF7FBFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE3E7EB))), alignment: Alignment.center, child: const Icon(Icons.favorite_rounded, size: 19))),
        const SizedBox(width: 8),
        PopupMenuButton<int>(onSelected: onSelectedDistance, itemBuilder: (_) => _MainShellScreenState._distanceOptions.map((e) => PopupMenuItem<int>(value: e, child: Text('${e}m'))).toList(), child: Container(width: 82, height: 46, decoration: BoxDecoration(color: const Color(0xFFF7FBFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE3E7EB))), alignment: Alignment.center, child: isSavingDistancePreference ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text('${selectedDistanceMeters}m', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF334148))))),
      ])),
    ]));
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: child,
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

class _SearchHereButton extends StatelessWidget {
  const _SearchHereButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE3E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 18),
              SizedBox(width: 6),
              Text(
                'この場所で探す',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334148),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleMapButton extends StatelessWidget {
  const _CircleMapButton({
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE3E7EB)),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Icon(icon),
        ),
      ),
    );
  }
}

class _RegisterMapButton extends StatelessWidget {
  const _RegisterMapButton({
    required this.isLoggedIn,
    required this.onPressed,
  });

  final bool isLoggedIn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334148),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapIdlePanel extends StatelessWidget {
  const _MapIdlePanel({
    required this.onTapFilter,
  });

  final VoidCallback onTapFilter;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '近くの自販機を探す',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '飲みたいドリンクから検索したり、気分 / タグで絞り込めます。',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF60707A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          const _SimpleInfoBlock(
            title: '絞り込みを使う',
            message: 'スッキリ・甘い・眠気覚ましなどから探せます。',
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTapFilter,
              child: const Text('気分 / タグを選ぶ'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineListPanel extends StatelessWidget {
  const _MachineListPanel({
    required this.views,
    required this.selectedMachineId,
    required this.distanceLabelBuilder,
    required this.scrollController,
    required this.keyForMachine,
    required this.onTapMachine,
  });

  final List<_MachineView> views;
  final String? selectedMachineId;
  final String Function(double? meters) distanceLabelBuilder;
  final ScrollController scrollController;
  final GlobalKey Function(String machineId) keyForMachine;
  final Future<void> Function(_MachineView view) onTapMachine;

  @override
  Widget build(BuildContext context) {
    if (views.isEmpty) {
      return const _EmptyPanel(
        title: '見つかりませんでした',
        message: '条件に合う自販機がありません。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '検索結果 ${views.length}件',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334148),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: views.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final view = views[index];
              final selected = selectedMachineId == view.machine.id;

              return KeyedSubtree(
                key: keyForMachine(view.machine.id),
                child: _MachineRowCard(
                  title: view.machine.name,
                  subtitle:
                  '${view.machine.manufacturer} ・ ${distanceLabelBuilder(view.distanceMeters)}',
                  products: view.displayProducts,
                  isEstimated: view.isEstimated,
                  selected: selected,
                  accentColor: _manufacturerAccentColorOf(
                    view.machine.manufacturer,
                  ),
                  onTap: () => onTapMachine(view),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MachineDetailPanel extends StatelessWidget {
  const _MachineDetailPanel({
    required this.view,
    required this.distanceLabel,
    required this.onTapClose,
    required this.onTapDetail,
  });

  final _MachineView view;
  final String distanceLabel;
  final VoidCallback onTapClose;
  final Future<void> Function() onTapDetail;

  Color _manufacturerAccentColor(String manufacturer) {
    switch (manufacturer.trim()) {
      case 'コカコーラ':
      case 'コカ・コーラ':
        return const Color(0xFFE53935);
      case 'サントリー':
        return const Color(0xFF1E88E5);
      case '伊藤園':
        return const Color(0xFF43A047);
      case 'キリン':
        return const Color(0xFFF9A825);
      case 'アサヒ':
        return const Color(0xFFFB8C00);
      case '大塚製薬':
        return const Color(0xFF3949AB);
      case 'AQUO':
        return const Color(0xFF00ACC1);
      case 'ダイドー':
        return const Color(0xFF8E24AA);
      default:
        return const Color(0xFF60707A);
    }
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFF60707A),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334148),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productChip(String name, bool isEstimated, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isEstimated
            ? const Color(0xFFF7F2E8)
            : accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isEstimated
              ? const Color(0xFFE4D3AF)
              : accentColor.withOpacity(0.22),
        ),
      ),
      child: Text(
        isEstimated ? '$name かも' : name,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334148),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _manufacturerAccentColor(view.machine.manufacturer);
    final locationName = (view.machine.locationName ?? '').trim();
    final hasLocation = locationName.isNotEmpty;
    final products = view.displayProducts;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              view.machine.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334148),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: accentColor.withOpacity(0.22),
                                ),
                              ),
                              child: Text(
                                view.machine.manufacturer,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onTapClose,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FBFC),
                            borderRadius: BorderRadius.circular(999),
                            border:
                            Border.all(color: const Color(0xFFE3E7EB)),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF60707A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(
                        icon: Icons.near_me_rounded,
                        label: distanceLabel,
                      ),
                      if (hasLocation)
                        _infoChip(
                          icon: Icons.place_outlined,
                          label: locationName,
                        ),
                      _infoChip(
                        icon: Icons.local_drink_outlined,
                        label: products.isEmpty ? 'ドリンク未登録' : '${products.length}件',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ドリンク',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (products.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FBFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE3E7EB),
                        ),
                      ),
                      child: const Text(
                        'まだドリンク情報は登録されていません。',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF60707A),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: products
                          .map(
                            (name) => _productChip(
                          name,
                          view.isEstimated,
                          accentColor,
                        ),
                      )
                          .toList(),
                    ),
                  if (view.isEstimated) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '※ 推定候補を含んでいます',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A6A2F),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onTapClose,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            side: const BorderSide(
                              color: Color(0xFFE3E7EB),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('閉じる'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onTapDetail,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('詳細を見る'),
                        ),
                      ),
                    ],
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

class _MachineRowCard extends StatefulWidget {
  const _MachineRowCard({
    required this.title,
    required this.subtitle,
    required this.products,
    required this.isEstimated,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<String> products;
  final bool isEstimated;
  final bool selected;
  final Color accentColor;
  final Future<void> Function() onTap;

  @override
  State<_MachineRowCard> createState() => _MachineRowCardState();
}

class _MachineRowCardState extends State<_MachineRowCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
      },
      onTapUp: (_) async {
        setState(() => _pressed = false);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await widget.onTap();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : (selected ? 1.02 : 1.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color:
            selected ? widget.accentColor.withOpacity(0.10) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? widget.accentColor
                  : const Color(0xFFE3E7EB),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: widget.accentColor.withOpacity(0.20),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              const BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ]
                : const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 8 : 6,
                height: 100,
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF60707A),
                        ),
                      ),
                      if (widget.products.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.products.take(4).map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isEstimated
                                    ? const Color(0xFFF7F2E8)
                                    : const Color(0xFFF7FBFC),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                widget.isEstimated ? '$name かも' : name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleInfoBlock extends StatelessWidget {
  const _SimpleInfoBlock({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

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
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF60707A),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _SimpleInfoBlock(
        title: title,
        message: message,
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
    required this.currentTab,
    required this.onChanged,
  });

  final _MainTab currentTab;
  final ValueChanged<_MainTab> onChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = <({IconData icon, String label, _MainTab tab})>[
      (icon: Icons.map_rounded, label: 'マップ', tab: _MainTab.map),
      (icon: Icons.favorite_rounded, label: 'お気に入り', tab: _MainTab
          .favorites),
      (icon: Icons.person_rounded, label: 'マイページ', tab: _MainTab.myPage),
    ];

    return SizedBox(
      height: 64,
      child: Row(
        children: List<Widget>.generate(tabs.length, (index) {
          final item = tabs[index];
          final selected = currentTab == item.tab;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 8),
              child: InkWell(
                onTap: () => onChanged(item.tab),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme
                        .of(context)
                        .colorScheme
                        .primary
                        : const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: selected ? Colors.white : Colors.black54,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
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


import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/vending_machine.dart';
import '../utils/distance_util.dart';
import 'auth_gate.dart';
import 'favorite_drinks_screen.dart';
import 'login_screen.dart';
import 'machine_create_screen.dart';
import 'machine_detail_screen.dart';
import 'my_page_screen.dart';
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
  static const Color _appBackground = Color(0xFFD6ECFF);

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

  int _currentTabIndex = 0;
  int _selectedMachineIndex = 0;
  int _selectedDistanceMeters = 100;

  String _selectedKeyword = '';
  String? _selectedMood;
  String? _selectedTag;
  String? _selectedFavoriteDrink;

  double? _currentLat;
  double? _currentLng;

  List<VendingMachine> _machines = <VendingMachine>[];

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

  static const List<int> _distanceOptions = <int>[
    50,
    100,
    300,
    500,
  ];

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
      // 現在地が取れなくても継続
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
        if (mounted) {
          setState(() {
            _selectedDistanceMeters = _sanitizeDistanceMeters(_selectedDistanceMeters);
          });
        }
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
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

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
      // 保存失敗でもUIは続行
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingDistancePreference = false;
      });
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
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _jumpToInitialMachineIfNeeded();
          await _moveCameraToSelectedMachine(animated: false);
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
    });

    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _moveCameraToSelectedMachine(animated: true);
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

    return false;
  }

  bool _matchesTag(VendingMachine machine, String tag) {
    final normalizedTag = _normalize(tag);

    for (final value in _productTagsOf(machine)) {
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

    final c = 2 * math.atan2(math.sqrt(a.toDouble()), math.sqrt(1 - a.toDouble()));
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
      return _MachineViewData(
        machine: machine,
        productNames: _productNamesOf(machine),
        productTags: _productTagsOf(machine),
        distanceMeters: _distanceMetersToMachine(machine),
      );
    }).toList();

    filtered.sort((a, b) {
      final aHasProducts = a.productNames.isNotEmpty;
      final bHasProducts = b.productNames.isNotEmpty;

      if (aHasProducts != bHasProducts) {
        return aHasProducts ? -1 : 1;
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
    if (selected != null) {
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
      final selected = index == _selectedMachineIndex;

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
          snippet: view.productNames.take(2).join(' / '),
        ),
        onTap: () async {
          setState(() {
            _selectedMachineIndex = index;
            _currentTabIndex = 0;
          });
          await _moveCameraToSelectedMachine(animated: true);
        },
      );
    }).toSet();
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
    );

    if (!mounted) return;
    setState(() {
      _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    });

    await _loadDistancePreferenceIfNeeded(force: true);
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
        builder: (_) => const MachineCreateScreen(),
      ),
    );

    if (result == null || result['created'] != true) return;

    final createdMachineId = result['machineId']?.toString();
    if (createdMachineId == null || createdMachineId.isEmpty) return;

    await Future<void>.delayed(const Duration(milliseconds: 300));

    final views = _machineViews;
    final index = views.indexWhere((e) => e.machine.id == createdMachineId);
    if (index == -1) return;

    setState(() {
      _selectedMachineIndex = index;
      _currentTabIndex = 0;
    });

    await _moveCameraToSelectedMachine(animated: true);

    if (result['openDetail'] == true && mounted) {
      final selected = _selectedView;
      if (selected != null) {
        await _openDetail(selected);
      }
    }
  }

  Future<void> _openDetail(_MachineViewData view) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MachineDetailScreen(machine: view.machine),
      ),
    );

    if (changed == true) {
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
    });
  }

  void _applyFavoriteDrinkSearch(String drinkName) {
    _searchController.text = drinkName;
    setState(() {
      _selectedKeyword = drinkName.trim();
      _selectedFavoriteDrink = drinkName.trim();
      _selectedMachineIndex = 0;
      _currentTabIndex = 0;
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
    });
  }

  Future<void> _applyDistanceSelection(int value) async {
    final sanitized = _sanitizeDistanceMeters(value);

    if (!mounted) return;
    setState(() {
      _selectedDistanceMeters = sanitized;
      _selectedMachineIndex = 0;
      _currentTabIndex = 0;
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
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

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
                      itemCount: favorites.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
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

  Future<void> _openFilterSheet() async {
    String? tempMood = _selectedMood;
    String? tempTag = _selectedTag;
    int tempDistance = _selectedDistanceMeters;

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
                      '距離',
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
                      children: _distanceOptions.map((meters) {
                        final selected = tempDistance == meters;
                        return ChoiceChip(
                          label: Text('${meters}m'),
                          selected: selected,
                          onSelected: (_) {
                            setSheetState(() {
                              tempDistance = meters;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
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
                            onPressed: () async {
                              Navigator.of(context).pop();
                              if (!mounted) return;
                              setState(() {
                                _selectedMood = null;
                                _selectedTag = null;
                                _selectedDistanceMeters = 100;
                                _selectedMachineIndex = 0;
                              });
                              await _saveDistancePreference(100);
                            },
                            child: const Text('クリア'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              if (!mounted) return;
                              setState(() {
                                _selectedMood = tempMood;
                                _selectedTag = tempTag;
                                _selectedDistanceMeters =
                                    _sanitizeDistanceMeters(tempDistance);
                                _selectedMachineIndex = 0;
                                _currentTabIndex = 0;
                              });
                              await _saveDistancePreference(
                                _sanitizeDistanceMeters(tempDistance),
                              );
                            },
                            child: const Text('適用'),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final selected = _selectedView;

    return Scaffold(
      backgroundColor: _appBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _TopSearchCard(
              controller: _searchController,
              selectedKeyword: _selectedKeyword,
              selectedMood: _selectedMood,
              selectedTag: _selectedTag,
              selectedFavoriteDrink: _selectedFavoriteDrink,
              selectedDistanceMeters: _selectedDistanceMeters,
              distanceOptions: _distanceOptions,
              isSavingDistancePreference: _isSavingDistancePreference,
              onSubmitted: _applySearch,
              onClear: _clearSearch,
              onTapFilter: _openFilterSheet,
              onTapNotifications: _openNotifications,
              onTapFavoriteSearch: _openFavoriteDrinkPicker,
              onDistanceChanged: _applyDistanceSelection,
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
                      content: _buildTabBody(selected),
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

  Widget _buildTabBody(_MachineViewData? selected) {
    if (_currentTabIndex == 0) {
      if (selected == null) {
        return _EmptyState(
          title: '見つかりませんでした',
          message: _selectedMood == null &&
              _selectedTag == null &&
              _selectedKeyword.isEmpty
              ? 'まだ自販機データがありません。'
              : '条件に合う自販機がありません。',
        );
      }

      if (!_isLoggedIn || FirebaseAuth.instance.currentUser == null) {
        return _HomePanelContent(
          selectedView: selected,
          machineViews: _machineViews,
          selectedMachineIndex: _selectedMachineIndex,
          favoriteDrinkNames: const <String>[],
          onSelectMachine: (index) async {
            setState(() {
              _selectedMachineIndex = index;
            });
            await _moveCameraToSelectedMachine(animated: true);
          },
          onOpenDetail: _openDetail,
          normalize: _normalize,
          distanceLabelBuilder: _distanceLabel,
        );
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final favoriteDrinkNames = _readStringList(data['favoriteDrinkNames']);

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
              });
            });
          }

          return _HomePanelContent(
            selectedView: selected,
            machineViews: _machineViews,
            selectedMachineIndex: _selectedMachineIndex,
            favoriteDrinkNames: favoriteDrinkNames,
            onSelectMachine: (index) async {
              setState(() {
                _selectedMachineIndex = index;
              });
              await _moveCameraToSelectedMachine(animated: true);
            },
            onOpenDetail: _openDetail,
            normalize: _normalize,
            distanceLabelBuilder: _distanceLabel,
          );
        },
      );
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
    required this.productNames,
    required this.productTags,
    required this.distanceMeters,
  });

  final VendingMachine machine;
  final List<String> productNames;
  final List<String> productTags;
  final double? distanceMeters;
}

class _TopSearchCard extends StatelessWidget {
  const _TopSearchCard({
    required this.controller,
    required this.selectedKeyword,
    required this.selectedMood,
    required this.selectedTag,
    required this.selectedFavoriteDrink,
    required this.selectedDistanceMeters,
    required this.distanceOptions,
    required this.isSavingDistancePreference,
    required this.onSubmitted,
    required this.onClear,
    required this.onTapFilter,
    required this.onTapNotifications,
    required this.onTapFavoriteSearch,
    required this.onDistanceChanged,
  });

  final TextEditingController controller;
  final String selectedKeyword;
  final String? selectedMood;
  final String? selectedTag;
  final String? selectedFavoriteDrink;
  final int selectedDistanceMeters;
  final List<int> distanceOptions;
  final bool isSavingDistancePreference;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onTapFilter;
  final VoidCallback onTapNotifications;
  final VoidCallback onTapFavoriteSearch;
  final ValueChanged<int> onDistanceChanged;

  @override
  Widget build(BuildContext context) {
    final hasFilter =
        selectedMood != null || selectedTag != null || selectedFavoriteDrink != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '自販機ナビ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334148),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onTapNotifications,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE3E7EB)),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              [
                '距離: ${selectedDistanceMeters}m',
                if (selectedFavoriteDrink != null) 'お気に入り: $selectedFavoriteDrink',
                if (selectedMood != null) '気分: $selectedMood',
                if (selectedTag != null) 'タグ: $selectedTag',
              ].join(' / '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF60707A),
              ),
            ),
          ),
          if (isSavingDistancePreference) ...[
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '距離設定を保存中...',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF60707A),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: onSubmitted,
                  decoration: InputDecoration(
                    hintText: '飲みたいドリンクで探す',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: selectedKeyword.isNotEmpty
                        ? IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onTapFilter,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(hasFilter ? '絞込中' : '絞込'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTapFavoriteSearch,
                  icon: const Icon(Icons.favorite_rounded, size: 18),
                  label: const Text('お気に入りから探す'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE3E7EB)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedDistanceMeters,
                    items: distanceOptions.map((meters) {
                      return DropdownMenuItem<int>(
                        value: meters,
                        child: Text('${meters}m'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      onDistanceChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({
    required this.initialCameraPosition,
    required this.markers,
    required this.onMapCreated,
  });

  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final ValueChanged<GoogleMapController> onMapCreated;

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

class _HomePanelContent extends StatelessWidget {
  const _HomePanelContent({
    required this.selectedView,
    required this.machineViews,
    required this.selectedMachineIndex,
    required this.favoriteDrinkNames,
    required this.onSelectMachine,
    required this.onOpenDetail,
    required this.normalize,
    required this.distanceLabelBuilder,
  });

  final _MachineViewData selectedView;
  final List<_MachineViewData> machineViews;
  final int selectedMachineIndex;
  final List<String> favoriteDrinkNames;
  final Future<void> Function(int index) onSelectMachine;
  final Future<void> Function(_MachineViewData view) onOpenDetail;
  final String Function(String value) normalize;
  final String Function(double? meters) distanceLabelBuilder;

  List<String> _matchingFavorites(List<String> products) {
    final favoriteMap = <String, String>{
      for (final item in favoriteDrinkNames) normalize(item): item,
    };

    final result = <String>[];
    final used = <String>{};

    for (final product in products) {
      final key = normalize(product);
      if (favoriteMap.containsKey(key) && !used.contains(key)) {
        result.add(product);
        used.add(key);
      }
    }

    return result;
  }

  bool _hasFavoriteMatch(List<String> products) {
    return _matchingFavorites(products).isNotEmpty;
  }

  List<_MachineViewData> _sortedMachineViews() {
    final copied = List<_MachineViewData>.from(machineViews);

    copied.sort((a, b) {
      final aFavorite = _hasFavoriteMatch(a.productNames);
      final bFavorite = _hasFavoriteMatch(b.productNames);
      if (aFavorite != bFavorite) {
        return aFavorite ? -1 : 1;
      }

      final aHasProducts = a.productNames.isNotEmpty;
      final bHasProducts = b.productNames.isNotEmpty;
      if (aHasProducts != bHasProducts) {
        return aHasProducts ? -1 : 1;
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

    return copied;
  }

  @override
  Widget build(BuildContext context) {
    final sortedMachines = _sortedMachineViews();
    final visibleMachines = sortedMachines.take(6).toList();
    final selectedMachine = selectedView.machine;
    final selectedFavorites = _matchingFavorites(selectedView.productNames);
    final selectedFavoriteKeys = selectedFavorites.map(normalize).toSet();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '選択中の自販機',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
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
                  color: selectedFavorites.isNotEmpty
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
                          selectedMachine.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (selectedFavorites.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2D9),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFD18B)),
                          ),
                          child: const Text(
                            'お気に入りあり',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8A5A00),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'メーカー: ${selectedMachine.manufacturer}',
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
                  if ((selectedMachine.locationName ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      selectedMachine.locationName!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF60707A),
                      ),
                    ),
                  ],
                  if ((selectedMachine.note ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '備考: ${selectedMachine.note!}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60707A),
                      ),
                    ),
                  ],
                  if (selectedFavorites.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'お気に入り一致',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8A5A00),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedFavorites.map((product) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2D9),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFD18B)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                size: 14,
                                color: Color(0xFFB56B00),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                product,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF8A5A00),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (selectedView.productNames.isEmpty)
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
                      children: selectedView.productNames.map((product) {
                        final isFavorite =
                        selectedFavoriteKeys.contains(normalize(product));

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isFavorite
                                ? const Color(0xFFFFF2D9)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isFavorite
                                  ? const Color(0xFFFFD18B)
                                  : const Color(0xFFE3E7EB),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFavorite) ...[
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 13,
                                  color: Color(0xFFB56B00),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                product,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isFavorite
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: isFavorite
                                      ? const Color(0xFF8A5A00)
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '一覧',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...List<Widget>.generate(visibleMachines.length, (index) {
            final view = visibleMachines[index];
            final machine = view.machine;
            final actualIndex = machineViews.indexOf(view);
            final selected = actualIndex == selectedMachineIndex;
            final matchingFavorites = _matchingFavorites(view.productNames);
            final hasFavorite = matchingFavorites.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onSelectMachine(actualIndex),
                onLongPress: () => onOpenDetail(view),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(10),
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
                    children: [
                      Icon(
                        hasFavorite
                            ? Icons.favorite_rounded
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    machine.manufacturer,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF60707A),
                                    ),
                                  ),
                                ),
                                if (hasFavorite) ...[
                                  const SizedBox(width: 8),
                                  Container(
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
                                  ),
                                ],
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
                            if (view.productNames.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                view.productNames.take(2).join(' / '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF60707A),
                                ),
                              ),
                            ],
                            if (hasFavorite) ...[
                              const SizedBox(height: 6),
                              Text(
                                '一致: ${matchingFavorites.join(' / ')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8A5A00),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/app_progress.dart';
import '../models/drink_item.dart';
import '../models/machine_create_result.dart';
import '../models/vending_machine.dart';
import '../repositories/mock_vending_repository.dart';
import '../services/firestore_service.dart';
import '../services/local_progress_service.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../utils/distance_util.dart';
import 'machine_create_screen.dart';
import 'machine_detail_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final MockVendingRepository _mockRepository = const MockVendingRepository();
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<VendingMachine>>? _machinesSubscription;
  GoogleMapController? _mapController;

  BitmapDescriptor? _normalMarkerIcon;
  BitmapDescriptor? _selectedMarkerIcon;
  BitmapDescriptor? _freshMarkerIcon;
  BitmapDescriptor? _oldMarkerIcon;

  int _currentIndex = 0;
  bool _mapExpanded = false;
  bool _isLoadingProgress = true;
  bool _isLoadingMachines = true;
  bool _isPreparingMarkers = true;
  bool _isFetchingLocation = true;

  String _microCopy = '今何を飲みたい気分？';
  String _selectedKeyword = '';
  int _selectedMachineIndex = 0;

  final List<String> _selectedTags = <String>[];
  AppProgress _progress = AppProgress.initial();

  List<VendingMachine> _liveMachines = <VendingMachine>[];
  Position? _currentPosition;

  final List<String> _quickCategories = <String>[
    'コーヒー',
    'お茶',
    '炭酸',
    '水',
  ];

  final List<String> _popularKeywords = <String>[
    'お〜いお茶',
    '綾鷹',
    'ボス',
    'ジョージア',
    '午後の紅茶',
  ];

  final List<String> _filterTags = <String>[
    '電子決済OK',
    '現金のみ',
    'ゴミ箱あり',
    '屋内',
    '屋外',
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _listenMachines();
    _prepareMarkerIcons();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _machinesSubscription?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _prepareMarkerIcons() async {
    final normal = await _buildMarkerIcon(
      backgroundColor: AppColors.primary,
      borderColor: Colors.white,
      iconColor: Colors.white,
      size: 120,
    );
    final selected = await _buildMarkerIcon(
      backgroundColor: AppColors.accent,
      borderColor: Colors.white,
      iconColor: Colors.white,
      size: 132,
    );
    final fresh = await _buildMarkerIcon(
      backgroundColor: AppColors.success,
      borderColor: Colors.white,
      iconColor: Colors.white,
      size: 120,
    );
    final old = await _buildMarkerIcon(
      backgroundColor: AppColors.warning,
      borderColor: Colors.white,
      iconColor: Colors.white,
      size: 120,
    );

    if (!mounted) return;

    setState(() {
      _normalMarkerIcon = normal;
      _selectedMarkerIcon = selected;
      _freshMarkerIcon = fresh;
      _oldMarkerIcon = old;
      _isPreparingMarkers = false;
    });
  }

  Future<BitmapDescriptor> _buildMarkerIcon({
    required Color backgroundColor,
    required Color borderColor,
    required Color iconColor,
    required int size,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final double width = size.toDouble();
    final double height = size.toDouble() * 1.2;

    final bodyPaint = Paint()..color = backgroundColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(width * 0.18, height * 0.08, width * 0.64, width * 0.64),
      Radius.circular(width * 0.16),
    );

    final pinTail = Path()
      ..moveTo(width * 0.50, height * 0.96)
      ..lineTo(width * 0.40, height * 0.72)
      ..lineTo(width * 0.60, height * 0.72)
      ..close();

    canvas.drawShadow(
      Path()..addRRect(body),
      Colors.black.withOpacity(0.28),
      8,
      false,
    );
    canvas.drawShadow(pinTail, Colors.black.withOpacity(0.28), 6, false);

    canvas.drawRRect(body, bodyPaint);
    canvas.drawRRect(body, borderPaint);
    canvas.drawPath(pinTail, bodyPaint);
    canvas.drawPath(pinTail, borderPaint);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.local_drink_rounded.codePoint),
        style: TextStyle(
          fontSize: width * 0.34,
          fontFamily: Icons.local_drink_rounded.fontFamily,
          package: Icons.local_drink_rounded.fontPackage,
          color: iconColor,
        ),
      ),
    )..layout();

    textPainter.paint(
      canvas,
      Offset((width - textPainter.width) / 2, height * 0.19),
    );

    final image = await recorder.endRecording().toImage(
      width.ceil(),
      height.ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }

    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }

  void _listenMachines() {
    _machinesSubscription?.cancel();

    _machinesSubscription = _firestoreService.watchVendingMachines().listen(
          (items) {
        if (!mounted) return;

        setState(() {
          _liveMachines = items;
          _isLoadingMachines = false;
          if (_selectedMachineIndex >= _machinesWithDistance.length) {
            _selectedMachineIndex = 0;
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveCameraToSelectedMachine(animated: false);
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isLoadingMachines = false;
        });
      },
    );
  }

  Future<void> _loadProgress() async {
    final loaded = await LocalProgressService.load();
    if (!mounted) return;

    setState(() {
      _progress = loaded;
      _isLoadingProgress = false;
    });
  }

  Future<void> _fetchCurrentLocation() async {
    final pos = await _locationService.getCurrentPositionSafe();
    if (!mounted) return;

    setState(() {
      _currentPosition = pos;
      _isFetchingLocation = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraToCurrentOrSelected(animated: false);
    });
  }

  List<VendingMachine> get _sourceMachines {
    if (_liveMachines.isNotEmpty) return _liveMachines;
    return _mockRepository.getNearbyMachines();
  }

  List<VendingMachine> get _filteredMachines {
    final query = _selectedKeyword.trim().toLowerCase();

    return _sourceMachines.where((machine) {
      final matchesQuery = query.isEmpty
          ? true
          : machine.name.toLowerCase().contains(query) ||
          machine.addressHint.toLowerCase().contains(query) ||
          machine.drinks.any((drink) => drink.matches(query));

      final matchesTags = _selectedTags.isEmpty
          ? true
          : _selectedTags.every(machine.tags.contains);

      return matchesQuery && matchesTags;
    }).toList();
  }

  List<VendingMachine> get _machinesWithDistance {
    final base = _filteredMachines.isNotEmpty ? _filteredMachines : _sourceMachines;

    if (_currentPosition == null) {
      return List<VendingMachine>.from(base)
        ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    }

    final updated = base.map((machine) {
      final distance = DistanceUtil.calculateDistanceMeters(
        lat1: _currentPosition!.latitude,
        lon1: _currentPosition!.longitude,
        lat2: machine.latitude,
        lon2: machine.longitude,
      );

      return machine.copyWith(distanceMeters: distance);
    }).toList();

    updated.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return updated;
  }

  VendingMachine get _selectedMachine {
    final list = _machinesWithDistance;
    if (list.isEmpty) return _sourceMachines.first;
    if (_selectedMachineIndex >= list.length) return list.first;
    return list[_selectedMachineIndex];
  }

  List<String> get _suggestions {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return <String>[];

    final candidates = <String>{};

    for (final machine in _sourceMachines) {
      if (machine.name.toLowerCase().contains(query)) {
        candidates.add(machine.name);
      }
      if (machine.addressHint.toLowerCase().contains(query)) {
        candidates.add(machine.addressHint);
      }
      for (final drink in machine.drinks) {
        if (drink.matches(query)) {
          candidates.add(drink.name);
        }
        if (drink.brand.toLowerCase().contains(query) && drink.brand.isNotEmpty) {
          candidates.add(drink.brand);
        }
        if (drink.category.toLowerCase().contains(query) &&
            drink.category.isNotEmpty) {
          candidates.add(drink.category);
        }
      }
    }

    candidates.addAll(
      <String>['Coca-Cola', 'サントリー', '伊藤園']
          .where((e) => e.toLowerCase().contains(query)),
    );

    return candidates.take(8).toList();
  }

  Set<Marker> get _markers {
    final machines = _machinesWithDistance;

    return machines.asMap().entries.map((entry) {
      final index = entry.key;
      final machine = entry.value;
      final selected = index == _selectedMachineIndex;

      BitmapDescriptor icon;
      if (selected && _selectedMarkerIcon != null) {
        icon = _selectedMarkerIcon!;
      } else if (machine.reliabilityScore >= 80 && _freshMarkerIcon != null) {
        icon = _freshMarkerIcon!;
      } else if (machine.reliabilityScore < 60 && _oldMarkerIcon != null) {
        icon = _oldMarkerIcon!;
      } else if (_normalMarkerIcon != null) {
        icon = _normalMarkerIcon!;
      } else {
        icon = BitmapDescriptor.defaultMarker;
      }

      return Marker(
        markerId: MarkerId(machine.id.isEmpty ? 'machine_$index' : machine.id),
        position: LatLng(machine.latitude, machine.longitude),
        icon: icon,
        onTap: () {
          setState(() {
            _selectedMachineIndex = index;
            _microCopy = 'いいの見つかるかも';
          });
          _moveCameraToSelectedMachine(animated: true);
        },
        zIndex: selected ? 2 : 1,
      );
    }).toSet();
  }

  CameraPosition get _initialCameraPosition {
    if (_currentPosition != null) {
      return CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 15.6,
      );
    }

    final machines = _machinesWithDistance;
    if (machines.isEmpty) {
      return const CameraPosition(
        target: LatLng(35.681236, 139.767125),
        zoom: 14,
      );
    }

    final machine = machines.first;
    return CameraPosition(
      target: LatLng(machine.latitude, machine.longitude),
      zoom: 15.3,
    );
  }

  Future<void> _moveCameraToCurrentOrSelected({required bool animated}) async {
    final controller = _mapController;
    if (controller == null) return;

    if (_currentPosition != null) {
      final update = CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 15.6,
        ),
      );
      if (animated) {
        await controller.animateCamera(update);
      } else {
        await controller.moveCamera(update);
      }
      return;
    }

    await _moveCameraToSelectedMachine(animated: animated);
  }

  Future<void> _moveCameraToSelectedMachine({required bool animated}) async {
    final controller = _mapController;
    final machines = _machinesWithDistance;
    if (controller == null || machines.isEmpty) return;

    final index =
    _selectedMachineIndex >= machines.length ? 0 : _selectedMachineIndex;
    final machine = machines[index];

    final update = CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(machine.latitude, machine.longitude),
        zoom: _mapExpanded ? 16.2 : 15.2,
      ),
    );

    if (animated) {
      await controller.animateCamera(update);
    } else {
      await controller.moveCamera(update);
    }
  }

  Future<void> _applySearch(String keyword) async {
    final normalized = keyword.trim();

    setState(() {
      _selectedKeyword = normalized;
      _searchController.text = normalized;
      _selectedMachineIndex = 0;
      _microCopy = normalized.isEmpty ? '今何を飲みたい気分？' : '近くにあるかも';
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

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _selectedKeyword = '';
      _selectedMachineIndex = 0;
      _microCopy = '今何を飲みたい気分？';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraToCurrentOrSelected(animated: true);
    });
  }

  Future<void> _applyTags(List<String> tags) async {
    setState(() {
      _selectedTags
        ..clear()
        ..addAll(tags);
      _selectedMachineIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraToSelectedMachine(animated: true);
    });
  }

  Future<void> _selectMachineFromList(int index) async {
    setState(() {
      _selectedMachineIndex = index;
      _microCopy = 'いいの見つかるかも';
    });
    await _moveCameraToSelectedMachine(animated: true);
  }

  Future<void> _openDetail() async {
    final machine = _selectedMachine;

    final updated = await LocalProgressService.addViewedMachine(
      machineId: machine.id,
      machineName: machine.name,
    );

    if (!mounted) return;

    setState(() {
      _progress = updated;
    });

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MachineDetailScreen(machine: machine),
      ),
    );

    await _loadProgress();
  }

  Future<void> _openDetailForMachine(VendingMachine machine) async {
    final updated = await LocalProgressService.addViewedMachine(
      machineId: machine.id,
      machineName: machine.name,
    );

    if (!mounted) return;

    setState(() {
      _progress = updated;
    });

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MachineDetailScreen(machine: machine),
      ),
    );

    await _loadProgress();
  }

  Future<void> _openCreate() async {
    final result = await Navigator.of(context).push<MachineCreateResult>(
      MaterialPageRoute<MachineCreateResult>(
        builder: (_) => const MachineCreateScreen(),
      ),
    );

    if (result == null) return;

    await LocalProgressService.addCreatedMachine(result.machineName);
    final updated = await LocalProgressService.load();

    if (!mounted) return;

    setState(() {
      _progress = updated;
      _microCopy = result.leveledUp ? 'レベルアップおめでとう！' : '登録ありがとう！';
      _selectedMachineIndex = 0;
    });
  }

  Future<void> _clearSearchHistory() async {
    final updated = await LocalProgressService.clearSearchHistory();
    if (!mounted) return;
    setState(() {
      _progress = updated;
    });
  }

  Future<void> _openSearchSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SearchOptionsTabbedSheet(
          suggestions: _suggestions,
          quickCategories: _quickCategories,
          popularKeywords: _popularKeywords,
          searchHistory: _progress.searchHistory,
          onClearHistory: _clearSearchHistory,
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      await _applySearch(selected);
    }
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final tempSelected = List<String>.from(_selectedTags);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return _FilterBottomSheet(
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

  @override
  Widget build(BuildContext context) {
    final isLoading = _isLoadingProgress ||
        _isLoadingMachines ||
        _isPreparingMarkers ||
        _isFetchingLocation;
    final hasMachines = _machinesWithDistance.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: <Widget>[
            _MinimalTopBar(
              controller: _searchController,
              microCopy: _microCopy,
              selectedTagsCount: _selectedTags.length,
              onChanged: (_) => setState(() {}),
              onSubmitted: _applySearch,
              onClear: _clearSearch,
              onOpenSearchSheet: _openSearchSheet,
              onOpenFilterSheet: _openFilterSheet,
            ),
            if (_currentIndex == 0) ...<Widget>[
              _MapArea(
                initialCameraPosition: _initialCameraPosition,
                markers: _markers,
                expanded: _mapExpanded,
                onToggleExpand: () {
                  setState(() {
                    _mapExpanded = !_mapExpanded;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _moveCameraToSelectedMachine(animated: true);
                  });
                },
                onMapCreated: (controller) {
                  _mapController = controller;
                  _moveCameraToCurrentOrSelected(animated: false);
                },
              ),
              Expanded(
                child: _BottomPanel(
                  currentIndex: _currentIndex,
                  onTabSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  child: !hasMachines
                      ? const _PlaceholderPanel(
                    icon: Icons.search_off_rounded,
                    title: '見つかりませんでした',
                    message: '条件を少しゆるめると見つかるかもしれません。',
                  )
                      : _HomeContent(
                    selectedKeyword: _selectedKeyword,
                    machine: _selectedMachine,
                    machines: _machinesWithDistance,
                    selectedMachineIndex: _selectedMachineIndex,
                    onOpenDetail: _openDetail,
                    onOpenDetailForMachine: _openDetailForMachine,
                    onOpenCreate: _openCreate,
                    onSelectMachine: _selectMachineFromList,
                  ),
                ),
              ),
            ] else if (_currentIndex == 1) ...<Widget>[
              Expanded(
                child: _BottomPanel(
                  currentIndex: _currentIndex,
                  onTabSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  child: const _PlaceholderPanel(
                    icon: Icons.favorite_rounded,
                    title: 'お気に入り',
                    message: 'また飲みたいドリンクをまとめて開けます。',
                  ),
                ),
              ),
            ] else ...<Widget>[
              Expanded(
                child: _BottomPanel(
                  currentIndex: _currentIndex,
                  onTabSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  child: _ProfilePanel(progress: _progress),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text(
          '登録する',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      )
          : null,
    );
  }
}

class _MinimalTopBar extends StatelessWidget {
  const _MinimalTopBar({
    required this.controller,
    required this.microCopy,
    required this.selectedTagsCount,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onOpenSearchSheet,
    required this.onOpenFilterSheet,
  });

  final TextEditingController controller;
  final String microCopy;
  final int selectedTagsCount;
  final ValueChanged<String> onChanged;
  final Future<void> Function(String value) onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onOpenSearchSheet;
  final VoidCallback onOpenFilterSheet;

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
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
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '飲みたいドリンクで探す',
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
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TopSquareButton(
                icon: Icons.expand_more_rounded,
                label: '候補',
                onTap: onOpenSearchSheet,
              ),
              const SizedBox(width: 8),
              _TopSquareButton(
                icon: Icons.tune_rounded,
                label: selectedTagsCount > 0 ? '絞込$selectedTagsCount' : '絞込',
                active: selectedTagsCount > 0,
                onTap: onOpenFilterSheet,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              microCopy,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSquareButton extends StatelessWidget {
  const _TopSquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF6F7) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapArea extends StatelessWidget {
  const _MapArea({
    required this.initialCameraPosition,
    required this.markers,
    required this.expanded,
    required this.onToggleExpand,
    required this.onMapCreated,
  });

  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<GoogleMapController> onMapCreated;

  @override
  Widget build(BuildContext context) {
    final height = expanded
        ? MediaQuery.of(context).size.height * 0.55
        : MediaQuery.of(context).size.height * 0.34;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: height,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
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
                myLocationButtonEnabled: true,
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
                onPressed: onToggleExpand,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(0, 44),
                ),
                icon: Icon(
                  expanded
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                ),
                label: Text(expanded ? '戻す' : 'マップ拡大'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.currentIndex,
    required this.onTabSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const tabs = <({IconData icon, String label})>[
      (icon: Icons.map_rounded, label: 'マップ'),
      (icon: Icons.favorite_rounded, label: 'お気に入り'),
      (icon: Icons.person_rounded, label: 'マイ'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
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
                final selected = currentIndex == index;

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
                              ? AppColors.primary
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              tab.icon,
                              size: 22,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.selectedKeyword,
    required this.machine,
    required this.machines,
    required this.selectedMachineIndex,
    required this.onOpenDetail,
    required this.onOpenDetailForMachine,
    required this.onOpenCreate,
    required this.onSelectMachine,
  });

  final String selectedKeyword;
  final VendingMachine machine;
  final List<VendingMachine> machines;
  final int selectedMachineIndex;
  final Future<void> Function() onOpenDetail;
  final Future<void> Function(VendingMachine machine) onOpenDetailForMachine;
  final Future<void> Function() onOpenCreate;
  final Future<void> Function(int index) onSelectMachine;

  @override
  Widget build(BuildContext context) {
    final title = selectedKeyword.trim().isEmpty
        ? '近くの自販機'
        : '$selectedKeyword を探す';

    final visibleMachines =
    machines.length > 4 ? machines.take(4).toList() : machines;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '喉乾いてない？',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _SelectedMachineCard(
            machine: machine,
            onOpenDetail: onOpenDetail,
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
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_business_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '自販機を登録する',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '登録した自販機が役に立ったよ！',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
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
          const SizedBox(height: 10),
          Text(
            '近い順',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...List<Widget>.generate(visibleMachines.length, (index) {
            final item = visibleMachines[index];
            final isSelected = index == selectedMachineIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MachineListTile(
                machine: item,
                isSelected: isSelected,
                onTap: () => onSelectMachine(index),
                onLongPress: () => onOpenDetailForMachine(item),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SelectedMachineCard extends StatelessWidget {
  const _SelectedMachineCard({
    required this.machine,
    required this.onOpenDetail,
  });

  final VendingMachine machine;
  final Future<void> Function() onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final photoUrl = machine.photoUrls.isNotEmpty ? machine.photoUrls.first : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFEAF6F7),
            Color(0xFFF6FBFB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary, width: 1.2),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '選択中',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _MachineThumbnail(
                imageUrl: photoUrl,
                size: 72,
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      machine.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _InfoChip(
                          icon: Icons.place_rounded,
                          text: DistanceUtil.formatDistance(machine.distanceMeters),
                        ),
                        if (machine.paymentLabel.isNotEmpty)
                          _InfoChip(
                            icon: Icons.payments_rounded,
                            text: machine.paymentLabel,
                          ),
                        if (machine.updatedLabel.isNotEmpty)
                          _InfoChip(
                            icon: Icons.update_rounded,
                            text: machine.updatedLabel,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '下のリストはタップで選択、長押しで詳細',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.directions_walk_rounded),
                  label: const Text('行く'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text('詳細'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MachineListTile extends StatelessWidget {
  const _MachineListTile({
    required this.machine,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final VendingMachine machine;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final photoUrl = machine.photoUrls.isNotEmpty ? machine.photoUrls.first : null;

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
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MachineThumbnail(
              imageUrl: photoUrl,
              size: 64,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '表示中',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    machine.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      _MiniPill(
                        text: DistanceUtil.formatDistance(machine.distanceMeters),
                      ),
                      if (machine.updatedLabel.isNotEmpty)
                        _MiniPill(text: machine.updatedLabel),
                      if (machine.paymentLabel.isNotEmpty)
                        _MiniPill(text: machine.paymentLabel),
                    ],
                  ),
                  if (machine.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: machine.tags.take(2).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
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
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border),
        ),
        child: hasImage
            ? Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const _ThumbnailFallback();
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
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
      child: Icon(
        Icons.local_drink_rounded,
        size: 26,
        color: AppColors.primary,
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _SearchOptionsTabbedSheet extends StatefulWidget {
  const _SearchOptionsTabbedSheet({
    required this.suggestions,
    required this.quickCategories,
    required this.popularKeywords,
    required this.searchHistory,
    required this.onClearHistory,
  });

  final List<String> suggestions;
  final List<String> quickCategories;
  final List<String> popularKeywords;
  final List<String> searchHistory;
  final Future<void> Function() onClearHistory;

  @override
  State<_SearchOptionsTabbedSheet> createState() =>
      _SearchOptionsTabbedSheetState();
}

class _SearchOptionsTabbedSheetState extends State<_SearchOptionsTabbedSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _sheetSearchController = TextEditingController();
  String _sheetQuery = '';

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.searchHistory.isNotEmpty ? 0 : 1;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sheetSearchController.dispose();
    super.dispose();
  }

  List<String> _filterItems(List<String> items) {
    final query = _sheetQuery.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items.where((item) => item.toLowerCase().contains(query)).toList();
  }

  Widget _buildChipList(List<String> items, {bool history = false}) {
    final filtered = _filterItems(items);

    if (filtered.isEmpty) {
      return const _SheetEmptyState(message: '一致する項目がありません');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filtered
            .map(
              (e) => ActionChip(
            avatar: history
                ? const Icon(Icons.history_rounded, size: 18)
                : null,
            label: Text(e),
            onPressed: () => Navigator.of(context).pop(e),
          ),
        )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentItems = widget.searchHistory;
    final popularItems = <String>[
      ...widget.suggestions,
      ...widget.popularKeywords,
    ].toSet().toList();

    return _BottomSheetFrame(
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
              suffixIcon: _sheetQuery.isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  _sheetSearchController.clear();
                  setState(() {
                    _sheetQuery = '';
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              tabs: const <Widget>[
                Tab(text: '最近'),
                Tab(text: '人気'),
                Tab(text: 'カテゴリ'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (recentItems.isNotEmpty)
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: _SheetSectionTitle(title: '最近探したもの'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await widget.onClearHistory();
                              if (!mounted) return;
                              Navigator.of(context).pop();
                            },
                            child: const Text('消す'),
                          ),
                        ],
                      )
                    else
                      const _SheetSectionTitle(title: '最近探したもの'),
                    Expanded(
                      child: _buildChipList(recentItems, history: true),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _SheetSectionTitle(title: '人気ワード'),
                    Expanded(
                      child: _buildChipList(popularItems),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _SheetSectionTitle(title: 'カテゴリ'),
                    Expanded(
                      child: _buildChipList(widget.quickCategories),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBottomSheet extends StatelessWidget {
  const _FilterBottomSheet({
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
    return _BottomSheetFrame(
      title: '絞り込み',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filterTags
                .map(
                  (tag) => FilterChip(
                label: Text(tag),
                selected: selectedTags.contains(tag),
                onSelected: (_) => onToggle(tag),
              ),
            )
                .toList(),
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

class _BottomSheetFrame extends StatelessWidget {
  const _BottomSheetFrame({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: <Widget>[
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.border,
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

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _SheetEmptyState extends StatelessWidget {
  const _SheetEmptyState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.progress,
  });

  final AppProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('レベル ${progress.level}', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '合計 ${progress.exp} EXP',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.levelProgress,
                    minHeight: 10,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progress.expToNextLevel == 0
                      ? '次のレベルまであと100 EXP'
                      : '次のレベルまであと ${progress.expToNextLevel} EXP',
                  style: theme.textTheme.bodySmall,
                ),
              ],
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
            title: '登録した自販機',
            emptyText: 'まだ登録した自販機はありません',
            items: progress.createdMachineNames,
            icon: Icons.add_business_rounded,
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
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
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
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
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

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({
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
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 36, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}